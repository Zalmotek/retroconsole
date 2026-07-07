# Display Setup — Waveshare 8" DSI LCD via Media Carrier

## Enable the panel (native — current method)

The carrier + panel are enabled in software via `arduino-linux-config` (the App
Lab carrier tool) — **no DTB hacking**. A fresh image ships the carrier
**disabled** with `display: none`, so the panel is dark until you run:

```bash
sudo arduino-linux-config carrier enable media-carrier display=8-dsi-touch-a
sudo reboot
```

- `arduino-linux-config carrier list` — show available devices/options
  (`display`: `none, 5-dsi-touch-a, 8-dsi-touch-a, 10-dsi-touch-a`).
- `arduino-linux-config carrier show` — current vs next-boot state.

After reboot the panel is `card0-DSI-1: connected` @ 1280x800, driven by
`panel_jadard_jd9365da_h3` (JD9365). The carrier reroutes the DSI lanes off the
on-board ANX7625, so HDMI-over-USB-C is unavailable while the carrier is enabled
(`carrier disable media-carrier` + remove carrier to use HDMI).

## Hardware Connection

1. Power off the Uno Q
2. Attach the **Uno Media Carrier** via the JMEDIA + JMISC board-to-board connectors
3. Lift the locking tab on the Media Carrier's 22-pin DSI connector
4. Insert the Waveshare display's FPC ribbon cable (contacts facing down)
5. Press the locking tab down to secure

## Boot and Check

Power on. The display may work immediately if the BSP recognizes it.

```bash
# Check DRM/KMS devices
ls /sys/class/drm/

# Look for a connected display
cat /sys/class/drm/card0-DSI-1/status 2>/dev/null

# Check kernel messages for DSI
dmesg | grep -i dsi
dmesg | grep -i panel
```

## If the Display Works

Great — skip to audio setup. RetroArch will use KMS/DRM directly.

Verify with:
```bash
# Should show noise on the display
cat /dev/urandom > /dev/fb0
```

## If the Display Doesn't Work

The Media Carrier officially supports the **Waveshare 8-DSI-TOUCH-A**. The 8" DSI LCD (C) uses the same MIPI-DSI connector but may have a different panel init sequence.

Options:
1. **Check for firmware updates** in Arduino App Lab — newer BSPs may add panel support
2. **Check available DT overlays**: `ls /boot/overlays/ 2>/dev/null || ls /boot/dtbs/`
3. **Use HDMI via USB-C as fallback** — the Uno Q supports DisplayPort Alt-Mode over USB-C, which works with HDMI adapters out of the box

### USB-C HDMI Fallback

If DSI doesn't work, connect a USB-C to HDMI adapter:
```bash
# Display should appear automatically
# Optimal resolution: 1280x720 or 1920x1080
```

## Touch (if DSI works)

The Waveshare capacitive touch controller (Goodix) has a mainline Linux driver:

```bash
# Check if touch device is detected
cat /proc/bus/input/devices | grep -A5 -i touch

# Test
evtest  # select the touch device
```

Touch isn't needed for RetroArch gaming (we use Modulino controls), but it's useful for menu navigation.
