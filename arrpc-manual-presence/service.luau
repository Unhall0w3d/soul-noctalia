--!nonstrict

local PUBLISHER_COMMAND = tostring(noctalia.getConfig("publisher_command") or "")
local STATE_FILE = noctalia.pluginDataDir() .. "/manual-presence.json"
local snapshot = {
  available = false,
  enabled = false,
  busy = false,
  ok = nil,
  message = "Manual presence is off.",
  application_id = "",
  details = "",
  state = "",
  include_timestamp = true,
}

local function validApplicationId(value)
  return tostring(value or ""):match("^%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d?%d?%d?$") ~= nil
end

local function persist()
  noctalia.writeFile(STATE_FILE, noctalia.json.encode({
    enabled = snapshot.enabled == true,
    application_id = tostring(snapshot.application_id or ""),
    details = tostring(snapshot.details or ""),
    state = tostring(snapshot.state or ""),
    include_timestamp = snapshot.include_timestamp ~= false,
  }))
end

local function restore()
  local raw = noctalia.readFile(STATE_FILE)
  if raw == nil or raw == "" then return end
  local decoded = noctalia.json.decode(raw)
  if type(decoded) ~= "table" then return end
  if validApplicationId(decoded.application_id) then
    snapshot.application_id = tostring(decoded.application_id)
    snapshot.enabled = decoded.enabled == true
  end
  if type(decoded.details) == "string" and #decoded.details <= 128 then snapshot.details = decoded.details end
  if type(decoded.state) == "string" and #decoded.state <= 128 then snapshot.state = decoded.state end
  snapshot.include_timestamp = decoded.include_timestamp ~= false
end

local function safeCommand()
  if PUBLISHER_COMMAND == "./arrpc-manual-presence" then
    local pluginDir = tostring(noctalia.pluginDir() or "")
    if pluginDir:match("^/") then return pluginDir .. "/arrpc-manual-presence" end
  end
  if PUBLISHER_COMMAND:match("^/[%w%._/%-]+$") then return PUBLISHER_COMMAND end
  return nil
end

local function shellQuote(value)
  return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

local function publish()
  noctalia.state.set("arrpc_manual_presence", snapshot)
end

local function setResult(result, successMessage, failureMessage)
  local output = tostring(result and result.stdout or "")
  local decoded = noctalia.json.decode(output)
  local ok = result and result.exitCode == 0 and type(decoded) == "table" and decoded.ok == true
  snapshot.ok = ok
  snapshot.available = type(decoded) == "table" and decoded.available == true
  snapshot.message = ok and successMessage or (type(decoded) == "table" and tostring(decoded.message or failureMessage) or failureMessage)
  return ok
end

local function runStatus()
  local command = safeCommand()
  if command == nil then
    snapshot.available = false
    snapshot.ok = false
    snapshot.message = "Publisher command is not configured safely."
    publish()
    return
  end
  snapshot.busy = true
  publish()
  noctalia.runAsync(command .. " status", function(result)
    snapshot.busy = false
    setResult(result, snapshot.enabled == true and "Manual override is active." or "Manual presence is off.", "Unable to query arRPC.")
    publish()
  end, 5000)
end

local function publishOverride(command)
  local appId = tostring(command.application_id or "")
  local details = tostring(command.details or "")
  local state = tostring(command.state or "")
  if not validApplicationId(appId) or details == "" or #details > 128 or #state > 128 then
    snapshot.ok = false
    snapshot.message = "Manual presence input failed bounded validation."
    publish()
    return
  end
  local executable = safeCommand()
  if executable == nil then
    snapshot.ok = false
    snapshot.available = false
    snapshot.message = "Publisher command is not configured safely."
    publish()
    return
  end
  snapshot.busy = true
  publish()
  local args = executable .. " publish --application-id " .. shellQuote(appId) .. " --details " .. shellQuote(details) .. " --state " .. shellQuote(state)
  if command.include_timestamp == true then args = args .. " --started-at " .. tostring(os.time()) end
  noctalia.runAsync(args, function(result)
    snapshot.busy = false
    if setResult(result, "Manual override published. Turn it off to return control to normal arRPC activity.", "Unable to publish manual presence.") then
      snapshot.enabled = true
      snapshot.application_id = appId
      snapshot.details = details
      snapshot.state = state
      snapshot.include_timestamp = command.include_timestamp == true
      persist()
    end
    publish()
  end, 5000)
end

local function clearOverride(command)
  local requestedAppId = tostring(command.application_id or "")
  local appId = validApplicationId(requestedAppId) and requestedAppId or tostring(snapshot.application_id or "")
  if not validApplicationId(appId) then
    snapshot.ok = false
    snapshot.message = "Enter the same valid Application ID to clear this manual activity."
    publish()
    return
  end
  local executable = safeCommand()
  if executable == nil then
    snapshot.ok = false
    snapshot.message = "Publisher command is not configured safely."
    publish()
    return
  end
  snapshot.busy = true
  publish()
  noctalia.runAsync(executable .. " clear --application-id " .. shellQuote(appId), function(result)
    snapshot.busy = false
    if setResult(result, "Manual override cleared. arRPC is available for normal application activity.", "Unable to clear manual presence.") then
      snapshot.enabled = false
      persist()
    end
    publish()
  end, 5000)
end

restore()

noctalia.state.watch("arrpc_manual_presence_command", function(command)
  if type(command) ~= "table" then return end
  if command.action == "status" then
    runStatus()
  elseif command.action == "publish" then
    publishOverride(command)
  elseif command.action == "clear" then
    clearOverride(command)
  end
end)

runStatus()
