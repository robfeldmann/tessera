---
kind: widget
status: specified
---

# List

`List` is Tessera's controlled, focusable collection widget for a `RandomAccessCollection`
whose elements are `Identifiable`. Application code owns the collection and
`Binding<Data.Element.ID?>` selection. The widget owns only its transient cell offset and
derives keyed row children on each graph update.

## Public boundary

```swift
List(data, selection: Binding<Data.Element.ID?>, emptyMessage: String = "No items") { element in
  row(element)
}
```

Rows use `Data.Element.ID` as their structural slot. Reordering with the same IDs
preserves the selected identity. Removing that ID does not mutate the application binding.
Row taps write the binding, while descendant focus and bindings continue through the row
builder. Empty data renders `emptyMessage`.

## Behavioral contract

- Up, Down, Page Up, Page Down, Home, and End write the controlled selection, clamp at the
  collection endpoints, and reveal the target row.
- Variable-height rows are measured every layout pass. Offset is clamped to the measured
  content and viewport extents; constrained and zero-height proposals remain bounded.
- Wheel events consume only a possible local offset change; events at an offset boundary
  bubble. Overflow is rendered by the shared output-only `ScrollIndicator`.
- Selection presentation is bold and remains legible without color. List does not own
  data, selection, sorting, a private pointer model, or indicator dragging.

The dedicated collection regressions cover keyed reorder/removal, empty state, keyboard
endpoint clamping, row pointer selection, and wheel offset routing.
