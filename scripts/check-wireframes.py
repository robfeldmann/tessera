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


def display_width(line: str) -> int:
    width = 0
    for ch in line:
        if unicodedata.combining(ch):
            continue
        width += 2 if unicodedata.east_asian_width(ch) in ("F", "W") else 1
    return width


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
