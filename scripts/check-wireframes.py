#!/usr/bin/env python3
"""Validate fixture-grade wireframes and styled grids in the design catalog.

A wireframe is a fenced code block whose info string is `wireframe WxH` with an optional
`id=NAME` (for example ```wireframe 46x9 id=anatomy). The contract, defined in
design/README.md, is:

- exactly H lines between the fences
- every line's display width is <= W (rows are trailing-trimmed)
- no trailing whitespace, no tab characters
- `NAME` matches [a-z0-9]+(-[a-z0-9]+)* and is unique within its doc; it never collides
  with the position-based identity (the 0-based fence index) of an id-less wireframe

Display width uses East Asian Width (F/W count as 2) and skips combining
marks, matching the naive-but-honest width model wireframes are drawn
against.

A styled grid is a `text` fence whose body starts with `── chars ──`, then `── style ──`,
then `── legend ──`. It belongs to the nearest preceding wireframe and its chars rows
must equal that wireframe's rows, unless the fence opens with ```text standalone. Style
rows use one letter per display cell (`.` is the default style), may be shorter than the
chars row, and are at most as wide as the wireframe. Legend lines are
`L  fg=ROLE bg=ROLE attribute...[ -- description]` with roles from design/tokens.md
`## Roles`. Every style letter is defined and every legend letter is used.

Usage:

    scripts/check-wireframes.py [paths...]

Paths may be markdown files or directories (searched recursively for
*.md). Defaults to `design/`. Exits non-zero on any violation.
"""

from __future__ import annotations

import functools
import re
import sys
import unicodedata
from pathlib import Path
from typing import NamedTuple

FENCE_RE = re.compile(r"^(`{3,}|~{3,})\s*(\S*)\s*(.*)$")
SIZE_RE = re.compile(r"^(\d+)x(\d+)$")
ID_RE = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
SECTION_RE = re.compile(r"^── ([a-z]+) ──$")
LEGEND_RE = re.compile(r"^(\S)  (\S.*)$")
GRID_SECTIONS = ("chars", "style", "legend")
ATTRIBUTES = ("bold", "dim", "italic", "underline", "reverse", "strikethrough")
TOKENS_PATH = Path(__file__).resolve().parent.parent / "design" / "tokens.md"


def _is_variation_selector(ch: str) -> bool:
    code_point = ord(ch)
    return 0xFE00 <= code_point <= 0xFE0F or 0xE0100 <= code_point <= 0xE01EF


def _is_emoji_modifier(ch: str) -> bool:
    return 0x1F3FB <= ord(ch) <= 0x1F3FF


def _is_regional_indicator(ch: str) -> bool:
    return 0x1F1E6 <= ord(ch) <= 0x1F1FF


def _is_grapheme_extension(ch: str) -> bool:
    return (
        unicodedata.category(ch) in ("Mn", "Mc", "Me")
        or _is_variation_selector(ch)
        or _is_emoji_modifier(ch)
    )


def _graphemes(text: str) -> list[str]:
    """Split text into the extended grapheme clusters wireframes need."""
    clusters: list[str] = []
    cluster: list[str] = []
    join_next = False
    regional_indicator_count = 0

    for ch in text:
        if not cluster:
            cluster.append(ch)
            regional_indicator_count = 1 if _is_regional_indicator(ch) else 0
            continue
        if ch == "\u200d":
            cluster.append(ch)
            join_next = True
            regional_indicator_count = 0
            continue
        if _is_grapheme_extension(ch):
            cluster.append(ch)
            continue
        if join_next:
            cluster.append(ch)
            join_next = False
            regional_indicator_count = 1 if _is_regional_indicator(ch) else 0
            continue
        if _is_regional_indicator(ch) and regional_indicator_count == 1:
            cluster.append(ch)
            regional_indicator_count = 2
            continue

        clusters.append("".join(cluster))
        cluster = [ch]
        regional_indicator_count = 1 if _is_regional_indicator(ch) else 0

    if cluster:
        clusters.append("".join(cluster))
    return clusters


def _is_emoji_presentation(ch: str) -> bool:
    """Cover the modern emoji blocks without mistaking ASCII symbols for emoji."""
    return 0x1F000 <= ord(ch) <= 0x1FAFF


