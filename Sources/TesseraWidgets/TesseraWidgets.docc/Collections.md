# Collections

Tessera's collection widgets are controlled views. Data, selection, sorting, and activation
remain application-owned; the widgets only derive keyed children and graph-owned transient
scroll state.

## List

Use `List(_:selection:emptyMessage:rowContent:)` with an identifiable random-access
collection. A row primary-pointer activation writes its identity to the selection binding. Up, Down, Page Up, Page
Down, Home, and End update the binding, clamp at collection endpoints, and reveal the target
row. Reordering with the same IDs preserves the selected identity. Removing the selected ID
does not mutate the binding. Empty collections render `emptyMessage`, and overflow uses the
same output-only `TesseraLayout/ScrollIndicator` metrics as `ScrollView`.

## Section

`Section` lays out a header and content as two structural children. The convenience
`Section(_:)` initializer supplies a text header. It owns no state and does not alter
identity, focus, environment, or input routing for descendants.

## Table

`Table` uses `TableColumn` values to render controlled rows and supports keyed selection,
optional activation, and a controlled `[SortDescriptor<Element>]` binding. Header taps record
sort intent by column title; the application performs the actual data reorder. Column widths
resolve through `FlexConstraint`, and rows are clipped to the table viewport. Narrow layouts
reserve one terminal column for the shared output-only scroll indicator rather than creating
a private scrolling model.

`TableStyle` controls header, active selection, inactive selection, and separator roles through
the `tableStyle(_:)` environment modifier.
