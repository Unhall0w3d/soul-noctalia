--!nonstrict

local SOUL_COMMAND = tostring(noctalia.getConfig("soul_command") or "")
local snapshot = {
  ok = false,
  loading = true,
  soul = { version = "unknown", health = "unavailable" },
  core = { available = false },
  voice_presence = { available = false, running = false },
  fleet = { available = false, device_count = 0, healthy_count = 0, devices = {} },
}
local refreshPending = false
local refreshQueued = false
local pendingCorePreview = nil
local refresh

local function commandBase()
  if SOUL_COMMAND == "" or not SOUL_COMMAND:match("^[%w%._/%-]+$") then
    return nil
  end
  return SOUL_COMMAND
end

local function publish()
  noctalia.state.set("soul_snapshot", snapshot)
end

local function safeCoreId(value)
  local id = tostring(value or "")
  if id == "daily" or id == "amd-free" or id == "music" or id == "free" or id == "dev" then
    return id
  end
  return nil
end

local function safeProfileId(value)
  local id = tostring(value or "")
  if id:match("^[a-z][a-z0-9%-]*$") and #id <= 40 then return id end
  return nil
end

local function safeConfirmation(value)
  local phrase = tostring(value or "")
  if phrase:match("^[A-Z][A-Z0-9_%-]*$") and #phrase <= 96 then return phrase end
  return nil
end

local function safeDigest(value)
  local digest = tostring(value or "")
  if digest:match("^[a-f0-9]+$") and #digest == 64 then return digest end
  return nil
end

local function coreAction(value)
  noctalia.state.set("soul_core_action", value)
end

local function previewCore(coreId)
  if safeCoreId(coreId) == nil then
    coreAction({ busy = false, ok = false, stage = "failed", message = "Soul rejected an unknown Core." })
    return
  end
  local command = commandBase()
  if command == nil then
    coreAction({ busy = false, ok = false, stage = "failed", message = "Soul command is not configured safely" })
    return
  end
  pendingCorePreview = nil
  coreAction({ busy = true, ok = nil, stage = "previewing", message = "Reviewing the exact Core transition…" })
  noctalia.runAsync(command .. " core-preview --core " .. coreId, function(result)
    local decoded = nil
    if result then decoded = noctalia.json.decode(result.stdout or "") end
    local data = type(decoded) == "table" and decoded.data or nil
    local valid = result and result.exitCode == 0 and type(decoded) == "table" and decoded.schema_version == "soul.noctalia.core_control.v1" and
      decoded.ok == true and type(data) == "table" and data.executable == true and
      safeCoreId(data.target_core and data.target_core.id) == coreId and
      safeProfileId(data.target_profile_id) ~= nil and safeConfirmation(data.confirmation_phrase) ~= nil and
      safeDigest(data.expected_digest) ~= nil
    if valid then
      pendingCorePreview = decoded
      coreAction({
        busy = false, ok = true, stage = "review", message = "Exact Core transition is ready for your approval.",
        target_core = data.target_core, source_core = data.source_core,
        service_mutation_required = data.service_mutation_required == true,
      })
      return
    end
    local message = type(decoded) == "table" and tostring(decoded.message or "Core preview was blocked") or "Soul returned an invalid Core preview"
    coreAction({ busy = false, ok = false, stage = "failed", message = message })
  end, 15000)
end

