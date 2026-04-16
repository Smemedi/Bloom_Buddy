#include <SoftwareSerial.h>

SoftwareSerial mod(2, 3);

// Write baud rate register 0x0065 to value 0x0002 (4800)
const byte changeBaud[] = {0x01, 0x06, 0x00, 0x65, 0x00, 0x02, 0x18, 0x14};

void setup() {
  Serial.begin(9600);
  mod.begin(9600);
  delay(2000);

  for (int i = 0; i < 5; i++) {
    while (mod.available()) mod.read();
    mod.write(changeBaud, sizeof(changeBaud));
    delay(500);
    Serial.print("Sent "); Serial.println(i + 1);
  }

  Serial.println("Power cycle the light sensor now!");
}

void loop() {}
