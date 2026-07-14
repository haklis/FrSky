local statusText = {
    [1]="Trim",[3]="Ready",[4]="Ignition",[5]="Preheat",[26]="Burner",
    [14]="Start",[28]="Switch",[6]="Fuel",[33]="Run",[34]="Run Max",
    [31]="Cool",[58]="Stop",[0]="High",[18]="Low",[25]="Flameout",
    [19]="Reset",[22]="Battery",[23]="Timeout",[24]="Overtemp",
    [30]="Pump",[17]="Fail",[20]="RPM",[16]="User",[35]="Restart",
    [36]="No Status"
}

local colorError  = { [0]=true,[18]=true,[25]=true,[19]=true,[22]=true,[23]=true,[24]=true,[30]=true,[17]=true }
local colorOrange = { [4]=true,[5]=true,[26]=true,[14]=true,[28]=true,[6]=true }
local colorBlue   = { [31]=true,[58]=true }
local colorGreen  = { [1]=true,[3]=true,[33]=true,[34]=true,[35]=true }

local function getColor(code)
    if colorError[code]  then return COLOR_RED end
    if colorOrange[code] then return lcd.ORANGE end
    if colorBlue[code]   then return lcd.BLUE end
    if colorGreen[code]  then return lcd.GREEN end
    return COLOR_WHITE
end

local function name(widget)
    return "ECU Status"
end

----------------------------------------------------------------------
-- CREATE: EthOS 2026 script-widget API
----------------------------------------------------------------------

local function create()
    return {
        sensor = nil,
        value  = "---",
        color  = COLOR_WHITE,
    }
end

----------------------------------------------------------------------
-- CONFIGURE: safe, no nil indexing
----------------------------------------------------------------------

local function configure(widget)
    local line = form.addLine("ECU Status Sensor")

    form.addFieldSensor(
        line,
        widget.sensor,
        function() return widget.sensor end,
        function(v)
            widget.sensor = v
            storage.write("ECU_sensor", v)
        end
    )
end

----------------------------------------------------------------------
-- READ / WRITE
----------------------------------------------------------------------

local function read(widget)
    widget.sensor = storage.read("ECU_sensor")
    return true
end

local function write(widget)
    storage.write("ECU_sensor", widget.sensor)
    return true
end

----------------------------------------------------------------------
-- WAKEUP: safe, checks nil before use
----------------------------------------------------------------------

local function wakeup(widget)
    if not widget.sensor then return end

    local val = sport.getSensorValue(widget.sensor)
    if not val then return end

    local code = val.value
    widget.value = statusText[code] or ("Unknown (" .. code .. ")")
    widget.color = getColor(code)

    lcd.invalidate()
end

----------------------------------------------------------------------
-- PAINT: safe, no zone usage
----------------------------------------------------------------------

local function paint(widget)
    lcd.color(widget.color)
    lcd.drawText(0, 0, widget.value, FONT_XXL)
    lcd.color(COLOR_WHITE)
end

local function event(widget, category, value, x, y)
    return true
end

local function menu(widget)
    return {}
end

----------------------------------------------------------------------
-- INIT: EthOS 2026 script-widget registration
----------------------------------------------------------------------

local function init()
    local key = "EcuStat"  -- <= 8 chars

    system.registerWidget({
        key       = key,
        name      = name,
        create    = create,
        configure = configure,
        paint     = paint,
        wakeup    = wakeup,
        read      = read,
        write     = write,
        event     = event,
        menu      = menu,
        persistent = false,
    })
end

return { init = init }
