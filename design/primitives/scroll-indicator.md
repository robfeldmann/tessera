---
kind: primitive
status: wireframed
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
  configurable symbols and styles, and nearest-integer rounding. Tessera receives
  immutable render inputs, has a parent-chosen placement, uses catalog glyph tokens, and
  floors the documented proportional equation so all three parents share the same result.
- [ScrollView](../widgets/scroll-view.md) -- copy its final-viewport inputs and its
  `floor`-based equation (`thumb = max(1, floor(track * viewport / content))`). Reject
  embedding that equation in a viewport widget: ScrollView determines stable overflow and
  clipping, then delegates only the indicator cells here.
- [Table](../widgets/table.md) -- copy a one-cell trailing strip beside visible data rows
  and its proportional visible/total intent. Reject Table-specific thumb rendering and its
  draft scrollbar-drag behavior for this primitive. First-delivery indicators are
  output-only; Table keeps wheel/key scrolling in its own widget and must not add input
  behavior to this shared render node.

## Inputs and geometry

The public vocabulary is intentionally small. The following is a candidate spelling, not a
committed declaration:

```swift
public struct ScrollIndicator: View {
    public init(
        axis: Axis,
        contentExtent: Int,
        viewportExtent: Int,
        effectiveOffset: Int
    )
}
```

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
0. r0-r3  Leading track -- four `scrollbar.track` cells before the vertical thumb
1. r4-r5  Thumb -- two `scrollbar.thumb` cells, styled with `semantic.accent`
2. r6-r9  Trailing track -- four `scrollbar.track` cells after the thumb
```

### Horizontal start middle and end

These are three independent horizontal `12x1` snapshots stacked for comparison. Each has
`C = 48`, `V = 12`, and `L = 3`. Their effective offsets are respectively `0`, `18`, and
`36` (the maximum). The middle start is `floor(18 * 9 / 36) = 4`.

```wireframe 12x3
■■■─────────
────■■■─────
─────────■■■
```

```text
Callouts (12x3, 0-based):
0. r0 c0-c2   Start thumb -- `O = 0`; thumb touches the leading edge
1. r0 c3-c11  Start trailing track -- nine `scrollbar.track` cells
2. r1 c0-c3   Middle leading track -- four `scrollbar.track` cells
3. r1 c4-c6   Middle thumb -- `O = 18`; three `scrollbar.thumb` cells
4. r1 c7-c11  Middle trailing track -- five `scrollbar.track` cells
5. r2 c0-c8   End leading track -- nine `scrollbar.track` cells
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
1. r6-r9    Thumb -- four `scrollbar.thumb` cells in the parent's trailing column
2. r10-r15  Trailing track -- vertical mobile allocation after the thumb
```

```wireframe 40x1
─────────────■■■■■■■■■■■■■──────────────
```

```text
Callouts (40x1, 0-based):
0. r0 c0-c12   Leading track -- thirteen cells in the parent's bottom row
1. r0 c13-c25  Thumb -- thirteen `scrollbar.thumb` cells
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
0. r0 c0  Minimum thumb -- the sole track cell is the one-cell minimum `scrollbar.thumb`
```

A zero-length proposal has no fixture because its render region has no cells. It paints
nothing; it does not create a one-cell minimum outside the rectangle.

## Variants

| Variant               | Geometry | Glyph and placement rule                                                                                                     |
| --------------------- | -------- | ---------------------------------------------------------------------------------------------------------------------------- |
| Vertical              | `1xT`    | Parent places the strip in its trailing column; track uses `scrollbar.track` vertical `│`, thumb uses `scrollbar.thumb` `█`. |
| Horizontal            | `Tx1`    | Parent places the strip in its bottom row; track uses `scrollbar.track` horizontal `─`, thumb uses `scrollbar.thumb` `■`.    |
| ASCII-only vertical   | `1xT`    | Same geometry; use the ASCII vertical bar for the track and `#` for the thumb from `scrollbar.ascii`.                        |
| ASCII-only horizontal | `Tx1`    | Same cells and geometry; replace track with `-` and thumb with `#` from `scrollbar.ascii`.                                   |

There are deliberately no leading/left, top, endpoint-arrow, disabled, focused, draggable,
or per-instance-glyph variants. Placement belongs to the parent layout; focus and disabled
semantics belong to an interactive parent; glyph selection comes only from the
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

This primitive does not own idle, loading, error, or empty business states. Those are
parent/app content states: a loading or error viewport may still show an indicator when
its actual measured content overflows; empty or no-overflow content causes the parent
omission above. No click, wheel, key, drag, or hit-test region is installed by the
primitive.

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

## Environment

The system/default rendering consumes only catalog tokens and complete semantic `Style`
values from the environment:

