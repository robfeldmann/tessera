"""Colour maths and role resolution of `design/tokens.md`.

`Theme` computes the blend and contrast rules ("Blend and contrast rules" in tokens.md,
the reference algorithm) from a theme's `fg`, `bg` and 16 slots; `resolve` turns one
styled-grid legend spec (`fg=ROLE bg=ROLE attributes`) into a `Style` for one of the three
tiers of tokens.md "Tiers":

- `derived`: the terminal answered the colour queries; roles are blends and guarded hues.
- `slots`: no answer; ANSI slots plus the attributes dim, reverse and bold. The slot pair is
  the unmeasured choice (bright on dark themes, normal on light ones).
- `nocolor`: `NO_COLOR`; attributes only.

Every value tokens.md lists under "Reference values" comes from the `Theme` attributes
and methods below: `fill8`/`fill12`/`fill16`, `ink2`/`ink3`, `hue(n)`, `faint`, `on` and
`syntax16`.
"""

from __future__ import annotations

import json
import re
from dataclasses import dataclass
from pathlib import Path

RGB = tuple[int, int, int]
THEMES_FILE = Path(__file__).with_name("themes.json")
TIERS = (
    ("derived", "Derived"),
    ("slots", "Slots"),
    ("nocolor", "NO_COLOR"),
)


def hx(text: str) -> RGB:
    text = text.lstrip("#")
    return (int(text[0:2], 16), int(text[2:4], 16), int(text[4:6], 16))


def hs(color: RGB) -> str:
    return f"#{color[0]:02x}{color[1]:02x}{color[2]:02x}"


def mix(a: RGB, b: RGB, percent: int) -> RGB:
    """`b` at `percent` opacity over `a`, per channel, exact integer arithmetic."""
    return tuple(  # type: ignore[return-value]
        (x * (100 - percent) + y * percent + 50) // 100 for x, y in zip(a, b)
    )


def _linear(value: int) -> float:
    s = value / 255
    return s / 12.92 if s <= 0.04045 else ((s + 0.055) / 1.055) ** 2.4


def luminance(c: RGB) -> float:
    return 0.2126 * _linear(c[0]) + 0.7152 * _linear(c[1]) + 0.0722 * _linear(c[2])


def contrast(a: RGB, b: RGB) -> float:
    ya, yb = luminance(a), luminance(b)
    return (max(ya, yb) + 0.05) / (min(ya, yb) + 0.05)


# Hue roles name the normal slot `n` of their pair; the bright slot is `n + 8`.
PAIR = {
    "accent": 6,
    "info": 4,
    "success": 2,
    "warning": 3,
    "error": 1,
    "destructive": 1,
    "syntax.keyword": 6,
    "syntax.string": 2,
    "syntax.constant": 5,
    "syntax.type": 3,
    "syntax.function": 4,
}
SYNTAX_HUES = ("syntax.keyword", "syntax.string", "syntax.constant", "syntax.type",
               "syntax.function")
NEUTRAL_SOLID = ("secondary", "disabled", "border")
FILL_ROLES = ("surface", "hover", "selection.fill", "selection.inactive", "disabled.fill")
BAR_GLYPHS = "▌>"  # selection.bar in Unicode and Nerd Font, and in ASCII


@dataclass(frozen=True)
class Hue:
    color: RGB
    slot: int  # the slot of the pair that was picked
    q: int  # guard step: percent mixed toward the pole


