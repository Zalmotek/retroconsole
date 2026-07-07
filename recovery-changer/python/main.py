"""
No-op Linux-side companion for modulino-i2c-changer.

The address change happens entirely on the MCU. This file exists only so
Arduino App Lab is happy with the project structure.
"""

import time

from arduino.app_utils import App


def loop():
    time.sleep(60)


App.run(user_loop=loop)
