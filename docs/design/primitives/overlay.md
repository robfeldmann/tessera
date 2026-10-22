---
kind: primitive
status: ready
---

# Overlay

`overlay(alignment:_:)` is a stateless wrapper that preserves its primary child's measured
size, proposes the overlay layer the primary child's final bounds, and paints the overlay
after the primary child. It is ZStack-equivalent only in placement and paint order: unlike
a free [ZStack](z-stack.md), an overlay's size is owned solely by the primary child.

## Prior art

- Ratatui `Clear`: `~/Developer/ratatui/ratatui/main/ratatui-widgets/src/clear.rs` resets
  cells inside its intersected render area. Overlay is the contrast: it paints only its
  overlay output and must not reset cells outside its clipped primary bounds.
- Tessera [ZStack](z-stack.md) supplies the shared `Alignment` vocabulary, placement
  offsets, source-order paint, and clipping geometry. Overlay deliberately rejects
  ZStack's maximum-child sizing.
- Tessera [Slice 3](../../docs/Spec.md#slice-3-styling-text-wrapping-and-decoration) owns
  this public API and primary-child-sized wrapper rule.
- omp2 has no in-flow overlay. Its layers are viewport-anchored
  ([overlay.rs](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/overlay.rs#L1-L6)),
  placed by `OverlayOptions` with an anchor, margins, a `z` height, and modality
  ([overlay.rs](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/overlay.rs#L57-L99)),
  and a nested paint pass draws into a scratch or overlay frame
  ([component.rs](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/component.rs#L1434-L1437)).
  The [translation key](../translation-key.md#h-layering) rejects viewport-anchored layers
  for 1.0 and layers in flow with `.overlay`, `.background`, and `ZStack` (key H1); the
  layer renders once into the primary's translated, clipped region, with no scratch copy
  (key H2). Reject anchors, margins, `z`, and modality: alignment inside the primary
  bounds is the only placement.

## Anatomy

In these fixtures the shaded cells are the overlay layer painted on top, and the letters
are the primary child showing through wherever the overlay does not cover. The grid is the
composited result; the overlay never enlarges the primary bounds.

Default `.topLeading` places a two-cell overlay at the leading top of a five-cell primary:

```wireframe 5x1
░░cde
```

```text
Callouts (5x1, 0-based):
1. r0 c0-c4  primary bounds -- final bounds measured from the primary child `abcde`
2. r0 c0-c1  overlay layer -- painted last, aligned by `.topLeading`
3. r0 c2-c4  revealed primary -- `cde`, the primary cells the overlay does not cover
```

An explicit `.topTrailing` moves the same overlay without changing the wrapper's size, and
the primary cells outside the overlay stay intact:

```wireframe 5x1
abc░░
```

```text
Callouts (5x1, 0-based):
1. r0 c0-c4  primary bounds -- final bounds measured from the primary child `abcde`
2. r0 c3-c4  overlay layer -- painted last, aligned by `.topTrailing`
3. r0 c0-c2  revealed primary -- `abc`, retained because the overlay overwrites only its region
```

An overlay wider than its primary child is clipped to the primary bounds. Here a five-cell
overlay band covers the whole top row of a four-by-two primary; the bottom row is primary:

```wireframe 4x2
░░░░
efgh
```

```text
Callouts (4x2, 0-based):
1. r0-r1 c0-c3  primary bounds -- final bounds measured from the primary child
2. r0 c0-c3     overlay layer -- a wider band clipped to the four-cell primary width
3. r1 c0-c3     revealed primary -- `efgh`, the row the overlay does not cover
```

A one-cell primary still establishes the only paintable bounds; the overlay paints over
that single cell.

```wireframe 1x1
░
```

```text
Callouts (1x1, 0-based):
1. r0 c0  overlay layer -- the sole primary cell, painted over after the primary
```

A zero-area primary paints nothing, so its overlay receives zero-area bounds and paints
nothing too.

## Public API

[Decoration](../../docs/Spec.md#decoration) fixes the spelling:

```swift
extension View {
  public func overlay<O: View>(
    alignment: Alignment = .topLeading,
    @ViewBuilder _ overlay: () -> O
  ) -> some View
}
```

The receiver is the primary child. `alignment` uses the same vocabulary as
[ZStack](z-stack.md); `.topLeading` is the default. The layer closure creates exactly the
overlay child and introduces no persistent state, style type, input handler, or z-index.

## Sizing

These rows use `Text("BASE")` as the primary child, which measures `4x1`, and
`Text("BADGE")` as the overlay layer. The overlay is proposed the primary's final result
in every row and is then clipped to those same bounds.

| Proposal  | Result | Rule                                                                                 |
| --------- | ------ | ------------------------------------------------------------------------------------ |
| nil x nil | 4x1    | The primary's unconstrained ideal is the wrapper result; the overlay never enlarges. |
| 4x1       | 4x1    | The tight proposal produces the primary's final `4x1` bounds for both layers.        |
| 2x1       | 4x1    | The under-minimum proposal retains the primary's measured result; the parent clips.  |
| 80x24     | 4x1    | The over-maximum proposal does not stretch the primary or admit overlay growth.      |

During placement, the primary receives its final bounds. The layer closure's child is also
proposed those final bounds, is aligned within them using `Alignment`, and has its paint
clipped to their intersection. The primary paints first; the overlay paints on top.

## Environment

Overlay consumes no token and creates no environment value. It does not create a
view-layer style or a color-only alias: the buffer's single `Style` remains the style
contract for each child. A primary or overlay child may independently consume `primary`,
`secondary`, `accent`, `disabled`, or `destructive` through that existing `Style`, but
Overlay neither resolves nor changes those tokens.

## Requirements

- `overlay reports the primary child ideal for an unconstrained proposal` (sizing: nil x
  nil)
- `overlay preserves primary size under a tight proposal` (sizing: 4x1)
- `overlay never enlarges an under-minimum primary result` (sizing: 2x1)
- `overlay does not stretch a primary for an over-maximum proposal` (sizing: 80x24)
- `overlay defaults its layer to the top-leading primary region` (anatomy: overlay layer,
  topLeading example)
- `overlay applies explicit top-trailing alignment without resizing` (anatomy: overlay
  layer, topTrailing example)
- `overlay clips an oversized layer to primary bounds` (anatomy: overlay layer, oversized
  example)
- `overlay paints its layer after the primary without clearing revealed cells` (anatomy:
  revealed primary, topTrailing example)
- `overlay paints nothing when its primary bounds have zero area` (anatomy: zero-area
  primary note)
- `decorative overlay requires explicit hit-testing opt-out` (open questions: decorative
  overlay decision)

## Degradation

Overlay emits no glyph, color, or capability token of its own. Its integer sizing,
alignment, clipping, and paint order are unchanged at every tier of the
[degradation ladder](../tokens.md#degradation-ladder); each child degrades its own `Style`
and glyph output.

## Open questions

- Resolved: the layer closure's child is proposed the primary child's final bounds. This
  preserves primary-only measurement while giving both layers one placement and clipping
  rectangle.
- Resolved: a decorative layer must declare `.allowsHitTesting(false)` explicitly. There
  is no implicit decorative or visual-only hit-testing default.
- Resolved by [Slice 5](../../docs/Spec.md#slice-5-mouse-and-hit-testing): hit testing
  respects ZStack order, topmost first, and Overlay is a ZStack-equivalent wrapper
  ([Decoration](../../docs/Spec.md#decoration)), so a point inside the primary bounds
  reaches the overlay layer before the primary. `.allowsHitTesting(false)` subtrees are
  skipped, and bubbling and click-to-focus follow Slice 5's routing. This primitive
  supplies only the paint order that routing reads.

Reviewed against the
[Phase 4 theses](../../docs/Spec.md#phase-4--view-layer-the-tessera-module): Overlay is a
value-type modifier lowered to one wrapper node, its sizing, alignment, clipping, and
paint order are deterministic and shown by `dump()`, it holds no state, and it touches no
terminal capability.

## Inspiration

- A compact status badge attached to an existing label without changing that label's
  layout size.
- A selection wash or decoration that can be layered over content while leaving every
  non-overlapping buffer cell intact.