class Theme:
    """One theme with every derived value of the reference algorithm."""

    def __init__(self, name: str, spec: dict) -> None:
        self.name = name
        self.id = re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-")
        self.source = spec.get("source", "")
        self.fg = hx(spec["foreground"])
        self.bg = hx(spec["background"])
        self.slots = [hx(color) for color in spec["palette"]]
        self.light = (luminance(self.bg) + 0.05) ** 2 > 1.05 * 0.05
        self.pole: RGB = (0, 0, 0) if self.light else (255, 255, 255)
        self.fill8 = mix(self.bg, self.fg, 8)
        self.fill12 = mix(self.bg, self.fg, 12)
        self.fill16 = mix(self.bg, self.fg, 16)
        self.ink2, self.ink2_p = self._ink(60, 4.5)
        self.ink3, self.ink3_p = self._ink(45, 3.0)
        self._hues: dict[int, Hue] = {}

    # Reference algorithm ----------------------------------------------------------------

    def _ink(self, start: int, floor: float) -> tuple[RGB, int]:
        for p in range(start, 101, 5):
            color = mix(self.bg, self.fg, p)
            if contrast(color, self.bg) >= floor:
                return color, p
        return self.fg, 100

    def pick(self, n: int) -> int:
        """The slot of pair `n`: the one with more contrast against `bg`; a tie takes the
        bright slot on dark and the normal slot on light."""
        normal, bright = contrast(self.slots[n], self.bg), contrast(self.slots[n + 8], self.bg)
        if normal != bright:
            return n if normal > bright else n + 8
        return n if self.light else n + 8

    def hue(self, n: int) -> Hue:
        """The pair's colour mixed toward the pole until it reaches 4.5:1 against `bg` and
        `fill16`; `q` = 100 when nothing passes."""
        if n not in self._hues:
            slot = self.pick(n)
            c = self.slots[slot]
            for q in range(0, 101, 5):
                x = mix(c, self.pole, q)
                if min(contrast(x, self.bg), contrast(x, self.fill16)) >= 4.5:
                    self._hues[n] = Hue(x, slot, q)
                    break
            else:
                self._hues[n] = Hue(mix(c, self.pole, 100), slot, 100)
        return self._hues[n]

    def faint(self, color: RGB) -> RGB:
        return mix(self.bg, color, 16)

    def on(self, fill: RGB) -> RGB:
        """The `contrast` label colour on a solid fill: `bg` or `fg`, whichever reads better."""
        return self.bg if contrast(self.bg, fill) >= contrast(self.fg, fill) else self.fg

    def syntax16(self, n: int) -> RGB | None:
        """A syntax hue at `ansi16` depth with every slot measured; None means it falls to
        `syntax.plain` because its slot reaches less than 3:1 against `bg`."""
        slot = self.slots[self.pick(n)]
        return slot if contrast(slot, self.bg) >= 3.0 else None

    # Derived tier -----------------------------------------------------------------------

    def derived(self, role: str) -> RGB | None:
        """A role's colour in the derived tier; None when `role` is not a colour role."""
        if role in ("primary", "default", "focus", "syntax.plain"):
            return self.fg
        if role in ("secondary", "syntax.comment", "syntax.punctuation"):
            return self.ink2
        if role in ("border", "disabled", "disabled.label"):
            return self.ink3
        if role in PAIR:
            return self.hue(PAIR[role]).color
        if role in ("surface", "disabled.fill"):
            return self.fill8
        if role == "hover":
            return self.fill12
        if role == "selection.inactive":
            return self.fill16
        if role == "selection.fill":
            return self.faint(self.hue(PAIR["accent"]).color)
        if (inner := faint_of(role)) is not None:
            base = self.derived(inner)
            return None if base is None else self.faint(base)
        return None


def faint_of(role: str) -> str | None:
    if role.startswith("faint(") and role.endswith(")"):
        return role[6:-1]
    return None


def load_themes(path: Path = THEMES_FILE) -> list[Theme]:
    return [Theme(name, spec) for name, spec in json.loads(path.read_text()).items()]


# Legend specs --------------------------------------------------------------------------------
#
# The grammar of design/README.md, linted by scripts/check-wireframes.py:
# `L  fg=ROLE bg=ROLE attribute...[ -- description]`. The gallery reads it the same way and
# collects what it cannot resolve in `Spec.problems` so a page can show it, never guessing.

