---
kind: primitive
status: specified
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

| Configuration                                                                            | Resolved axis                                                                        | Child proposal and placement                                                                            |
| ---------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------- |
| `.frame(width: w, height: h, alignment: a)`                                              | Each non-nil axis is exactly that non-negative integer.                              | Fixed axes are proposed as the fixed extent; `a` places a smaller child in the retained slack.          |
| `.frame(minWidth: minW, maxWidth: maxW, minHeight: minH, maxHeight: maxH, alignment: a)` | Each bounded axis clamps the child's ideal between its declared minimum and maximum. | The child receives the finite resolved bound when one exists; `a` places an undersized child within it. |
| Omitted axis                                                                             | Child's measured axis.                                                               | Frame does not invent stretch on that axis.                                                             |

`Alignment` defaults to `.topLeading`; `.top`, `.center`, `.bottomTrailing`, and the other
public enum cases select the corresponding integer offset. When slack is odd, leading/top
receives the lower coordinate and trailing/bottom receives the remainder. A child larger
than its frame keeps its measured extent but is clipped by the frame; Frame does not
scale, re-measure, or redistribute it.

Composition order is observable: `content.padding(1).frame(width: 8)` aligns the padded
`content` inside eight cells, while `content.frame(width: 8).padding(1)` adds two outer
cells and reports width ten.

## Sizing

For `Text("Go").frame(width: 8, height: 3)`, the child is intrinsically `2x1`; a fixed
frame reports its fixed dimensions even when the incoming proposal is narrower. This makes
narrow parent behavior deterministic: the parent selects the final allocation and the
[Slice 2 placement contract](../../docs/Spec.md#slice-2-the-layout-protocol-and-stack-containers)
clips the resulting subtree.

| Proposal  | Result | Rule                                                                                   |
| --------- | ------ | -------------------------------------------------------------------------------------- |
| nil x nil | 8x3    | Fixed width and height determine the frame's ideal size.                               |
| 8x3       | 8x3    | Tight proposal equals the fixed frame.                                                 |
| 3x1       | 8x3    | A fixed frame retains its declared size; its parent may later clip its assigned frame. |
| 80x24     | 8x3    | Extra proposal does not enlarge a fixed frame.                                         |

For `Text("Go").frame(minWidth: 6, maxWidth: 10)`, `nil x nil` reports `6x1`: the child's
`2x1` ideal is raised to the minimum. An unbounded maximum never forces expansion; a
maximum only caps a larger resolved child extent.

## Environment

Frame consumes no environment token and has no state model. Alignment is a Slice 2 layout
value, not a style or environment token.

## Requirements

- `fixed frame reports its declared dimensions` (sizing: nil x nil).
- `fixed frame remains its declared size under a narrow proposal` (sizing: 3x1).
- `bounded frame raises an undersized child to its minimum` (sizing: bounded-frame
  example).
- `frame aligns an undersized child inside retained slack` (anatomy: Child region).
- `odd centered slack assigns the extra cell to trailing and bottom` (variants:
  Alignment).
- `frame clips an oversized child to its final allocated rectangle` (variants: oversized
  child).
- `padding and frame preserve modifier order` (variants: composition order).

## Degradation

Frame draws no glyphs and consumes no style or terminal capability. Its integer sizing,
alignment, and clipping remain unchanged in ASCII-only and no-color modes.

## Open questions

- Settle the public validation rule for contradictory min/max arguments before the API
  freezes. This contract requires a deterministic non-negative resolved interval and no
  inverted frame.
- Confirm whether a max-only frame forwards an unconstrained or capped proposal to a
  flexible custom Layout; the resulting reported size and clipping rule above remain the
  required observable behavior.

## Inspiration

Frame is allocation and alignment, not decoration. Borders, backgrounds, and hit-target
policy are separate later composition layers.
