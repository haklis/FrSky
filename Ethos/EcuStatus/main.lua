local statusText = {
    [1]="Trim Low",
    [3]="Ready",
    [4]="Ignition",
    [5]="Preheat",
    [6]="Fuel",
    [14]="Start",
    [16]="User",
    [17]="Fail",
    [18]="Low",
    [19]="Reset",
    [20]="RPM",
    [22]="Battery",
    [23]="Timeout",
    [24]="Overtemp",
    [25]="Flameout",
    [26]="Burner",
    [28]="SwitchOv",
    [30]="Pump",
    [31]="Cool",
    [33]="Run",
    [34]="Run Max",
    [35]="Restart",
    [36]="No Status",
    [58]="Stop",
    [0]="High"
}

local colorError = {
    [0]=true,
    [17]=true,
    [18]=true,
    [19]=true,
    [22]=true,
    [23]=true,
    [24]=true,
    [25]=true,
    [30]=true
}

local colorOrange = {
    [4]=true,
    [5]=true,
    [6]=true,
    [14]=true,
    [26]=true,
    [28]=true
}

local colorBlue = {
    [1]=true,
    [31]=true,
    [58]=true
}

local colorGreen = {
    [3]=true,
    [33]=true,
    [34]=true,
    [35]=true
}

local function getColor(code)

    if colorError[code] then
        return COLOR_RED
    end

    if colorOrange[code] then
        return COLOR_ORANGE
    end

    if colorBlue[code] then
        return COLOR_BLUE
    end

    if colorGreen[code] then
        return COLOR_GREEN
    end

    return COLOR_WHITE
end

local function name()
    return "ECU Status"
end

local function create()
    return {
        source = nil,
        code = nil,
        text = "---",
        color = COLOR_WHITE,
        width = 0,
        height = 0
    }
end

local function build(widget)
    widget.width, widget.height = lcd.getWindowSize()
end

local function configure(widget)

    local line = form.addLine("ECU Status Sensor")

    form.addSourceField(
        line,
        nil,
        function()
            return widget.source
        end,
        function(newValue)
            widget.source = newValue
        end
    )
end

local function read(widget)
    widget.source = storage.read("source")
end

local function write(widget)
    storage.write("source", widget.source)
end

local function wakeup(widget)

    if not widget.source then
        return
    end

    local code = widget.source:value()

    if code == nil then
        widget.text = "No Telem"
        widget.color = COLOR_RED
        return
    end

    code = math.floor(code)

    if code ~= widget.code then

        widget.code = code

        widget.text =
            statusText[code]
            or ("Unknown " .. tostring(code))

        widget.color = getColor(code)

        lcd.invalidate()
    end
end

local function paint(widget)

    local w = widget.width
    local h = widget.height

    lcd.font(FONT_XL)
    lcd.color(widget.color)

    lcd.drawText(
        w / 2,
        h / 2,
        widget.text,
        TEXT_CENTERED
    )
end

local function menu(widget)
    return {}
end

local function init()

    system.registerWidget({
        key = "ECUSTAT",
        name = name,
        create = create,
        build = build,
        configure = configure,
        wakeup = wakeup,
        paint = paint,
        read = read,
        write = write,
        menu = menu,
        title = false
    })
end

return { init = init }