def _cluster_width(cluster: str) -> int:
    base = next(
        (
            ch
            for ch in cluster
            if ch != "\u200d" and not _is_grapheme_extension(ch)
        ),
        None,
    )
    if base is None:
        return 0
    if (
        "\u200d" in cluster
        or "\ufe0f" in cluster
        or "\u20e3" in cluster
        or _is_emoji_presentation(base)
    ):
        return 2
    return 2 if unicodedata.east_asian_width(base) in ("F", "W") else 1


def display_width(line: str) -> int:
    return sum(_cluster_width(cluster) for cluster in _graphemes(line))


# Connections use terminal display cells, not source-string indexes.  The mapping
# deliberately covers only the box-drawing vocabulary that the catalog uses; ASCII
# punctuation is ordinary content and is not geometry.
CONNECTIONS: dict[str, frozenset[str]] = {
    # Light (also the straight edges used with rounded corners).
    "─": frozenset("EW"),
    "│": frozenset("NS"),
    "┌": frozenset("ES"),
    "┐": frozenset("SW"),
    "└": frozenset("NE"),
    "┘": frozenset("NW"),
    "├": frozenset("NES"),
    "┤": frozenset("NSW"),
    "┬": frozenset("ESW"),
    "┴": frozenset("NEW"),
    "┼": frozenset("NESW"),
    # Rounded.
    "╭": frozenset("ES"),
    "╮": frozenset("SW"),
    "╰": frozenset("NE"),
    "╯": frozenset("NW"),
    # Heavy.
    "━": frozenset("EW"),
    "┃": frozenset("NS"),
    "┏": frozenset("ES"),
    "┓": frozenset("SW"),
    "┗": frozenset("NE"),
    "┛": frozenset("NW"),
    "┣": frozenset("NES"),
    "┫": frozenset("NSW"),
    "┳": frozenset("ESW"),
    "┻": frozenset("NEW"),
    "╋": frozenset("NESW"),
    # Double.
    "═": frozenset("EW"),
    "║": frozenset("NS"),
    "╔": frozenset("ES"),
    "╗": frozenset("SW"),
    "╚": frozenset("NE"),
    "╝": frozenset("NW"),
    "╠": frozenset("NES"),
    "╣": frozenset("NSW"),
    "╦": frozenset("ESW"),
    "╩": frozenset("NEW"),
    "╬": frozenset("NESW"),
}

TOP_LEFT_CORNERS = frozenset("┌╭┏╔")
TOP_RIGHT_CORNERS = frozenset("┐╮┓╗")
BOTTOM_LEFT_CORNERS = frozenset("└╰┗╚")
BOTTOM_RIGHT_CORNERS = frozenset("┘╯┛╝")
SUPPORTED_CORNERS = (
    TOP_LEFT_CORNERS
    | TOP_RIGHT_CORNERS
    | BOTTOM_LEFT_CORNERS
    | BOTTOM_RIGHT_CORNERS
)


FULL_CAPABILITY_INDICATORS = frozenset("│┃█")
ASCII_INDICATORS = frozenset("|#")
# A scroll indicator placed in a box's border draws its thumb in the edge column, so
# these glyphs continue a vertical edge. They never start one: a solid bar elsewhere in a
# grid is not a broken edge.
EDGE_THUMBS = frozenset("█▐▌")
DIRECTION_OFFSETS = {
    "N": (-1, 0),
    "E": (0, 1),
    "S": (1, 0),
    "W": (0, -1),
}
DIRECTION_NAMES = {
    "N": "north",
    "E": "east",
    "S": "south",
    "W": "west",
}
RECIPROCAL_DIRECTIONS = {
    "N": "S",
    "E": "W",
    "S": "N",
    "W": "E",
}


def display_grid(rows: list[str]) -> list[dict[int, str]]:
    """Return the cluster-start glyph at each 0-based terminal display column."""
    grid: list[dict[int, str]] = []
    for row in rows:
        cells: dict[int, str] = {}
        column = 0
        for cluster in _graphemes(row):
            cluster_width = _cluster_width(cluster)
            if cluster_width == 0:
                continue
            cells[column] = cluster[0]
            if cluster_width == 2:
                cells[column + 1] = ""
            column += cluster_width
        grid.append(cells)
    return grid


def _connects(ch: str | None, direction: str) -> bool:
    return direction in CONNECTIONS.get(ch or "", ())


def _continues_vertical_edge(ch: str | None, direction: str) -> bool:
    return _connects(ch, direction) or (ch in EDGE_THUMBS and direction in "NS")


def _corner_columns(cells: dict[int, str], corners: frozenset[str]) -> list[int]:
    return [column for column, ch in cells.items() if ch in corners]


