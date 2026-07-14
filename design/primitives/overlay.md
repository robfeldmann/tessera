---
kind: primitive
status: sketch
---

# Overlay

`overlay(alignment:_:)` is a stateless wrapper that preserves its primary child's measured
size, assigns the overlay the primary child's final bounds, and paints the overlay after
the primary child. It is ZStack-equivalent only in placement and paint order: unlike a
free `ZStack`, an overlay's size is owned solely by the primary child.

## Prior art

- Ratatui `Clear`: `~/Developer/ratatui/ratatui/main/ratatui-widgets/src/clear.rs` — use
  as contrast for explicitly overwriting a bounded layer; Tessera Overlay must not reset
  unrelated cells outside its clipped primary bounds.
- Tessera [ZStack](z-stack.md) — reuse source-order paint, shared alignment vocabulary,
  and clipping geometry; do not inherit ZStack's maximum-child sizing.
- Tessera [Slice 3](../../docs/Spec.md#slice-3-styling-text-wrapping-and-decoration) —
  owns the public API and primary-child-sized wrapper rule.

## Future wireframe and specification notes

Wireframe default and explicit alignments, an overlay larger than its primary child, and
non-overlapping versus overwritten cells. Specify measurement/proposal forwarding, exact
render order, primary-child clipping, nesting with Border/Background, and whether the
overlay has an independent style inheritance boundary.

Specify Slice 5 behavior with the same fixtures: topmost-first hit testing inside the
primary-child clip, interactive overlay bubbling, click-to-focus ordering, and decorative
overlays using `.allowsHitTesting(false)` so they do not steal input.

## Open questions

- Decide whether the public overlay closure's child receives the primary child's final
  proposal or its already-resolved bounds; the result must remain primary-size preserving.
- Decide whether a visual-only overlay has a convenience hit-testing default or always
  requires the explicit `.allowsHitTesting(false)` modifier.

## Inspiration

Overlay is for a badge, selection wash, or other layer that belongs to existing
content—not for creating a second independently sized layout container.
