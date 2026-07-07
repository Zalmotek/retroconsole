# OS Setup — Arduino Uno Q

## Prerequisites

- Arduino Uno Q with Debian already flashed
- USB-C cable
- Arduino App Lab on your PC (https://www.arduino.cc/en/software)

## First-Time App Lab Connection

1. Connect the Uno Q to your PC via USB-C
2. Open Arduino App Lab
3. The board will auto-check for firmware/OS updates — install if prompted
4. Set device name, password, and Wi-Fi credentials

## Network Access

After initial setup, you can connect via SSH over Wi-Fi:

```bash
# From your PC
ssh arduino@<device-name>.local
# Default password: set during first-time setup
```

Or connect via USB-C (gadget ethernet):

```bash
ssh arduino@192.168.7.1
```

## Verify I2C (Qwiic bus)

The Qwiic I2C bus is managed by the MCU, not directly accessible from Linux. To verify Modulino devices are connected:

1. Open Arduino App Lab
2. Upload the `File > Examples > Arduino_Modulino > Modulino_Scanner` sketch
3. Check Serial Monitor — it should list detected devices at 0x58, 0x7C, 0x7D

## System Packages

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y git python3-pip evtest i2c-tools alsa-utils
```

## Clone This Repo

```bash
git clone <repo-url>
cd retroconsole
```
