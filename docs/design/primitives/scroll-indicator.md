---
kind: primitive
status: ready
---

# ScrollIndicator

`ScrollIndicator` is the shared, stateless output strip for a scrollable axis. Given one
axis, the content extent, the final viewport extent, and the parent's effective offset, it
paints a proportional track and thumb. It has no focus, binding, key or mouse handler,
drag mapping, animation, business status, or persistent state. In particular, it never
decides whether a scrollable parent has overflow: [ScrollView](../widgets/scroll-view.md),
List, and [Table](../widgets/table.md) make that decision, reserve the trailing or bottom
cell, and mount this primitive only for an overflowing axis.

The primitive owns the one canonical integer mapping from extents and position to a thumb.
That removes the parallel thumb formulas presently described by ScrollView and Table from
their implementation and readiness path: each parent supplies its already-final metrics
and renders `ScrollIndicator`; none redraws or rounds a thumb itself. The parent remains
the owner of scrolling, clipping, selection, and any corner where two indicator strips
meet.

## Prior art

- Ratatui `Scrollbar`: `~/Developer/ratatui/ratatui/main/ratatui-widgets/src/scrollbar.rs`
  (`ScrollbarOrientation`, `ScrollbarState`, and `part_lengths`) -- copy its separate
  vertical and horizontal strips, saturating treatment of malformed dimensions, bounded
  thumb, and the invariant that the terminal position puts the thumb wholly at track end.
  Reject its caller-owned mutable `ScrollbarState`, endpoint arrows, left/top placements,
  and nearest-integer rounding. Its configurable symbols and styles are not copied as an
  open-ended API: owner decision, omp2 review, 2026-10, reverses the earlier rejection of
  configurable styles; owner decision, 2026-10-10, replaces free thumb and track choices
  with curated presets, each a fixed thumb and track pair (see Decisions). Tessera
  receives immutable render inputs, has a parent-chosen placement, uses catalog glyph
  tokens, and floors the documented proportional equation so all three parents share the
  same result.
