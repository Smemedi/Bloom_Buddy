#include <SoftwareSerial.h>

SoftwareSerial mod(2, 3);

const byte changeID[] = {0x01, 0x06, 0x07, 0xD0, 0x00, 0x02, 0x08, 0x86};

void setup() {
  Serial.begin(9600);
  mod.begin(4800);
  delay(2000);

  for (int i = 0; i < 5; i++) {
    while (mod.available()) mod.read();
    mod.write(changeID, sizeof(changeID));
    delay(300);
  }
}

void loop() {}
