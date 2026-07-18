---
kind: primitive
status: ready
---

# Frame

`frame` is a stateless layout modifier that proposes an explicit or bounded rectangle to
one child, reports its own resolved layout size, and places the child inside that
rectangle using `Alignment`. It neither draws a border nor changes the child's content.
Its final allocated frame is the clipping boundary for rendering and, when input arrives
in later slices, hit testing.

## Prior art

- Ratatui `Rect`: `~/Developer/ratatui/ratatui/main/ratatui-core/src/layout/rect.rs` —
  copy explicit integer rectangles and intersection-based clipping. Reject hidden floating
  point placement.
- Apple SwiftUI
  [View.frame](<https://developer.apple.com/documentation/swiftui/view/frame(width:height:alignment:)>)
  — copy fixed and min/max frame vocabulary with child alignment.
- Tessera [Slice 2](../../docs/Spec.md#slice-2-the-layout-protocol-and-stack-containers) —
  owns the public overloads, top-leading default, and parent-frame clipping contract.

## Anatomy

A fixed `8x3` frame aligns `Text("Go")` at `.bottomTrailing`:

```wireframe 8x3


      Go
```

```text
Callouts (8x3, 0-based):
1. r0-r2 c0-c7 Frame region -- the modifier's resolved rectangle and clipping boundary.
2. r2 c6-c7 Child region -- intrinsic `2x1` child placed by `.bottomTrailing`.
```

## Variants

| Configuration                                                                            | Resolved axis                                                                      | Child proposal and placement                                                                                            |
| ---------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| `.frame(width: w, height: h, alignment: a)`                                              | Each non-nil axis is exactly that non-negative integer.                            | Fixed axes are proposed as the fixed extent; `a` places a smaller child in retained slack.                              |
| `.frame(minWidth: minW, maxWidth: maxW, minHeight: minH, maxHeight: maxH, alignment: a)` | Each bounded axis clamps the child's extent to its declared non-negative interval. | A present maximum caps the child proposal; see [catalog layout decisions](../../docs/Spec.md#catalog-layout-decisions). |
| Invalid bounds                                                                           | Rejected before layout.                                                            | Every extent is non-negative; a supplied `min` is no greater than its supplied `max`.                                   |
| Omitted axis                                                                             | Child's measured axis.                                                             | Frame does not invent stretch on that axis.                                                                             |

`Alignment` defaults to `.topLeading`; `.top`, `.center`, `.bottomTrailing`, and the other
public enum cases select the corresponding integer offset. When slack is odd, leading/top
receives the lower coordinate and trailing/bottom receives the remainder. A child larger
than its frame keeps its measured extent but is clipped by the frame; Frame does not
scale, re-measure, or redistribute it.

Composition order is observable: `content.padding(1).frame(width: 8)` aligns the padded
`content` inside eight cells, while `content.frame(width: 8).padding(1)` adds two outer
cells and reports width ten.

| Composition                             | Result | Rule                                                                      |
| --------------------------------------- | ------ | ------------------------------------------------------------------------- |
| `Text("Go").padding(1).frame(width: 8)` | 8x3    | Frame aligns the already-padded `4x3` child inside eight cells.           |
| `Text("Go").frame(width: 8).padding(1)` | 10x3   | Padding adds two outer columns after Frame resolves its eight-cell width. |

## Sizing

For `Text("Go").frame(width: 8, height: 3)`, the child is intrinsically `2x1`; a fixed
frame reports its fixed dimensions even when the incoming proposal is narrower. Bounded
frames use the validation and proposal rules in
[catalog layout decisions](../../docs/Spec.md#catalog-layout-decisions).

| Proposal                                                           | Result | Rule                                                                                                    |
| ------------------------------------------------------------------ | ------ | ------------------------------------------------------------------------------------------------------- |
| `Text("Go").frame(width: 8, height: 3)`, nil x nil                 | 8x3    | Fixed width and height determine the frame's ideal size.                                                |
| `Text("Go").frame(width: 8, height: 3)`, 8x3                       | 8x3    | Tight proposal equals the fixed frame.                                                                  |
| `Text("Go").frame(width: 8, height: 3)`, 3x1                       | 8x3    | Fixed frame retains its size; its parent may later clip its assigned frame.                             |
| `Text("Go").frame(width: 8, height: 3)`, 80x24                     | 8x3    | Extra proposal does not enlarge a fixed frame.                                                          |
| `Text("Go").frame(minWidth: 6)`, nil x nil                         | 6x1    | The two-cell child is raised to the declared minimum.                                                   |
| `Text("Go").frame(minWidth: 6, maxWidth: 10)`, 8x1                 | 6x1    | Child remains intrinsic and frame clamps its resolved width inside the valid interval.                  |
| `Text("Twelve chars").frame(minWidth: 6, maxWidth: 10)`, nil x nil | 10x1   | The larger intrinsic child is capped at maximum and clipped in the resolved frame.                      |
| `Text("Go").frame(maxWidth: 4)`, nil x nil                         | 2x1    | Max-only frame proposes its finite cap but does not stretch non-flexible Text.                          |
| `Text("Twelve chars").frame(maxWidth: 4)`, nil x nil               | 4x1    | Max-only frame reports the cap and clips the larger child; it never forwards an unconstrained proposal. |
| `Text("Go").frame(maxWidth: 4)`, 3x1                               | 2x1    | A finite parent proposal is capped to the smaller of parent and maximum before child measurement.       |

## Alignment fixtures

| Alignment fixture                    | Child frame | Rule                                                          |
| ------------------------------------ | ----------- | ------------------------------------------------------------- |
| fixed `8x3`, `.bottomTrailing`, `Go` | `(6,2) 2x1` | Bottom-trailing placement matches the anatomy's Child region. |
| fixed `6x2`, `.center`, `Go`         | `(2,0) 2x1` | One odd slack cell goes to trailing and one to bottom.        |

## Environment

Frame consumes no environment token and has no state model. Alignment is a Slice 2 layout
value, not a style or environment token.

## Requirements

- `fixed frame reports its declared dimensions` (sizing:
  `Text("Go").frame(width: 8, height: 3)`, nil x nil).
- `fixed frame remains its declared size under a narrow proposal` (sizing:
  `Text("Go").frame(width: 8, height: 3)`, 3x1).
- `bounded frame raises an undersized child to its minimum` (sizing:
  `Text("Go").frame(minWidth: 6)`, nil x nil).
- `bounded frame caps an oversized child at its maximum` (sizing:
  `Text("Twelve chars").frame(minWidth: 6, maxWidth: 10)`, nil x nil).
- `max-only frame forwards a finite capped proposal` (sizing:
  `Text("Go").frame(maxWidth: 4)`, nil x nil).
- `max-only frame clips an oversized child` (sizing:
  `Text("Twelve chars").frame(maxWidth: 4)`, nil x nil).
- `frame rejects inverted or negative bounds before layout` (variants: Invalid bounds).
- `frame aligns an undersized child inside retained slack` (alignment fixture: fixed
  `8x3`, `.bottomTrailing`, `Go`; anatomy: Child region).
- `odd centered slack assigns the extra cell to trailing and bottom` (alignment fixture:
  fixed `6x2`, `.center`, `Go`).
- `frame clips an oversized child to its final allocated rectangle` (sizing:
  `Text("Twelve chars").frame(maxWidth: 4)`, nil x nil).
- `padding and frame preserve modifier order` (composition fixtures:
  `Text("Go").padding(1).frame(width: 8)` and `Text("Go").frame(width: 8).padding(1)`).

## Degradation

Frame draws no glyphs and consumes no style or terminal capability. Its integer sizing,
alignment, and clipping remain unchanged in ASCII-only and no-color modes.

## Decisions

Frame validation and bounded-axis proposal rules are fixed in
[catalog layout decisions](../../docs/Spec.md#catalog-layout-decisions): invalid bounds
trap before layout, and a max-only axis sends a finite capped proposal to its child. No
Frame-specific decision remains open.

## Inspiration

Frame is allocation and alignment, not decoration. Borders, backgrounds, and hit-target
policy are separate later composition layers.
