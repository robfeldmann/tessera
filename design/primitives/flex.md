---
kind: primitive
status: ready
---

# Flex

Flex is a stateless main-axis layout that resolves explicit integer constraints for each
ordered child, then places those children with deterministic spacing and cross-axis
alignment. It owns allocation only: it does not render separators, retain sizes, scroll,
focus, or handle input.

## Prior art

- Ratatui `~/Developer/ratatui/ratatui/main/ratatui-core/src/layout/constraint.rs`
  supplies the `Length`, `Min`, `Max`, `Percentage`, `Ratio`, and `Fill` vocabulary.
  Tessera keeps those integer constraint meanings but uses its own `Layout` measurement
  and clipping rules.
- Ratatui `~/Developer/ratatui/ratatui/main/ratatui-core/src/layout/flex.rs` demonstrates
  deterministic excess-space distribution. Tessera exposes one weighted policy rather than
  a second set of start/end/space-around modes.
- [Linear stacks](stacks.md) establish Tessera's ideal/minimum probes, source-order
  integer remainder, and sole `.layoutPriority(_:)` API. Flex reuses those rules rather
  than creating a parallel priority property.
- SwiftUI's flexible frame vocabulary motivates separating a child's measured minimum,
  ideal, and cap. Tessera retains explicit integer-cell constraints and tolerance-free
  results rather than proposing floating-point geometry.

## Anatomy

```wireframe 30x1
AAAA BBBBBBBBBBBBBBBBBBB CCCC
```

```text
Callouts (30x1, 0-based):
1. r0c0-3    first allocated child segment
2. r0c4      spacing cell
3. r0c5-23   weighted flexible child segment
4. r0c24     spacing cell
5. r0c25-28  capped child segment
6. r0c29     unused parent slack after all children reach a cap
```

The wireframe shows allocation regions, not glyphs emitted by Flex. Child views own every
visible cell. Source order is placement and paint order.

## Public vocabulary

```swift
public enum FlexConstraint: Equatable, Sendable {
  case length(Int)
  case min(Int)
  case max(Int)
  case percentage(Int)
  case ratio(Int, Int)
  case fill(Int)
}

public struct Flex<Content: View>: View {
  public init(
    _ axis: Axis,
    spacing: Int = 0,
    @ViewBuilder content: () -> Content
  )
}

extension View {
  public func flex(_ constraint: FlexConstraint) -> some View
}
```

`spacing` and all cell extents must be nonnegative. Percentage must be in `0...100`. Ratio
numerator must be nonnegative and its denominator positive; a ratio above one is legal and
may overflow the parent. Fill weight must be nonnegative; `fill(0)` always receives zero
main-axis cells and does not enter weighted distribution. Invalid values fail a
precondition at construction. Overflowing intermediate integer arithmetic saturates at
`Int.max`; it never wraps or creates a negative allocation.

| Input                                     | Valid range                     | Invalid behavior / overflow rule                                       |
| ----------------------------------------- | ------------------------------- | ---------------------------------------------------------------------- |
| `spacing`, `length`, `min`, `max`         | nonnegative whole cells         | negative construction fails a precondition                             |
| `percentage(p)`                           | `0...100`                       | out-of-range construction fails a precondition                         |
| `ratio(numerator, denominator)`           | numerator >= 0; denominator > 0 | invalid construction fails; ratios above one are legal over-constraint |
| `fill(weight)`                            | weight >= 0                     | negative construction fails; zero receives zero and is not weighted    |
| allocation multiplication, sum, placement | representable or overflowing    | full-width intermediate saturates at `Int.max`; never wraps negative   |

## Constraint resolution

For each child Flex measures the ideal with an unspecified main-axis proposal and the
minimum with a zero main-axis proposal. The cross-axis proposal passes through unchanged.
With a finite parent main-axis proposal, spacing is reserved before child allocation.

Every public constraint and SplitView's range adapter lowers to the same resolver item:

