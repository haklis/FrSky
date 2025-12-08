local sensors_extended = {
    {appId=0x4400, name="EGT", unit=UNIT_DEGREE, min=-100},
    {appId=0x4401, name="RPM", unit=UNIT_RPM, max=999999},
    {appId=0x4402, name="ECU Thr", unit=UNIT_PERCENT},
    {appId=0x4403, name="ECU Batt", unit=UNIT_VOLT, decimals=1},
    {appId=0x4404, name="Pump RPM", decimals=1},
    {appId=0x4405, name="Fuel Left", unit=UNIT_PERCENT},
    {appId=0x4406, name="ECU Status"}
}

local sensors_extended_gearboxrpm = {
    {appId=0x4414, name="Gearbox RPM", unit=UNIT_RPM}
}

local sensors_extended_gearboxtemp = {
    {appId=0x4415, name="Gearbox Temp", unit=UNIT_DEGREE, min=-100}
}

local sensors_maximum = {
    {appId=0x440B, name="Serial Number"},
    {appId=0x440C, name="ECU Batt used", unit=UNIT_MILLIAMPERE_HOUR},
    {appId=0x440D, name="Engine Time", unit=UNIT_SECOND},
    {appId=0x440E, name="Pump Current", unit=UNIT_AMPERE, decimals=1}
}

local sensors_hub = {
    {appId=0x4407, name="HUB Temp", unit=UNIT_DEGREE, min=-100},
    {appId=0x4408, name="HUB Pressure", unit=UNIT_BAR, decimals=3},
    {appId=0x4409, name="HUB Altitude", unit=UNIT_METER},
    {appId=0x440A, name="Fuel Flow", unit=UNIT_MILLILITER_PER_MINUTE}
}

local sensors_basic = {
    {appId=0x0400, name="EGT", unit=UNIT_DEGREE, min=-100},
    {appId=0x0500, name="RPM", unit=UNIT_RPM, max=999999},
    {appId=0x0A20, name="ECU Thr", unit=UNIT_PERCENT},
    {appId=0x0900, name="ECU Batt", unit=UNIT_VOLT, decimals=2},
    {appId=0x0910, name="Pump RPM", decimals=1},
    {appId=0x0A10, name="Fuel Left", unit=UNIT_PERCENT},
    {appId=0x0410, name="ECU Status"}
}

local sensors_basic_gearboxrpm = {
    {appId=0x0A30, name="Gearbox RPM", unit=UNIT_RPM}
}

local msg_table_xicoy = {
    [0]  = "HighTemp",
    [1]  = "Trim Low",
    [2]  = "SetIdle!",
    [3]  = "Ready",
    [4]  = "Ignition",
    [5]  = "FuelRamp",
    [6]  = "Glow Test",
    [7]  = "Running",
    [8]  = "Stop",
    [9]  = "FlameOut",
    [10] = "SpeedLow",
    [11] = "Cooling",
    [12] = "Ignit.Bad",
    [13] = "Start.Fail",
    [14] = "AccelFail",
    [15] = "Start On",
    [16] = "UserOff",
    [17] = "Failsafe",
    [18] = "Low RPM",
    [19] = "Reset",
    [20] = "RXPwFail",
    [21] = "PreHeat",
    [22] = "Battery!",
    [23] = "Time Out",
    [24] = "Overload",
    [25] = "Ign.Fail",
    [26] = "Burner On",
    [27] = "Starting",
    [28] = "SwitchOv",
    [29] = "Cal.Pump",
    [30] = "PumpLimi",
    [31] = "NoEngine",
    [32] = "PwrBoost",
    [33] = "Run-Idle",
    [34] = "Run-Max ",
    [35] = "Restart ",
    [36] = "No Status",
    [37] = "NO SENSOR",
    [100] = "NO ECU"
}	

local TELETYPE_NONE = 0
local TELETYPE_ADAPTER = 1
local TELETYPE_HUBPRO = 2

local ENGINETYPE_JET = 0
local ENGINETYPE_HELI = 1
local ENGINETYPE_TP = 2

local OPTION_BASIC = 0
local OPTION_EXTENDED = 1
local OPTION_MAXIMUM = 2

local function stat_paint(widget)
    local w, h = lcd.getWindowSize()

    local id = 0x4406

    if (widget.teletype == TELETYPE_HUBPRO and widget.option == OPTION_BASIC) then
        id = 0x0410
    end

    local statMsg = "NO SENSOR"
    local src = system.getSource({category=CATEGORY_TELEMETRY, appId=id})

    if src ~= nil then
        statMsg = "NO DATA"
        
        local value = src:value()
        if value ~= nil then
            statMsg = msg_table_xicoy[value]
        end
    end

	lcd.font(FONT_XL)
	lcd.drawText(w/2, h/2 - 20, statMsg, CENTERED )
end

