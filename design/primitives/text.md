---
kind: primitive
status: ready
---

# Text

`Text` is Tessera's stateless leaf for rendering an immutable `String` into its allocated
rectangle. It measures display-cell width at extended-grapheme-cluster boundaries,
preserves source line breaks, word-wraps at any finite width, and writes top-leading into
its `RenderRegion`. It has no focus, binding, `NodeState`, key handling, pointer handling,
scrolling, border, padding, title, or alignment policy. Those concerns compose through
layout, decoration, styling, ScrollView, and widgets.

The accepted public direction is `Text(_ content: String)`. Text is a leaf
(`Body == Never`) and has no mutable business or ephemeral state. Its content is immutable
view configuration; callers replace the value and reconcile the graph. Wrapping needs no
configuration: Text wraps whenever its width is finite (owner decision, 2026-10-18). The
row budget (`lineLimit`) and the truncation mode arrive through the environment, as in
SwiftUI.

## Prior art

- Ratatui Paragraph: `~/Developer/ratatui/ratatui/main/ratatui-widgets/src/paragraph.rs` —
  copy grapheme-aware text rendering and word wrapping. Reject its opt-in wrap policy,
  combining text, alignment, scrolling, a surrounding Block, and widget-local style into
  Tessera's `Text`: they compose separately as layout, ScrollView, decoration, and style
  modifiers.
