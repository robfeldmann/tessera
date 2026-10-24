---
type: research
observed: 2026-10-23 # main 9325271 and origin/docs/phase-4-decisions 79da704; spikes rebuilt on Swift 6.3.3 (Xcode 26.6)
status: resolved
description: Architect review of the Decision 9 (i) record ([Decision 9 (i)](decision-9i-application-contract.md)) — verdict, concerns with evidence, required amendment changes, and answers to the two owner questions.
---

# Decision 9 (i): architect review

> Resolved 2026-10-23: the owner took the review's answer (a) as `TesseraRuntime` created in Phase 4 and re-exported by `Tessera`, accepted the required changes to the amendment text, and went further on isolation (no `SendableMetatype`, `@MainActor` hosts, `TerminalSession.draw` caller-isolated); the spec's [Runtime isolation](../spec/phase-5-runtime-and-polish.md#runtime-isolation) section supersedes the text below wherever they differ, and the CLI is `tessera` with `apps`, `launch`, and `run`, not `app list|run`.

Claims with a `path:line`, a command, or a quoted compiler message were observed. [INFERENCE] marks the rest. Review probes live in `/Users/rob/Developer/robfeldmann/tessera/decision-9-spike/spikes/Decision9Review/` (untracked; nothing in `main` touched).

## Verdict

**Accept with changes.** The contract shape holds: `Application` with `body`, `apply(_:)` for events the graph left `.ignored`, and `isFinished`; `AnyObject`; a registry of `@Sendable` factories; no host quit key; no public stepping API at 1.0. Every compiler result in the record reproduced (results 1-7, both spike packages, the `Move` pair). Three of its claims do not hold as written and change the amendment text: the recommended adoption pattern fails for default-main-actor app modules (concern 1), "dropping `SendableMetatype` breaks no adopter" is false for the same modules (concern 2), and the slice 1 canonical loop the record calls "exactly the harness `Driver.step`" applies every event where the contract applies only unhandled ones (concern 3). On owner question (a) I recommend E, not D, because concern 1 is a consequence of D's adoption-by-extension and E removes it along with the Phase 5 move. On (b), rename.

## What was verified

```sh
# senior's spike, Swift 6.3.3
swift build --build-tests && swift test            # 5 tests passed, no warnings
.build/debug/ProbeDefaultIsolationRun              # apply ran in HostActor's isolation; count=1
PROBE=<name> swift build --target <name>           # all five failing probes fail with the quoted messages
(cd Move/before && swift build) && (cd Move/after && swift build)   # both build; AppTests/AppCore shasums d543402f…, 1a90ef83…
# review probes (Decision9Review/)
swift build --target AdoptMA | AdoptMAFixed | InModuleMA | GraphMA
(cd MoveAlias && swift build --target AppTests | AppTestsScoped)
```

Also read: `docs/architecture/developer-tooling.md`, `docs/spec/phase-4/{architecture,testing-posture,slice-01-tesseracore,slice-04-focus-and-key-routing,state-model,definition-of-done}.md`, `docs/spec/phase-5-runtime-and-polish.md`, `docs/spec/module-and-file-layout.md`, `docs/spec/ownership-and-isolation-thesis.md`, `AGENTS.md`, plan 036 on both `main` and the decisions branch, `ViewGraph.swift:63-72,138-141`, `TerminalSession.swift:657-659`, `TerminalDevice+Live.swift:127`.

## Concerns, ranked by what they cost later

### 1. Adoption by extension fails for default-main-actor app modules (medium)

The record's adoption story is `extension MyApp: Application {}` in a test or dev target, and it claims `SendableMetatype` "makes default-main-actor app targets work unannotated" (record line 102, amendment lines 150 and 188). Result 6 tested a conformance declared *with the type* in the default-isolation module. The recommended pattern declares it in another module, where isolation inference of the type has already happened. Probe `AdoptMA` (an `AppMA` target with `.defaultIsolation(MainActor.self)` declaring `final class Notes` without any conformance; `AdoptMA` adding `extension Notes: Application {}` and hosting it in an actor):

```text
Adopt.swift:7:18: error: conformance of 'Notes' to protocol 'Application' crosses into main actor-isolated code and can cause data races [#ConformanceIsolation]
Adopt.swift:10:28: error: call to main actor-isolated initializer 'init()' in a synchronous nonisolated context [#ActorIsolatedCall]
```

The fix is in production code: `public nonisolated final class NotesExplicit` plus the same extension builds (`AdoptMAFixed`). The in-module form also builds, `@Observable` included: `@Observable final class ObservedNotes: Application` in a default-main-actor module is inferred nonisolated and hosts in an actor (`InModuleMA`). So the claim is true only when the conformance is declared where the type is, which D's "production never mentions the harness" story forbids. Two further facts bound the cost: no manifest in this repository sets `defaultIsolation` and `swift package init --type executable` on 6.3.3 writes none (checked in `/tmp/d9init`), so default-main-actor TUI targets are an opt-in today; and `GraphMA` shows that a conforming app whose model is any other class in the same default-main-actor module fails at every touch (`main actor-isolated property 'items' can not be referenced from a nonisolated context`), so the whole model graph must be nonisolated, not just the app type.

Fix: see (a). If the owner keeps D, the amendment must say "a type in a default-main-actor module is declared `nonisolated` before it adopts `Application` from another target", and Slice 4's compile-fail fixture should pair the `@MainActor` conformance case with this cross-module case.

### 2. "Dropping `SendableMetatype` breaks no adopter" is false for in-module adopters under default main-actor isolation (medium)

Record line 102 and the Phase 5 amendment (line 208): "dropping the refinement breaks no adopter [INFERENCE]". The record's own result 5 is the counter-example: before the refinement, `final class Notes: Application` in a default-isolation target *stayed main-actor isolated* (the `ProbeDefaultIsolation` controls failed on `Notes.lines`) and the hosted run trapped in `MainActor.assertIsolated`. Removing the refinement therefore flips the inferred isolation of every such adopter from nonisolated to main-actor, which changes what their own nonisolated code may call and turns their conformance into an isolated conformance; whether that still compiles then depends entirely on the host's isolation. It is a Phase 5 decision to make *with* the runtime's isolation and the draw API, before 1.0, not a relaxation that can be made after.

Fix: replace the sentence in the Phase 5 amendment and in the record's risk list with: "`Application` refines `SendableMetatype` in Phase 4 because the harness hosts apps inside the session's isolation. Whether 1.0 keeps it is decided in this phase together with the runtime's isolation and the draw API; removing it changes the inferred isolation of adopters in default-main-actor modules, so it is not a post-1.0 change."

### 3. The slice 1 canonical loop and the contract disagree on which events reach `apply` (medium)

`docs/spec/phase-4/slice-01-tesseracore.md:149-150` is `_ = graph.dispatch(event)` then `model.apply(event)`: every event. The contract (and `developer-tooling.md:87`, and slice 4 line 49) applies only events the graph left `.ignored`. The record calls the two "one algorithm" (line 55) and amends neither. Phase 5's runtime "automates exactly this, nothing more" (slice 1 line 141), and the record's own risk list says the canonical-loop text is "the only thing keeping [an app's production loop and the `Driver`] aligned until the runtime exists" (line 233). As written, an author who copies the canonical loop into production drifts from the harness on exactly the behaviour the contract fixes (a key the focused control consumed is also seen by the app).

Fix: add an amendment to slice 1 lines 149-150: `if graph.dispatch(event) == .ignored { model.apply(event) }` with the comment "app-owned state; only what the tree left unhandled". The `Driver` and the loop are then one algorithm by text, not by assertion.

### 4. `SendableMetatype` plus session-isolated hosting forecloses main-actor-bound models, which the thesis names (medium, 1.0 shape; low for Phase 4)

The ownership thesis says "users remain free to bring TCA or any other state architecture" (`ownership-and-isolation-thesis.md:26`); TCA's `Store` is `@preconcurrency @MainActor public final class Store<State, Action>` (`~/Developer/pointfreeco/swift-composable-architecture/main/Sources/ComposableArchitecture/Store.swift:116-117`). Phase 4 and 5 both describe the optional runtime as `@MainActor` (`phase-4.md:17`, `phase-5-runtime-and-polish.md:31`). Under the contract, an app type cannot be main-actor isolated (result 6) and its nonisolated `apply`/`body` cannot touch a main-actor model even when the host happens to run on the main actor (`GraphMA` is the same shape). The record lists this as a risk about "app authors used to SwiftUI" (line 230); it is narrower and more specific than that: a 1.0 that keeps `SendableMetatype` cannot host a TCA app. Demos and the `@Observable` intro-app variant are unaffected (result 1, `InModuleMA`).

Fix: the Phase 5 open question should name the two shapes it must choose between before 1.0: (i) apps run in the session's isolation, `SendableMetatype` stays, main-actor models are out; or (ii) the runtime hosts on the main actor and `TerminalSession.draw` changes so a main-actor host can present (today `draw` takes `(borrowing Frame) throws -> sending R`, `TerminalSession.swift:657-659`, and result 4 shows a main-actor caller cannot send its graph), after which the refinement can go. State that (i) excludes TCA-shaped models, so the thesis line 26 is either amended or honoured by (ii).

### 5. Resizes reach `apply` only by accident of `dispatch` (low)

The contract promises `apply` "each event the graph left `.ignored`, resizes included". The spike `Driver` calls `apply` only when `dispatch` returned `.ignored` (`Driver.swift:26-29`); that is true today because `dispatch` returns `.ignored` for everything (`ViewGraph.swift:138-141`). Slice 4 line 51 makes `.resize` the app's to forward but does not pin its disposition. Fix: the Slice 4 amendment text says the `Driver` forwards `.resize` to `apply` unconditionally (it is never routed), so routing work in Slice 9 cannot silently take resizes away from apps.

### 6. The amendments target `main`, not the decisions branch (low, but blocks acceptance as written)

Every line and slice number in the record is from `main` 9325271. `origin/docs/phase-4-decisions` (79da704) renumbered the slices (its Decisions entry dated 2026-10-23, line 224: former 1-5 are 2-6, 11-19 are 12-20). On the branch: the harness target slice is Slice 3 (line 72), the demo-contract slice is Slice 4 (lines 78 and 80; line 80 now reads "This slice starts only once Decision 9 (i) is recorded below", not the `architect` sentence the record replaces), the scenario slice is Slice 5 (line 84), the clock is Slice 16, live inspection Slice 18, the docs slice Slice 19 (line 168), and the open Decision 9 entry is line 225 with different (i) wording and a (iii) that already says the per-app executable is built under every option. `developer-tooling.md`'s open-questions bullet on the branch already carries the libghostty-vt resolution, so the record's replacement at "line 195" must be rewritten against the branch text. Fix: re-target every amendment to the branch before the owner accepts; the record's "Slice 15" for the clock becomes "Slice 16".

### 7. If D is kept, the move needs one more line (low)

Record line 232 flags that `TesseraHarness.Application` breaks at the move. `MoveAlias/AppTests` shows the fix: `TesseraHarness` keeps `@_exported import TesseraRuntime` and adds `public typealias Application = TesseraRuntime.Application`; a client that writes both `extension Counter: TesseraHarness.Application {}` and unqualified `Application` builds with no ambiguity. `MoveAlias/AppTestsScoped` shows that `@_exported import protocol TesseraRuntime.Application` re-exports only the protocol (the client sees `Application` and `Host`, and `RuntimeOnly` is `cannot find 'RuntimeOnly' in scope`), so the harness need not re-export the whole runtime. Moot under E.

### 8. Two public shapes are under-specified for a frozen surface (low; Slice 5 detail)

`ScenarioRunner.run(_ path: String) async -> ScenarioReport` returns one report, while the CLI's `run PATH...` accepts files and directories and reports per scenario; the Swift entry point should take the same inputs and return one report per scenario, or 1.0 freezes an asymmetric pair. `ScenarioReport.json` has no type (String or Data). The record also says `register` does not throw while the spike's does (`Application.swift:60-64` throws `duplicateName`); the record's choice (fail every reading entry point, exit 3) is the better one and Slice 4 should not copy the spike's signature. None of this changes the decision; it must be settled in the slice that lands the names.

## Checks the brief asked for

- **Swift 6 isolation claims.** A `@MainActor` conformance is a compile error (results 5-6, reproduced). `@Observable` adopts unchanged, nonisolated, in both a plain module (result 1) and a default-main-actor module (`InModuleMA`). Default-main-actor targets work only with in-module conformance (concern 1). A main-actor host cannot present through `draw` (result 4, reproduced; signature at `TerminalSession.swift:657-659`).
- **Phase 5 move is source-compatible.** Holds for unqualified use (result 7, reproduced, shasums match); qualified use needs the typealias (concern 7). Irrelevant under E.
- **No test affordances in product API.** D adds no product API. E adds `Application`, which is the app's contract with any host, not a hook into the libraries; principle 6's text (`developer-tooling.md:25`) forbids hooks *exposed by* the view and terminal libraries, and plan acceptance (branch line 201) forbids test affordances. Neither is violated by E.
- **Slice 16's clock.** Not foreclosed: the `Driver` owns the `ViewGraph` and its base environment (`ViewGraph.swift:70`, fixed at init), the plan already makes the clock a package seam the harness advances (branch Decisions 2026-10-21, line 212; branch Slice 2 line 66, "the `ViewGraph` clock seam as is"), and the contract names no clock. App-level timers are a Phase 5 additive requirement with a default; agreed.
- **Decision 9 (iii).** Not foreclosed: `HarnessCLI.main(registry:) async -> Never` is the per-app executable's body, which the branch's (iii) entry already requires under every option, and the frozen command and flag set is what a front end or plugin forwards.
- **Stable surface width.** About right. Seven names is narrow enough to hold; the grammar, exit codes, JSON report, commands and flags, goldens, and rule ids are the surfaces agents and CI depend on; projection, trace, cost numbers, pictures, `coverage`, `conform`, and the socket are correctly left free with version fields. Nothing should be removed. The "check rule added in a minor runs when named, joins bare `check` next major" rule is the right one. I would not add a stepping API at 1.0; the record's reasoning (one more schema to freeze; additive later) is sound, but the Phase 5 amendment should keep one sentence saying a public Swift stepping API is a Phase 5 option so the spec's intent (`phase-5:33-49`) is not lost with its sketch.
- **Quit without a host key.** Raw mode clears only `ICANON | ECHO` (`TerminalDevice+Live.swift:127`), so `ISIG` stays on and Ctrl+C still terminates a live `app run` whose app never sets `isFinished`. The harness needs no quit key; the record is right.

## Required changes to the amendment text

1. Re-target every amendment to `origin/docs/phase-4-decisions` (concern 6): Slice 3 line 72, Slice 4 lines 78 and 80, Slice 5 line 84, Slice 19 line 168, Decisions line 225; `developer-tooling.md` open-questions bullet in its branch wording; "Slice 15" → "Slice 16".
2. Add a slice 1 amendment: lines 149-150 become `if graph.dispatch(event) == .ignored { model.apply(event) }` (concern 3).
3. Slice 4 amendment: "the `Driver` forwards `.resize` to `apply` unconditionally; it is never routed" (concern 5).
4. Replace "makes default-main-actor app targets work unannotated" and "adopts it with one conformance line in a test or dev target" per the answer to (a) below; under D they must instead read "a type declared in a default-main-actor module is marked `nonisolated` before another target adopts `Application` for it" (concern 1), and Slice 4's verify line gains the cross-module compile-fail fixture.
5. Phase 5 amendment: replace "dropping the refinement breaks no adopter" with the sentence in concern 2, and state the two shapes and the TCA consequence from concern 4; keep one sentence that a public stepping API is an additive Phase 5 option.
6. Under D only: at the move, `TesseraHarness` adds `public typealias Application = TesseraRuntime.Application` (concern 7).

## Owner question (a): harness now and move (D), or `TesseraRuntime` now (E)

**E.** Create `TesseraRuntime` now, holding only `Application`, depending on `TesseraCore` (for `View`; `InputEvent` comes with it), re-exported by the `Tessera` umbrella from day one; `TesseraHarness` depends on it and re-exports nothing.

Reasons, in order of weight:

1. It fixes concern 1 by construction. With the protocol reachable from `import Tessera`, an app declares `final class MyApp: Application` where the type lives, which is where isolation inference happens; a default-main-actor module then gets a nonisolated app type with no keyword (result 6, `InModuleMA`), and `@Observable` works the same way. Under D the same author must write `nonisolated` in production *and* the extension in the test target, and the record's "one line" claim is false for them.
2. It removes the move, the typealias, and the "qualified name breaks" hazard, and the Phase 5 spec stops describing a relocation.
3. The module layout already intends this: `Tessera` is the "view/runtime product" and its "re-export target for the view/runtime product" (`module-and-file-layout.md:21,26`), with `TesseraRuntime` a target under it (line 31). E reaches the spec's own end state early; D invents an interim home.
4. The record's objection, "a product module whose only host for a whole phase is a test library", is the objection to a protocol with no semantics. `Application`'s semantics are the canonical loop in slice 1, which every hand-written app loop already follows; the harness is the first library host, not the definition. Principle 6 is about hooks exposed by the libraries, not about product API in general (see Checks above), so "Phase 4 adds no product API" is a stricter rule than the one written down.
5. Cost of being wrong is symmetric on the contract itself: if Phase 5 wants a different `Application`, it changes public API before 1.0 under either option (`CONTRIBUTING.md:267`), because `TesseraHarness` is public too. E's only extra exposure is a one-file module existing a phase early.

Keep `SendableMetatype` in Phase 4 under E as well; it is what makes the session-isolated host safe (result 5). The production spelling makes the constraint visible where it applies, which is a feature. [INFERENCE] If the owner nonetheless prefers D, apply changes 4 and 6 and accept the `nonisolated` requirement as documented cost.

## Owner question (b): `app list|run` instead of `demo list|run`

**Rename.** The scenario header already binds `app NAME` (`developer-tooling.md:95,107`), the registry is an application registry for both audiences, and the commands are in the frozen 1.0 set (record line 132), so `demo` would be a Tessera-internal word app authors read in their own tool for the whole 1.x line. Cost now is four lines of `developer-tooling.md` and two of plan 036 (re-targeted per concern 6); cost later is a 2.0 change. No collision: `app run NAME` and `run PATH...` are distinct subcommands.

## What is sound

The contract's three requirements name only `Tessera` types and are the canonical loop's inputs, so adoption is one conformance (result 1). Dropping `apply(_:disposition:)` and the host quit key, and making quit the app's `isFinished`, follow slice 4 line 49 and lose nothing (the trace records the disposition). The registry of `@Sendable` factories called inside the host's isolation is the archived gallery's proven pattern and gives fixtures without an `init()` requirement. One `Driver` over `isolated TerminalSession` for live and headless is the Showcase's shape and compiles (result 2). Rejecting B is correct on the evidence: the sketch does not compile (result 3), it has no quit or unhandled-event path, and a main-actor host cannot present today (result 4). The stability scope is well drawn, the "additions only; unknown statement is a parse error" and "new rule joins bare `check` next major" rules are the right ones, and keeping the stepping API out of 1.0 is the right call.

## What this review did not check

Linux and Windows builds of either spike; the real headless path over `InMemoryTerminalDevice` (Slice 2 seams, not on `main`); routing once `dispatch` routes; a live run.
