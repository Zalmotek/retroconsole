#!/bin/sh
# =============================================================================
# Apply tuned audio defaults for the Arduino Imola codec (sound card 0).
#
# WHY THIS EXISTS: WirePlumber resets these codec controls to low-power
# defaults on every (re)start and does not persist the card-profile choice,
# so a one-shot set at install time does not stick. This script is run by
# audio-tune.service, which is PartOf wireplumber.service and therefore
# re-runs each time WirePlumber starts.
#
# OUTPUT MODE comes from /etc/kiosk-audio-output ("headphones" if absent):
#   headphones -> MIC-IN/Headphones CTIA jack (hw:0,0), stereo. Demo console.
#   earpiece   -> Earphones Out jack: mono differential Class-AB earpiece amp
#                 driving a 10.67-32 ohm speaker directly (no external amp).
#                 Production arcade mode. Requires the "Speaker" mono loopback
#                 sink (51-earpiece-mono-sink.conf) for the FL+FR downmix.
#
# HEADPHONES tuning (chosen by listening test against the current amplifier
# board; the best combo is amp-dependent, re-test if the amp changes):
#   RX_HPH PWR Mode = ULP     -> ultra-low-power amp mode sounded best with this
#                               amp board (LOHIFI was preferred on the previous one).
#   RX_HPH HD2 Mode = on      -> enables 2nd-harmonic-distortion correction.
#   sink volume     = 0.90    -> source level; final loudness set on the amp.
#
# CHANNEL BALANCE (headphones): WirePlumber drives only 'RX_RX1 Digital Volume'
# (right) from the sink slider and leaves 'RX_RX0 Digital Volume' (left) at its
# own default, which makes the two channels unequal. We fix it by setting the
# sink first, then mirroring left = right. (Holds because the kiosk sets volume
# once here and does runtime loudness on the amp; a runtime sink change would
# re-skew it.)
# NOTE: Class-H (RX INT0/1 DEM MUX = CLSH_DSM_OUT) is MANDATORY — switching it
# to NORMAL_DSM_OUT silences the headphone output, so we leave it alone.
# =============================================================================
CARD=0
MODE=$(cat /etc/kiosk-audio-output 2>/dev/null || echo headphones)

# Wait for a wpctl object matching $1 to appear and print its id. The sinks
# only appear after WirePlumber has configured the card, so waiting also
# guarantees our amixer overrides land AFTER WirePlumber's (otherwise it
# overwrites us).
wait_id() {
    i=0
    while [ "$i" -lt 30 ]; do
        ID=$(wpctl status 2>/dev/null | grep -iE "[0-9]+\. $1" \
             | grep -oE '[0-9]+\.' | head -1 | tr -d '.')
        if [ -n "$ID" ]; then echo "$ID"; return 0; fi
        i=$((i + 1))
        sleep 1
    done
    return 1
}

if [ "$MODE" = "earpiece" ]; then
    # ---- Earpiece speaker path (production arcades) -------------------------
    # Select the UCM "Earphones" card profile. Index 2 comes from the verb
    # order in /usr/share/alsa/ucm2/Qualcomm/qcm2290/Arduino-Imola.conf
    # (0=off, 1=Headphones, 2=Earphones, 3=LineOut, 4=pro-audio).
    wait_id 'Built-in Audio (Headphones|Earphones) playback' >/dev/null 2>&1
    DEV=$(wpctl status 2>/dev/null | sed -n '/Devices:/,/Sinks:/p' \
          | grep 'Built-in Audio' | grep -oE '[0-9]+\.' | head -1 | tr -d '.')
    [ -n "$DEV" ] && wpctl set-profile "$DEV" 2 2>/dev/null

    SINK=$(wait_id 'Built-in Audio Earphones playback')
    if [ -n "$SINK" ]; then
        # WirePlumber does not reliably activate the route on a profile switch
        # (the sink appears but EAR_RDAC stays off = silence), so set it
        # explicitly. Route index 0 = "[Out] Earphones" in the UCM EnumRoute.
        wpctl set-route "$SINK" 0 2>/dev/null || true
        wpctl set-volume "$SINK" 1.0 2>/dev/null || true
    fi

    # Loudness chain (listening-tested on the delivered speaker): max codec
    # digital gain on both channels + EAR boost mode. Overall level is set on
    # the mono Speaker sink below (0.95 — 1.0 clips into the earpiece amp).
    amixer -c"$CARD" cset iface=MIXER,name='RX_RX0 Digital Volume' 124 >/dev/null 2>&1 || true
    amixer -c"$CARD" cset iface=MIXER,name='RX_RX1 Digital Volume' 124 >/dev/null 2>&1 || true
    amixer -c"$CARD" cset iface=MIXER,name='RX_EAR Mode Switch' on   >/dev/null 2>&1 || true

    # Default sink = the mono "Speaker" loopback sink, which downmixes FL+FR.
    # Streams sent straight to the raw Earphones sink would silently lose the
    # right channel (the jack carries hw ch0 only).
    MONO=$(wait_id 'earpiece_mono ')
    if [ -n "$MONO" ]; then
        wpctl set-default "$MONO" 2>/dev/null || true
        wpctl set-volume "$MONO" 0.95 2>/dev/null || true
    fi
    exit 0
fi

# ---- Headphone-jack path (demo console, default) ----------------------------
SINK=$(wait_id 'Built-in Audio Headphones playback')

if [ -n "$SINK" ]; then
    wpctl set-default "$SINK" 2>/dev/null || true
    wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.90 2>/dev/null || true
fi

amixer -c"$CARD" sset 'RX_HPH PWR Mode' ULP >/dev/null 2>&1 || true
amixer -c"$CARD" sset 'RX_HPH HD2 Mode' on  >/dev/null 2>&1 || true

# Balance: mirror left (RX_RX0) onto the right value WirePlumber set from the
# sink slider (RX_RX1). Must run AFTER the sink volume is applied above.
RIGHT=$(amixer -c"$CARD" cget iface=MIXER,name='RX_RX1 Digital Volume' \
        2>/dev/null | grep -oE 'values=[0-9]+' | tail -1 | cut -d= -f2)
if [ -n "$RIGHT" ]; then
    amixer -c"$CARD" cset iface=MIXER,name='RX_RX0 Digital Volume' "$RIGHT" \
        >/dev/null 2>&1 || true
fi
