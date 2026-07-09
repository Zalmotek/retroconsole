#!/bin/bash
# =============================================================================
# Arduino Uno Q Retro Game Console — Linux-side installer.
#
# Run on the Q itself, AFTER:
#   1. The repo has been cloned to ~/retroconsole
#   2. The MCU sketch + python app from ./game-console/ have been deployed
#      once via Arduino App Lab on the workstation (this brings up the
#      Arduino Router, exposes /run/arduino-router.sock, and creates the
#      python-apps-base Docker container we need to copy from).
#
# What this script does (idempotent — safe to re-run):
#   1.  Install APT packages (RetroArch, libretro cores, python deps, evtest…)
#   2.  Enable the uinput kernel module
#   3.  Copy `arduino.app_utils` Python package out of the App Lab container
#       into /opt/modulino-gamepad/lib so the host daemon can talk to Bridge
#   4.  Install /opt/modulino-gamepad/gamepad_daemon.py + systemd unit
#   5.  Drop the RetroArch udev gamepad autoconfig
#   6.  Create ROM directories under ~/roms/{gb,gbc,gba,nes,snes,genesis}
#   6a. Enable the Media Carrier + DSI panel via arduino-linux-config
#       (default 8-dsi-touch-a, takes effect on reboot; no-op if already
#       enabled; skip with KIOSK_DISPLAY=none for HDMI/bench setups)
#   6c1. Install audio-tune user service (jack per /etc/kiosk-audio-output:
#        headphones = demo console, earpiece = production speaker; select
#        with KIOSK_AUDIO_OUTPUT=earpiece sudo bash setup.sh)
#   7.  Install the RetroArch fullscreen kiosk autostart (.desktop)
#   8.  Append fullscreen + core-path overrides to retroarch.cfg
#   9.  Configure lightdm autologin for the `arduino` user
#  10.  Hide Arduino App Lab from autostart (kiosk doesn't need it)
#  11.  Hide light-locker (no screen lock on the console)
#  12.  Disable Magic SysRq (stray keyboards triggered emergency RO remount)
#  13.  Stop the App Lab Python container (host daemon owns Bridge now)
#
# After a successful run, reboot — the Q autologs `arduino`, RetroArch
# autostarts fullscreen, the gamepad daemon is already running as a service.
# =============================================================================
set -e

echo "============================================"
echo " Arduino Uno Q Retro Console — Linux Setup"
echo "============================================"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARDUINO_USER="${SUDO_USER:-arduino}"
ARDUINO_HOME="$(getent passwd "$ARDUINO_USER" | cut -d: -f6)"
AUTOSTART_DIR="$ARDUINO_HOME/.config/autostart"
PY_SITE="/opt/modulino-gamepad/lib"

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root: sudo bash $0"
    exit 1
fi

run_as_arduino() { sudo -u "$ARDUINO_USER" "$@"; }

# -------- 1. APT packages ----------------------------------------------------
echo "==> Installing APT packages..."
apt-get update
apt-get install -y \
    python3 python3-pip \
    python3-uinput python3-msgpack python3-numpy \
    python3-watchdog python3-yaml python3-aiohttp python3-bcrypt \
    i2c-tools evtest joystick alsa-utils \
    xinput \
    retroarch \
    libretro-gambatte libretro-snes9x libretro-mgba \
    libretro-nestopia libretro-genesisplusgx

# -------- 2. uinput kernel module -------------------------------------------
echo "==> Enabling uinput kernel module..."
modprobe uinput
echo "uinput" > /etc/modules-load.d/uinput.conf

# -------- 3. arduino.app_utils on host --------------------------------------
echo "==> Copying arduino.app_utils into $PY_SITE..."
mkdir -p "$PY_SITE"
if [ ! -d "$PY_SITE/arduino" ]; then
    CID="$(docker ps -a --filter name=game-console-main --format '{{.ID}}' | head -1)"
    if [ -z "$CID" ]; then
        echo "  WARNING: App Lab container not found. Deploy the App Lab project"
        echo "           first, then re-run this step."
    else
        docker cp "$CID:/usr/local/lib/python3.13/site-packages/arduino" \
                  "$PY_SITE/arduino"
    fi
fi

# -------- 4. Gamepad daemon --------------------------------------------------
echo "==> Installing Modulino Gamepad daemon..."
mkdir -p /opt/modulino-gamepad
install -m 0755 "$SCRIPT_DIR/modulino-gamepad/gamepad_daemon.py" /opt/modulino-gamepad/
install -m 0644 "$SCRIPT_DIR/modulino-gamepad/modulino-gamepad.service" /etc/systemd/system/
systemctl daemon-reload
systemctl enable modulino-gamepad

