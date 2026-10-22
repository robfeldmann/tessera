---
type: spec
description: "Slice 6: Grid, Table, and fitting"
---

# Slice 6: `Grid`, `Table`, and fitting

Slice 6 consumes the Phase 2.5 Flex solver and final SplitView geometry; it does not
reopen either allocator. Plan 032 Phase 14 delivers it: `Flow` and `ViewThatFits` in step
14.1, and `Grid` and `Table` in step 14.4.

```swift
public struct Grid<Content: View>: View {
    public init(columns: [FlexConstraint], spacing: Int = 0,
                @ViewBuilder content: () -> Content)
}
public struct GridRow<Content: View>: View {
    public init(@ViewBuilder content: () -> Content)
}
```

Columns resolve once per grid through the established Flex algorithm; row heights are the
maximum of each row's children at their resolved column widths. No spanning in v1 — say no
now, design spanning later if real applications demand it.

Lip Gloss's `Join`/`Place`/`Compose` vocabulary maps onto existing primitives:
`JoinHorizontal` is `HStack(alignment:)`, `Place` is `.frame(width:height:alignment:)`,
and `Compose` is `ZStack`. Document that mapping in DocC rather than shipping duplicate
APIs.

## Flow layout and `ViewThatFits`

[`Flow`](../../design/primitives/flow.md) places its children left to right in source
order and starts a new line when the next child would pass the proposed width; each child
keeps its ideal width, capped at the line width, and is never split or stretched. Picker's
radio chips wrap this way and never clip.
[`ViewThatFits`](../../design/primitives/view-that-fits.md) holds candidate arrangements
in order of preference and shows the first whose ideal size fits the proposal on its
tested axes, or the last when none fits; it never places the others. Layout priority is
read by the parent, never among candidates or Flow items: `.layoutPriority(_:)` on a
candidate or an item does nothing, while priority on the `ViewThatFits` or the `Flow`
itself decides, through the enclosing stack or Flex allocation, which one keeps its
preferred arrangement longer. Priority fitting is therefore one shared mechanism rather
than per-component rules. Form's stacked layout, the description layouts of Picker and
MultiPicker, LabeledContent's stacked form, and ProgressView's label placement all choose
through `ViewThatFits`. `HStack` never wraps, so the stack contract stays unchanged.

## Table

[`Table`](../../design/widgets/table.md) resolves its columns through the Phase 2.5
`FlexConstraint` representation rather than creating a competing solver. It consumes
[`ScrollIndicator`](../../design/primitives/scroll-indicator.md) output with the same
overflow geometry as ScrollView, establishing indicator parity. Its styles (`.plain` by
default, `.bordered`, and `.grid`), `.alternatingRowBackgrounds()`, sorting by column
identity rather than title, and default row hover are catalog contract.

## NavigationSplitView is post-1.0

[`NavigationSplitView`](../../design/widgets/navigation-split-view.md) moved out of 1.0
(owner decision, 2026-10-09); 1.0 apps compose multi-column layouts from nested
`SplitView`s. Its composition contract (generic role children, controlled visibility, and
a responsive role policy over final SplitView negotiation) stays in the catalog until it
is scheduled.

## Definition of done for slice 6

1. Grid snapshot tests cover resolved columns, row heights, spacing, clipping, and paint
   order while proving the shared Flex solver is the only allocator.
2. [`Table`](../../design/widgets/table.md) reuses the Flex representation for its column
   solver and has ScrollIndicator parity with ScrollView.
3. `Flow` and `ViewThatFits` meet their catalog contracts, and the components that choose
   between arrangements do so only through `ViewThatFits`.

---
