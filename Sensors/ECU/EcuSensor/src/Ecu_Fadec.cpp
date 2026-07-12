#include "Ecu_Fadec.h"
//#include "src/Ecu_Fadec.h"
#include <Sport.h>


//SimpleSPortSensor* sensorECUStatus;
Ecu_Fadec::Ecu_Fadec() {
    sensorECUStatus = new SimpleSPortSensor(0x05100);
    sensorEGT = new SimpleSPortSensor(0x0400);
    sensorRPM = new SimpleSPortSensor(0x0500);
    sensorCurrent = new SimpleSPortSensor(0x0200);
    sensorBattVoltage = new SimpleSPortSensor(0x0900);
    sensorPumpVoltage = new SimpleSPortSensor(0x0910);
}

void Ecu_Fadec::begin() {
    Serial.begin(4800);
}

void Ecu_Fadec::registerSensors(SPortHub& hub) {
    hub.registerSensor(*sensorEGT);
    hub.registerSensor(*sensorRPM);
    hub.registerSensor(*sensorCurrent);
    hub.registerSensor(*sensorBattVoltage);
    hub.registerSensor(*sensorPumpVoltage);
    hub.registerSensor(*sensorECUStatus);
}

void Ecu_Fadec::handle() {
    while(Serial.available()) {
        byte newVal = Serial.read();
        if(newVal == 253 && ecuPrev == 252) { //New frame!
            ecuIndex = 1;
            ecuValid = true;
        }

        if(ecuValid) {
            ecuBuffer[ecuIndex] = newVal;

            if(ecuIndex == 49) {
                ecuValid = false;
                SendKeyCode();
                HandleXicoyFrame();
            }

            ecuIndex++;
        }

        ecuPrev = newVal;
    }
};

void Ecu_Fadec::enableSensors(bool enabled) {
    sensorEGT->enabled = enabled;
    sensorRPM->enabled = enabled;
    sensorCurrent->enabled = enabled;
    sensorBattVoltage->enabled = enabled;
    sensorPumpVoltage->enabled = enabled;
    sensorECUStatus->enabled = enabled;
}

void Ecu_Fadec::SendKeyCode() {
    if(terminalKey == 0) {
        return;
    }

    delay(2);

    //Setup key command
    byte data[26];
    data[0] = 0xDE;
    data[1] = 0xDF;
    data[2] = 0x70;

    //Reset all else to 0
    for(int i = 5; i < 25; i++) {
        data[i] = 0;
    }

    data[25] = 0xFF;

    if(terminalKey == 1) { //data down
        data[3] = 0x42;
        data[4] = 0xB2;
    } else if(terminalKey == 2) { //data up
        data[3] = 0x41;
        data[4] = 0xB1;
    } else if(terminalKey == 3) { //menu up
        data[3] = 0x43;
        data[4] = 0xB3;
    } else if(terminalKey == 4) { //menu down
        data[3] = 0x44;
        data[4] = 0xB4;
    }

    Serial.write(data, 26);

    terminalKey = 0;
}

void Ecu_Fadec::HandleXicoyFrame() {
    //Led on indicates data from ECU
    digitalWrite(LED_BUILTIN, HIGH);

    int keyByte = 35;

    //Correct frame bytes
    int key = ecuBuffer[keyByte];

    for(int i = 2; i < 50; i++) {
        byte val = 255 - ecuBuffer[i] + key;

        if(val > 255) {
        val -= 255;
        }

        ecuBuffer[i] = val;
    }

    for(int i = 0; i < 32; i++) { //Create display string
        terminalDisplay[i] = ecuBuffer[i + 2];
    }

    // Try to status decode ECU status from LCD text and map it to a status byte for s.port. 
    // Jet Dashboard compatible status byte values
    // https://github.com/GIB2A/ETHOS-LUA-XICOY-JetCat-KingTech-and-JetMunt
    
    uint8_t status = 36; // Default: "No Status"

    // Jet Dashboard kompatibel dekoding
    if (strncmp(terminalDisplay, "Trim Low", 8) == 0) status = 1;
    else if (strncmp(terminalDisplay, "Ready", 5) == 0) status = 3;
    else if (strncmp(terminalDisplay, "Ignition", 8) == 0) status = 4;
    else if (strncmp(terminalDisplay, "PreHeat", 7) == 0) status = 5;
    else if (strncmp(terminalDisplay, "BurnerOn", 8) == 0 ||
            strncmp(terminalDisplay, "Burner On", 9) == 0) status = 26;
    else if (strncmp(terminalDisplay, "Start On", 8) == 0 ||
            strncmp(terminalDisplay, "StartOn", 7) == 0) status = 14;
    else if (strncmp(terminalDisplay, "SwitchOver", 10) == 0 ||
            strncmp(terminalDisplay, "SwitchOv", 8) == 0) status = 28;
    else if (strncmp(terminalDisplay, "FuelRamp", 8) == 0 ||
            strncmp(terminalDisplay, "Fuel Ramp", 9) == 0) status = 6;
    else if (strncmp(terminalDisplay, "Run-Idle", 8) == 0 ||
            strncmp(terminalDisplay, "Run Idle", 8) == 0 ||
            strncmp(terminalDisplay, "Run IDLE", 8) == 0 ||
            strncmp(terminalDisplay, "RunIdle", 7) == 0) status = 33;
    else if (strncmp(terminalDisplay, "Running", 7) == 0) status = 33;
    else if (strncmp(terminalDisplay, "Run Max", 7) == 0) status = 34;
    else if (strncmp(terminalDisplay, "Stop", 4) == 0) status = 58;
    else if (strncmp(terminalDisplay, "Cooling", 7) == 0 ||
            strncmp(terminalDisplay, "Cool Down", 9) == 0) status = 31;

    // Send status til S.Port
    sensorECUStatus->value = status;


    // rc_puls = ecuBuffer[40];
    // rc_puls += ecuBuffer[41] * 256;


    // throttle = ecuBuffer[44] / 2.55;
    

    // TODO Validate values
 
    sensorEGT->value = ecuBuffer[45] * 4;  // Tested OK
    sensorRPM->value = (ecuBuffer[48] + (ecuBuffer[49] * 0x100)) * 100;  // Tested OK
    sensorCurrent->value = (ecuBuffer[38] + (ecuBuffer[37] * 0x100)) / 100;
    sensorBattVoltage->value = ecuBuffer[46] * 6;
    sensorPumpVoltage->value = ecuBuffer[42] * 6;
}

