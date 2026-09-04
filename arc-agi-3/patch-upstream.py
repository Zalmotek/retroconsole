#!/usr/bin/env python3
"""Add gamepad and fullscreen support to the upstream ARC-AGI-3 player.

The upstream project (github.com/aashen1/arc-agi-3-local-play) targets a
desktop with a keyboard and a mouse. The console has neither. This script
edits the checkout in place so that:

  * every event loop reads through `human_player.gamepad`, which turns the
    Modulino Gamepad buttons into synthetic key events;
  * `ARC_FULLSCREEN=1` opens a fullscreen window and hides the cursor;
  * a corrupt user_config.json falls back to the defaults instead of raising
    (upstream catches `json.JsonDecodeError`, which does not exist).

Safe to re-run. Usage: patch-upstream.py <checkout dir>
"""

import pathlib
import sys

EDITS = [
    # (file, old, new, expected count)
    (
        "human_player/__main__.py",
        "from human_player.config import (",
        "from human_player import gamepad\nfrom human_player.config import (",
        1,
    ),
    (
        "human_player/__main__.py",
        """        pygame.init()
        self.screen = pygame.display.set_mode(
            (WINDOW_WIDTH, WINDOW_HEIGHT),
            pygame.RESIZABLE,
        )
        pygame.display.set_caption("ARC-AGI-3 Human Player")""",
        """        pygame.init()
        self.fullscreen = os.getenv("ARC_FULLSCREEN", "") not in ("", "0", "false")
        self.display_flags = pygame.FULLSCREEN if self.fullscreen else pygame.RESIZABLE
        self.screen = pygame.display.set_mode(
            (0, 0) if self.fullscreen else (WINDOW_WIDTH, WINDOW_HEIGHT),
            self.display_flags,
        )
        pygame.display.set_caption("ARC-AGI-3 Human Player")
        gamepad.init()
        if self.fullscreen:
            pygame.mouse.set_visible(False)""",
        1,
    ),
    (
        "human_player/__main__.py",
        """        self.window_w = WINDOW_WIDTH
        self.window_h = WINDOW_HEIGHT
        self.scale_factor = 1.0""",
        """        self.window_w, self.window_h = self.screen.get_size()
        self.scale_factor = 1.0""",
        1,
    ),
    (
        "human_player/__main__.py",
        """                for event in pygame.event.get():
                    if event.type == pygame.QUIT:""",
        """                context = (
                    gamepad.CONTEXT_GAME if self.state == "GAME" else gamepad.CONTEXT_MENU
                )
                for event in gamepad.get_events(context):
                    if event.type == pygame.QUIT:""",
        1,
    ),
    (
        "human_player/__main__.py",
        """                        self.screen = pygame.display.set_mode(
                            (self.window_w, self.window_h),
                            pygame.RESIZABLE,
                        )""",
        """                        self.screen = pygame.display.set_mode(
                            (self.window_w, self.window_h),
                            self.display_flags,
                        )""",
        1,
    ),
    # The resume, completed and level-select prompts each run their own event
    # loop, so they need the bridge too or the pad goes dead on those screens.
    (
        "human_player/__main__.py",
        "        for event in pygame.event.get():",
        "        for event in gamepad.get_events(gamepad.CONTEXT_PROMPT):",
        3,
    ),
    (
        "human_player/config.py",
        "json.JsonDecodeError",
        "json.JSONDecodeError",
        1,
    ),
]


def main() -> int:
    root = pathlib.Path(sys.argv[1]).resolve()
    changed = 0
    for name, old, new, count in EDITS:
        path = root / name
        text = path.read_text(encoding="utf-8")
        if new in text:
            continue  # already applied
        found = text.count(old)
        if found != count:
            print(
                f"error: {name}: expected {count} match(es) of the upstream text, "
                f"found {found}. Upstream has changed; update patch-upstream.py.",
                file=sys.stderr,
            )
            return 1
        path.write_text(text.replace(old, new), encoding="utf-8")
        changed += 1
    print(f"patched {changed} edit(s)" if changed else "already patched")
    return 0


if __name__ == "__main__":
    sys.exit(main())
