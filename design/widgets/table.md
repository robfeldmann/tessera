---
kind: widget
status: specified
---

# Table

`Table` is a controlled, keyed, scrollable data view. Application code owns immutable
data, selection, sort intent, and actual ordering. Table owns only transient scroll offset
and derives rows from the current collection on every update.

## Public boundary

```swift
Table(
  data,
  selection: Binding<Data.Element.ID?>,
  sortOrder: Binding<[SortDescriptor<Data.Element>]>? = nil,
  columns: [TableColumn<Data.Element>],
  emptyMessage: String = "No items",
  onActivate: ((Data.Element) -> Void)? = nil
)
```

`TableColumn<Element>` contains a title, `FlexConstraint`, drop priority, and a value
closure that produces the cell's display string. `SortDescriptor<Element>` contains a
column key and ascending flag. Header taps write sort intent to the optional binding;
Table never reorders the input collection. `TableStyle` supplies header, active-selection,
inactive-selection, and separator styles through `tableStyle(_:)`.

## Behavioral contract

- Rows use `Data.Element.ID` structural slots. Reorder with stable IDs preserves
  selection; removing the selected ID leaves the application binding unchanged.
- Up, Down, Page Up, Page Down, Home, and End move controlled selection and clamp at both
  endpoints. Enter activates the selected element when `onActivate` is supplied.
- Row pointer taps select through the binding. Normalized wheel-up/down events adjust only
  the graph-owned offset; horizontal wheel and vertical boundaries bubble. Overflow uses
  the shared output-only `ScrollIndicator`.
- Column widths resolve through the shared Flex allocator. Rows and header cells are
  clipped to the table viewport. Empty data renders `emptyMessage`; resize recomputes
  extents and clamps offset. No spanning, sorting framework, or private data-source model
  is introduced.

Dedicated collection regressions cover header sort intent, activation, row pointer
selection, empty data, identity removal, endpoint clamp, resize, and normalized wheel
routing.
