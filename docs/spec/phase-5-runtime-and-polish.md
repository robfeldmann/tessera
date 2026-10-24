---
type: spec
description: "Phase 5 — Runtime + polish"
---

# Phase 5 — Runtime + polish

- The immediate-mode API (Ratatui-shaped: you own the loop, call `terminal.draw { … }`)
- The optional convenience loop (UIKit/SwiftUI-shaped event delivery, responder routing, focus, invalidation, and render scheduling)
- Example apps (counter, file browser, chat client, etc. — these double as integration tests)
- DocC tutorial content
- Performance pass (profiling, capacity reservation, the `@inlinable` work, etc.)
- Windows snapshot-test story (the macOS/Linux direct libghostty-vt build from Phase 2 Slice 1 already runs in CI; Windows is the remaining gap)
- 1.0 release prep

## Runtime isolation

**Decision.** An app, the `ViewGraph` that lowers its views, and the loop that steps them live in one isolation domain: the host's. The terminal session stays its own actor and receives finished frames. `TerminalSession.draw` runs its render body in the caller's isolation and commits the result on the session, so a host on any actor renders a graph that lives with it. The optional runtime and the harness are main-actor hosts; a hand-written loop keeps whatever isolation its author chose, including the session's. The app contract carries no isolation of its own: a nonisolated app runs on any host, and an app whose model is main-actor isolated declares a main-actor isolated conformance that only a main-actor host can use.

**Why.** Isolation has to live somewhere; the question is where. Putting it on the app contract (a `@MainActor` protocol) would force every demo, test, and hand-written loop onto the main actor. Putting the app inside the session actor, as the examples do today, would exclude every model that is main-actor isolated, which is what TCA's `Store` and every type in a default-main-actor module are, and would contradict the [ownership thesis](ownership-and-isolation-thesis.md) ("users remain free to bring TCA or any other state architecture") and the [Phase 4 design](phase-4.md) ("the optional `@MainActor` runtime in Phase 5"). Putting it on a thin host, and passing it into the shared step as a parameter, lets the compiler prove the one rule that matters: an app is only ever touched from its host's isolation. Every mismatch below is a compile error; nothing is an `assumeIsolated` or a `nonisolated(unsafe)`.

### Where isolation lives

```text
app code                  Application (reference type; nonisolated, or a main-actor isolated conformance)
                          ViewGraph (non-Sendable; owned by the host)
   ─── one isolation: the host's ───────────────────────────────────────────────────────────
host                      ApplicationRuntime (@MainActor) · harness scenarios (@MainActor)
                          per-test actor hosts (Tessera's own nonisolated demos) · hand-written loops (any)
   ─── draw(): body in the host's isolation; Buffer crosses ──────────────────────────────
terminal                  TerminalSession (actor): modes, size, diff, bytes, input queue
```

| Layer | Isolation | Owns | Crosses the boundary as |
| --- | --- | --- | --- |
| `Application` | none required: nonisolated, or `@MainActor` through an isolated conformance | its model | never; the host constructs it and keeps it |
| `ViewGraph` | the host's; non-`Sendable`, created by the host | nodes, `NodeState`, focus, environment, the clock | never |
| the canonical step | nonisolated code with an `isolated any Actor` parameter; the host passes its own | nothing | n/a |
| `ApplicationRuntime`, the harness | `@MainActor` | the app, the graph, the loop, app effects | `TerminalSession` (an actor, `Sendable`) |
| `TerminalSession` | its own actor | terminal authority: modes, size, the last drawn buffer, the renderer, bytes, the input queue | `Buffer`, `TerminalPosition?`, `InputEvent` (values); `events` is a `nonisolated let` stream |

### The app contract

```swift
public protocol Application: AnyObject {
  associatedtype Body: View
  @ViewBuilder var body: Body { get }   // the root view; reads the model, hands out Bindings
  func apply(_ event: InputEvent)       // each event the graph left .ignored; resizes always
  var isFinished: Bool { get }          // default false; the host stops after the step that sets it
}
```

The protocol refines nothing but `AnyObject`. It is not `@MainActor`, and it does not refine `SendableMetatype`: that refinement would forbid isolated conformances (SE-0470), which are the compile-time proof this design rests on. The app is a reference type because `body` reads the model and hands out `Binding`s that write back to it.

### The canonical step

One function, nonisolated, takes the host's isolation as a parameter and runs the loop of [slice 1](phase-4/slice-01-tesseracore.md) once. The runtime and the harness both call it; it is not public at 1.0.

```swift
@discardableResult
static func run<App: Application>(
  _ app: App, graph: ViewGraph, event: InputEvent, isolation: isolated any Actor
) -> EventDisposition {
  var isResize = false
  if case .resize(let size) = event {
    isResize = true
    graph.resize(to: size)
  }
  let disposition = graph.dispatch(event)
  if disposition == .ignored || isResize { app.apply(event) }   // slice 4: the app decides what unhandled events mean
  graph.update()
  return disposition
}
```

