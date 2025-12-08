local lcdtools = dofile("../lib/lcdtools.lua")

local function setDefaults(widget)
    if widget.p1 == nil then widget.p1 = 0 end
    if widget.p2 == nil then widget.p2 = 60 end
    if widget.p3 == nil then widget.p3 = 80 end
    if widget.p4 == nil then widget.p4 = 100 end

    if widget.color1 == nil then widget.color1 = lcd.RGB(255,128,0) end
    if widget.color2 == nil then widget.color2 = lcd.RGB(0,255,0) end
    if widget.color3 == nil then widget.color3 = lcd.RGB(255,0,0) end
end

local function create()
  myForm = dofile("../lib/myForms.lua")

  widget = { myForm=myForm }
  setDefaults(widget)

  return widget
end

local function paint(widget)
    --lcd.setWindowTitle("OK", nil)
    local value = 0
    local name = "---"
    if widget.source ~= nil then
        value = widget.source:value()
        name = widget.source:name()
    end

    local w, h = lcd.getWindowSize()

    min = widget.p1
    max = widget.p3

    colorY = 25

    if(widget.p4 > max) then max = widget.p4 end

    lcd.color(lcd.themeColor(0))
    lcd.drawText(10, 0, min, LEFT)
    lcd.drawText(w-10, 0, max, RIGHT)
	
	if value ~= nil then
		lcd.drawText(w/2, 0, name .." (" .. value .. ")", CENTERED)

		--lcd step per value
		delta = w / (max - min)
		
		p2x = (widget.p2 - widget.p1) * delta

		lcd.color(widget.color1)
		lcd.drawFilledRectangle(0,colorY,p2x - 10,h-colorY)
		lcdtools.gradient(p2x - 10, colorY, 20, h-colorY, widget.color1, widget.color2)

		p3x = (widget.p3 - widget.p1) * delta

		lcd.color(widget.color2)
		lcd.drawFilledRectangle(p2x + 10,colorY,p3x - 10,h-colorY)

		if(widget.p4 > widget.p3) then 
			lcdtools.gradient(p3x - 10, colorY, 20, h-colorY, widget.color2, widget.color3)

			p4x = (widget.p4 - widget.p1) * delta
		
			lcd.color(widget.color3)
			lcd.drawFilledRectangle(p3x + 10,colorY,p4x,h-colorY)
		else
			lcd.drawFilledRectangle(p2x + 10,colorY,p3x,h-colorY)
		end

		x = (value  - widget.p1) * delta

		if(x < 0) then 
			x = 0
		elseif(x > w) then
			x = w
		end

		-- Hide upper part
		lcd.color(lcd.themeColor(1))
		lcd.drawFilledRectangle(x, 25, w - x, h - 28)
	end

    -- Draw bar
    -- lcd.color(lcd.themeColor(0))
    -- lcd.drawFilledRectangle(x, 25, 5, h - 25)
    -- lcd.color(lcd.themeColor(1))
    -- lcd.drawFilledRectangle(x+1, 27, 3, h - 29)
end

local function wakeup(widget)
    lcd.invalidate()
end

local function configure(widget)
    local parameters = {
        -- { name, type, default, value, min, max, suffix, remoteid }
        {"Source", widget.myForm.addSourceField, 0, widget.source },
        {"Point 1", widget.myForm.createNumberField, 0, widget.p1, -99999, 99999 },
        {"Color 1 - 2", widget.myForm.addColorField, 0, widget.color1 },
        {"Point 2", widget.myForm.createNumberField, 0, widget.p2, -99999, 99999 },
        {"Color 2 - 3", widget.myForm.addColorField, 0, widget.color2 },
        {"Point 3", widget.myForm.createNumberField, 0, widget.p3, -99999, 99999 },
        {"Color 3 - 4", widget.myForm.addColorField, 0, widget.color3 },
        {"Point 4", widget.myForm.createNumberField, 0, widget.p4, -99999, 99999 },
    }

    widget.myForm.load(parameters, function(parameter)
        print("parameter changed " .. parameter[1])
        if parameter[1] == parameters[1][1] then widget.source = parameter[4] end
        if parameter[1] == parameters[2][1] then widget.p1 = parameter[4] end
        if parameter[1] == parameters[3][1] then widget.color1 = parameter[4] end
        if parameter[1] == parameters[4][1] then widget.p2 = parameter[4] end
        if parameter[1] == parameters[5][1] then widget.color2 = parameter[4] end
        if parameter[1] == parameters[6][1] then widget.p3 = parameter[4] end
        if parameter[1] == parameters[7][1] then widget.color3 = parameter[4] end
        if parameter[1] == parameters[8][1] then widget.p4 = parameter[4] end
    end)
end

local function read(widget)
    widget.source = storage.read("source")

    widget.p1 = storage.read("p1")
    widget.p2 = storage.read("p2")
    widget.p3 = storage.read("p3")
    widget.p4 = storage.read("p4")

    widget.color1 = storage.read("color1")
    widget.color2 = storage.read("color2")
    widget.color3 = storage.read("color3")

    setDefaults(widget)
end

local function write(widget)
    storage.write("source", widget.source)

    storage.write("p1", widget.p1)
    storage.write("p2", widget.p2)
    storage.write("p3", widget.p3)
    storage.write("p4", widget.p4)

    storage.write("color1", widget.color1)
    storage.write("color2", widget.color2)
    storage.write("color3", widget.color3)
end

local function init()
  system.registerWidget({key="gauge", name="Gauge", create=create, paint=paint, wakeup=wakeup, configure=configure, read=read, write=write })
end

return {init=init}