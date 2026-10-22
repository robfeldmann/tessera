---
kind: widget
status: specified
---

# ProgressView

`ProgressView` shows progress, in one row where it fits. With a `value` it draws a determinate bar, a label, and a current-value label that defaults to the percent. Without a `value` it draws an indeterminate spinner glyph and an optional label. The label is content: when label, bar and percent do not fit one row, the label moves above the bar and wraps (owner decision, 2026-10-18; see Narrow). The app owns every number and string: value, total, label, current-value label, and spinner style come from the initializer or modifiers, redeclared on every update (key D2). The view stores none of them. The indeterminate form is a [motion view](../../spec/phase-4/motion-views-and-the-tick-requirement.md): it derives its frame from a clock the environment supplies (key L1), so it keeps no timer, and it declares a tick requirement at its frame set's interval (key L2; see State model). Gauge is post-1.0 (owner decision, 2026-10-10); its threshold tones and tick markers are not part of this doc.

The determinate and indeterminate forms share one doc because they share a row, a label, and the same width rules. Decisions attributed to "owner decision, omp2 review, 2026-10" are the owner's answers on the reviewed omp2 components.

Standard [Slice 7](../../spec/phase-4/slice-07-catalog-integration.md) controlled-widget rule applies: the app owns the binding; the view derives its presentation.

## Prior art