def _add_geometry_error(
    errors: list[tuple[int, int, str]],
    seen: set[tuple[int, int, str]],
    row: int,
    column: int,
    message: str,
) -> None:
    error = (row, column, message)
    if error not in seen:
        errors.append(error)
        seen.add(error)


def _check_vertical_edge(
    grid: list[dict[int, str]],
    top: int,
    bottom: int,
    column: int,
    errors: list[tuple[int, int, str]],
    seen: set[tuple[int, int, str]],
) -> None:
    """Require reciprocal vertical links, and make one- or two-cell shifts useful."""
    for row in range(top, bottom):
        source = grid[row].get(column)
        below = grid[row + 1].get(column)
        if _continues_vertical_edge(source, "S") and _continues_vertical_edge(below, "N"):
            continue

        shifted_column = next(
            (
                candidate
                for distance in (1, 2)
                for candidate in (column - distance, column + distance)
                if _connects(grid[row + 1].get(candidate), "N")
            ),
            None,
        )
        if _connects(source, "S") and shifted_column is not None:
            _add_geometry_error(
                errors,
                seen,
                row,
                column,
                f"vertical edge shifts to column {shifted_column} on the next row",
            )
        else:
            _add_geometry_error(
                errors,
                seen,
                row,
                column,
                "vertical edge lacks a reciprocal connection below",
            )



def _check_shifted_vertical_connections(
    grid: list[dict[int, str]],
    errors: list[tuple[int, int, str]],
    seen: set[tuple[int, int, str]],
) -> None:
    """Catch a displaced divider without treating an endpoint as a broken box."""
    for row, cells in enumerate(grid[:-1]):
        for column, source in cells.items():
            if not _connects(source, "S") or _continues_vertical_edge(
                grid[row + 1].get(column), "N"
            ):
                continue
            shifted_column = next(
                (
                    candidate
                    for distance in (1, 2)
                    for candidate in (column - distance, column + distance)
                    if _connects(grid[row + 1].get(candidate), "N")
                ),
                None,
            )
            if shifted_column is not None:
                _add_geometry_error(
                    errors,
                    seen,
                    row,
                    column,
                    f"vertical edge shifts to column {shifted_column} on the next row",
                )



def _last_non_space_cell(cells: dict[int, str]) -> tuple[int, str] | None:
    for column in sorted(cells, reverse=True):
        glyph = cells[column]
        if glyph not in ("", " "):
            return column, glyph
    return None


def _same_indicator_family(first: str, second: str) -> bool:
    return (
        first in FULL_CAPABILITY_INDICATORS and second in FULL_CAPABILITY_INDICATORS
    ) or (first in ASCII_INDICATORS and second in ASCII_INDICATORS)


def _check_trailing_indicator_continuity(
    grid: list[dict[int, str]],
    errors: list[tuple[int, int, str]],
    seen: set[tuple[int, int, str]],
) -> None:
    """Require compatible trailing scrollbar glyphs to keep their display column."""
    for row, cells in enumerate(grid[:-1]):
        current = _last_non_space_cell(cells)
        following = _last_non_space_cell(grid[row + 1])
        if (
            current is None
            or following is None
            or not _same_indicator_family(current[1], following[1])
            or current[0] == following[0]
        ):
            continue
        _add_geometry_error(
            errors,
            seen,
            row,
            current[0],
            f"trailing indicator shifts to column {following[0]} on the next row",
        )


def _check_junction_reciprocity(
    grid: list[dict[int, str]],
    network_bounds: list[tuple[int, int, int, int]],
    errors: list[tuple[int, int, str]],
    seen: set[tuple[int, int, str]],
) -> None:
    """Check declared junction arms when enough reciprocal neighbors establish geometry."""
    for row, cells in enumerate(grid):
        for column, glyph in cells.items():
            connections = CONNECTIONS.get(glyph, frozenset())
            if len(connections) < 3:
                continue
            inside_network = any(
                top <= row <= bottom and left <= column <= right
                for top, left, bottom, right in network_bounds
            )

            reciprocal_directions = [
                direction
                for direction in "NESW"
                if direction in connections
                and _connects(
                    grid[row + DIRECTION_OFFSETS[direction][0]].get(
                        column + DIRECTION_OFFSETS[direction][1]
                    )
                    if 0 <= row + DIRECTION_OFFSETS[direction][0] < len(grid)
                    else None,
                    RECIPROCAL_DIRECTIONS[direction],
                )
            ]
            minimum_reciprocals = 2 if inside_network else 3
            if len(reciprocal_directions) < minimum_reciprocals:
                continue
            for direction in "NESW":
                if direction in connections and direction not in reciprocal_directions:
                    _add_geometry_error(
                        errors,
                        seen,
                        row,
                        column,
                        f"junction lacks a reciprocal connection {DIRECTION_NAMES[direction]}",
                    )

