"""Gamepad support, for console builds that have no keyboard.

The console (Arduino Uno Q + Modulino Gamepad) exposes a uinput device with
11 key-only buttons and no axes. This module turns its button events into
synthetic keyboard events. Every existing menu, prompt and game handler then
works without change.

Call `get_events(context)` in place of `pygame.event.get()`. It returns the
normal event list with the gamepad buttons already translated, plus the
auto-repeat events for a held direction button.

Button indices follow the SDL2 evdev order. SDL scans key codes upwards from
BTN_JOYSTICK (0x120), so the pad reports

    0:A  1:B  2:X  3:Y  4:L1  5:Select  6:Start
    7:DPad-Up  8:DPad-Down  9:DPad-Left  10:DPad-Right

This is the same order the RetroArch autoconfig for this pad uses.
"""

import pygame
from arcengine import GameAction

from human_player.config import get_keymap

BTN_A = 0
BTN_B = 1
BTN_X = 2
BTN_Y = 3
BTN_L1 = 4
BTN_SELECT = 5
BTN_START = 6
BTN_UP = 7
BTN_DOWN = 8
BTN_LEFT = 9
BTN_RIGHT = 10

CONTEXT_MENU = "menu"
CONTEXT_GAME = "game"
CONTEXT_PROMPT = "prompt"

DIRECTIONS = {
    BTN_UP: pygame.K_UP,
    BTN_DOWN: pygame.K_DOWN,
    BTN_LEFT: pygame.K_LEFT,
    BTN_RIGHT: pygame.K_RIGHT,
}

# Menus: list navigation and confirm/cancel.
MENU_KEYS = {
    **DIRECTIONS,
    BTN_A: pygame.K_RETURN,
    BTN_B: pygame.K_ESCAPE,
    BTN_START: pygame.K_RETURN,
    BTN_SELECT: pygame.K_TAB,
}

# Resume / completed prompts, which read letter keys.
PROMPT_KEYS = {
    **DIRECTIONS,
    BTN_A: pygame.K_c,  # continue
    BTN_X: pygame.K_n,  # new game
    BTN_Y: pygame.K_l,  # level select
    BTN_B: pygame.K_ESCAPE,
    BTN_START: pygame.K_ESCAPE,
}

# In game the pad drives game actions. The key sent per action comes from the
# active keymap, so both the WASD and the arrow scheme work.
GAME_ACTIONS = {
    BTN_UP: GameAction.ACTION1,
    BTN_DOWN: GameAction.ACTION2,
    BTN_LEFT: GameAction.ACTION3,
    BTN_RIGHT: GameAction.ACTION4,
    BTN_A: GameAction.ACTION5,
    BTN_B: GameAction.ACTION7,
    BTN_X: GameAction.ACTION7,
    BTN_Y: GameAction.RESET,
}

# In game, buttons that send a fixed key instead of a game action.
GAME_KEYS = {
    BTN_START: pygame.K_ESCAPE,
}

# Buttons that auto-repeat while held.
REPEAT_BUTTONS = frozenset(DIRECTIONS)
REPEAT_DELAY_MS = 400
REPEAT_INTERVAL_MS = 120

JOY_EVENTS = frozenset(
    {
        pygame.JOYBUTTONDOWN,
        pygame.JOYBUTTONUP,
        pygame.JOYDEVICEADDED,
        pygame.JOYDEVICEREMOVED,
    }
)


class GamepadBridge:
    """Translate joystick buttons into synthetic keyboard events."""

    def __init__(self):
        self._joysticks = {}
        self._held = {}  # button index -> (key, next repeat time in ms)
        if not pygame.joystick.get_init():
            pygame.joystick.init()
        for index in range(pygame.joystick.get_count()):
            self._open(index)

    @property
    def connected(self) -> bool:
        return bool(self._joysticks)

    def _open(self, index: int):
        try:
            joystick = pygame.joystick.Joystick(index)
        except pygame.error:
            return
        self._joysticks[joystick.get_instance_id()] = joystick

    def _key_for(self, button: int, context: str):
        """Return the key a button sends, or None if it is unbound."""
        if context == CONTEXT_GAME:
            if button in GAME_KEYS:
                return GAME_KEYS[button]
            action = GAME_ACTIONS.get(button)
            if action is None:
                return None
            for key, mapped in get_keymap().items():
                if mapped == action:
                    return key
            return None
        if context == CONTEXT_PROMPT:
            return PROMPT_KEYS.get(button)
        return MENU_KEYS.get(button)

    def translate(self, event, context: str):
        """Turn one joystick event into a list of synthetic keyboard events."""
        if event.type == pygame.JOYDEVICEADDED:
            self._open(event.device_index)
            return []
        if event.type == pygame.JOYDEVICEREMOVED:
            self._joysticks.pop(event.instance_id, None)
            self._held.clear()
            return []

        if event.type == pygame.JOYBUTTONDOWN:
            key = self._key_for(event.button, context)
            if key is None:
                return []
            if event.button in REPEAT_BUTTONS:
                self._held[event.button] = (key, pygame.time.get_ticks() + REPEAT_DELAY_MS)
            return [_key_event(pygame.KEYDOWN, key)]

        if event.type == pygame.JOYBUTTONUP:
            key = self._key_for(event.button, context)
            self._held.pop(event.button, None)
            if key is None:
                return []
            return [_key_event(pygame.KEYUP, key)]

        return []

    def repeats(self):
        """Return the synthetic events due for the buttons that are held."""
        if not self._held:
            return []
        now = pygame.time.get_ticks()
        events = []
        for button, (key, due) in list(self._held.items()):
            if now < due:
                continue
            self._held[button] = (key, now + REPEAT_INTERVAL_MS)
            events.append(_key_event(pygame.KEYDOWN, key))
            events.append(_key_event(pygame.KEYUP, key))
        return events

    def clear(self):
        """Forget the held buttons. Use this when the app changes screen."""
        self._held.clear()


_bridge = None


def init() -> GamepadBridge:
    """Create the shared bridge. Safe to call more than once."""
    global _bridge
    if _bridge is None:
        _bridge = GamepadBridge()
    return _bridge


def get_events(context: str = CONTEXT_MENU):
    """Drop-in replacement for `pygame.event.get()` that adds gamepad keys."""
    raw = pygame.event.get()
    if _bridge is None:
        return raw
    out = []
    for event in raw:
        if event.type in JOY_EVENTS:
            out.extend(_bridge.translate(event, context))
        else:
            out.append(event)
    out.extend(_bridge.repeats())
    return out


def clear():
    """Forget the held buttons on the shared bridge."""
    if _bridge is not None:
        _bridge.clear()


def _key_event(event_type: int, key: int):
    return pygame.event.Event(
        event_type,
        key=key,
        mod=0,
        unicode="",
        scancode=0,
        window=None,
    )
