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

| Family     | Full        | `NO_COLOR`         | 16-color        | ASCII-only   |
| ---------- | ----------- | ------------------ | --------------- | ------------ |
| borders    | any set     | unchanged          | unchanged       | `ascii` set  |
| selection  | fill + bar  | reverse video only | indexed reverse | `>` gutter   |
| focus      | accent      | bold               | indexed accent  | bold         |
| scrollbar  | track+thumb | unchanged          | unchanged       | `\|` and `#` |
| truncation | `…`         | unchanged          | unchanged       | `~`          |

## Open questions

- Accent color: one accent token or a small semantic palette (accent, warning,
  destructive)? Lean small palette, decided when Slice 3 styling lands.
- Should `focus.border` imply a title-position change (SwiftUI-style) or stay purely
  stylistic? Defer until Border primitive is drafted.