def _check_bottom_edge(
    grid: list[dict[int, str]],
    row: int,
    left: int,
    right: int,
    errors: list[tuple[int, int, str]],
    seen: set[tuple[int, int, str]],
) -> None:
    for column in range(left, right):
        current = grid[row].get(column)
        following = grid[row].get(column + 1)
        if _connects(current, "E") and _connects(following, "W"):
            continue
        _add_geometry_error(
            errors,
            seen,
            row,
            column,
            "bottom edge lacks a reciprocal horizontal connection",
        )

def _has_reciprocal_vertical_edge(
    grid: list[dict[int, str]], top: int, bottom: int, column: int
) -> bool:
    return all(
        _continues_vertical_edge(grid[row].get(column), "S")
        and _continues_vertical_edge(grid[row + 1].get(column), "N")
        for row in range(top, bottom)
    )


def _has_reciprocal_horizontal_edge(
    grid: list[dict[int, str]], row: int, left: int, right: int
) -> bool:
    return all(
        _connects(grid[row].get(column), "E")
        and _connects(grid[row].get(column + 1), "W")
        for column in range(left, right)
    )


def check_wireframe_geometry(rows: list[str], first_markdown_line: int) -> list[str]:
    """Validate closed Unicode boxes and return line/terminal-column diagnostics.

    The validator intentionally starts from supported top-left corners.  It therefore
    does not try to turn divider samples or ASCII art into boxes, and top borders may
    contain a title or other text.  Bottom and side edges are stricter because they are
    the unambiguous closure of a detected box.
    """
    grid = display_grid(rows)
    errors: list[tuple[int, int, str]] = []
    seen: set[tuple[int, int, str]] = set()
    matched_corners: set[tuple[int, int]] = set()
    network_bounds: list[tuple[int, int, int, int]] = []
    _check_shifted_vertical_connections(grid, errors, seen)
    _check_trailing_indicator_continuity(grid, errors, seen)

    for top, cells in enumerate(grid):
        for left in _corner_columns(cells, TOP_LEFT_CORNERS):
            right_corners = [
                column
                for column in _corner_columns(cells, TOP_RIGHT_CORNERS)
                if column > left
            ]
            full_boxes: list[tuple[int, int]] = []
            for right in right_corners:
                for bottom in range(top + 1, len(grid)):
                    if (
                        grid[bottom].get(left) in BOTTOM_LEFT_CORNERS
                        and grid[bottom].get(right) in BOTTOM_RIGHT_CORNERS
                    ):
                        full_boxes.append((bottom, right))

            if full_boxes:
                bottom, right = min(
                    full_boxes,
                    key=lambda candidate: (
                        (candidate[0] - top) * (candidate[1] - left),
                        candidate[1],
                        candidate[0],
                    ),
                )
                matched_corners.update(
                    {(top, left), (top, right), (bottom, left), (bottom, right)}
                )
                network_bounds.append((top, left, bottom, right))
                _check_vertical_edge(grid, top, bottom, left, errors, seen)
                _check_vertical_edge(grid, top, bottom, right, errors, seen)
                _check_bottom_edge(grid, bottom, left, right, errors, seen)
                continue

            missing_top_right_boxes: list[tuple[int, int]] = []
            for bottom in range(top + 2, len(grid)):
                if grid[bottom].get(left) not in BOTTOM_LEFT_CORNERS:
                    continue
                for right in _corner_columns(grid[bottom], BOTTOM_RIGHT_CORNERS):
                    if (
                        right > left
                        and grid[top].get(right) not in TOP_RIGHT_CORNERS
                        and _has_reciprocal_vertical_edge(grid, top, bottom, left)
                        and _connects(grid[top + 1].get(right), "N")
                        and _has_reciprocal_vertical_edge(grid, top + 1, bottom, right)
                        and _has_reciprocal_horizontal_edge(grid, bottom, left, right)
                    ):
                        missing_top_right_boxes.append((bottom, right))
            if missing_top_right_boxes:
                bottom, right = min(
                    missing_top_right_boxes,
                    key=lambda candidate: (
                        (candidate[0] - top) * (candidate[1] - left),
                        candidate[1],
                        candidate[0],
                    ),
                )
                matched_corners.update({(top, left), (bottom, left), (bottom, right)})
                network_bounds.append((top, left, bottom, right))
                _add_geometry_error(
                    errors,
                    seen,
                    top,
                    right,
                    f"box top-right corner is missing at column {right}",
                )
                continue

            partial_boxes: list[tuple[int, int]] = []
            for right in right_corners:
                for bottom in range(top + 1, len(grid)):
                    if grid[bottom].get(left) in BOTTOM_LEFT_CORNERS:
                        partial_boxes.append((bottom, right))
            if not right_corners:
                continue
            if not partial_boxes:
                right = min(right_corners)
                matched_corners.update({(top, left), (top, right)})
                _add_geometry_error(
                    errors,
                    seen,
                    top,
                    left,
                    "box top-left corner has no matching bottom-left corner",
                )
                continue

            bottom, right = min(
                partial_boxes,
                key=lambda candidate: (candidate[0] - top, candidate[1] - left),
            )
            matched_corners.update({(top, left), (top, right), (bottom, left)})
            network_bounds.append((top, left, bottom, right))
            _check_vertical_edge(grid, top, bottom, left, errors, seen)
            _check_vertical_edge(grid, top, bottom, right, errors, seen)
            nearby_corner = next(
                (
                    column
                    for distance in (0, 1, 2)
                    for column in (
                        (right,) if distance == 0 else (right - distance, right + distance)
                    )
                    if grid[bottom].get(column) in SUPPORTED_CORNERS
                ),
                None,
            )
            if nearby_corner is not None:
                matched_corners.add((bottom, nearby_corner))
                detail = f"; found corner at column {nearby_corner}" if nearby_corner != right else ""
            else:
                detail = ""
            _add_geometry_error(
                errors,
                seen,
                bottom,
                right,
                f"box bottom-right corner is missing at column {right}{detail}",
            )

    _check_junction_reciprocity(grid, network_bounds, errors, seen)

    for row, cells in enumerate(grid):
        for column, ch in cells.items():
            if (
                ch in SUPPORTED_CORNERS
                and (row, column) not in matched_corners
                and any(
                    top <= row <= bottom and left <= column <= right
                    for top, left, bottom, right in network_bounds
                )
            ):
                _add_geometry_error(
                    errors,
                    seen,
                    row,
                    column,
                    "orphan box corner in a detected box network",
                )

    return [
        f"line {first_markdown_line + row} column {column}: {message}"
        for row, column, message in sorted(errors)
    ]


