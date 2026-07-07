/*
 * Modulino I2C Address Changer — deterministic, one module per run.
 *
 * Renumbers ONE Modulino Buttons module from CURRENT_ADDR to NEW_ADDR.
 * No auto-assignment: a flaky Qwiic connector makes an occupied address
 * look free, so the target is always set explicitly below.
 *
 * FROM-SCRATCH ROUTINE for the 3-module retro-console (full steps in
 * README.md). One Buttons module attached at a time, joystick may stay:
 *
 *   Run 1:  NEW_ADDR = 0x3F   → that module becomes Buttons #2
 *   Run 2:  NEW_ADDR = 0x40   → that module becomes Buttons #3
 *   The untouched third module stays 0x3E and is Buttons #1.
 *
 * Then FLASH SOMETHING ELSE (the bus-scanner app or game-console) before
 * rebuilding the full chain: this sketch re-runs on every MCU reset for as
 * long as it sits in flash.
 *
 * Monitor output shows the bus before/after and the verdict. LED feedback
 * on the module:
 *   all three blinking  → success (or already at target)
 *   only LED 0 blinking → failed / refused — read the Monitor
 *   no LEDs at all      → no module answered — check the connectors
 *
 * After a success, unplug/replug the module: if the blinking RESUMES, the
 * new address persisted across the power-cycle.
 *
 * Safety guards (what makes re-runs and stray resets harmless):
 *   - target already occupied AND source present  → refuses, changes nothing
 *   - module already at target, none at source    → reports done, no write
 *   - nothing at source                           → reports failure, no write
 *
 * Works for other module types too — set CURRENT_ADDR / NEW_ADDR. Defaults
 * (7-bit, pinstrap = value × 2): Buttons 0x3E, Joystick 0x2C, Buzzer 0x1E,
 * Smartleds 0x36, Vibro 0x38, Opto Relay 0x14, Encoder 0x3B/0x3A.
 * Distance / Thermo / Movement are hardware-fixed and cannot be changed.
 */

#include <Wire.h>
#include <Modulino.h>

// ---- Edit per run -----------------------------------------------------------
constexpr uint8_t CURRENT_ADDR = 0x3E;  // factory default (Buttons)
constexpr uint8_t NEW_ADDR     = 0x3F;  // run 1 (#2): 0x3F  |  run 2 (#3): 0x40
// ------------------------------------------------------------------------------

void scanBus() {
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
}

bool present(uint8_t addr) {
  Wire1.requestFrom(addr, (uint8_t)1);
  bool found = Wire1.available() > 0;
  while (Wire1.available()) Wire1.read();
  return found;
}

void blinkForever(uint8_t addr, bool ok) {
  ModulinoButtons buttons(addr);
  buttons.begin();
  while (true) {
    buttons.setLeds(ok, ok, ok);
    delay(250);
    buttons.setLeds(!ok, false, false);
    delay(250);
  }
}

void setup() {
  Serial.begin(115200);
  while (!Serial && millis() < 5000) {}
  Wire1.begin();
  delay(600);
  Modulino.begin();

  Serial.println("Bus before:");
  scanBus();

  bool srcHere = present(CURRENT_ADDR);
  bool dstHere = present(NEW_ADDR);

  if (dstHere && !srcHere) {
    Serial.println("Already at target — nothing to do.");
    blinkForever(NEW_ADDR, true);
  }
  if (dstHere && srcHere) {
    Serial.println("REFUSING: target address already in use by another module.");
    Serial.println("Detach the module that owns it (or pick another NEW_ADDR).");
    blinkForever(CURRENT_ADDR, false);
  }
  if (!srcHere) {
    Serial.println("FAILED: no module at CURRENT_ADDR. Check the Qwiic");
    Serial.println("connectors — they need a firm click on both ends.");
    blinkForever(CURRENT_ADDR, false);
  }

  // Modulino address-change frame: 'C' 'F' <newAddr*2>, padded to 40 bytes.
  uint8_t data[40] = { 'C', 'F', static_cast<uint8_t>(NEW_ADDR * 2) };
  Wire1.beginTransmission(CURRENT_ADDR);
  Wire1.write(data, 40);
  Wire1.endTransmission();
  delay(500);

  bool ok = present(NEW_ADDR);
  Serial.println(ok ? "SUCCESS — unplug/replug the module; if the blinking"
                      "\nresumes, the new address persisted."
                    : "FAILED: no response at the new address.");
  Serial.println("Bus after:");
  scanBus();

  blinkForever(ok ? NEW_ADDR : CURRENT_ADDR, ok);
}

void loop() {}