- omp2 `Progress` ([progress.rs](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/progress.rs#L12-L111)): copy the one-row label, bar, and trailing percent, and the value clamped to `[0, max]`. Reject its row without truncation: a long label clips the bar and the percent off the right edge. Owner decision, omp2 review, 2026-10: the bar and percent stay and the label gives way first. Owner decision, 2026-10-18: the label is content, so it moves to its own wrapping rows above the bar instead of truncating, as SwiftUI's linear ProgressView draws its label above; it tail-truncates only under a fixed one-row height. The owner also rejected the percent-from-total reading of `max=4` (see Current-value labels). omp2's `value` and `max` attributes, refreshed with `set_prop`, become plain initializer parameters (keys D2, A8).
- omp2 `Spinner` ([spinner.rs](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/spinner.rs#L16-L139)): copy the glyph-then-label row and the braille default. Reject its markup path: `<spinner>` renders no label from `label=` or from its body, so markup puts a sibling `Text` in a row. Tessera's label is an initializer argument, so the label is always drawn.
- omp2 frame timing ([context.rs](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/context.rs#L288-L306), [anim.rs](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/anim.rs#L222-L241)): copy the frame choice from elapsed time: `(now / interval) mod frames.count` (key L3). The clock itself is supplied by the environment (key L1). Reject the per-node wake deadline ([`PaintCtx::wake`](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/component.rs#L1453-L1458)): the view declares a tick requirement that the graph aggregates instead (key L2).
- SwiftUI [`ProgressView`](https://developer.apple.com/documentation/swiftui/progressview) and [`ProgressViewStyle`](https://developer.apple.com/documentation/swiftui/progressviewstyle) supply the vocabulary: `value` and `total`, a label, a `currentValueLabel`, and styles chosen with `progressViewStyle(_:)`.

## API direction

The public API is SwiftUI-shaped. A supplied `value` makes the view determinate; without one it is indeterminate:

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

// ◢ ◣ ◤ ◥ are app-supplied and depend on the font's Geometric Shapes coverage
// (tokens.md#spinners).
ProgressView()
    .progressViewStyle(.spinner(frames: ["◢", "◣", "◤", "◥"], interval: .milliseconds(100)))
```

Modifier and set names (`.spinner(.braille)`, `.spinner(.orbit)`, `.spinner(frames:interval:)`) are settled as written (owner decision, 2026-10-10).

## Anatomy

### Determinate

One row: the label first, then the bar, then the percent. The bar fills what the label and percent leave.

```wireframe 40x1
Downloading model weights ██████░░░░ 62%
```

```text
Callouts (40x1, 0-based):
1. r0 c0-c24   Label -- Text, token `primary`; content, wraps (moves above the bar when the row is too narrow)
2. r0 c26-c31  Fill -- bar glyphs, token `accent`; chrome, one row; the bar keeps at least four cells
3. r0 c32-c35  Track -- empty bar glyphs, token `border`; chrome, one row
4. r0 c37-c39  Percent -- `62%`, token `secondary`; the default current-value label; atomic value
```

> Wrap exception (rules 1 and 2): the percent and an app-supplied current-value label are atomic: they never wrap or truncate. The label gives way first, by moving above the bar. (owner decision, 2026-10-18)

```text
── chars ──
Downloading model weights ██████░░░░ 62%
── style ──
AAAAAAAAAAAAAAAAAAAAAAAAAABBBBBBCCCC.DDD
── legend ──
.  default
A  fg=primary
B  fg=accent
C  fg=border
D  fg=secondary
```

### Indeterminate

One spinner frame, a space, then the label. A Nerd Font frame takes two cells, the glyph and a real space that is also the gap; every other frame takes one cell followed by the gap. The label starts at c2 for every set, so it does not shift as the spinner turns ([spinners](../tokens.md#spinners); owner decision, 2026-10-19). The frame shown is derived from the clock; this grid shows the braille default at one instant. The label is content and wraps beside the spinner, its continuation rows hanging under the label text; under a fixed one-row height it tail-truncates (owner decision, 2026-10-18; the hanging indent is an inference).

```wireframe 21x1
⠋ Indexing repository
```

```text
Callouts (21x1, 0-based):
1. r0 c0       Spinner frame -- the active frame: one cell, or under `.nerdFont` the glyph plus its blank cell at c1, token `accent`
2. r0 c2-c20   Label -- Text, token `primary`; supplied by the app; content, wraps
```

At 12 columns the label wraps:

```wireframe 12x2
⠋ Indexing
  repository
```

```text
Callouts (12x2, 0-based):
1. r0 c0-c1    Spinner frame -- the active frame: one cell, or under `.nerdFont` the glyph plus its blank cell at c1, token `accent`; chrome, one row
2. r0-r1 c2-c11  Label -- Text, token `primary`; content, wraps, continuation hangs at c2
```

### Frame sets

Each built-in set and the custom example, in frame order. These rows run past 40 cells, so this is a text reference rather than a wireframe block.

```text standalone
── chars ──
braille  ⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏
orbit    ⣾ ⣽ ⣻ ⢿ ⡿ ⣟ ⣯ ⣷
clock    󱑖 󱑋 󱑌 󱑍 󱑎 󱑏 󱑐 󱑑 󱑒 󱑓 󱑔 󱑕
arc           
slices   󰪞 󰪟 󰪠 󰪡 󰪢 󰪣 󰪤 󰪥
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
HHHHHHHHHFFFFFFFMMMMMMMMMMMMMMMMMMMMMMMMMMMM
── legend ──
.  default
H  fg=secondary bold
F  fg=accent
M  fg=secondary
```

Set rules:

- `braille` (10 frames, 80 ms) is the default; the owner asked for it, and omp2 already uses it (owner decision, omp2 review, 2026-10).
- `orbit` (8 frames, 80 ms) is omp2's status spinner: the dot runs clockwise around a full braille cell. `.progressViewStyle(.spinner(.orbit))` selects it.
- `clock` (12 frames, 80 ms) is a Nerd Font clock face whose hand steps clockwise. It falls back to `orbit` without a Nerd Font.
- `arc` (Nerd Font `progress-spinner-1` to `-6`, U+EE06 to U+EE0B, 100 ms) is an arc of a circle's outline that turns clockwise. `slices` (Nerd Font `circle-slice-1` to `-8`, U+F0A9E to U+F0AA5, 125 ms) fills one eighth at a time, up to a full disc, then restarts. Both were added to the built-in options at the owner's request, and both fall back to `orbit` without a Nerd Font (owner decision, omp2 review, 2026-10).
- `halves` (`◐◓◑◒`, 120 ms) is a plain Unicode set; its Geometric Shapes glyphs can render from a fallback font ([tokens.md#spinners](../tokens.md#spinners)). `quarters` is dropped: Maple Mono NF carries only `◶`, so the frames jump between fonts (owner decision, 2026-10-19).
- `line` (`|`, `/`, `-`, `\`) is the ASCII set, at 120 ms. In ASCII-only output every set draws `line` at 120 ms; each set carries its own interval (owner decision, 2026-10-10). A Nerd Font set that falls back to `orbit` runs at `orbit`'s 80 ms. Tessera has no reduced-motion setting in 1.0 (owner decision, 2026-10-19).
- A custom set is given as frames and an interval. The owner asked that the API accept an array of characters; a custom set may carry an ASCII fallback, and without one it falls back to `line`.
- Nerd Font frames (`clock`, `arc`, `slices`) take two cells, the glyph and the real space after it ([Nerd Font cells](../tokens.md#nerd-font-cells)); every other frame takes one cell plus the gap, so the label never shifts.

## States

### Mobile (40 columns)

The `mobile` state is the component at 40 columns, at its natural height, not padded to a frame (owner decision, 2026-10-10).

```wireframe 40x1
Downloading model weights ██████░░░░ 62%
```

```text
Callouts (40x1, 0-based):
1. r0 c0-c39   Progress row -- determinate, as in the anatomy above; at its natural size
```

### Narrow: 24 and 16 columns

When the full label, a minimum four-cell bar and the percent do not fit one row, the label moves to its own rows above the bar and wraps. The bar row fills the width: the bar takes what the percent and its gap leave (owner decision, 2026-10-18). The choice is [ViewThatFits](../primitives/view-that-fits.md), nested so that a fixed one-row height keeps the one-row form, and proposed the readable width when the width is nil:

```swift
ViewThatFits(in: .horizontal) {
    oneRow
    ViewThatFits(in: .vertical) {
        stacked
        oneRow
    }
}
```

The one-row form needs `25 + 1 + 4 + 1 + 3 = 34` cells for the fixture, so both widths stack.

```wireframe 24x3
Downloading model
weights
████████████░░░░░░░░ 62%
```

```text
Callouts (24x3, 0-based):
1. r0-r1 c0-c16  Label -- Text, `primary`; content, wraps
2. r2 c0-c11     Fill -- 12 of 20 bar cells, `accent`; chrome, one row
3. r2 c12-c19    Track -- `border`; chrome, one row
4. r2 c21-c23    Percent -- `62%` in `secondary`; atomic value
```

```text
── chars ──
Downloading model
weights
████████████░░░░░░░░ 62%
── style ──
AAAAAAAAAAAAAAAAA
AAAAAAA
BBBBBBBBBBBBCCCCCCCC.DDD
── legend ──
.  default
A  fg=primary
B  fg=accent
C  fg=border
D  fg=secondary
```

```wireframe 16x3
Downloading
model weights
███████░░░░░ 62%
```

```text
Callouts (16x3, 0-based):
1. r0-r1 c0-c12  Label -- Text, `primary`; content, wraps
2. r2 c0-c11     Bar -- 12 cells, 7 filled
3. r2 c13-c15    Percent -- `62%` in `secondary`; atomic value
```

```text
── chars ──
Downloading
model weights
███████░░░░░ 62%
── style ──
AAAAAAAAAAA
AAAAAAAAAAAAA
BBBBBBBCCCCC.DDD
── legend ──
.  default
A  fg=primary
B  fg=accent
C  fg=border
D  fg=secondary
```

### Fixed one-row height: 24 and 16 columns

Under a fixed height of one row the stacked form cannot fit, so the one-row form draws and the label tail-truncates with the truncation mark (`…` here; `~` in ASCII-only output, see the degradation ladder). The percent and a four-cell minimum bar stay. Space goes to the percent first, then the minimum bar, then the label, then the bar again (owner decision, omp2 review, 2026-10; kept for the one-row budget by owner decision, 2026-10-18).

```wireframe 24x1
Downloading mo… ██░░ 62%
```

```text
Callouts (24x1, 0-based):
1. r0 c0-c14   Label -- Text, truncated at the tail with `truncation.mark`; content, fixed one-row budget
2. r0 c16-c19  Bar -- four cells, the minimum bar: fill `accent`, track `border`
3. r0 c21-c23  Percent -- `62%` in `secondary`; never truncated
```

```text
── chars ──
Downloading mo… ██░░ 62%
── style ──
AAAAAAAAAAAAAAAABBCC.DDD
── legend ──
.  default
A  fg=primary
B  fg=accent
C  fg=border
D  fg=secondary
```

```wireframe 16x1
Downlo… ██░░ 62%
```

```text
Callouts (16x1, 0-based):
1. r0 c0-c6    Label -- Text, truncated at the tail with `truncation.mark`; content, fixed one-row budget
2. r0 c8-c11   Bar -- four cells, the minimum bar
3. r0 c13-c15  Percent -- `62%` in `secondary`
```

```text
── chars ──
Downlo… ██░░ 62%
── style ──
AAAAAAAABBCC.DDD
── legend ──
.  default
A  fg=primary
B  fg=accent
C  fg=border
D  fg=secondary
```

### Minimum (11x4)

The floor is the widest row of the stacked form (owner decision, 2026-10-18; it replaces the 9x1 floor of 2026-10-10 for a labelled bar). The label is primary content, and its widest word in the fixture, `Downloading`, is 11 cells; the bar row needs a four-cell bar, a space and the widest percent, `100%`, which is 9. The widest row is 11, and at 11 the label takes three rows (`Downloading`, `model`, `weights`) above the bar row, so the floor is 11x4. Below 11 the label's words break between grapheme clusters; the bar row keeps its 9-cell floor.

```wireframe 11x4
Downloading
model
weights
██████ 100%
```

```text
Callouts (11x4, 0-based):
1. r0-r2 c0-c10  Label -- Text, `primary`; content, wraps
2. r3 c0-c5      Bar -- six cells, all filled at 100%; token `accent`
3. r3 c7-c10     Percent -- `100%` in `secondary`; atomic value
```

```text
── chars ──
Downloading
model
weights
██████ 100%
── style ──
AAAAAAAAAAA
AAAAA
AAAAAAA
BBBBBB.DDDD
── legend ──
.  default
A  fg=primary
B  fg=accent
D  fg=secondary
```

### One-row floor (9x1)

Under a fixed one-row height, below about ten columns even the truncated label has no room, so it disappears and the row is the bar and the percent. The floor is a four-cell bar, a space, and a four-column percent (`100%`). The label-drop threshold is the owner's; the 9-column floor is derived from the minimum bar and the widest percent, and is settled for the one-row budget (owner decision, 2026-10-10).

```wireframe 9x1
████ 100%
```

```text
Callouts (9x1, 0-based):
1. r0 c0-c3    Bar -- four cells, all filled at 100%; token `accent`
2. r0 c5-c8    Percent -- `100%` in `secondary`; the label is absent at this width
```

```text
── chars ──
████ 100%
── style ──
BBBB.DDDD
── legend ──
.  default
B  fg=accent
D  fg=secondary
```

### Current-value labels

Each row is a determinate bar. The percent is the default current-value label. The `Steps` row supplies its own label, `3/4`, in place of the percent (owner decision, omp2 review, 2026-10). The bar still reads `value` over `total`. The view never derives a step count from `total`: `total: 4` could be four gigabytes as easily as four steps.

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
AAAAAAACCCCCCCCCCCCCCCCCCCCCCCCCCCCCC.DD
AAAAAAAAABBBBBBCCCCCCCCCCCCCCCCCCCCC.DDD
AAAAAAAAAABBBBBBBBBBBBBCCCCCCCCCCCCC.DDD
AAAAAAAABBBBBBBBBBBBBBBBBBBBBCCCCCCC.DDD
AAAAABBBBBBBBBBBBBBBBBBBBBBBBBBBBBB.DDDD
AAAAAABBBBBBBBBBBBBBBBBBBBBBCCCCCCCC.DDD
── legend ──
.  default
A  fg=primary
B  fg=accent
C  fg=border
D  fg=secondary
```

## State model

Schema: [README](../../design.md#state-model-table). The `Binding` rows are app-owned display data, plain initializer parameters redeclared on every update (key D2); the view writes none of them.

| State | Owner | Type | Reset or clamp rule |
| --- | --- | --- | --- |
| value | Binding | `Double?` | clamped to `0...total` each render; `nil` selects the indeterminate form |
| total | Binding | `Double` | at least 1; a smaller total is clamped to 1 |
| label | Binding | `Text` builder | app content; wraps, above the bar when the row is narrow; tail-truncates only under a fixed one-row height |
| currentValueLabel | Binding | `Text` builder? | replaces the percent when supplied; absent means percent |
| spinner style | Environment | `SpinnerSet` or custom frames and interval | a style choice; the label starts at c2 for every set |
| clock | Environment | instant | graph-owned (key L1): the app or the Phase 5 runtime supplies it; the view stores none |
| frame index | derived | `Int` | `(now / interval) mod frames.count`, recomputed each render; never stored (key L3) |
| tick requirement | derived | frame interval, or none | while indeterminate, the interval of the set actually drawn (a fallback set declares its own interval); none when determinate; recomputed on every update and aggregated by the graph over live nodes (key L2) |

The view stores no state, so it has no `NodeState` row and no responder. Plan 032 step 16.1 settles the Swift spellings of the clock value and the tick requirement ([motion views](../../spec/phase-4/motion-views-and-the-tick-requirement.md)).

## Key table

Schema: [README](../../design.md#key-table).

None. The view is not focusable and consumes no key input.

## Mouse table

Schema: [README](../../design.md#mouse-table).

None. The view has no pointer regions and consumes no pointer input.

## Sizing

Schema: [README](../../design.md#sizing-table). The determinate fixture is the `Downloading model weights` label at 62%. The height is 1 when the one-row form fits and grows by the label's wrapped rows in the stacked form.

| Proposal | Result | Rule |
| --- | --- | --- |
| nil x nil (determinate) | 72x1 | The ideal width is the readable width, 72 (owner decision, 2026-10-18): the bar fills what the label and percent leave (42 cells here), so stacked bars align |
| nil x nil (indeterminate) | 21x1 | No bar to fill: glyph, space and the label at its natural width (inference: capped at 72, wrapping beyond) |
| 40 x nil | 40x1 | One row fits: the bar takes the extra width (10 cells) and the label stays whole |
| 100 x nil (over-maximum) | 100x1 | A finite width is not capped: the readable width is only the nil-width ideal ([Readable width](../primitives/readable-width.md)), so the bar takes the extra width (70 cells), as at 40 |
| 24 x nil | 24x3 | One row needs 34 cells, so `ViewThatFits` stacks: label wraps to two rows above a 20-cell bar row (Narrow) |
| 16 x nil | 16x3 | Stacked: label wraps to two rows above a 12-cell bar row (Narrow) |
| 24 x 1 (fixed one row) | 24x1 | The stacked form cannot fit; the one-row form draws and the label tail-truncates (Fixed one-row height) |
| 11 x nil (minimum) | 11x4 | Floor: label words whole over three rows, then the bar row (Minimum) |
| 9 x 1 | 9x1 | tight one-row: the bar and the percent draw, and the label is absent |
| 8 x 1 (under-minimum) | 9x1 | under the one-row minimum: the view reports the 9x1 floor; the bar keeps four cells and the percent stays |

Below the 11-column floor with an unbounded height, the label's words break between grapheme clusters ([Text](../primitives/text.md#wrapping)), the bar row keeps its 9-cell floor, and the percent never clips.

## Environment

Tokens consumed, each defined in [tokens.md](../tokens.md).

- `primary`: label and indeterminate label.
- `accent`: bar fill and spinner glyph.
- `border`: bar track. `secondary`: percent and current-value label default ([text roles](../tokens.md#text-roles)).
- `bar.fill` and `bar.track`: the bar glyphs ([bars and ramps](../tokens.md#bars-and-ramps); key K9). The spinner sets and their intervals: [spinners](../tokens.md#spinners) (key K11).
- `truncation.mark`: tail truncation mark under a fixed one-row height, defined in [tokens.md](../tokens.md#truncation).
- `readableWidth` (environment): the determinate form's nil-width ideal; see [Readable width](../primitives/readable-width.md).

## Primitive dependencies

- [Text](../primitives/text.md): label, current-value label, percent, and spinner glyph.
- Tail truncation follows the `tail` policy, grapheme-safe, in [tokens.md](../tokens.md#truncation).
- [ViewThatFits](../primitives/view-that-fits.md) (plan 032 step 14.1): picks the one-row or the stacked form.
- [Readable width](../primitives/readable-width.md): the nil-width ideal.

## Requirements

- `determinate bar keeps a four-cell minimum when the label fills the row` (fixed one-row states)
- `label moves above the bar and wraps when label, bar and percent do not fit one row` (Narrow; owner decision, 2026-10-18)
- `label tail-truncates before the bar or percent is clipped under a fixed one-row height` (Fixed one-row height; owner decision, 2026-10-18)
- `label is dropped below about ten columns under a fixed one-row height` (One-row floor)
- `percent and supplied current-value label never wrap or truncate` (Determinate wrap exception; owner decision, 2026-10-18)
- `nil x nil determinate ideal width is the readable width and the bar fills the rest` (Sizing; owner decision, 2026-10-18)
- `stacked minimum is 11x4 for the fixture label` (Minimum; owner decision, 2026-10-18)
- `indeterminate label wraps beside the spinner` (Indeterminate; owner decision, 2026-10-18)
- `percent is the default current-value label` (current-value labels state)
- `supplied current-value label replaces the percent` (current-value labels state)
- `value is clamped to the closed range from zero to total` (state model: value)
- `indeterminate label starts two cells in for every frame set` (indeterminate anatomy; frame sets)
- `braille is the default spinner frame set` (frame sets)
- `nerd font spinner sets fall back to orbit without a nerd font` (frame sets)
- `ascii-only output draws every spinner set with line` (frame sets; degradation)
- `custom frames without an ascii fallback draw line in ascii-only output` (frame sets)
- `nerd font spinner frame is followed by a real space` (frame sets; [Nerd Font cells](../tokens.md#nerd-font-cells))
- `built-in spinner sets run at their own intervals` (frame sets: braille, orbit and clock 80 ms, arc 100 ms, slices 125 ms, halves and line 120 ms)
- `quarters is not a built-in spinner set` (frame sets)
- `spinner frame derives from the supplied clock and stores no state` (state model: frame index)
- `indeterminate view declares a tick requirement at its frame set's interval` (state model: tick requirement)
- `determinate view declares no tick requirement` (state model: tick requirement)
- `nerd font set drawn as orbit declares orbit's interval` (state model: tick requirement; frame sets)
- `under-minimum proposal reports the 9x1 floor` (sizing table: 8x1)
- `tight 9x1 proposal draws the bar and percent without the label` (sizing table: 9x1)
- `determinate bar takes the proposed width and the label stays whole when one row fits` (sizing table: 40 x nil)
- `determinate bar fills a proposal wider than the readable width` (sizing table: 100 x nil)

## Degradation

- ASCII-only: the truncation mark under a fixed one-row height becomes `~` ([degradation ladder](../tokens.md#degradation-ladder)). Every spinner set draws `line`. The determinate bar draws `#` for fill and `.` for track in ASCII-only output (owner decision, 2026-10-10).
- `NO_COLOR` and 16-color: roles resolve to their fallbacks per the [roles](../tokens.md#roles) rules. The bar stays legible through its glyphs.
- Below the 11x4 minimum the label's words break between grapheme clusters and the bar row keeps its 9-cell floor. Under a fixed one-row height below 9 columns the row draws the bar and percent only; the view reports its 9x1 minimum rather than hiding the percent.

This design was reviewed against the [Phase 4 theses](../../spec/phase-4.md): every number and string is an app-owned value redeclared on each update, the spinner frame is a pure function of the environment's clock, the tick requirement is declared for the graph to aggregate rather than scheduled by the view, and the row is deterministic integer-cell output with no responder.

## Open questions

- **Shimmer and elapsed time (key L5).** The omp2 review's owner decision 3 (2026-10-08) reads: "The animation path is in 1.0, so indeterminate `ProgressView`, elapsed time, and shimmer are too." It puts shimmer, omp2's brightness crest sweeping across text ([anim.rs#L252-L262](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/anim.rs#L252-L262)), and elapsed time, a running count since a start instant, in 1.0 beside the spinner. But [spinners](../tokens.md#spinners) says the spinner is the only animation in the catalog, which is also why Tessera has no reduced-motion setting in 1.0, and no catalog doc defines shimmer or elapsed time. Do shimmer and elapsed time ship in 1.0, and if so, is each a ProgressView style or its own motion view? Blocks `ready`: a second motion view changes the reduced-motion reasoning this doc cites.

## Inspiration

No inbox entries yet.
