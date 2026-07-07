#!/usr/bin/env python3
"""
Modulino Gamepad — host-side daemon.

Subscribes to the Arduino Router (/run/arduino-router.sock) for `gamepad_state`
notifications coming from the MCU sketch, and emits Linux input events on a
virtual uinput device that RetroArch picks up via udev autoconfig.

Runs on the Uno Q's host (outside the App Lab Docker container) because the
container has no /dev/uinput access.
"""

import time

import uinput
from arduino.app_utils.bridge import Bridge

# Joystick analog dead zone (raw values are roughly -100..+100).
DEAD_ZONE = 25

EVENTS = (
    uinput.BTN_DPAD_UP,
    uinput.BTN_DPAD_DOWN,
    uinput.BTN_DPAD_LEFT,
    uinput.BTN_DPAD_RIGHT,
    uinput.BTN_A,
    uinput.BTN_B,
    uinput.BTN_X,
    uinput.BTN_Y,
    uinput.BTN_START,
    uinput.BTN_SELECT,
    uinput.BTN_TL,  # joystick press → L1
)

device = uinput.Device(EVENTS, name="Modulino Gamepad", vendor=0x2341, product=0xC001)

state = {e: 0 for e in EVENTS}
_event_count = 0


def _emit(evt, value):
    if state[evt] != value:
        device.emit(evt, value, syn=False)
        state[evt] = value


_last_print = (None,) * 9


def on_gamepad_state(x, y, j_btn, a, b, start, x_btn, y_btn, sel):
    global _last_print
    snapshot = (x // 10, y // 10, j_btn, a, b, start, x_btn, y_btn, sel)
    if snapshot != _last_print:
        _last_print = snapshot
        print(f"x={x} y={y} J={int(j_btn)} A={int(a)} B={int(b)} S={int(start)} X={int(x_btn)} Y={int(y_btn)} SEL={int(sel)}", flush=True)

    # Axes swapped to match the DSI panel mount orientation: the stick's
    # x axis drives up/down and the y axis drives left/right.
    _emit(uinput.BTN_DPAD_LEFT,  1 if y < -DEAD_ZONE else 0)
    _emit(uinput.BTN_DPAD_RIGHT, 1 if y >  DEAD_ZONE else 0)
    _emit(uinput.BTN_DPAD_UP,    1 if x < -DEAD_ZONE else 0)
    _emit(uinput.BTN_DPAD_DOWN,  1 if x >  DEAD_ZONE else 0)

    # A/B come from Modulino #2 (x_btn/y_btn) and X/Y from Modulino #1 (a/b):
    # the two button modules are swapped relative to the sketch's wiring.
    _emit(uinput.BTN_A,      int(bool(x_btn)))
    _emit(uinput.BTN_B,      int(bool(y_btn)))
    _emit(uinput.BTN_START,  int(bool(start)))
    _emit(uinput.BTN_X,      int(bool(a)))
    _emit(uinput.BTN_Y,      int(bool(b)))
    _emit(uinput.BTN_SELECT, int(bool(sel)))
    _emit(uinput.BTN_TL,     int(bool(j_btn)))

    device.syn()


def linux_started() -> bool:
    return True


def main():
    Bridge.provide("linux_started", linux_started)
    Bridge.provide("gamepad_state", on_gamepad_state)
    print("Modulino Gamepad daemon ready", flush=True)
    while True:
        time.sleep(3600)


if __name__ == "__main__":
    main()
