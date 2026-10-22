"""HTML pages of the component gallery: the index, one page per catalog component, and the
Tokens page. Pages are built on every request, so edits to the catalog show on reload.

Each wireframe fence of a catalog doc is one entry with three slots: the catalog wireframe,
and the `Current` and `Previous` renders of the real widget. The slots read
`.build/tessera-dev/<slug>/<key>-current.svg` and `<key>-previous.svg`, where `<slug>` is the
doc's file name without `.md` and `<key>` is the fence's `id=NAME` when its header has one
and its 0-based position among the doc's `wireframe` fences otherwise (`catalog.Wireframe.key`);
a missing file shows "not built yet". This layout is a provisional guess pending plan 033
Phase C, which decides where `tessera-dev` writes its renders; the gallery only displays what
it finds and never judges it.

A styled grid whose fence opens with `text standalone` illustrates no wireframe, so it has no
render slots: it is drawn from its own `chars` rows as a standalone entry after the doc's
wireframes. Anything the gallery cannot honour in a doc (a grid that matches no wireframe, an
unknown legend token or role, a style letter the legend does not define) shows as a warning
badge and list on the page instead of silently falling back to a default.
"""

from __future__ import annotations

import hashlib
import html
import re
from pathlib import Path
from urllib.parse import quote

from . import catalog, colors, wireframe
from .colors import TIERS, Theme, contrast, hs, paint, resolve

ASSETS = Path(__file__).parent
BUILD = catalog.REPO / ".build" / "tessera-dev"
RENDER = re.compile(r"[a-z0-9]+(?:-[a-z0-9]+)*-(?:current|previous)\.svg")
SLOTS = (("current", "Current"), ("previous", "Previous"))


# Shared pieces ---------------------------------------------------------------------------------


_themes: tuple[int, list[Theme]] | None = None


def themes() -> list[Theme]:
    """The review themes, re-read when `themes.json` changes."""
    global _themes
    stamp_ns = colors.THEMES_FILE.stat().st_mtime_ns
    if _themes is None or _themes[0] != stamp_ns:
        _themes = (stamp_ns, colors.load_themes())
    return _themes[1]


def pick_theme(requested: str | None) -> Theme:
    """The theme named by a `?theme=` value (its id or exact name); the first by default."""
    available = themes()
    return next((t for t in available if requested in (t.id, t.name)), available[0])


def stamp() -> str:
    """Changes when a catalog doc, the theme file or a render under `.build/tessera-dev`
    changes on disk."""
    paths = [*catalog.source_paths(), colors.THEMES_FILE, *sorted(BUILD.glob("*/*.svg"))]
    digest = hashlib.sha1()
    for path in paths:
        try:
            digest.update(f"{path}:{path.stat().st_mtime_ns}\n".encode())
        except FileNotFoundError:
            continue
    return digest.hexdigest()[:12]


def render_path(slug: str, name: str) -> Path | None:
    """The build render `name` of component `slug`, if the gallery may serve it."""
    if catalog.find(slug) is None or RENDER.fullmatch(name) is None:
        return None
    path = BUILD / slug / name
    return path if path.is_file() else None


def inline(text: str) -> str:
    return re.sub(r"`([^`]+)`", r"<code>\1</code>", html.escape(text))


def link(path: str, theme: Theme) -> str:
    """`path` carrying the theme choice, so it survives navigation."""
    return path if theme.id == themes()[0].id else f"{path}?theme={quote(theme.id)}"


def page(title: str, body: str, theme: Theme | None = None, *, active: str = "",
         wide: bool = False) -> str:
    chosen = theme or themes()[0]
    nav = (
        f'<a href="{link("/", chosen)}"{" class=current" if active == "gallery" else ""}>'
        "Gallery</a>"
        f'<a href="/tokens"{" class=current" if active == "tokens" else ""}>Tokens</a>'
    )
    css = (ASSETS / "gallery.css").read_text()
    script = (ASSETS / "gallery.js").read_text()
    return (
        "<!doctype html><html lang=en><head><meta charset=utf-8>"
        '<meta name=viewport content="width=device-width, initial-scale=1">'
        f"<title>{html.escape(title)}</title><style>{css}</style></head>"
        f'<body data-stamp="{stamp()}"><nav>{nav}</nav>'
        f'<main{" class=wide" if wide else ""}>{body}</main>'
        '<div id="banner">Files changed on disk; click to reload</div>'
        f"<script>{script}</script></body></html>"
    )


