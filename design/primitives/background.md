---
kind: primitive
status: sketch
---

# Background

`background(@ViewBuilder:)` is a stateless wrapper that preserves its primary child's
measured size, assigns the background the primary child's final bounds, paints it first,
and then paints the primary child over it. It is distinct from `.background(Color)`, which
belongs to the Style modifiers environment contract. Neither overload changes
primary-child identity or creates a second independently sized layout container.

## Prior art

- Ratatui `Clear`: `~/Developer/ratatui/ratatui/main/ratatui-widgets/src/clear.rs` — copy
  bounded, clipped cell writes as a rendering discipline. Reject resetting cells outside
  the primary bounds or using a background to clear terminal-global state.
- Tessera [ZStack](z-stack.md) — reuse alignment, clipping, and ordered layer composition;
  Background reverses the visible layer order and retains primary-child sizing.
- Tessera [Slice 3](../../docs/Spec.md#slice-3-styling-text-wrapping-and-decoration) —
  owns the public view-builder API and ZStack-equivalent wrapper direction.

## Future wireframe and specification notes

Wireframe opaque and sparse backgrounds, explicit alignment, backgrounds larger than the
primary child, nested Background/Overlay combinations, and the color-overload distinction.
Specify measurement/proposal forwarding, background-first paint order, primary-child
clipping, inherited style boundaries, and Frame/Padding/Border composition.

Specify Slice 5 behavior in the same contract: background hit testing is restricted to the
primary-child clip, interactive backgrounds bubble from their deeper handler position, and
pure decoration must use `.allowsHitTesting(false)` so it cannot intercept primary-child
input.

## Open questions

- Decide whether the view-builder background has a visual-only convenience or always needs
  explicit `.allowsHitTesting(false)` when it is decorative.
- Decide how a sparse background's untouched cells interact with `.background(Color)`
  style fills while preserving predictable paint order.

## Inspiration

Background decorates existing content from behind. It must not turn a bounded component
into a terminal-wide canvas.
