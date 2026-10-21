---
kind: widget
status: specified
---

# Table

A columnar, selectable, scrollable data view: List's structured sibling. Controlled
throughout, per
[Slice 7](../../docs/Spec.md#slice-7-catalog-integration--list-section-controlled-widgets-and-the-showcase):
the app supplies immutable data, selection, and sort order; selection and sort order use
bindings, while Table derives rows from its data input on every update. Table owns only
view state in `NodeState`: a scroll offset, a cursor row (multi-select), and a header
cursor (keyboard sorting; owner decision, 2026-10-10). Table renders chrome (header, rule,
selection, scrollbar, and the optional frame of a table style) but never invents data,
selection, or ordering.

Provisional API shape (vocabulary, not a commitment):

```swift
public struct Table<Data: RandomAccessCollection, ID: Hashable, ColumnID: Hashable>: View
where Data.Element: Identifiable, Data.Element.ID == ID {
    /// Single selection: `selection` is the selected row's ID, or nil.
    public init(
        _ data: Data,
        selection: Binding<ID?>,
        sortOrder: Binding<[TableSortOrder<ColumnID>]>? = nil,
        columns: [TableColumn<Data.Element, ColumnID>],
        onActivate: ((Data.Element) -> Void)? = nil
    )

    /// Multi-select (owner decision, 2026-10-10): `selection` is the membership set; the
    /// cursor row and header cursor live in NodeState.
    public init(
        _ data: Data,
        selection: Binding<Set<ID>>,
        sortOrder: Binding<[TableSortOrder<ColumnID>]>? = nil,
        columns: [TableColumn<Data.Element, ColumnID>],
        onActivate: ((Data.Element) -> Void)? = nil
    )
}

public struct TableColumn<Element, ColumnID: Hashable> {
    public let id: ColumnID   // sort identity; the title is display text only
    public let title: String
    /// Rows a cell in this column may take. Default 1: one row that tail-truncates.
    /// `nil` wraps every row the cell needs; `n` caps the cell at `n` rows and marks the
    /// last visible row. Header cells are always one row.
    public func lineLimit(_ limit: Int?) -> TableColumn
}

public struct TableSortOrder<ColumnID: Hashable> {
    public var column: ColumnID
    public var ascending: Bool
}
```

## Prior art

- Ratatui `Table`: `~/Developer/ratatui/ratatui/main/ratatui-widgets/src/table.rs` -- copy
  the column-constraint vocabulary (fixed / min / fill) and the highlight-selected-row
  rendering; reject the stateful-`TableState`-passed-by-hand ergonomics, which Tessera
  replaces with bindings plus `NodeState`.
- Bubbles `table` -- good interaction feel for keyboard navigation; reject its ownership
  model (the widget owns rows and cursor), which is exactly the coupling the controlled
  rule exists to prevent.
- SwiftUI `Table` -- copy the `TableColumn` + `sortOrder` binding vocabulary and the
  `.tableStyle(_:)` modifier shape; reject its macOS-scale feature set for v1, except
  multi-select, which is designed here (Multi-select and keyboard sorting) with `Set<ID>`
  as its binding. Column reordering stays out. Sort entries name a column identity, not a
  title or a comparator over `Element`.
- omp2 `Table` (`crates/tui/src/components/table.rs`): grid-aligned columns with row bands
  and an optional overflow footer. It draws no header row, rules, or borders, and its
  inventory entry lists no selection or sorting, so `.bordered`, `.grid`, the header rule,
  and sorting are Tessera additions. Struct and doc:
  <https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/table.rs#L20-L38>
- omp2 cell truncation (`table.rs#L281-L330`): clips a flattened cell at its edge with
  `…`. In omp2's 20-column truncation capture the cut text carried a column-gap space
  inside the cut (the file names `table.rs` and `tree.rs` came out split by a space), so
  the cut spilled past the cell's own column. Tessera contains each cut inside its own
  column (anatomy callout 6; Requirements):
  <https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/table.rs#L281-L330>
- omp2 Markdown tables (`crates/tui/src/markdown/mod.rs`): a recognised pipe table renders
  as a full box-bordered grid with per-column alignment, and ASCII uses `+`, `-`, `|`. The
  delimiter needs at least three dashes (`table_alignment`,
  <https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/markdown/mod.rs#L1529-L1541>),
  and header and delimiter need equal cell counts (`table_header`,
  <https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/markdown/mod.rs#L1467-L1474>).
  Tessera's Markdown tables reuse this renderer in the `grid` style, matching omp2's
  full-grid Markdown table.
- Scrollbar geometry: `~/Developer/ratatui/ratatui/main/ratatui-widgets/src/scrollbar.rs`.

## Anatomy

The anatomy is the `plain` style, the default. The other styles are under Styles.

```wireframe 46x9
 Name              Size  Modified
──────────────────────────────────────────────
 Spec.md         372 KB  2026-07-06          ┃
▌Package.swift    12 KB  2026-07-01          ┃
 README.md       2.6 KB  2026-06-28          ┃
 CHANGELOG.md    8.8 KB  2026-06-28          │
 CONTRIBUTING…    13 KB  2026-06-27          │
 LICENSE         1.1 KB  2026-06-20          │
 row 2 of 12
```

```text
Callouts (46x9, 0-based):
1. r0       Header row -- Text per column, `primary` plus bold by default;
            `TableStyle` may override; pinned, never scrolls; chrome, one row
2. r0 c1    Header cell -- one per column; click target for sorting; chrome, one row
3. r1       Header rule -- Divider, token `divider.light`, full width
4. r3 c0    Selection bar -- `selection.bar` in `accent` when focused, `secondary` when
            unfocused; row also gets `selection.fill`; the bar cell takes the fill when
            derived; where `selection.fill` is reverse video (slots, indexed256, NO_COLOR)
            the bar draws on the terminal background and the fill starts at the next cell
            ([selection](../tokens.md#selection); owner decision, 2026-10-19)
5. r2-r7    Data row -- one row per visible element here (every cell single-line); 6 of
            12 visible; cells are content, one row (wrap exception)
6. r6 c14   Truncation -- Text `tail` policy, `truncation.mark` (`…`; ASCII `~`),
            grapheme-safe, cut inside the cell's own column
7. c45      Scrollbar -- output-only ScrollIndicator; track `border`, thumb `accent`
            (ScrollIndicator presets;
            [scroll indicators](../tokens.md#scroll-indicators)),
            thumb = max(1, floor(6x6/12)) = 3 of 6, counted in rows
8. r8       Footer -- app-provided slot, NOT Table chrome (owner decision, 2026-10-10)
9. r4       Hover (not drawn in this fixture) -- on by default; the row under the pointer
            takes `hover` (12%, [fill roles](../tokens.md#fill-roles)); its row label (the
            leading Name cell) is underlined where no fill is drawn (slots, NO_COLOR,
            16-colour); a selected row keeps `selection.fill` under the pointer
```

> Wrap exception (rule 1): cells are single-line by default, the spreadsheet idiom that
> keeps columns scannable. A column opts in with `TableColumn(...).lineLimit(nil)`; row
> height is then its tallest cell. (owner decision, 2026-10-18)

Table pins `lineLimit(1)` on header cells and on the cells of every column that has not
opted in, so an app's inherited `lineLimit` never changes the rows. The header row is
always one row and tail-truncates. See [Wrapped columns](#wrapped-columns).

Region names for the mouse table: header row, header cell, data row, selection bar (part
of data row), mark gutter (part of data row; multi-select only), scrollbar.

## Styles

Owner decision, omp2 review, 2026-10: `plain` is the default; `bordered` and `grid` ship
as options. `.alternatingRowBackgrounds()` is a separate modifier, not a style, so it
applies to every style. Markdown tables render through this same renderer in the `grid`
style, so there is one table renderer, not two.

Borders use the shared border sets: `light` by default, with the `ascii` set (`+`, `-`,
`|`) under degradation. A bordered table takes the box focus rules on its outer border
([Focus border](../primitives/border.md#focus-border), rule 5): the heavy set in the
`focus` role when the table itself has focus, `light` weight in the `focus` role when
focus is inside it, and bold under ASCII. Heavy and double sets keep their weight and
change colour only.

The header rule of `plain` is a Divider; in `bordered` and `grid` the header rule and row
rules are border-set lines joined into the frame.

```swift
extension View {
    /// `.plain` (default), `.bordered`, `.grid`; set on a Table and read from Environment.
    public func tableStyle(_ style: TableStyle) -> some View
    /// Stripes every second data row, starting with the second; applies to every style.
    public func alternatingRowBackgrounds() -> some View
}

public struct TableStyle: Sendable {
    public static let plain: TableStyle
    public static let bordered: TableStyle
    public static let grid: TableStyle
}
```

### Plain (default)

Data rows with a header rule and no frame. Four rows fit, so no scrollbar is drawn.

```wireframe 40x6
 Name                    Size   Modified
────────────────────────────────────────
 Spec.md               372 KB 2026-07-06
▌Package.swift          12 KB 2026-07-01
 README.md             2.6 KB 2026-06-28
 CHANGELOG.md          8.8 KB 2026-06-28
```

```text
Callouts (40x6, 0-based):
1. r0       Header row -- Text per column, `primary` plus bold; no rule
            above it; pinned, never scrolls
2. r1       Header rule -- Divider, token `divider.light`; the only rule in plain
3. r3 c0    Selection bar -- `selection.bar` in `accent` when focused, `secondary` when
            unfocused; row also gets `selection.fill`; the bar cell takes the fill when
            derived; where `selection.fill` is reverse video (slots, indexed256, NO_COLOR)
            the bar draws on the terminal background and the fill starts at the next cell
            ([selection](../tokens.md#selection); owner decision, 2026-10-19)
4. r2-r5    Data rows -- all four rows fit, so no ScrollIndicator is drawn
```

```text
── chars ──
 Name                    Size   Modified
────────────────────────────────────────
 Spec.md               372 KB 2026-07-06
▌Package.swift          12 KB 2026-07-01
 README.md             2.6 KB 2026-06-28
 CHANGELOG.md          8.8 KB 2026-06-28
── style ──
.HHHH....................HHHH...HHHHHHHH
DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD
.PPPPPPP...............PPP.PP.PPPPPPPPPP
BSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS
.PPPPPPPPP.............PPP.PP.PPPPPPPPPP
.PPPPPPPPPPPP..........PPP.PP.PPPPPPPPPP
── legend ──
.  default
H  fg=primary bold
D  fg=border
P  fg=primary
S  fg=primary bg=selection.fill
B  fg=accent bg=selection.fill
```

### Bordered

An outer frame, column separators, and a header rule joined into the frame. No rules
between rows, so the table stays dense. The selection is the fill alone: the left border
takes the bar's column.

```wireframe 40x8
┌───────────────┬─────────┬────────────┐
│ Name          │    Size │ Modified   │
├───────────────┼─────────┼────────────┤
│ Spec.md       │  372 KB │ 2026-07-06 │
│ Package.swift │   12 KB │ 2026-07-01 │
│ README.md     │  2.6 KB │ 2026-06-28 │
│ CHANGELOG.md  │  8.8 KB │ 2026-06-28 │
└───────────────┴─────────┴────────────┘
```

```text
Callouts (40x8, 0-based):
1. r0, r7   Border -- shared `light` set (`┌┐└┘`, `─`, `│`), unfocused; focus rules
            apply to this ring (see Styles)
2. r1       Header row -- as plain: bold `primary`, pinned
3. r2       Header rule -- `├ ┼ ┤` on the border set, joined into the frame; junction
            glyphs use the `border` role (see [border sets](../tokens.md#border-sets))
4. r0 c16, r0 c26, r7 c16, r7 c26 -- `┬` and `┴` where the column separators meet
            the top and bottom edges; same junction, `border` role
5. r4 c1-c15 Selection fill -- `selection.fill` on the cell interiors; no bar, because
            the left border occupies the bar's column
6. r3-r6    Data rows -- all four rows fit, so no ScrollIndicator is drawn
7. c0, c16, c26, c39 -- `│` column separators and side borders, border role
```

```text
── chars ──
┌───────────────┬─────────┬────────────┐
│ Name          │    Size │ Modified   │
├───────────────┼─────────┼────────────┤
│ Spec.md       │  372 KB │ 2026-07-06 │
│ Package.swift │   12 KB │ 2026-07-01 │
│ README.md     │  2.6 KB │ 2026-06-28 │
│ CHANGELOG.md  │  8.8 KB │ 2026-06-28 │
└───────────────┴─────────┴────────────┘
── style ──
DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD
DHHHHHHHHHHHHHHHDHHHHHHHHHDHHHHHHHHHHHHD
DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD
DPPPPPPPPPPPPPPPDPPPPPPPPPDPPPPPPPPPPPPD
DSSSSSSSSSSSSSSSDSSSSSSSSSDSSSSSSSSSSSSD
DPPPPPPPPPPPPPPPDPPPPPPPPPDPPPPPPPPPPPPD
DPPPPPPPPPPPPPPPDPPPPPPPPPDPPPPPPPPPPPPD
DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD
── legend ──
.  default
H  fg=primary bold
D  fg=border
P  fg=primary
S  fg=primary bg=selection.fill
```

### Grid

A bordered table with a rule between every row, which is what omp2's Markdown tables look
like. It takes twice the height, so it suits short reference tables rather than long
scrolling lists.

```wireframe 40x11
┌───────────────┬─────────┬────────────┐
│ Name          │    Size │ Modified   │
├───────────────┼─────────┼────────────┤
│ Spec.md       │  372 KB │ 2026-07-06 │
├───────────────┼─────────┼────────────┤
│ Package.swift │   12 KB │ 2026-07-01 │
├───────────────┼─────────┼────────────┤
│ README.md     │  2.6 KB │ 2026-06-28 │
├───────────────┼─────────┼────────────┤
│ CHANGELOG.md  │  8.8 KB │ 2026-06-28 │
└───────────────┴─────────┴────────────┘
```

```text
Callouts (40x11, 0-based):
1. r0, r10  Border -- shared `light` set, unfocused; focus rules apply to this ring
2. r1       Header row -- bold `primary`, pinned
3. r2       Header rule -- `├ ┼ ┤`, joined into the frame
4. r4, r6, r8 Row rules -- one between every pair of rows; junctions on the border set
5. r5 c1-c15 Selection fill -- `selection.fill` on the cell interiors; no bar
6. r3-r9    Data rows -- all four rows fit, so no ScrollIndicator is drawn
7. c16, c26 Column separators -- `│` between cells; `┼` where they meet a row rule
```

```text
── chars ──
┌───────────────┬─────────┬────────────┐
│ Name          │    Size │ Modified   │
├───────────────┼─────────┼────────────┤
│ Spec.md       │  372 KB │ 2026-07-06 │
├───────────────┼─────────┼────────────┤
│ Package.swift │   12 KB │ 2026-07-01 │
├───────────────┼─────────┼────────────┤
│ README.md     │  2.6 KB │ 2026-06-28 │
├───────────────┼─────────┼────────────┤
│ CHANGELOG.md  │  8.8 KB │ 2026-06-28 │
└───────────────┴─────────┴────────────┘
── style ──
DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD
DHHHHHHHHHHHHHHHDHHHHHHHHHDHHHHHHHHHHHHD
DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD
DPPPPPPPPPPPPPPPDPPPPPPPPPDPPPPPPPPPPPPD
DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD
DSSSSSSSSSSSSSSSDSSSSSSSSSDSSSSSSSSSSSSD
DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD
DPPPPPPPPPPPPPPPDPPPPPPPPPDPPPPPPPPPPPPD
DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD
DPPPPPPPPPPPPPPPDPPPPPPPPPDPPPPPPPPPPPPD
DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD
── legend ──
.  default
H  fg=primary bold
D  fg=border
P  fg=primary
S  fg=primary bg=selection.fill
```

### Striped (alternating rows, plain)

`.alternatingRowBackgrounds()` on the default style. Owner decision, 2026-10-10: the
stripe is the `surface` role (8%) on every second data row. Hover and stripes coexist: a
hovered striped row shows `hover` (12%) over its stripe (owner decision, 2026-10-19). The
selected row keeps `selection.fill` over both, so the stripe is hidden under it. Under
NO_COLOR the stripe is dropped (see Degradation).

```wireframe 40x6
 Name                    Size   Modified
────────────────────────────────────────
 Spec.md               372 KB 2026-07-06
▌Package.swift          12 KB 2026-07-01
 README.md             2.6 KB 2026-06-28
 CHANGELOG.md          8.8 KB 2026-06-28
```

```text
Callouts (40x6, 0-based):
1. r0       Header row -- as plain
2. r1       Header rule -- Divider, token `divider.light`
3. r3 c0    Selection bar -- `selection.bar` in `accent` (focused) / `secondary`
            (unfocused); the row gets `selection.fill`, which replaces the stripe on this
            row; the bar cell takes the fill when derived; where `selection.fill` is
            reverse video the bar draws on the terminal background and the fill starts at
            the next cell ([selection](../tokens.md#selection))
4. r2, r4   Data rows -- no stripe (first and third data rows)
5. r3, r5   Stripe -- `surface` (8%) background on the second and fourth data rows; a
            hovered stripe row shows `hover` instead; dropped under NO_COLOR
```

```text
── chars ──
 Name                    Size   Modified
────────────────────────────────────────
 Spec.md               372 KB 2026-07-06
▌Package.swift          12 KB 2026-07-01
 README.md             2.6 KB 2026-06-28
 CHANGELOG.md          8.8 KB 2026-06-28
── style ──
.HHHH....................HHHH...HHHHHHHH
DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD
.PPPPPPP...............PPP.PP.PPPPPPPPPP
BSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS
.PPPPPPPPP.............PPP.PP.PPPPPPPPPP
ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ
── legend ──
.  default
H  fg=primary bold
D  fg=border
P  fg=primary
S  fg=primary bg=selection.fill
B  fg=accent bg=selection.fill
Z  fg=primary bg=surface
```

### Bordered striped

`.bordered` with `.alternatingRowBackgrounds()`. Same frame and selection rules as
Bordered; the stripe covers the whole interior of the striped row, not the separators.

```wireframe 40x8
┌───────────────┬─────────┬────────────┐
│ Name          │    Size │ Modified   │
├───────────────┼─────────┼────────────┤
│ Spec.md       │  372 KB │ 2026-07-06 │
│ Package.swift │   12 KB │ 2026-07-01 │
│ README.md     │  2.6 KB │ 2026-06-28 │
│ CHANGELOG.md  │  8.8 KB │ 2026-06-28 │
└───────────────┴─────────┴────────────┘
```

```text
Callouts (40x8, 0-based):
1. r0, r7   Border -- shared `light` set, unfocused; focus rules apply to this ring
2. r1       Header row -- as plain: bold `primary`, pinned
3. r2       Header rule -- `├ ┼ ┤`, joined into the frame
4. r4 c1-c15 Selection fill -- `selection.fill` on the second data row, which is also
            a stripe row; selection wins over the stripe
5. r6 c1-c15 Stripe -- `surface` background on the fourth data row; the column separators
            keep the border role; dropped under NO_COLOR
6. r3-r6    Data rows -- all four rows fit, so no ScrollIndicator is drawn
```

```text
── chars ──
┌───────────────┬─────────┬────────────┐
│ Name          │    Size │ Modified   │
├───────────────┼─────────┼────────────┤
│ Spec.md       │  372 KB │ 2026-07-06 │
│ Package.swift │   12 KB │ 2026-07-01 │
│ README.md     │  2.6 KB │ 2026-06-28 │
│ CHANGELOG.md  │  8.8 KB │ 2026-06-28 │
└───────────────┴─────────┴────────────┘
── style ──
DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD
DHHHHHHHHHHHHHHHDHHHHHHHHHDHHHHHHHHHHHHD
DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD
DPPPPPPPPPPPPPPPDPPPPPPPPPDPPPPPPPPPPPPD
DSSSSSSSSSSSSSSSDSSSSSSSSSDSSSSSSSSSSSSD
DPPPPPPPPPPPPPPPDPPPPPPPPPDPPPPPPPPPPPPD
DZZZZZZZZZZZZZZZDZZZZZZZZZDZZZZZZZZZZZZD
DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD
── legend ──
.  default
H  fg=primary bold
D  fg=border
P  fg=primary
S  fg=primary bg=selection.fill
Z  fg=primary bg=surface
```

## Wrapped columns

A column opts in to wrapping with `TableColumn.lineLimit(_:)` (owner decision,
2026-10-18); every other column stays single-line. The opt-in is per column, so the
columns you scan down keep their one-row cells while a prose column such as a description
shows all of its text.

```swift
// `selection` is a Binding from the app's model.
Table(files, selection: selection, columns: [
    TableColumn(id: .name, title: "Name"),
    TableColumn(id: .size, title: "Size"),
    TableColumn(id: .description, title: "Description").lineLimit(nil),
])
```

The 40-column fixture below gives Name 13 cells, Size 6, and Description 18 (a `fill`
column), with the selected row in the middle. Description wraps at its 18 cells; the other
cells are one row, top-aligned in the first row of their data row.

```wireframe 40x12
 Name            Size Description
────────────────────────────────────────
 Spec.md       372 KB The constitution:
                      architecture and
                      the layout
                      protocol
▌Package.swift  12 KB Targets, products,
▌                     and dependencies
 README.md     2.6 KB Start here
 CHANGELOG.md  8.8 KB Release notes,
                      newest first
 LICENSE       1.1 KB MIT
```

```text
Callouts (40x12, 0-based):
1. r0 c1-c32   Header row -- chrome, one row; the wrapped column's header stays one row
2. r1          Header rule -- Divider, token `divider.light`
3. r2-r5       Data row -- four rows tall: its tallest cell is Description
4. r2 c1-c7    Name cell -- content, one row (wrap exception); top-aligned, rows below blank
5. r2 c15-c20  Size cell -- content, one row (wrap exception); right-aligned, top-aligned
6. r2-r5 c22-c39  Description cell -- content, wraps at the column's 18 cells
7. r6-r7 c0    Selection bar -- `selection.bar` on every row of the selected data row; both
               rows also get `selection.fill` across c0-c39; the bar cell takes the fill
               when derived; where `selection.fill` is reverse video the bar draws on the
               terminal background and the fill starts at the next cell
               ([selection](../tokens.md#selection))
8. r8          Data row -- one row; the short description needs no wrap
9. r9-r10      Data row -- two rows tall
10. r11        Data row -- one row
```

Rules for a wrapped column:

- **Height.** A data row is as tall as its tallest cell, and never shorter than one row.
  `lineLimit(nil)` gives every row the cell needs; `lineLimit(n)` caps the cell at `n`
  rows, and the last visible row ends in `…` (ASCII `~`) per
  [Text's row budget](../primitives/text.md#row-budget). Cells that are shorter than the
  row leave blank rows below their text.
- **Width.** The column solver is unchanged: `fixed`, `min`, `fill`. A wrapped column
  usually takes `fill` so it absorbs the slack. A nil width proposal does not wrap, so
  such a column keeps its unwrapped ideal width.
- **Narrow tables.** Dropping columns by priority is unchanged (owner decision,
  2026-10-18): a wrapped column does not change the drop order. It wraps at whatever width
  the surviving columns leave it, breaking a word between graphemes only when the word is
  wider than the column.
- **Selection.** The bar, the fill, and the multi-select cursor bar cover every row of a
  data row. The member mark `●` sits on the first row only. A stripe covers every row.
- **Frames.** In `bordered` and `grid` the column separators and side borders run down
  every row of a tall data row. `grid`'s row rules sit between data rows, never inside
  one.
- **Scrolling.** The offset, the thumb, and paging count rows, per
  [ScrollView's contract](scroll-view.md#rows-and-variable-height-content): a data row cut
  by the top or bottom edge draws its visible rows, with no truncation mark, and a
  selection move reveals the fewest rows that show the whole data row.
- **Header.** The header row stays one row. Its cells tail-truncate, and a sort mark keeps
  its place.

## States

Mobile (40 columns at natural height, 40x14): the Modified column is dropped by column
priority; Name gets the slack. All 12 rows fit at natural height, so no ScrollIndicator
and no footer are drawn (owner decision, 2026-10-10: components are wireframed at natural
height; mobile means 40 columns, not a padded frame). Column priority is a Tessera
addition (see Prior art).

```wireframe 40x14
 Name                               Size
────────────────────────────────────────
 Spec.md                          372 KB
▌Package.swift                     12 KB
 README.md                        2.6 KB
 CHANGELOG.md                     8.8 KB
 CONTRIBUTING.md                   13 KB
 LICENSE                          1.1 KB
 CODE_OF_CONDUCT.md               5.3 KB
 Brewfile                          531 B
 Justfile                          721 B
 a-very-long-filename-example-v…  4.2 KB
 WindowsFrostVM.md               13.5 KB
 LocalDevelopmentState.md         4.6 KB
```

Min (24x5, the declared floor): only the highest-priority column survives; below this
width Table renders truncated single-column rows rather than failing. Cells are
single-line, so the floor is not re-derived from whole words (wrap exception); a surviving
column that opted in to wrapping wraps inside the width, breaking a word between graphemes
when it is wider than the column.

```wireframe 24x5
 Name
────────────────────────
▌Package.swift         ┃
 README.md             │
 row 2 of 12
```

Empty (46x3 at natural height, owner decision, 2026-10-10): header and rule stay; the body
is one row showing the app-provided empty message (default "No files" here), centered.

```wireframe 46x3
 Name                          Size   Modified
──────────────────────────────────────────────
                   No files
```

Degraded ascii/no-color (46x6): geometry identical, glyphs swapped per the
[degradation ladder](../tokens.md#degradation-ladder). Unfocused looks the same but uses
`selection.inactive` instead of `selection.fill`.

```wireframe 46x6
 Name              Size  Modified
----------------------------------------------
 Spec.md         372 KB  2026-07-06          #
>Package.swift    12 KB  2026-07-01          #
 README.md       2.6 KB  2026-06-28          |
 row 2 of 12
```

## State model

| State                 | Owner       | Type                                                | Reset or clamp rule                                                                                                                                                                                                                                                                                                                                                                           |
| --------------------- | ----------- | --------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| rows                  | derived     | immutable `Data` (RandomAccessCollection)           | recomputed from the data input on every update; never stored or bound                                                                                                                                                                                                                                                                                                                         |
| row heights           | derived     | `[Int]` (rows per data row)                         | a row is as tall as its tallest cell: 1 unless a column opted in to wrapping with `lineLimit(_:)`, then the rows that cell needs, capped by the limit; re-measured whenever column widths change; never stored                                                                                                                                                                                |
| selection mode        | derived     | single or multi                                     | multi when the `Set<ID>` initializer is used, single when the `ID?` initializer is used; never stored                                                                                                                                                                                                                                                                                         |
| selection             | Binding     | `Element.ID?` (single) or `Set<Element.ID>` (multi) | Table never invents a value; if an ID vanishes from data, selection renders nowhere but the binding is not mutated; a vanished multi-select ID stays in the set                                                                                                                                                                                                                               |
| cursor                | NodeState   | `Int?` (row index; multi-select only)               | nil until a cursor key or click; clamped to `0..<count` on every update; nil when data is empty; cursor moves never write the selection binding                                                                                                                                                                                                                                               |
| header mode           | derived     | `Bool`                                              | true while the header cursor is set; never stored                                                                                                                                                                                                                                                                                                                                             |
| header cursor         | NodeState   | `Int?` (column index)                               | set by Ctrl-↑ to the first column; clamped to the first and last column on every update; cleared by ↑, ↓, Esc, or focus loss                                                                                                                                                                                                                                                                  |
| sort order            | Binding     | `[TableSortOrder<ColumnID>]?`                       | keyed by column identity, not title; Table marks the header of each named column with its direction, and the app re-sorts data itself; an entry naming no column ID is ignored and the binding is not mutated; header Space and header click write the binding on user action only                                                                                                            |
| sort marks            | derived     | `↑`, `↓` (ASCII `^`, `v`)                           | drawn on each header whose column ID has an entry in the sort order binding; never stored                                                                                                                                                                                                                                                                                                     |
| scroll offset         | NodeState   | `Int` (content rows above the viewport)             | counts rows, not data rows, so a partly visible row at either edge draws its visible rows; clamps to `0...maximum scroll offset` on every update, including after a width change re-wraps cells; keeps the cursor or selection visible after cursor- or selection-moving keys by the fewest rows that show every row of it (a row taller than the viewport aligns its first row with the top) |
| maximum scroll offset | derived     | `Int`                                               | recomputed as `max(0, C - V)` for C content rows (the sum of row heights) and V viewport rows on every update and layout pass; never stored                                                                                                                                                                                                                                                   |
| column widths         | derived     | `[Int]`                                             | recomputed per layout pass from column policy; never stored                                                                                                                                                                                                                                                                                                                                   |
| column line limit     | derived     | `Int?` per column                                   | read from the column declaration on every update: 1 unless the column opted in with `TableColumn.lineLimit(_:)`; nil wraps every row, n caps the cell at n rows; header cells are always 1; never stored                                                                                                                                                                                      |
| table style           | Environment | `TableStyle` (`plain`, `bordered`, `grid`)          | default `plain`; set by `.tableStyle(_:)`; a style never changes rows, selection, or scroll offset                                                                                                                                                                                                                                                                                            |
| alternating rows      | Environment | `Bool`                                              | set by `.alternatingRowBackgrounds()`; applies to every style; the selected row keeps `selection.fill` over the stripe                                                                                                                                                                                                                                                                        |
| header styling        | Environment | `primary` plus bold                                 | default header style; `TableStyle` may override                                                                                                                                                                                                                                                                                                                                               |
| selection style       | Environment | `selection.*` tokens                                | active (`selection.bar`, `selection.fill`) when focused and not in header mode; `selection.inactive` for the row in header mode; header cursor cell uses `selection.fill` in header mode                                                                                                                                                                                                      |
| hovered row           | derived     | `Int?` (row index under the pointer)                | set from motion while the table is on screen; cleared on leave or unmount; never stored in NodeState or a binding; a selected row keeps `selection.fill` under the pointer                                                                                                                                                                                                                    |
| hover enabled         | Environment | `Bool`                                              | on by default; `.rowHover(.disabled)` placeholder opts out (owner decision, 2026-10-19)                                                                                                                                                                                                                                                                                                       |

The "selection ID vanished" rule is this widget's version of Slice 7's mandatory "app
mutated data under the widget" case: Table must render sanely and must not write to the
binding to "fix" it -- the app owns that decision. The sort-order rule follows the same
pattern: an unknown column ID changes nothing and the app owns the sort decision.

The scroll offset and both keyboard cursors have exactly one runtime owner. If `Table` is
implemented as a `LeafView`, keyboard and mouse handling use `LeafView.handleEvent` and
the same `NodeState` read by layout and rendering. The implementation must not mirror the
offset into `_ResponderView.ResponderState` or transfer it between independent stores
during a graph update.

## Key table

| Key    | Precondition                                     | Effect                                                                                          | Consumed |
| ------ | ------------------------------------------------ | ----------------------------------------------------------------------------------------------- | -------- |
| ↓      | focused, single-select                           | moves selection to next row via binding                                                         | yes      |
| ↑      | focused, single-select                           | moves selection to previous row via binding                                                     | yes      |
| PgDn   | focused, single-select                           | moves selection down one viewport of rows via binding                                           | yes      |
| PgUp   | focused, single-select                           | moves selection up one viewport of rows via binding                                             | yes      |
| Home   | focused, single-select                           | moves selection to first row via binding                                                        | yes      |
| End    | focused, single-select                           | moves selection to last row via binding                                                         | yes      |
| Enter  | focused, single-select, selection is set         | calls `onActivate` with the selected element                                                    | yes      |
| ↓      | focused, single-select, selection not set        | sets selection to first visible row via binding                                                 | yes      |
| ↓      | focused, multi-select, cursor is set             | moves cursor to next row; membership unchanged                                                  | yes      |
| ↑      | focused, multi-select, cursor is set             | moves cursor to previous row; membership unchanged                                              | yes      |
| PgDn   | focused, multi-select, cursor is set             | moves cursor down one viewport of rows; membership unchanged                                    | yes      |
| PgUp   | focused, multi-select, cursor is set             | moves cursor up one viewport of rows; membership unchanged                                      | yes      |
| Home   | focused, multi-select, cursor is set             | moves cursor to first row; membership unchanged                                                 | yes      |
| End    | focused, multi-select, cursor is set             | moves cursor to last row; membership unchanged                                                  | yes      |
| ↓      | focused, multi-select, cursor not set            | sets cursor to first visible row; membership unchanged                                          | yes      |
| Space  | focused, multi-select, cursor is set             | toggles the cursor row's membership via binding; cursor stays                                   | yes      |
| Enter  | focused, multi-select, cursor is set             | calls `onActivate` with the cursor row                                                          | yes      |
| Ctrl-↑ | focused, sort order binding set, not header mode | enters header mode; header cursor set to the first column                                       | yes      |
| ←      | header mode                                      | moves header cursor to previous column, clamped at the first column                             | yes      |
| →      | header mode                                      | moves header cursor to next column, clamped at the last column                                  | yes      |
| Space  | header mode                                      | cycles the header cursor column's sort entry through ascending, descending, removed via binding | yes      |
| ↑      | header mode                                      | leaves header mode; header cursor cleared                                                       | yes      |
| ↓      | header mode                                      | leaves header mode; header cursor cleared                                                       | yes      |
| Esc    | header mode                                      | leaves header mode; header cursor cleared                                                       | yes      |

Every cursor- or selection-moving key also updates the `NodeState` scroll offset per its
clamp rule so the moved row stays visible. Keys move by data row; only the offset is in
rows, so PgUp and PgDn move to the data row containing the row one viewport (V rows) above
or below the current row's first row, clamped to the first and last data row.

## Mouse table

| Event        | Region      | Precondition                                                                | Effect                                                                                     | Consumed |
| ------------ | ----------- | --------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------ | -------- |
| click        | data row    | single-select                                                               | sets selection to that row's ID via binding                                                | yes      |
| click        | data row    | multi-select                                                                | replaces the selection set with that row's ID via binding; cursor moves to the row         | yes      |
| click        | mark gutter | multi-select                                                                | toggles that row's ID in the selection set via binding; cursor moves to the row            | yes      |
| double-click | data row    | always                                                                      | runs the click effect for that row, then calls `onActivate`                                | yes      |
| click        | header cell | sort order binding set                                                      | cycles that column's entry (by column ID) through the Space sequence via binding           | yes      |
| wheel-down   | data row    | scroll offset < maximum scroll offset                                       | increments NodeState scroll offset                                                         | yes      |
| wheel-up     | data row    | scroll offset > 0                                                           | decrements NodeState scroll offset                                                         | yes      |
| move         | data row    | pointer on screen; rows request pointer motion while the table is on screen | sets the hovered row to the row under the pointer (`hover`); no selection or scroll change | no       |

Wheel scrolling moves the viewport without touching selection (selection may scroll out of
view; the bar and fill simply are not rendered until it returns). The ScrollIndicator is
output-only and has no drag interaction. In multi-select the mark gutter is part of the
data row region; its click wins over the data-row click.

## Multi-select and keyboard sorting

Owner decision, 2026-10-10: multi-select and keyboard sorting are designed for v1.
Shift-range selection is the one part deferred (see Open questions).

Multi-select uses the second initializer in the API, which takes
`selection: Binding<Set<ID>>`. Membership is the binding and nothing else. The cursor
lives in `NodeState`, and moving it never changes membership. A member row is drawn with a
mark gutter (`●`, ASCII `*`) and `selection.fill`; the cursor row gets `selection.bar`
only, so a cursor on a non-member row has no fill.

```wireframe 40x6
  Name                   Size   Modified
────────────────────────────────────────
 ●Spec.md              372 KB 2026-07-06
 ●Package.swift         12 KB 2026-07-01
▌ README.md            2.6 KB 2026-06-28
 ●CHANGELOG.md         8.8 KB 2026-06-28
```

```text
Callouts (40x6, 0-based):
1. r0       Header row -- as plain; the mark gutter has no header
2. r2-r5 c1 Mark gutter -- member mark `●` (ASCII `*`) on members, blank otherwise; click
            toggles membership; part of the data row, and its click wins over the data-row click
3. r2, r3, r5 Membership fill -- `selection.fill` on each member row
4. r4 c0    Cursor bar -- `selection.bar` on the cursor row; the cursor row is not a member
```

```text
── chars ──
  Name                   Size   Modified
────────────────────────────────────────
 ●Spec.md              372 KB 2026-07-06
 ●Package.swift         12 KB 2026-07-01
▌ README.md            2.6 KB 2026-06-28
 ●CHANGELOG.md         8.8 KB 2026-06-28
── style ──
..HHHH...................HHHH...HHHHHHHH
DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD
SBSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS
SBSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS
A.PPPPPPPPP............PPP.PP.PPPPPPPPPP
SBSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS
── legend ──
.  default
H  fg=primary bold
D  fg=border
P  fg=primary
S  fg=primary bg=selection.fill
B  fg=accent bg=selection.fill
A  fg=accent
```

Keyboard sorting needs no mouse. Ctrl-↑ enters header mode when a sort-order binding is
set. In header mode, ← and → move the header cursor across the columns, clamped at the
first and last column, and Space cycles the header cursor column's sort entry through
ascending, descending, and removed. Header mode dims the row selection to
`selection.inactive` and draws the header cursor cell in `selection.fill`. ↑, ↓, or Esc
leaves header mode; focus loss clears the header cursor. Each sorted column shows its
direction as a sort mark: `↑` for ascending, `↓` for descending (ASCII `^` and `v`). Table
never reorders data; the app sorts it from the sort-order binding.

```wireframe 40x6
 Name ↑                  Size   Modified
────────────────────────────────────────
 CHANGELOG.md          8.8 KB 2026-06-28
▌Package.swift          12 KB 2026-07-01
 README.md             2.6 KB 2026-06-28
 Spec.md               372 KB 2026-07-06
```

```text
Callouts (40x6, 0-based); header mode is on the Size column and Name is sorted ascending:
1. r0 c6     Sort mark -- `↑` on the sorted column's title; `↓` when descending; glyphs
             per [Marks](../tokens.md#marks)
2. r0 c22-28 Header cursor cell -- `selection.fill` on the cell under the header cursor,
             drawn only in header mode
3. r3 c0-c39 Inactive row -- `selection.inactive` for the bar and fill of the row selection
             while in header mode; the fill covers c0-c39 when derived, and where
             `selection.fill` is reverse video the fill starts at the next cell; the bar
             takes `secondary` (unfocused) ([selection](../tokens.md#selection))
```

```text
── chars ──
 Name ↑                  Size   Modified
────────────────────────────────────────
 CHANGELOG.md          8.8 KB 2026-06-28
▌Package.swift          12 KB 2026-07-01
 README.md             2.6 KB 2026-06-28
 Spec.md               372 KB 2026-07-06
── style ──
.HHHH.H...............SSSSSSS...HHHHHHHH
DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD
.PPPPPPPPPPPP..........PPP.PP.PPPPPPPPPP
JIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIII
.PPPPPPPPP.............PPP.PP.PPPPPPPPPP
.PPPPPPP...............PPP.PP.PPPPPPPPPP
── legend ──
.  default
H  fg=primary bold
D  fg=border
P  fg=primary
S  fg=primary bg=selection.fill
I  fg=primary bg=selection.inactive
J  fg=secondary bg=selection.inactive
```

## Sizing

Table is greedy on both axes when proposed; its ideal is content-driven.

| Proposal  | Result | Rule                                                                                                                                                                                                                                                                    |
| --------- | ------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| nil x nil | 45x14  | ideal: all 12 rows fit, so there is no ScrollIndicator or scrollbar reservation; content-resolved columns are 45 wide; height = header + rule + all 12 rows (no footer: app slot); a nil width does not wrap, so a column that opted in keeps its unwrapped ideal width |
| 40 x nil  | 40x14  | mobile state: Modified dropped by column priority; height = header + rule + all 12 rows at natural height, no footer (owner decision, 2026-10-10)                                                                                                                       |
| 40 x nil  | 40x12  | wrapped-column fixture: Description wraps at the 18 cells it gets, row heights 4, 2, 1, 2, 1; height = header + rule + 10 rows                                                                                                                                          |
| 40 x 6    | 40x6   | wrapped-column fixture: the 10 content rows overflow the 4 data rows of the viewport, so the indicator column is reserved and Description re-wraps at 17 cells (11 rows); offset, thumb, and paging count rows, and an edge row draws its visible rows                  |
| 46 x 9    | 46x9   | fills the proposal exactly; rows beyond the viewport scroll                                                                                                                                                                                                             |
| 24 x 5    | 24x5   | fills; column priority drops columns to fit (min state)                                                                                                                                                                                                                 |
| 10 x 3    | 10x3   | fills; single truncated column, no scrollbar below width 12                                                                                                                                                                                                             |
| 200 x 50  | 200x50 | fills; fill-policy columns absorb the slack, rows below content stay blank                                                                                                                                                                                              |

Numbers in the nil x nil row are for the anatomy example's data set; the rule, not the
numbers, is normative.

Horizontal overflow (owner decision, 2026-10-10): a nil-width proposal lays every column
out at ideal width with no drops, and a narrower proposal drops columns by priority. Table
adds no horizontal scrolling of its own; an app that needs a wide table in a narrow
proposal wraps it in `ScrollView(.horizontal)`.

Narrow tables keep dropping columns by priority before anything else; a column that opted
in to wrapping wraps in the width the surviving columns leave it (owner decision,
2026-10-18).

Style chrome adds to the content size and is part of the ideal:

- `plain`: no chrome. Height = header + header rule + rows; width = sum of column widths.
- `bordered`: width = sum of column widths + one separator per column boundary + 2 ring
  columns; height = 2 ring rows + header + header rule + rows. The 40-column example is
  15 + 9 + 12 + 2 + 2 = 40 wide and 2 + 1 + 1 + 4 = 8 rows tall.
- `grid`: as `bordered`, plus one rule row between each pair of data rows; height = 2 ring
  rows + header + header rule + rows + (rows - 1). The 40-column example is 11 rows tall.

Column width policy (baseline; the shared solver stays with Grid, deferred to
[Slice 6](../../docs/Spec.md#slice-6-grid-table-and-navigationsplitview-composition),
owner decision, 2026-10-10): each `TableColumn` declares `fixed(n)`, `min(n)`, or
`fill(weight:)`; fixed first, then min at their minimums, then remaining slack distributed
to fill columns by weight, integer remainders leading-first. Columns also carry a drop
priority for narrow viewports (mobile state); drop priority stays in v1 (owner decision,
2026-10-10).

## Environment

- `primary` plus bold -- default header text style; `TableStyle` may override it
- `selection.bar` (ASCII `>`), `selection.fill`, `selection.inactive`
- `divider.light` for the plain header rule
- `border` role ([roles](../tokens.md#roles)) -- frame, separators, junction glyphs
  (`├ ┼ ┤`), frame corners, and row rules of `bordered` and `grid`
- shared border sets (`light`, `heavy`, `ascii`) -- see
  [border sets](../tokens.md#border-sets)
- `focus` role -- outer ring of a bordered table when it or its content has focus, drawn
  as the terminal's default foreground in bold with no hue ([focus](../tokens.md#focus));
  ASCII uses bold (owner decision, 2026-10-19)
- `surface` role -- alternating row background (`.alternatingRowBackgrounds()`), 8%
  ([fill roles](../tokens.md#fill-roles)); `hover` (12%) is a separate role that wins over
  a stripe on a hovered row
- `hover` -- 12% row fill ([fill roles](../tokens.md#fill-roles)); slots and NO_COLOR draw
  an underline on the row label instead; `.rowHover(.disabled)` is the placeholder opt-out
  spelling (owner decision, 2026-10-19). Pointer motion requests cite Spec Slice 5
  ([Slice 5](../../docs/Spec.md#slice-5-mouse-and-hit-testing)).
- member mark glyph `●` (ASCII `*`) and sort mark glyphs `↑`, `↓` (ASCII `^`, `v`) --
  glyphs per [Marks](../tokens.md#marks)
- track `border`, thumb `accent` for the output-only ScrollIndicator
  ([scroll indicators](../tokens.md#scroll-indicators))
- `truncation.mark`
- `lineLimit` / `truncationMode` (environment) -- Table pins `lineLimit(1)` on header
  cells and on cells of columns that have not opted in; an opted-in column uses its own
  `TableColumn.lineLimit(_:)`, and `truncationMode` still comes from the environment

## Primitive dependencies

- [Divider](../primitives/divider.md) -- header rule. Ready.
- [Text](../primitives/text.md#truncation) -- `lineLimit` and `truncationMode` (default
  `.tail`, grapheme-safe), with [wrapping](../primitives/text.md#wrapping) and the
  [row budget](../primitives/text.md#row-budget) for opted-in columns. The wrapping
  contract is specified, not implemented: `Sources/TesseraCore/Views/Text.swift` is still
  the non-wrapping Slice 1 leaf, so this blocks `ready` until the Text wrapping slice
  lands.
- [ScrollIndicator](../primitives/scroll-indicator.md) -- shared with ScrollView and List;
  output-only, so Table supplies its viewport state but does not route pointer input to
  it. Ready.
- [ScrollView](scroll-view.md#rows-and-variable-height-content) -- the row-based offset,
  partial-row, paging, and reveal contract Table follows when a row is more than one row
  tall.
- Column width distribution -- consumes the ready shared [Flex](../primitives/flex.md)
  constraint vocabulary; Slice 6 Grid and Table delegate to its one resolver rather than
  designing a second allocator.

## Requirements

- `rows recompute from immutable data input on every update without a binding` (state
  model: rows)
- `selection stays visible when moved past the viewport edge` (key table: ↓; state: scroll
  offset)
- `successive selection moves separated by graph updates keep selection and scroll offset synchronized`
  (key table: ↓; state: selection and scroll offset)
- `wheel scrolling moves viewport without changing selection` (mouse table: wheel-down)
- `scroll indicator is output-only and has no drag interaction` (anatomy: callout 7; mouse
  table)
- `selection binding survives app reordering rows` (state model: selection)
- `vanished selection id renders no selection and does not mutate the binding` (state
  model: selection)
- `scroll offset clamps when app shrinks data` (state model: scroll offset; maximum scroll
  offset)
- `default header uses bold primary and TableStyle can override it` (state model: header
  styling)
- `header click cycles the sort entry for that column id through binding` (mouse table:
  header cell)
- `sort order is keyed by column id so retitling a column keeps its sort` (state model:
  sort order)
- `sort entry naming no column id is ignored and does not mutate the binding` (state
  model: sort order)
- `enter activates the selected element` (key table: Enter)
- `column narrower than content renders truncation mark not overflow` (anatomy: callout 6)
- `cell cut by truncation stays inside its own column` (anatomy: callout 6; prior art:
  omp2 cell truncation)
- `cjk cell content truncates on grapheme boundary` (anatomy: callout 6; Slice 7 mandatory
  case)
- `columns drop by priority at mobile width` (states: mobile)
- `table fills its proposal on both axes` (sizing: 46 x 9)
- `nil x nil fits all rows without an indicator or scrollbar reservation` (sizing: nil x
  nil)
- `empty data renders header and empty message` (states: empty)
- `ascii degradation preserves geometry` (states: degraded)
- `plain style draws no frame and keeps the header rule` (styles: plain)
- `bordered style draws an outer frame, column separators, and a header rule` (styles:
  bordered)
- `bordered selection fill leaves the border column unchanged` (styles: bordered)
- `grid style draws a rule between every row` (styles: grid)
- `alternating row backgrounds stripe every second data row in every style` (styles:
  striped; bordered striped)
- `selected row keeps selection fill over the stripe` (styles: striped; bordered striped)
- `table with focus draws its outer ring in the focus role with the heavy set; focus inside draws it at light weight`
  (styles: environment)
- `ascii focus renders bold on the bordered ring` (styles: environment; degradation)
- `bordered and grid table height and width match the sizing rules` (sizing: style chrome)
- `markdown tables render through the grid style` (styles: intro)
- `multi-select click on a data row replaces the selection set and moves the cursor there`
  (mouse table: click data row, multi-select)
- `mark gutter click toggles membership and moves the cursor` (mouse table: mark gutter)
- `double-click runs the click effect, then activates the row, in single and multi-select`
  (mouse table: double-click)
- `multi-select arrow keys move the cursor and leave membership unchanged` (key table: ↓;
  state model: cursor)
- `multi-select space toggles the cursor row membership and leaves the cursor in place`
  (key table: Space; state model: cursor)
- `multi-select enter activates the cursor row` (key table: Enter)
- `multi-select cursor clamps to the data count and clears when data is empty` (state
  model: cursor)
- `vanished multi-select id renders nowhere and stays in the set without a binding write`
  (state model: selection)
- `multi-select membership draws selection fill with a member mark in the gutter`
  (multi-select wireframe: callouts 3-4)
- `ctrl-up enters header mode only when a sort order binding is set` (key table: Ctrl-↑)
- `space in header mode cycles that column's sort entry through none, ascending, descending, removed`
  (key table: Space; mouse table: header cell)
- `left and right clamp the header cursor to the first and last column` (key table: ← →;
  state model: header cursor)
- `down and escape leave header mode, and focus loss clears the header cursor` (key table:
  ↓, Esc; state model: header cursor)
- `header mode draws the header cursor cell in selection fill and dims the row selection`
  (state model: selection style; keyboard sorting wireframe: callouts 2-3)
- `sort marks name each sorted column and table never reorders data` (state model: sort
  order; keyboard sorting wireframe: callout 1)
- `mobile state at 40 columns is natural height with no scrollbar or footer` (sizing: 40 x
  nil; states: mobile)
- `nil width proposal lays out every column at ideal width without dropping` (sizing: nil
  x nil; states: mobile)
- `alternating stripe uses the surface role and is dropped under NO_COLOR` (styles:
  striped; degradation)
- `cut mark renders as an ellipsis, or a tilde under ASCII` (anatomy: callout 6;
  degradation)
- `ascii multi-select and sort marks render as asterisk, greater-than, caret, and v`
  (degradation: ASCII-only)
- `cells are single-line by default and ignore an inherited line limit` (anatomy: wrap
  exception; state model: column line limit)
- `header row stays one row and tail-truncates` (anatomy: callout 1; wrapped columns)
- `column with line limit nil wraps its cells at the column width` (wrapped columns:
  callout 6)
- `data row height is its tallest wrapped cell` (wrapped columns: callouts 3, 8-9; sizing:
  40 x nil)
- `line limit of n caps a wrapped cell at n rows and marks the last visible row` (wrapped
  columns: height rule)
- `selection bar and fill cover every row of a wrapped data row; the bar cell takes the fill when derived and draws on the terminal background where selection.fill is reverse video`
  (wrapped columns: callout 7)
- `bar cell takes accent or secondary and the selection fill when derived; under reverse-video selection fill it draws on the terminal background`
  (Anatomy callout 4)
- `row under the pointer takes the hover fill; a selected row keeps selection.fill under the pointer`
  (Anatomy callout 9; state model: hovered row)
- `hover and stripes coexist: a hovered striped row shows hover over its stripe` (Styles:
  Striped)
- `rows request pointer motion only while the table is on screen` (state model: hovered
  row; [Slice 5](../../docs/Spec.md#slice-5-mouse-and-hit-testing))
- `.rowHover(.disabled) removes the hover fill and the motion request` (state model: hover
  enabled)
- `move event sets the hovered row without changing selection or scroll offset` (mouse
  table: move)
- `slots, NO_COLOR and 16-colour show hover as an underline on the row label`
  (Degradation: hover)
- `scroll offset thumb and paging count rows not data rows` (state model: scroll offset;
  sizing: 40 x 6)
- `partly visible data row draws its visible rows without a mark` (state model: scroll
  offset)
- `narrow table drops columns by priority and wraps the surviving wrapped column` (sizing:
  24 x 5; wrapped columns: narrow tables)
- `nil width proposal does not wrap an opted-in column` (sizing: nil x nil)

## Degradation

- `NO_COLOR`: selection falls back to reverse video; header to bold. Membership keeps its
  member mark, and the header cursor cell keeps reverse video, so neither depends on
  colour.
- 16-color: indexed equivalents of the accent; geometry unchanged.
- ASCII-only: degraded wireframe above -- `-` rule, `>` selection, `|`/`#` scrollbar, `~`
  truncation mark.
- ASCII-only, multi-select and keyboard sorting: member mark `*`, cursor bar `>`, sort
  marks `^` (ascending) and `v` (descending).
- ASCII-only, bordered and grid: the `ascii` border set -- `+` for every corner and
  junction, `-` for horizontal edges and rules, `|` for vertical edges and separators.
  Geometry is identical to the Unicode styles.
- Stripes have no ASCII glyph and are dropped under `NO_COLOR` (owner decision,
  2026-10-10): the stripe is a background only, and the selection keeps reverse video.
- Below `min` width (24): single truncated column, scrollbar dropped below width 12, never
  a layout failure; cells are single-line (wrap exception), and a surviving column that
  opted in to wrapping wraps, breaking words between graphemes when needed. ASCII marks a
  capped wrapped cell with `~`.
- Hover: slots, NO_COLOR and 16-colour draw no hover fill; the row label is underlined
  (owner decision, 2026-10-19).

## Open questions

- Shift-range selection in multi-select (`Shift-↓`, `Shift-↑` extend membership from an
  anchor row to the cursor) is deferred. Reason: it needs an anchor row in NodeState,
  which is a new state model row, plus a reset rule for the anchor when rows are reordered
  or vanish, and no use case is named yet. Deferred under the owner decision of 2026-10-10
  to defer any multi-select part that proves too complex to specify. Multi-select itself
  is designed in [Multi-select and keyboard sorting](#multi-select-and-keyboard-sorting).

## Inspiration

- 2026-07-06 -- Anatomy, states, and tables in this doc were developed as the process
  exemplar; see [README](../README.md) for the conventions they exercise.
