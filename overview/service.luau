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

local function commandBase()
  if SOUL_COMMAND == "" or not SOUL_COMMAND:match("^[%w%._/%-]+$") then
    return nil
  end
  return SOUL_COMMAND
end

local function publish()
  noctalia.state.set("soul_snapshot", snapshot)
end

local function refresh()
  if refreshPending then return end
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
  end, 10000)
end

noctalia.state.watch("soul_command", function(command)
  if type(command) ~= "table" then return end
  if command.action == "refresh" then
    refresh()
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
