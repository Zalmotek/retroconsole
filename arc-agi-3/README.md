# ARC-AGI-3 on the Retro Game Console

Turn the console into a machine for the **ARC-AGI-3** benchmark — the
interactive puzzle games the ARC Prize Foundation uses to measure abstract
reasoning. You play them with the Modulino gamepad and the touchscreen.

The games give you no instructions. No tutorial, no goal text, no legend for
the colours. You work out the rules of each world by acting in it and reading
what changes. That is the whole point of the benchmark: it measures how fast a
player builds a theory from nothing. Today humans beat every frontier AI model
on it by a wide margin, and this console lets you feel exactly why.

## What you get

- **25 games**, each with several levels, downloaded once and then played
  fully offline. No account and no API key.
- **Gamepad control.** D-pad moves, A interacts, B undoes, Y resets, Start
  opens the menu. The D-pad auto-repeats when held, for menu scrolling.
- **Touch control** for the grid click action, which some games need, and for
  the menus.
- **Player profiles.** Each player keeps their own progress, level unlocks and
  statistics, so several people can share one console.
- **Replays**, saved in a lightweight JSONL log and in the official ARC-AGI-3
  recording format.
- **RetroArch stays.** Both apps sit in the dock. Tap one to play puzzles,
  tap the other for retro games.

The player is [aashen1/arc-agi-3-local-play][upstream], a Pygame front end for
the official `arc-agi` toolkit. This directory adds what the console needs:
gamepad input, fullscreen, the icon and the dock entries.

## Install

On the console, with a network connection:

```bash
git clone https://github.com/Zalmotek/retroconsole.git ~/retroconsole
cd ~/retroconsole
sudo bash install_arc_agi_3_player.sh
```

It takes about ten minutes, most of it building the Python environment. When
it finishes, tap the **ARC-AGI-3** icon in the dock.

Run `setup.sh` first if the console is new — this script assumes the DSI
panel, the gamepad daemon and the audio are already provisioned.

### Options

| Variable | Effect |
|---|---|
| `ARC_KEEP_KIOSK=1` | Keep RetroArch starting at boot. |
| `ARC_SKIP_DOWNLOAD=1` | Skip the game download, for a console with no network. Press **Sync** in the app later. |
| `ARC_APP_DIR=<path>` | Install somewhere other than `~/arc-play`. |
| `ARC_UPSTREAM_REF=<ref>` | Pin a different upstream commit or tag. |

### What it changes

- Installs the player to `~/arc-play`, in its own Python virtual environment.
  Not pixi: the upstream `pixi.toml` has no `linux-aarch64` platform, and every
  dependency ships an aarch64 wheel, so a plain venv needs no compiler.
- Adds two launchers to the XFCE dock, makes the dock 100 px tall with 80 px
  icons, and turns off autohide. On this 8-inch panel an 80 px icon is about
  10.8 mm, above the 9 mm a fingertip needs.
- Parks the RetroArch autostart as
  `~/.config/autostart/retroarch-kiosk.desktop.disabled`. Both apps want the
  whole display, so only one may start at boot. Restore the old kiosk with:

  ```bash
  mv ~/.config/autostart/retroarch-kiosk.desktop{.disabled,}
  ```

## Controls

| Button | In a menu | In a game |
|---|---|---|
| D-pad | Navigate | Move up, down, left, right |
| A | Confirm | Interact |
| B | Back | Undo |
| X | — | Undo |
| Y | — | Reset the level |
| Start | Confirm | Back to the menu |
| Touch | Tap a button | Tap the grid, for the click action |

On the resume prompt: **A** continues, **X** starts a new game, **Y** opens
level select, **B** goes back.

## Files

| File | Purpose |
|---|---|
| `gamepad.py` | Turns gamepad buttons into key events, per screen. Copied into `human_player/`. |
| `patch-upstream.py` | Adds the gamepad and fullscreen hooks to the upstream checkout. Idempotent, and it stops with a clear message if upstream has moved. |
| `arc-play.sh` | The launcher. Sets an absolute `ENVIRONMENTS_DIR`, forces fullscreen, stops the screen blanking. |
| `panel-launchers/` | The two dock entries. |
| `icons/` | The ARC Prize mark, 16 to 256 px. |

[upstream]: https://github.com/aashen1/arc-agi-3-local-play
