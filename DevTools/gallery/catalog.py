"""Reads the design catalog: one `Doc` per component doc, one `Wireframe` per
```` ```wireframe WxH ```` fence in document order.

The catalog (`design/primitives/*.md`, `design/widgets/*.md`) is the only source of
wireframes. A fence's styled grid is the first `── chars ──` text fence between it and the
next wireframe fence whose character grid equals the fence; its callouts are every
`Callouts (WxH, 0-based):` text fence in the same span. Fences follow the rules of
`scripts/check-wireframes.py`: they start in column 0.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
DESIGN = REPO / "design"
GROUPS = (("primitives", "Primitives"), ("widgets", "Widgets"))

FENCE = re.compile(r"^(`{3,}|~{3,})\s*(\S*)\s*(.*)$")
HEADING = re.compile(r"^#{1,6}\s+(.*?)(?:\s+#+)?\s*$")
SECTION = re.compile(r"^── (.+) ──$")
SIZE = re.compile(r"^(\d+)x(\d+)$")
MIN_HEADING = re.compile(r"\bmin(?:imum)?\b", re.IGNORECASE)


@dataclass
class StyledGrid:
    """A `── chars ──` / `── style ──` / `── legend ──` text fence."""

    chars: list[str]
    styles: list[str]
    legend: dict[str, str]


@dataclass
class Wireframe:
    index: int  # position among the doc's wireframe fences, 0-based
    line: int  # 1-based line of the opening fence
    heading: str  # nearest preceding heading, as written
    width: int
    height: int
    rows: list[str]
    grid: StyledGrid | None = None
    callouts: list[str] = field(default_factory=list)

    @property
    def size(self) -> str:
        return f"{self.width}x{self.height}"

    @property
    def viewport(self) -> str:
        """The viewport name of tokens.md#viewports: `min` when the heading says so,
        `desktop` for 80 columns, `mobile` for 40, otherwise the size."""
        if MIN_HEADING.search(self.heading):
            return "min"
        return {80: "desktop", 40: "mobile"}.get(self.width, self.size)


@dataclass
class Doc:
    slug: str
    group: str
    group_title: str
    title: str
    kind: str
    status: str
    path: str  # relative to the repository root
    wireframes: list[Wireframe]


def _normalized(rows: list[str]) -> list[str]:
    rows = [row.rstrip() for row in rows]
    while rows and not rows[-1]:
        rows.pop()
    return rows


def parse_styled_grid(body: list[str]) -> StyledGrid | None:
    sections: dict[str, list[str]] = {}
    current: list[str] | None = None
    for line in body:
        if (match := SECTION.match(line)) is not None:
            current = sections.setdefault(match.group(1), [])
        elif current is not None:
            current.append(line)
    if not {"chars", "style", "legend"} <= sections.keys():
        return None
    legend = {}
    for line in sections["legend"]:
        if line.strip():
            legend[line[0]] = line[1:].strip()
    return StyledGrid(sections["chars"], sections["style"], legend)


def parse_doc(path: Path, group: str, group_title: str) -> Doc:
    lines = path.read_text(encoding="utf-8").split("\n")
    kind = status = ""
    start = 0
    if lines and lines[0].strip() == "---":
        for number in range(1, len(lines)):
            if lines[number].strip() == "---":
                start = number + 1
                break
            key, _, value = lines[number].partition(":")
            value = value.split(" #")[0].strip()
            if key == "kind":
                kind = value
            elif key == "status":
                status = value

    title = ""
    heading = ""
    wireframes: list[Wireframe] = []
    span: list[tuple[str, list[str]]] = []  # text fences after the latest wireframe
    number = start
    while number < len(lines):
        line = lines[number]
        if (fence := FENCE.match(line)) is None:
            if (match := HEADING.match(line)) is not None:
                heading = match.group(1)
                title = title or heading
            number += 1
            continue
        marker, info, rest = fence.groups()
        opening = number + 1
        body = []
        number += 1
        while number < len(lines):
            closing = FENCE.match(lines[number])
            if (
                closing is not None
                and closing.group(1)[0] == marker[0]
                and len(closing.group(1)) >= len(marker)
                and not closing.group(2)
                and not closing.group(3)
            ):
                break
            body.append(lines[number])
            number += 1
        number += 1  # past the closing fence
        if info == "wireframe":
            size = SIZE.match(rest.strip())
            if size is None:
                raise ValueError(f"{path}:{opening}: wireframe fence needs a WxH size")
            _attach(wireframes, span)
            span = []
            wireframes.append(
                Wireframe(
                    index=len(wireframes),
                    line=opening,
                    heading=heading or title or path.stem,
                    width=int(size.group(1)),
                    height=int(size.group(2)),
                    rows=body,
                )
            )
        elif info == "text" and wireframes:
            span.append((marker, body))
    _attach(wireframes, span)

    return Doc(
        slug=path.stem,
        group=group,
        group_title=group_title,
        title=title or path.stem,
        kind=kind,
        status=status,
        path=path.relative_to(REPO).as_posix(),
        wireframes=wireframes,
    )


def _attach(wireframes: list[Wireframe], span: list[tuple[str, list[str]]]) -> None:
    """Gives the latest wireframe the styled grid and callouts found after it."""
    if not wireframes:
        return
    wire = wireframes[-1]
    for _, body in span:
        if not body:
            continue
        if body[0].startswith("Callouts ("):
            wire.callouts.append("\n".join(body))
        elif body[0].startswith("── chars ──") and wire.grid is None:
            grid = parse_styled_grid(body)
            if grid is not None and _normalized(grid.chars) == _normalized(wire.rows):
                wire.grid = grid


_cache: dict[Path, tuple[int, Doc]] = {}


def load() -> list[Doc]:
    """Every catalog doc, grouped in `GROUPS` order and sorted by slug."""
    docs: list[Doc] = []
    for folder, title in GROUPS:
        for path in sorted((DESIGN / folder).glob("*.md")):
            stamp = path.stat().st_mtime_ns
            cached = _cache.get(path)
            if cached is None or cached[0] != stamp:
                cached = (stamp, parse_doc(path, folder, title))
                _cache[path] = cached
            docs.append(cached[1])
    slugs = [doc.slug for doc in docs]
    if len(set(slugs)) != len(slugs):
        raise ValueError(f"duplicate catalog slugs: {sorted(s for s in slugs if slugs.count(s) > 1)}")
    return docs


def find(slug: str) -> Doc | None:
    return next((doc for doc in load() if doc.slug == slug), None)


def source_paths() -> list[Path]:
    """Files whose changes make an open page stale."""
    return [path for folder, _ in GROUPS for path in sorted((DESIGN / folder).glob("*.md"))]
