---
type: spec
description: "Slice 4: Focus and key routing (the responder system)"
---

# Slice 4: Focus and key routing (the responder system)

## What this slice proves

Input routing is explicit and inspectable: there is a focus list you can print, a documented routing order, and nothing else.

Plan 032 Phase 10 delivers this slice: focus identity, traversal, and responder routing (step 10.1), focus appearance and focus scopes (10.2), and `KeyLegend` from declared key bindings (10.3). The keyboard paths of components are this slice's contract too, but land with the components: ScrollView in Phase 12, the controls in Phase 13, and SplitView in Phase 15.

## Focus model

```swift
public struct FocusID: Hashable, Sendable {
    public init(_ value: some Hashable & Sendable)
}

public final class FocusManager {
    public private(set) var focused: FocusID?
    public func focus(_ id: FocusID?)                  // nil = clear
    public func advance(_ direction: FocusDirection)   // .forward / .backward, wraps
    public var focusableIDs: [FocusID] { get }          // document order (DFS)
}

extension View {
    public func focusable(_ id: FocusID) -> some View
    public func focused(_ binding: Binding<FocusID?>, equals id: FocusID) -> some View
}
```

Focus IDs are explicit. Auto-derived focus identity is a footgun (it silently changes when structure changes); requiring an ID is one argument and removes a whole bug class. The focus order is the depth-first document order of `.focusable` nodes after layout — `focusableIDs` _is_ the debug tool. Only placed nodes count: a node its parent never places, such as an unchosen `ViewThatFits` candidate, is not in `focusableIDs`. When the focused node leaves the focus order, focus clears to `nil` and the graph records it in `statistics`; it does not guess a neighbor. That check runs after every layout pass, a resize included, not only after an update.

**No implicit Tab handling.** The graph never swallows keys. The app (or the Phase 5 runtime, as a default policy) opts in:

```swift
content.onKey(.tab) { context in context.focusAdvance(.forward) }
       .onKey(.shift(.tab)) { context in context.focusAdvance(.backward) }
```

## Event routing (normative)

`graph.dispatch(event)` for a key event:

1. If a focused node exists, deliver to its `handleEvent` (leaf/widget) and its `.onKey` handlers, innermost first.
2. While `.ignored`, bubble through ancestors' handlers up to the root.
3. Return the final disposition; the app decides what unhandled events mean (quit keys, global shortcuts). The graph never exits the process.

Non-key events: `.resize` is the app's job to forward to `resize(to:)`; paste events route like key events to the focused node; mouse is slice 5; focus-in/out terminal events are surfaced as graph-level callbacks, not routed.

## Handler modifiers and `ResponderContext`

```swift
extension View {
    public func onKey(
        _ handler: @escaping (KeyEvent, inout ResponderContext) -> EventDisposition
    ) -> some View
    public func onKey(_ pattern: KeyPattern,
                      perform: @escaping (inout ResponderContext) -> Void) -> some View
}

public struct ResponderContext: ~Copyable {
    public mutating func setNeedsDisplay()
    public mutating func setNeedsLayout()
    public mutating func focus(_ id: FocusID?)
    public mutating func focusAdvance(_ direction: FocusDirection)
    public var nodeBounds: Rect { get }
    public var isFocused: Bool { get }
}
```

`KeyEvent`/`KeyPattern` build on Phase 2 Slice 5's `Key`/`Modifiers`. `ResponderContext` deliberately cannot render, cannot reach a `Frame`, cannot touch terminal modes, and cannot see app state — it is UI-scoped capability lending, per the ownership thesis. Handlers run synchronously inside `dispatch`; async work belongs in the app's own machinery after `dispatch` returns.

## Focus appearance, focus scopes, and declared key bindings

Focus appearance is delegated: a focus-appearance host, such as a bordered container or a control that paints its own focus cue, applies the Slice 3 focus border while focus is on it or within it. A focus scope traps traversal inside an overlay: `focusAdvance` cycles within the scope while it is presented, and dismissing the overlay restores focus to where it was ([docs/design/inbox.md](../../design/inbox.md)).

