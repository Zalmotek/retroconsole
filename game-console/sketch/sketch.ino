/*
 * Modulino Gamepad — MCU-side sketch.
 *
 * Reads Modulino Joystick (0x2C) + three Modulino Buttons (0x3E, 0x3F, 0x40)
 * over I2C/Qwiic and pushes the combined gamepad state to Linux via Bridge
 * at ~60 Hz.
 *
 * Only the two EXTERIOR buttons (indices 0 and 2) of each module are wired
 * into the gamepad — the three buttons sit too close together for the middle
 * one to be usable. Three modules × 2 buttons = the 6 actions we need.
 *
 * Buttons #2 and #3 must already be at 0x3F / 0x40 — run modulino-i2c-changer
 * once per extra module before this sketch will see them.
 */

#include <Modulino.h>

ModulinoJoystick joystick;
ModulinoButtons  buttons1(0x3E);  // A, B          (exterior pair)
ModulinoButtons  buttons2(0x3F);  // X, Y          (exterior pair)
ModulinoButtons  buttons3(0x40);  // Start, Select (exterior pair)

bool linuxReady = false;

void setup() {
  Modulino.begin();
  joystick.begin();
  buttons1.begin();
  buttons2.begin();
  buttons3.begin();

  Bridge.begin();
}

void loop() {
  if (!linuxReady) {
    bool result = false;
    Bridge.call("linux_started").result(result);
    linuxReady = result;
    if (!linuxReady) {
      delay(500);
      return;
    }
  }

  joystick.update();
  buttons1.update();
  buttons2.update();
  buttons3.update();

  int  x    = joystick.getX();         // -128..+127
  int  y    = joystick.getY();
  bool jBtn = joystick.isPressed();

  bool a     = buttons1.isPressed(0);
  bool b     = buttons1.isPressed(2);
  bool xBtn  = buttons2.isPressed(0);
  bool yBtn  = buttons2.isPressed(2);
  bool start = buttons3.isPressed(0);
  bool sel   = buttons3.isPressed(2);

  // Visual feedback: light each LED while its button is held (middle unused).
  buttons1.setLeds(a, false, b);
  buttons2.setLeds(xBtn, false, yBtn);
  buttons3.setLeds(start, false, sel);

  Bridge.notify("gamepad_state", x, y, jBtn, a, b, start, xBtn, yBtn, sel);

  delay(16);  // ~60 Hz
}