# -------- 5. RetroArch gamepad autoconfig -----------------------------------
echo "==> Installing RetroArch udev gamepad autoconfig..."
RA_AUTOCONFIG="$ARDUINO_HOME/.config/retroarch/autoconfig/udev"
run_as_arduino mkdir -p "$RA_AUTOCONFIG"
install -m 0644 -o "$ARDUINO_USER" -g "$ARDUINO_USER" \
    "$SCRIPT_DIR/retroarch/modulino-gamepad.cfg" "$RA_AUTOCONFIG/"

# -------- 5b. RetroArch UI assets -------------------------------------------
# Debian's retroarch package ships no icon/cursor/font assets, so the menu
# renders as black squares. Pull the official asset bundle from the libretro
# buildbot once per unit (~70 MB).
RA_ASSETS="$ARDUINO_HOME/.config/retroarch/assets"
if [ ! -d "$RA_ASSETS/ozone" ]; then
    echo "==> Downloading RetroArch UI assets..."
    run_as_arduino mkdir -p "$RA_ASSETS"
    TMP_ZIP="$(mktemp /tmp/ra-assets.XXXXXX.zip)"
    chmod 0644 "$TMP_ZIP"
    curl -fsSL -o "$TMP_ZIP" https://buildbot.libretro.com/assets/frontend/assets.zip
    run_as_arduino unzip -oq "$TMP_ZIP" -d "$RA_ASSETS"
    rm -f "$TMP_ZIP"
fi

# -------- 6. ROM directories -------------------------------------------------
echo "==> Creating ROM directories..."
run_as_arduino mkdir -p "$ARDUINO_HOME"/roms/{gb,gbc,gba,nes,snes,genesis}

# -------- 6a. Enable Media Carrier + DSI panel -------------------------------
# A fresh image ships with the carrier disabled -> the panel stays dark and X
# falls back to a 320x200 dummy framebuffer. arduino-linux-config composes the
# carrier+panel DTB for the NEXT boot, so this lands on the same reboot as the
# rest of the setup. Enabling the carrier reroutes the DSI lanes away from the
# ANX7625 bridge, so HDMI-over-USB-C stops working (expected).
# The rotation + touch configs below are specific to the 8" Touch A panel, so
# its name is hard-coded; KIOSK_DISPLAY=none skips this step (HDMI/bench use).
KIOSK_DISPLAY="${KIOSK_DISPLAY:-8-dsi-touch-a}"
if [ "$KIOSK_DISPLAY" != "none" ]; then
    if ! command -v arduino-linux-config >/dev/null 2>&1; then
        echo "  WARNING: arduino-linux-config not found — update the OS via App Lab,"
        echo "           then enable the panel manually:"
        echo "           sudo arduino-linux-config carrier enable media-carrier display=$KIOSK_DISPLAY"
    elif arduino-linux-config carrier show 2>/dev/null | grep -q "$KIOSK_DISPLAY"; then
        echo "==> Media Carrier display already configured ($KIOSK_DISPLAY) — skipping"
    else
        echo "==> Enabling Media Carrier + $KIOSK_DISPLAY panel (takes effect on reboot)..."
        arduino-linux-config carrier enable media-carrier display="$KIOSK_DISPLAY"
    fi
fi

# -------- 6b. Rotate DSI panel into landscape -------------------------------
# Waveshare 8-DSI-TOUCH-A is native 800x1280 portrait. Rotate left in Xorg so
# RetroArch + the desktop come up horizontal (1280x800) on every boot.
echo "==> Installing Xorg DSI rotation + touchscreen calibration..."
# Menus + desktop come up in landscape (Xorg "Rotate left"). The
# ra-rotate-watcher service (installed below) flips to native portrait when
# a game launches so the scanout is tear-free, and back to landscape when
# we return to the menu.
install -m 0644 "$SCRIPT_DIR/kiosk/10-monitor-dsi-rotate.conf" /etc/X11/xorg.conf.d/
install -m 0644 "$SCRIPT_DIR/kiosk/99-touchscreen-rotate-left.rules" /etc/udev/rules.d/
udevadm control --reload-rules

# -------- 6c2. RA rotation watcher ------------------------------------------
echo "==> Installing ra-rotate-watcher service..."
install -m 0755 "$SCRIPT_DIR/kiosk/ra-rotate-watcher.py" /opt/modulino-gamepad/
install -m 0644 "$SCRIPT_DIR/kiosk/ra-rotate-watcher.service" /etc/systemd/system/
systemctl daemon-reload
systemctl enable ra-rotate-watcher.service

