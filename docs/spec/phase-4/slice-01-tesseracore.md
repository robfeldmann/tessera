---
type: spec
description: "Slice 1: TesseraCore — View, ViewGraph, reconciliation, Text"
---

# Slice 1: TesseraCore — `View`, `ViewGraph`, reconciliation, `Text`

## What this slice proves

A declarative view value can be lowered to an explicit node tree, rendered into a `Buffer` through the real session `Frame`, updated incrementally, and inspected. At the end of this slice you can run an example app showing live, declaratively-described text — no layout system yet (children stack vertically by a hardcoded interim rule), no input routing.

## The `View` protocol and builders

```swift
public protocol View {
    associatedtype Body: View
    @ViewBuilder var body: Body { get }
}

extension Never: View { /* body: fatalError */ }
extension Optional: View where Wrapped: View { /* lowered to presence/absence */ }

@resultBuilder
public enum ViewBuilder {
    public static func buildBlock<each Content: View>(
        _ content: repeat each Content
    ) -> TupleView<repeat each Content>
    public static func buildEither<T: View, F: View>(first: T) -> ConditionalView<T, F>
    public static func buildEither<T: View, F: View>(second: F) -> ConditionalView<T, F>
    public static func buildOptional<C: View>(_ content: C?) -> C?
    public static func buildExpression<C: View>(_ content: C) -> C
}
```

`TupleView` uses parameter packs — this is one of the Swift 6 highlights. The Phase 0 Swift 6.3 probe compiled pack iteration, `~Copyable`/`~Escapable` borrowed-region lending (with the `Lifetimes` experimental feature), and generic opening of a `View` existential. The parameter-pack implementation remains selected; fixed-arity overloads up to 10 remain the documented fallback only if a supported toolchain regresses.