class Fence(NamedTuple):
    line: int  # 1-based line of the opening fence
    marker: str
    info: str
    rest: str
    body: list[str]
    closed: bool


def parse_fences(lines: list[str]) -> list[Fence]:
    """Every fenced block of a document, in order.

    Fences start in column 0. A closing fence repeats the opening character at least as
    many times and has no info string, so a fence nested in a longer one is body text.
    """
    fences: list[Fence] = []
    index = 0
    while index < len(lines):
        match = FENCE_RE.match(lines[index])
        index += 1
        if match is None:
            continue
        marker, info, rest = match.groups()
        opening = index
        body: list[str] = []
        closed = False
        while index < len(lines):
            closing = FENCE_RE.match(lines[index])
            index += 1
            if (
                closing is not None
                and closing.group(1)[0] == marker[0]
                and len(closing.group(1)) >= len(marker)
                and not closing.group(2)
                and not closing.group(3)
            ):
                closed = True
                break
            body.append(lines[index - 1])
        fences.append(Fence(opening, marker, info, rest.strip(), body, closed))
    return fences


class RoleTableError(Exception):
    """design/tokens.md has no readable `## Roles` tables."""


@functools.cache
def load_roles(tokens: Path = TOKENS_PATH) -> frozenset[str]:
    """The role names a legend may use: the backticked first column of the role tables
    (`Role` and `Style` columns) under `## Roles` in tokens.md. `solid(R)` and `faint(R)`
    are functions of a role, not roles; a legend spells the first `fg=contrast bg=R bold`
    and the second `faint(R)`."""
    try:
        lines = tokens.read_text(encoding="utf-8").splitlines()
    except OSError as error:
        raise RoleTableError(f"cannot read {tokens}: {error}") from error
    roles: set[str] = set()
    in_roles = False
    header: str | None = None  # first header cell of the table being read
    for line in lines:
        if line.startswith("## "):
            in_roles = line.rstrip() == "## Roles"
        if not in_roles:
            continue
        if not line.startswith("|"):
            header = None
            continue
        cell = line[1:].split("|", 1)[0].strip()
        if header is None:
            header = cell
        elif header in ("Role", "Style"):
            name = re.fullmatch(r"`([^`]+)`", cell)
            if name and "(" not in name.group(1):
                roles.add(name.group(1))
    if not roles:
        raise RoleTableError(f"{tokens}: no roles found in the tables under `## Roles`")
    return frozenset(roles)


