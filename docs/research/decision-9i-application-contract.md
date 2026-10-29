---
type: research
observed: 2026-10-23 # citations hold at main 9325271; the spike ran on origin/main 3b05863, which differs only by a dependency bump
status: resolved
description: Decision 9 (i) — how an app hands itself to TesseraHarness, and which harness names and contracts carry a 1.0 promise.
---

# Decision 9 (i): the app contract and the harness's 1.0 surface

> Resolved 2026-10-23: the owner decided Decision 9 (i) as `Application: AnyObject` in a `TesseraRuntime` module created in Phase 4 (no `SendableMetatype`, no `@MainActor`, `@MainActor` hosts and registry factories, no host quit key, no public stepping API), the stable surface below, and the `tessera` CLI (`tessera apps`, `tessera launch NAME`, `tessera run PATH...`) in place of `tessera-dev` and `app list|run`; the spec's [Runtime isolation](../spec/phase-5-runtime-and-polish.md#runtime-isolation) section supersedes the text below wherever they differ, and [plan 036](../plans/phase-4-view-layer-and-developer-tooling.md) records the decisions.

Claims with a `path:line`, a command, or a quoted compiler message were observed. Claims marked [INFERENCE] were not. Links are relative to `docs/research/`, where this record would live as `decision-9i-app-contract.md`; the amendment texts link it by that name and date the decision 2026-10-23, to be changed to the day the owner accepts it.

## Question

How does an app hand itself to `TesseraHarness` so the harness can drive it headlessly (and live, for dev runs and live inspection), and which harness names carry a 1.0 stability promise? Plan 036 defers this to the start of Slice 3 ([plan 036](../plans/phase-4-view-layer-and-developer-tooling.md), line 200) and names two candidates: `HeadlessApp` as plan 036 and plan 033 design it, or the Phase 5 runtime's scene driven by `TestRuntime(scene:terminal:)`. The answer must say which shape app authors adopt, exactly which public names exist at 1.0 and what "stable" covers, and what Slices 2-5 and the Phase 5 spec must say, without foreclosing Slice 15 (the schedulable clock) or Decision 9 (iii) (how an app gets `tessera-dev`).

## Candidates

- **A. `HeadlessApp` as designed.** `protocol HeadlessApp: AnyObject { associatedtype Root: View; init(); var root: Root { get }; func apply(_ event: InputEvent, disposition: EventDisposition) }` in `TesseraHarness`, with `Demo: HeadlessApp` adding `name`, `minimum`, and `fixtures` ([plan 033](../plans/developer-tooling.md), lines 66-82). The `Driver` steps resize → `graph.dispatch` → `apply` → `graph.update()` → `TerminalSession.draw`, and live and headless share it ([plan 036](../plans/phase-4-view-layer-and-developer-tooling.md), line 71; [Developer tooling](../architecture/developer-tooling.md), lines 85-87). Quit is a host rule, `DemoHost.isQuitKey`.
- **B. The Phase 5 scene.** `@MainActor protocol ApplicationScene { associatedtype Body: View; borrowing var body: Body { get } }` and `@MainActor protocol EventResponder { mutating func handle(_:context: borrowing ResponderContext) -> EventRouting }`, driven by `TestRuntime(scene:terminal:)` with `step` and `drain(maxSteps:)` ([Phase 5](../spec/phase-5-runtime-and-polish.md), lines 18-49). Phase 5 is not built.
- **C. A closure value (added).** No protocol: the harness takes the canonical loop's two inputs as a value, `HarnessApp(root: { … }, apply: { event in … })`, the same shape `ViewGraph(root:size:environment:)` already takes (`Sources/TesseraCore/Runtime/ViewGraph.swift:63-72`).
- **D. `Application`, harness now, runtime in Phase 5 (added; recommended).** One protocol whose requirements are the canonical loop's inputs plus a finish flag, written only in `Tessera` types, refining `SendableMetatype`; it lives in `TesseraHarness` during Phase 4, and Phase 5 moves it to `TesseraRuntime`, which `TesseraHarness` re-exports, so the Phase 5 runtime hosts the same protocol and adopting code does not change.
- **E. `Application` in a product module from Phase 4 (added).** As D, but `TesseraRuntime` (or `TesseraCore`) is created now holding only the protocol, so it never moves.

## Evidence

### Spike

Location: `/Users/rob/Developer/robfeldmann/tessera/decision-9-spike/spikes/Decision9/` (a detached worktree of `origin/main` at `3b05863`; nothing committed, nothing in `main` touched). Its `README.md` lists hypotheses, layout, commands, and results. It depends on Tessera by path and uses public API only. `Sources/Contract` holds candidate D: `Application`, `Viewport`, `ApplicationRegistry`, one `Driver`, a `HeadlessHost` (through `VirtualTerminal.snapshot`, as spike 1 did) and a `LiveHost` (through `TerminalSession.draw` inside `withApplicationTerminal`).

