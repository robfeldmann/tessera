---
type: spec
description: "Slice 2: The Layout protocol and stack containers"
---

# Slice 2: The `Layout` protocol and stack containers

## What this slice proves

Layout is a first-class, user-implementable protocol — not renderer folklore. The interim vertical-stacking rule from slice 1 is deleted and replaced by real containers.

## The protocol

Integer-cell adaptation of SwiftUI's `Layout`, which is the right shape to feel familiar while staying fully explicit:

```swift
public protocol Layout {
    func sizeThatFits(_ proposal: ProposedSize, subviews: Subviews) -> TerminalSize
    func placeSubviews(in bounds: Rect, proposal: ProposedSize, subviews: Subviews)
}

public struct Subviews: RandomAccessCollection {
    public struct Subview {
        public func sizeThatFits(_ proposal: ProposedSize) -> TerminalSize  // memoized
        public func place(at origin: TerminalPosition, proposal: ProposedSize)
        public subscript<K: LayoutValueKey>(key: K.Type) -> K.Value { get }
        public var priority: Int { get }   // .layoutPriority sugar
    }
}

public protocol LayoutValueKey {
    associatedtype Value
    static var defaultValue: Value { get }
}

extension Layout {
    /// `VStack { … }`-style call syntax for custom layouts: `MyColumns { … }`.
    public func callAsFunction<Content: View>(
        @ViewBuilder _ content: () -> Content
    ) -> some View
}
```

`Subview.sizeThatFits` is memoized per (node, proposal) within a layout pass, so naive layouts that probe children repeatedly stay O(children) per distinct proposal. `place` not being called for a subview hides it (zero rect) — stated, not implied.

Layout pass contract, exactly: the graph proposes the root the full terminal size; each container receives `sizeThatFits` then `placeSubviews`; placement assigns each child's absolute `frame: Rect`, clipped to the parent's frame for rendering and hit testing (overflow is clipped, never painted outside the parent — see ZStack flag below).

## Containers and modifiers in this slice

```swift
public struct VStack<Content: View>: View {
    public init(alignment: HorizontalAlignment = .leading, spacing: Int = 0,
                @ViewBuilder content: () -> Content)
}
public struct HStack<Content: View>: View {
    public init(alignment: VerticalAlignment = .top, spacing: Int = 0,
                @ViewBuilder content: () -> Content)
}
public struct ZStack<Content: View>: View {
    public init(alignment: Alignment = .topLeading,
                @ViewBuilder content: () -> Content)
}
public struct Spacer: View {
    public init(minLength: Int = 0)
}

extension View {
    public func frame(width: Int? = nil, height: Int? = nil,
                      alignment: Alignment = .topLeading) -> some View
    public func frame(minWidth: Int? = nil, maxWidth: Int? = nil,
                      minHeight: Int? = nil, maxHeight: Int? = nil,
                      alignment: Alignment = .topLeading) -> some View
    public func padding(_ insets: EdgeInsets) -> some View
    public func padding(_ all: Int = 1) -> some View
    public func layoutPriority(_ priority: Int) -> some View
    public func id<ID: Hashable>(_ id: ID) -> some View
}
```

## Catalog layout decisions

The Slice 2 public APIs reject invalid configuration with `precondition` before a layout pass: `spacing`, `Spacer.minLength`, every `EdgeInsets` edge, and every fixed/min/max frame extent must be non-negative; if both bounds on an axis are supplied, `min <= max`. Invalid configuration is never clamped, never creates an inverted rectangle, and never reaches a graph dump.

For a bounded frame axis, the reported extent is `clamp(childExtent, min, max)` using any present endpoint. A present maximum is also a child-proposal cap: a max-only frame proposes that maximum when its parent axis is `nil`, and otherwise proposes `min(parentProposal, maximum)`. The child can therefore measure its flexible layout at a finite cap; the frame still clips a larger placed child to its resolved bounds.

`dump()` records `paintOrder` on each placed child: its zero-based lexical source index within the parent. Render visits increasing `paintOrder`; ZStack does not have a separate `zIndex` layout value.

Note alignment defaults: terminal UIs read top-leading, not center. `Alignment`, `HorizontalAlignment`, `VerticalAlignment` are simple enums (no custom alignment guides — if they are ever needed, that is a separate proposal, not a quiet addition).

## Deferred baseline alignment

Baseline alignment is not part of Phase 4 or its alignment enums. It requires a separate post-1.0 proposal that defines a text-baseline metric for every participating view; until that proposal lands, HStack accepts only `.top`, `.center`, and `.bottom`, and VStack only `.leading`, `.center`, and `.trailing`.

