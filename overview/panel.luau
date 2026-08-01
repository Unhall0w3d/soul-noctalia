--!nonstrict

local snapshot = noctalia.state.get("soul_snapshot") or {
  ok = false,
  loading = true,
  soul = { version = "unknown", health = "unavailable" },
  core = { available = false },
  voice_presence = { available = false, running = false },
  fleet = { available = false, device_count = 0, healthy_count = 0, devices = {} },
}
local action = noctalia.state.get("soul_action") or { busy = false }
local SOUL_COMMAND = tostring(noctalia.getConfig("soul_command") or "")
local flippedDevices = {}
local render

local function statusColor(health)
  if health == "unhealthy" or health == "unavailable" then return "error" end
  if health == "healthy" then return "tertiary" end
  return "secondary"
end

local function coreStateText(core)
  if core.available ~= true then return "Unavailable" end
  local mode = tostring(core.mode or core.id or "")
  if mode == "free" then return "No model loaded" end
  if mode == "dev" then return "Development lane active" end
  if mode == "" or mode == "unloaded" then return "No Core active" end
  return "Core active"
end

local function card(children)
  return ui.column({ gap = 8, padding = 12, fill = "surface_variant/0.45", radius = 12 }, children)
end

local function rowsText(rows, separator)
  local values = {}
  for _, row in ipairs(rows or {}) do
    local label = tostring(row.label or "")
    local value = tostring(row.value or "")
    if label ~= "" and value ~= "" then
      table.insert(values, label .. ": " .. value)
    end
  end
  return table.concat(values, separator or "\n")
end

local function frontText(device)
  local identity = rowsText(device.summary_rows, " · ")
  if identity == "" then identity = device.subtitle or "SSH-integrated device" end
  return (device.display_name or device.id or "Unknown device") .. "    " .. (device.health or "unknown") .. "\n" .. identity
end

local function backText(device)
  local title = (device.display_name or device.id or "Device") .. " — " .. (device.subtitle or "SSH-integrated device")
  local details = rowsText(device.detail_rows, "\n")
  return details == "" and title or title .. "\n" .. details
end

local function connectAction(device)
  for _, candidate in ipairs(device.actions or {}) do
    if candidate.id == "connect" and candidate.kind == "terminal" and candidate.enabled == true then
      return candidate
    end
  end
  return nil
end

local function connectDevice(device)
  local id = tostring(device.id or "")
  if connectAction(device) == nil or not id:match("^[%w][%w%._%-]*$") then
    noctalia.notifyError("Soul SSH", "Soul has not allowed an interactive connection for this device.")
    return
  end
  if SOUL_COMMAND == "" or not SOUL_COMMAND:match("^[%w%._/%-]+$") then
    noctalia.notifyError("Soul SSH", "Soul command is not configured safely.")
    return
  end
  if noctalia.runInTerminal(SOUL_COMMAND .. " connect --device " .. id) then
    panel.close()
  else
    noctalia.notifyError("Soul SSH", "The default terminal could not be opened for " .. (device.display_name or id) .. ".")
  end
end

local function flipDevice(device)
  local key = tostring(device.id or "unknown")
  local wasFlipped = flippedDevices[key] == true
  flippedDevices = {}
  if not wasFlipped then flippedDevices[key] = true end
  render()
end

local function activeFlippedKey()
  for key, flipped in pairs(flippedDevices) do
    if flipped == true then return key end
  end
  return nil
end