def is_role(name: str, roles: frozenset[str]) -> bool:
    """A role of tokens.md, or `faint(R)` with `R` a role."""
    if name.startswith("faint(") and name.endswith(")"):
        return name[6:-1] in roles
    return name in roles


# ` -- ` opens a legend entry's free-text description; so does a trailing ` --`.
DESCRIPTION_RE = re.compile(r"(?:^| )--(?: |$)")


def check_legend_spec(letter: str, text: str, roles: frozenset[str]) -> list[str]:
    """The problems of one legend entry's `SPEC[ -- description]`, as messages."""
    problems: list[str] = []
    divider = DESCRIPTION_RE.search(text)
    spec = text[: divider.start()] if divider else text
    if divider and not text[divider.end() :].strip():
        problems.append("empty description after `--`")
    tokens = spec.split()
    if not tokens:
        return [*problems, "no style before `--`"]
    if letter == ".":
        if tokens != ["default"]:
            problems.append("`.` is the default style; its entry is `.  default`")
        return problems
    seen: set[str] = set()
    for token in tokens:
        key, equals, value = token.partition("=")
        if equals and key in ("fg", "bg"):
            if key in seen:
                problems.append(f"`{key}=` appears twice")
            seen.add(key)
            if not is_role(value, roles):
                hint = (
                    "; solid(R) is written `fg=contrast bg=R bold`"
                    if value.startswith("solid(")
                    else "; roles are the `## Roles` tables of design/tokens.md"
                )
                problems.append(f"unknown role `{value}` in `{token}`{hint}")
        elif not equals and token in ATTRIBUTES:
            continue
        elif token == "default":
            problems.append("`default` is only for the `.` entry")
        else:
            problems.append(
                f"unknown token `{token}`: a spec is fg=ROLE, bg=ROLE and attributes "
                f"({', '.join(ATTRIBUTES)}); free text goes after ` -- `"
            )
    return problems


class Wireframe(NamedTuple):
    line: int  # 1-based line of the opening fence
    rows: list[str]
    width: int | None  # None when the fence header has no valid size
    id: str | None


def _row_mismatch(chars: list[str], rows: list[str]) -> tuple[int, str]:
    """Where the chars rows first differ from the wireframe rows, and how."""
    if len(chars) != len(rows):
        return 0, f"{len(chars)} chars rows but the wireframe has {len(rows)}"
    row = next(r for r, (first, second) in enumerate(zip(chars, rows)) if first != second)
    return row, f"chars row r{row} is {chars[row]!r} but the wireframe row is {rows[row]!r}"


