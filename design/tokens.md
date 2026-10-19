---
kind: tokens
status: ready
---

# Design tokens

Cross-cutting visual vocabulary. Every wireframe and every widget doc references these by
name instead of relitigating glyphs and styles per component. Each token family maps
naturally onto a future `EnvironmentValues` key, so this doc is quietly also the
environment-key design doc for
[Slice 3](../docs/Spec.md#slice-3-styling-text-wrapping-and-decoration) and beyond.

## Viewports

Named sizes for wireframes and, later, snapshot fixtures.

| Viewport  | Size          | Rationale                                                                                                                                                                                                                                                                                                              |
| --------- | ------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `desktop` | 80x24         | The classic baseline; default for CI fixtures.                                                                                                                                                                                                                                                                         |
| `mobile`  | 40 columns    | Deliberately tighter than a real phone terminal (Termius/Blink portrait is typically 45-55 cols). If a component works at 40 columns, phones are comfortable. Components are wireframed at their natural height; screen-filling compositions use 40x16. Measure the real device with `stty size` and adjust here once. |
| `min`     | per-component | Each component declares its own floor and its degradation below it.                                                                                                                                                                                                                                                    |

Wider fixtures are component-specific. A component may declare a wider natural fixture
when width changes its anatomy, but the catalog does not assign that size a global
viewport name until device testing establishes a reusable breakpoint.

## Semantic styles

Semantic roles resolve to complete `Style` values through the environment, not only to
colors. System component styles consume these roles; applications may replace any role for
a subtree. The initial vocabulary is intentionally small:

| Role                   | Default intent                                         | `NO_COLOR` fallback | Used by                              |
| ---------------------- | ------------------------------------------------------ | ------------------- | ------------------------------------ |
| `semantic.primary`     | terminal-default foreground                            | unchanged           | ordinary labels and content          |
| `semantic.secondary`   | dim terminal-default foreground                        | dim                 | supporting labels and inactive facts |
| `semantic.accent`      | ANSI bright cyan (index 14) + bold                     | bold                | selection and application accents    |
| `semantic.focus`       | ANSI black on dark yellow (indices 0/3) + bold         | bold                | the current focus owner only         |
| `semantic.disabled`    | dim terminal-default foreground                        | dim                 | disabled control presentation        |
| `semantic.destructive` | ANSI bright red (index 9) + bold + underline when able | bold + underline    | destructive actions and warnings     |

These values describe presentation only. Whether a control is enabled, selected, focused,
or destructive remains semantic component state supplied to its system or custom style.
The roles do not add `success`, `warning`, or `information` in 1.0; add roles only when a
specified component demonstrates distinct behavior that cannot use the existing set.

## Border sets

Glyph tables for `Border`/frame drawing. Names follow the style, not the codepoints.

| Set       | Corners | H   | V   | Notes                             |
| --------- | ------- | --- | --- | --------------------------------- |
| `light`   | ┌┐└┘    | ─   | │   | default                           |
| `rounded` | ╭╮╰╯    | ─   | │   | preferred for focus-styled chrome |
| `heavy`   | ┏┓┗┛    | ━   | ┃   | emphasis                          |
| `double`  | ╔╗╚╝    | ═   | ║   | rarely; retro chrome              |
| `ascii`   | ++++    | -   | \|  | degradation target                |

## Divider glyphs

| Style    | Horizontal | Vertical |
| -------- | ---------- | -------- |
| `light`  | ─          | │        |
| `heavy`  | ━          | ┃        |
| `double` | ═          | ║        |
| `dashed` | ╌          | ╎        |
| `ascii`  | -          | \|       |

## Selection

| Token                | Value                     | Used by           |
| -------------------- | ------------------------- | ----------------- |
| `selection.bar`      | `▌` in the leading gutter | List, Table       |
| `selection.fill`     | reverse video on the row  | List, Table       |
| `selection.inactive` | dim instead of reverse    | unfocused widgets |
| `selection.ascii`    | `>` in the leading gutter | degradation       |

## Disclosure

How a collapsible [Section](widgets/section.md) header announces its expansion state, in
the host List's gutter column.

| Token                  | Value     | Used by                                   |
| ---------------------- | --------- | ----------------------------------------- |
| `disclosure.expanded`  | `▾`       | Section headers with an expansion binding |
| `disclosure.collapsed` | `▸`       | Section headers with an expansion binding |
| `disclosure.ascii`     | `-` / `+` | degradation (expanded / collapsed)        |

## Focus

How a focused widget announces itself. System-wide decision, not per-widget.

| Token           | Value                                                                                                                                                 | Notes                                                                    |
| --------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------ |
| `focus.border`  | border glyphs switch to `rounded` and take the focus color as a foreground overlay (bold); background unchanged; title text preserved (not recolored) | focus-owning bordered controls; delegated hosts preserve declared chrome |
| `focus.content` | complete focus owner uses `semantic.focus`                                                                                                            | borderless widgets and controls                                          |

## Scroll indicators

The shared [ScrollIndicator](primitives/scroll-indicator.md) is built from two independent
style axes plus a placement mode. `scrollbar.weight` sets the thumb weight;
`scrollbar.track` sets the track treatment; reduced capability falls back to the ASCII
glyphs.

| `scrollbar.weight` | Vertical thumb | Horizontal thumb | Notes                          |
| ------------------ | -------------- | ---------------- | ------------------------------ |
| `line` (default)   | `┃`            | `━`              | thin heavy-line thumb          |
| `mid`              | `▐`            | `▄`              | half block; the lazygit weight |
| `block`            | `█`            | `■`              | solid, high-contrast           |

| `scrollbar.track` | Vertical track | Horizontal track | Notes                              |
| ----------------- | -------------- | ---------------- | ---------------------------------- |
| `solid` (default) | `│`            | `─`              | continuous rule                    |
| `dashed`          | `╎`            | `╌`              | shares the `dashed` divider glyphs |
| `none`            | (blank)        | (blank)          | only the thumb paints              |

`scrollbar.ascii` is the shared degradation target: track `\|` / `-`, thumb `#`; a `none`
track stays blank.

Placement is parent-owned. `reserved` (default) gives the strip one trailing column or
bottom row inside the component frame. `onBorder` rides an adjacent
[Border](primitives/border.md) or [Box](primitives/box.md) edge: the border line is the
track, the thumb overlays the edge cells, and no extra cell is reserved. Thumb length is
`max(1, floor(track x viewport / content))` for every combination. Scroll indicators
appear only when content overflows.

## Truncation

| Token             | Value                    | Notes                                    |
| ----------------- | ------------------------ | ---------------------------------------- |
| `truncation.mark` | `…` (width 1)            | `~` in ascii degradation                 |
| policies          | `tail`, `head`, `middle` | `tail` default; grapheme-safe boundaries |

## Degradation ladder

What each family becomes as capabilities shrink. Capability detection is advisory
([Slice 6](../docs/Spec.md#slice-6-terminal-capability-detection)); the ladder is what
"reduce feature use, do not break" looks like, decided once here.

| Family          | Full             | `NO_COLOR`         | 16-color                   | ASCII-only      |
| --------------- | ---------------- | ------------------ | -------------------------- | --------------- |
| borders         | any set          | unchanged          | unchanged                  | `ascii` set     |
| selection       | fill + bar       | reverse video only | indexed reverse            | `>` gutter      |
| focus           | `semantic.focus` | bold               | indexed black/yellow pair  | bold            |
| scrollbar       | weight + track   | unchanged          | unchanged                  | `\|` and `#`    |
| disclosure      | `▾` / `▸`        | unchanged          | unchanged                  | `-` / `+`       |
| truncation      | `…`              | unchanged          | unchanged                  | `~`             |
| semantic styles | full role Style  | attributes only    | indexed color + attributes | attributes only |

## Requirements

- `semantic accent has a deterministic indexed-color fallback` (semantic styles:
  `semantic.accent`).
- `semantic focus uses a yellow background plus bold when color is available` (semantic
  styles: `semantic.focus`).
- `semantic destructive preserves emphasis without color` (semantic styles:
  `semantic.destructive`).
- `disclosure glyphs degrade to minus and plus in ascii` (disclosure: `disclosure.ascii`).
- `focused bordered controls retain their title geometry` (focus: `focus.border`).
- `ascii degradation substitutes only the shared glyph families` (degradation ladder:
  ASCII-only).
- `scroll indicator weight and track axes resolve independent glyphs` (scroll indicators:
  weight and track tables).
- `on-border placement reserves no cell and rides the edge` (scroll indicators:
  placement).