ATTRIBUTES = {"bold", "dim", "italic", "underline", "strikethrough", "reverse"}
# The roles of tokens.md "Roles" that a legend may name (`faint(R)` of any of them too);
# scripts/test_check_wireframes.py keeps this set equal to the tables of tokens.md.
ROLES = frozenset(
    {"primary", "secondary", "border", "disabled", "focus", "contrast", "disabled.label",
     "syntax.plain", "syntax.comment", "syntax.punctuation", *PAIR, *FILL_ROLES}
)
DESCRIPTION = re.compile(r"(?:^| )--(?: |$)")  # ` -- ` opens the free-text description


def split_description(text: str) -> tuple[str, str | None]:
    """A legend entry's `SPEC` and its free-text description (None without ` -- `)."""
    divider = DESCRIPTION.search(text)
    if divider is None:
        return text, None
    return text[: divider.start()], text[divider.end() :].strip()


def is_role(name: str) -> bool:
    """A role of tokens.md, or `faint(R)` with `R` a role."""
    inner = faint_of(name)
    return (name if inner is None else inner) in ROLES


@dataclass(frozen=True)
class Spec:
    fg: str | None
    bg: str | None
    attrs: frozenset[str]
    problems: tuple[str, ...] = ()  # what the grammar rejected; the page shows these


_specs: dict[str, Spec] = {}


def parse_spec(text: str) -> Spec:
    """Reads a legend entry's `SPEC[ -- description]`, such as `fg=contrast bg=accent bold`.
    The description is dropped. A token the grammar does not know, a role that tokens.md
    does not define, and a repeated `fg=` or `bg=` come back in `problems` and change
    nothing else about the style."""
    if text in _specs:
        return _specs[text]
    fg = bg = None
    attrs: set[str] = set()
    problems: list[str] = []
    for token in split_description(text)[0].split():
        key, sep, value = token.partition("=")
        if sep and key in ("fg", "bg"):
            if (fg if key == "fg" else bg) is not None:
                problems.append(f"`{key}=` appears twice")
            if not is_role(value):
                problems.append(f"unknown role `{value}` in `{token}`")
            elif key == "fg":
                fg = value
            else:
                bg = value
        elif not sep and token in ATTRIBUTES:
            attrs.add(token)
        elif token != "default":
            problems.append(f"unknown token `{token}`")
    _specs[text] = Spec(fg, bg, frozenset(attrs), tuple(problems))
    return _specs[text]


# Resolution ----------------------------------------------------------------------------------


@dataclass
class Style:
    """A cell style before reverse video: `fg`/`bg` None mean the terminal defaults."""

    fg: RGB | None = None
    bg: RGB | None = None
    fg_slot: int | None = None
    bg_slot: int | None = None
    bold: bool = False
    dim: bool = False
    italic: bool = False
    underline: bool = False
    strike: bool = False
    reverse: bool = False
    blank: bool = False  # drawn in the background colour: caps with no fill to cap

    def attributes(self) -> list[str]:
        names = ("bold", "dim", "italic", "underline", "reverse")
        return [name for name in names if getattr(self, name)] + (
            ["strikethrough"] if self.strike else []
        )


@dataclass(frozen=True)
class Paint:
    """What a cell looks like on screen: colours as hex, `bg` None for the page colour."""

    fg: str
    bg: str | None
    bold: bool
    dim: bool
    italic: bool
    underline: bool
    strike: bool


def paint(theme: Theme, style: Style) -> Paint:
    fg = style.fg or theme.fg
    bg = style.bg or theme.bg
    if style.reverse:
        fg, bg = bg, fg
    if style.blank:
        fg = bg
    return Paint(
        hs(fg),
        None if bg == theme.bg else hs(bg),
        style.bold,
        style.dim,
        style.italic,
        style.underline,
        style.strike,
    )