Structural views the reconciler understands natively: `TupleView`, `ConditionalView`, `Optional`, `EmptyView`, `ForEach`, `AnyView` (type erasure; documented as an identity barrier just like SwiftUI's), and `EquatableView`/`.equatable()` (skip subtree re-evaluation when old and new values compare equal).

```swift
public struct ForEach<Data: RandomAccessCollection, ID: Hashable, Content: View>: View {
    public init(_ data: Data, id: KeyPath<Data.Element, ID>,
                @ViewBuilder content: @escaping (Data.Element) -> Content)
}
extension ForEach where Data.Element: Identifiable, ID == Data.Element.ID {
    public init(_ data: Data, @ViewBuilder content: @escaping (Data.Element) -> Content)
}
```

## The leaf seam

Primitives are public protocol conformances, not compiler magic, so third parties can write their own leaves (a sparkline, a sixel image view) without forking:

```swift
public protocol LeafView: View where Body == Never {
    associatedtype NodeState = Void

    func makeState() -> NodeState
    func sizeThatFits(
        _ proposal: ProposedSize,
        state: inout NodeState,
        environment: EnvironmentValues
    ) -> TerminalSize
    func render(
        in region: inout RenderRegion,
        state: inout NodeState,
        environment: EnvironmentValues
    )
    /// Only called when this node is focused or on the bubble path. Default: .ignored.
    func handleEvent(
        _ event: InputEvent,
        state: inout NodeState,
        context: inout ResponderContext
    ) -> EventDisposition
}

public struct ProposedSize: Sendable, Hashable {
    public var width: Int?    // nil = unconstrained
    public var height: Int?
    public static let unspecified: ProposedSize
    public init(width: Int?, height: Int?)
}

public enum EventDisposition: Sendable, Equatable {
    case handled
    case ignored
}
```

Defaults: `makeState()` for `NodeState == Void`, and `handleEvent` returning `.ignored`, so a render-only leaf implements exactly two methods.

## `RenderRegion`

The view layer's borrowed write capability — a clipped, translated window onto the frame's `Buffer`:

```swift
public struct RenderRegion: ~Copyable {
    /// Local coordinates: origin is (0,0); bounds.size is this node's frame size.
    public var bounds: Rect { get }

    public mutating func write(_ string: String, at position: TerminalPosition,
                               style: Style)
    public mutating func setCell(_ cell: Cell, at position: TerminalPosition)
    public mutating func fill(_ cell: Cell, in rect: Rect)
    /// Scoped sub-region: translated and clipped. The closure cannot escape it.
    public mutating func with(_ rect: Rect, _ body: (inout RenderRegion) -> Void)
    /// Producer escape hatch, clipped and damage-policy-paired per Phase 2 Slice 2.
    public mutating func raw(_ payload: RawTerminalPayload, at position: TerminalPosition)
}
```

Out-of-bounds writes clip silently (never trap, never wrap). Wide-grapheme writes that straddle the clip edge follow the Phase 2 Slice 4 continuation-cell rules. `~Copyable` keeps regions from being stored or aliased; render is the only place they exist.

## `RuntimeNode` and `ViewGraph`

```swift
public final class ViewGraph {
    public init<Root: View>(
        root: @escaping () -> Root,
        size: TerminalSize,
        environment: EnvironmentValues = EnvironmentValues()
    )

    public func update()                       // pass 1
    public func layoutIfNeeded()               // pass 2 (update() does NOT imply layout)
    public func render(into frame: borrowing Frame) // passes 2+3 as needed, then draw
    public func resize(to size: TerminalSize)

    public func dispatch(_ event: InputEvent) -> EventDisposition  // slice 4+
    public var focus: FocusManager { get }                          // slice 4
    public var terminalRequirements: TerminalRequirements { get }   // slice 4
    public var needsRender: Bool { get }
    public var needsLayout: Bool { get }

    public func dump() -> String
    public var statistics: GraphStatistics { get }
}
```

`GraphStatistics` includes counts for nodes created/destroyed/updated, body evaluations, equatable skips, leaf updates, `sizeThatFits` calls, placements, rendered nodes, focus changes, terminal requirement changes, debug-only invalidation reasons, and pass durations. Anything developers need print statements to answer belongs here or in `dump()`.

`ViewGraph` is non-`Sendable` and unisolated; whoever creates it owns it. The canonical immediate-mode loop (the Phase 5 runtime automates exactly this, nothing more):

```swift
let session = try await TerminalSession(configuration: config)
let graph = ViewGraph(root: { AppView(model: model) }, size: await session.size)

for await event in await session.events {
    var isResize = false
    if case .resize(let size) = event {
        isResize = true
        graph.resize(to: size)
    }
    let disposition = graph.dispatch(event)
    if disposition == .ignored || isResize {
        model.apply(event)        // app-owned state, app-owned architecture: only what the tree left unhandled, and every resize
    }
    graph.update()
    if graph.needsRender {
        try await session.draw { frame in graph.render(into: frame) }
    }
}
```

The app sees an event only when the graph left it `.ignored`, and every resize (a resize is never routed, [slice 4](slice-04-focus-and-key-routing.md#event-routing-normative)). The Phase 5 runtime and the developer harness run exactly this body as one nonisolated step that takes the host's isolation as a parameter ([Runtime isolation](../phase-5-runtime-and-polish.md#the-canonical-step)), so a hand-written loop and the hosts cannot drift. This example runs in the session's isolation; a loop in any other isolation passes `draw` a body in its own isolation, since `draw` runs the body in the caller's.

`RuntimeNode` (internal class; its _shape_ is spec'd so dumps and tests are stable): identity, view type id, stored view value (`any View`), `NodeState` box, children, environment snapshot, `frame: Rect` (absolute), cached `sizeThatFits` memo (cleared each layout pass), `needsLayout`/`needsRender` flags, registered handlers (slices 4–5).

`dump()` is the primary debugger, not a pretty extra. It prints identity paths, dynamic view types, frames, proposals, measured sizes, clip rects, dirty flags, environment overrides, focusability, focused state, installed handlers, and terminal requirements contributed by each subtree. If Phase 4 development requires a print statement to answer a "why did this update/layout/render/focus change" question, fix `dump()` or `statistics`.

## Immutable local developer diagnostics

`graph.dump()` and `statistics` are human-readable projections of the **public immutable diagnostics snapshot** from the most recently completed graph pass. Its schema is frozen:

- every node's identity and dynamic type;
- parent identity and ordered child identities;
- proposal, measured size, absolute frame, and clip;
- resolved environment override names and installed handler kinds;
- requested graph and effective session `TerminalRequirements`; and
- reconciliation counters (node create/destroy/update, body evaluation, equatable skip, leaf update, measurement, placement, render, focus, and requirements changes).

No other data enters this schema: it excludes controlled values, raw view values, raw input, raw terminal bytes, `NodeState`, closures, and borrowed regions. It is local-only and has no serialization, persistence, logging, telemetry, or remote transport. A diagnostics inspector, wherever a demo or the intro app shows one, reads the immutable snapshot only; it cannot mutate the graph, retain a borrowed `RenderRegion`, change focus or state, or trigger a pass. The graph reports requested requirements; the session is the sole authority that decides and reports effective requirements in the snapshot.

## The reconciliation algorithm

Spelled out so it can be implemented mechanically and reviewed against this text:

1. `update()` calls the root closure to get the new root view value, then calls `reconcile(node: rootNode, view: newRoot)`.
2. **Fast path:** if the stored and new view values are of the same type, that type is `Equatable` (or wrapped in `EquatableView`), and they compare equal, stop — the entire subtree is unchanged. Flags already set remain set.
3. **Type check:** if the dynamic type differs from the stored one, destroy the node's subtree (running focus cleanup) and build fresh at the same slot. Record in statistics.
4. **Leaf:** if the view is a `LeafView`, store the new value, mark `needsRender` (and `needsLayout` — leaves cannot cheaply prove their size is unchanged; the layout memo makes this cheap anyway).
5. **Structural:** if the view is `TupleView` / `ConditionalView` / `Optional` / `ForEach` / a modifier wrapper, diff children by slot per the identity rules: matching slots recurse; missing slots are destroyed; new slots are built. `ForEach` matches by id, preserving nodes across reorders (moves are reorders of the child array, not destroy/create).
6. **Composite:** otherwise evaluate `body` once and recurse into the single `.body` child.

Body evaluation happens **only** inside this pass. Layout and render never call `body`. Every view gets a node (composites included) so identity paths, environment scoping, and `dump()` reflect the structure the user wrote, not a flattened soup.

The reconciler operates on `any View` existentials, opened via generic helper functions (`func reconcile<V: View>(_ view: V, …)` dispatched through a small number of `as? any LeafView`-style checks). This is the honest cost of having no compiler support; at terminal scale (hundreds of nodes, not hundreds of thousands) it is well within budget, and `statistics` keeps it observable.

## Environment

```swift
public protocol EnvironmentKey {
    associatedtype Value
    static var defaultValue: Value { get }
}

public struct EnvironmentValues {
    public init()
    public subscript<K: EnvironmentKey>(key: K.Type) -> K.Value { get set }
}

extension View {
    public func environment<V>(
        _ keyPath: WritableKeyPath<EnvironmentValues, V>, _ value: V
    ) -> some View
}
```

Implementation: copy-on-write storage keyed by `ObjectIdentifier`. The `.environment` modifier node stores the override; children snapshot the resolved environment during reconciliation. Changing an environment value marks the subtree below the modifier dirty. Built-in keys land with the features that need them (`defaultStyle` in slice 3, `isFocused`-adjacent values in slice 4).

There is no `@Environment` property wrapper in slice 1. Composite views receive environment explicitly via `EnvironmentReader` (a view whose body closure is handed the resolved `EnvironmentValues`); leaves receive it as a parameter. A property-wrapper sugar can be added later without changing the model — keep the explicit reader as the canonical mechanism.

## Slice 1 primitives

- `Text(String)` — measures grapheme display width per line (Phase 2 Slice 4 width tables), renders top-left into its region, truncates per line at the region edge. No wrapping yet (slice 3). Styling parameter exists (`Text("hi", style: …)`) but the fluent style story is slice 3.
- `EmptyView` — zero size, renders nothing.
- Interim composition rule, replaced in slice 2: a node with multiple children stacks them vertically at x=0, each child proposed the full width and its own measured height. This is explicitly temporary scaffolding so slice 1 ships something visible; it must not grow options.

## Tests

- Reconciler unit tests, no terminal: build a tree, `update()` with mutated inputs, assert created/destroyed/updated counts and identity paths via `statistics` and `dump()` golden snapshots. Cover: tuple reorder (destroys), `ForEach` reorder (preserves), branch switch (destroys), `.id` change (destroys), duplicate explicit IDs under different parents (distinct), `Equatable` fast path (zero child body evaluations), and `AnyView` barrier.
- Work-accounting tests: `bodyEvaluations`, equatable skips, `sizeThatFits` calls, and rendered-node counts change only when the documented pass semantics say they should.
- Import-boundary architecture test: view-layer source files do not import `TesseraTerminalIO`, platform IO shims, SwiftUI, AppKit, or UIKit.
- `NodeState` lifetime tests: a test leaf whose `NodeState` counts renders proves state survives updates and dies on identity change. Widget-shaped tests cover cursor/scroll state surviving keyed `ForEach` moves and dying on branch, type, or `.id` changes.
- Render tests through the existing harness: `ViewGraph` → `Frame`/`Buffer` → `VirtualTerminal` snapshot, including clipping (write past region edge), paint order, and a wide grapheme straddling a clip boundary.
- An `Examples/Counter` app updated to the declarative API, driven by the canonical loop above.

## Definition of done for slice 1

1. `View`, `ViewBuilder`, structural views, `LeafView`, `RenderRegion`, `EnvironmentValues`, `ViewGraph` exist in `TesseraCore` with the shapes above.
2. The reconciliation algorithm matches the six numbered steps and has tests for each identity rule.
3. `graph.dump()` and `statistics` output is stable enough to snapshot and shows identity, type, proposal, measured size, frame, dirty flags, handlers, focus state, terminal requirements, and pass work counters per node/subtree.
4. The public immutable diagnostics snapshot records the most recent completed pass with the normative graph, geometry, handler, requirement, and reconciliation fields; its read-only inspector boundary forbids mutation, pass triggering, serialization, persistence, logging, telemetry, remote transport, and raw controlled-value capture.
5. The source import-boundary test passes for the view-layer source roots.
6. A declarative example app renders through a real `TerminalSession` on macOS/Linux.
7. No `Sendable` conformances were added to views, nodes, or the graph.

## Things to flag

1. **Parameter-pack `TupleView` is a toolchain bet.** Validate pack iteration in the reconciler early in the slice; fall back to generated fixed arity if it fights back.
2. **`AnyView` is an identity barrier by design.** Document it loudly; do not try to be cleverer than SwiftUI here.
3. **Resist adding `@State` "just for demos."** The moment it exists, the architecture-agnostic story is dead. Demos use a plain model object and the loop.
4. **Do not use SwiftUI as Tessera's oracle.** SwiftUI informs API feel, but Tessera's correctness oracle is this spec plus exact terminal-cell tests.

---
