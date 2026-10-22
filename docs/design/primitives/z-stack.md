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
- Tessera [Slice 2](../../spec/phase-4/slice-02-layout-protocol-and-stacks.md) — owns the
  public initializer, `.topLeading` default, and frame clipping contract.
- omp2 has no in-flow ZStack. Its layers are viewport-anchored overlays
  ([overlay.rs](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/overlay.rs#L1-L6))
  that `Ui::show_overlay` stacks above the document by an explicit `z`, later overlays on
  top among equal `z`
  ([ui.rs](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/ui.rs#L1129-L1145)).
  The [translation key](../translation-key.md#h-layering) rejects those layers for 1.0:
  Tessera layers in flow with `ZStack`, `.overlay`, and `.background`, and defers
  viewport-anchored modal presentation (key H1). Copy the later-on-top rule; reject the
  explicit `z`, so source order is the only order.

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
the same bounds; it is not a linear stack and ignores `layoutPriority`. A non-text child
(a fixed-size frame, for example) that exceeds its ZStack bounds remains clipped to the
ZStack's final parent frame; a Text child never is: it lays out again at the proposal it
is given and wraps or marks its last visible row. Later layout modifiers may make an
overlay's visual area smaller than the common allocation, as in the anatomy's fixed-width
Text.

## Allocation and diagnostics

| ZStack proposal and children                          | Child frames                         | Diagnostics and rule                                                                            |
| ----------------------------------------------------- | ------------------------------------ | ----------------------------------------------------------------------------------------------- |
| `6x1`: `Text("status")`, `Text("OK").frame(width: 2)` | `status: (0,0) 6x1`; `OK: (0,0) 2x1` | `paintOrder` is `0` for `status`, `1` for `OK`; increasing source order overwrites prior cells. |
| `6x1`: `Text("A").layoutPriority(9)`, `Text("B")`     | `A: (0,0) 6x1`; `B: (0,0) 6x1`       | `paintOrder` stays `0`, `1`; layout priority does not change ZStack placement or paint order.   |

`dump()` records this zero-based `paintOrder` field for each placed child; it does not
invent a separate z-index value. This durable schema is fixed by
[catalog layout decisions](../../spec/phase-4/slice-02-layout-protocol-and-stacks.md#catalog-layout-decisions).

## Sizing

For `ZStack { Text("A"); Text("BBBB") }`, the ideal result is `4x1`: the maximum of child
dimensions, not their sum. ZStack proposes its own proposal to every child. A narrow
proposal does not make ZStack report a negative size: Text children lay out again at the
narrow width (`Text("BBBB")` at 2x1 is one budget row, `B…`, per
[Text](text.md#row-budget)), while a non-text child that keeps its fixed extent is clipped
by the
[Slice 2 placement contract](../../spec/phase-4/slice-02-layout-protocol-and-stacks.md)
when its parent assigns a smaller frame.

| Proposal                                                  | Result | Rule                                                                                       |
| --------------------------------------------------------- | ------ | ------------------------------------------------------------------------------------------ |
| nil x nil                                                 | 4x1    | Ideal width is the widest child and ideal height is the tallest child.                     |
| 4x1                                                       | 4x1    | Tight proposal equals the combined maximum extent.                                         |
| 2x1                                                       | 2x1    | Text lays out again at two cells: `Text("BBBB")` marks its one budget row `B…`.            |
| `ZStack { Text("A"); Text("BBBB").frame(width: 4) }`, 2x1 | 4x1    | The fixed frame retains four cells; a parent assigning two cells clips that frame's cells. |
| 80x24                                                     | 4x1    | Extra proposal does not stretch non-flexible child content or the ZStack ideal.            |

## Environment

ZStack consumes no environment token and has no mutable state model. Common bounds,
alignment offsets, source-order paint order, and the parent-frame clipping intersection
are derived every layout and render pass.

## Requirements

- `zstack reports the maximum child width and height` (sizing: nil x nil).
- `zstack does not sum child extents` (sizing: nil x nil).
- `zstack proposes a narrow width to Text, which wraps or marks its last visible row`
  (sizing: 2x1).
- `zstack clips a fixed-size non-text child to its assigned parent frame` (sizing:
  `ZStack { Text("A"); Text("BBBB").frame(width: 4) }`, 2x1).
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

Source order is the only overlay ordering: `dump()` records lexical `paintOrder`, ZStack
has no distinct z-index (key H1), and
[Slice 5](../../spec/phase-4/slice-05-mouse-and-hit-testing.md) hit testing visits its
children topmost first. The exact diagnostics schema is
[catalog layout decisions](../../spec/phase-4/slice-02-layout-protocol-and-stacks.md#catalog-layout-decisions);
no ZStack decision remains open.

Reviewed against the [Phase 4 theses](../../spec/phase-4.md): ZStack is a value
description lowered to one layout node, its common bounds and paint order are
deterministic and shown by `dump()`, it holds no state, and it touches no terminal
capability.

## Inspiration

ZStack is geometry and deterministic paint order. Viewport-anchored modal presentation is
deferred (key H1); pointer capture, background fill, and decoration belong to other
components rather than this primitive.
