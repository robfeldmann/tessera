---
type: spec
description: "Phase 5 — Runtime + polish"
---

# Phase 5 — Runtime + polish

- The immediate-mode API (Ratatui-shaped: you own the loop, call `terminal.draw { … }`)
- The optional convenience loop (UIKit/SwiftUI-shaped event delivery, responder routing,
  focus, invalidation, and render scheduling)
- Example apps (counter, file browser, chat client, etc. — these double as integration
  tests)
- DocC tutorial content
- Performance pass (profiling, capacity reservation, the `@inlinable` work, etc.)
- Windows snapshot-test story (the macOS/Linux direct libghostty-vt build from Phase 2
  Slice 1 already runs in CI; Windows is the remaining gap)
- 1.0 release prep

Runtime isolation rules to make explicit before building this phase:

```swift
@MainActor
public protocol ApplicationScene {
    associatedtype Body: View
    borrowing var body: Body { get }
}

@MainActor
public protocol EventResponder {
    mutating func handle(_ event: InputEvent, context: borrowing ResponderContext) -> EventRouting
}
```

The optional runtime is isolated to `@MainActor` for familiarity with Apple's UI
ecosystem. It owns UI concerns such as event delivery, responder routing, focus,
display/layout invalidation, and render scheduling. It does not own the app's business
model and does not require a Tessera-specific `State`/`Action`/`Effect` architecture.
Runtime contexts expose only UI-scoped capabilities and cannot expose mutable app state, a
`Frame`, raw terminal handles, or arbitrary terminal writes. Rendering still happens only
in `draw {}` with a borrowed `Frame`.

Tests should drive the runtime with explicit events and explicit render steps. Do not make
snapshot tests depend on `Task.yield()` or sleeps to "let the UI catch up." Use injected
clocks for delayed work and explicit terminal snapshots for render assertions.

A runtime test harness should define precise units of work:

```swift
let terminal = TestTerminal()
let runtime = TestRuntime(scene: CounterScene(), terminal: terminal)

await runtime.step(.key(.character("+")))
#expect(terminal.snapshot == expected)
```

`step` should deliver one event, process resulting synchronous UI work, coalesce
invalidations, perform at most one render pass if needed, then return. A bounded drain is
acceptable for work that schedules more work, but an unbounded "drain until idle" is a
smell because work can schedule more work forever:

```swift
try await runtime.drain(maxSteps: 100)
```

Timers, animations, debounce, and delayed work use injected clocks, not wall-clock sleeps.
SnapshotTesting remains a good fit for deterministic output.

**Open question for Phase 5:** how to supply those injected clocks. Two options:

1. The project's owned-seam pattern — a `live` value with a task-local test override, as
   `TesseraTerminalIO` already does for its syscall surface.
2. Reintroduce Point-Free's `swift-clocks`/`TestClock` (and `swift-dependencies`) for this
   layer.

Current lean is the owned-seam pattern: the low-level `TesseraTerminal` modules should
avoid a third-party DI dependency, and `swift-dependencies` did not earn its keep in the
snapshot harness (see its removal). Reintroducing a third-party dependency for clocks
should be a deliberate decision made when Phase 5 lands, not assumed here.

**End of Phase 5:** Tessera 1.0.
