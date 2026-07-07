#!/bin/bash
set -e

echo "=== Modulino Gamepad Installer ==="

# Install Python dependencies
apt-get update
apt-get install -y python3-pip i2c-tools evtest
pip3 install python-uinput

# Load uinput module
modprobe uinput
echo "uinput" >> /etc/modules-load.d/uinput.conf

# Install daemon files
mkdir -p /opt/modulino-gamepad
cp gamepad_daemon.py /opt/modulino-gamepad/
chmod +x /opt/modulino-gamepad/gamepad_daemon.py

# Install and enable systemd service
cp modulino-gamepad.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable modulino-gamepad

echo "=== Installation complete ==="
echo ""
echo "NOTE: The Arduino sketch (sketch/ folder) must be deployed to the"
echo "MCU via Arduino App Lab. The Python daemon receives data via Bridge."
echo ""
echo "After deploying the sketch via App Lab:"
echo "  systemctl start modulino-gamepad"
echo "  evtest  # look for 'Modulino Gamepad'"
