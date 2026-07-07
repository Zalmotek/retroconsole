#!/bin/bash
# Kiosk boot watchdog.
#
# On the DSI panel, lightdm intermittently launches Xorg but then fails to
# connect to it ("Error connecting to XServer :0") and wedges: Xorg is up on
# vt7 but no autologin session starts, so the screen stays black with no
# RetroArch. It does not self-recover. The race is worsened when the App Lab
# Python container spins up during boot (Run-at-startup) and competes for I/O
# in the X-init window.
#
# Restarting lightdm reliably recovers it. This watchdog waits for RetroArch
# to appear; if it doesn't, it restarts lightdm, up to a few attempts.
set -u

for attempt in 1 2 3; do
    for _ in $(seq 1 5); do
        sleep 5
        if pgrep -x retroarch >/dev/null; then
            logger -t kiosk-watchdog "RetroArch up (attempt ${attempt})"
            exit 0
        fi
    done
    logger -t kiosk-watchdog "no RetroArch after 25s; restarting lightdm (attempt ${attempt})"
    systemctl restart lightdm
done

logger -t kiosk-watchdog "gave up after 3 lightdm restarts"
exit 1
