---
kind: primitive
status: specified
---

# Grid

Grid is a stateless two-axis layout primitive. Its rows are `GridRow`s, each row's cells
fill the columns in source order, and its columns resolve once per layout pass through the
shared [Flex](flex.md) resolver. Each row is as tall as its tallest cell at the resolved
column widths, and cells paint in source order. It does not span cells, scroll, draw
separators, retain selection, or handle input.

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
- omp2 has no grid component. Its counterpart is the column solver that `<table>` and
  `<select>` share
  ([`grid_measure` and `solve_columns`](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/layout.rs#L197-L299))
  and its row placement
  ([`place_grid_row`](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/layout.rs#L301-L324));
  the [translation key](../translation-key.md#g-layout) puts Grid and Table on Flex's one
  resolver (key G9). Copy column bounds that aggregate every row's cells, a row as tall as
  its tallest cell, and a gap between columns only
  ([table.rs](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/table.rs#L86-L94)).
  Reject the column count taken from the longest row, column sizes read from cell
  attributes (key B2), the floating-point grow score and widest-first shrink, the one-cell
  minimum per column and per row, and cells stretched to the row height (key G7).
- Apple SwiftUI [Grid](https://developer.apple.com/documentation/swiftui/grid) and
  [GridRow](https://developer.apple.com/documentation/swiftui/gridrow) — copy `GridRow` as
  the row grouping. Reject the implicit column count and cell spanning; its separate
  horizontal and vertical spacing is an [open question](#open-questions).

## Anatomy

`Grid(columns: [.length(6), .fill(1)], spacing: 1)` holds
`GridRow { Text("Name"); Text("Tessera") }` and
`GridRow { Text("State"); Text("ready to ship") }`, assigned 14 columns:

```wireframe 14x3
Name   Tessera
State  ready
       to ship
```

```text
Callouts (14x3, 0-based):
1. r0-r2 c0-c5      First column -- `.length(6)`: six cells in every row
2. r0-r2 c6         Spacing -- the one `spacing: 1` cell between columns; no outer spacing
3. r0-r2 c7-c13     Second column -- `.fill(1)`: compressed from its 13-cell ideal to 7
4. r0               First row -- one row tall: its tallest cell at the resolved widths
5. r1-r2            Second row -- two rows tall: `ready to ship` wraps at seven cells; content, wraps
6. r1 c5, r2 c0-c5  Cell slack -- `State` keeps its measured 5x1 at its cell's top-leading corner
```

## Public API

[Slice 6](../../spec.md#slice-6-grid-table-and-fitting) fixes the spelling; `GridRow`'s
initializer, which the Spec elides, takes only its cells:

```swift
public struct Grid<Content: View>: View {
  public init(
    columns: [FlexConstraint],
    spacing: Int = 0,
    @ViewBuilder content: () -> Content
  )
}

public struct GridRow<Content: View>: View {
  public init(@ViewBuilder content: () -> Content)
}
```

`columns.count` is the column count, and each `FlexConstraint` is validated at its own
construction ([Flex](flex.md#public-vocabulary)). `spacing` must be non-negative; a
negative value fails a `precondition` before layout, as
[catalog layout decisions](../../spec.md#catalog-layout-decisions) fix for stacks.

## Measurement and placement

Grid measures, resolves, and places in this order:

1. **Columns.** Column `j`'s measured ideal is the widest ideal of its cells across all
   rows, each cell measured at `(nil, nil)`; its measured minimum is the widest width its
   cells report at `(0, nil)`. A column with no cells measures zero for both.
2. **Resolution.** Each column lowers to one
   [Flex resolver item](flex.md#constraint-resolution) with `columns[j]` as its
   constraint. Grid's width proposal and `spacing` are the resolver's main-axis proposal
   and spacing, so spacing is reserved between columns only, an unspecified width reports
   the sum of the initial allocations plus spacing, and a deficit keeps hard floors and
   lets the parent clip trailing columns. The resolver runs once per layout pass, and
   every row uses its widths (key G9).
3. **Rows.** Each `GridRow` is one row, and its cells fill columns `0, 1, ...` in source
   order; a row with fewer cells leaves its trailing columns empty. A row's height is the
   tallest of its cells, each measured at `(column width, nil)`; a row with no cells is
   zero rows tall. Rows are adjacent.
4. **Height.** Grid reports the sum of its row heights. A finite height proposal never
   compresses a row: the parent clips trailing rows, and a grid that must scroll goes in a
   ScrollView (key B8).
5. **Placement.** Each cell is proposed its cell rectangle, the column's width by the
   row's height, and placed at that rectangle's top-leading corner at the size it reports;
   Grid never stretches a cell (key G7). A cell paints only inside its rectangle, so
   overflow never reaches the spacing or the next column. Each `GridRow` node's frame
   spans the grid's width and the row's height.

## Variants

| Configuration                                   | Behavior                                                                                                       |
| ----------------------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| `Grid(columns: cs) { ... }`                     | One column per constraint in `cs`; `spacing` defaults to 0.                                                    |
| `Grid(columns: cs, spacing: s) { ... }`         | `s` cells between adjacent columns, none before the first or after the last; rows stay adjacent.               |
| `GridRow { ... }` with one cell per column      | Cells fill the columns in source order.                                                                        |
| `GridRow { ... }` with fewer cells than columns | The row is valid; its trailing columns stay empty and have no node.                                            |
| `ForEach(items) { item in GridRow { ... } }`    | One row per element; each row keeps its identity by `ForEach` id (key A2).                                     |
| `.ratio(1, n)` for each of `n` columns          | Under a finite width `W`, equal tracks of `floor((W - s * (n - 1)) / n)` cells; the remainder is unused slack. |
| Negative `spacing`                              | Rejected by `precondition` before layout; never clamped.                                                       |

## Sizing

Schema: [README](../../design.md#sizing-table). The fixture is the Anatomy grid:
`[.length(6), .fill(1)]`, spacing 1, rows `Name`/`Tessera` and `State`/`ready to ship`.
The first column's cells measure 4 and 5 cells wide, so its fixed six cells hold both; the
second column's ideal is 13, from `ready to ship`, and its minimum is zero.

| Proposal  | Result | Rule                                                                                                                                              |
| --------- | ------ | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| nil x nil | 20x2   | Column ideals 6 and 13 plus one spacing cell; each row is one row tall at those widths.                                                           |
| 20x2      | 20x2   | A tight proposal matches the initial allocations, so no remainder is distributed.                                                                 |
| 14xnil    | 14x3   | The fill column compresses from 13 to 7 cells; `ready to ship` wraps into two rows, so the second row is two rows tall.                           |
| 5xnil     | 7x2    | Under the minimum, the `.length(6)` floor and the spacing cell stay, the fill column compresses to zero, and the parent clips the trailing cells. |
| 40x10     | 40x2   | Over the ideal, the fill column absorbs the 20 extra cells; extra height adds no rows.                                                            |
| 20x1      | 20x2   | A finite height never compresses a row; Grid reports both rows and the parent clips the second.                                                   |

## Allocation and diagnostics

| Grid, proposal, and rows                                                                             | Frames                                                                                                                    | Rule                                                                                                                                         |
| ---------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| Anatomy grid, `14xnil`                                                                               | rows: `(0,0) 14x1`, `(0,1) 14x2`; `Name: (0,0) 4x1`; `Tessera: (7,0) 7x1`; `State: (0,1) 5x1`; `ready to ship: (7,1) 7x2` | Cells sit at their cell's top-leading corner at their measured size. `paintOrder` is 0 and 1 for the rows, and 0 and 1 for each row's cells. |
| `[.length(6), .fill(1)]`, spacing 1, `nil x nil`: `Name`/`Tessera`, then `GridRow { Text("Notes") }` | rows: `(0,0) 14x1`, `(0,1) 14x1`; `Name: (0,0) 4x1`; `Tessera: (7,0) 7x1`; `Notes: (0,1) 5x1`                             | An incomplete row leaves column 1 empty, with no node; the column still measures `Tessera`.                                                  |
| `[.ratio(1, 3), .ratio(1, 3), .ratio(1, 3)]`, spacing 1, `21xnil`: `a`, `b`, `c`                     | row: `(0,0) 20x1`; `a: (0,0) 1x1`; `b: (7,0) 1x1`; `c: (14,0) 1x1`                                                        | The 19 cells left after spacing give three six-cell tracks; the leftover cell is unused, and Grid reports 20.                                |
| `[.length(4), .length(3)]`, `nil x nil`: `Text("Gopher").frame(width: 6)`, `X`                       | row: `(0,0) 7x1`; `Gopher: (0,0) 6x1`, painted in `(0,0) 4x1`; `X: (4,0) 1x1`                                             | A cell wider than its column keeps its measured size but paints only inside its cell: the row reads `GophX`.                                 |
| `[.length(6), .fill(1)]`, `9x1`, no rows                                                             | no child frames                                                                                                           | An empty grid reports `0x0` and paints nothing.                                                                                              |

Origins are relative to the grid's origin. `dump()` records each node's proposal, size,
frame, and `paintOrder`
([catalog layout decisions](../../spec.md#catalog-layout-decisions)); render visits rows
and then each row's cells in increasing `paintOrder`.

## Environment

Grid consumes no token and has no state model. It publishes no `stackAxis`, so a
[Divider](divider.md) in a cell follows Divider's own rule: the nearest enclosing linear
stack, else horizontal. Column widths, row heights, and cell rectangles are derived for
each layout pass and never stored (key D10).

## Requirements

- `grid reports column ideals plus spacing for an unconstrained proposal` (sizing: nil x
  nil)
- `grid matches a tight proposal without distributing a remainder` (sizing: 20x2)
- `grid resolves its columns once through the shared flex resolver` (sizing: 14xnil;
  anatomy: Second column)
- `a grid row is as tall as its tallest cell at the resolved widths` (sizing: 14xnil;
  anatomy: Second row)
- `grid keeps hard column floors and lets the parent clip trailing cells` (sizing: 5xnil)
- `a fill column absorbs a wider proposal` (sizing: 40x10)
- `grid never compresses a row under a finite height` (sizing: 20x1)
- `grid spacing separates columns without outer spacing` (anatomy: Spacing; variants:
  `Grid(columns: cs, spacing: s) { ... }`)
- `grid places each cell top-leading at its measured size` (allocation and diagnostics:
  Anatomy grid, `14xnil`; anatomy: Cell slack)
- `grid paints rows and cells in source order` (allocation and diagnostics: Anatomy grid,
  `14xnil`)
- `an incomplete grid row leaves its trailing columns empty` (allocation and diagnostics:
  `GridRow { Text("Notes") }` row; variants: fewer cells than columns)
- `equal ratio columns give equal tracks and leave the remainder unused` (allocation and
  diagnostics: `.ratio(1, 3)` row; variants: `.ratio(1, n)`)
- `grid clips a cell's overflow at its column edge` (allocation and diagnostics:
  `Text("Gopher").frame(width: 6)` row)
- `empty grid reports zero size and paints nothing` (allocation and diagnostics: no rows)
- `grid rejects negative spacing before layout` (variants: Negative `spacing`)
- `grid rows keep their identity across a keyed reorder` (variants:
  `ForEach(items) { item in GridRow { ... } }`)

## Degradation

Grid emits no cells and has no capability-dependent state. Glyph, width, colour, and ASCII
degradation remain each cell's responsibility. Column resolution, row heights, clipping,
and source order are identical at every tier of the
[degradation ladder](../tokens.md#degradation-ladder).

## Decisions

Each decision cites the written source that settles it.

- **API and row grouping.** [Slice 6](../../spec.md#slice-6-grid-table-and-fitting) fixes
  `Grid(columns:spacing:content:)` and `GridRow`: rows group cells, `columns.count` makes
  the column count explicit, and rows keep structural or `ForEach` identity (key A2).
  `GridRow` takes only its cells.
- **Spacing separates columns.** Columns resolve through Flex, whose `spacing` is
  main-axis only ([Slice 6](../../spec.md#slice-6-grid-table-and-fitting);
  [Flex](flex.md#constraint-resolution)), and omp2's grid gap also separates columns only,
  which key B4 makes `spacing:`. Rows are adjacent; whether they gain spacing is an open
  question.
- **No alignment controls in 1.0.**
  [Slice 6](../../spec.md#slice-6-grid-table-and-fitting)'s initializer takes none, and
  terminal layout reads top-leading
  ([catalog layout decisions](../../spec.md#catalog-layout-decisions)). A cell keeps its
  measured size at its top-leading corner (key G7) and aligns its own content with Spacers
  (key B4): `HStack { Spacer(); Text("42") }` fills its column and right-aligns the
  number.
- **Column constraints live on Grid.** omp2 reads `w`, `min`, `max`, and `grow` from each
  cell; Tessera declares one `FlexConstraint` per column in `columns:` (key B2), and
  `w=40%` is `.percentage(40)` (key G8). A cell's `.flex(_:)` value does not change its
  column.
- **No spanning in v1** ([Slice 6](../../spec.md#slice-6-grid-table-and-fitting)).
- **Rows are never compressed.** [Slice 6](../../spec.md#slice-6-grid-table-and-fitting)
  defines a row's height only by its cells at their resolved widths, so a height proposal
  does not change it; a taller grid clips, or scrolls in a ScrollView (key B8).
- **Empty and incomplete geometry.** An empty grid reports `0x0` and paints nothing, as
  empty [stacks](stacks.md#allocation-fixtures), [Flex](flex.md#remainder-and-priority),
  and [ZStack](z-stack.md#variants) do. A missing cell has no node, each `GridRow` node
  spans the grid's width and its row's height, and `dump()` shows both
  ([catalog layout decisions](../../spec.md#catalog-layout-decisions)).
- **Equal tracks come from Flex.** `.ratio(1, n)` columns give equal integer tracks with
  unused trailing slack under a finite width, by Flex's normative resolver, which answers
  the equal-column note in [inbox.md](../inbox.md) without a Grid-specific API.

Reviewed against the
[Phase 4 theses](../../spec.md#phase-4--view-layer-the-tessera-module): Grid and `GridRow`
are value descriptions lowered to layout nodes, column resolution and row heights are
deterministic integer math that `dump()` shows, Grid holds no state, and it touches no
terminal capability.

## Open questions

These need the owner's answer before Grid can be `ready`; none has a written answer in the
Spec, the translation key, or the catalog.

1. **Extra cells.** What does a `GridRow` with more cells than `columns.count` do: leave
   the extras unplaced (a zero rect in `dump()`, as the
   [Slice 2 placement contract](../../spec.md#the-protocol) hides an unplaced subview),
   wrap them onto a new row, or fail? An empty `columns` array is the limit case.
2. **Bare children.** What does a direct child of `Grid` that is not a `GridRow` do:
   become a one-cell row in the first column, span the full width as in SwiftUI (spanning,
   which [Slice 6](../../spec.md#slice-6-grid-table-and-fitting) leaves out of v1), or
   fail?
3. **GridRow outside a Grid.** Does it lay out like an `HStack`, as in SwiftUI, or is it
   an error?
4. **Row spacing.** [Slice 6](../../spec.md#slice-6-grid-table-and-fitting) gives one
   `spacing:`, read here as column spacing because columns resolve through Flex. Should
   rows take the same spacing, gain a separate row spacing (SwiftUI's `verticalSpacing`),
   or stay adjacent as specified here?
5. **Cell priority.** Should `.layoutPriority(_:)` on a cell lift its column into a higher
   growth and compression tier (for example, the highest priority among the column's
   cells), or does Grid ignore cell priority, as ZStack does?

## Inspiration

- A settings list or key-value panel whose labels share the width of the widest label: one
  Grid replaces padding each label by hand, which is how omp2's Fact rows and Form labels
  line up.
- Equal-width chips or dashboard tiles from `.ratio(1, n)` columns.
