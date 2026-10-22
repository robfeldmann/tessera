"""Draws a catalog wireframe as SVG, cell by cell.

Backgrounds come first so wide glyphs may overflow into the next cell; block elements and
Powerline caps are exact shapes, the way terminals such as Ghostty draw them. Glyph text
uses the page's `Gallery Mono` font (a Nerd Font served by `scripts/gallery-serve.py`).
Colours come from a styled grid resolved through `colors.resolve`; a wireframe with no
styled grid draws in the theme's foreground on its background.
"""

from __future__ import annotations

import html
import unicodedata
from collections.abc import Sequence

from .catalog import StyledGrid
from .colors import BAR_GLYPHS, Paint, Style, Theme, hs, paint, parse_spec, resolve

CELL_W, CELL_H, BASELINE, PAD = 9, 18, 14, 8


def cell_width(ch: str) -> int:
    if unicodedata.combining(ch) or ch in "\u200d\ufe0f":
        return 0
    return 2 if unicodedata.east_asian_width(ch) in ("W", "F") else 1


def block_rects(ch: str) -> list[tuple[float, float, float, float, float]] | None:
    """Filled areas of a block element (U+2580-U+259F) as cell fractions plus opacity."""
    code = ord(ch)
    quad = {"tl": (0, 0, 0.5, 0.5, 1), "tr": (0.5, 0, 1, 0.5, 1),
            "bl": (0, 0.5, 0.5, 1, 1), "br": (0.5, 0.5, 1, 1, 1)}
    quads = {0x2596: "bl", 0x2597: "br", 0x2598: "tl", 0x2599: "tl bl br", 0x259A: "tl br",
             0x259B: "tl tr bl", 0x259C: "tl tr br", 0x259D: "tr", 0x259E: "tr bl",
             0x259F: "tr bl br"}
    if code == 0x2580:
        return [(0, 0, 1, 0.5, 1)]
    if 0x2581 <= code <= 0x2588:
        return [(0, 1 - (code - 0x2580) / 8, 1, 1, 1)]
    if 0x2589 <= code <= 0x258F:
        return [(0, 0, (0x2590 - code) / 8, 1, 1)]
    if code == 0x2590:
        return [(0.5, 0, 1, 1, 1)]
    if 0x2591 <= code <= 0x2593:
        return [(0, 0, 1, 1, (code - 0x2590) / 4)]
    if code == 0x2594:
        return [(0, 0, 1, 0.125, 1)]
    if code == 0x2595:
        return [(0.875, 0, 1, 1, 1)]
    if code in quads:
        return [quad[q] for q in quads[code].split()]
    return None


def powerline_path(ch: str, x: float, y: float) -> str | None:
    """Powerline caps fill the cell edge to edge; terminals such as Ghostty draw them as
    shapes rather than font glyphs, so the picture does the same."""
    w, h, mid = CELL_W, CELL_H, y + CELL_H / 2
    shapes = {
        "\ue0b0": f"M{x} {y} L{x + w} {mid} L{x} {y + h} Z",
        "\ue0b2": f"M{x + w} {y} L{x} {mid} L{x + w} {y + h} Z",
        # Round caps reach half a pixel into the neighbouring fill so the anti-aliased
        # flat side leaves no seam.
        "\ue0b4": f"M{x - 0.5} {y} L{x} {y} A{w} {h / 2} 0 0 1 {x} {y + h} L{x - 0.5} {y + h} Z",
        "\ue0b6": f"M{x + w + 0.5} {y} L{x + w} {y} A{w} {h / 2} 0 0 0 {x + w} {y + h} L{x + w + 0.5} {y + h} Z",
    }
    return shapes.get(ch)


