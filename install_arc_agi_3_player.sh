#!/bin/bash
# =============================================================================
# ARC-AGI-3 player — installer for the Arduino Uno Q Retro Game Console.
#
# Installs the ARC-AGI-3 benchmark games as a second app on the console, next
# to RetroArch. Both then start from the XFCE dock with one touch.
#
# Run on the Q itself, after the repo is cloned to ~/retroconsole and
# setup.sh has provisioned the console (DSI panel, gamepad daemon, audio).
#
# What this script does (idempotent — safe to re-run):
#   1. Install APT packages (python3-venv, the XFCE metadata tool)
#   2. Clone the upstream player and pin it to a known commit
#   3. Patch it for the console: gamepad input, fullscreen, a config fix
#   4. Build a venv and install the dependencies (aarch64 wheels, no build)
#   5. Download the 25 games once, so the console then plays offline
#   6. Install the ARC Prize icon into the user icon theme
#   7. Add dock launchers for the player and for RetroArch
#   8. Size the dock for the touchscreen
#   9. Park the RetroArch autostart, so neither app fights for the display
#
# Options (environment variables):
#   ARC_KEEP_KIOSK=1     keep the RetroArch autostart; skip step 9
#   ARC_SKIP_DOWNLOAD=1  skip step 5, for a console with no network
#   ARC_UPSTREAM_REF     commit or tag to pin (default below)
#   ARC_APP_DIR          install location (default ~/arc-play)
#
# After a successful run, tap the ARC-AGI-3 icon in the dock.
# =============================================================================
set -e

UPSTREAM_URL="https://github.com/aashen1/arc-agi-3-local-play.git"
UPSTREAM_REF="${ARC_UPSTREAM_REF:-824ac63}"

echo "================================================"
echo " Arduino Uno Q Retro Console — ARC-AGI-3 Player"
echo "================================================"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASSETS="$SCRIPT_DIR/arc-agi-3"
ARDUINO_USER="${SUDO_USER:-arduino}"
ARDUINO_HOME="$(getent passwd "$ARDUINO_USER" | cut -d: -f6)"
APP_DIR="${ARC_APP_DIR:-$ARDUINO_HOME/arc-play}"
AUTOSTART_DIR="$ARDUINO_HOME/.config/autostart"
PANEL_DIR="$ARDUINO_HOME/.config/xfce4/panel"
ICON_DIR="$ARDUINO_HOME/.local/share/icons/hicolor"

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root: sudo bash $0"
    exit 1
fi
if [ ! -d "$ASSETS" ]; then
    echo "Missing $ASSETS — run this script from inside the cloned repo."
    exit 1
fi

run_as_arduino() { sudo -u "$ARDUINO_USER" "$@"; }

# xfconf-query needs the user's session bus to reach the running panel.
xfconf() {
    sudo -u "$ARDUINO_USER" \
        DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u "$ARDUINO_USER")/bus" \
        xfconf-query "$@"
}

# -------- 1. APT packages ----------------------------------------------------
# Debian marks the system Python externally managed, so the app needs its own
# venv. libglib2.0-bin provides gtk-update-icon-cache for the icon theme.
echo "==> Installing APT packages..."
apt-get update
apt-get install -y git python3-venv libglib2.0-bin

# -------- 2. Upstream checkout ----------------------------------------------
echo "==> Fetching the upstream player ($UPSTREAM_REF)..."
if [ ! -d "$APP_DIR/.git" ]; then
    if [ -d "$APP_DIR" ] && [ -n "$(ls -A "$APP_DIR" 2>/dev/null)" ]; then
        echo "$APP_DIR exists but is not a git checkout. Move it aside first."
        exit 1
    fi
    run_as_arduino git clone "$UPSTREAM_URL" "$APP_DIR"
fi
run_as_arduino git -C "$APP_DIR" fetch --all --quiet
run_as_arduino git -C "$APP_DIR" checkout --quiet "$UPSTREAM_REF"

# -------- 3. Console patches -------------------------------------------------
# Upstream assumes a keyboard and a mouse. The console has a gamepad and a
# touchscreen, so the event loops read through the gamepad bridge instead.
echo "==> Patching the player for the console..."
install -o "$ARDUINO_USER" -g "$ARDUINO_USER" -m 644 \
    "$ASSETS/gamepad.py" "$APP_DIR/human_player/gamepad.py"
run_as_arduino python3 "$ASSETS/patch-upstream.py" "$APP_DIR"

install -d -o "$ARDUINO_USER" -g "$ARDUINO_USER" "$APP_DIR/console"
install -o "$ARDUINO_USER" -g "$ARDUINO_USER" -m 755 \
    "$ASSETS/arc-play.sh" "$APP_DIR/console/arc-play.sh"

# -------- 4. Virtual environment --------------------------------------------
# Every dependency ships an aarch64 wheel, so nothing compiles here. Do not
# use pixi: its pixi.toml has no linux-aarch64 platform.
echo "==> Building the virtual environment (a few minutes)..."
if [ ! -x "$APP_DIR/.venv/bin/python" ]; then
    run_as_arduino python3 -m venv "$APP_DIR/.venv"
fi
run_as_arduino "$APP_DIR/.venv/bin/pip" install -q --upgrade pip
run_as_arduino sh -c "cd '$APP_DIR' && .venv/bin/pip install -q \
    'arc-agi>=0.9.8,<0.10' 'rich>=13.0' 'pygame-ce>=2.5.7,<3' -e ."