def theme_picker(current: Theme) -> str:
    options = "".join(
        f'<option value="{t.id}"{" selected" if t.id == current.id else ""}>'
        f"{html.escape(t.name)}</option>"
        for t in themes()
    )
    return (
        '<form class="theme-picker" method="get"><label>Theme <select name="theme">'
        f'{options}</select></label><noscript><button>Apply</button></noscript></form>'
    )


# Index -----------------------------------------------------------------------------------------


def index_page(theme: Theme) -> str:
    docs = catalog.load()
    total = sum(len(doc.wireframes) for doc in docs)
    parts = [
        "<h1>Component gallery</h1>",
        f"<p>{len(docs)} catalog components and {total} wireframes, read from the "
        "<code>wireframe</code> fences of <code>docs/design/primitives</code> and "
        "<code>docs/design/widgets</code>. Each wireframe sits beside empty Current and "
        "Previous slots for the renders <code>tessera-dev</code> will write to "
        "<code>.build/tessera-dev/</code>.</p>",
        theme_picker(theme),
    ]
    for folder, title in catalog.GROUPS:
        group = [doc for doc in docs if doc.group == folder]
        rows = "".join(
            f'<tr><td><a href="{link(f"/c/{doc.slug}", theme)}">{html.escape(doc.slug)}</a></td>'
            f"<td>{inline(doc.title)}</td>"
            f'<td><span class="badge status-{html.escape(doc.status)}">'
            f"{html.escape(doc.status or 'no status')}</span></td>"
            f'<td class="num">{len(doc.wireframes)}</td></tr>'
            for doc in group
        )
        parts.append(
            f"<h2>{title} <span class=count>{len(group)}</span></h2>"
            "<table class=index><thead><tr><th>Slug</th><th>Component</th><th>Status</th>"
            f'<th class="num">Wireframes</th></tr></thead><tbody>{rows}</tbody></table>'
        )
    return page("Component gallery", "".join(parts), theme, active="gallery")


# Component pages -------------------------------------------------------------------------------


def slot_html(slug: str, key: str, kind: str, caption: str) -> str:
    name = f"{key}-{kind}.svg"
    path = render_path(slug, name)
    if path is None:
        body = '<p class="placeholder">not built yet</p>'
    else:
        version = path.stat().st_mtime_ns
        body = (
            f'<div class="picture"><img src="/render/{quote(slug)}/{name}?v={version}" '
            f'alt="{caption} render of {html.escape(slug)} wireframe {html.escape(key)}"></div>'
        )
    return f'<figure class="slot {kind}"><figcaption>{caption}</figcaption>{body}</figure>'


def grid_text(wire: catalog.Wireframe) -> str:
    lines = list(wire.rows)
    if wire.grid is not None:
        lines += grid_sections(wire.grid)
    return "\n".join(lines)


def grid_sections(grid: catalog.StyledGrid) -> list[str]:
    legend = [f"{letter}  {spec}" for letter, spec in grid.legend.items()]
    return ["── style ──", *grid.styles, "── legend ──", *legend]


def warnings_html(warnings: list[str]) -> str:
    """What the gallery could not honour in the catalog, in plain sight on the page."""
    if not warnings:
        return ""
    items = "".join(f"<li>{inline(text)}</li>" for text in warnings)
    return f'<ul class="warnings">{items}</ul>'


def warning_chip(count: int) -> str:
    if not count:
        return ""
    noun = "warning" if count == 1 else "warnings"
    return f'<span class="chip warning">⚠ {count} {noun}</span>'


