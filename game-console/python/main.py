"""
Modulino Gamepad — Linux-side daemon.

Registers Bridge handlers so the MCU sketch can:
  - call `linux_started`  → returns True once we're ready
  - notify `gamepad_state` → push an input event for RetroArch

For now this just logs every event so we can confirm the data flow.
uinput virtual gamepad will be added once we see the prints.
"""

import time

from arduino.app_utils import App, Bridge


def linux_started() -> bool:
    return True


def on_gamepad_state(x, y, j_btn, a, b, start, x_btn, y_btn, sel):
    print(
        f"GAMEPAD x={x:>4} y={y:>4} J={int(j_btn)} "
        f"A={int(a)} B={int(b)} START={int(start)} "
        f"X={int(x_btn)} Y={int(y_btn)} SEL={int(sel)}",
        flush=True,
    )


Bridge.provide("linux_started", linux_started)
Bridge.provide("gamepad_state", on_gamepad_state)


def loop():
    time.sleep(1)


App.run(user_loop=loop)
