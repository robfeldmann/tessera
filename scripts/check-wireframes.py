#!/usr/bin/env python3
"""Validate fixture-grade wireframes in the design catalog.

A wireframe is a fenced code block whose info string is `wireframe WxH`
(for example ```wireframe 46x9). The contract, defined in
design/README.md, is:

- exactly H lines between the fences
- every line's display width is <= W (rows are trailing-trimmed)
- no trailing whitespace, no tab characters

Display width uses East Asian Width (F/W count as 2) and skips combining
marks, matching the naive-but-honest width model wireframes are drawn
against. Usage:

    scripts/check-wireframes.py [paths...]

Paths may be markdown files or directories (searched recursively for
*.md). Defaults to `design/`. Exits non-zero on any violation.
"""

from __future__ import annotations

import re
import sys
import unicodedata
from pathlib import Path

FENCE_RE = re.compile(r"^(`{3,}|~{3,})\s*(\S*)\s*(.*)$")
SIZE_RE = re.compile(r"^(\d+)x(\d+)$")


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
        if _connects(source, "S") and _connects(below, "N"):
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
            if not _connects(source, "S") or _connects(grid[row + 1].get(column), "N"):
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
        _connects(grid[row].get(column), "S")
        and _connects(grid[row + 1].get(column), "N")
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


def check_file(path: Path) -> list[str]:
    errors: list[str] = []
    lines = path.read_text(encoding="utf-8").splitlines()
    in_wireframe = False
    fence = ""
    declared: tuple[int, int] | None = None
    block_start = 0
    block_lines: list[str] = []

    def close_block(end_line: int) -> None:
        assert declared is not None
        width, height = declared
        if len(block_lines) != height:
            errors.append(
                f"{path}:{block_start}: declared {width}x{height} but block has "
                f"{len(block_lines)} rows"
            )
        for offset, row in enumerate(block_lines):
            lineno = block_start + 1 + offset
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
            f"{path}: {error}"
            for error in check_wireframe_geometry(block_lines, block_start + 1)
        )

    for lineno, line in enumerate(lines, start=1):
        match = FENCE_RE.match(line)
        if in_wireframe:
            if match and match.group(1).startswith(fence[0]) and len(match.group(1)) >= len(fence):
                close_block(lineno)
                in_wireframe = False
                block_lines = []
            else:
                block_lines.append(line)
            continue
        if match and match.group(2) == "wireframe":
            fence = match.group(1)
            block_start = lineno
            size = SIZE_RE.match(match.group(3).strip())
            if not size:
                errors.append(
                    f"{path}:{lineno}: wireframe fence needs a WxH size, "
                    f"e.g. ```wireframe 46x9"
                )
                declared = None
                continue
            declared = (int(size.group(1)), int(size.group(2)))
            in_wireframe = True
            block_lines = []

    if in_wireframe:
        errors.append(f"{path}:{block_start}: unterminated wireframe fence")
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
        all_errors.extend(check_file(file))

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
