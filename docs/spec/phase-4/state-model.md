---
type: spec
description: "State model: bring your own"
---

# State model: bring your own

- **Composite views are pure.** `body` is a function of values the app passed in. No
  `@State`, no `@StateObject`, no property-wrapper storage smuggled into structs.
- **`Binding` is the controlled-widget seam.** A minimal value:

  ```swift
  @propertyWrapper
  public struct Binding<Value> {
      public var wrappedValue: Value { get nonmutating set }
      public init(get: @escaping () -> Value, set: @escaping (Value) -> Void)
      public static func constant(_ value: Value) -> Binding<Value>
      public var projectedValue: Binding<Value> { get }
  }
  ```

  No graph plumbing, no transactions. It is two closures. TCA bindings, `@Observable`
  references, and plain `inout`-style closures all adapt to it in one line.

  Controlled widget ownership is fixed before implementation. A controlled initializer
  receives the app's `Binding`, never an initial value to retain; an action is an
  app-supplied escaping closure invoked only for the documented user interaction:

  ```swift
  public init(
      role: ButtonRole? = nil,
      action: @escaping () -> Void,
      @ViewBuilder label: () -> Label
  )

  public init(
      text: Binding<String>,
      prompt: String? = nil,
      onSubmit: (() -> Void)? = nil,
      @ViewBuilder label: () -> Label
  )
  ```

  These are `Button.init(role:action:label:)` and
  `TextField.init(text:prompt:onSubmit:label:)`. `ScrollView` retains its catalog
  `init(_:offset:content:)` signature with optional `Binding<TerminalPosition>`. `Toggle`,
  `Picker`, `Stepper`, `List`, and `Table` likewise accept their catalog-defined bindings
  rather than copying controlled values into `NodeState`.

- **`NodeState` is for ephemeral UI internals only.** Leaf primitives and widgets may
  declare node-local state (cursor index, scroll offset, marquee phase) that lives on the
  `RuntimeNode`, keyed by identity, passed `inout` to the primitive's methods. It survives
  updates while identity survives, and dies with the node. It must never hold business
  state.
- **Every piece of widget state has exactly one of four homes.** A catalog doc's State
  model table names the home for each row
  ([State model table](../../design.md#state-model-table)):
  1. **App-owned `Binding`.** Data the user produces, or that the app must read or persist
     (text, a checked value, a selection, expansion, an active tab, pane sizes, a sort
     order), is an app-owned `Binding` that the initializer takes. The widget writes it
     only on its documented interaction and never retains an initial value.
  2. **Initializer parameter.** Data the app supplies for display (a progress value,
     source text, an image source) is a plain parameter, redeclared on every update and
     never copied into widget state.
  3. **`NodeState`.** Position and interaction in flight (a cursor, a scroll position no
     binding owns, a caret, a pressed or open flag, an uncommitted draft) is `NodeState`.
     Losing it loses position or unfinished input, never committed data; anything whose
     loss would lose data is a `Binding`.
  4. **Graph-owned.** Focus, hover, the clock, and environment values belong to the graph.
     A view reads them through the environment or derives them during layout or render,
     and never mirrors them into `NodeState`.
- **Re-render is externally driven.** The app mutates its state, then calls
  `graph.update()` (directly, or via the Phase 5 runtime). Integration recipes that belong
  in DocC, not in the core API:
  - `@Observable`: wrap `update()` in `withObservationTracking`, re-arm on change.
  - TCA: observe the store; on state change, call `update()`.
  - Plain loop: call `update()` after every handled event. Unconditional update is always
    correct; reconciliation makes it cheap.