- omp2 `TextLeaf` truncation -- `crates/tui/src/components/text.rs` `limited_text` (lines
  82-88) at the pinned
  [omp2 source](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/text.rs#L82-L88).
  Copy the choice of which end keeps text; reject its UTF-16 unit limit, because Tessera
  measures truncation in display cells.
- Apple SwiftUI [Text](https://developer.apple.com/documentation/swiftui/text) — copy the
  immutable value-view model, composition with modifiers, wrapping by default, and
  `lineLimit(_:)` and `truncationMode(_:)` as environment modifiers whose truncation
  applies to the last visible line. Reject treating Text as an input control; editable
  text belongs to TextField.
- Tessera
  [Slice 1](../../docs/Spec.md#slice-1-tesseracore--view-viewgraph-reconciliation-text) —
  copy the leaf seam, top-leading `RenderRegion` rendering, and no-wrap initial delivery.
  Tessera [Slice 3](../../docs/Spec.md#slice-3-styling-text-wrapping-and-decoration)
  supplies wrapping, truncation, style inheritance, and decoration composition.

## Anatomy

Natural single-line fixture:

```wireframe 14x1
Hello, Tessera
```

```text
Callouts (14x1, 0-based):
1. r0 c0-c13 Text content -- immutable source graphemes, rendered top-leading at their
   display-cell width with the resolved full Style.
```

Text measures terminal cells, not Unicode scalar count. Wide CJK and emoji-presentation
clusters occupy two cells; a combining sequence stays attached to its base and occupies
the base's width.

```wireframe 9x1
東京 👩🏽‍💻 é
```

```text
Callouts (9x1, 0-based):
1. r0 c0-c3 Wide text -- `東京` occupies four cells.
2. r0 c5-c6 Emoji cluster -- `👩🏽‍💻` is one extended grapheme cluster and occupies two cells.
3. r0 c8 Combining sequence -- `é` occupies one cell; the combining mark never gains a cell.
```

Source `\r\n` normalizes to one source newline at `Text` initialization; a lone `\r`
remains literal source content. Under a nil width proposal Text keeps each source line as
one row and invents no line breaks.

```wireframe 8x2
release
notes
```

```text
Callouts (8x2, 0-based):
1. r0-r1 c0-c6 Source rows -- the normalized newline separates two independently measured
   and rendered source lines; trailing cells remain untouched by Text.
```

### Wrapping

At any finite width Text wraps each source line at Unicode word boundaries, whatever the
height (owner decision, 2026-10-18). A word moves to the next row when it fits there
intact:

```wireframe 8x2
Ship one
thing
```

```text
Callouts (8x2, 0-based):
1. r0 c0-c7 First wrapped row -- the assigned width is eight cells.
2. r1 c0-c4 Wrapped continuation -- `thing` moves to the next row rather than breaking a
   word that fits intact.
```

A word wider than the whole width breaks between extended grapheme clusters; it is never
clipped. The same text at four cells:

```wireframe 4x4
Ship
one
thin
g
```

```text
Callouts (4x4, 0-based):
1. r0-r1 c0-c3 Whole words -- `Ship` and `one` each fit in four cells.
2. r2-r3 c0-c3 Broken word -- `thing` is five cells wide, so it fills r2 and continues on
   r3; the break falls between graphemes and never splits a cluster.
```

A grapheme wider than the whole width (a two-cell `東` at width one) cannot be drawn; Text
draws `truncation.mark` in its place, on its own row. Wrapped Text reports the width of
its widest row, which can be narrower than the proposal.

### Row budget

Text gets every row it needs when its height is unbounded: a nil height proposal, or
ScrollView content. A finite height proposal is a row budget, and so is `lineLimit(n)`;
when both are present the smaller wins. When the wrapped rows exceed the budget, Text
fills the budget and only the last visible row ends in the mark (owner decision,
2026-10-18):

```wireframe 8x1
Ship on…
```

```text
Callouts (8x1, 0-based):
1. r0 c0-c6 Last visible row -- the remainder `Ship one thing`, cut to seven cells.
2. r0 c7    Budget mark -- `truncation.mark`, tail mode; it says rows are hidden.
```

Rows before the last wrap normally. The last visible row holds its remainder: the text
from that row's first grapheme to the end of its source line, laid out unwrapped and cut
to the width by the truncation mode. A two-row budget on a long status sentence at 24
columns:

```wireframe 24x2
Long status text that
would otherwise wrap ac…
```

```text
Callouts (24x2, 0-based):
1. r0 c0-c20 Wrapped row -- an ordinary word-wrapped row.
2. r1 c0-c22 Last visible row -- the remainder `would otherwise wrap across several rows of
             the panel`, cut to 23 cells at a grapheme boundary.
3. r1 c23    Budget mark -- `truncation.mark` in the last cell.
```

When the remainder fits and only later source lines are hidden, nothing in the row is cut,
so every mode draws the mark directly after the remainder. `Text("release\nnotes")` with
`.lineLimit(1)`:

```wireframe 8x1
release…
```

```text
Callouts (8x1, 0-based):
1. r0 c0-c6 Last visible row -- the whole first source line.
2. r0 c7    Hidden source line mark -- `truncation.mark` after the remainder; `notes` is
            hidden.
```

### Truncation

Owner decision, omp2 review, 2026-10: truncation follows SwiftUI. `.truncationMode(_:)`
takes a `TruncationMode` and defaults to `.tail`; `.head` and `.middle` are additional
modes. Truncation applies only to the last visible row, and only when content is hidden:
the wrapped rows exceed the row budget, or a grapheme is wider than the whole width.

- `.tail` keeps the leading cells of the remainder and draws the mark after them.
- `.head` draws the mark in the first cell and keeps the trailing cells of the remainder.
- `.middle` keeps the first `ceil((width - 1) / 2)` cells, draws the mark, and keeps the
  remaining cells of the remainder after it.
- `.clip` draws no mark; the row keeps the leading cells of the remainder that fit.

Cuts are measured in display cells and never split an extended grapheme cluster. A wide
grapheme that would straddle the cut moves to the mark side: the kept text ends one cell
early, and the freed cell stays blank. The mark uses the text's resolved Style. Text owns
this cut: if a parent assigns a rectangle smaller than Text measured, Text lays out again
at the assigned width and height, so the overflow ends in the mark instead of a silent
clip.

Each row below is a separate `Text` with `.lineLimit(1)`. Path rows show tail, head, and
middle truncation at 40 columns (rows 0-2); the status sentence shows tail and middle
(rows 3-4).

```wireframe 40x5
crates/tui/src/components/markdown/rend…
…/markdown/render/table_layout_solver.rs
crates/tui/src/compo…le_layout_solver.rs
Long status text that would otherwise w…
Long status text tha…l rows of the panel
```

```text
Callouts (40x5, 0-based):
1. r0 c39   Tail truncation, default -- Text, `truncation.mark` in c39; c0-c38 keep the
            leading cells.
2. r1 c0    Head truncation -- Text, `truncation.mark` in c0; c1-c39 keep the trailing
            cells.
3. r2 c20   Middle truncation -- Text, `truncation.mark` in c20; c0-c19 are
            `ceil((40 - 1) / 2)` leading cells and c21-c39 keep the remaining cells.
4. r3 c39   Tail truncation, status sentence -- same rule as callout 1.
5. r4 c20   Middle truncation, status sentence -- same rule as callout 3.
```

The same source at 24 columns, with the same modes:

```wireframe 24x5
crates/tui/src/componen…
…/table_layout_solver.rs
crates/tui/s…t_solver.rs
Long status text that w…
Long status …f the panel
```

```text
Callouts (24x5, 0-based):
1. r0 c23   Tail truncation, default -- Text, `truncation.mark` in c23.
2. r1 c0    Head truncation -- Text, `truncation.mark` in c0.
3. r2 c12   Middle truncation -- Text, `truncation.mark` in c12; c0-c11 are
            `ceil((24 - 1) / 2)` leading cells and c13-c23 keep the remaining cells.
4. r3 c23   Tail truncation, status sentence -- same rule as callout 1.
5. r4 c12   Middle truncation, status sentence -- same rule as callout 3.
```

Clipping without a mark remains for non-text geometry (panes, borders, layers, and
overlays clipped by a parent's region), for ScrollView's viewport (its indicator is the
overflow cue), for the explicit `.clip` opt-out, and for components whose docs record a
deliberate wrap exception.

## Variants

| Configuration              | Earliest slice | Behavior                                                                                                                                                                                                                                                  |
| -------------------------- | -------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| default (no modifier)      | Slice 3        | Word-wraps at Unicode word boundaries for any finite width; a word wider than the width breaks between grapheme clusters. A nil width keeps source lines as rows. Slice 1 ships no wrapping and clips at the region edge until Slice 3 flips the default. |
| `.lineLimit(nil)`          | Slice 3        | Default. No app row budget: every row under a nil height; a finite height proposal is still a budget.                                                                                                                                                     |
| `.lineLimit(n)`            | Slice 3        | Row budget of `n` rows. The smaller of `n` and a finite height proposal wins. `n` below 1 traps before layout.                                                                                                                                            |
| `.truncationMode(.tail)`   | Slice 3        | Default. The last visible row keeps the leading cells of its remainder and ends in `truncation.mark`, cut at a grapheme-safe boundary.                                                                                                                    |
| `.truncationMode(.head)`   | Slice 3        | Draws the mark in the first cell and keeps the trailing cells of the remainder.                                                                                                                                                                           |
| `.truncationMode(.middle)` | Slice 3        | Keeps `ceil((width - 1) / 2)` leading cells of the remainder, draws the mark, then keeps the remaining cells.                                                                                                                                             |
| `.truncationMode(.clip)`   | Slice 3        | Opt-out: the last visible row keeps the leading cells of its remainder and draws no mark.                                                                                                                                                                 |

Wrapping decides how many rows Text needs; the row budget decides how many it shows;
truncation marks the last shown row when anything is hidden. Text never grows past its
budget to reveal a truncated suffix.

## Sizing

Text measures against the proposal and renders against its final rectangle. A finite width
wraps, and the result width is the widest displayed row, never wider than the proposal. A
nil width keeps source lines as rows. The row budget is the smaller of a finite height
proposal and `lineLimit`; with no budget Text reports every row. Height proposals never
stretch Text or add blank content rows.

Text declares no minimum: every finite width shows every grapheme. The smallest width at
which every word stays whole is the display width of the widest word (five cells for
`Ship one thing`); components derive their floors from it
([README](../README.md#wrap-and-truncation)).

| Configuration and proposal                       | Result | Rule                                                                                        |
| ------------------------------------------------ | ------ | ------------------------------------------------------------------------------------------- |
| `Text("Hello")`, nil x nil                       | 5x1    | Ideal is the display width of the longest source line and the source line count.            |
| `Text("Hello")`, 5x1                             | 5x1    | Tight allocation preserves the natural single-line fixture.                                 |
| `Text("Hello")`, 80x24                           | 5x1    | Extra proposal does not stretch Text or create blank rows.                                  |
| `Text("release\nnotes")`, nil x nil              | 7x2    | A nil width does not wrap; width is the longest source row and height the source row count. |
| `Text("a\r\nb")`, nil x nil                      | 1x2    | Public initialization normalizes CRLF to two one-cell source rows.                          |
| `Text("Ship one thing")`, 8xnil                  | 8x2    | A finite width wraps at word boundaries and a nil height reports every row.                 |
| `Text("Ship one thing")`, 8x5                    | 8x2    | A row budget larger than the rows needed adds no blank rows.                                |
| `Text("Ship one thing")`, 8x1                    | 8x1    | The height proposal is a one-row budget; the last visible row ends in the mark at c7.       |
| `Text("Ship one thing").lineLimit(1)`, 8xnil     | 8x1    | `lineLimit` sets the same one-row budget under an unbounded height.                         |
| `Text("Ship one thing")`, 4xnil                  | 4x4    | `thing` is wider than four cells, so it breaks between graphemes into `thin` and `g`.       |
| `Text("World")`, 3xnil                           | 3x2    | The overlong word breaks into `Wor` and `ld`; nothing is clipped.                           |
| `Text("World")`, 3x1                             | 3x1    | Two wrapped rows exceed the one-row budget; tail keeps `Wo` and draws the mark.             |
| `Text("World").truncationMode(.clip)`, 3x1       | 3x1    | Clip keeps `Wor` and draws no mark.                                                         |
| `Text("release\nnotes").lineLimit(1)`, nil x nil | 8x1    | The hidden second source line puts the mark directly after `release`.                       |
| `Text("東京")`, nil x nil                        | 4x1    | Two wide graphemes each occupy two terminal cells.                                          |
| `Text("東京")`, 3xnil                            | 2x2    | Each two-cell grapheme takes its own row; width is the widest row, not the proposal.        |
| `Text("東京")`, 1xnil                            | 1x2    | A grapheme wider than the whole width is drawn as the mark on its own row.                  |
| `Text("Hello")`, 0xnil                           | 0x1    | A zero width holds no grapheme and no mark; Text paints nothing.                            |
| `Text("")`, nil x nil                            | 0x1    | Empty content occupies one source row but paints no cells.                                  |

## Environment

| Input            | Text behavior                                                                                                                                      |
| ---------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- |
| inherited Style  | `defaultStyle` arrives with Slice 3; nearest ancestor wins per attribute, then explicit Text attributes win.                                       |
| shared modifiers | `.foreground`, `.background`, `.bold`, `.italic`, `.underline`, and `.style` are shared Slice 3 modifiers; Text has no private API.                |
| line limit       | `.lineLimit(_:)` writes `EnvironmentValues.lineLimit` (`Int?`, default `nil`); nearest ancestor wins, so one modifier on a List reaches every row. |
| truncation mode  | `.truncationMode(_:)` writes `EnvironmentValues.truncationMode` (`TruncationMode`, default `.tail`); nearest ancestor wins.                        |
| background fill  | `background` fills Text's allocated rectangle while foreground and attributes apply only to written cells.                                         |
| truncation mark  | `truncation.mark` supplies `…`, drawn in the text's resolved Style; ASCII-only output substitutes `~`.                                             |

A component that fixes a text region to one row (chrome) applies `.lineLimit(1)` directly
to that Text, so an app's inherited `lineLimit` reaches content but not chrome.

## Progressive slice sequence

1. **After Slice 1:** `Text` measures source lines by grapheme display width, renders
   top-leading through `RenderRegion`, preserves source newlines, and clips in its
   allocated region. It has no wrapping, truncation marker, inherited style API, focus, or
   input.
2. **After Slice 2:** Text composes with [linear stacks](stacks.md), [Frame](frame.md),
   [Padding](padding.md), alignment, and explicit allocated rectangles. Those wrappers own
   placement and insets; Text remains a leaf.
3. **After Slice 3:** Text wraps by default, honors row budgets from height proposals and
   `lineLimit`, and gains tail/head/middle/clip truncation, inherited full Styles,
   decoration composition, and ASCII marker degradation as fixture-backed behavior.
   Callers that relied on Slice 1 clipping pin `.lineLimit(1)`.
4. **After Slice 4 and later:** Text remains noninteractive. TextField, List, Button, and
   other widgets compose Text labels/content while owning focus, bindings, and input.

## Input routing

Text installs no responder. These explicit no-op rows make the routing contract
fixture-testable without giving a leaf focus or state.

| Key                      | Precondition | Effect                                  | Consumed |
| ------------------------ | ------------ | --------------------------------------- | -------- |
| printable characters     | always       | installs no handler; dispatch continues | no       |
| Enter                    | always       | installs no handler; dispatch continues | no       |
| Up / Down / Left / Right | always       | installs no handler; dispatch continues | no       |

| Event      | Region       | Precondition | Effect                                  | Consumed |
| ---------- | ------------ | ------------ | --------------------------------------- | -------- |
| click      | Text content | always       | installs no handler; dispatch continues | no       |
| drag       | Text content | always       | installs no handler; dispatch continues | no       |
| wheel-up   | Text content | always       | installs no handler; dispatch continues | no       |
| wheel-down | Text content | always       | installs no handler; dispatch continues | no       |

## Requirements

- `text measures natural width in terminal display cells` (anatomy: Text content; sizing:
  `Text("Hello")`, nil x nil).
- `text measures wide emoji and combining graphemes without splitting clusters` (anatomy:
  Wide text, Emoji cluster, and Combining sequence).
- `text preserves normalized source newline rows` (anatomy: Source rows; sizing:
  `Text("a\r\nb")`, nil x nil).
- `text does not wrap under a nil width proposal` (anatomy: Source rows; sizing:
  `Text("release\nnotes")`, nil x nil).
- `text word-wraps at any finite width by default` (wrapping: First wrapped row and
  Wrapped continuation; sizing: `Text("Ship one thing")`, 8xnil).
- `a word wider than the width breaks between grapheme clusters` (wrapping: Broken word;
  sizing: `Text("Ship one thing")`, 4xnil and `Text("World")`, 3xnil).
- `wrapped text reports the width of its widest row` (sizing: `Text("東京")`, 3xnil).
- `a grapheme wider than the whole width is drawn as the mark` (sizing: `Text("東京")`,
  1xnil).
- `a finite height proposal is a row budget that ends the last visible row in the mark`
  (row budget: Budget mark; sizing: `Text("Ship one thing")`, 8x1 and `Text("World")`,
  3x1).
- `line limit sets a row budget under an unbounded height` (row budget: Last visible row;
  sizing: `Text("Ship one thing").lineLimit(1)`, 8xnil; variants: `.lineLimit(n)`).
- `the last visible row holds its remainder cut by the truncation mode` (row budget: Last
  visible row, 24x2).
- `hidden source lines put the mark directly after the remainder` (row budget: Hidden
  source line mark; sizing: `Text("release\nnotes").lineLimit(1)`, nil x nil).
- `a row budget larger than the content adds no blank rows` (sizing:
  `Text("Ship one thing")`, 8x5).
- `invalid line limit traps before layout` (variants: `.lineLimit(n)`).
- `line limit and truncation mode inherit from the nearest ancestor` (environment: line
  limit and truncation mode).
- `text lays out again at a smaller assigned rectangle and marks the cut` (Truncation
  section; degradation: Narrow or short allocation).
- `clip truncation keeps the leading cells without a mark` (variants:
  `.truncationMode(.clip)`; sizing: `Text("World").truncationMode(.clip)`, 3x1).
- `tail-truncated text is the default and uses the mark at a grapheme-safe boundary`
  (anatomy: Tail truncation; variants: `.truncationMode(.tail)`).
- `head-truncated text keeps trailing cells behind a leading mark` (anatomy: Head
  truncation; variants: `.truncationMode(.head)`).
- `middle-truncated text keeps ceil((width - 1) / 2) leading cells` (anatomy: Middle
  truncation; variants: `.truncationMode(.middle)`).
- `a wide grapheme straddling a truncation cut moves to the mark side and leaves its cell blank`
  (variants: every `.truncationMode` row; Truncation section).
- `text does not stretch for excess proposal` (sizing: `Text("Hello")`, 80x24).
- `zero-width text reports zero by one and paints nothing` (sizing: `Text("Hello")`,
  0xnil).
- `empty text measures zero by one and paints no cells` (sizing: `Text("")`, nil x nil).
- `text merges inherited and explicit styles by attribute precedence` (environment:
  inherited Style).
- `text background fills its allocated rectangle` (environment: background fill).
- `text substitutes ascii truncation mark without changing geometry` (environment:
  truncation mark; degradation: ASCII-only).
- `truncation mark takes the text's resolved style` (environment: truncation mark).
- `text never consumes keyboard or pointer input` (key table: printable characters, Enter,
  and Up / Down / Left / Right; mouse table: click, drag, wheel-up, and wheel-down).

## Degradation

| Capability or space        | Text behavior                                                                                                                                                                                               |
| -------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Full capability            | Uses the resolved full Style; wide and combining grapheme geometry remains exact; truncation uses `…`.                                                                                                      |
| `NO_COLOR`                 | Preserves text and geometry; resolved Styles degrade to their attributes per the [degradation ladder](../tokens.md#degradation-ladder).                                                                     |
| 16-color                   | Preserves text geometry and resolves the inherited full Style to the indexed palette.                                                                                                                       |
| ASCII-only                 | Preserves source ASCII text; borderless Text needs no glyph substitution; truncation changes from `…` to `~`. Unicode source text is rendered only when the active terminal capability can represent it.    |
| Narrow or short allocation | Wraps at any finite width; a word wider than the width breaks between graphemes; a row budget ends the last visible row in the mark; a zero width paints nothing. Text never creates scroll state or focus. |

## Decisions

- **Wrapping is the default and has no mode API (owner decision, 2026-10-18, for the
  default; spelling settled here).** The earlier `.wrapped(.none/.word/.character)` is
  removed. `.word` is now simply what Text does. `.none` is spelled `.lineLimit(1)`, which
  marks the cut instead of clipping silently, or comes from a nil width proposal, such as
  a horizontal ScrollView, when unwrapped intrinsic lines are the point. `.character` is
  dropped: the overlong-word fallback already breaks between graphemes where a word cannot
  fit, SwiftUI has no character-wrap mode, and no catalog component needs one (code and
  TextField lay out their own lines under their documented wrap exceptions). A
  Tessera-only granularity control can be proposed later if a component needs it.
- **`lineLimit` and `truncationMode` are environment modifiers (SwiftUI parity).** One
  `.lineLimit(1)` on a List or Picker reaches every row (owner decision, 2026-10-18).
  Chrome pins its own `.lineLimit(1)`, so inherited values reach content only. 1.0 ships
  `lineLimit(_: Int?)`; SwiftUI's range and `reservesSpace:` overloads are not in 1.0.
- **`.clip` stays a Tessera-only `TruncationMode` case.** The Spec's Slice 3 boundary
  already lists it, and it is the explicit no-mark opt-out. `.tail` remains the default.
- **Vertical overflow:** the last visible row carries its remainder, cut by the mode, as
  SwiftUI and UIKit truncate the last line. A mark always appears when anything is hidden.
- **Text owns the cut.** It re-lays out at its final rectangle, so a parent that assigns
  less than Text measured gets a marked cut. Parents clip only non-text geometry.
- **Spec drift:** the [Text grows up](../../docs/Spec.md#text-grows-up) snippet in
  `docs/Spec.md` still shows `wrapped(_:)` with a `.none` default and `truncation(_:)`
  with a `.clip` default. This doc supersedes that snippet under the owner decisions
  above; the Spec text needs the same update.

## Deferred scope

Rich text segments, localized interpolation, and formatted values are excluded from Phase
4 1.0; the exact deferred boundary is
[Catalog text boundary decisions](../../docs/Spec.md#catalog-text-boundary-decisions).
They require a separate text-composition proposal and must not turn Text into a mutable
document model.

## Inspiration

The Text demo renders ordinary, wide, combining, multiline, wrapped, budget-truncated, and
mode-truncated Text fixtures before it introduces focusable controls. Text has no
demo-only behavior; the demo proves the public leaf through a real `ViewGraph` and
`Frame`.
