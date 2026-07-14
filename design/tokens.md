---
kind: tokens
status: sketch
---

# Design tokens

Cross-cutting visual vocabulary. Every wireframe and every widget doc references these by
name instead of relitigating glyphs and styles per component. Each token family maps
naturally onto a future `EnvironmentValues` key, so this doc is quietly also the
environment-key design doc for
[Slice 3](../docs/Spec.md#slice-3-styling-text-wrapping-and-decoration) and beyond.

## Viewports

Named sizes for wireframes and, later, snapshot fixtures.

| Viewport  | Size          | Rationale                                                                                                                                                                                                               |
| --------- | ------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `desktop` | 80x24         | The classic baseline; default for CI fixtures.                                                                                                                                                                          |
| `mobile`  | 40x16         | Deliberately tighter than a real phone terminal (Termius/Blink portrait is typically 45-55 cols). If a component works at 40x16, phones are comfortable. Measure the real device with `stty size` and adjust here once. |
| `min`     | per-component | Each component declares its own floor and its degradation below it.                                                                                                                                                     |

Wider fixtures are component-specific. A component may declare a wider natural fixture
when width changes its anatomy, but the catalog does not assign that size a global
viewport name until device testing establishes a reusable breakpoint. Tessera Showcase
currently uses `120x24` provisionally for its simultaneous three-region composition.

## Semantic styles

Semantic roles resolve to complete `Style` values through the environment, not only to
colors. System component styles consume these roles; applications may replace any role for
a subtree. The initial vocabulary is intentionally small:

| Role                   | Default intent                   | `NO_COLOR` fallback | Used by                              |
| ---------------------- | -------------------------------- | ------------------- | ------------------------------------ |
| `semantic.primary`     | terminal-default foreground      | unchanged           | ordinary labels and content          |
| `semantic.secondary`   | dim terminal-default foreground  | dim                 | supporting labels and inactive facts |
| `semantic.accent`      | configured accent color + bold   | bold                | focus and selected controls          |
| `semantic.disabled`    | dim terminal-default foreground  | dim                 | disabled control presentation        |
| `semantic.destructive` | red + bold + underline when able | bold + underline    | destructive actions and warnings     |

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

| Token                | Value (proposed)          | Used by           |
| -------------------- | ------------------------- | ----------------- |
| `selection.bar`      | `▌` in the leading gutter | List, Table       |
| `selection.fill`     | reverse video on the row  | List, Table       |
| `selection.inactive` | dim instead of reverse    | unfocused widgets |
| `selection.ascii`    | `>` in the leading gutter | degradation       |

## Focus

How a focused widget announces itself. System-wide decision, not per-widget.

| Token           | Value (proposed)                                | Notes                            |
| --------------- | ----------------------------------------------- | -------------------------------- |
| `focus.border`  | border switches to `rounded` + accent color     | bordered widgets                 |
| `focus.content` | selection tokens switch active/inactive variant | borderless widgets (List, Table) |

## Scroll indicators

| Token             | Value (proposed) | Notes                                           |
| ----------------- | ---------------- | ----------------------------------------------- |
| `scrollbar.track` | `│` / `─`        | vertical / horizontal                           |
| `scrollbar.thumb` | `█` / `■`        | thumb length = max(1, viewport/content x track) |
| `scrollbar.ascii` | `\|` and `#`     | degradation                                     |

Scrollbars appear only when content overflows; they occupy one cell on the trailing or
bottom edge, inside the component's frame.

## Truncation

| Token             | Value                    | Notes                                    |
| ----------------- | ------------------------ | ---------------------------------------- |
| `truncation.mark` | `…` (width 1)            | `~` in ascii degradation                 |
| policies          | `tail`, `head`, `middle` | `tail` default; grapheme-safe boundaries |

## Degradation ladder

What each family becomes as capabilities shrink. Capability detection is advisory
([Slice 6](../docs/Spec.md#slice-6-terminal-capability-detection)); the ladder is what
"reduce feature use, do not break" looks like, decided once here.

| Family          | Full            | `NO_COLOR`         | 16-color                   | ASCII-only      |
| --------------- | --------------- | ------------------ | -------------------------- | --------------- |
| borders         | any set         | unchanged          | unchanged                  | `ascii` set     |
| selection       | fill + bar      | reverse video only | indexed reverse            | `>` gutter      |
| focus           | accent          | bold               | indexed accent             | bold            |
| scrollbar       | track+thumb     | unchanged          | unchanged                  | `\|` and `#`    |
| truncation      | `…`             | unchanged          | unchanged                  | `~`             |
| semantic styles | full role Style | attributes only    | indexed color + attributes | attributes only |

## Open questions

- Which terminal-indexed colors should system `semantic.accent` and `semantic.destructive`
  use before an application overrides them? Resolve while reviewing the first control
  style; role names and non-color fallbacks are accepted.
- Should `focus.border` imply a title-position change (SwiftUI-style) or stay purely
  stylistic? Defer until Border primitive is drafted.
