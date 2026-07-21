---
kind: primitive
status: sketch
---

# Border

`border` is a stateless unary layout-and-render modifier. It reserves one cell on every
edge, draws a `BorderStyle` glyph ring in the retained inset, and clips its child to the
interior frame. It composes with Frame and Padding but is not a Box: Border has no title
or implicit content padding.

## Prior art

- Ratatui `Block`: `~/Developer/ratatui/ratatui/main/ratatui-widgets/src/block.rs` — copy
  explicit border glyph selection and edge-aware rendering. Reject coupling title,
  padding, and all decoration configuration into the simple Border modifier.
- Ratatui border glyph support:
  `~/Developer/ratatui/ratatui/main/ratatui-widgets/src/borders.rs` — use as a reference
  for named box-drawing sets and custom glyph sets.
- Tessera [Slice 3](../../docs/Spec.md#slice-3-styling-text-wrapping-and-decoration) —
  owns `BorderStyle`, the public modifier signature, and one-cell-inset direction.

## Future wireframe and specification notes

Wireframe every named `BorderStyle` (`single`, `rounded`, `double`, `heavy`, `ascii`) and
a custom glyph fixture. Include normal, narrow, `1x1`, and zero-area allocations;
degenerate frames must clamp and never crash. Specify exact child proposal reduction,
corner and edge precedence, line-style inheritance/override, Frame/Padding order, final
clipping, ASCII fallback, and Slice 5 hit-testing geometry for a decorative border versus
an interactive wrapped child.

## Open questions

- Reconcile the Spec's `single` spelling with the catalog token table's `light` border-set
  name without exposing two user-facing defaults.
- Decide the custom `BorderGlyphs` validation and degenerate-edge rendering policy.

## Inspiration

Border is the canonical example of a modifier that is both ordinary layout geometry and a
small render decoration.