# -------- 5. Game download ---------------------------------------------------
# ENVIRONMENTS_DIR must be absolute. The SDK defaults it to a path relative to
# the working directory, so a launcher started elsewhere downloads all 25
# games again on every start.
if [ "${ARC_SKIP_DOWNLOAD:-0}" = "1" ]; then
    echo "==> Skipping the game download (ARC_SKIP_DOWNLOAD=1)."
else
    echo "==> Downloading the games (needs a network connection)..."
    run_as_arduino env \
        ENVIRONMENTS_DIR="$APP_DIR/environment_files" \
        SDL_VIDEODRIVER=dummy \
        "$APP_DIR/.venv/bin/python" -c \
        "from human_player.game_sync import sync_games; r = sync_games(); \
print('downloaded', r.downloaded, 'skipped', r.skipped, 'failed', r.failed)" \
        2>/dev/null || echo "    Download failed. Re-run later, or start the app and press Sync."
fi

# -------- 6. Icon ------------------------------------------------------------
# The ARC Prize mark: a magenta and a yellow square, the two colours the games
# themselves use. GTK needs an index.theme in the user icon directory.
echo "==> Installing the icon..."
for size in 16 24 32 48 64 128 256; do
    run_as_arduino install -d "$ICON_DIR/${size}x${size}/apps"
    run_as_arduino install -m 644 \
        "$ASSETS/icons/arc-agi-3-${size}.png" \
        "$ICON_DIR/${size}x${size}/apps/arc-agi-3.png"
done
[ -f "$ICON_DIR/index.theme" ] || \
    run_as_arduino cp /usr/share/icons/hicolor/index.theme "$ICON_DIR/index.theme"
run_as_arduino gtk-update-icon-cache -f -t "$ICON_DIR" >/dev/null 2>&1 || true

# -------- 7. Dock launchers --------------------------------------------------
# A panel launcher takes one tap. A desktop icon needs a double tap, which is
# hard to hit on the touchscreen.
echo "==> Adding the dock launchers..."
run_as_arduino install -d "$PANEL_DIR/launcher-20" "$PANEL_DIR/launcher-21"
# The entry ships the default path, so point it at wherever APP_DIR really is.
sed "s#^Exec=.*/console/arc-play.sh#Exec=$APP_DIR/console/arc-play.sh#" \
    "$ASSETS/panel-launchers/arc-agi-3.desktop" \
    > "$PANEL_DIR/launcher-20/arc-agi-3.desktop"
run_as_arduino install -m 644 \
    "$ASSETS/panel-launchers/retroarch.desktop" "$PANEL_DIR/launcher-21/"
chown "$ARDUINO_USER:$ARDUINO_USER" "$PANEL_DIR/launcher-20/arc-agi-3.desktop"
chmod 644 "$PANEL_DIR/launcher-20/arc-agi-3.desktop"

xfconf -c xfce4-panel -p /plugins/plugin-20 -n -t string -s launcher || true
xfconf -c xfce4-panel -p /plugins/plugin-21 -n -t string -s launcher || true
xfconf -c xfce4-panel -p /plugins/plugin-20/items -n -t string \
    -s "arc-agi-3.desktop" --force-array || true
xfconf -c xfce4-panel -p /plugins/plugin-21/items -n -t string \
    -s "retroarch.desktop" --force-array || true

# Put the two game launchers first, after the show-desktop button.
xfconf -c xfce4-panel -p /panels/panel-2/plugin-ids \
    -t int -s 11 -t int -s 12 -t int -s 20 -t int -s 21 -t int -s 13 \
    -t int -s 14 -t int -s 15 -t int -s 16 -t int -s 17 -t int -s 18 \
    -t int -s 19 --force-array || true

# -------- 8. Dock sizing -----------------------------------------------------
# The 8-inch panel is 1280 px across about 173 mm, so 7.4 px/mm. An 80 px icon
# is about 10.8 mm, above the 9 mm a fingertip needs. Autohide off, because a
# hidden dock is hard to summon by touch.
echo "==> Sizing the dock for touch..."
xfconf -c xfce4-panel -p /panels/panel-2/size -t int -s 100 || true
xfconf -c xfce4-panel -p /panels/panel-2/icon-size -n -t int -s 80 || true
xfconf -c xfce4-panel -p /panels/panel-2/autohide-behavior -t int -s 0 || true

# -------- 9. Park the RetroArch autostart -----------------------------------
# RetroArch and the player both want the whole display, so only one may
# autostart. Both are one tap away in the dock instead.
if [ "${ARC_KEEP_KIOSK:-0}" = "1" ]; then
    echo "==> Keeping the RetroArch autostart (ARC_KEEP_KIOSK=1)."
elif [ -f "$AUTOSTART_DIR/retroarch-kiosk.desktop" ]; then
    echo "==> Parking the RetroArch autostart..."
    run_as_arduino mv "$AUTOSTART_DIR/retroarch-kiosk.desktop" \
        "$AUTOSTART_DIR/retroarch-kiosk.desktop.disabled"
fi

# -------- Reload the panel ---------------------------------------------------
run_as_arduino env DISPLAY=:0 \
    DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u "$ARDUINO_USER")/bus" \
    xfce4-panel -r >/dev/null 2>&1 || true

echo
echo "================================================"
echo " Done. Tap the ARC-AGI-3 icon in the dock."
echo
echo " Gamepad   D-pad moves, A interacts, B undoes,"
echo "           Y resets, Start opens the menu."
echo " Touch     tap the grid for the click action."
echo
echo " Restore the RetroArch kiosk with:"
echo "   mv $AUTOSTART_DIR/retroarch-kiosk.desktop{.disabled,}"
echo "================================================"