def entry_html(doc: catalog.Doc, wire: catalog.Wireframe, theme: Theme) -> str:
    problems = list(wire.warnings)
    if wire.grid is not None:
        problems += [f"styled grid: {problem}" for problem in wire.grid.problems]
    chips = [f'<span class="chip">{wire.size}</span>']
    if wire.viewport != wire.size:
        chips.append(f'<span class="chip viewport">{html.escape(wire.viewport)}</span>')
    chips.append(
        f'<span class="chip" title="{html.escape(doc.path)}:{wire.line}">'
        f"{f'{html.escape(wire.id)} · ' if wire.id else ''}fence {wire.index}"
        f" · line {wire.line}</span>"
    )
    chips.append(
        '<span class="chip styled">styled grid</span>'
        if wire.grid
        else '<span class="chip plain" title="no styled grid follows this fence">'
        "unstyled</span>"
    )
    chips.append(warning_chip(len(problems)))
    picture = wireframe.render(
        wire.rows, theme, "derived", wire.grid, (wire.width, wire.height),
        label=f"{doc.slug} {wire.heading}",
    )
    callouts = "".join(f'<pre class="callouts">{html.escape(text)}</pre>' for text in wire.callouts)
    return (
        f'<section class="entry" id="w-{html.escape(wire.key)}" data-key="{html.escape(wire.key)}">'
        f'<h2><a href="#w-{html.escape(wire.key)}">{inline(wire.heading)}</a></h2>'
        f'<p class="meta">{"".join(chips)}</p>'
        f"{warnings_html(problems)}"
        '<div class="triple">'
        f'<figure class="slot wireframe"><figcaption>Wireframe</figcaption>{picture}</figure>'
        + "".join(slot_html(doc.slug, wire.key, kind, caption) for kind, caption in SLOTS)
        + f"</div>{callouts}"
        f"<details><summary>Text</summary><pre>{html.escape(grid_text(wire))}</pre></details>"
        "</section>"
    )


def standalone_html(doc: catalog.Doc, grid: catalog.StyledGrid, number: int,
                    theme: Theme) -> str:
    """A `text standalone` grid: drawn from its own chars rows, with no render slots,
    since it names no wireframe a real widget could be compared with."""
    picture = wireframe.render(
        grid.chars, theme, "derived", grid, label=f"{doc.slug} {grid.heading} (standalone)"
    )
    chips = (
        '<span class="chip">standalone</span>'
        f'<span class="chip" title="{html.escape(doc.path)}:{grid.line}">line {grid.line}</span>'
        '<span class="chip styled">styled grid</span>'
        + warning_chip(len(grid.problems))
    )
    text = "\n".join(["── chars ──", *grid.chars, *grid_sections(grid)])
    return (
        f'<section class="entry standalone" id="standalone-{number}">'
        f'<h2><a href="#standalone-{number}">{inline(grid.heading)}</a></h2>'
        f'<p class="meta">{chips}</p>'
        f"{warnings_html([f'styled grid: {p}' for p in grid.problems])}"
        f'<figure class="slot wireframe"><figcaption>Styled grid</figcaption>{picture}</figure>'
        f"<details><summary>Text</summary><pre>{html.escape(text)}</pre></details>"
        "</section>"
    )


