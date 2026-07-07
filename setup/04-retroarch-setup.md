# RetroArch Setup

## Installation

```bash
# Install RetroArch and common cores
sudo apt install -y retroarch \
  libretro-gambatte \
  libretro-snes9x \
  libretro-mgba \
  libretro-genesis-plus-gx \
  libretro-nestopia

# If packages aren't available, build from source:
# sudo apt install -y build-essential git libdrm-dev libasound2-dev
# git clone https://github.com/libretro/RetroArch.git
# cd RetroArch
# ./configure --disable-x11 --enable-kms --enable-alsa
# make -j4
# sudo make install
```

## Gamepad Configuration

Install the Modulino Gamepad autoconfig:

```bash
mkdir -p ~/.config/retroarch/autoconfig/udev/
cp ~/retroconsole/retroarch/modulino-gamepad.cfg \
   ~/.config/retroarch/autoconfig/udev/
```

## Display Configuration

Edit `~/.config/retroarch/retroarch.cfg`:

```
video_driver = "kms"
video_fullscreen = "true"
video_windowed_fullscreen = "false"
video_monitor_index = "0"
```

## Audio Configuration

```
audio_driver = "alsa"
audio_enable = "true"
audio_sync = "true"
audio_latency = "64"
```

## Auto-Start RetroArch on Boot

Create a systemd service:

```bash
sudo tee /etc/systemd/system/retroarch.service << 'EOF'
[Unit]
Description=RetroArch Emulator
After=modulino-gamepad.service
Wants=modulino-gamepad.service

[Service]
Type=simple
User=arduino
Environment=XDG_RUNTIME_DIR=/run/user/1000
ExecStart=/usr/bin/retroarch --config ~/.config/retroarch/retroarch.cfg
Restart=on-failure
RestartSec=5

[Install]
WantedBy=graphical.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable retroarch
```

## Adding ROMs

Place ROM files in the RetroArch content directory:

```bash
mkdir -p ~/roms/{gb,gbc,gba,snes,nes,genesis}
# Copy your legally obtained ROMs into the appropriate folders
```

## Testing

```bash
# Start the gamepad daemon first
sudo systemctl start modulino-gamepad

# Launch RetroArch manually for testing
retroarch

# Navigate menus with the joystick, load a ROM, verify controls
```

## Performance Tips

- The A53 @ 2GHz handles GB, GBC, GBA, NES, SNES, and Genesis well
- For SNES, use snes9x (lighter than bsnes)
- Avoid N64/PS1 cores — they'll likely be too slow
- If frames drop, try: Settings → Video → Threaded Video = ON