The `isolated` parameter is what makes the proof work. A main-actor host passes `MainActor.shared`, so a main-actor isolated conformance is accepted; an actor host passes `self`, and the same conformance is rejected at the call site. `Task`s the step may start in Phase 5 (app effects) are created inside this isolation and stay in it. There is no optional `#isolation` default: a nonisolated caller cannot compile the call.

### Adopting it

The conformance is declared where the type is declared, so isolation inference and the conformance agree. The four shapes:

```swift
// 1. A plain class. Runs on any host, including a per-test actor.
final class Counter: Application {
  private(set) var count = 0
  var body: some View { Text("Count: \(count)") }
  func apply(_ event: InputEvent) {
    if case .key(let key) = event, key == Key(code: .character("+")) { count += 1 }
  }
}

// 2. An @Observable model. Same as 1; observation lives on the model, not on the host.
@Observable final class Counter: Application { /* as above */ }

// 3. A module with `.defaultIsolation(MainActor.self)` (Xcode 26 app templates). Nothing to
//    write: the type is main-actor isolated by inference and so is its conformance. It runs on
//    the runtime and the harness; it may touch any other main-actor type in its module.
final class Notes: Application {
  let store = NotesStore()               // another main-actor class in the module
  var body: some View { Text("\(store.saved) saved") }
  func apply(_ event: InputEvent) { store.save() }
}
//    The same module, when one app should also run on per-test actors: opt that type out.
nonisolated final class Tool: Application { /* nonisolated members */ }

// 4. A main-actor store (TCA's `Store` is `@MainActor`). Declare the conformance isolated.
@MainActor final class Browser: @MainActor Application {
  let store: StoreOf<BrowserFeature>
  var body: some View { Text("\(store.items.count) items") }
  func apply(_ event: InputEvent) { store.send(.input(event)) }
}
```

When production code must stay free of the contract, a test or dev target adopts it with the isolation the type has: `extension Counter: Application {}` for a nonisolated type, `extension Notes: @MainActor Application {}` for a main-actor one. Writing `@MainActor` on the conformance is accepted in every mode. Leaving it off depends on the compiler mode of the module that writes the extension, not on which module declares the type. In plain Swift 6 mode it is a compile error ("conformance of 'Notes' to protocol 'Application' crosses into main actor-isolated code and can cause data races"), not a trap. With the `InferIsolatedConformances` upcoming feature, or with default main-actor isolation in the extension's module, the compiler infers the isolated conformance instead and the line compiles. One corner differs by toolchain: under `InferIsolatedConformances` alone, Swift 6.3 infers it for a type declared `@MainActor` but not for a type that is main-actor isolated only through its own module's default isolation, while Swift 6.4 infers both. Either way no path is a runtime trap.

### The runtime

The runtime is the one isolation annotation around an app: a `@MainActor` class that owns the app and the graph, pumps the session's events, runs the canonical step, and presents through `draw`. Its `init` and `run` are the whole public shape at 1.0.

```swift
@MainActor
public final class ApplicationRuntime<App: Application> {
  public init(app: App)
  public func run(configuration: TerminalApplicationConfiguration = .default) async throws
}

@main
struct BrowserMain {
  @MainActor static func main() async throws {
    try await ApplicationRuntime(app: Browser()).run()
  }
}
```

Inside, `run` opens the session with `withApplicationTerminal` and hands its scope a main-actor function value, not the generic runtime, so the app's conformance never leaves the main actor (Swift 6.4 diagnoses the direct form: "conformance of 'App' to protocol 'Application' may be isolated and cannot be passed to main actor-isolated context"). The loop is the canonical loop:

```swift
private func loop(in session: TerminalSession) async throws {
  var size = TerminalSize(columns: 80, rows: 24)          // corrected by the first frame
  let graph = ViewGraph(root: { [app] in app.body }, size: size)
  try await session.draw { frame in
    if frame.size != size { size = frame.size; graph.resize(to: size) }
    graph.render(into: frame)
  }
  for await event in session.events {
    Step.run(app, graph: graph, event: event, isolation: MainActor.shared)
    if graph.needsRender { try await session.draw { frame in graph.render(into: frame) } }
    if app.isFinished { return }
  }
}
```

What the runtime adds beyond the step is additive and arrives as a requirement with a default or as runtime configuration, never as a change to `apply`: a Tab focus policy the app opts into ([slice 4](phase-4/slice-04-focus-and-key-routing.md)), render scheduling and redraws driven by the aggregated tick requirement ([motion views](phase-4/motion-views-and-the-tick-requirement.md)), and a path for app work that completes after `apply` returns. That work is an effect: enqueued during `apply`, started after the step in the runtime's isolation, resumed there, and it edits the model without an `await`. Handlers stay synchronous inside `dispatch` (slice 4).

### The session

`draw` becomes caller-isolated. The signature loses `sending` on both the body and the result, which is a relaxation: every existing caller compiles unchanged.

```swift
nonisolated(nonsending)
public func draw<R>(_ body: (borrowing Frame) throws -> R) async throws -> R
```