def render(rows: Sequence[str], theme: Theme, tier: str = "derived",
           grid: StyledGrid | None = None, size: tuple[int, int] | None = None,
           label: str = "") -> str:
    """The wireframe `rows` as an inline SVG in a `.picture` div. `size` is the fence's
    declared WxH; the picture is at least that big."""
    styles = grid.styles if grid else []
    legend = grid.legend if grid else {}
    default = paint(theme, Style())
    page = hs(theme.bg)

    # Snapshots trim trailing spaces from the character grid but keep their style letters,
    # so a styled blank cell (a segment's right padding) extends the row to the style width.
    rows = [
        line + " " * max(0, len(styles[row] if row < len(styles) else "")
                         - sum(map(cell_width, line)))
        for row, line in enumerate(rows)
    ]
    columns = max([sum(cell_width(c) for c in line) for line in rows] + [size[0] if size else 0])
    height_rows = max(len(rows), size[1] if size else 0, 1)
    width, height = columns * CELL_W + 2 * PAD, height_rows * CELL_H + 2 * PAD

    painted: dict[tuple[str, str, bool], Paint] = {}
    backgrounds: list[str] = []
    glyphs: list[str] = []
    for row, line in enumerate(rows):
        style_row = styles[row] if row < len(styles) else ""
        column, y = 0, PAD + row * CELL_H
        previous_bg: str | None = None
        for ch in line:
            span = cell_width(ch)
            if span == 0:
                continue
            letter = style_row[column] if column < len(style_row) else "."
            spec = legend.get(letter, "") if letter != "." else ""
            bg_role = parse_spec(spec).bg
            run_start = bg_role != previous_bg
            previous_bg = bg_role
            key = (spec, ch if ch in BAR_GLYPHS else "", run_start)
            if key not in painted:
                painted[key] = (
                    paint(theme, resolve(theme, spec, tier, key[1], run_start))
                    if spec
                    else default
                )
            attrs = painted[key]
            x = PAD + column * CELL_W
            column += span
            if attrs.bg is not None:
                backgrounds.append(
                    f'<rect x="{x}" y="{y}" width="{span * CELL_W}" height="{CELL_H}" '
                    f'fill="{attrs.bg}"/>'
                )
            if not ch.strip():
                continue
            fill = f'fill="{attrs.fg}"' + (' fill-opacity="0.6"' if attrs.dim else "")
            if (rects := block_rects(ch)) is not None:
                for x0, y0, x1, y1, alpha in rects:
                    glyphs.append(
                        f'<rect x="{x + x0 * CELL_W:.2f}" y="{y + y0 * CELL_H:.2f}" '
                        f'width="{(x1 - x0) * CELL_W:.2f}" height="{(y1 - y0) * CELL_H:.2f}" '
                        f'{fill} opacity="{alpha}" shape-rendering="crispEdges"/>'
                    )
                continue
            if (path := powerline_path(ch, x, y)) is not None:
                glyphs.append(f'<path d="{path}" {fill}/>')
                continue
            line_glyph = "\u2500" <= ch <= "\u257f"
            extra = fill
            if attrs.bold and not line_glyph:
                extra += ' font-weight="bold"'
            if attrs.italic and not line_glyph:
                extra += ' font-style="italic"'
            decorations = [name for name, on in (("underline", attrs.underline),
                                                 ("line-through", attrs.strike)) if on]
            if decorations:
                extra += f' text-decoration="{" ".join(decorations)}"'
            glyphs.append(f'<text x="{x}" y="{y + BASELINE}" {extra}>{html.escape(ch)}</text>')
    title = f"<title>{html.escape(label)}</title>" if label else ""
    return (
        f'<div class="picture"><svg xmlns="http://www.w3.org/2000/svg" width="{width}" '
        f'height="{height}" viewBox="0 0 {width} {height}" role="img">{title}'
        f'<rect width="{width}" height="{height}" fill="{page}"/>'
        f'<g font-size="15" xml:space="preserve"><g shape-rendering="crispEdges">'
        f'{"".join(backgrounds)}</g>{"".join(glyphs)}</g>'
        f"</svg></div>"
    )