# -------- 6c3. Kiosk boot watchdog ------------------------------------------
# lightdm intermittently launches Xorg but fails to connect to it on the DSI
# panel ("Error connecting to XServer :0"), wedging with a black screen and no
# session. Restarting lightdm recovers it. This watchdog self-heals that race.
echo "==> Installing kiosk boot watchdog..."
mkdir -p /opt/kiosk
install -m 0755 "$SCRIPT_DIR/kiosk/kiosk-session-watchdog.sh" /opt/kiosk/
install -m 0644 "$SCRIPT_DIR/kiosk/kiosk-session-watchdog.service" /etc/systemd/system/
systemctl daemon-reload
systemctl enable kiosk-session-watchdog.service

# -------- 6c1. Audio codec tuning -------------------------------------------
# WirePlumber brings the Imola codec up with untuned defaults and resets the
# controls (and the card profile) on every (re)start. audio-tune.service is
# PartOf wireplumber.service so it re-applies the tuned values each time
# WirePlumber starts. See kiosk/audio-tune.sh for the rationale.
#
# OUTPUT MODE: /etc/kiosk-audio-output selects the jack audio-tune.sh drives:
#   headphones (default) -> MIC-IN/Headphones CTIA jack (demo console)
#   earpiece             -> Earphones Out jack driving a bare 10.67-32 ohm
#                           speaker (production arcades)
# Select at provision time with:  KIOSK_AUDIO_OUTPUT=earpiece sudo bash setup.sh
# An existing mode file is preserved when the env var is not set.
echo "==> Installing audio codec tuning service..."
if [ -n "${KIOSK_AUDIO_OUTPUT:-}" ]; then
    echo "$KIOSK_AUDIO_OUTPUT" > /etc/kiosk-audio-output
elif [ ! -f /etc/kiosk-audio-output ]; then
    echo headphones > /etc/kiosk-audio-output
fi
echo "==> Audio output mode: $(cat /etc/kiosk-audio-output)"

# The mono "Speaker" loopback sink is only wanted in earpiece mode; on
# headphone units it would show up as a bogus selectable sink.
PW_CONF_DIR="$ARDUINO_HOME/.config/pipewire/pipewire.conf.d"
if [ "$(cat /etc/kiosk-audio-output)" = "earpiece" ]; then
    run_as_arduino mkdir -p "$PW_CONF_DIR"
    install -m 0644 -o "$ARDUINO_USER" -g "$ARDUINO_USER" \
        "$SCRIPT_DIR/kiosk/51-earpiece-mono-sink.conf" "$PW_CONF_DIR/"
else
    rm -f "$PW_CONF_DIR/51-earpiece-mono-sink.conf"
fi

install -m 0755 "$SCRIPT_DIR/kiosk/audio-tune.sh" /opt/modulino-gamepad/
USER_SYSTEMD="$ARDUINO_HOME/.config/systemd/user"
run_as_arduino mkdir -p "$USER_SYSTEMD"
install -m 0644 -o "$ARDUINO_USER" -g "$ARDUINO_USER" \
    "$SCRIPT_DIR/kiosk/audio-tune.service" "$USER_SYSTEMD/"
UID_ARDUINO="$(id -u "$ARDUINO_USER")"
sudo -u "$ARDUINO_USER" env "XDG_RUNTIME_DIR=/run/user/$UID_ARDUINO" \
    systemctl --user daemon-reload 2>/dev/null || true
sudo -u "$ARDUINO_USER" env "XDG_RUNTIME_DIR=/run/user/$UID_ARDUINO" \
    systemctl --user enable audio-tune.service 2>/dev/null || true

# -------- 6c. Disable xfwm4 compositor --------------------------------------
# The compositor re-composites RetroArch's framebuffer at its own rate,
# breaking vsync and causing tearing during gameplay. Turn it off for the
# kiosk user.
echo "==> Disabling xfwm4 compositor for $ARDUINO_USER..."
run_as_arduino mkdir -p "$ARDUINO_HOME/.config/xfce4/xfconf/xfce-perchannel-xml"
run_as_arduino tee "$ARDUINO_HOME/.config/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml" > /dev/null <<'XFWM_EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfwm4" version="1.0">
  <property name="general" type="empty">
    <property name="use_compositing" type="bool" value="false"/>
  </property>
</channel>
XFWM_EOF

# -------- 7. RetroArch kiosk autostart --------------------------------------
echo "==> Installing RetroArch kiosk autostart..."
run_as_arduino mkdir -p "$AUTOSTART_DIR"
install -m 0644 -o "$ARDUINO_USER" -g "$ARDUINO_USER" \
    "$SCRIPT_DIR/kiosk/retroarch-kiosk.desktop" "$AUTOSTART_DIR/"

