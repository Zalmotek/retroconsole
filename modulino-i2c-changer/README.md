# Modulino I2C Address Changer

Arduino App Lab utility that renumbers a Modulino's I2C address so multiple
modules of the same type can share a Qwiic bus.

The retro-console uses **three Modulino Buttons** (only the exterior pair of
each is mapped — the middle button is too cramped to use). All three ship at
the same factory address, so two of them must be renumbered before the
gamepad sketch can tell them apart:

```
Buttons #1  0x3E  (factory — untouched)
Buttons #2  0x3E → 0x3F
Buttons #3  0x3E → 0x40
```

The changer is **deterministic**: you set the target address explicitly in
the sketch for each run. There is no auto-assignment on purpose — a
half-seated Qwiic connector makes an occupied address look free, which is
how you end up with two modules on one address (see Recovery below).

## From-scratch routine (new unit, 3 fresh Buttons modules)

**Rule 1: exactly one Buttons module on the chain per run.** An I2C write
reaches every device at that address, so two factory modules attached at
once would both be renumbered.
**Rule 2: the changer re-runs on every MCU reset while it's in flash.**
Its guards make that mostly harmless, but always finish with step 5.

The Joystick (0x2C) can stay attached throughout.

1. **Run 1 — make Buttons #2:** attach one Buttons module (alone). Open this
   project in App Lab and press **Run** with the sketch as shipped
   (`NEW_ADDR = 0x3F`). Watch the Monitor: `SUCCESS` + a bus scan. The
   module's three LEDs blink in unison.
2. **Persistence check:** unplug and replug that module. The blinking
   resumes → the address survived the power-cycle. Label the module **#2**
   and detach it.
3. **Run 2 — make Buttons #3:** edit one line in the sketch —
   `NEW_ADDR = 0x40` — attach the second module (alone), press **Run**.
   Same checks. Label it **#3**, detach it.
4. The third module is **Buttons #1**: it stays at the factory `0x3E` —
   no run. Label it anyway.
5. **Disarm:** run the `bus-scanner` app (import `dist/bus-scanner.zip`).
   This removes the changer from MCU flash so later resets can't renumber
   anything, and doubles as the verifier for the next step.
6. **Verify the full chain:** connect
   `Uno Q → Joystick → #1 → #2 → #3` and read the Monitor. It must list
   `0x2C, 0x3E, 0x3F, 0x40`. A missing address = bad connector or cable on
   that segment — reseat until all four show.
7. Flash the gameplay sketch (`game-console`) and test all six buttons.

## Monitor + LED feedback

The Monitor prints the bus before/after and one of:

| Message | Meaning |
|---|---|
| `SUCCESS` | renumbered and verified at the new address |
| `Already at target — nothing to do.` | harmless re-run after a success |
| `REFUSING: target address already in use…` | another module owns NEW_ADDR — detach it first; nothing was changed |
| `FAILED: no module at CURRENT_ADDR…` | nothing answered — almost always a half-seated Qwiic connector |

LEDs on the module: **all three blinking** = success / already done;
**only LED 0** = failed or refused (read the Monitor); **no LEDs** = no
module answered at all.

## Recovery: two (or more) modules on the same address

If addresses ever collide (the classic symptom: a button reads stuck-on,
LEDs won't clear, or the scanner shows fewer Buttons than are attached),
use the `recovery-changer` app (`dist/recovery-changer.zip`): attach **one
module alone**, set its
`NEW_ADDR` to where that module belongs (`0x3E` / `0x40`; the one that
should be #2 needs no run if it's already at `0x3F`), Run, persistence-check,
repeat per module. Finish with the disarm + full-chain verify (steps 5–6).

## Notes

- The address is stored in the module's own flash (non-volatile) — this is
  a once-per-unit operation. Label the modules so units don't get mixed.
- Distance, Thermo, and Movement modules have hardware-fixed addresses and
  cannot be changed.
- If App Lab can't see the board (kiosk image flips USB-C to host mode on
  boot): see "USB host mode" in the main README — role flip to `device`
  **plus** `systemctl restart adbd`.
