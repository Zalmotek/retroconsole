#!/usr/bin/env python3
"""
RetroArch rotation watcher.

The Touch A panel runs in native portrait, but the user holds it landscape.
- In the RA *menu* we want Xorg-level rotation (Rotate "left") so the menu
  looks landscape. Menus don't scroll so the Xorg rotation copy pass doesn't
  produce visible tearing.
- During *gameplay* the Xorg rotation copy races the panel scanout and a
  fixed-position tearline appears during horizontal scrolling. So while a
  core is loaded we un-rotate Xorg and let RetroArch rotate inside its own
  swapchain (video_rotation = "3"), which is tear-free.

This script polls RA's network command interface for content/core state and
toggles `xrandr --output DSI-1 --rotate {left,normal}` accordingly.
"""
import socket
import subprocess
import time

HOST = "127.0.0.1"
PORT = 55355
POLL_S = 0.5
OUTPUT = "DSI-1"

_last_rot = None


def xrandr(rotation: str) -> None:
    """Idempotent xrandr rotation change."""
    global _last_rot
    if rotation == _last_rot:
        return
    subprocess.run(
        ["xrandr", "--output", OUTPUT, "--rotate", rotation],
        check=False,
    )
    _last_rot = rotation


def ra_status() -> str | None:
    """Return raw GET_STATUS response, or None if RA isn't listening yet."""
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
            s.settimeout(0.4)
            s.sendto(b"GET_STATUS\n", (HOST, PORT))
            data, _ = s.recvfrom(1024)
            return data.decode(errors="replace").strip()
    except (socket.timeout, OSError):
        return None


def main() -> None:
    # Start in landscape so the menu comes up landscape on session start
    # even before RA finishes initialising.
    xrandr("left")
    while True:
        resp = ra_status()
        # Response looks like:
        #   "GET_STATUS CONTENTLESS"                  -> menu, no core
        #   "GET_STATUS PLAYING <core>,<rom>,<crc>"   -> game running
        #   "GET_STATUS PAUSED <core>,<rom>,<crc>"    -> paused in game
        if resp is None:
            # RA not up yet — keep menu rotation
            xrandr("left")
        elif "CONTENTLESS" in resp or "NONE" in resp:
            xrandr("left")
        else:
            xrandr("normal")
        time.sleep(POLL_S)


if __name__ == "__main__":
    main()
