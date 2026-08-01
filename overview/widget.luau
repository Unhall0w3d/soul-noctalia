--!nonstrict

local PANEL_ID = "soul/overview:overview"
local snapshot = noctalia.state.get("soul_snapshot") or {
  ok = false,
  loading = true,
  soul = { version = "unknown", health = "unavailable" },
  core = {},
  fleet = { device_count = 0, healthy_count = 0 },
}

local function healthColor()
  local health = snapshot.soul and snapshot.soul.health or "unavailable"
  if health == "healthy" then return "tertiary" end
  if health == "degraded" then return "secondary" end
  return "error"
end

local function coreStateText(core)
  if core.available ~= true then return "unavailable" end
  local mode = tostring(core.mode or core.id or "")
  if mode == "free" then return "no model loaded" end
  if mode == "dev" then return "development lane active" end
  if mode == "" or mode == "unloaded" then return "no Core active" end
  return "active"
end

local function render()
  local core = snapshot.core or {}
  local fleet = snapshot.fleet or {}
  local children = {
    ui.glyph({ name = "sparkles", size = 17, color = snapshot.ok and "primary" or "on_surface_variant" }),
    ui.box({ width = 7, height = 7, radius = 4, fill = healthColor() }),
  }
  local container = barWidget.isVertical() and ui.column or ui.row
  barWidget.render(container({ gap = 5, align = "center" }, children))
  barWidget.setTooltip(table.concat({
    `Soul {snapshot.soul and snapshot.soul.version or "unknown"}`,
    `Core: {core.label or core.mode or "unavailable"}`,
    `Core state: {coreStateText(core)}`,
    `SSH fleet: {tonumber(fleet.healthy_count) or 0}/{tonumber(fleet.device_count) or 0} healthy`,
  }, "\n"))
end

noctalia.state.watch("soul_snapshot", function(value)
  if type(value) == "table" then
    snapshot = value
    render()
  end
end)

function onClick()
  noctalia.togglePanel(PANEL_ID)
end

function onRightClick()
  noctalia.state.set("soul_command", { action = "refresh", requestedAt = os.time() })
end

render()