local function fleetRows()
  local devices = snapshot.fleet and snapshot.fleet.devices or {}
  local rows = {}
  local activeKey = activeFlippedKey()
  local deviceCount = #devices
  local compactFleet = deviceCount > 4
  local rowGap = compactFleet and 4 or 6
  local frontHeight = compactFleet and math.max(40, math.floor((274 - ((deviceCount - 1) * rowGap)) / deviceCount)) or 64
  for _, device in ipairs(devices) do
    local key = tostring(device.id or "unknown")
    local flipped = flippedDevices[key] == true
    local canConnect = connectAction(device) ~= nil
    if activeKey == nil or key == activeKey then
      table.insert(rows, ui.button({
        key = key,
        text = flipped and backText(device) or frontText(device),
        glyph = flipped and "info-circle" or "server",
        glyphSize = 18,
        fontSize = flipped and 12 or (compactFleet and 12 or 14),
        contentAlign = "start",
        controlSize = "lg",
        height = flipped and 274 or frontHeight,
        variant = statusColor(device.health) == "error" and "destructive" or "outline",
        selected = flipped,
        tooltip = canConnect and (flipped and "Left-click to connect · right-click to return to the fleet" or "Left-click to connect · right-click for details") or "No interactive action is available",
        onClick = function() connectDevice(device) end,
        onRightClick = function() flipDevice(device) end,
      }))
    end
  end
  if #rows == 0 then
    table.insert(rows, ui.label({ text = "No SSH-integrated devices are available.", color = "on_surface_variant", textAlign = "center" }))
  end
  return rows, rowGap
end

render = function()
  local soul = snapshot.soul or {}
  local core = snapshot.core or {}
  local voice = snapshot.voice_presence or {}
  local fleet = snapshot.fleet or {}
  local voiceText = voice.running and "Voice Presence is open" or "Voice Presence is closed"
  local voiceButtonText = voice.running and "Already open" or "Launch Voice Presence"
  local fleetItems, fleetGap = fleetRows()

  panel.render(ui.column({ flexGrow = 1, gap = 12, padding = 16 }, {
    ui.row({ gap = 10, align = "center" }, {
      ui.glyph({ name = "sparkles", size = 28, color = "primary" }),
      ui.column({ gap = 1, flexGrow = 1 }, {
        ui.label({ text = "Soul", fontSize = 22, fontWeight = "bold" }),
        ui.label({ text = `Version {soul.version or "unknown"}`, color = "on_surface_variant" }),
      }),
      ui.button({ text = "Refresh", glyph = "refresh", variant = "outline", onClick = "onRefresh", enabled = snapshot.loading ~= true }),
    }),
    card({
      ui.label({ text = "Active Core", fontWeight = "bold", color = "primary" }),
      ui.label({ text = core.label or core.mode or "Unavailable", fontSize = 18, fontWeight = "bold" }),
      ui.label({ text = `State: {coreStateText(core)}`, color = "on_surface_variant" }),
    }),
    card({
      ui.row({ gap = 8, align = "center" }, {
        ui.glyph({ name = "microphone", size = 20, color = voice.running and "tertiary" or "on_surface_variant" }),
        ui.column({ gap = 2, flexGrow = 1 }, {
          ui.label({ text = "Persistent voice presence", fontWeight = "bold" }),
          ui.label({ text = voiceText, color = "on_surface_variant", fontSize = 12 }),
        }),
        ui.button({ text = voiceButtonText, variant = "outline", onClick = "onVoiceLaunch", enabled = voice.available == true and voice.running ~= true and action.busy ~= true }),
      }),
      action.message and ui.label({ text = action.message, color = action.ok == false and "error" or "on_surface_variant", fontSize = 12 }) or ui.spacer({ height = 0 }),
    }),
    ui.row({ gap = 8, align = "center" }, {
      ui.label({ text = "SSH-integrated fleet", fontWeight = "bold", flexGrow = 1 }),
      ui.label({ text = `{tonumber(fleet.healthy_count) or 0}/{tonumber(fleet.device_count) or 0} healthy`, color = "on_surface", fontWeight = "bold" }),
    }),
    ui.column({ gap = fleetGap }, fleetItems),
    snapshot.error and ui.label({ text = snapshot.error, color = "error", fontSize = 12, maxLines = 2 }) or ui.spacer({ height = 0 }),
  }))
end

noctalia.state.watch("soul_snapshot", function(value)
  if type(value) == "table" then snapshot = value; render() end
end)

noctalia.state.watch("soul_action", function(value)
  if type(value) == "table" then action = value; render() end
end)

function onOpen(_context)
  noctalia.state.set("soul_command", { action = "refresh", requestedAt = os.time() })
  render()
end

function onRefresh()
  noctalia.state.set("soul_command", { action = "refresh", requestedAt = os.time() })
end

function onVoiceLaunch()
  noctalia.state.set("soul_command", { action = "voice-launch", requestedAt = os.time() })
end

render()