def component_page(slug: str, theme: Theme) -> str | None:
    docs = catalog.load()
    doc = next((d for d in docs if d.slug == slug), None)
    if doc is None:
        return None
    position = docs.index(doc)
    neighbours = []
    for other, arrow in ((docs[position - 1] if position else None, "←"),
                         (docs[position + 1] if position + 1 < len(docs) else None, "→")):
        if other is not None:
            text = f"{arrow} {other.slug}" if arrow == "←" else f"{other.slug} {arrow}"
            neighbours.append(f'<a href="{link(f"/c/{other.slug}", theme)}">{text}</a>')
    contents = "".join(
        f'<a href="#w-{w.key}">{html.escape(w.key)} {inline(w.heading)} <small>{w.size}</small></a>'
        for w in doc.wireframes
    ) + "".join(
        f'<a href="#standalone-{n}">standalone {n} {inline(grid.heading)}</a>'
        for n, grid in enumerate(doc.standalone)
    )
    standalone = (
        "<h2 class=\"standalone-title\">Standalone styled grids</h2>"
        "<p class=\"hint\">Grids that illustrate no wireframe (<code>```text standalone</code>), "
        "drawn from their <code>chars</code> rows.</p>"
        + "".join(standalone_html(doc, grid, n, theme) for n, grid in enumerate(doc.standalone))
        if doc.standalone else ""
    )
    body = (
        f'<p class="crumbs"><a href="{link("/", theme)}">Gallery</a> › '
        f"{doc.group_title} › {html.escape(doc.slug)}</p>"
        f'<h1>{inline(doc.title)} <span class="badge status-{html.escape(doc.status)}">'
        f"{html.escape(doc.status or 'no status')}</span></h1>"
        f'<p class="hint"><code>{html.escape(doc.path)}</code> · {len(doc.wireframes)} '
        f"wireframes{f' · {len(doc.standalone)} standalone grids' if doc.standalone else ''}"
        " · colours resolved for the <b>derived</b> tier of the chosen theme</p>"
        f"{warnings_html(doc.warnings)}"
        f"{theme_picker(theme)}"
        + (f'<nav class="contents">{contents}</nav>' if contents else "")
        + "".join(entry_html(doc, wire, theme) for wire in doc.wireframes)
        + standalone
        + ('<p class="empty">This doc has no wireframe fences yet.</p>'
           if not doc.wireframes and not doc.standalone else "")
        + f'<p class="pager">{" · ".join(neighbours)}</p>'
    )
    return page(f"{doc.slug} · gallery", body, theme, active="gallery", wide=True)


# Tokens page -----------------------------------------------------------------------------------

ROLE_ROWS = (
    ("Text", ("primary", "secondary", "border", "disabled", "focus")),
    ("Hues", ("accent", "info", "success", "warning", "error", "destructive")),
    ("Fills", ("surface", "hover", "selection.fill", "selection.inactive", "disabled.fill",
               "disabled.label")),
    ("Solid fills", ("solid(primary)", "solid(focus)", "solid(accent)", "solid(info)",
                     "solid(success)", "solid(warning)", "solid(error)", "solid(secondary)")),
    ("Tinted fills", ("faint(accent)", "faint(focus)", "faint(error)", "faint(secondary)")),
    ("Syntax", ("syntax.keyword", "syntax.string", "syntax.constant", "syntax.type",
                "syntax.function", "syntax.comment", "syntax.punctuation", "syntax.plain")),
)

# Catalog wireframes drawn on every theme: (doc slug, heading prefix, why it is here).
SAMPLES = (
    ("button", "Intents and emphasis", "filled, tinted and plain over three intents"),
    ("button", "States fixture", "focus, hover, press and disabled"),
    ("badge", "Anatomy", "solid tones"),
    ("callout", "Mobile", "tone roles and the header badge"),
    ("outline", "Anatomy", "selection fill and the selection bar"),
    ("table", "Striped", "surface stripes"),
    ("key-legend", "Keycaps", "keycaps on the surface fill"),
    ("picker", "Icons only at 40 columns", "segmented control"),
    ("tab-view", "Anatomy", "focus chip"),
    ("code-view", "Syntax highlighting", "syntax roles"),
    ("box", "Self focus", "focus border"),
    ("progress-view", "Determinate", "bar fill and track"),
)

# The bar draws in `accent` while the widget is focused and `secondary` when inactive; the
# row's text keeps its own role on the fill.
SELECTION_ROWS = (
    ("Selection row, focused", "fg=accent bg=selection.fill", "fg=primary bg=selection.fill"),
    ("Selection row, inactive", "fg=secondary bg=selection.inactive",
     "fg=primary bg=selection.inactive"),
)


def swatch_spec(role: str) -> tuple[str, str]:
    """The legend spec and sample text that show `role`."""
    if role.startswith("solid("):
        return f"fg=contrast bg={role[6:-1]} bold", "Label"
    if role.startswith("faint("):
        return f"fg={role[6:-1]} bg={role}", "Label"
    if role == "disabled.label":
        return "fg=disabled.label bg=disabled.fill", "Label"
    if role in colors.FILL_ROLES:
        return f"fg=primary bg={role}", "Row text"
    return f"fg={role}", "Sample text"


