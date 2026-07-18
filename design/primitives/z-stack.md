---
kind: primitive
status: ready
---

# ZStack

`ZStack` is a stateless overlay container. It measures its ideal extent as the maximum
width and height reported by its children, assigns every child the same final bounds, and
places each child using a shared `Alignment`. Children render in source order: later
children paint over earlier children where their clipped frames overlap. It owns neither
style nor input routing.

## Prior art

- Ratatui `Rect`: `~/Developer/ratatui/ratatui/main/ratatui-core/src/layout/rect.rs` —
  copy explicit rectangle intersection as the only clipping mechanism.
- Apple SwiftUI [ZStack](https://developer.apple.com/documentation/swiftui/zstack) — copy
  overlay composition and explicit alignment. Reject implicit modal/input behavior.
- Tessera [Slice 2](../../docs/Spec.md#slice-2-the-layout-protocol-and-stack-containers) —
  owns the public initializer, `.topLeading` default, and frame clipping contract.

## Anatomy

`ZStack { Text("status"); Text("OK").frame(width: 2) }` is assigned `6x1`; the later `OK`
overlay paints over the first two cells of `status`:

```wireframe 6x1
OKatus
```

```text
Callouts (6x1, 0-based):
1. r0 c0-c5 Base child region -- first child fills its allocated source-order layer.
2. r0 c0-c1 Overlay region -- later child paints last and replaces overlapping cells.
3. r0 c2-c5 Revealed base region -- base cells remain where no later child paints.
```

## Variants

| Configuration                        | Measurement                    | Placement and paint                                                                          |
| ------------------------------------ | ------------------------------ | -------------------------------------------------------------------------------------------- |
| `ZStack { ... }`                     | maximum child width and height | `.topLeading`; children receive common bounds and paint in source order.                     |
| `ZStack(alignment: a) { ... }`       | maximum child width and height | `a` positions undersized children within common bounds; later source children remain on top. |
| children with `.layoutPriority(...)` | maximum child width and height | Priority is ignored; common bounds and lexical source paint order are unchanged.             |
| Empty `ZStack`                       | `0x0`                          | Places no subviews and paints no cells.                                                      |

ZStack does not reserve space between layers. Each child is independently positioned in
the same bounds; it is not a linear stack and ignores `layoutPriority`. A child that
exceeds its ZStack bounds remains clipped to the ZStack's final parent frame. Later layout
modifiers may make an overlay's visual area smaller than the common allocation, as in the
anatomy's fixed-width Text.

## Allocation and diagnostics

| ZStack proposal and children                          | Child frames                         | Diagnostics and rule                                                                            |
| ----------------------------------------------------- | ------------------------------------ | ----------------------------------------------------------------------------------------------- |
| `6x1`: `Text("status")`, `Text("OK").frame(width: 2)` | `status: (0,0) 6x1`; `OK: (0,0) 2x1` | `paintOrder` is `0` for `status`, `1` for `OK`; increasing source order overwrites prior cells. |
| `6x1`: `Text("A").layoutPriority(9)`, `Text("B")`     | `A: (0,0) 6x1`; `B: (0,0) 6x1`       | `paintOrder` stays `0`, `1`; layout priority does not change ZStack placement or paint order.   |

`dump()` records this zero-based `paintOrder` field for each placed child; it does not
invent a separate z-index value. This durable schema is fixed by
[catalog layout decisions](../../docs/Spec.md#catalog-layout-decisions).

## Sizing

For `ZStack { Text("A"); Text("BBBB") }`, the ideal result is `4x1`: the maximum of child
dimensions, not their sum. A narrow parent does not cause a ZStack to report a negative or
compressed child size; it assigns its final frame and clips overflow by the
[Slice 2 placement contract](../../docs/Spec.md#slice-2-the-layout-protocol-and-stack-containers).

| Proposal  | Result | Rule                                                                            |
| --------- | ------ | ------------------------------------------------------------------------------- |
| nil x nil | 4x1    | Ideal width is the widest child and ideal height is the tallest child.          |
| 4x1       | 4x1    | Tight proposal equals the combined maximum extent.                              |
| 2x1       | 4x1    | Child ideal extent is retained; a later assigned 2-cell parent frame clips it.  |
| 80x24     | 4x1    | Extra proposal does not stretch non-flexible child content or the ZStack ideal. |

## Environment

ZStack consumes no environment token and has no mutable state model. Common bounds,
alignment offsets, source-order paint order, and the parent-frame clipping intersection
are derived every layout and render pass.

## Requirements

- `zstack reports the maximum child width and height` (sizing: nil x nil).
- `zstack does not sum child extents` (sizing: nil x nil).
- `zstack clips an oversized child to its assigned parent frame` (sizing: 2x1).
- `later zstack children paint over earlier overlapping cells` (anatomy: Overlay region;
  allocation and diagnostics: `6x1`: `Text("status")`, `Text("OK").frame(width: 2)`).
- `zstack aligns undersized children within common bounds` (variants:
  `ZStack(alignment: a) { ... }`).
- `empty zstack reports zero size and paints nothing` (variants: Empty `ZStack`).
- `zstack ignores layout priority during overlay placement` (allocation and diagnostics:
  `6x1`: `Text("A").layoutPriority(9)`, `Text("B")`; variants: children with
  `.layoutPriority(...)`).

## Degradation

ZStack uses no glyph, color, or capability token. ASCII-only and reduced-color terminals
preserve its integer bounds, source-order overwriting, alignment, and clipping.

## Decisions

Source order is the only overlay ordering: `dump()` records lexical `paintOrder`, and
ZStack has no distinct z-index. The exact diagnostics schema is
[catalog layout decisions](../../docs/Spec.md#catalog-layout-decisions); no ZStack
decision remains open.

## Inspiration

ZStack is geometry and deterministic paint order. Modal presentation, pointer capture,
background fill, and decoration belong to later components rather than this primitive.
