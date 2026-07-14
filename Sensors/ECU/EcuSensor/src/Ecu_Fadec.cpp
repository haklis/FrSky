#include "Ecu_Fadec.h"
#include <Sport.h>

// 32-bit accumulator for total fuel consumption
uint32_t pumpTotalAccum = 0;

// Constructor
Ecu_Fadec::Ecu_Fadec() {
    sensorECUStatus     = new SimpleSPortSensor(0x5100);   // DIY #1 (status)
    sensorEGT           = new SimpleSPortSensor(0x0400);
    sensorRPM           = new SimpleSPortSensor(0x0500);
    sensorCurrent       = new SimpleSPortSensor(0x0200);
    sensorBattVoltage   = new SimpleSPortSensor(0x0900);
    sensorPumpVoltage   = new SimpleSPortSensor(0x0910);

    // NEW: DIY #2 — total fuel consumption (slow-growing 16-bit)
    sensorPumpTotal     = new SimpleSPortSensor(0x5101);
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

    // NEW: register total fuel consumption sensor
    hub.registerSensor(*sensorPumpTotal);
}

void Ecu_Fadec::handle() {
    while(Serial.available()) {
        byte newVal = Serial.read();
        if(newVal == 253 && ecuPrev == 252) { // New frame
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
}

void Ecu_Fadec::enableSensors(bool enabled) {
    sensorEGT->enabled         = enabled;
    sensorRPM->enabled         = enabled;
    sensorCurrent->enabled     = enabled;
    sensorBattVoltage->enabled = enabled;
    sensorPumpVoltage->enabled = enabled;
    sensorECUStatus->enabled   = enabled;
    sensorPumpTotal->enabled   = enabled;   // NEW
}

void Ecu_Fadec::SendKeyCode() {
    if(terminalKey == 0) {
        return;
    }

    delay(2);

    byte data[26];
    data[0] = 0xDE;
    data[1] = 0xDF;
    data[2] = 0x70;

    for(int i = 5; i < 25; i++) {
        data[i] = 0;
    }

    data[25] = 0xFF;

    if(terminalKey == 1) { data[3] = 0x42; data[4] = 0xB2; }
    else if(terminalKey == 2) { data[3] = 0x41; data[4] = 0xB1; }
    else if(terminalKey == 3) { data[3] = 0x43; data[4] = 0xB3; }
    else if(terminalKey == 4) { data[3] = 0x44; data[4] = 0xB4; }

    Serial.write(data, 26);
    terminalKey = 0;
}

void Ecu_Fadec::HandleXicoyFrame() {
    digitalWrite(LED_BUILTIN, HIGH);

    int keyByte = 35;
    int key = ecuBuffer[keyByte];

    for(int i = 2; i < 50; i++) {
        byte val = 255 - ecuBuffer[i] + key;
        if(val > 255) val -= 255;
        ecuBuffer[i] = val;
    }

    for(int i = 0; i < 32; i++) {
        terminalDisplay[i] = ecuBuffer[i + 2];
    }

    uint8_t status = 36;
    char *d = terminalDisplay;

    if      (strncmp(d, "Tri", 3) == 0) status = 1;
    else if (strncmp(d, "Rea", 3) == 0) status = 3;
    else if (strncmp(d, "Ign", 3) == 0) status = 4;
    else if (strncmp(d, "Pre", 3) == 0) status = 5;
    else if (strncmp(d, "Bur", 3) == 0) status = 26;
    else if (strncmp(d, "Sta", 3) == 0) status = 14;
    else if (strncmp(d, "Swi", 3) == 0) status = 28;
    else if (strncmp(d, "Fue", 3) == 0) status = 6;
    else if (strncmp(d, "Run-", 4) == 0) status = 33;
    else if (strncmp(d, "Run M", 5) == 0) status = 34;
    else if (strncmp(d, "Run", 3) == 0) status = 33;
    else if (strncmp(d, "Coo", 3) == 0) status = 31;
    else if (strncmp(d, "Sto", 3) == 0) status = 58;

    else if (strncmp(d, "Hig", 3) == 0) status = 0;
    else if (strncmp(d, "Low", 3) == 0) status = 18;
    else if (strncmp(d, "Fla", 3) == 0) status = 25;
    else if (strncmp(d, "Res", 3) == 0) status = 19;
    else if (strncmp(d, "Bat", 3) == 0) status = 22;
    else if (strncmp(d, "Tim", 3) == 0) status = 23;
    else if (strncmp(d, "Ove", 3) == 0) status = 24;
    else if (strncmp(d, "Ign F", 5) == 0) status = 25;
    else if (strncmp(d, "Pum", 3) == 0) status = 30;
    else if (strncmp(d, "Fai", 3) == 0) status = 17;
    else if (strncmp(d, "RXP", 3) == 0) status = 20;
    else if (strncmp(d, "Use", 3) == 0) status = 16;
    else if (strncmp(d, "Re", 2) == 0)  status = 35;
    else if (strncmp(d, "No ", 3) == 0) status = 36;

    sensorECUStatus->value = status;

    sensorEGT->value         = ecuBuffer[45] * 4;
    sensorRPM->value         = (ecuBuffer[48] + (ecuBuffer[49] * 0x100)) * 100;
    sensorCurrent->value     = (ecuBuffer[38] + (ecuBuffer[37] * 0x100)) / 100;
    sensorBattVoltage->value = ecuBuffer[46] * 6;
    sensorPumpVoltage->value = ecuBuffer[42] * 6;

    // NEW: integrate raw pumpVoltage (byte 42)
    pumpTotalAccum += ecuBuffer[42];

    // NEW: slow-growing 16-bit output (divide by 32 for overflow margin)
    sensorPumpTotal->value = pumpTotalAccum >> 5;
}
