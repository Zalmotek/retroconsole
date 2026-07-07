/*
 * RECOVERY address changer — fixes the "all modules at 0x3F" state.
 *
 * Run with EXACTLY ONE Buttons module attached (joystick may stay).
 * Idempotent: safe to re-run / reset with the same module attached.
 *
 *   Run A: NEW_ADDR = 0x3E  → module becomes Buttons #1
 *   Run B: NEW_ADDR = 0x40  → module becomes Buttons #3
 *   The module that stays at 0x3F is Buttons #2 — never run this on it,
 *   and don't plug it in while this sketch is still in MCU flash (any
 *   reset renumbers whatever single 0x3F module it finds).
 *
 * Monitor prints the bus before/after + SUCCESS/FAILED.
 * LEDs on the module: all three blink = success, only LED 0 = failure.
 * After unplug/replug, blinking resumes = the new address persisted.
 */

#include <Wire.h>
#include <Modulino.h>

constexpr uint8_t CURRENT_ADDR = 0x3F;
constexpr uint8_t NEW_ADDR     = 0x3E;   // <-- run A: 0x3E  |  run B: 0x40

void scanBus() {
  for (uint8_t a = 0x08; a <= 0x77; a++) {
    Wire1.beginTransmission(a);
    if (Wire1.endTransmission() == 0) { Serial.print("  ACK 0x"); Serial.println(a, HEX); }
  }
}

bool present(uint8_t addr) {
  Wire1.requestFrom(addr, (uint8_t)1);
  bool found = Wire1.available() > 0;
  while (Wire1.available()) Wire1.read();
  return found;
}

void setup() {
  Serial.begin(115200);
  while (!Serial && millis() < 5000) {}
  Wire1.begin();
  delay(600);
  Modulino.begin();

  Serial.println("Bus before:"); scanBus();

  // Modulino address-change frame: 'C' 'F' <newAddr*2>, padded to 40 bytes.
  uint8_t data[40] = { 'C', 'F', static_cast<uint8_t>(NEW_ADDR * 2) };
  Wire1.beginTransmission(CURRENT_ADDR);
  Wire1.write(data, 40);
  Wire1.endTransmission();
  delay(500);

  bool ok = present(NEW_ADDR);
  Serial.println(ok ? "SUCCESS" : "FAILED");
  Serial.println("Bus after:"); scanBus();

  ModulinoButtons b(ok ? NEW_ADDR : CURRENT_ADDR);
  b.begin();
  while (true) { b.setLeds(ok, ok, ok); delay(250); b.setLeds(!ok, false, false); delay(250); }
}

void loop() {}