| Input                   | Floor                         | Initial allocation                    | Growth cap                | Growth weight | Compression phase |
| ----------------------- | ----------------------------- | ------------------------------------- | ------------------------- | ------------- | ----------------- |
| `length(n)`             | `n`                           | `n`                                   | `n`                       | 0             | fixed             |
| `percentage(p)`         | resolved percentage           | `floor(available * p / 100)`          | initial                   | 0             | fixed             |
| `ratio(n, d)`           | resolved ratio                | `floor(available * n / d)`            | initial                   | 0             | fixed             |
| `max(n)`                | measured ideal clamped to `n` | measured ideal clamped to `n`         | initial                   | 0             | fixed             |
| `min(n)`                | max(measured minimum, `n`)    | max(measured ideal, floor)            | nil                       | 1             | minimum           |
| `fill(weight)`          | 0                             | measured ideal, or 0 when weight is 0 | nil                       | `weight`      | fill              |
| no `.flex` value        | measured minimum              | max(measured ideal, measured minimum) | nil                       | 1             | minimum           |
| SplitView range adapter | controlled minimum            | controlled requested ideal            | controlled maximum or nil | 1             | minimum           |

`initial` is the allocation before parent remainder is applied. `floor` is the lower bound
for the listed compression phase. `growth cap == nil` is unbounded. Fixed items have
identical floor, initial, and cap. Priority is read from the child separately and never
stored in the resolver item.

When the main-axis proposal is unspecified, Flex reports the sum of these initial
allocations plus spacing. Percentage and ratio use the child ideal because no container
extent exists; no weighted growth occurs. A finite proposal never forces Flex to report a
smaller extent than the remaining fixed allocations and hard floors.

## Remainder and priority

`Subview.priority`, supplied only by `.layoutPriority(_:)`, participates in flexible
allocation. Fixed `length`, percentage, ratio, and `max` allocations ignore priority.

| Condition                     | Resolution rule                                                                                                                                                                                         |
| ----------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| positive remainder            | Visit priority tiers descending. Within the first tier that can grow, distribute by weight; quotient cells follow weights and leftover one-cell remainders go to earliest source children.              |
| positive remainder after caps | Continue to the next lower priority tier only when every child in the higher tier has reached its upper bound; uncapped `min`, positive `fill`, default, and SplitView range items have no upper bound. |
| negative remainder, `fill`    | Visit priority tiers ascending and remove weighted cells toward zero; equal-tier remainder cells come from later source children first.                                                                 |
| negative remainder, minimum   | After fill compression, visit priority tiers ascending and reduce `min`, default, and SplitView range items toward their floors; later source children yield remainder cells first.                     |
| unresolved negative remainder | Keep fixed allocations and hard floors, report their nonnegative total extent, and let the parent clip trailing children. No child receives a negative rectangle.                                       |
| no children                   | Report `0x0`; spacing contributes no outer cells.                                                                                                                                                       |
| one child                     | Resolve that child normally; spacing contributes zero.                                                                                                                                                  |

The descending growth/ascending compression ordering means a higher-priority flexible
child receives surplus first and resists compression longer. It is the same priority
concept used by linear stacks, not a separate Flex priority API.

## Sizing

The examples use horizontal Flex, one-cell spacing, and one-row children. The primary
fixture is `[length(4), fill(1), max(4)]`, where the fill child's measured ideal is 6 and
the capped child's measured ideal is 8. The capped-only over-maximum fixture is
`[max(4), max(6)]`.

| Proposal  | Result | Rule                                                                                    |
| --------- | ------ | --------------------------------------------------------------------------------------- |
| nil x nil | 16x1   | Initial ideals `4 + 6 + 4` plus two spacing cells define the unconstrained ideal.       |
| 16x1      | 16x1   | The exact proposal matches initial allocations and spacing, so no remainder is present. |
| 8x1       | 10x1   | Fill compresses from 6 to 0; fixed children and spacing retain 10 cells and trail-clip. |
| 30x1      | 11x1   | Two capped children retain `4 + 6` plus one spacing cell and leave parent slack unused. |