def swatch_note(theme: Theme, role: str, tier: str, style: colors.Style) -> str:
    if tier == "derived":
        if role.startswith("solid("):
            fill = theme.derived(role[6:-1])
            label = theme.on(fill)
            return (f"{hs(fill)} · label {'bg' if label == theme.bg else 'fg'} "
                    f"{contrast(label, fill):.1f}:1")
        color = theme.derived(role)
        if color is None:
            return ""
        note = hs(color)
        if role in colors.PAIR:
            hue = theme.hue(colors.PAIR[role])
            note += f" · slot {hue.slot}, q={hue.q}"
            return f"{note} · {contrast(color, theme.bg):.1f}:1"
        if role == "focus":
            return f"{note} · default fg, bold"
        if role in ("secondary", "syntax.comment", "syntax.punctuation"):
            return f"{note} · p={theme.ink2_p} · {contrast(color, theme.bg):.1f}:1"
        if role in ("border", "disabled", "disabled.label"):
            return f"{note} · p={theme.ink3_p} · {contrast(color, theme.bg):.1f}:1"
        return note
    parts = []
    if style.fg_slot is not None:
        parts.append(f"fg ansi {style.fg_slot}")
    if style.bg_slot is not None:
        parts.append(f"bg ansi {style.bg_slot}")
    parts += style.attributes()
    if style.blank:
        parts.append("blank")
    return " ".join(parts) or "none"


def swatch_cell(theme: Theme, role: str, tier: str) -> str:
    spec, text = swatch_spec(role)
    style = resolve(theme, spec, tier)
    look = paint(theme, style)
    css = [f"color:{look.fg}"]
    if look.bg:
        css.append(f"background:{look.bg}")
    if look.bold:
        css.append("font-weight:bold")
    if look.italic:
        css.append("font-style:italic")
    if look.underline:
        css.append("text-decoration:underline")
    if look.dim:
        css.append("opacity:.6")
    return (
        f'<td style="background:{hs(theme.bg)}"><span class="sw" style="{";".join(css)}">'
        f'{text}</span><small style="color:{hs(theme.ink2)}">'
        f"{html.escape(swatch_note(theme, role, tier, style))}</small></td>"
    )


def selection_cell(theme: Theme, tier: str, bar: str, label: str) -> str:
    row = "▌ Selected row  "
    grid = catalog.StyledGrid([row], ["A" + "B" * (len(row) - 1)], {"A": bar, "B": label})
    return f"<td>{wireframe.render([row], theme, tier, grid)}</td>"


def tier_tabs(tier: str) -> str:
    tabs = "".join(
        f'<a href="/tokens?tier={key}"{" class=current" if key == tier else ""}>{title}</a>'
        for key, title in TIERS
    )
    return f'<nav class="tabs">{tabs}</nav>'


TIER_NOTES = {
    "derived": "The terminal answered the colour queries: roles are blends of the real "
    "<code>fg</code> and <code>bg</code> and guarded hues of the measured slots. A hue with "
    "<code>q=0</code> is emitted as its ANSI slot; the swatch note shows slot, guard step "
    "and contrast against <code>bg</code>.",
    "slots": "The terminal did not answer, or the depth is 16 colours: ANSI slots plus dim, "
    "reverse and bold. Hues take the bright slot on dark themes and the normal slot on light "
    "ones, unmeasured. Dim is drawn at 60% opacity; terminals vary.",
    "nocolor": "<code>NO_COLOR</code>: attributes only. Every role resolves to bold, dim, "
    "reverse or nothing.",
}