# -------- 8. RetroArch config overrides -------------------------------------
echo "==> Applying RetroArch kiosk overrides to retroarch.cfg..."
RA_CFG="$ARDUINO_HOME/.config/retroarch/retroarch.cfg"
run_as_arduino mkdir -p "$(dirname "$RA_CFG")"
[ -f "$RA_CFG" ] || run_as_arduino touch "$RA_CFG"
MARK_BEGIN="# >>> modulino-kiosk-overrides >>>"
MARK_END="# <<< modulino-kiosk-overrides <<<"
run_as_arduino sed -i "/$MARK_BEGIN/,/$MARK_END/d" "$RA_CFG"
# Drop any stale lines RetroArch wrote on a previous run so our overrides
# below are unambiguous (last-write-wins parser would still pick our copy,
# but cleaner this way and avoids the "first wins" gotcha in some paths).
run_as_arduino sed -i '/^libretro_directory\s*=/d; /^libretro_info_path\s*=/d; /^video_driver\s*=/d; /^video_vsync\s*=/d; /^video_hard_sync\s*=/d; /^video_max_swapchain_images\s*=/d; /^video_frame_delay_auto\s*=/d; /^video_rotation\s*=/d; /^menu_rotation\s*=/d; /^video_allow_rotate\s*=/d; /^menu_driver\s*=/d; /^kiosk_mode_enable\s*=/d; /^audio_enable\s*=/d; /^audio_driver\s*=/d; /^audio_mute_enable\s*=/d; /^audio_mixer_mute_enable\s*=/d; /^audio_volume\s*=/d; /^network_cmd_enable\s*=/d; /^network_cmd_port\s*=/d; /^input_exit_emulator\s*=/d; /^confirm_on_exit\s*=/d; /^quit_press_twice\s*=/d' "$RA_CFG"
{
    echo "$MARK_BEGIN"
    cat "$SCRIPT_DIR/kiosk/retroarch-overrides.cfg"
    echo "$MARK_END"
} | run_as_arduino tee -a "$RA_CFG" > /dev/null

# -------- 9. Lightdm autologin ----------------------------------------------
echo "==> Configuring lightdm autologin for $ARDUINO_USER..."
LIGHTDM_DROPIN=/etc/lightdm/lightdm.conf.d/50-kiosk-autologin.conf
mkdir -p "$(dirname "$LIGHTDM_DROPIN")"
cat > "$LIGHTDM_DROPIN" <<EOF
[Seat:*]
autologin-user=$ARDUINO_USER
autologin-user-timeout=0
EOF

# -------- 10. Hide Arduino App Lab from autostart ---------------------------
hide_autostart() {
    local src=$1
    local name
    name="$(basename "$src")"
    [ -f "$src" ] || return 0
    cp "$src" "$AUTOSTART_DIR/$name"
    sed -i '/^Hidden=/d' "$AUTOSTART_DIR/$name"
    [ "$(tail -c1 "$AUTOSTART_DIR/$name")" = "" ] || echo "" >> "$AUTOSTART_DIR/$name"
    echo "Hidden=true" >> "$AUTOSTART_DIR/$name"
    chown "$ARDUINO_USER:$ARDUINO_USER" "$AUTOSTART_DIR/$name"
}

echo "==> Hiding non-kiosk autostart entries..."
hide_autostart /etc/xdg/autostart/ArduinoAppLab.desktop
hide_autostart /etc/xdg/autostart/light-locker.desktop

# -------- 10b. Force USB-C into host mode -----------------------------------
# Default is "device" so the workstation can talk to the Q via App Lab. For
# kiosk use we want host mode so external keyboards/USB hubs are usable.
# (To revert temporarily, run:
#   echo device | sudo tee /sys/devices/platform/soc@0/4ef8800.usb/4e00000.usb/usb_role/4e00000.usb-role-switch/role)
echo "==> Installing USB host-mode service..."
install -m 0644 "$SCRIPT_DIR/kiosk/usb-host-mode.service" /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now usb-host-mode.service

# -------- 11. Disable Magic SysRq -------------------------------------------
echo "==> Disabling Magic SysRq..."
install -m 0644 "$SCRIPT_DIR/kiosk/99-kiosk.conf" /etc/sysctl.d/99-kiosk.conf
echo 0 > /proc/sys/kernel/sysrq

# -------- 12. Stop the App Lab Python container -----------------------------
# Two subscribers on the same Bridge RPC name conflict — the host daemon owns
# linux_started + gamepad_state now.
echo "==> Stopping App Lab Python container (host daemon takes over)..."
docker stop game-console-main-1 2>/dev/null || true

systemctl restart modulino-gamepad

echo ""
echo "============================================"
echo " Setup complete. Reboot to land in RetroArch."
echo "============================================"