local function newSensor(sensorConfig)
    local sensor = model.createSensor()
    sensor:appId(sensorConfig.appId)
    if sensorConfig.unit ~= nil then sensor:unit(sensorConfig.unit) end
    if sensorConfig.decimals ~= nil then sensor:decimals(sensorConfig.decimals) end

    return sensor
end

local function updateSensor(sensor, sensorConfig, id)
    sensor:name(sensorConfig.name)
    sensor:physId(id - 1) --offset fix

    if sensorConfig.unit ~= nil then sensor:protocolUnit(sensorConfig.unit) end
    if sensorConfig.min ~= nil then sensor:minimum(sensorConfig.min) end
    if sensorConfig.max ~= nil then sensor:maximum(sensorConfig.max) end
    if sensorConfig.decimals ~= nil then sensor:protocolDecimals(sensorConfig.decimals) end
end

local function ensureSensors(sensors, id)
    for _, sensorConfig in pairs(sensors) do
        local sensor = system.getSource({category=CATEGORY_TELEMETRY, appId=sensorConfig.appId})

        if not sensor then
            sensor = newSensor(sensorConfig)
        end

        updateSensor(sensor, sensorConfig, id)
    end
end

local function checkSensors(widget)
    if widget.teletype == TELETYPE_NONE then return
    elseif widget.teletype == TELETYPE_ADAPTER then
        ensureSensors(sensors_extended, widget.id)
        if widget.enginetype == ENGINETYPE_TP then 
            ensureSensors(sensors_extended_gearboxrpm, widget.id) 
            ensureSensors(sensors_extended_gearboxtemp, widget.id) 
        end
    elseif widget.teletype == TELETYPE_HUBPRO then
        if widget.option == OPTION_BASIC then
            ensureSensors(sensors_basic, widget.id)
            if widget.enginetype ~= ENGINETYPE_JET then 
                ensureSensors(sensors_basic_gearboxrpm, widget.id) 
            end
        else
            ensureSensors(sensors_extended, widget.id)
            ensureSensors(sensors_hub, widget.id)
            
            if widget.option == OPTION_MAXIMUM then
                ensureSensors(sensors_maximum, widget.id)
            end
            if widget.enginetype ~= ENGINETYPE_JET then
                ensureSensors(sensors_extended_gearboxrpm, widget.id) 
            end
        end
    end
end

local function configure(widget)
    local parameters = {
        -- { name, type, default, value, min, max, suffix, remoteid }
        {"Telemetry type", widget.myForm.addChoiceField, TELETYPE_NONE, widget.teletype, {{"None", TELETYPE_NONE}, {"HubPro", TELETYPE_HUBPRO}, {"Adapter", TELETYPE_ADAPTER}} },
        {"Engine type", widget.myForm.addChoiceField, ENGINETYPE_JET, widget.enginetype, {{"Jet", ENGINETYPE_JET}, {"Heli", ENGINETYPE_HELI}, {"Turboprop", ENGINETYPE_TP}} },
        {"Sensor set", widget.myForm.addChoiceField, OPTION_BASIC, widget.option, {{"Basic", OPTION_BASIC}, {"Extended", OPTION_EXTENDED}, {"Maximum", OPTION_MAXIMUM}} },
        {"Physical Sensor ID", widget.myForm.addNumberField, 12, widget.id, 1, 24 },
    }

    widget.myForm.load(parameters, function(parameter)
        print("parameter changed " .. parameter[1])
        if parameter[1] == parameters[1][1] then widget.teletype = parameter[4] end
        if parameter[1] == parameters[2][1] then widget.enginetype = parameter[4] end
        if parameter[1] == parameters[3][1] then widget.option = parameter[4] end
        if parameter[1] == parameters[4][1] then widget.id = parameter[4] end
    end)
end

local function setDefaults(widget)
    if widget.teletype == nil then widget.teletype = TELETYPE_NONE end
    if widget.enginetype == nil then widget.enginetype = ENGINETYPE_JET end
    if widget.option == nil then widget.option = OPTION_BASIC end
    if widget.id == nil then widget.id = 12 end
end

local function read(widget)
    widget.teletype = storage.read("teletype")
    widget.enginetype = storage.read("enginetype")
    widget.option = storage.read("option")
    widget.id = storage.read("id")

    setDefaults(widget)
end

local function write(widget)
    storage.write("teletype", widget.teletype)
    storage.write("enginetype", widget.enginetype)
    storage.write("option", widget.option)
    storage.write("id", widget.id)

    checkSensors(widget)
end

local function wakeup(widget)
    lcd.invalidate()
end

local function create()
  myForm = dofile("../lib/myForms.lua")

  widget = { myForm=myForm }
  setDefaults(widget)

  return widget
end

local function init()
    system.registerWidget({key="xicoyst", name="Xicoy status", create=create, paint=stat_paint, wakeup=wakeup, configure=configure, read=read, write=write })
end

return {init=init}