/*
 * Modulino Gamepad — MCU-side sketch (TEST MODE)
 *
 * Testing with Joystick + Buttons #1 only. Buttons #2 and #3 are stubbed
 * to false until the extra modules' I2C addresses are changed from 0x7C
 * to 0x7D / 0x80 via the modulino-i2c-changer sketch. The full sketch
 * lives in game-console/sketch/sketch.ino.
 *
 * Sends gamepad state to Linux via Bridge at ~60Hz.
 */

#include <Modulino.h>

ModulinoJoystick joystick;
ModulinoButtons  buttons1;  // 0x7C — A, B, Start

bool linuxReady = false;

void setup() {
  Modulino.begin();
  joystick.begin();
  buttons1.begin();

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

  int  x    = joystick.getX();         // -128..+127
  int  y    = joystick.getY();
  bool jBtn = joystick.isPressed();

  bool a     = buttons1.isPressed(0);
  bool b     = buttons1.isPressed(1);
  bool start = buttons1.isPressed(2);

  // Buttons #2 stubbed for now
  Bridge.notify("gamepad_state", x, y, jBtn, a, b, start, false, false, false);

  delay(16);  // ~60 Hz
}
