---
kind: primitive
status: sketch
---

# Grid

Grid is a stateless two-axis layout primitive for source-ordered children. It resolves its
columns through Tessera's shared [Flex](flex.md) constraints, derives each row's height
from the tallest child at its resolved column width, and paints cells in source order. It
does not span cells, scroll, draw separators, retain selection, or handle input.

## Prior art

- Ratatui's
  [`Constraint`](https://github.com/ratatui/ratatui/blob/a2ca2df5688772baffb743b494761f4ec82b3174/ratatui-core/src/layout/constraint.rs)
  and
  [`Layout`](https://github.com/ratatui/ratatui/blob/a2ca2df5688772baffb743b494761f4ec82b3174/ratatui-core/src/layout/layout.rs)
  sources demonstrate reusable integer constraints and deterministic one-axis allocation.
  Tessera reuses its established Flex solver rather than adding a Grid-specific allocator.
- Ratatui's
  [`Table`](https://github.com/ratatui/ratatui/blob/a2ca2df5688772baffb743b494761f4ec82b3174/ratatui-widgets/src/table.rs)
  demonstrates coordinated columns across rows. Tessera Grid remains a stateless layout
  primitive; headers, selection, scrolling, and data semantics belong to higher-level
  widgets.
- Ratatui's
  [`Constraint Explorer`](https://github.com/ratatui/ratatui/blob/a2ca2df5688772baffb743b494761f4ec82b3174/examples/apps/constraint-explorer/src/main.rs)
  demonstrates app-owned editable constraints and allocation labels. A Tessera demo of the
  same kind should compose the public Grid API without moving explorer state or diagnostic
  presentation into Grid.

## Known direction

- Column constraints use the public `FlexConstraint` vocabulary and resolve once per
  layout pass through the shared solver.
- Row heights are the maximum measured child height at each resolved column width.
- Children occupy cells in source order; an incomplete final row remains valid.
- Version 1 rejects spanning rather than introducing an unproved placement model.
- Grid owns allocation only. Cell selection, editable row fixtures, scrolling, and
  Inspector presentation remain application or widget concerns.

## Open questions

- What public initializer and row-grouping shape preserves `ViewBuilder` identity while
  making the column count explicit?
- How do horizontal and vertical spacing participate in ideal, tight, and unspecified
  measurement proposals?
- Which public alignment controls, if any, are required independently for cells and the
  complete grid?
- What exact empty-grid and incomplete-row geometry should diagnostics expose?