def tokens_page(requested_tier: str | None) -> str:
    tier = requested_tier if requested_tier in dict(TIERS) else "derived"
    all_themes = themes()
    header = "".join(f"<th>{html.escape(t.name)}</th>" for t in all_themes)
    parts = [
        "<h1>Tokens</h1>",
        "<p>Roles computed from <code>docs/design/tokens.md</code> (blend and contrast rules, "
        "roles, selection) for the five review themes in "
        "<code>DevTools/gallery/themes.json</code>. Swatches are drawn from each theme's hex "
        "values, not terminal screenshots.</p>",
        tier_tabs(tier),
        f'<p class="hint">{TIER_NOTES[tier]}</p>',
    ]
    rows = []
    for t in all_themes:
        palette = "".join(
            f'<span title="{i}: {hs(c)}" style="background:{hs(c)}"></span>'
            for i, c in enumerate(t.slots)
        )
        rows.append(
            f"<tr><th>{html.escape(t.name)}</th><td>{'light' if t.light else 'dark'}</td>"
            f'<td style="background:{hs(t.bg)};color:{hs(t.fg)}">fg on bg '
            f"{contrast(t.fg, t.bg):.1f}:1</td><td class=pal>{palette}</td>"
            f"<td><small>{inline(t.source)}</small></td></tr>"
        )
    parts.append(
        "<h2>Themes</h2><table class=tok><tr><th>Theme</th><th>Scheme</th><th>fg/bg</th>"
        f"<th>Slots 0-15</th><th>Source</th></tr>{''.join(rows)}</table>"
    )
    table = [f"<table class=tok><tr><th>Role</th>{header}</tr>"]
    for group, roles in ROLE_ROWS:
        table.append(f"<tr><th colspan={len(all_themes) + 1}>{group}</th></tr>")
        for role in roles:
            table.append(
                f"<tr><td><code>{html.escape(role)}</code></td>"
                + "".join(swatch_cell(t, role, tier) for t in all_themes)
                + "</tr>"
            )
    table.append(f"<tr><th colspan={len(all_themes) + 1}>Selection bar</th></tr>")
    for label, bar, text in SELECTION_ROWS:
        table.append(
            f"<tr><td>{label}</td>"
            + "".join(selection_cell(t, tier, bar, text) for t in all_themes)
            + "</tr>"
        )
    table.append("</table>")
    parts.append(f"<h2>Roles</h2>{''.join(table)}")
    if tier == "slots":
        cells = []
        for t in all_themes:
            plain = [
                f"<code>{key.removeprefix('syntax.')}</code> "
                f"({contrast(t.slots[t.pick(colors.PAIR[key])], t.bg):.2f}:1)"
                for key in colors.SYNTAX_HUES
                if t.syntax16(colors.PAIR[key]) is None
            ]
            cells.append(f"<td>{', '.join(plain) or 'none'}</td>")
        parts.append(
            "<h2>Syntax floor at 16 colours</h2><p class=hint>With every slot measured, a "
            "syntax hue whose slot reaches less than 3:1 against <code>bg</code> resolves as "
            f"<code>syntax.plain</code>.</p><table class=tok><tr>{header}</tr><tr>"
            f"{''.join(cells)}</tr></table>"
        )
    parts.append(f"<h2>Catalog samples</h2><p class=hint>Styled grids of catalog wireframes, "
                 f"resolved for the {dict(TIERS)[tier]} tier.</p>")
    docs = {doc.slug: doc for doc in catalog.load()}
    for slug, prefix, why in SAMPLES:
        doc = docs.get(slug)
        wire = next((w for w in doc.wireframes if w.heading.startswith(prefix) and w.grid),
                    None) if doc else None
        if wire is None:
            parts.append(f'<p class="empty">Sample missing: {slug} "{html.escape(prefix)}"</p>')
            continue
        cards = "".join(
            f'<div style="background:{hs(t.bg)}"><h4 style="color:{hs(t.ink2)}">'
            f"{html.escape(t.name)}</h4>"
            f"{wireframe.render(wire.rows, t, tier, wire.grid, (wire.width, wire.height))}</div>"
            for t in all_themes
        )
        parts.append(
            f'<h3><a href="/c/{slug}#w-{html.escape(wire.key)}">{html.escape(slug)} · '
            f"{inline(wire.heading)}</a> <small>{html.escape(why)}</small></h3>"
            f'<div class="themes">{cards}</div>'
        )
    return page("Tokens", "".join(parts), active="tokens", wide=True)