Its transaction, in order: acquire the draw gate (on the session); begin the frame on the session (`checkOpen`, read the size, fix the rendering policy for this frame: color capability, hyperlinks, synchronized output, underline); allocate the frame storage and run `body` synchronously in the caller's isolation; commit on the session (`checkOpen` again, since the session's scope can have closed while the body ran; then encode the diff against the last drawn buffer, write, flush, record `lastDrawn`); release the gate. The policy commit point keeps its meaning: it follows the size suspension and precedes the body, so no setter can affect a frame once its bytes begin to be constructed. The `Buffer` and cursor that cross into the commit are values. A caller inside the session's isolation (`isolated TerminalSession`, today's examples) runs the body on the session and hops nowhere; a main-actor caller renders on the main actor and hops once to commit.

Everything else in the session is unchanged: `events` is already a `nonisolated let` stream a main-actor loop consumes directly; `withApplicationTerminal` still scopes the session's isolation around its body. A caller-isolated `withApplicationTerminal` overload is a convenience this phase may add; the runtime does not need it.

The session may later adopt the runtime's executor so the commit hop is free; that is a performance-pass option that changes no contract above.

### The harness

The harness is a main-actor host over the same step, so it drives every app shape the runtime does, headless through a session over an in-memory device and live in a terminal. Registry factories are main-actor closures, `register(_ name: String, make: @escaping @MainActor () -> App)`, opened on the main actor; a `@Sendable` factory for a main-actor app is a compile error at the registration site. Tessera's own nonisolated demos may additionally be stepped on per-test actors inside the package, one actor per test, for parallel suites; that shell is not public.

### Supported at 1.0

Supported: the four shapes above, on the runtime, on the harness, and in hand-written loops of any isolation, including the session's; conformances declared with the type or in a test target with matching isolation; `@Observable` models with the re-render driven by the loop ([state model](phase-4/state-model.md)).

Not supported, each a compile error: hosting a main-actor app on a non-main actor (a per-test actor, the session); a conformance isolated to any global actor other than the main actor, since the hosts are main-actor; sending an app or a graph between hosts (both are non-`Sendable`); touching a main-actor app from nonisolated code. One app instance belongs to one host.

Unchecked constructs on these paths: none for isolation. `draw` keeps its one memory vouch, the heap storage the borrowed `Frame` views, with the invariant that the body runs synchronously, without suspension, while the frame is live.

### Testing posture

Tests assert at a moment the design guarantees, never after a sleep.

- A host's step is synchronous. When it returns, `apply` has run, the graph is updated, and the headless screen is rendered; the test reads state or screen at once. A scenario statement is one step.
- Runtime and harness tests run in a `@MainActor` suite; Tessera's nonisolated demos also run on per-test actor hosts, which keeps that suite parallel.
- `draw` returns when the frame is committed. A loop awaits it; a test over a real session awaits it; nothing yields to "let the UI catch up".
- Effects (Phase 5 app work) start after the step and run in the host's isolation; a test joins the task the step returns, and `settle` is a bounded drain against the injected clock, as the clock section below says.
- Isolation itself is pinned by compile-fail fixtures beside `Tests/CompileFailFixtures/`: an actor host given a main-actor app, and a default-main-actor type adopted from another module without `@MainActor` on the conformance. No exit tests are needed, because no path carries an `assumeIsolated`.

### Rejected

- `@MainActor protocol Application`: puts every app, demo, test, and hand-written loop on the main actor and removes parallel testing; today's `isolated TerminalSession` loops could not adopt it.
- `Application: SendableMetatype`: forbids isolated conformances, so TCA-shaped apps and default-main-actor apps are excluded for the whole 1.x line; dropping it later flips the inferred isolation of adopters in default-main-actor modules.
- The app inside the session's isolation (today's examples, the archived gallery): the same exclusion, and the runtime could not be `@MainActor` as the thesis promises.
- The session borrowing the main actor's executor: removes the hop but not the static boundary; `draw`'s closure would still have to be sent.
- A public two-step `beginFrame() -> Buffer` / `commit(_:)`: the same mechanics as `draw`'s new transaction, but it exposes the buffer and loses the borrowed, non-escapable `Frame`.
- `ApplicationScene` plus `EventResponder` driven by `TestRuntime(scene:terminal:)`: a second contract that does not compile and has no path for unhandled events or quitting.
- `assumeIsolated` in a host so an actor can run a main-actor app: a vouch where a compile-time proof exists.

Timers, animations, debounce, and delayed work use injected clocks, not wall-clock sleeps. SnapshotTesting remains a good fit for deterministic output.

**Open question for Phase 5:** how to supply those injected clocks. Two options:

1. The project's owned-seam pattern — a `live` value with a task-local test override, as `TesseraTerminalIO` already does for its syscall surface.
2. Reintroduce Point-Free's `swift-clocks`/`TestClock` (and `swift-dependencies`) for this layer.

Current lean is the owned-seam pattern: the low-level `TesseraTerminal` modules should avoid a third-party DI dependency, and `swift-dependencies` did not earn its keep in the snapshot harness (see its removal). Reintroducing a third-party dependency for clocks should be a deliberate decision made when Phase 5 lands, not assumed here.

**End of Phase 5:** Tessera 1.0.