- omp2 `Scroll`'s scrollbar, ScrollIndicator's counterpart in the
  [translation key](../translation-key.md#coverage) ([scroll.rs][scroll-bar], thumb
  formula at [L172][scroll-thumb], glyphs in [`Charset::scrollbar`][scroll-charset]) --
  copy the default look, which is the `standard` preset (key K8): an accent `█` thumb on a
  `│` track, unchanged by the review, with omp2's `muted` track drawn in Tessera's
  `border` role ([scroll indicators](../tokens.md#scroll-indicators)). Copy its floored
  thumb position. Reject its click and drag on the bar, which jump the thumb
  ([scroll.rs][scroll-drag]): indicators are output-only (key F2).
- [ScrollView](../widgets/scroll-view.md) -- copy its final-viewport inputs and its
  `floor`-based equation (`thumb = max(1, floor(track * viewport / content))`). Reject
  embedding that equation in a viewport widget: ScrollView determines stable overflow and
  clipping, then delegates only the indicator cells here.
- [Table](../widgets/table.md) -- copy a one-cell trailing strip beside visible data rows
  and its proportional visible/total intent. Reject Table-specific thumb rendering and its
  draft scrollbar-drag behavior for this primitive. First-delivery indicators are
  output-only; Table keeps wheel/key scrolling in its own widget and must not add input
  behavior to this shared render node.

[scroll-bar]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/scroll.rs#L168-L193
[scroll-thumb]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/scroll.rs#L172
[scroll-charset]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/context.rs#L211-L217
[scroll-drag]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/scroll.rs#L230-L256

## Inputs and geometry

The public vocabulary is intentionally small and now committed for implementation:

```swift
public struct ScrollIndicator: View {
    public init(
        axis: Axis,
        contentExtent: Int,
        viewportExtent: Int,
        effectiveOffset: Int
    )
}

extension EnvironmentValues {
    public var scrollIndicatorStyle: ScrollIndicatorStyle { get set }          // default .standard
    public var scrollIndicatorPlacement: ScrollIndicatorPlacement { get set }  // default .reserved
}

extension View {
    public func scrollIndicatorStyle(_ style: ScrollIndicatorStyle) -> some View
    public func scrollIndicatorPlacement(_ placement: ScrollIndicatorPlacement) -> some View
}
```

`ScrollIndicatorStyle` is the closed list of eight presets in [Variants](#variants), and
`ScrollIndicatorPlacement` is `.reserved` or `.border`. Each modifier writes its
environment value for the subtree, and the nearest ancestor wins, as [Text](text.md)'s
`lineLimit` and `truncationMode` do. Parents read the placement to decide what to reserve,
and the indicator reads the preset to pick its glyphs.

`axis` is exactly one axis, never `Axis.Set`: `.vertical` makes a one-column strip and
`.horizontal` makes a one-row strip. `contentExtent` and `viewportExtent` are cell counts
on that axis; `effectiveOffset` is the parent-clamped first visible content cell on that
axis. The allocated primary-axis length is the track length `T`; it comes from layout, not
from a fifth public metric. The cross axis is always one cell.

Before rendering, normalize independently of parent correctness:

1. `T = max(0, allocated primary-axis length)`.
2. `C = max(1, contentExtent)` and `V = clamp(viewportExtent, 0...C)`.
3. `M = C - V` and `O = clamp(effectiveOffset, 0...M)`.
4. If `T == 0`, paint no cells. Otherwise `L = clamp(max(1, floor(T * V / C)), 1...T)` is
   the thumb length and `S = floor(O * (T - L) / max(1, M))` is the leading-track length.
   The remaining `T - S - L` cells are trailing track.

All division is integer floor division. Implementations must evaluate the two products
with an overflow-safe widened or quotient/remainder calculation; the result is the
mathematical integer result above, never a wrapping value. The normalization gives a
deterministic, non-negative render result for negative extents, a viewport larger than
content, and an offset outside its valid range. It is defensive rendering only, not a
visibility policy: parents omit the primitive rather than showing a full-thumb strip when
`contentExtent <= viewportExtent`.

For valid overflowing metrics (`C > V`) at `O == 0`, `S == 0`; at `O == M`, `S == T - L`.
Thus the thumb touches the leading and trailing/bottom ends exactly, including when
rounding makes the thumb a single cell.

## Anatomy

### Natural vertical middle

This natural vertical strip is allocated `1x10`, with `C = 40`, `V = 10`, and `O = 15`.
The geometry is `L = floor(10 * 10 / 40) = 2` and
`S = floor(15 * (10 - 2) / (40 - 10)) = 4`.

```wireframe 1x10
│
│
│
│
█
█
│
│
│
│
```

```text
Callouts (1x10, 0-based):
0. r0-r3  Leading track -- four track cells (`border`) before the vertical thumb
1. r4-r5  Thumb -- two `standard` `█` thumb cells, styled with `accent`
2. r6-r9  Trailing track -- four track cells (`border`) after the thumb
```

### Horizontal start middle and end

These are three independent horizontal `12x1` snapshots stacked for comparison. Each has
`C = 48`, `V = 12`, and `L = 3`. Their effective offsets are respectively `0`, `18`, and
`36` (the maximum). The middle start is `floor(18 * 9 / 36) = 4`.

The fixtures use the `standard` preset: a `🬋` thumb on a `─` track. A full block is twice
as tall as it is wide, so horizontal strips use a centred one-third bar instead of `█`
(owner decisions, 2026-10-10 and 2026-10-11).

```wireframe 12x3
🬋🬋🬋─────────
────🬋🬋🬋─────
─────────🬋🬋🬋
```

```text
Callouts (12x3, 0-based):
0. r0 c0-c2   Start thumb -- `O = 0`; thumb touches the leading edge
1. r0 c3-c11  Start trailing track -- nine track cells (`border`)
2. r1 c0-c3   Middle leading track -- four track cells (`border`)
3. r1 c4-c6   Middle thumb -- `O = 18`; three thumb cells (`accent`)
4. r1 c7-c11  Middle trailing track -- five track cells (`border`)
5. r2 c0-c8   End leading track -- nine track cells (`border`)
6. r2 c9-c11  End thumb -- `O = 36 = M`; thumb touches the bottom/trailing end
```

### Mobile allocations

At the catalog `mobile` viewport (`40x16`), a vertical parent reserves trailing `c39` and
proposes this `1x16` strip. With `C = 64`, `V = 16`, and `O = 24`, its four-cell thumb
starts at `r6`. A horizontal parent instead reserves bottom `r15` and proposes a `40x1`
strip; its `C = 120`, `V = 40`, `O = 40` thumb is thirteen cells beginning at `c13`. These
are allocation examples, not chrome owned by this primitive.

```wireframe 1x16
│
│
│
│
│
│
█
█
█
█
│
│
│
│
│
│
```

```text
Callouts (1x16, 0-based):
0. r0-r5    Leading track -- vertical mobile allocation before the thumb
1. r6-r9    Thumb -- four thumb cells (`accent`) in the parent's trailing column
2. r10-r15  Trailing track -- vertical mobile allocation after the thumb
```

```wireframe 40x1
─────────────🬋🬋🬋🬋🬋🬋🬋🬋🬋🬋🬋🬋🬋──────────────
```

```text
Callouts (40x1, 0-based):
0. r0 c0-c12   Leading track -- thirteen cells in the parent's bottom row
1. r0 c13-c25  Thumb -- thirteen thumb cells (`accent`)
2. r0 c26-c39  Trailing track -- fourteen cells; the complete strip is exactly 40 columns
```

### Declared minimum

A one-cell track has no smaller useful renderable geometry. With `T = 1`, `C = 100`,
`V = 10`, and `O = 90 = M`, floor rounding still produces `L = 1` and `S = 0`.

```wireframe 1x1
█
```

```text
Callouts (1x1, 0-based):
0. r0 c0  Minimum thumb -- the sole track cell is the one-cell minimum thumb (`accent`)
```

A zero-length proposal has no fixture because its render region has no cells. It paints
nothing; it does not create a one-cell minimum outside the rectangle.

## Variants

The strip has three axes: orientation (set by the parent's placement), the curated preset,
and placement. A preset fixes the thumb and the track together, so a thumb is never paired
with a track it was not designed for. Geometry is identical across every combination; only
glyphs and paint change. The thumb arithmetic never changes. The default look, the
`standard` preset, is omp2's unchanged look (owner decision, omp2 review, 2026-10).

| Orientation | Geometry | Placement rule                                  |
| ----------- | -------- | ----------------------------------------------- |
| Vertical    | `1xT`    | Parent places the strip in its trailing column. |
| Horizontal  | `Tx1`    | Parent places the strip in its bottom row.      |

Curated presets (`.scrollIndicatorStyle(_ style: ScrollIndicatorStyle)`; owner decision,
2026-10-10; list and glyphs confirmed, owner decision, 2026-10-11). There is one list of
eight presets, and each preset has a vertical glyph pair and a horizontal glyph pair; the
set is closed, and thumb and track are never chosen separately.

| Preset               | Vertical thumb | Vertical track | Horizontal thumb | Horizontal track |
| -------------------- | -------------- | -------------- | ---------------- | ---------------- |
| `standard` (default) | `█`            | `│`            | `🬋`              | `─`              |
| `thin`               | `┃`            | `│`            | `━`              | `─`              |
| `inner`              | `▌`            | `│`            | `🮂`              | `─`              |
| `outer`              | `▐`            | `│`            | `▂`              | `─`              |
| `dashed`             | `█`            | `╎`            | `🬋`              | `╌`              |
| `dotted`             | `█`            | `┊`            | `🬋`              | `┈`              |
| `heavy`              | `█`            | `┃`            | `🬋`              | `━`              |
| `thumbOnly`          | `█`            | none           | `🬋`              | none             |

The table's glyphs are the vocabulary the presets draw from, not public enums. Curated
presets exclude mismatched pairs: no preset puts a thumb on a track of the same glyph, so
every thumb stays distinguishable without colour, and no preset uses a full block on a
horizontal track, which is too tall there (owner decision, 2026-10-10).

Horizontal thumbs match the visual thickness of their vertical counterparts, because a
cell is about twice as tall as it is wide (owner decision, 2026-10-11):

- `standard`'s horizontal thumb is `🬋` (BLOCK SEXTANT-34), a centred bar one third of the
  cell high, so it reads as thicker than `thin`'s `━` the way `█` does against `┃`.
- `inner` and `outer` use quarter blocks, `🮂` (UPPER ONE QUARTER BLOCK) and `▂` (LOWER ONE
  QUARTER BLOCK), which are as thick as the vertical half blocks `▌` and `▐`. `inner` sits
  toward the content (left, or the top of a horizontal strip); `outer` sits toward the
  screen edge (right, or the bottom). Horizontally they hug the cell edge, leaving a small
  gap from the centred track, rather than touching it as `▌` and `▐` do. The sheets list
  `inner` before `outer` so the two thumbs face away from each other instead of meeting.
- `heavy`'s thumb is the standard thumb, `█` and `🬋`, centred and fully covering the heavy
  track. A half-block thumb only covers half the track's thickness, which left a notch in
  the track at each end of the thumb.

`🬋` and `🮂` come from Unicode's Symbols for Legacy Computing block, so the table shows the
Nerd Font charset; the Unicode charset draws `━` and `▔` instead (see
[Degradation](#degradation)). The `stipple` track and the `thick` and `smooth` thumbs were
dropped in review and are not presets.

Horizontal strips, one preset per row, each on the same 15-cell strip with the thumb at
the same offset:

```wireframe 25x8
standard  ────🬋🬋🬋────────
thin      ────━━━────────
inner     ────🮂🮂🮂────────
outer     ────▂▂▂────────
dashed    ╌╌╌╌🬋🬋🬋╌╌╌╌╌╌╌╌
dotted    ┈┈┈┈🬋🬋🬋┈┈┈┈┈┈┈┈
heavy     ━━━━🬋🬋🬋━━━━━━━━
thumbOnly     🬋🬋🬋
```

```text
Callouts (25x8, 0-based):
1. r0-r7 c0-c9             Preset names -- one preset per row; its thumb and track pair is fixed
2. r0-r7 c14-c16           Thumb -- three cells at the same offset in every row; only the glyph
                           changes
3. r0-r6 c10-c13, c17-c24  Track -- the preset's horizontal track (`border`); r7 (`thumbOnly`)
                           paints no track
```

Vertical strips, one preset per column in the same order as the horizontal sheet. The
thumb sits in rows r4-r6 in every column, on the centred track:

```wireframe 75x10
┌─ Vertical presets ──────────────────────────────────────────────────────┐
│ standard   thin    inner    outer    dashed   dotted   heavy  thumbOnly │
│    │        │        │        │        ╎        ┊        ┃              │
│    │        │        │        │        ╎        ┊        ┃              │
│    █        ┃        ▌        ▐        █        █        █        █     │
│    █        ┃        ▌        ▐        █        █        █        █     │
│    █        ┃        ▌        ▐        █        █        █        █     │
│    │        │        │        │        ╎        ┊        ┃              │
│    │        │        │        │        ╎        ┊        ┃              │
└─────────────────────────────────────────────────────────────────────────┘
```

```text
Callouts (75x10, 0-based):
0. r1              Preset names -- one preset per column, centred over its strip
1. r4-r6 c5        `standard` -- `█` thumb (`accent`) on the centred `│` track; the default
2. r4-r6 c14       `thin` -- `┃` thumb on the `│` track
3. r4-r6 c23       `inner` -- `▌` half block; the left half sits toward the content
4. r4-r6 c32       `outer` -- `▐` half block; the right half sits toward the screen edge
5. r4-r6 c41       `dashed` -- `█` thumb on the `╎` track
6. r4-r6 c50       `dotted` -- `█` thumb on the `┊` track
7. r4-r6 c59       `heavy` -- `█` thumb covering the `┃` track
8. r4-r6 c68       `thumbOnly` -- `█` thumb with no track; r2-r3 and r7-r8 at c68 paint nothing
9. r2-r3, r7-r8    Track -- each preset's vertical track (`border`)
```

```text
── chars ──
┌─ Vertical presets ──────────────────────────────────────────────────────┐
│ standard   thin    inner    outer    dashed   dotted   heavy  thumbOnly │
│    │        │        │        │        ╎        ┊        ┃              │
│    │        │        │        │        ╎        ┊        ┃              │
│    █        ┃        ▌        ▐        █        █        █        █     │
│    █        ┃        ▌        ▐        █        █        █        █     │
│    █        ┃        ▌        ▐        █        █        █        █     │
│    │        │        │        │        ╎        ┊        ┃              │
│    │        │        │        │        ╎        ┊        ┃              │
└─────────────────────────────────────────────────────────────────────────┘
── style ──
RRRTTTTTTTTRTTTTTTTRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRR
R.HHHHHHHH...HHHH....HHHHH....HHHHH....HHHHHH...HHHHHH...HHHHH..HHHHHHHHH.R
R....A........A........A........A........A........A........A..............R
R....A........A........A........A........A........A........A..............R
R....B........B........B........B........B........B........B........B.....R
R....B........B........B........B........B........B........B........B.....R
R....B........B........B........B........B........B........B........B.....R
R....A........A........A........A........A........A........A..............R
R....A........A........A........A........A........A........A..............R
RRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRR
── legend ──
.  default
A  fg=border
B  fg=accent
H  fg=secondary bold
R  fg=border
T  fg=primary bold
```

Placement is parent-owned:

| Placement            | Reserves                          | Track           | Used by                 |
| -------------------- | --------------------------------- | --------------- | ----------------------- |
| `reserved` (default) | one trailing column or bottom row | preset track    | ScrollView, List, Table |
| `.border`            | nothing                           | the border line | Border, Box             |

`.border` is opt-in with `.scrollIndicatorPlacement(.border)`, and applies only when the
nearest ancestor is a bordered [Box](box.md). Without one, `.border` falls back to
`reserved` (owner decision, 2026-10-10). The thumb overlays the box's right border; the
border line is the track, the preset's track glyph is ignored, and no cell is reserved.
lazygit draws the thumb over the border this way. The fixture paints the `thin` `┃` thumb;
`inner` and `outer` ride the same edge, as shown in the
[ScrollView](../widgets/scroll-view.md) in-border wireframe:

```wireframe 20x8
╭─ Files ──────────╮
│ Spec.md          │
│ Package.swift    ┃
│ README.md        ┃
│ CHANGELOG.md     ┃
│ LICENSE          │
│ Brewfile         │
╰──────────────────╯
```

```text
Callouts (20x8, 0-based):
0. r0, r7        Box border -- top and bottom chrome; no interior column is reserved
1. c19           Track edge -- the right border column doubles as the indicator track
2. r2-r4 c19     Thumb -- rides the border edge (`thin` `┃`)
3. r1-r6 c2-c17  Content -- Box interior, unreduced by the indicator
```

There are deliberately no leading/left, top, endpoint-arrow, disabled, focused, or
draggable variants, and no per-instance glyph override. Placement belongs to the parent
layout; focus and disabled semantics belong to an interactive parent. The preset and
placement are set on a subtree with modifiers and reach the indicator through the
environment.

## Parent contract and absence states

A parent follows this order for each enabled axis:

1. Measure content and determine its final viewport extent, including any stable
   cross-axis reservation the parent needs.
2. If `contentExtent > viewportExtent` and the allocated primary track length is positive,
   reserve exactly one trailing column for a vertical indicator or one bottom row for a
   horizontal indicator, then render this primitive with the final extent and effective
   offset.
3. If the axis has no overflow (`contentExtent <= viewportExtent`), if content is zero, or
   if the assigned track length is zero, omit the primitive and reserve no cell for it.
4. If both axes overflow, the parent owns the one-cell intersection and paints no child
   content there unless its own component design explicitly assigns it a role.

The numbered order above is the `reserved` placement. In `.border` placement the parent
instead rides the nearest [Box](box.md)'s ring: it reserves no extra cell, the ring line
is the track, and only the thumb paints, on the ring's edge cells at the resolved thumb
rows or columns. Box paints those cells after its descendants, because the ring lies
outside the parent's region and key G4 lets no view write outside its own (see
[Open questions](#open-questions)). This is the deliberate exception to "reserve exactly
one trailing column or bottom row"; the thumb math is unchanged, and because the ring owns
the track glyph, the preset's track does not apply. The parent still omits the indicator
when the axis has no overflow.

This primitive does not own idle, loading, error, or empty business states. Those are
parent/app content states: a loading or error viewport may still show an indicator when
its actual measured content overflows; empty or no-overflow content causes the parent
omission above. No click, wheel, key, drag, or hit-test region is installed by the
primitive: a click or drag on an indicator falls through to the parent, which returns it
`.ignored` (key F2; [ScrollView](../widgets/scroll-view.md#mouse-table)).

## Sizing

The following examples use normalized `C = 40`, `V = 10`, and `O = 15`. `nil` on the
primary axis reports the viewport-length ideal so the primitive is independently
measurable; parents normally give the finite exact track length that their reserved edge
provides. An extra cross-axis proposal is never consumed. A zero cross-axis proposal
produces no cells.

| Proposal                | Result | Rule                                                                     |
| ----------------------- | ------ | ------------------------------------------------------------------------ |
| vertical, `nil x nil`   | `1x10` | Natural vertical size is one column by the viewport-length ideal track.  |
| vertical, `1x10`        | `1x10` | Tight vertical proposal is accepted exactly.                             |
| vertical, `0x10`        | `0x10` | Under-minimum cross axis is honored as zero; no column is invented.      |
| vertical, `4x16`        | `1x16` | Over-maximum cross axis is ignored while the finite primary track fills. |
| horizontal, `nil x nil` | `10x1` | Natural horizontal size is the viewport-length ideal track by one row.   |
| horizontal, `10x1`      | `10x1` | Tight horizontal proposal is accepted exactly.                           |
| horizontal, `10x0`      | `10x0` | Under-minimum cross axis is honored as zero; no row is invented.         |
| horizontal, `16x4`      | `16x1` | Over-maximum cross axis is ignored while the finite primary track fills. |

In `.border` placement the primitive reports a zero-area contribution: it reserves no cell
of its own, and Box composites the thumb onto the ring edge it already allocated. The
thumb length and position come from the same equation, with the ring's edge between its
corners as the track.

## Environment

The system/default rendering consumes only catalog tokens and complete semantic `Style`
values from the environment:

- Preset (`standard`, the default; `thin`; `inner`; `outer`; `dashed`; `dotted`; `heavy`;
  or `thumbOnly`), read from `scrollIndicatorStyle` and set by
  `.scrollIndicatorStyle(_:)`, selects the thumb and track glyphs for the strip's axis
  without changing the normalized geometry. `thumbOnly` paints no track cell.
- Placement, read from `scrollIndicatorPlacement` and set by
  `.scrollIndicatorPlacement(_:)`, selects `.reserved` (the default) or `.border`. Under
  `.border` the ring line is the track, so the preset's track glyph is ignored and only
  its thumb paints.
- `scrollIndicator.ascii` supplies the ASCII `|`/`-` track and `#` thumb.
- `border` is the complete `Style` applied to the track, including any attributes and
  background as well as foreground ([scroll indicators](../tokens.md#scroll-indicators)).
- `accent` is the complete `Style` applied to the thumb, including any attributes and
  background as well as foreground.

The standard style never synthesizes a color, ANSI sequence, or partial foreground value.
`NO_COLOR` and 16-color resolution happen when the track and thumb roles resolve, exactly
as defined in [tokens.md](../tokens.md#roles). A future custom component style must
receive the resolved axis and geometry plus complete track/thumb semantic styles; it may
change presentation but may not change the normalized geometry, input-free nature, or
parent-owned overflow policy. Its environment key and protocol are deferred to Slice 3
(see [Decisions](#decisions)).

## Dependencies and readiness cutover

- Slice 2 layout/render substrate -- `Axis`, finite and nil `ProposedSize`, placement, and
  buffer painting are needed to allocate the one-cell strip.
- Slice 3 environment style resolution -- supplies the full `border` (track;
  [scroll indicators](../tokens.md#scroll-indicators)) and `accent` (thumb) `Style` values
  and the degradation capability selection.
- [Box](box.md) -- `.border` placement rides its ring, and Box paints the thumb there.
- [ScrollView](../widgets/scroll-view.md), List, and [Table](../widgets/table.md) depend
  on this primitive's geometry and output contract. They own their own measurement,
  effective offset, visibility, and reservation; they do not carry a duplicate thumb
  calculation or an indicator state/protocol.

This primitive is the single resolution of the shared ScrollView/List/Table indicator
question. Its API spelling is settled; once plan 032 step 9.4 implements it, ScrollView
and Table can remove their respective shared-indicator readiness blocker without waiting
for a separate renderer or an independently rounded formula. It creates no dependency on
Form, Outline, source browsing, or source mapping.

## Requirements

- `vertical indicator renders exact proportional middle thumb geometry` (Anatomy: natural
  vertical middle)
- `horizontal indicator places the thumb at start middle and end` (Anatomy: horizontal
  start middle and end)
- `maximum effective offset places the thumb flush with the trailing track end` (Inputs
  and geometry; Anatomy: horizontal end)
- `one cell track renders a one cell thumb at every valid position` (Anatomy: declared
  minimum)
- `negative oversized and out of range metrics normalize before painting` (Inputs and
  geometry)
- `zero length track paints no cells without expanding its proposal` (Anatomy: declared
  minimum; sizing: under-minimum rows)
- `parent omits indicator and reserves no edge for zero or nonoverflow content` (Parent
  contract and absence states)
- `reserved placement reserves exactly one trailing column or bottom row` (Variants:
  placement; Anatomy: mobile allocations)
- `mobile forty column horizontal allocation preserves exact thumb geometry` (Anatomy:
  mobile allocations, `40x1`)
- `ascii indicator preserves full capability geometry with canonical glyph replacements`
  (Variants; Degradation: ASCII-only)
- `scroll indicator installs no focus binding input or drag handler` (Overview; Parent
  contract and absence states)
- `scroll view list and table use identical indicator geometry for equal metrics`
  (Dependencies and readiness cutover)
- `each preset renders its fixed thumb and track pair at identical geometry on both axes`
  (Variants: preset table and strips)
- `thumbOnly preset paints no track cells on either axis` (Variants: preset strips)
- `no preset pairs a thumb with a track of the same glyph` (Variants: preset table)
- `inner and outer presets draw on the centred track, not on an edge track` (Variants:
  preset strips)
- `unicode charset draws ━ and ▔ where the nerd font charset draws 🬋 and 🮂` (Degradation:
  Symbols for Legacy Computing)
- `heavy preset draws a light horizontal track under unicode` (Symbols for Legacy
  Computing; scroll indicators: `heavy`)
- `on-border placement rides the edge and reserves no cell` (Variants: placement and
  on-border box wireframe; Parent contract and absence states)
- `border placement without a box ancestor falls back to reserved placement` (Variants:
  placement)
- `box paints the border placement thumb on its ring` (Parent contract and absence states;
  Sizing: `.border` placement)
- `style and placement modifiers set their subtree's environment value` (Inputs and
  geometry: environment values)

## Degradation

- `NO_COLOR`: retain the canonical Unicode geometry and glyphs; resolved `border` (track)
  and `accent` (thumb) fall back to their token-defined attributes.
- 16-color: retain geometry; resolve those full semantic styles to indexed terminal
  styles.
- Symbols for Legacy Computing: `🬋` and `🮂` are drawn only in the Nerd Font charset. The
  Unicode charset falls back to `━` for `🬋` and `▔` for `🮂`, staying within Block Elements
  and box drawing (owner decision, 2026-10-11). Ghostty, kitty and WezTerm draw the Legacy
  Computing glyphs themselves; Terminal.app and Windows Terminal are checked in
  implementation QA.
- Unicode `heavy` preset: horizontal track `─` under its `━` thumb, because a `━` track
  would break the rule that no thumb shares its track's glyph (owner decision, 2026-10-19,
  [scroll indicators](../tokens.md#scroll-indicators)). The Nerd Font track stays `━`.
- ASCII-only: collapse every preset's thumb to `#`; replace every track with `|`
  (vertical) or `-` (horizontal), except `thumbOnly`, whose track stays blank. The `40x1`
  mobile allocation below is the exact degraded horizontal fixture for `C = 120`,
  `V = 40`, `O = 40`.

```wireframe 40x1
-------------#############--------------
```

```text
Callouts (40x1, 0-based):
0. r0 c0-c12   ASCII leading track -- thirteen `scrollIndicator.ascii` `-` cells
1. r0 c13-c25  ASCII thumb -- thirteen `scrollIndicator.ascii` `#` cells
2. r0 c26-c39  ASCII trailing track -- fourteen `scrollIndicator.ascii` `-` cells
```

- Below the one-cell cross-axis minimum or at a zero primary-axis proposal, honor the
  non-negative assigned rectangle and paint nothing outside it. The parent omission rule
  remains unchanged; no fallback border, label, spinner, or status text appears.

## Decisions

The public axis parameter uses the existing singular `Axis`; `.vertical` and `.horizontal`
each name one strip and the type never admits an `Axis.Set`. The immutable inputs stay
four scalar values — `axis`, `contentExtent`, `viewportExtent`, and `effectiveOffset` — on
the selected axis rather than a wrapper struct, so a parent supplies its already-final
metrics with no extra type. These spellings are the committed contract; the geometry,
normalization, and floor equation above do not depend on the choice.

Reviewed against the [Phase 4 theses](../../spec/phase-4.md): the primitive is output-only
rendered data, appearance comes from shared tokens and complete semantic `Style` roles,
and its thumb geometry is deterministic integer-cell output shared by every parent.

Owner decision, omp2 review, 2026-10: the earlier rejection of configurable indicator
styles is withdrawn, so that the look can be chosen per use while omp2's look stays the
default. Tessera offers a placement that draws the thumb inside a box's border as lazygit
does, and a set of curated looks. Owner decision, 2026-10-10: the look is one curated
`ScrollIndicatorStyle` preset, selected with
`.scrollIndicatorStyle(_ style: ScrollIndicatorStyle)`. Each preset fixes a thumb and a
track together for both axes; no open-ended style API exists and thumb and track cannot be
chosen separately. Every preset and `.border` placement ship in 1.0 (owner decision,
2026-10-10).

Preset list and glyphs confirmed (owner decision, 2026-10-11): `standard` (default),
`thin`, `inner`, `outer`, `dashed`, `dotted`, `heavy`, and `thumbOnly`, with glyphs as in
[Variants](#variants). Horizontal thumbs match their vertical counterparts' visual
thickness, and `heavy` uses the standard thumb so it covers the heavy track. The old thumb
and track tables are the glyph vocabulary the presets draw from, not public enums.

Curated presets exclude mismatched pairs. A type-level split into free thumb and track
parameters would need a second parameter to reach the heavy track, the shape the owner
rejected for `stipple`, and would admit pairs such as a `┃` thumb on a `┃` track. Under
curation no preset puts a thumb on a track of the same glyph, so every thumb stays
distinguishable without colour, and no preset uses a full block on a horizontal track,
which is too tall there (owner decision, 2026-10-10). `thick` and `smooth` thumbs were
dropped in review.

Placement adds `.border` beside the default `.reserved` mode, set by its own modifier,
`.scrollIndicatorPlacement(_:)`, separate from the preset. `.border` is the deliberate
exception to reserving a trailing cell: it rides the nearest Box's ring, uses that line as
the track, and paints only the thumb. It changes reservation and track ownership, never
the thumb equation or the input-free contract.

Both modifiers write environment values, `scrollIndicatorStyle` and
`scrollIndicatorPlacement`, read by the parent and the indicator. Key B12 makes a closed
set of looks a style modifier read from the environment, as `.buttonStyle(_:)` and
`.toggleStyle(_:)` are, and key A11 gives each concern its own environment key; the
spelling follows Text's `lineLimit` and `truncationMode` keys. This settles the
environment spelling that was the doc's last open question.

Owner decision, 2026-10-10: a custom presentation surface beyond the curated presets (an
environment protocol with a resolved configuration, or a closure-style environment value)
stays deferred to [Slice 3](../../spec/phase-4/slice-03-styling-and-decoration.md). Any
such surface must receive complete semantic `Style` roles and resolved geometry, never raw
colors or control state, and must not change the normalized geometry or input-free nature.
Indicators stay output-only in 1.0: Slice 5's
[pointer cutover](../../spec/phase-4/slice-05-mouse-and-hit-testing.md#pointer-cutover-for-controls-fields-panes-and-viewports)
has clicks and drags on them return `.ignored`, and omp2's click-to-jump is rejected (key
F2). Any later hit target layered over an indicator must retain this primitive's
input-free API and reuse its resolved geometry rather than reimplementing thumb math.

## Open questions

- Deferred to plan 032 step 9.4: how a parent's resolved `.border` indicator geometry
  reaches the Box that paints the thumb. The ring lies outside the parent's region, and
  key G4 lets no view write outside its own, so Box paints the thumb cells after its
  descendants, as it paints delegated focus. The graph has no channel yet that carries
  child metrics up to an ancestor; step 9.4 adds one to the
  [`ScrollIndicator`](../../spec/phase-4/slice-03-styling-and-decoration.md#scrollindicator)
  contract without giving the indicator any input.

## Inspiration

- Stable edge strips communicate document extent without consuming a focus stop or needing
  animation, which is especially valuable in the catalog's `40x16` mobile viewport.
- A single floor-based mapping turns an easily diverging visual detail into a reusable,
  snapshot-testable primitive while leaving control and application state with the widgets
  that legitimately own them.
