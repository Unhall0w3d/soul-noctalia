--!nonstrict

local snapshot = noctalia.state.get("arrpc_manual_presence") or {
  available = false,
  enabled = false,
  busy = false,
  message = "Manual presence is off.",
}

local applicationId = ""
local details = ""
local state = ""
local includeTimestamp = true
local revision = 0
local render

local function clean(value)
  return noctalia.string.trim(tostring(value or ""))
end

local function validApplicationId(value)
  return value:match("^%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d?%d?%d?$") ~= nil
end

local function publish(action)
  noctalia.state.set("arrpc_manual_presence_command", {
    action = action,
    application_id = clean(applicationId),
    details = clean(details),
    state = clean(state),
    include_timestamp = includeTimestamp == true,
    requested_at = os.time(),
  })
end

local function statusCard()
  local availableText = snapshot.available == true and "arRPC is reachable." or "arRPC is not reachable. Start its user service, then refresh."
  return ui.column({ gap = 5, padding = 12, fill = "surface_variant/0.45", radius = 12 }, {
    ui.row({ gap = 8, align = "center" }, {
      ui.glyph({ name = "brand-discord", size = 20, color = snapshot.enabled == true and "primary" or "on_surface_variant" }),
      ui.label({ text = snapshot.enabled == true and "Manual presence active" or "Manual presence off", fontWeight = "bold", flexGrow = 1 }),
      ui.button({ text = "Refresh", glyph = "refresh", variant = "outline", onClick = function() publish("status") end, enabled = snapshot.busy ~= true }),
    }),
    ui.label({ text = availableText, fontSize = 12, color = snapshot.available == true and "on_surface_variant" or "error" }),
    ui.label({ text = tostring(snapshot.message or ""), fontSize = 12, color = snapshot.ok == false and "error" or "on_surface_variant", visible = tostring(snapshot.message or "") ~= "" }),
  })
end

render = function()
  local valid = validApplicationId(clean(applicationId)) and clean(details) ~= ""
  panel.render(ui.column({ height = 528, padding = 16 }, {
    ui.scroll({ flexGrow = 1, gap = 12 }, {
      ui.row({ gap = 10, align = "center" }, {
        ui.glyph({ name = "brand-discord", size = 28, color = "primary" }),
        ui.column({ gap = 1, flexGrow = 1 }, {
          ui.label({ text = "Manual Rich Presence", fontSize = 21, fontWeight = "bold" }),
          ui.label({ text = "A deliberate static override; it does not inspect Soul or application activity.", fontSize = 12, color = "on_surface_variant" }),
        }),
      }),
      statusCard(),
      ui.label({ text = "Discord Application ID", fontWeight = "bold" }),
      ui.input({ key = "application-id-" .. revision, value = applicationId, placeholder = "Developer Portal application ID", onChange = "onApplicationIdChange" }),
      ui.label({ text = "Create your own Discord application for this presence. The ID is public; no token is needed.", fontSize = 12, color = "on_surface_variant" }),
      ui.label({ text = "Details", fontWeight = "bold" }),
      ui.input({ key = "details-" .. revision, value = details, placeholder = "e.g. Building a quiet system", onChange = "onDetailsChange" }),
      ui.label({ text = "State (optional)", fontWeight = "bold" }),
      ui.input({ key = "state-" .. revision, value = state, placeholder = "e.g. Atelier / Local", onChange = "onStateChange" }),
      ui.row({ gap = 8, align = "center" }, {
        ui.toggle({ checked = includeTimestamp, onChange = "onTimestampChange" }),
        ui.label({ text = "Show elapsed time since activation", flexGrow = 1 }),
      }),
      ui.label({ text = valid and "" or "Enter a valid Discord Application ID and Details before publishing.", fontSize = 12, color = "error", visible = not valid }),
    }),
    ui.row({ gap = 8 }, {
      ui.button({ text = "Publish override", glyph = "broadcast", variant = "primary", flexGrow = 1, enabled = valid and snapshot.busy ~= true and snapshot.available == true, onClick = function() publish("publish") end }),
      ui.button({ text = "Turn off", glyph = "player-stop", variant = "outline", enabled = validApplicationId(clean(applicationId)) and snapshot.busy ~= true, onClick = function() publish("clear") end }),
    }),
  }))
end

function onApplicationIdChange(value)
  applicationId = tostring(value or "")
  render()
end

function onDetailsChange(value)
  details = tostring(value or "")
  render()
end

function onStateChange(value)
  state = tostring(value or "")
  render()
end

function onTimestampChange(value)
  includeTimestamp = value == true
  render()
end

noctalia.state.watch("arrpc_manual_presence", function(value)
  if type(value) == "table" then
    snapshot = value
    render()
  end
end)

render()
