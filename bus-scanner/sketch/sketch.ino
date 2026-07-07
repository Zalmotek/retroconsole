/*
 * Qwiic / Wire1 I2C bus scanner — prints every ACKing address to the
 * Monitor every 2 seconds. Harmless to leave running; also useful to
 * "disarm" the MCU after running an address-changer sketch.
 *
 * Healthy retro-console chain: 0x2C (Joystick), 0x3E (Buttons #1),
 * 0x3F (Buttons #2), 0x40 (Buttons #3).
 */

#include <Wire.h>

void setup() {
  Serial.begin(115200);
  while (!Serial && millis() < 5000) {}
  Wire1.begin();
  delay(600);
}

void loop() {
  Serial.println("Scanning Wire1 (Qwiic)...");
  int found = 0;
  for (uint8_t a = 0x08; a <= 0x77; a++) {
    Wire1.beginTransmission(a);
    if (Wire1.endTransmission() == 0) {
      Serial.print("  ACK at 0x");
      Serial.println(a, HEX);
      found++;
    }
  }
  if (!found) Serial.println("  nothing found");
  Serial.println();
  delay(2000);
}
