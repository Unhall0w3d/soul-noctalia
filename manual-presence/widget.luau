--!nonstrict

local PANEL_ID = "arrpc/manual-presence:editor"
local snapshot = noctalia.state.get("arrpc_manual_presence") or {
  available = false,
  enabled = false,
  busy = false,
  message = "Manual presence is off.",
}

local function render()
  local color = snapshot.enabled == true and "primary" or "on_surface_variant"
  local container = barWidget.isVertical() and ui.column or ui.row
  barWidget.render(container({ gap = 5, align = "center" }, {
    ui.glyph({ name = "brand-discord", size = 17, color = color }),
    ui.box({
      width = 7,
      height = 7,
      radius = 4,
      fill = snapshot.busy == true and "secondary" or (snapshot.enabled == true and "tertiary" or "on_surface_variant"),
    }),
  }))
  local state = snapshot.enabled == true and "Manual override active" or "Manual override off"
  if snapshot.available ~= true then state = "arRPC unavailable" end
  barWidget.setTooltip("arRPC Manual Presence\n" .. state .. "\n" .. tostring(snapshot.message or ""))
end

noctalia.state.watch("arrpc_manual_presence", function(value)
  if type(value) == "table" then
    snapshot = value
    render()
  end
end)

function onClick()
  noctalia.togglePanel(PANEL_ID)
end

function onRightClick()
  noctalia.state.set("arrpc_manual_presence_command", {
    action = "status",
    requested_at = os.time(),
  })
end

render()
