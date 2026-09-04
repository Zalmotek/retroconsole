#!/bin/sh
# Launcher for the ARC-AGI-3 player on the Arduino Uno Q Retro Game Console.
#
# ENVIRONMENTS_DIR must be absolute. The arc_agi SDK defaults it to a path
# relative to the working directory, so a launcher started elsewhere would
# download all 25 games again on every start.
set -e

# This script lives in <app dir>/console/, so the app dir is one level up.
APP_DIR="$(cd "$(dirname "$0")/.." && pwd)"

export ENVIRONMENTS_DIR="$APP_DIR/environment_files"
export ARC_FULLSCREEN=1

# Keep the panel awake while somebody plays.
xset s off || true
xset s noblank || true
xset -dpms || true

cd "$APP_DIR"
exec "$APP_DIR/.venv/bin/python" -m human_player