Responders declare the keys they handle, each with a short description. A declaration describes a handler that exists; it installs no behavior and remaps no key, so the graph still routes without interpreting. [`KeyLegend`](../../design/widgets/key-legend.md) renders the focused responder chain's declared bindings, `plain` by default with `keycaps` as an option, and drops whole entries by priority when narrow. Plan 032 step 10.3 settles the Swift spellings.

## Terminal requirements aggregation

```swift
public struct TerminalRequirements: Sendable, Equatable {
    public var wantsKeyboardEnhancement: Bool   // Kitty protocol, if available
    public var wantsMouse: Bool                 // set by slice 5 handlers
    public var wantsMouseMotion: Bool           // slice 5 hover handlers and row hover
    public var wantsBracketedPaste: Bool
    public var wantsFocusReporting: Bool
    public static func union(_ a: Self, _ b: Self) -> Self
}
```

Recomputed during reconciliation as the union over live nodes (an `.onTap` anywhere ⇒ `wantsMouse`). Live means present in the graph, not placed: because requirements are recomputed before layout chooses, an unchosen `ViewThatFits` candidate or a Table scrolled out of view still contributes, a resize never toggles a terminal mode, and a component that requests a mode "while it is on screen" requests it while it is live. The app forwards `graph.terminalRequirements` to the session, which checks capabilities/configuration and applies deltas through `ModeLifecycle`. Views still never touch modes; this is the declarative-requirements design from the ownership thesis made concrete.

## Controls and focused viewport interaction

[`Button`](../../design/widgets/button.md), `Toggle`, `Picker`, `MultiPicker`, and `Stepper` are controlled responders (plan 032 Phase 13): their catalog-owned contracts receive current values through `Binding` and report a user action by writing that binding or invoking their documented action. The graph supplies focus and routing only; it never manufactures a model value or interprets an unhandled key.

[`TextField`](../../design/widgets/text-field.md) lands whole in plan 032 step 13.4, on a shared text editing core (grapheme-safe cursor, selection, and reveal). It participates in document-order focus, receives focused key and paste routing, and requests redraw through `ResponderContext`; its controlled editing contract is in Slice 7. This preserves the rule that `NodeState` contains only ephemeral UI state.

The Slice 2 [`ScrollView`](../../design/widgets/scroll-view.md) viewport gains keyboard movement in plan 032 Phase 12. Focused movement changes its controlled offset (or its ephemeral offset where the catalog permits one) and clamps it to content bounds; the viewport takes focus only while it can scroll, and moving focus into hidden content scrolls that content into view. The [`SplitView`](../../design/widgets/split-view.md) divider gains focused keyboard resize in plan 032 Phase 15, writing its controlled pane state through Phase 2.5's final negotiation.

## Tests

- Routing tables: synthetic trees with recording handlers; assert exact delivery order for focused/bubble/unhandled cases.
- Focus lifecycle: advance wraps both directions; focused-node removal clears focus; `focusableIDs` matches document order across relayouts.
- Requirements aggregation: adding/removing an `.onTap`-bearing subtree toggles `wantsMouse` across updates.
- All driven through `graph.dispatch` with constructed `InputEvent`s — no terminal, no sleeps, no `Task.yield()`.

## Definition of done for slice 4

1. `FocusManager`, `focusable`, `focused`, `onKey`, `ResponderContext`, `EventDisposition` ship with the normative routing order tested.
2. No key is consumed by the graph without a user-installed handler.
3. Button, Toggle, Picker, MultiPicker, Stepper, TextField, ScrollView keyboard movement, and focused-divider SplitView keyboard resize obey their controlled binding and routing rules.
4. `TerminalRequirements` aggregation works end-to-end against a real `TerminalSession` in the focus demo (focus two widgets, Tab between them).
5. A focus scope traps traversal and restores focus on dismissal, and `KeyLegend` renders the focused chain's declared bindings.

## Things to flag

1. **Resist a global keymap table in the graph.** Key→action indirection belongs in apps (or a future opt-in module). The graph routes; it does not interpret.
2. **`handleEvent` on `LeafView` vs `.onKey` ordering** (leaf first, then its wrapping handlers, then ancestors) must be pinned by a test — it is the kind of rule that silently flips during refactors.

---