def check_styled_grid(
    path: Path, fence: Fence, owner: Wireframe | None, roles: frozenset[str]
) -> list[str]:
    """Lint one ```text styled grid (a fence whose body starts with `── chars ──`)."""
    errors: list[str] = []
    body = fence.body
    standalone = fence.rest == "standalone"

    def error(offset: int | None, message: str) -> None:
        line = fence.line if offset is None else fence.line + 1 + offset
        errors.append(f"{path}:{line}: styled grid: {message}")

    if fence.rest not in ("", "standalone"):
        error(None, f"unexpected `{fence.rest}` after `text`; the only header word is `standalone`")

    headers = [
        (offset, match.group(1))
        for offset, line in enumerate(body)
        if (match := SECTION_RE.match(line))
    ]
    unknown = [(offset, name) for offset, name in headers if name not in GRID_SECTIONS]
    for offset, name in unknown:
        error(offset, f"unknown section `── {name} ──`; the sections are chars, style and legend")
    names = [name for _, name in headers if name in GRID_SECTIONS]
    if unknown:
        return errors
    if names != list(GRID_SECTIONS):
        found = ", ".join(f"`── {name} ──`" for name in names) or "none"
        error(
            0,
            "sections must be `── chars ──`, `── style ──` and `── legend ──`, once each "
            f"and in that order (found {found})",
        )
        return errors
    starts = {name: offset for offset, name in headers}
    chars_start = starts["chars"] + 1
    style_start = starts["style"] + 1
    legend_start = starts["legend"] + 1
    chars = body[chars_start : starts["style"]]
    styles = body[style_start : starts["legend"]]
    legend = body[legend_start:]
    trimmed = [row.rstrip() for row in chars]

    for r, row in enumerate(chars):
        if "\t" in row:
            error(chars_start + r, f"tab character in chars row r{r}")

    width: int | None = None  # the widest a style row may be; None when unbounded
    if not standalone:
        if owner is None:
            error(
                None,
                "no preceding wireframe fence; open the fence with ```text standalone "
                "if the grid illustrates no wireframe",
            )
        else:
            width = owner.width
            wanted = [row.rstrip() for row in owner.rows]
            if trimmed != wanted:
                row, detail = _row_mismatch(trimmed, wanted)
                error(
                    chars_start + row,
                    f"chars do not match the preceding wireframe at line {owner.line} "
                    f"({detail}); open the fence with ```text standalone if the grid "
                    "illustrates no wireframe",
                )

    if len(styles) > len(chars):
        error(
            style_start + len(chars),
            f"{len(styles)} style rows but only {len(chars)} chars rows",
        )
    used: dict[str, int] = {}  # style letter -> body offset of its first row
    for r, row in enumerate(styles):
        offset = style_start + r
        if width is not None and len(row) > width:
            error(offset, f"style row r{r} is {len(row)} cells wide; the wireframe is {width} wide")
        blank = next((column for column, ch in enumerate(row) if ch.isspace()), None)
        if blank is not None:
            error(
                offset,
                f"style row r{r} has whitespace at column c{blank}; write `.` for the "
                "default style (a row may end early instead)",
            )
        for ch in row:
            if not ch.isspace() and ch != ".":
                used.setdefault(ch, offset)

    defined: dict[str, int] = {}  # legend letter -> body offset of its line
    for j, line in enumerate(legend):
        offset = legend_start + j
        if not line.strip():
            error(offset, "blank line in the legend")
            continue
        match = LEGEND_RE.match(line)
        if match is None:
            error(offset, f"legend line {line!r} must be `L  SPEC`: one letter, two spaces, a spec")
            continue
        letter, text = match.groups()
        if display_width(letter) != 1:
            error(offset, f"legend letter {letter!r} must be one display cell wide")
            continue
        if letter in defined:
            error(
                offset,
                f"legend letter `{letter}` is defined twice (first at line "
                f"{fence.line + 1 + defined[letter]})",
            )
            continue
        defined[letter] = offset
        for message in check_legend_spec(letter, text, roles):
            error(offset, f"legend `{letter}`: {message}")

    for letter, offset in used.items():
        if letter not in defined:
            error(offset, f"style letter `{letter}` is not defined in the legend")
    for letter, offset in defined.items():
        if letter != "." and letter not in used:
            error(offset, f"legend letter `{letter}` is not used in the style rows")
    return errors