def resolve(theme: Theme, spec_text: str, tier: str, glyph: str = "",
            run_start: bool = True) -> Style:
    """The style of one legend spec in `tier`. `glyph` and `run_start` (the cell opens a
    run of equal backgrounds) find the selection bar, which never takes a reverse-video
    fill (tokens.md "Selection")."""
    spec = parse_spec(spec_text)
    if tier == "derived":
        style = _derived(theme, spec)
    elif tier == "slots":
        style = _slots(theme, spec, glyph, run_start)
    else:
        style = _nocolor(spec, glyph, run_start)
    style.italic |= "italic" in spec.attrs or spec.fg == "syntax.comment"
    style.underline |= "underline" in spec.attrs
    style.strike |= "strikethrough" in spec.attrs
    style.dim |= "dim" in spec.attrs
    style.bold |= "bold" in spec.attrs
    style.reverse |= "reverse" in spec.attrs
    return style


def _derived(t: Theme, spec: Spec) -> Style:
    style = Style(bg=t.derived(spec.bg) if spec.bg else None)
    if spec.fg == "contrast":
        style.fg = t.on(style.bg or t.bg)
        style.bold = True
    elif spec.fg:
        style.fg = t.derived(spec.fg)
        style.bold = spec.fg == "focus"
    return style


def _bar(spec: Spec, glyph: str, run_start: bool) -> bool:
    """The selection bar: `▌` (`>` in ASCII) opening a run of `selection.fill`."""
    return spec.bg == "selection.fill" and glyph != "" and glyph in BAR_GLYPHS and run_start


def _is_solid(bg: str | None) -> bool:
    return bg is not None and (bg in PAIR or bg in ("primary", "focus", "default")
                               or bg in NEUTRAL_SOLID)


def _slots(t: Theme, spec: Spec, glyph: str, run_start: bool) -> Style:
    style = Style()
    dark = not t.light
    pair_offset = 8 if dark else 0
    bg, role = spec.bg, spec.fg

    def ansi(slot: int) -> None:
        style.fg, style.fg_slot = t.slots[slot], slot

    if _is_solid(bg):
        # solid(R): the role's slot as reverse video, the terminal background as the label;
        # secondary and disabled have no slot to reverse, so ANSI 8 on dark, plain reverse
        # on light.
        style.bold = True
        if bg in PAIR:
            ansi(PAIR[bg] + pair_offset)
            style.reverse = True
        elif bg in NEUTRAL_SOLID and dark:
            style.bg, style.bg_slot = t.slots[8], 8
        else:
            style.reverse = True
        return style
    if bg is not None and (faint_of(bg) is not None or bg in ("surface", "disabled.fill")):
        if dark:
            style.bg, style.bg_slot = t.slots[8], 8
    elif bg == "hover":
        style.underline = True
    elif bg == "selection.fill":
        style.reverse = not _bar(spec, glyph, run_start)
    elif bg == "selection.inactive":
        style.dim = True

    if role == "focus":
        style.bold = True
    elif role in ("secondary", "border", "disabled", "syntax.punctuation", "syntax.comment",
                  "selection.inactive"):
        style.dim = True
    elif role == "disabled.label":
        if dark:
            ansi(7)
        else:
            style.dim = True
    elif role in PAIR:
        ansi(PAIR[role] + pair_offset)
    elif role is not None and (role in FILL_ROLES or faint_of(role) is not None):
        # Caps drawn in a fill colour: ANSI 8 on dark, blank where no fill exists.
        if dark:
            ansi(8)
        else:
            style.blank = True
    return style


def _nocolor(spec: Spec, glyph: str, run_start: bool) -> Style:
    style = Style()
    bg = spec.bg
    if _is_solid(bg):
        style.reverse = style.bold = True
    elif bg is not None and faint_of(bg) is not None:
        style.reverse = True
    elif bg == "selection.fill":
        style.reverse = not _bar(spec, glyph, run_start)
    elif bg == "selection.inactive":
        style.dim = True
    elif bg == "hover":
        style.underline = True
    role = spec.fg
    if role in ("secondary", "border", "disabled", "disabled.label", "selection.inactive",
                "syntax.punctuation", "syntax.comment"):
        style.dim = True
    elif role in ("focus", "accent"):
        style.bold = True
    return style
