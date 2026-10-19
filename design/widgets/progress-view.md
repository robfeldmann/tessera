---
kind: widget
status: wireframed
---

# ProgressView

`ProgressView` shows progress in one row. With a `value` it draws a determinate bar, a
label, and a current-value label that defaults to the percent. Without a `value` it draws
an indeterminate spinner glyph and an optional label. The app owns every number and
string: value, total, label, current-value label, and spinner style come from the
initializer or modifiers. The view stores none of them. The spinner frame is computed from
a clock the environment supplies, so the view keeps no timer. The tick requirement is
declared, as plan 032 step 16.1 specifies. Gauge is post-1.0 (owner decision, 2026-10-10);
its threshold tones and tick markers are not part of this doc.

The determinate and indeterminate forms share one doc because they share a row, a label,
and the same width rules. Decisions attributed to "owner decision, omp2 review, 2026-10"
are the owner's answers on the reviewed omp2 components.

Standard
[Slice 7](../../docs/Spec.md#slice-7-catalog-integration--list-section-controlled-widgets-and-the-showcase)
controlled-widget rule applies: the app owns the binding; the view derives its
presentation.

## Prior art

- omp2 `Progress`
  ([progress.rs](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/progress.rs#L12-L111)):
  copy the one-row label, bar, and trailing percent; the value clamped to `[0, max]`; the
  integer percent; the accent fill over a muted track. Reject its label-first layout
  without truncation: a long label clips the bar and the percent off the right edge. Owner
  decision, omp2 review, 2026-10: the bar and percent stay, and the label truncates first
  at the tail. The owner also rejected the percent-from-total reading of `max=4` (see
  Current-value labels).
- omp2 `Spinner`
  ([spinner.rs](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/spinner.rs#L16-L139)):
  copy the glyph-then-label row and the braille default. Reject its markup path:
  `<spinner>` renders no label from `label=` or from its body, so markup puts a sibling
  `Text` in a row. Tessera's label is an initializer argument, so the label is always
  drawn.
- omp2 frame timing
  ([context.rs](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/context.rs#L288-L306),
  [anim.rs](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/anim.rs#L222-L241)):
  copy the frame choice from elapsed time: `(now / interval) mod frames.count`. The clock
  itself is supplied by the environment (plan 032 step 16.1).
- SwiftUI [`ProgressView`](https://developer.apple.com/documentation/swiftui/progressview)
  and
  [`ProgressViewStyle`](https://developer.apple.com/documentation/swiftui/progressviewstyle)
  supply the vocabulary: `value` and `total`, a label, a `currentValueLabel`, and styles
  chosen with `progressViewStyle(_:)`.

## API direction

The public API is SwiftUI-shaped. A supplied `value` makes the view determinate; without
one it is indeterminate:

```swift
// Determinate. value is clamped to 0...total; the default current-value label is the percent.
ProgressView(value: 62, total: 100) {
    Text("Downloading model weights")
}

// The app supplies its own current-value label instead of the percent.
ProgressView(value: 3, total: 4) {
    Text("Steps")
} currentValueLabel: {
    Text("3/4")
}

// Indeterminate. The default spinner set is braille.
ProgressView {
    Text("Indexing repository")
}

ProgressView()
    .progressViewStyle(.spinner(.orbit))

ProgressView()
    .progressViewStyle(.spinner(frames: ["◢", "◣", "◤", "◥"], interval: .milliseconds(100)))
```

Modifier and set names (`.spinner(.braille)`, `.spinner(.orbit)`,
`.spinner(frames:interval:)`) are settled as written (owner decision, 2026-10-10).

## Anatomy

### Determinate

One row: the label first, then the bar, then the percent.

```wireframe 40x1
Downloading model weights ██████░░░░ 62%
```

```text
Callouts (40x1, 0-based):
1. r0 c0-c24   Label -- Text, token `semantic.primary`; truncates at the tail first
2. r0 c26-c31  Fill -- bar glyphs, token `semantic.accent`; the bar keeps at least four cells
3. r0 c32-c35  Track -- empty bar glyphs, token `muted` (token pending plan 032 step 5.3)
4. r0 c37-c39  Percent -- `62%`, token `muted`; the default current-value label
```

```text
── chars ──
Downloading model weights ██████░░░░ 62%
── style ──
AAAAAAAAAAAAAAAAAAAAAAAAAABBBBBBCCCCCCCC
── legend ──
.  default
A  fg=primary
B  fg=accent
C  fg=muted
```

### Indeterminate

One spinner glyph, a space, then the label. Every frame is one cell wide, so the label
does not shift as the spinner turns. The frame shown is derived from the clock; this grid
shows the braille default at one instant.

```wireframe 21x1
⠋ Indexing repository
```

```text
Callouts (21x1, 0-based):
1. r0 c0       Spinner glyph -- one cell from the active frame set, token `semantic.accent`
2. r0 c2-c20   Label -- Text, token `semantic.primary`; supplied by the app
```

### Frame sets

Each built-in set and the custom example, in frame order. These rows run past 40 cells, so
this is a text reference rather than a wireframe block.

```text
── chars ──
braille  ⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏
orbit    ⣾ ⣽ ⣻ ⢿ ⡿ ⣟ ⣯ ⣷
clock    󱑖 󱑋 󱑌 󱑍 󱑎 󱑏 󱑐 󱑑 󱑒 󱑓 󱑔 󱑕
arc           
slices   󰪞 󰪟 󰪠 󰪡 󰪢 󰪣 󰪤 󰪥
quarters ◴ ◷ ◶ ◵
halves   ◐ ◓ ◑ ◒
line     | / - \
custom   ◢ ◣ ◤ ◥   frames: ["◢","◣","◤","◥"]
── style ──
HHHHHHHHHFFFFFFFFFFFFFFFFFFF
HHHHHHHHHFFFFFFFFFFFFFFF
HHHHHHHHHFFFFFFFFFFFFFFFFFFFFFFF
HHHHHHHHHFFFFFFFFFFF
HHHHHHHHHFFFFFFFFFFFFFFF
HHHHHHHHHFFFFFFF
HHHHHHHHHFFFFFFF
HHHHHHHHHFFFFFFF
HHHHHHHHHFFFFFFFMMMMMMMMMMMMMMMMMMMMMMMMMMMM
── legend ──
.  default
H  fg=secondary bold
F  fg=accent
M  fg=muted
```

Set rules:

- `braille` (10 frames, 80 ms) is the default; the owner asked for it, and omp2 already
  uses it (owner decision, omp2 review, 2026-10).
- `orbit` (8 frames, 80 ms) is omp2's status spinner: the dot runs clockwise around a full
  braille cell. `.progressViewStyle(.spinner(.orbit))` selects it.
- `clock` (12 frames) is a Nerd Font clock face whose hand steps clockwise. It falls back
  to `orbit` without a Nerd Font.
- `arc` (Nerd Font `progress-spinner-1` to `-6`, U+EE06 to U+EE0B) is an arc of a circle's
  outline that turns clockwise. `slices` (Nerd Font `circle-slice-1` to `-8`, U+F0A9E to
  U+F0AA5) fills one eighth at a time, up to a full disc, then restarts. Both were added
  to the built-in options at the owner's request, and both fall back to `orbit` without a
  Nerd Font (owner decision, omp2 review, 2026-10).
- `quarters` (`◴◷◶◵`) and `halves` (`◐◓◑◒`) are plain Unicode sets.
- `line` (`|`, `/`, `-`, `\`) is the ASCII set, at 120 ms. In ASCII-only output every set
  draws `line` at 120 ms; each set carries its own interval (owner decision, 2026-10-10).
- A custom set is given as frames and an interval. The owner asked that the API accept an
  array of characters; a custom set may carry an ASCII fallback, and without one it falls
  back to `line`.
- Every frame, in every set, is one cell wide, so the label never shifts.

## States

### Mobile (40 columns)

The `mobile` state is the component at 40 columns, at its natural height, not padded to a
frame (owner decision, 2026-10-10).

```wireframe 40x1
Downloading model weights ██████░░░░ 62%
```

```text
Callouts (40x1, 0-based):
1. r0 c0-c39   Progress row -- determinate, as in the anatomy above; at its natural size
```

### Narrow: 24 and 16 columns

The percent and a four-cell minimum bar stay. The label truncates at the tail with the
truncation mark (`…` here; `~` in ASCII-only output, see the degradation ladder). Space
goes to the percent first, then the minimum bar, then the label, then the bar again (owner
decision, omp2 review, 2026-10).

```wireframe 24x1
Downloading mo… ██░░ 62%
```

```text
Callouts (24x1, 0-based):
1. r0 c0-c14   Label -- Text, truncated at the tail with `truncation.mark`
2. r0 c16-c19  Bar -- four cells, the minimum bar: fill `semantic.accent`, track `muted`
3. r0 c21-c23  Percent -- `62%` in `muted`; never truncated
```

```text
── chars ──
Downloading mo… ██░░ 62%
── style ──
AAAAAAAAAAAAAAAABBCCCCCC
── legend ──
.  default
A  fg=primary
B  fg=accent
C  fg=muted
```

```wireframe 16x1
Downlo… ██░░ 62%
```

```text
Callouts (16x1, 0-based):
1. r0 c0-c6    Label -- Text, truncated at the tail with `truncation.mark`
2. r0 c8-c11   Bar -- four cells, the minimum bar
3. r0 c13-c15  Percent -- `62%` in `muted`
```

```text
── chars ──
Downlo… ██░░ 62%
── style ──
AAAAAAAABBCCCCCC
── legend ──
.  default
A  fg=primary
B  fg=accent
C  fg=muted
```

### Minimum (9x1)

Below about ten columns even the truncated label has no room, so it disappears and the row
is the bar and the percent. The floor is a four-cell bar, a space, and a four-column
percent (`100%`). The label-drop threshold is the owner's; the 9-column floor is derived
from the minimum bar and the widest percent, and is settled (owner decision, 2026-10-10).

```wireframe 9x1
████ 100%
```

```text
Callouts (9x1, 0-based):
1. r0 c0-c3    Bar -- four cells, all filled at 100%; token `semantic.accent`
2. r0 c5-c8    Percent -- `100%` in `muted`; the label is absent at this width
```

```text
── chars ──
████ 100%
── style ──
BBBB.CCCC
── legend ──
.  default
B  fg=accent
C  fg=muted
```

### Current-value labels

Each row is a determinate bar. The percent is the default current-value label. The `Steps`
row supplies its own label, `3/4`, in place of the percent (owner decision, omp2 review,
2026-10). The bar still reads `value` over `total`. The view never derives a step count
from `total`: `total: 4` could be four gigabytes as easily as four steps.

```wireframe 40x6
Queued ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ 0%
Fetching ██████░░░░░░░░░░░░░░░░░░░░░ 25%
Compiling █████████████░░░░░░░░░░░░░ 50%
Linking █████████████████████░░░░░░░ 75%
Done ██████████████████████████████ 100%
Steps ██████████████████████░░░░░░░░ 3/4
```

```text
Callouts (40x6, 0-based):
1. r0-r4       Percent rows -- default current-value label `{percent}%` from value over total
2. r5 c37-c39  Supplied label -- app `currentValueLabel` `Text("3/4")` replaces the percent
```

```text
── chars ──
Queued ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ 0%
Fetching ██████░░░░░░░░░░░░░░░░░░░░░ 25%
Compiling █████████████░░░░░░░░░░░░░ 50%
Linking █████████████████████░░░░░░░ 75%
Done ██████████████████████████████ 100%
Steps ██████████████████████░░░░░░░░ 3/4
── style ──
AAAAAAACCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC
AAAAAAAAABBBBBBCCCCCCCCCCCCCCCCCCCCCCCCC
AAAAAAAAAABBBBBBBBBBBBBCCCCCCCCCCCCCCCCC
AAAAAAAABBBBBBBBBBBBBBBBBBBBBCCCCCCCCCCC
AAAAABBBBBBBBBBBBBBBBBBBBBBBBBBBBBBCCCCC
AAAAAABBBBBBBBBBBBBBBBBBBBBBCCCCCCCCCCCC
── legend ──
.  default
A  fg=primary
B  fg=accent
C  fg=muted
```

## State model

Schema: [README](../README.md#state-model-table).

| State             | Owner       | Type                                       | Reset or clamp rule                                                       |
| ----------------- | ----------- | ------------------------------------------ | ------------------------------------------------------------------------- |
| value             | Binding     | `Double?`                                  | clamped to `0...total` each render; `nil` selects the indeterminate form  |
| total             | Binding     | `Double`                                   | at least 1; a smaller total is clamped to 1                               |
| label             | Binding     | `Text` builder                             | app content; truncates at the tail when the row is narrow                 |
| currentValueLabel | Binding     | `Text` builder?                            | replaces the percent when supplied; absent means percent                  |
| spinner style     | Environment | `SpinnerSet` or custom frames and interval | a style choice; every frame one cell wide                                 |
| clock             | Environment | instant                                    | supplied by the environment (plan 032 step 16.1); the view stores none    |
| frame index       | derived     | `Int`                                      | `(now / interval) mod frames.count`, recomputed each render; never stored |

The view stores no state, so it has no `NodeState` row and no responder.

## Key table

Schema: [README](../README.md#key-table).

None. The view is not focusable and consumes no key input.

## Mouse table

Schema: [README](../README.md#mouse-table).

None. The view has no pointer regions and consumes no pointer input.

## Sizing

| Proposal | Result | Rule                                                                                              |
| -------- | ------ | ------------------------------------------------------------------------------------------------- |
| 8x1      | 9x1    | under the minimum: the view reports the 9x1 floor; the bar keeps four cells and the percent stays |
| 9x1      | 9x1    | tight fit: the bar and the percent draw, and the label is absent                                  |
| 40x1     | 40x1   | fills the proposed width: the bar takes the extra width and the label truncates at the tail       |

The `nil x nil` ideal-width row is not written; the ideal width is open (see Open
questions). The height is always 1.

## Environment

Tokens consumed, each defined in [tokens.md](../tokens.md) when the row exists; otherwise
the token is pending plan 032 step 5.3.

- `semantic.primary`: label and indeterminate label.
- `semantic.accent`: bar fill and spinner glyph.
- `muted` (token pending plan 032 step 5.3): bar track, percent, and current-value label
  default. `muted` is not in [tokens.md](../tokens.md).
- `truncation.mark`: tail truncation mark, defined in
  [tokens.md](../tokens.md#truncation).

## Primitive dependencies

- [Text](../primitives/text.md): label, current-value label, percent, and spinner glyph.
- Tail truncation follows the `tail` policy, grapheme-safe, in
  [tokens.md](../tokens.md#truncation).

## Requirements

- `determinate bar keeps a four-cell minimum when the label fills the row` (narrow-24 and
  narrow-16 states)
- `label truncates at the tail before the bar or percent is clipped` (anatomy; narrow
  states)
- `label is dropped below about ten columns` (minimum state)
- `percent is the default current-value label` (current-value labels state)
- `supplied current-value label replaces the percent` (current-value labels state)
- `value is clamped to the closed range from zero to total` (state model: value)
- `indeterminate glyph is one cell wide in every frame` (indeterminate anatomy; frame
  sets)
- `braille is the default spinner frame set` (frame sets)
- `nerd font spinner sets fall back to orbit without a nerd font` (frame sets)
- `ascii-only output draws every spinner set with line` (frame sets; degradation)
- `custom frames without an ascii fallback draw line in ascii-only output` (frame sets)
- `spinner frame derives from the supplied clock and stores no state` (state model: frame
  index)
- `under-minimum proposal reports the 9x1 floor` (sizing table: 8x1)
- `tight 9x1 proposal draws the bar and percent without the label` (sizing table: 9x1)
- `determinate bar takes the proposed width and the label truncates` (sizing table: 40x1)

## Degradation

- ASCII-only: the truncation mark becomes `~`
  ([degradation ladder](../tokens.md#degradation-ladder)). Every spinner set draws `line`.
  The determinate bar draws `#` for fill and `.` for track in ASCII-only output (owner
  decision, 2026-10-10).
- `NO_COLOR` and 16-color: roles resolve to their fallbacks per the
  [semantic styles](../tokens.md#semantic-styles) rules. The bar stays legible through its
  glyphs.
- Below the 9-column minimum the row draws the bar and percent only. The view reports its
  9x1 minimum rather than hiding the percent.

## Open questions

- Ideal width. The `nil x nil` sizing row is not written. The review answered the floor
  and the proposal rules only; the ideal width needs a decision before the sizing table is
  complete.
- `muted` and `warning` are not in tokens.md. The 1.0 role set does not add them. Token
  pending plan 032 step 5.3.

## Inspiration

No inbox entries yet.