## The stack algorithm (normative)

Deterministic integer distribution, written down so two implementations agree. For `HStack` with proposal `W` and children `c₁…cₙ` (VStack is the transpose):

1. Subtract total spacing: `available = W - spacing × (n - 1)`.
2. Probe flexibility: each child is measured at the proposal `(width: nil, height: h)` (ideal) and `(width: 0, height: h)` (minimum). Children whose ideal equals their minimum are **rigid**; others (and `Spacer`) are **flexible**.
3. Group children by descending `layoutPriority`. Within each priority tier, measure rigid children at their ideal first and subtract; then offer each flexible child a fair share of the remainder: `share = remaining / flexibleLeft`, measured left-to-right (top-to-bottom for VStack), subtracting the child's actual chosen width each time. Integer division remainder cells go to the **earliest** flexible children, one extra cell each — this is the documented rounding rule.
4. `Spacer` consumes its share as empty space (min `minLength`).
5. Place sequentially with spacing; cross-axis alignment per the stack's alignment.

If children overflow the proposal, trailing children clip — stacks never go negative and never redistribute below a child's reported minimum.

## `Divider`

[`Divider`](../../design/primitives/divider.md) lands with stack layout. It reads the `stackAxis` environment established by its enclosing stack and occupies the cross axis: horizontal in a `VStack`, vertical in an `HStack`. Its component appearance and sizing contract remain in the catalog; Slice 3 supplies its final style/decorative integration.

## Static controlled `SplitView` pane geometry

The first [`SplitView`](../../design/widgets/split-view.md) is a static, controlled pane layout: the app supplies the pane state through bindings, and layout derives fixed pane frames from it. It establishes divider placement and clipping only; it has no keyboard or pointer manipulation yet. This intentionally narrow geometry foundation is replaced, not extended by parallel code paths, by Phase 2.5's multi-pane min/ideal/max negotiation.

## `ScrollView` viewport foundation

The first [`ScrollView`](../../design/widgets/scroll-view.md) measures content at its ideal on each scrollable axis by proposing `nil` there, renders through a translated and clipped `RenderRegion`, and clamps a programmatic offset to content bounds on every layout. It shows static overflow only: it reserves no trailing or bottom edge unless that axis actually overflows. Keyboard, wheel, and pointer input with boundary bubbling arrive in plan 032 Phase 12 under the Slice 4 and Slice 5 contracts; this slice supplies their static controlled foundation.

## Invalidation semantics (graph-wide, defined here)

- `needsLayout` on any node ⇒ the next `layoutIfNeeded()` re-runs the full layout pass from the root (memoized measures make this cheap; trees are small).
- `needsRender` ⇒ the next `render(into:)` repaints (full tree; the buffer diff makes terminal output minimal).
- Reconciliation sets both for changed nodes; `resize(to:)` sets `needsLayout` globally; widget `NodeState` mutations set them via `ResponderContext` (slice 4).

## Tests

- Pure `Layout` unit tests with stub subviews — no graph, no terminal: distribution tables as parameterized tests (`(proposal, children) → frames`), including remainder rules, priority tiers, spacer behavior, overflow clipping.
- Graph integration snapshots: nested stacks + frame/padding through `VirtualTerminal`.
- A custom user-defined `Layout` (e.g., a trivial `FlowLayout`) implemented in the test target, proving the protocol is sufficient for third parties.

## Definition of done for slice 2

1. `Layout`, `Subviews`, `LayoutValueKey` are public; stacks, `Spacer`, `frame`, `padding`, `layoutPriority`, `id`, and [`Divider`](../../design/primitives/divider.md) ship; Slice 1's interim stacking rule is deleted.
2. The stack distribution algorithm matches the normative steps, with table tests.
3. Static controlled [`SplitView`](../../design/widgets/split-view.md) pane geometry and the [`ScrollView`](../../design/widgets/scroll-view.md) viewport foundation meet their documented measurement, clipping, clamping, and non-reserved-overflow rules.
4. `dump()` includes proposal, size, and absolute frame per node.
5. A third-party-style custom layout works using only public API.

## Things to flag

1. **Resist Cassowary.** The deterministic tiered algorithm covers TUI needs; a constraint solver would destroy the "layout is readable integer math" property. Ratatui's move _away_ from purely solver-driven layout is the cautionary tale.
2. **Min-size probing costs a second measure.** Memoization makes it fine; do not complicate the protocol with a separate "flexibility" method until profiling says so.

---