- `scrollbar.track` supplies the orientation-specific full-capability track glyph.
- `scrollbar.thumb` supplies the orientation-specific full-capability thumb glyph.
- `scrollbar.ascii` supplies the ASCII `|`/`-` tracks and `#` thumbs.
- `semantic.secondary` is the complete `Style` applied to the track, including any
  attributes and background as well as foreground.
- `semantic.accent` is the complete `Style` applied to the thumb, including any attributes
  and background as well as foreground.

The standard style never synthesizes a color, ANSI sequence, or partial foreground value.
`NO_COLOR` and 16-color resolution happen when the two semantic roles resolve, exactly as
defined in [tokens.md](../tokens.md#semantic-styles). A future custom component style must
receive the resolved axis and geometry plus complete track/thumb semantic styles; it may
change presentation but may not change the normalized geometry, input-free nature, or
parent-owned overflow policy. The environment key and protocol spelling for that custom
style remain open rather than adding an unregistered token here.

## Dependencies and readiness cutover

- Slice 2 layout/render substrate -- `Axis`, finite and nil `ProposedSize`, placement, and
  buffer painting are needed to allocate the one-cell strip.
- Slice 3 environment style resolution -- supplies the full `semantic.secondary` and
  `semantic.accent` `Style` values and the degradation capability selection.
- [ScrollView](../widgets/scroll-view.md), List, and [Table](../widgets/table.md) depend
  on this primitive's geometry and output contract. They own their own measurement,
  effective offset, visibility, and reservation; they do not carry a duplicate thumb
  calculation or an indicator state/protocol.

This primitive is the single resolution of the shared ScrollView/List/Table indicator
question. Once its API spelling is settled and it is implemented, ScrollView and Table can
remove their respective shared-indicator readiness blocker without waiting for a separate
renderer or an independently rounded formula. It creates no dependency on Form, Outline,
source browsing, or source mapping.

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
- `vertical and horizontal parents reserve exactly one trailing column or bottom row`
  (Variants; Anatomy: mobile allocations)
- `mobile forty column horizontal allocation preserves exact thumb geometry` (Anatomy:
  mobile allocations, `40x1`)
- `ascii indicator preserves full capability geometry with canonical glyph replacements`
  (Variants; Degradation: ASCII-only)
- `scroll indicator installs no focus binding input or drag handler` (Overview; Parent
  contract and absence states)
- `scroll view list and table use identical indicator geometry for equal metrics`
  (Dependencies and readiness cutover)

## Degradation

- `NO_COLOR`: retain the canonical Unicode geometry and glyphs; resolved
  `semantic.secondary` and `semantic.accent` fall back to their token-defined attributes.
- 16-color: retain geometry; resolve those full semantic styles to indexed terminal
  styles.
- ASCII-only: replace vertical track `│` with `|`, horizontal track `─` with `-`, and
  either thumb (`█` or `■`) with `#`. The `40x1` mobile allocation below is the exact
  degraded horizontal fixture for `C = 120`, `V = 40`, `O = 40`.

```wireframe 40x1
-------------#############--------------
```

```text
Callouts (40x1, 0-based):
0. r0 c0-c12   ASCII leading track -- thirteen `scrollbar.ascii` `-` cells
1. r0 c13-c25  ASCII thumb -- thirteen `scrollbar.ascii` `#` cells
2. r0 c26-c39  ASCII trailing track -- fourteen `scrollbar.ascii` `-` cells
```

- Below the one-cell cross-axis minimum or at a zero primary-axis proposal, honor the
  non-negative assigned rectangle and paint nothing outside it. The parent omission rule
  remains unchanged; no fallback border, label, spinner, or status text appears.

## Open questions

- Should the public axis parameter use the existing singular `Axis`, or a dedicated
  `ScrollIndicatorAxis` that prevents an accidental `Axis.Set` call? The semantic contract
  is one axis either way.
- Are `contentExtent`, `viewportExtent`, and `effectiveOffset` the accepted public labels,
  or should the immutable input be a single `ScrollIndicatorMetrics` value? Keep all four
  values immutable and scalar on the selected axis regardless of spelling.
- Should custom presentation be an environment `ScrollIndicatorStyle` protocol with a
  resolved `Configuration`, or a closure-style environment value? It must receive complete
  semantic `Style` roles and resolved geometry, not raw colors or control state.
- After terminal pointer behavior is proven, should an interactive parent layer a separate
  hit target over this output primitive? Any such work must retain this primitive's
  input-free API and use its resolved geometry rather than reimplementing thumb math.

## Inspiration

- Stable edge strips communicate document extent without consuming a focus stop or needing
  animation, which is especially valuable in the catalog's `40x16` mobile viewport.
- A single floor-based mapping turns an easily diverging visual detail into a reusable,
  snapshot-testable primitive while leaving control and application state with the widgets
  that legitimately own them.
