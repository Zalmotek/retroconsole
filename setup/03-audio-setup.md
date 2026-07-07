# Audio Setup — Uno Media Carrier

## Hardware

The Uno Media Carrier has a 3.5mm line-out jack. Connect powered speakers or headphones.

## Software Configuration

### Verify Audio Device

```bash
# List audio devices
aplay -l

# You should see an audio device from the Media Carrier
# Look for something like "qrb2210" or "sm8250" audio
```

### Test Audio Output

```bash
# Install audio tools
sudo apt install -y alsa-utils

# Generate and play a test tone
speaker-test -t sine -f 440 -c 2 -l 1

# Or play a WAV file
aplay /usr/share/sounds/alsa/Front_Center.wav
```

### Set Default Output

If multiple audio devices exist, set the Media Carrier as default:

```bash
# Find card number from aplay -l output
# Edit ALSA config
cat > ~/.asoundrc << 'EOF'
defaults.pcm.card 0
defaults.pcm.device 0
defaults.ctl.card 0
EOF
```

### Volume Control

```bash
# Set volume (0-100)
amixer set Master 80%

# Or use interactive mixer
alsamixer
```

## RetroArch Audio Config

RetroArch routes through PipeWire's PulseAudio shim (`pipewire-pulse` is active;
WirePlumber auto-configures the Imola codec headphone path on card 0, so the raw
`amixer` pipeline from the Media Carrier manual is NOT needed). These are applied
by `setup.sh` via `kiosk/retroarch-overrides.cfg`:

```
audio_driver = "pulse"
audio_device = ""
audio_enable = "true"
audio_mute_enable = "false"   # default profile ships this as "true" → silent games
audio_sync = "true"
audio_latency = "64"
```

## Codec tuning (headphone amp quality)

The Imola codec headphone amp comes up in a low-power, distorting default. Tuned
values (chosen by listening test) are applied by `audio-tune.service`, a user
service bound to `wireplumber.service` (so it re-runs whenever WirePlumber
restarts and resets the codec):

```
amixer -c0 sset 'RX_HPH PWR Mode' ULP      # best with the current amp board
amixer -c0 sset 'RX_HPH HD2 Mode' on       # 2nd-harmonic distortion correction
wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.90 # source level; final loudness on amp
# balance: WirePlumber drives only RX_RX1 (right) from the sink slider, so mirror
# left = right AFTER setting the sink, or the channels are uneven:
RIGHT=$(amixer -c0 cget iface=MIXER,name='RX_RX1 Digital Volume' | grep -oE 'values=[0-9]+' | tail -1 | cut -d= -f2)
amixer -c0 cset iface=MIXER,name='RX_RX0 Digital Volume' "$RIGHT"
```

> **Channel balance gotcha:** `RX_RX1 Digital Volume` (right) *is* the sink
> volume — WirePlumber maps the slider onto it and leaves `RX_RX0` (left)
> alone, so the two channels drift apart. There's no independent "set codec to
> N and sink to M"; the right codec value is whatever the slider dictates. The
> only fix is to mirror left = right after the sink is set (audio-tune.sh does
> this automatically each boot).

- `RX_HPH PWR Mode`: the best mode is **amp-dependent**. `LOHIFI` won on the
  first amp; `ULP` won on the current amp board. Re-run the listening test
  (A: LOHIFI+HD2on, B: LOHIFI+HD2off, C: ULP+HD2on, D: ULP+HD2off) if the amp changes.
- `RX_HPH HD2 Mode`: `on` consistently helped; `off` was audibly worse.
- **Do NOT touch `RX INT0/1 DEM MUX`** — switching Class-H (`CLSH_DSM_OUT`) to
  `NORMAL_DSM_OUT` silences the headphone output entirely, and toggling it live
  wedges the codec until `systemctl --user restart wireplumber`.
- The `HPHL`/`HPHR` analog gain spans only ~1.4 dB — useless as a volume control.
- For an external amp: keep the digital sink moderate (~50%) and set final
  loudness on the amp; the dedicated **Line Out (`hw:0,1`) is mono/differential**,
  not a stereo line out.

## Troubleshooting

- **No sound in games but system beep works**: RetroArch is muted —
  `audio_mute_enable = "true"`. Set it to `"false"` (setup.sh pins this), or
  live-toggle on the running kiosk: `echo -n MUTE | nc -u -w1 127.0.0.1 55355`.
- **No sound**: Check `amixer` isn't muted, verify correct card in `aplay -l`,
  and that the default sink is at volume: `wpctl get-volume @DEFAULT_AUDIO_SINK@`
- **Crackling**: Increase `audio_latency` in RetroArch (try 128)
- **No audio device**: Media Carrier may need kernel module; check `dmesg | grep audio`