Commands, run with `DEVELOPER_DIR` set to Xcode 26.6 (Swift 6.3.3) and again to Xcode 27.1 (Swift 6.4), with identical results on both:

```sh
swift build --build-tests && swift test
.build/debug/ProbeDefaultIsolationRun
for p in ProbePhase5Sketch ProbeMainActorDraw ProbeMainActorAppInSession ProbeMainActorHeadless ProbeDefaultIsolation; do
  PROBE=$p swift build --target $p
done
(cd Move/before && swift build) && (cd Move/after && swift build)
```

Results:

1. **Adoption is one line.** `Sources/CounterApp/Counter.swift` imports only `Tessera` and declares `body`, `apply(_:)`, and `isFinished` as plain members; `Tests/ContractTests/ContractTests.swift` adopts with `extension Counter: Application {}`. A clean build has no warnings (no retroactive-conformance warning, since the app and its test target share a package), and `Test run with 5 tests in 0 suites passed`: steps render the model, a resize reaches both the graph and the app, quit is the app's `isFinished`, the registry injects fixtures through factories and rejects a duplicate and an unknown name, and an `@Observable` app adopts unchanged (the intro app's `@Observable` variant, [definition of done](../spec/phase-4/definition-of-done.md), line 9).
2. **One driver, two hosts.** `HeadlessHost` and `LiveHost` both call `Driver.step`; `LiveHost` compiles over `isolated TerminalSession` with the draw closure capturing the driver, the shape the Showcase uses today (`Examples/Sources/TesseraShowcase/TesseraShowcaseApp.swift:24-44`) and the LiveSocket spike recommended ([plan 033](../plans/developer-tooling.md), line 225). The live host was compiled, not run.
3. **The Phase 5 sketch does not compile.** `ProbePhase5Sketch` holds `docs/spec/phase-5-runtime-and-polish.md:18-29` verbatim: `'borrowing' may only be used on 'func' declarations` (line 22's `borrowing var body`) and `cannot find type 'EventRouting' in scope`. Phase 4 already spells the handler capability `inout ResponderContext` and the result `EventDisposition` ([slice 4](../spec/phase-4/slice-04-focus-and-key-routing.md), lines 57-71; `Sources/TesseraCore/Input/EventDisposition.swift:2`).
4. **A main-actor host cannot present through the session today.** `ProbeMainActorDraw`: a `@MainActor` type calling `try await session.draw { frame in graph.render(into: frame) }` fails with `sending value of non-Sendable type '(borrowing Frame) -> sending ()' risks causing data races`, whether the closure captures `self` or the graph. `TerminalSession` is an actor (`Sources/TesseraTerminal/TerminalSession.swift:79`) and `draw` takes a non-Sendable closure (`:657-659`). Phase 5's `@MainActor` runtime ([Phase 5](../spec/phase-5-runtime-and-polish.md), line 31) therefore needs either a different home for the app or a draw API change.
5. **Without `SendableMetatype`, a main-actor app races silently.** With `Application: AnyObject` only (6.3.3): an explicitly `@MainActor` conformance compiled and could be hosted on the main actor (`ProbeMainActorHeadless`); hosting it in another isolation was rejected only when the calling function was nonisolated (`main actor-isolated conformance of 'MainActorCounter' to 'Application' cannot be used in nonisolated context`); and in a target with `.defaultIsolation(MainActor.self)`, the default of Xcode 26's app templates, a plain `final class Notes: Application` stayed main-actor isolated (controls in `Control.swift` failed on both a plain class and `Notes`), compiled, and when an actor standing in for `TerminalSession` ran it, trapped in `MainActor.assertIsolated` inside `Notes.apply`, called from `Driver.step` (`apply on main thread: false`). Without that assertion the race is silent. `results/ProbeDefaultIsolationRun-before-SendableMetatype.swift.txt` keeps that probe.
6. **With `SendableMetatype`, the race is a compile error and the default-isolation case just works.** After `public protocol Application: AnyObject, SendableMetatype`: explicit `@MainActor` conformances fail with `cannot form main actor-isolated conformance of 'MainActorCounter' to SendableMetatype-inheriting protocol 'Application'`; in the default-main-actor target, conforming makes `Notes` nonisolated (it is read from a `nonisolated` function without error, while the plain-class control still fails), and the run probe prints `apply ran in HostActor's isolation; count=1`.
7. **Moving the protocol later breaks nothing.** `Move/before` declares the protocol in `TesseraHarness`; `Move/after` declares it in `TesseraRuntime` and gives `TesseraHarness` one line, `@_exported import TesseraRuntime`. The app module and the adopting module are byte-identical in both (`shasum` `1a90ef83…` and `d543402f…`), and both packages build on both toolchains.

The spike does not prove the real headless path (`TerminalSession` over `InMemoryTerminalDevice`, the output tap, one persistent Ghostty terminal), because those seams are `package` and not on `main`; Slice 1 adds them. `ViewGraph.dispatch` still returns `.ignored` (`Sources/TesseraCore/Runtime/ViewGraph.swift:138-141`), so routing is untested.

### Spec, plan, and code

- The Phase 5 runtime is the canonical loop and nothing more: "The canonical immediate-mode loop (the Phase 5 runtime automates exactly this, nothing more)", followed by resize → `graph.dispatch` → `model.apply(event)` → `graph.update()` → draw if `needsRender` ([slice 1](../spec/phase-4/slice-01-tesseracore.md), lines 141-155). That loop is exactly the harness `Driver.step` ([Developer tooling](../architecture/developer-tooling.md), line 87), so the harness host and the Phase 5 host are one algorithm [INFERENCE from the two texts].
- Unhandled events and quitting belong to the app: "Return the final disposition; the app decides what unhandled events mean (quit keys, global shortcuts). The graph never exits the process"; "`.resize` is the app's job to forward to `resize(to:)`" ([slice 4](../spec/phase-4/slice-04-focus-and-key-routing.md), lines 49-51). There is no implicit Tab handling; the app or "the Phase 5 runtime, as a default policy" opts in (line 36). Handlers are synchronous and "async work belongs in the app's own machinery after `dispatch` returns" (line 74).
- Isolation: views, nodes, and `ViewGraph` "live in one isolation domain (the caller's in Phase 4; the optional `@MainActor` runtime in Phase 5)" ([Phase 4](../spec/phase-4.md), line 17); `ViewGraph` "is non-`Sendable` and unisolated; whoever creates it owns it" ([slice 1](../spec/phase-4/slice-01-tesseracore.md), line 141); apps keep their own architecture ([ownership thesis](../spec/ownership-and-isolation-thesis.md), line 26; [state model](../spec/phase-4/state-model.md), lines 48-51).
- No test affordances in product API: "the seams it needs are `package`, never `public`, and the harness, which app authors import, uses them internally without re-exporting them" ([Developer tooling](../architecture/developer-tooling.md), line 25); `TesseraCore` "gains only value-typed diagnostics fields, each by spec amendment" (line 21); plan acceptance "no test affordance is public API" ([plan 036](../plans/phase-4-view-layer-and-developer-tooling.md), line 178). Investigation 036 names test affordances leaking into public API as one cause of the archived attempts' failure ([tooling context](phase-4-tooling-context-and-prior-attempts.md), line 20).
- Module plan: `TesseraRuntime // optional @MainActor convenience loop (Phase 5)` ([module layout](../spec/module-and-file-layout.md), line 31); `TesseraHarness` is not listed there. The `Tessera` umbrella re-exports `TesseraCore`, `TesseraLayout`, `TesseraTerminal`, and `TesseraWidgets` (`Sources/Tessera/Tessera.swift`).
- Phase 5's test harness wants "explicit events and explicit render steps", a `step` that does at most one render pass, a bounded `drain`, and injected clocks, with the clock mechanism open ([Phase 5](../spec/phase-5-runtime-and-polish.md), lines 33-58). Motion views read a clock instant "that the app or the Phase 5 runtime supplies" ([motion views](../spec/phase-4/motion-views-and-the-tick-requirement.md), line 8).
- The graph's base environment is fixed at init (`private let baseEnvironment`, `ViewGraph.swift:23`; set once at `:70`), and the host constructs the graph, so any environment clock is the host's to supply; Slice 15 needs a host-side way to advance it, not an app-side one [INFERENCE].
- Prior shapes: the archived gallery's `DemoModel` grew defaulted requirements (`animationFrameDelay` with a `nil` default, `archive/phase4:Examples/Sources/TesseraGallery/DemoHost.swift:33, 45-46`) and constructed the model "inside the session's isolation" from a `@Sendable` factory (`:82-88`, `:103`); the review loop's `ApplicationDriver` coordinated "synchronous application work in the host's isolation domain" and presented through `isolated TerminalSession` (`archive/phase4-review-loop:Examples/Sources/SpecimenSupport/ApplicationDriver.swift:3, 66`), and it also applied terminal requirements to the session and hard-coded `q` as quit (`:29-55`, `:93`).
- Plan 033 said the harness has "no 1.0 stability promise and is not offered to app authors" ([plan 033](../plans/developer-tooling.md), line 62); the owner reversed that on 2026-10-22 ([plan 036](../plans/phase-4-view-layer-and-developer-tooling.md), line 196). Before 1.0 a breaking change bumps the minor version (`CONTRIBUTING.md:267`); 1.0 is the end of Phase 5 ([Phase 5](../spec/phase-5-runtime-and-polish.md), line 60).

### Comparison

| Question | A `HeadlessApp` | B Phase 5 scene | C closure value | D `Application`, moved in Phase 5 | E `Application` in a product module now |
| --- | --- | --- | --- | --- | --- |
| One way across Phase 4 and 5 | No: Phase 5's sketch is a second contract | Yes, from Phase 5 | No, unless Phase 5 also hosts closures | Yes: Phase 5 hosts the same protocol | Yes |
| Phase 4 → 5 without breaking adopters | No: re-adopt the scene | n/a | Adapter needed [INFERENCE] | Yes (result 7) | Yes, no move |
| What demos need now | Yes | No: nothing to drive until Phase 5 is built | Yes | Yes | Yes |
| Input | Every event, with disposition | `EventResponder`, separate protocol | `apply` closure | Each `.ignored` event (slice 4, line 49) | as D |
| Resize | Host, then `apply` | Unspecified | as D | Host resizes the graph, then `apply(.resize)` | as D |
| Time | Host's environment clock | "Injected clocks", open | as D | Host's environment clock; app timers are a Phase 5 addition | as D |
| Quit | Host quit key (`q`) steals a key from apps | Unspecified | A closure flag | `isFinished`, the app's call | as D |
| Fixtures for app tests | No: `init()` requirement | Unspecified | Yes | Yes: registry factories (result 1) | as D |
| Compiles today | Yes | No (result 3) | Yes [INFERENCE] | Yes (results 1-2) | Yes [INFERENCE] |
| Main-actor apps | Silent race (result 5; A has the same isolation shape as the probe) | Host cannot draw (result 4) | Untested | Compile error (result 6) | as D |
| Public API forced into product modules in Phase 4 | None | `TesseraRuntime` now, with no production host | None | None | `TesseraRuntime` or `TesseraCore` now, with only the test host |

## Recommendation

Adopt **D**. Neither named candidate survives as written: A gives Phase 4 one contract and Phase 5 another, steals `q` from apps through a host quit key, forces `init()` (so a scenario cannot inject a fake file system), and is unsafe for main-actor apps; B cannot be built in Phase 4, its sketch does not compile, it has no path for app-level unhandled events or quitting, and a main-actor host cannot present through today's `TerminalSession`. D keeps A's mechanism (one `Driver`, live and headless on one draw path) and makes its contract the one Phase 5 hosts.

The contract, in `TesseraHarness` during Phase 4:

```swift
public protocol Application: AnyObject, SendableMetatype {
  associatedtype Body: View
  @ViewBuilder var body: Body { get }   // the root view; reads the model, hands out Bindings
  func apply(_ event: InputEvent)       // each event the graph left .ignored, resizes included
  var isFinished: Bool { get }          // default false; the host stops after the step that sets it
}
```

Why each part:

- **Requirements name only `Tessera` types.** An app's production type satisfies them with its own members, so adoption is `extension MyApp: Application {}` in the test or dev target that imports the harness (result 1), and the production target never links the harness or Ghostty. An app that runs its own loop over `TerminalSession` keeps it in production during Phase 4; [INFERENCE] its loop and the harness `Driver` can drift until Phase 5's runtime replaces hand-written loops, which the skill and guide should say.
- **`apply` sees only unhandled events.** That is slice 4's rule (line 49); the `Driver` records the disposition in the trace, so the app need not see it. Plan 033's `apply(_:disposition:)` is dropped.
- **Quit is the app's.** `isFinished` follows slice 4's "the app decides"; demos keep `DemoHost.isQuitKey` in `DemoSupport` and report through `isFinished`, so the harness hard-codes no key and installs no Tab policy (slice 4, line 36).
- **No `init()`; a registry of factories.** `ApplicationRegistry.register(_:minimum:viewports:make:)` takes a `@Sendable` factory the host calls inside its own isolation once per run, the archived gallery's pattern; each run starts fresh, and a fixture is a second registration (`register("browser-empty") { Browser(fs: .empty) }`).
- **`SendableMetatype`.** It turns result 5's silent race into result 6's compile error, and makes default-main-actor app targets work unannotated. Dropping the refinement later relaxes a constraint and breaks no adopter [INFERENCE: removing a protocol's inherited marker protocol leaves every existing conformance valid], so Phase 5 can drop it if it builds a main-actor host that can present; adding it after 1.0 would break adopters.
- **Time and other later needs are additive.** The host owns the `ViewGraph` and its environment, so Slice 15's clock needs nothing from the app. App work that completes after `apply` returns (a file load, a debounce) has no path in this contract; Phase 5 adds one as a requirement with a default, the way `DemoModel` added `animationFrameDelay`, never by changing `apply`'s signature.
- **`body`, not `root`.** It matches Phase 5's sketch and SwiftUI's `App`; nothing else depends on the spelling.
- **Harness now, runtime in Phase 5 (D over E).** Phase 4 adds no product API, which is the letter of principle 6 and plan acceptance line 178; the Phase 5 move costs one `@_exported import` and no adopter edit (result 7). E avoids the move but puts a protocol in a product module whose only host for a whole phase is a test library. This is the one close call; see [Owner decisions](#owner-decisions).

Not public at 1.0: a Swift stepping API (the `Driver`, a `TestRuntime`). App authors drive through scenarios, run from `swift test` by `ScenarioRunner` or from their dev executable by `HarnessCLI`; Tessera's own runtime tests use the `package` `Driver` from inside the root package. Every public observation on a stepping type (screen, projection, trace) would be one more schema to freeze beside the JSON report. Adding it later is additive.

No `architect` agent was available in this session, so the review plan 036 asks for at Slice 3 (line 73) has not happened; this record is its input.

## The public 1.0 surface

### Swift names in `TesseraHarness`

Seven names, with only the members listed:

1. `protocol Application` — `body`, `apply(_:)`, `isFinished` (default `false`). In Phase 5 it moves to `TesseraRuntime` and `TesseraHarness` re-exports it; at 1.0 its promise is `TesseraRuntime`'s.
2. `struct ApplicationRegistry: Sendable` — `init()`; `mutating func register<App: Application>(_ name: String, minimum: TerminalSize? = nil, viewports: [Viewport], make: @escaping @Sendable () -> App)`. A duplicate name makes every entry point that reads the registry fail (exit 3, or a failing report), never last-wins; registration itself does not throw.
3. `enum Viewport: Hashable, Sendable` — `desktop` (80x24), `mobile` (40 columns, natural height), `mobileScreen` (40x16), `custom(TerminalSize)`.
4. `enum HarnessCLI` — `static func main(registry: ApplicationRegistry) async -> Never`, the whole body of a per-app dev executable and of `tessera-dev`.
5. `struct ScenarioRunner: Sendable` — `init(registry: ApplicationRegistry, record: Bool = false)`; `func run(_ path: String) async -> ScenarioReport`, the `swift test` entry point.
6. `struct ScenarioReport: Sendable, CustomStringConvertible` — `scenario`, `passed`, `failures`, `description` (the human form), `json` (the JSON form).
7. `struct ScenarioFailure: Sendable` — `line`, `statement`, `verb`, `message`.

### What "stable" covers

Within 1.x, a change to any of these is a 2.0 change:

- **Scenario grammar.** Every statement, header key, `term` option, locator key (`type=`, `layout=`, `id=`, `text=`, `nth=`, `focused`, `focusable`, `role=`, `label=`), role name, and check rule id documented in `Examples/Scenarios/README.md` at 1.0 keeps its syntax and meaning. Additions are additive. An unknown statement stays a parse error (exit 2), so a scenario that uses a newer statement fails loudly on an older harness. `type=` values are public view type names; framework-private names (`_SplitPane`) are not covered.
- **Exit codes.** 0 pass, 1 an expectation or check failed, 2 a usage or parse error, 3 a harness error.
- **The JSON report.** One object per scenario and per command, with the fields it has at 1.0; fields are added, never removed, renamed, or retyped, and consumers ignore fields they do not know.
- **CLI commands and flags.** `app list`, `app run NAME`, `run PATH...`, `shot`, `tree`, `check`, `help COMMAND`, and `--record`, `--repeat N`, `--timing`, `--json`, `--pretty`. This is also what keeps Decision 9 (iii) open: a prebuilt front end or a SwiftPM plugin only forwards to the per-app executable's command line.
- **Golden file formats.** `NAME.txt` and `NAME.grid.txt` keep their format, so a harness upgrade alone never drifts an app's goldens. A library rendering change (a widget drawing differently) is a library change and drifts goldens like any other; Tessera's release notes say so.
- **Check rules.** Ids are stable; a rule added in 1.x runs when named and joins bare `check` only in the next major, so a minor release cannot fail an app's CI with a rule the app never asked for.

Not covered, and free to change in any release (each carries a version field): the projection JSON that `tree` and `dump` print; the trace JSONL and `replay`; the numbers `expect cost` compares (its syntax is covered; the counts are the library's work, so assert with `<=` bounds); SVG and PNG shots; `coverage` output (Decision 8); `conform`, which reads Tessera's own catalog; and the live-inspection socket protocol and `attach` (Slice 17).

### `package` or internal

Everything else: `Driver` and both hosts; the scenario parser and its syntax tree; `Projection`, the locator engine, invariant rules, the trace writer, shot writers, key-name normalisation, the natural-height probe, the socket server; and every root-package seam (`InMemoryTerminalDevice` resize injection, `TerminalSession.lastDrawn` and output tap, the `ViewGraph` clock and nil-height proposal), which the harness uses and never re-exports. Plan 033's `.scenario` SnapshotTesting strategy in `TesseraTestSupport` is not added: `shot` goldens are the one golden mechanism, and `ScenarioRunner` is the Swift entry point.

## Proposed amendments

Each block is replacement text the owner can accept as written. Paths are repository-relative.

### Plan 036, Decisions (`docs/plans/phase-4-view-layer-and-developer-tooling.md`, line 200)

Replace the sentences of the open Decision 9 entry that describe (i) ("(i) The public surface: … before `HeadlessApp` is fixed.") with nothing, and add above the open entries:

> - 2026-10-23 Decision 9 (i), the public surface: neither named candidate. The harness drives `Application` (`AnyObject` and `SendableMetatype`; `body`, `apply(_:)` for each event the graph left `.ignored`, and `isFinished`), whose requirements name only `Tessera` types, so an app adopts it with one conformance line in a test or dev target. It lives in `TesseraHarness` in Phase 4; Phase 5's runtime hosts the same protocol, moved to `TesseraRuntime` and re-exported by `TesseraHarness`, so adopting code does not change. The 1.0 promise covers seven Swift names (`Application`, `ApplicationRegistry`, `Viewport`, `HarnessCLI`, `ScenarioRunner`, `ScenarioReport`, `ScenarioFailure`) and the scenario grammar, CLI commands and flags, exit codes, JSON report fields, check rule ids, and golden formats, under the rules in Developer tooling (`../architecture/developer-tooling.md#stability`); everything else in the harness is `package` or internal. (owner, from Decision 9 (i) (`../research/decision-9i-application-contract.md`))

### Plan 036, Slice 2 (line 65)

Replace "its product and stability promise follow Decision 9." with:

> it is a library product, `TesseraHarness`, whose public names are the seven Decision 9 (i) lists; nothing else in it is `public`.

### Plan 036, Slice 3 (lines 71 and 73)

Replace the first three sentences of line 71 ("Plan 032 Step 8.2 … `TerminalSession.draw` path.") with:

> Plan 032 Step 8.2 and plan 033 Step B.1, under Decision 9 (i). `TesseraHarness` gains the app contract and its registry: `Application` (`AnyObject` and `SendableMetatype`; `@ViewBuilder var body: Body { get }`; `func apply(_ event: InputEvent)` for each event the graph left `.ignored`, resizes included; `var isFinished: Bool { get }`, `false` by default), `ApplicationRegistry` (one selection point; `register(_:minimum:viewports:make:)` takes a `@Sendable` factory the host calls inside its own isolation, once per run; a duplicate name fails every entry point that reads the registry, never last-wins), and `Viewport` (`desktop` 80x24, `mobile`, `mobileScreen` 40x16, `custom`). `Examples/Sources/DemoSupport` adds `Demo` (an `Application` with a registry name, minimum size, and declared `fixtures`, no default), the demo registry, and the demos' quit key (`DemoHost.isQuitKey`, whole-key matching), which a demo reports through `isFinished`; the harness has no quit key and no Tab policy of its own. One `package` `Driver` with one update policy, ported from the review loop's `ApplicationDriver`: resize the graph if asked, `graph.dispatch`, `apply` if the disposition is `.ignored`, `graph.update()`, then `TerminalSession.draw` when the graph needs a render. The `Driver` owns the `ViewGraph` and its base environment, and live and headless share it and the draw path.

In the same line, replace "(`demo run`, a demo's headless snapshot test)" with "(`app run`, a demo's headless snapshot test)". Replace line 73 with:

> Delivers: a demo runs live in a terminal and renders identically headless, and a type written against `Tessera` alone adopts `Application` with one conformance line. Verify: registry tests cover duplicates and lookup; a greedy demo fails `size mobile`; one demo's snapshot test is a few lines; a compile-fail fixture beside `Tests/CompileFailFixtures/FrameRegionEscape.swift` shows that a `@MainActor` conformance to `Application` does not compile.

### Plan 036, Slice 4 (line 77)

Replace "`Examples/Sources/TesseraDev` is `HarnessCLI.main(registry:)` with `demo list|run`," with:

> `Examples/Sources/TesseraDev` is `HarnessCLI.main(registry:)` with `app list|run` (the word the scenario header already binds), and `ScenarioRunner` runs one scenario from `swift test` and returns the same `ScenarioReport`;

### Plan 036, Slice 18 (line 161)

Replace "(the loop: `demo run` → `run` →" with "(the loop: `app run` → `run` →", and replace "the app-author path from Decision 9 (an app adopts the harness, writes scenarios, and runs `check` in its own CI)" with:

> the app-author path from Decision 9 (an app adds `extension MyApp: Application {}` and a dev executable whose body is `HarnessCLI.main(registry:)`, writes scenarios, runs them from `swift test` through `ScenarioRunner`, and runs `check` in its own CI; until Phase 5, the guide says that an app's own production loop must match the canonical loop the `Driver` runs)

### Developer tooling (`docs/architecture/developer-tooling.md`)

Line 54: replace "Headless driver (`Driver`, `HeadlessApp`)" with "Headless driver (`Driver`, `Application`)".

Line 79: replace "`tessera-dev demo run NAME`" with "`tessera-dev app run NAME`". Line 162: replace "`demo list`, `demo run NAME` | list demos; run one live in this terminal" with "`app list`, `app run NAME` | list registered apps (demos, for `tessera-dev`); run one live in this terminal". Line 186: replace "`tessera-dev demo run NAME`" with "`tessera-dev app run NAME`".

Replace line 85 with:

> The driver runs anything that adopts `Application`: a reference type that owns its model, whose `body` is the root view (it reads the model and hands out `Binding`s so controlled controls can write back), whose `apply(_:)` receives each event the view graph left `.ignored`, resizes included, and whose `isFinished` tells the host to stop. Every requirement uses only `Tessera` types, so an app written against `Tessera` alone satisfies it and adopts it with `extension MyApp: Application {}` in whichever target imports the harness. The app lives in its host's isolation domain; the protocol refines `SendableMetatype`, so a main-actor-isolated conformance is a compile error rather than a model touched off the main actor. `ApplicationRegistry` names each app and holds a `@Sendable` factory the host calls inside its own isolation, once per run, so each run starts fresh and a fixture is one more registration. `Demo` is `Application` plus the registry name, minimum size, and viewports. An app that runs its own loop over `TerminalSession` keeps it in production; its test or dev target adopts `Application`, and the app runtime hosts the same protocol.

Insert after "### `tessera-dev`" section's last paragraph (after line 170) a new section:

```markdown
### Stability

`TesseraHarness`'s public names are `Application`, `ApplicationRegistry`, `Viewport`, `HarnessCLI`, `ScenarioRunner`, `ScenarioReport`, and `ScenarioFailure`; everything else is `package` or internal. Within a major version these stay as they are: the scenario grammar (statements, header keys, `term` options, locator keys, role names, and check rule ids; additions only, and an unknown statement stays a parse error); the exit codes; the JSON report's fields (added, never removed, renamed, or retyped; consumers ignore unknown fields); the commands `app list`, `app run`, `run`, `shot`, `tree`, `check`, and `help` and the flags `--record`, `--repeat N`, `--timing`, `--json`, and `--pretty`; and the `NAME.txt` and `NAME.grid.txt` formats. A check rule added in a minor version runs when named and joins bare `check` in the next major. The projection JSON from `tree` and `dump`, the trace and `replay`, the counts `expect cost` compares, SVG and PNG shots, `coverage`, `conform`, and the live-inspection socket may change in any release and carry a version field. A library rendering change can drift goldens in any release; that is the library's change, not the harness's.
```

Replace the first bullet under "Open questions" (line 195) with:

> - How app authors consume the harness is decided: they adopt `Application` and drive it through scenarios (see The headless driver (`#the-headless-driver`) and Stability (`#stability`)); libghostty-vt ships as a prebuilt artifact bundle (libghostty-vt distribution (`libghostty-vt-distribution.md`)).

### Phase 5 spec (`docs/spec/phase-5-runtime-and-polish.md`)

Replace lines 16-49 (from "Runtime isolation rules to make explicit before building this phase:" through the `drain(maxSteps:)` code block) with:

> The runtime hosts the app contract the harness already drives. `Application` (`body`, `apply(_:)` for each event the graph left unhandled, `isFinished`) is defined in `TesseraHarness` during Phase 4 and moves into `TesseraRuntime` in this phase; `TesseraHarness` re-exports it, so adopting code compiles unchanged. App-level keys are the view tree's `.onKey` handlers (slice 4 (`phase-4/slice-04-focus-and-key-routing.md`)); there is no separate app responder protocol. The runtime adds what the harness host leaves to the app: a Tab focus policy an app opts into, render scheduling, redraws driven by the aggregated tick requirement, and a path for app work that completes after `apply` returns. Each arrives as a requirement with a default or as runtime configuration, never as a change to an existing requirement.
>
> The runtime owns UI concerns such as event delivery, responder routing, focus, display and layout invalidation, and render scheduling. It does not own the app's business model and does not require a Tessera-specific `State`/`Action`/`Effect` architecture. Runtime contexts expose only UI-scoped capabilities and cannot expose mutable app state, a `Frame`, raw terminal handles, or arbitrary terminal writes. Rendering still happens only in `draw {}` with a borrowed `Frame`.
>
> **Open question for Phase 5:** the runtime's isolation. A main-actor host cannot present through `TerminalSession` today: `session.draw { frame in graph.render(into: frame) }` from `@MainActor` code fails with "sending value of non-Sendable type … risks causing data races" (Decision 9 (i) (`../research/decision-9i-application-contract.md`)). Either the runtime runs the app in the session's isolation, as the harness does, or this phase changes the draw API before choosing `@MainActor`. `Application` refines `SendableMetatype` until then; dropping the refinement breaks no adopter.
>
> Tests drive the runtime through `TesseraHarness`: scenarios run from `swift test` by `ScenarioRunner` or by an app's `HarnessCLI` executable, and Tessera's own runtime tests use the harness's `package` `Driver`, whose `step` is the unit of work. Do not make snapshot tests depend on `Task.yield()` or sleeps to "let the UI catch up." A step delivers one event, processes the resulting synchronous UI work, coalesces invalidations, performs at most one render pass if needed, then returns:
>
> ```text
> app counter
> size desktop
> key +
> expect text 0 "Count: 1"
> ```
>
> A bounded drain is acceptable for work that schedules more work, and is the scenario verb `settle`, bounded and driven by the harness clock; an unbounded "drain until idle" is a smell because work can schedule more work forever.

Leave line 31's remainder as folded into the second paragraph above, and keep lines 51-60 (clocks, the open clock question, end of phase) as they are.

### Module layout (`docs/spec/module-and-file-layout.md`)

In the products block (lines 20-23), add `TesseraHarness          // public harness: Application (until Phase 5), registry, scenarios, CLI; for test and dev targets`. In the targets block, add the same `TesseraHarness` line after `TesseraTestSupport`, and replace line 31 with `TesseraRuntime           // optional convenience loop; hosts Application (Phase 5)`. At the end of the paragraph on line 44, add: "`TesseraHarness` drives an app headlessly and live for tests and dev executables; app authors import it from those targets, never from production code."

## Risks and what would change the answer

- **Phase 5 isolation.** If Phase 5 keeps `@MainActor` and changes the draw API, `Application` can drop `SendableMetatype` and accept main-actor apps (result 5 shows an isolated conformance hosted on the main actor compiles); nothing in D changes otherwise. If Phase 5 instead requires `apply` to be `async`, that changes `apply`'s signature and breaks adopters: decide app work's shape in Phase 5 before 1.0, as a defaulted addition.
- **Main-actor models.** Apps cannot keep a `@MainActor` model behind `Application` (result 6). An `@Observable` model without `@MainActor` works (result 1). [INFERENCE] App authors used to SwiftUI will hit this first; the guide and the compile error carry the fix.
- **Asserting app state in Swift.** With the headless path inside the `TerminalSession` actor and a `@Sendable` factory, a Swift test cannot keep a reference to the app or a fake it captured and inspect it after a scenario [INFERENCE from the isolation rules in results 4-6]. Scenarios assert on screen and projection only, as principle 2 intends. If the owner wants model assertions from Swift, that needs a public stepping API whose app stays in the caller's isolation, which would change the "not public at 1.0" call above.
- **The move in Phase 5.** A fully qualified `TesseraHarness.Application` in app code breaks at the move [INFERENCE]; unqualified uses do not (result 7). An app that later moves its conformance into production code must delete the one in its test target.
- **Live and headless drift for apps until Phase 5.** An app's hand-written production loop is not the `Driver`; the canonical loop text is the only thing keeping them aligned until the runtime exists.
- **Naming.** `Application` may collide with an app's own type; `app list|run` renames `demo list|run`. Both are cheap before Slice 3 lands and expensive after 1.0.
- **Unverified here.** The real headless path through `InMemoryTerminalDevice` (Slice 1 seams), a live run, routing once `dispatch` routes, and Windows and Linux builds of the spike (it ran on macOS only).

## Owner decisions

- **D or E:** `Application` in `TesseraHarness` now and moved to `TesseraRuntime` in Phase 5 (recommended; no product API in Phase 4), or `TesseraRuntime` created now holding only the protocol (no move; a product module whose only host for a phase is a test library).
- **`app list|run` instead of `demo list|run`:** recommended so the CLI word matches the scenario header for app authors; it touches four lines of [Developer tooling](../architecture/developer-tooling.md) and two of plan 036.
- **The Slice 3 `architect` review** plan 036 asks for has not been run on this record.
