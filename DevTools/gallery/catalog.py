"""Reads the design catalog: one `Doc` per component doc, one `Wireframe` per
```` ```wireframe WxH[ id=NAME] ```` fence in document order.

The catalog (`design/primitives/*.md`, `design/widgets/*.md`) is the only source of
wireframes. A wireframe's identity is `(doc slug, key)`: `key` is the fence's `id` when it
has one and its 0-based position among the doc's wireframe fences otherwise. A styled grid
is a `text` fence that starts with `── chars ──`; it belongs to the nearest preceding
wireframe and colours it when its chars equal the fence's rows. A grid whose fence opens
with ```` ```text standalone ```` illustrates no wireframe and is listed in
`Doc.standalone`. A wireframe's callouts are every `Callouts (WxH, 0-based):` text fence
after it, up to the next wireframe fence.

The gallery never drops catalog content silently. What it cannot honour (a grid that
matches no wireframe, an unknown legend token, an undefined style letter) is kept in the
`warnings` and `problems` lists for the page to show. `scripts/check-wireframes.py` lints
the same grammar and is the gate; these lists only keep the pages honest while a doc is
being edited. Fences follow the rules of that script: they start in column 0.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from pathlib import Path

from .colors import parse_spec, split_description

REPO = Path(__file__).resolve().parents[2]
DESIGN = REPO / "design"
GROUPS = (("primitives", "Primitives"), ("widgets", "Widgets"))

FENCE = re.compile(r"^(`{3,}|~{3,})\s*(\S*)\s*(.*)$")
HEADING = re.compile(r"^#{1,6}\s+(.*?)(?:\s+#+)?\s*$")
SECTION = re.compile(r"^── ([a-z]+) ──$")
LEGEND = re.compile(r"^(\S)  (\S.*)$")
SIZE = re.compile(r"^(\d+)x(\d+)$")
ID = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
MIN_HEADING = re.compile(r"\bmin(?:imum)?\b", re.IGNORECASE)
GRID_SECTIONS = ("chars", "style", "legend")


@dataclass
class StyledGrid:
    """A `── chars ──` / `── style ──` / `── legend ──` text fence."""

    chars: list[str]
    styles: list[str]
    legend: dict[str, str]  # letter -> `SPEC[ -- description]` as written
    line: int = 0  # 1-based line of the opening fence
    heading: str = ""  # nearest preceding heading, as written
    problems: list[str] = field(default_factory=list)  # what the gallery had to work around


@dataclass
class Wireframe:
    index: int  # position among the doc's wireframe fences, 0-based
    line: int  # 1-based line of the opening fence
    heading: str  # nearest preceding heading, as written
    width: int
    height: int
    rows: list[str]
    id: str | None = None  # the `id=NAME` of the fence header
    grid: StyledGrid | None = None
    callouts: list[str] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)  # styled grids that were not used

    @property
    def key(self) -> str:
        """The wireframe's identity within its doc, and the stem of its render files
        (`<slug>/<key>-current.svg`): the id when there is one, else the position."""
        return self.id or str(self.index)

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
    standalone: list[StyledGrid] = field(default_factory=list)  # grids of no wireframe
    warnings: list[str] = field(default_factory=list)  # fences the gallery could not place


def _trimmed(rows: list[str]) -> list[str]:
    return [row.rstrip() for row in rows]


def parse_styled_grid(body: list[str], line: int = 0, heading: str = "") -> StyledGrid:
    """The grid of a fence whose body starts with `── chars ──`. Whatever the gallery can
    only work around (a missing section, an unknown legend token, a style letter the legend
    does not define) goes into `StyledGrid.problems`."""
    sections: dict[str, list[str]] = {}
    problems: list[str] = []
    current: list[str] | None = None
    for text in body:
        if (match := SECTION.match(text)) is not None:
            name = match.group(1)
            if name not in GRID_SECTIONS:
                problems.append(f"unknown section `── {name} ──`")
            elif name in sections:
                problems.append(f"section `── {name} ──` appears twice")
            current = sections.setdefault(name, [])
        elif current is not None:
            current.append(text)
    problems.extend(
        f"missing section `── {name} ──`" for name in GRID_SECTIONS if name not in sections
    )

    legend: dict[str, str] = {}
    for text in sections.get("legend", []):
        if not text.strip():
            problems.append("blank line in the legend")
        elif (match := LEGEND.match(text)) is None:
            problems.append(f"legend line `{text}` is not `L  SPEC`")
        elif match.group(1) in legend:
            problems.append(f"legend letter `{match.group(1)}` is defined twice")
        else:
            letter, spec = match.groups()
            legend[letter] = spec
            problems.extend(f"legend `{letter}`: {problem}" for problem in parse_spec(spec).problems)
            words = split_description(spec)[0].split()
            if letter == "." and words != ["default"]:
                problems.append("legend `.`: the default entry is `.  default`")
            elif letter != "." and "default" in words:
                problems.append(f"legend `{letter}`: `default` is only for the `.` entry")

    styles = sections.get("style", [])
    letters = {ch for row in styles for ch in row if not ch.isspace()} - {"."} - legend.keys()
    if letters:
        problems.append(
            "style letters missing from the legend: " + ", ".join(f"`{ch}`" for ch in sorted(letters))
        )
    if any(ch.isspace() for row in styles for ch in row):
        problems.append("a style row holds whitespace; `.` is the default style")
    return StyledGrid(sections.get("chars", []), styles, legend, line, heading, problems)


def _parse_header(path: Path, line: int, rest: str) -> tuple[int, int, str | None]:
    """`WxH` and an optional `id=NAME` from the text after `wireframe`."""
    tokens = rest.split()
    size = SIZE.match(tokens[0]) if tokens else None
    if size is None:
        raise ValueError(f"{path}:{line}: wireframe fence needs a WxH size")
    wire_id = None
    for token in tokens[1:]:
        if wire_id is None and token.startswith("id=") and ID.fullmatch(token[3:]):
            wire_id = token[3:]
        else:
            raise ValueError(
                f"{path}:{line}: wireframe fence header is `WxH` or `WxH id=NAME`; "
                f"found `{token}`"
            )
    return int(size.group(1)), int(size.group(2)), wire_id


def _place(doc: Doc, grid: StyledGrid, standalone: bool) -> None:
    """Gives `grid` to the latest wireframe of `doc`, or lists it as standalone. A grid that
    cannot be used becomes a warning where the page shows it."""
    if standalone:
        doc.standalone.append(grid)
    elif not doc.wireframes:
        doc.warnings.append(
            f"line {grid.line}: a styled grid before any wireframe needs `text standalone`"
        )
    else:
        wire = doc.wireframes[-1]
        if _trimmed(grid.chars) != _trimmed(wire.rows):
            wire.warnings.append(
                f"the styled grid at line {grid.line} does not match this wireframe; "
                "it is not shown (open its fence with `text standalone` if it illustrates "
                "no wireframe)"
            )
        elif wire.grid is not None:
            wire.warnings.append(
                f"the styled grid at line {grid.line} is a second grid for this wireframe; "
                f"only the first, at line {wire.grid.line}, is shown"
            )
        else:
            wire.grid = grid


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
    doc = Doc(
        slug=path.stem,
        group=group,
        group_title=group_title,
        title=path.stem,
        kind=kind,
        status=status,
        path=path.relative_to(REPO).as_posix(),
        wireframes=[],
    )
    ids: dict[str, int] = {}  # id -> line of the fence that declares it
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
        label = heading or title or path.stem
        if info == "wireframe":
            width, height, wire_id = _parse_header(path, opening, rest)
            if wire_id is not None:
                if wire_id in ids:
                    raise ValueError(
                        f"{path}:{opening}: duplicate wireframe id `{wire_id}` "
                        f"(first used at line {ids[wire_id]})"
                    )
                ids[wire_id] = opening
            doc.wireframes.append(
                Wireframe(
                    index=len(doc.wireframes),
                    line=opening,
                    heading=label,
                    width=width,
                    height=height,
                    rows=body,
                    id=wire_id,
                )
            )
        elif info == "text" and body and body[0].startswith("── chars"):
            grid = parse_styled_grid(body, opening, label)
            if rest.strip() not in ("", "standalone"):
                grid.problems.append(f"unexpected `{rest.strip()}` after `text`")
            _place(doc, grid, rest.strip() == "standalone")
        elif info == "text" and body and body[0].startswith("Callouts (") and doc.wireframes:
            doc.wireframes[-1].callouts.append("\n".join(body))
        elif body and (
            body[0].startswith("── chars")
            or (
                info == "text"
                and any(SECTION.match(text) for text in body)
                and not any(FENCE.match(text) for text in body)  # not a documented example
            )
        ):
            doc.warnings.append(
                f"line {opening}: a fence holds styled-grid sections but is not a `text` "
                "fence that starts with `── chars ──`; it is not shown"
            )
    doc.title = title or path.stem

    positional = {str(wire.index): wire for wire in doc.wireframes if wire.id is None}
    for wire_id, line in ids.items():
        if wire_id in positional:
            raise ValueError(
                f"{path}:{line}: wireframe id `{wire_id}` collides with the position-based "
                f"identity of the id-less wireframe at line {positional[wire_id].line}"
            )
    return doc


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
