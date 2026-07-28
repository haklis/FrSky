--[[
  FuelEst - Turbine fuel-remaining widget for FrSky ETHOS
  --------------------------------------------------------
  API pattern confirmed against github.com/flyingeek/ethos-color-value
  (an actively maintained widget that branches on ethosVersion.major>=26),
  so this follows the current lifecycle: create -> build -> configure ->
  read/write (storage) -> wakeup (throttled) -> paint -> menu.

  ETHOS has two coexisting firmware branches as of mid-2026: the legacy
  1.6.x line and the newer year-numbered 26.x line. This script avoids
  version-specific font/theme names that only exist on one branch,
  falling back where needed (see valueFont below).

  ------------------------------------------------------------------
  CONCEPT (unchanged from before)
  ------------------------------------------------------------------
  Your Arduino telemetry adapter integrates effective pump voltage
  every ECU frame:

      effective_pump_voltage = (PW / PW_max) * battery_voltage

  and sends the running sum as a single telemetry sensor ("pump
  total"). Fuel used is modelled as linear in that accumulator:

      fuel_used_mL = (Calib / 1000) * (pump_total_raw - baseline)

  Calib is "mL per 1000 raw units" (kept as an integer field; divide
  by 1000 internally for sub-mL/unit resolution). Tune it empirically:
  fly, measure fuel actually used, divide by the raw delta logged
  over that flight, multiply by 1000, enter as Calib.

  `baseline` normally stays 0 (assumes the Arduino's accumulator
  resets to 0 at power-up). Use the widget's long-press menu ->
  "Mark tank full" to rebase to 100% at any time, e.g. after a
  manual top-off mid-day without power-cycling anything.

  ------------------------------------------------------------------
  FUEL LOW / FUEL CRITICAL
  ------------------------------------------------------------------
  Two independent thresholds, each with its own audio file:

    - Fuel Low      (default 30%) -> yellow widget background
    - Fuel Critical (default 10%) -> red widget background

  The audio file for a threshold plays once, the first time fuel
  drops to or below that percentage ("fires"). It re-arms only once
  fuel rises back above (threshold + CALLOUT_HYSTERESIS), so normal
  telemetry noise/rounding near the threshold doesn't repeat the
  callout on every wakeup. "Mark tank full" (menu) also re-arms both
  immediately. The background color follows the current fuel level
  directly (not the fired/armed state), so it always reflects reality
  even if you mute/skip a callout.

  ------------------------------------------------------------------
  INSTALLATION
  ------------------------------------------------------------------
  Copy to /scripts/fuelest/main.lua on the radio's storage, then add
  as a widget on a telemetry screen and configure Tank / Calibration
  / Sensor from its "Configure widget" menu.
]]

local widgetName = "Fuel %"

-- refresh throttle: fuel telemetry doesn't need to be checked faster
-- than a couple times a second
local refreshRate = 0.5 -- seconds

-- percentage points the fuel level must rise back above a threshold
-- before that threshold's audio callout is allowed to fire again
local CALLOUT_HYSTERESIS = 3

-- defensive font choice: FONT_XL/FONT_S exist on both 1.6.x and 26.x;
-- newer fonts like FONT_M are not guaranteed pre-26, so we don't rely on them
local valueFont = FONT_XL
local labelFont = FONT_S

local function name()
  return widgetName
end

local function create()
  return {
    -- configuration (persisted via storage)
    tank = 1000,      -- tank capacity, mL
    calib = 500,      -- mL per 1000 raw pump_total units
    source = nil,     -- telemetry source for pump_total
    baseline = 0,      -- raw value treated as "tank full"

    fuelLowPct = 30,        -- yellow background + callout at/below this %
    fuelLowFile = nil,      -- audio file for the fuel-low callout
    fuelCriticalPct = 10,   -- red background + callout at/below this %
    fuelCriticalFile = nil, -- audio file for the fuel-critical callout

    -- runtime state (not persisted)
    fuelLowFired = false,
    fuelCriticalFired = false,
    pct = nil,
    lastPctInt = nil,
    timestamp = 0,
    updateNextWakeup = true,
    width = nil,
    height = nil,
  }
end

-- ------------------------------------------------------------------
-- build(): called on creation and on layout/theme changes. Cache
-- geometry here rather than calling lcd.getWindowSize() in paint().
-- ------------------------------------------------------------------
local function build(widget)
  widget.width, widget.height = lcd.getWindowSize()
  widget.updateNextWakeup = true
end

-- ------------------------------------------------------------------
-- configure(): widget setup form
-- ------------------------------------------------------------------
local function configure(widget)
  local line = form.addLine("Tank capacity (mL)")
  form.addNumberField(line, nil, 100, 30000,
    function() return widget.tank end,
    function(value)
      widget.tank = value
      widget.updateNextWakeup = true
    end)

  line = form.addLine("Calibration (mL per 1000 units)")
  form.addNumberField(line, nil, 1, 50000,
    function() return widget.calib end,
    function(value)
      widget.calib = value
      widget.updateNextWakeup = true
    end)

  line = form.addLine("Pump total sensor")
  form.addSourceField(line, nil,
    function() return widget.source end,
    function(value)
      widget.source = value
      widget.baseline = 0 -- new sensor: reset baseline, avoid stale offset
      widget.updateNextWakeup = true
    end)

  line = form.addLine("Fuel Low threshold (%)")
  form.addNumberField(line, nil, 0, 100,
    function() return widget.fuelLowPct end,
    function(value)
      widget.fuelLowPct = value
      widget.fuelLowFired = false -- re-arm on threshold change
      widget.updateNextWakeup = true
    end)

  line = form.addLine("Fuel Low audio file")
  form.addFileField(line, nil, "/audio/en/us", "audio",
    function() return widget.fuelLowFile end,
    function(value)
      widget.fuelLowFile = value
      widget.fuelLowFired = false
    end)

  line = form.addLine("Fuel Critical threshold (%)")
  form.addNumberField(line, nil, 0, 100,
    function() return widget.fuelCriticalPct end,
    function(value)
      widget.fuelCriticalPct = value
      widget.fuelCriticalFired = false
      widget.updateNextWakeup = true
    end)

  line = form.addLine("Fuel Critical audio file")
  form.addFileField(line, nil, "/audio/en/us", "audio",
    function() return widget.fuelCriticalFile end,
    function(value)
      widget.fuelCriticalFile = value
      widget.fuelCriticalFired = false
    end)
end

-- ------------------------------------------------------------------
-- persistence
-- ------------------------------------------------------------------
local function read(widget)
  widget.tank = storage.read("tank") or widget.tank
  widget.calib = storage.read("calib") or widget.calib
  widget.source = storage.read("source")
  widget.baseline = storage.read("baseline") or 0
  widget.fuelLowPct = storage.read("fuelLowPct") or widget.fuelLowPct
  widget.fuelLowFile = storage.read("fuelLowFile")
  widget.fuelCriticalPct = storage.read("fuelCriticalPct") or widget.fuelCriticalPct
  widget.fuelCriticalFile = storage.read("fuelCriticalFile")
end

local function write(widget)
  storage.write("tank", widget.tank)
  storage.write("calib", widget.calib)
  storage.write("source", widget.source)
  storage.write("baseline", widget.baseline)
  storage.write("fuelLowPct", widget.fuelLowPct)
  storage.write("fuelLowFile", widget.fuelLowFile)
  storage.write("fuelCriticalPct", widget.fuelCriticalPct)
  storage.write("fuelCriticalFile", widget.fuelCriticalFile)
end

-- ------------------------------------------------------------------
-- core calculation
-- ------------------------------------------------------------------
local function computePct(widget)
  if not widget.source then return nil end
  local raw = widget.source:value()
  if type(raw) ~= "number" then return nil end

  local calib = widget.calib / 1000.0
  local usedML = (raw - widget.baseline) * calib
  if usedML < 0 then usedML = 0 end

  local remainML = widget.tank - usedML
  if remainML < 0 then remainML = 0 end

  local pct = 0
  if widget.tank > 0 then
    pct = remainML / widget.tank * 100
  end
  if pct > 100 then pct = 100 end

  return pct
end

-- ------------------------------------------------------------------
-- checkCallout(): edge-triggered threshold callout with hysteresis.
-- Fires (plays the configured file) the first time pct drops to/below
-- threshold; re-arms once pct rises back above threshold+hysteresis.
-- ------------------------------------------------------------------
local function checkCallout(pct, threshold, file, fired)
  if not file then return fired end
  if not fired and pct <= threshold then
    system.playFile(file)
    return true
  elseif fired and pct > (threshold + CALLOUT_HYSTERESIS) then
    return false
  end
  return fired
end

-- ------------------------------------------------------------------
-- wakeup(): throttled to refreshRate; only invalidates on real change
-- ------------------------------------------------------------------
local function wakeup(widget)
  local now = os.clock()
  local enforce = widget.updateNextWakeup
  if not enforce and (now < widget.timestamp + refreshRate) then
    return
  end
  widget.timestamp = now

  local pct = computePct(widget)
  local pctInt = pct and math.floor(pct + 0.5) or nil

  if pct ~= nil then
    widget.fuelLowFired = checkCallout(pct, widget.fuelLowPct, widget.fuelLowFile, widget.fuelLowFired)
    widget.fuelCriticalFired = checkCallout(pct, widget.fuelCriticalPct, widget.fuelCriticalFile, widget.fuelCriticalFired)
  end

  if enforce or pctInt ~= widget.lastPctInt then
    widget.pct = pct
    widget.lastPctInt = pctInt
    lcd.invalidate()
  end

  if enforce then widget.updateNextWakeup = false end
end

-- ------------------------------------------------------------------
-- paint()
-- ------------------------------------------------------------------
local function paint(widget)
  local w, h = widget.width or 0, widget.height or 0

  if not widget.source then
    lcd.font(labelFont)
    lcd.color(lcd.RGB(255, 60, 60))
    lcd.drawText(w / 2, h / 2, "No sensor set", TEXT_CENTERED)
    return
  end

  local pct = widget.pct
  if pct == nil then
    lcd.font(labelFont)
    lcd.color(lcd.RGB(255, 150, 0))
    lcd.drawText(w / 2, h / 2, "No data", TEXT_CENTERED)
    return
  end

  -- current fuel state drives both background and text/bar color;
  -- based directly on the live percentage, not on callout fired state
  local bgColor, fgColor
  if pct <= widget.fuelCriticalPct then
    bgColor = lcd.RGB(200, 0, 0)     -- red
    fgColor = lcd.RGB(255, 255, 255) -- white text for contrast on red
  elseif pct <= widget.fuelLowPct then
    bgColor = lcd.RGB(230, 200, 0)   -- yellow
    fgColor = lcd.RGB(0, 0, 0)       -- black text for contrast on yellow
  else
    bgColor = nil                    -- normal: leave theme background as-is
    fgColor = lcd.RGB(0, 170, 0)     -- green
  end

  if bgColor then
    lcd.color(bgColor)
    lcd.drawFilledRectangle(0, 0, w, h)
  end

  -- big percentage figure
  lcd.font(valueFont)
  lcd.color(fgColor)
  local textY = math.floor(h / 2) - 20
  lcd.drawText(w / 2, textY, string.format("%d%%", math.floor(pct + 0.5)), TEXT_CENTERED)

  -- slim gauge bar underneath
  local barX, barY = 4, math.floor(h * 0.72)
  local barW, barH = w - 8, math.max(8, math.floor(h * 0.16))
  lcd.color(lcd.RGB(90, 90, 90))
  lcd.drawRectangle(barX, barY, barW, barH)
  local fillW = math.floor((barW - 2) * (pct / 100))
  if fillW > 0 then
    lcd.color(fgColor)
    lcd.drawFilledRectangle(barX + 1, barY + 1, fillW, barH - 2)
  end
end

-- ------------------------------------------------------------------
-- menu(): long-press action list on the widget
-- ------------------------------------------------------------------
local function menu(widget)
  local menuData = {}
  if widget.source then
    table.insert(menuData, {
      "Mark tank full",
      function()
        local raw = widget.source:value()
        if type(raw) == "number" then
          widget.baseline = raw
          storage.write("baseline", widget.baseline)
          widget.fuelLowFired = false
          widget.fuelCriticalFired = false
          widget.updateNextWakeup = true
        end
      end
    })
  end
  return menuData
end

-- ------------------------------------------------------------------
-- registration
-- ------------------------------------------------------------------
local function init()
  system.registerWidget({
    key = "fuelpct",
    name = name(),
    create = create,
    build = build,
    configure = configure,
    paint = paint,
    wakeup = wakeup,
    read = read,
    write = write,
    menu = menu,
  })
end

return { init = init }