def check_file(path: Path, roles: frozenset[str] | None = None) -> list[str]:
    """Every problem of one markdown file. `roles` defaults to the roles of tokens.md,
    which is read only when the file holds a styled grid."""
    errors: list[str] = []
    lines = path.read_text(encoding="utf-8").splitlines()
    wireframes: list[Wireframe] = []  # one per wireframe fence; the position is its index
    ids: dict[str, int] = {}  # id -> line of the fence that declares it

    def check_rows(fence: Fence, width: int, height: int) -> None:
        rows = fence.body
        if len(rows) != height:
            errors.append(
                f"{path}:{fence.line}: declared {width}x{height} but block has "
                f"{len(rows)} rows"
            )
        for offset, row in enumerate(rows):
            lineno = fence.line + 1 + offset
            if "\t" in row:
                errors.append(f"{path}:{lineno}: tab character in wireframe row")
            if row != row.rstrip():
                errors.append(f"{path}:{lineno}: trailing whitespace in wireframe row")
            row_width = display_width(row.rstrip())
            if row_width > width:
                errors.append(
                    f"{path}:{lineno}: row display width {row_width} exceeds "
                    f"declared width {width}"
                )
        errors.extend(
            f"{path}: {error}" for error in check_wireframe_geometry(rows, fence.line + 1)
        )

    def check_header(fence: Fence) -> tuple[tuple[int, int] | None, str | None]:
        """Validate `WxH[ id=NAME]`; return the size and the id when they are valid."""
        where = f"{path}:{fence.line}"
        tokens = fence.rest.split()
        size = SIZE_RE.match(tokens[0]) if tokens else None
        if size is None:
            errors.append(
                f"{where}: wireframe fence needs a WxH size, e.g. ```wireframe 46x9"
            )
            return None, None
        names = [token for token in tokens[1:] if token.startswith("id=")]
        for token in tokens[1:]:
            if not token.startswith("id="):
                errors.append(
                    f"{where}: unexpected `{token}` after the size; the only allowed "
                    "header word is `id=NAME`"
                )
        wire_id: str | None = None
        if len(names) > 1:
            errors.append(f"{where}: more than one `id=` in the wireframe fence header")
        elif names:
            name = names[0][3:]
            if not ID_RE.fullmatch(name):
                errors.append(
                    f"{where}: invalid wireframe id `{name}`; use lowercase words joined "
                    "by hyphens (a-z, 0-9), e.g. `id=anatomy`"
                )
            elif name in ids:
                errors.append(
                    f"{where}: duplicate wireframe id `{name}` (first used at line "
                    f"{ids[name]})"
                )
            else:
                ids[name] = fence.line
                wire_id = name
        return (int(size.group(1)), int(size.group(2))), wire_id

    for fence in parse_fences(lines):
        where = f"{path}:{fence.line}"
        grid = bool(fence.body) and fence.body[0].startswith("── chars")
        if not fence.closed:
            kind = "wireframe" if fence.info == "wireframe" else "code"
            errors.append(f"{where}: unterminated {kind} fence")
            if fence.info == "wireframe":
                wireframes.append(Wireframe(fence.line, fence.body, None, None))
            continue
        if fence.info == "wireframe":
            size, wire_id = check_header(fence)
            wireframes.append(
                Wireframe(fence.line, fence.body, size[0] if size else None, wire_id)
            )
            if size is not None:
                check_rows(fence, *size)
        elif grid and fence.info == "text":
            if roles is None:
                roles = load_roles()
            owner = wireframes[-1] if wireframes else None
            errors.extend(check_styled_grid(path, fence, owner, roles))
        elif grid:
            errors.append(
                f"{where}: a styled grid must be a `text` fence, not `{fence.info or 'unlabeled'}`"
            )
        elif fence.info == "text":
            # A fence that shows other fences (the README's examples) documents the
            # convention; its section headers belong to the examples.
            documents_fences = any(FENCE_RE.match(line) for line in fence.body)
            stray = next((line for line in fence.body if SECTION_RE.match(line)), None)
            if stray is not None and not documents_fences:
                errors.append(
                    f"{where}: section header `{stray}` outside a styled grid; a styled "
                    "grid is one `text` fence that starts with `── chars ──`"
                )
            if fence.rest == "standalone":
                errors.append(
                    f"{where}: `standalone` applies only to styled grids, whose fence "
                    "starts with `── chars ──`"
                )

    positional = {
        str(position): wire.line for position, wire in enumerate(wireframes) if wire.id is None
    }
    for name, line in ids.items():
        if name in positional:
            errors.append(
                f"{path}:{line}: wireframe id `{name}` collides with the position-based "
                f"identity of the id-less wireframe at line {positional[name]}"
            )
    return errors


def main(argv: list[str]) -> int:
    targets = [Path(a) for a in argv] or [Path("design")]
    files: list[Path] = []
    for target in targets:
        if target.is_dir():
            files.extend(sorted(target.rglob("*.md")))
        elif target.suffix == ".md":
            files.append(target)
    if not files:
        print("check-wireframes: no markdown files found", file=sys.stderr)
        return 0

    all_errors: list[str] = []
    checked = 0
    for file in files:
        checked += 1
        try:
            all_errors.extend(check_file(file))
        except RoleTableError as error:
            print(f"check-wireframes: {error}", file=sys.stderr)
            return 2

    for error in all_errors:
        print(error, file=sys.stderr)
    if all_errors:
        print(
            f"check-wireframes: {len(all_errors)} problem(s) in {checked} file(s)",
            file=sys.stderr,
        )
        return 1
    print(f"check-wireframes: {checked} file(s) clean")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