Cross-axis size is the maximum measured cross-axis child extent. Placement uses the
selected `HorizontalAlignment` for vertical Flex and `VerticalAlignment` for horizontal
Flex when a child is smaller than that cross extent. Child output larger than its
allocated segment is clipped by that segment before later siblings render.

## Environment

Flex consumes no style or glyph token.

| Value                  | Source                               | Default | Effect                                                                  |
| ---------------------- | ------------------------------------ | ------- | ----------------------------------------------------------------------- |
| `Subview.priority`     | existing `.layoutPriority(_:)` value | 0       | selects descending growth and ascending compression tiers               |
| descendant `stackAxis` | Flex's public axis                   | —       | gives Divider and Spacer the same cross-axis semantics as linear stacks |

## Requirements

- `flex resolves fixed relative capped minimum and fill constraints in normative order`
  (constraint resolution: every row)
- `flex defaults an unconstrained child to its measured minimum compression floor`
  (constraint resolution: no `.flex` value)
- `flex gives positive weighted remainder cells to earlier children first` (remainder and
  priority: positive remainder)
- `flex allocates higher priority growth before lower priority growth` (remainder and
  priority: positive remainder after caps)
- `flex compresses lower priority fill before minimum constrained children` (remainder and
  priority: negative remainder rows)
- `flex compresses an unannotated child toward its measured minimum before clipping`
  (constraint resolution: no `.flex` value; remainder and priority: negative minimum)
- `flex clips trailing fixed children when hard floors exceed the proposal` (remainder and
  priority: unresolved negative remainder; sizing: 8x1)
- `flex keeps every allocated frame nonnegative under a zero proposal` (remainder and
  priority: unresolved negative remainder)
- `flex reports the sum of initial allocations when its main axis is unspecified` (sizing:
  nil x nil)
- `flex leaves slack after every child reaches a cap` (sizing: 30x1)
- `flex handles empty and single child content without outer spacing` (remainder and
  priority: no children and one child)
- `flex rejects negative extents invalid percentages ratios and fill weights` (validation:
  extent, percentage, ratio, and fill rows)
- `flex saturates overflowing arithmetic without wrapping negative` (validation:
  allocation multiplication row)
- `flex publishes its axis to descendant Divider and Spacer views` (environment:
  descendant stackAxis row)

## Degradation

Flex emits no cells and has no capability-dependent state. Unicode width, glyph, color,
and ASCII degradation remain each child's responsibility. Allocation, clipping, and source
order are identical at every capability tier in the
[degradation ladder](../tokens.md#degradation-ladder).

## Decisions

- Flex has one weighted surplus policy. HStack/VStack remain the concise intrinsic-layout
  API; callers choose Flex only when explicit constraints are part of the contract.
- `.layoutPriority(_:)` is the only priority API. Flex does not add priority to
  `FlexConstraint` or child configuration.
- Percentage and ratio are relative only when the main-axis proposal is finite; child
  ideal is the deterministic unconstrained fallback.
- An unannotated child mirrors stack behavior: its measured ideal is the initial
  allocation, its measured minimum is the compression floor, and it participates with
  weight 1.
- Grid and Table will consume this constraint vocabulary and solver later; they do not own
  separate allocators.

This contract was reviewed against the
[Phase 4 theses](../../docs/Spec.md#phase-4--view-layer-the-tessera-module): views remain
values, allocation is deterministic integer geometry, child state is not retained, and
clipping remains explicit in the graph.

## Inspiration

- SplitView side panes capped at an ideal width while a middle pane absorbs surplus.
- Ratatui constraint tables for dashboards whose dimensions must remain inspectable.
- CSS flex-grow/flex-shrink vocabulary as contrast; Tessera uses integer priorities and
  one deterministic remainder policy rather than floating-point factors.
