/*
 * Button checker — prints every press/release to the App Lab Monitor with
 * the gamepad role each button is mapped to in the game-console sketch.
 * Standalone (no Bridge / Linux daemon needed). LEDs mirror presses, same
 * as the gameplay sketch (middle LEDs stay off — middle buttons are unused).
 *
 * Expected chain: Joystick 0x2C, Buttons #1 0x3E, #2 0x3F, #3 0x40.
 * Modules that don't answer at startup are reported and skipped.
 *
 * D-pad directions follow the daemon's convention (axes inverted to match
 * the physical mount): push left on the mounted console → "D-pad LEFT".
 */

#include <Wire.h>
#include <Modulino.h>

constexpr int DEAD_ZONE = 25;  // same as gamepad_daemon.py

struct Pad {
  uint8_t     addr;
  const char *name;
  const char *role[3];
};

Pad pads[3] = {
  { 0x3E, "Buttons #1", { "A",     "(middle, unused)", "B"      } },
  { 0x3F, "Buttons #2", { "X",     "(middle, unused)", "Y"      } },
  { 0x40, "Buttons #3", { "Start", "(middle, unused)", "Select" } },
};

ModulinoButtons  b1(0x3E), b2(0x3F), b3(0x40);
ModulinoButtons *mod[3] = { &b1, &b2, &b3 };
ModulinoJoystick joystick;

bool padAlive[3], joyAlive;
bool lastBtn[3][3];
bool lastJoyBtn = false;
int  lastDirX = 0, lastDirY = 0;

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

  Serial.println("=== Modulino Gamepad button checker ===");
  Serial.println("Mapping: #1 ext = A/B | #2 ext = X/Y | #3 ext = Start/Select");
  Serial.println("Joystick: D-pad; press = L1");
  Serial.println("Hotkeys:  Select+Start = RA menu | Select+L1 = quit game");
  Serial.println();

  joyAlive = present(0x2C);
  Serial.print("Joystick 0x2C: ");
  Serial.println(joyAlive ? "OK" : "MISSING");
  if (joyAlive) joystick.begin();

  for (int p = 0; p < 3; p++) {
    padAlive[p] = present(pads[p].addr);
    Serial.print(pads[p].name);
    Serial.print(" 0x");
    Serial.print(pads[p].addr, HEX);
    Serial.print(": ");
    Serial.println(padAlive[p] ? "OK" : "MISSING");
    if (padAlive[p]) mod[p]->begin();
  }
  Serial.println("\nPress buttons / move the joystick...\n");
}

void loop() {
  for (int p = 0; p < 3; p++) {
    if (!padAlive[p]) continue;
    mod[p]->update();
    for (int i = 0; i < 3; i++) {
      bool cur = mod[p]->isPressed(i);
      if (cur != lastBtn[p][i]) {
        lastBtn[p][i] = cur;
        Serial.print(cur ? "PRESSED  " : "released ");
        Serial.print(pads[p].name);
        Serial.print(" btn ");
        Serial.print(i);
        Serial.print("  ->  ");
        Serial.println(pads[p].role[i]);
      }
    }
    // LED feedback like the gameplay sketch: exterior LEDs follow presses.
    mod[p]->setLeds(lastBtn[p][0], false, lastBtn[p][2]);
  }

  if (joyAlive) {
    joystick.update();
    int  x   = joystick.getX();
    int  y   = joystick.getY();
    bool jb  = joystick.isPressed();
    int  dx  = (x > DEAD_ZONE) ? -1 : (x < -DEAD_ZONE) ? 1 : 0;  // daemon-inverted
    int  dy  = (y > DEAD_ZONE) ? 1 : (y < -DEAD_ZONE) ? -1 : 0;

    if (jb != lastJoyBtn) {
      lastJoyBtn = jb;
      Serial.print(jb ? "PRESSED  " : "released ");
      Serial.println("Joystick button  ->  L1");
    }
    if (dx != lastDirX) {
      lastDirX = dx;
      if (dx) Serial.println(dx < 0 ? "D-pad LEFT" : "D-pad RIGHT");
      else    Serial.println("D-pad X centered");
    }
    if (dy != lastDirY) {
      lastDirY = dy;
      if (dy) Serial.println(dy > 0 ? "D-pad DOWN" : "D-pad UP");
      else    Serial.println("D-pad Y centered");
    }
  }

  delay(16);
}