local function activateCore(coreId)
  local preview = pendingCorePreview
  local data = type(preview) == "table" and preview.data or nil
  if safeCoreId(coreId) == nil or type(data) ~= "table" or safeCoreId(data.target_core and data.target_core.id) ~= coreId then
    pendingCorePreview = nil
    coreAction({ busy = false, ok = false, stage = "failed", message = "Core preview is missing or no longer matches." })
    return
  end
  local profile = safeProfileId(data.target_profile_id)
  local confirmation = safeConfirmation(data.confirmation_phrase)
  local digest = safeDigest(data.expected_digest)
  local command = commandBase()
  if command == nil or profile == nil or confirmation == nil or digest == nil then
    pendingCorePreview = nil
    coreAction({ busy = false, ok = false, stage = "failed", message = "Core approval data failed bounded validation." })
    return
  end
  coreAction({ busy = true, ok = nil, stage = "activating", message = "Applying the reviewed Core transition…" })
  local invocation = command .. " core-activate --core " .. coreId .. " --target-profile " .. profile ..
    " --confirmation " .. confirmation .. " --expected-digest " .. digest
  noctalia.runAsync(invocation, function(result)
    pendingCorePreview = nil
    local decoded = nil
    if result then decoded = noctalia.json.decode(result.stdout or "") end
    local ok = result and result.exitCode == 0 and type(decoded) == "table" and
      decoded.schema_version == "soul.noctalia.core_control.v1" and decoded.ok == true
    local label = type(decoded) == "table" and decoded.data and decoded.data.active_core_label or nil
    local message = ok and ((label or "Requested Core") .. " is active.") or
      (type(decoded) == "table" and tostring(decoded.message or "Core transition failed safely") or "Core transition failed safely")
    coreAction({ busy = false, ok = ok, stage = ok and "complete" or "failed", message = message })
    refresh()
  end, 120000)
end

refresh = function()
  if refreshPending then refreshQueued = true; return end
  refreshQueued = false
  refreshPending = true
  snapshot.loading = true
  publish()
  local command = commandBase()
  if command == nil then
    refreshPending = false
    snapshot.ok = false
    snapshot.loading = false
    snapshot.error = "Soul command is not configured safely"
    publish()
    return
  end
  noctalia.runAsync(command .. " status", function(result)
    refreshPending = false
    local output = tostring(result and result.stdout or "")
    local standardError = tostring(result and result.stderr or "")
    local decoded, errorMessage = noctalia.json.decode(output)
    if type(decoded) == "table" and decoded.schema_version == "soul.noctalia.status.v2" then
      snapshot = decoded
      snapshot.loading = false
      snapshot.error = decoded.error
      publish()
      if refreshQueued then refresh() end
      return
    end
    noctalia.log(`soul-overview: status failed exit={result and result.exitCode or -1} stdout_bytes={#output} stderr={standardError:sub(1, 240)}`)
    if standardError ~= "" then
      snapshot.error = standardError
    elseif output ~= "" then
      snapshot.error = "Soul returned an invalid status document"
    else
      snapshot.error = "Soul status returned no data"
    end
    snapshot.ok = false
    snapshot.loading = false
    publish()
    if refreshQueued then refresh() end
  end, 10000)
end

noctalia.state.watch("soul_command", function(command)
  if type(command) ~= "table" then return end
  if command.action == "refresh" then
    refresh()
  elseif command.action == "core-preview" then
    previewCore(command.core_id)
  elseif command.action == "core-activate" then
    activateCore(command.core_id)
  elseif command.action == "core-cancel" then
    pendingCorePreview = nil
    coreAction({ busy = false, ok = nil, stage = "idle", message = "Core transition canceled." })
  elseif command.action == "voice-launch" then
    noctalia.state.set("soul_action", { busy = true, message = "Opening Voice Presence…" })
    local executable = commandBase()
    if executable == nil then
      noctalia.state.set("soul_action", { busy = false, ok = false, message = "Soul command is not configured safely" })
      return
    end
    noctalia.runAsync(executable .. " voice-launch", function(result)
      local decoded = nil
      if result then decoded = noctalia.json.decode(result.stdout or "") end
      local ok = result and result.exitCode == 0 and type(decoded) == "table" and decoded.ok == true
      noctalia.state.set("soul_action", {
        busy = false,
        ok = ok,
        message = type(decoded) == "table" and decoded.message or tostring(result and result.stderr or "Voice Presence launch failed"),
      })
      refresh()
    end, 15000)
  end
end)

noctalia.setUpdateInterval(30000)

function update()
  refresh()
end

refresh()
