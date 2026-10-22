---
type: spec
description: "Phase 2.5: Flex and final SplitView negotiation"
---

# Phase 2.5: Flex and final SplitView negotiation

This geometry stabilization lands immediately after Slice 2. It proves that the public `Layout` protocol carries explicit non-stack allocation and ensures later style, keyboard, and pointer work consume one final SplitView geometry path.

## Public Flex vocabulary

```swift
public enum FlexConstraint: Sendable, Equatable {
    case length(Int)
    case min(Int)
    case max(Int)
    case percentage(Int)
    case ratio(Int, Int)
    case fill(Int)
}

public struct Flex<Content: View>: View {
    public init(_ axis: Axis, spacing: Int = 0, @ViewBuilder content: () -> Content)
}

extension View {
    public func flex(_ constraint: FlexConstraint) -> some View
}
```

Spacing and every cell extent are nonnegative. Percentage is in `0...100`; ratio has a nonnegative numerator and positive denominator; fill weight is nonnegative. Ratios above one are legal over-constraints. `fill(0)` receives zero cells and does not participate in weighted distribution. Invalid construction fails a precondition. Full-width intermediates and saturating conversion prevent integer wraparound.

## Flex allocation (normative)

For each child, Flex measures the ideal with an unspecified main-axis proposal and the minimum with a zero main-axis proposal. It reserves spacing before resolving a finite container extent. Every public constraint and SplitView range lowers to one resolver item:

| Input | Floor | Initial allocation | Growth cap | Weight | Compression |
| --- | --- | --- | --- | --- | --- |
| `length(n)` | `n` | `n` | `n` | 0 | fixed |
| `percentage(p)` | resolved percentage | `floor(available * p / 100)` | initial | 0 | fixed |
| `ratio(n, d)` | resolved ratio | `floor(available * n / d)` | initial | 0 | fixed |
| `max(n)` | measured ideal clamped to `n` | measured ideal clamped to `n` | initial | 0 | fixed |
| `min(n)` | max(measured minimum, `n`) | max(measured ideal, floor) | nil | 1 | minimum |
| `fill(weight)` | 0 | measured ideal, or 0 for zero weight | nil | `weight` | fill |
| no `.flex` value | measured minimum | max(measured ideal, measured minimum) | nil | 1 | minimum |
| SplitView range adapter | controlled minimum | controlled requested ideal | controlled maximum or nil | 1 | minimum |

`initial` precedes parent remainder, `floor` bounds the listed compression phase, and a nil growth cap is unbounded. Priority remains separate child metadata.

With an unspecified main axis, percentage and ratio use the child ideal and no weighted growth occurs. A finite positive remainder visits `.layoutPriority(_:)` tiers descending, distributes by weight, and gives leftover one-cell remainders to earlier source children. It reaches a lower tier only after every child in the higher tier is capped; positive `fill`, `min`, default, and SplitView range items are otherwise uncapped.

A negative remainder visits priority tiers ascending. It first reduces `fill` allocations toward zero, then `min`, default, and SplitView range items toward their floors; equal-tier remainder cells come from later source children first. Fixed/relative/`max` allocations and exhausted floors do not become negative. Any unresolved deficit remains in the reported main-axis extent and the graph clips trailing children. Flex has no outer spacing for zero or one child. Cross size is the largest child cross extent. These rules are owned by [`Flex`](../../design/primitives/flex.md); Grid and Table later delegate to the same resolver.

`.layoutPriority(_:)` remains the one priority API. Flex reads `Subview.priority` exactly as stacks do and introduces no constraint-specific or pane-specific priority property. An unannotated child therefore matches stack behavior: measured ideal is its initial allocation and measured minimum is its compression floor.

## Final controlled SplitView sizing

```swift
public struct SplitViewPaneSizing: Sendable, Equatable {
    public init(minimum: Int = 0, ideal: Int, maximum: Int? = nil)
}
```

Construction requires `0 <= minimum <= ideal <= maximum` when maximum exists; nil maximum is unbounded. Each visible pane lowers this range to the resolver's `floor`, `initial`, `growth cap`, weight-1 `minimum` compression fields. The child view's existing `layoutPriority` remains separate priority metadata. SplitView reserves one divider cell per adjacent visible pair before resolution. It grows higher-priority panes toward maxima and compresses lower-priority panes toward minima; earliest children receive positive remainder and later children yield compression remainder first.

Collapsed panes retain their complete bound sizing but contribute no resolver item, rect, divider, or hit region. Effective negotiation never writes back to the binding. Keyboard and pointer resizing in later slices update only the adjacent pair's controlled ideals, preserve their pair total whenever both ranges permit, and use the immutable resolved frames from this single geometry path.

## Definition of done for Phase 2.5

1. Flex's catalog document is `ready`; table tests cover every constraint, default, priority, remainder, over-constraint, validation, and overflow branch.
2. Final SplitView negotiation deletes the static allocator and has exact min/ideal/max, collapse, clipping, resize, and controlled-state tests.
3. Pane-set breakpoints (which panes show at which width) are application policy, not SplitView contract; the SplitView demo of plan 032 Phase 15 carries SplitView's fixtures at the canonical 40x16 and 80x24 sizes.
4. Grid and Table remain Slice 6 consumers of this established geometry rather than pulling their unrelated scope forward.

---
