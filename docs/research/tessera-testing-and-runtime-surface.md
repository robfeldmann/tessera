---
name: Tessera Testing and Runtime Surface
date: 2026-10-19
status: resolved
---

# Tessera Testing and Runtime Surface

## Question

What does Tessera main (HEAD `31966cc`, branch `devtools-plan`) provide today to run,
observe, and assert on a Tessera app? Which runtime data structures, injection seams, and
cross-platform constraints would a devtool build on, and what is missing?

Scope: `Sources/Tessera*`, `Examples/`, `DevTools/`, `justfiles/`, `scripts/`,
architecture tests, the boundary check, the Spec and status docs, and investigations
002-028 (selected). The uncommitted omp2-gallery files are out of scope.

## Outcome

- A deterministic test substrate exists: `InMemoryTerminalDevice`,
  `InMemoryTerminalSession`, a libghostty-backed `VirtualTerminal`, and snapshot
  strategies for text, styled grid, view graph, and diagnostics. An agent can render a
  view tree headlessly and assert on cells, styles, cursor, and the diagnostics tree.
- The runtime exposes a read-only projection (`ViewGraph.dump()`, `ViewGraph.diagnostics`,
  `GraphStatistics`) with per-node identity, frame, clip, proposal, size, and
  requirements.
- Terminal I/O sits behind package seams (`TerminalDevice`, `PlatformIO`, `probeSleep`,
  `sizeChanges`), and POSIX syscalls have task-local overrides.
- Missing: input routing (`dispatch` is a stub), focus, real controls, a runtime clock
  seam, live resize injection in the in-memory path, any logging or trace channel, public
  access to frames, dirty regions, or diffs, and a headless step/drain harness. The Spec
  rejects telemetry and remote transport for diagnostics (Spec.md:7437, 7551).
- Doc drift: `LocalDevelopmentState.md:17-20`, `ProjectStatus.md:40-46`, and
  `Spec.md:8381-8390` contradict current code and CI (Section 11).

## Findings

### 1. How an app runs today

`Sources/Tessera/Tessera.swift` only re-exports modules; there is no public `App` type or
run loop. The reference loop is the Showcase:

- `Examples/Sources/TesseraShowcase/TesseraShowcaseApp.swift:17-21` opens
  `TerminalSession.withApplicationTerminal(configuration:)` and runs the loop.
- Loop (`:17-61`): `nextEvent` → `graph.dispatch(event)` (returns `.ignored`) →
  `model.dispatch` (`ShowcaseModel.swift:72-84`) → resize → `graph.update()` → if
  `graph.needsRender`, `draw { graph.render(into:) }` (`:43-48`).
- `ShowcaseModel.swift:79-81` is the only place the full `InputEvent` vocabulary is
  matched (`.resize`, `.key`, `.paste`, `.mouse`, `.focusGained`, `.focusLost`,
  `.kittyGraphicsResponse`, `.kittyKeyboardEnhancementFlags`, `.primaryDeviceAttributes`,
  `.privateModeStatus`, `.unknown`).
- `ShowcaseScript` (`ShowcaseFixture.swift`, ~26) holds fixed event sequences at sizes
  120x24, 80x24, 80x16, 40x16, and 22x10.

The Spec's canonical loop (Spec.md:7394-7409) calls `TerminalSession(configuration:)`,
which does not exist. The real entry point is `withApplicationTerminal`.

### 2. Terminal session and I/O seams

`Sources/TesseraTerminal/TerminalSession.swift` (actor, `:99`):

- Public `withApplicationTerminal` (`:345`) builds
  `PlatformIO(handles: PlatformHandles.standard())` (`:349`). The package variant
  (`:355-357`) takes `configuration`, `io: PlatformIO`, and `environment` (default
  `TerminalCapabilityDetector.currentEnvironment()`), which tests use to inject I/O and
  environment.
- State (`:114-124`): `io`, `lastDrawnBuffer: Buffer?`, `modeLifecycle`,
  `probeCoordinator`, `probeImageID` (random, `:232`), `probeSleep` (`:233`), `renderer`.
- `sizeChanges: AsyncStream<TerminalSize>` (`:160-161`, "for future live session");
  `events` (`:154`).
- `probeSleep` defaults to `ContinuousClock().sleep` (`:234`), the only clock seam in the
  terminal layer.
- `draw(_:)` (`:593`): `io.size()` (`:596`); `Buffer(size:)` (`:609`);
  `renderer.encodeFrame(previous: lastDrawnBuffer, current:)` (`:626-630`), so output is a
  diff against the last drawn buffer; `io.flush` (`:641`); `lastDrawnBuffer = buffer`
  (`:643`). A failed flush calls `invalidateRenderer()` (`:645-647`, `:697-698`), which
  nils `lastDrawnBuffer`.

`Sources/TesseraTerminalIO/TerminalDevice.swift:4-66` is the package device seam, with
`sizeChanges` as a parameter (`:50`). `PlatformIO.swift:5-50` merges byte-derived events
with `sizeChanges` and runs `InputParser`; `init(terminalDevice:)` (`:32`) disables the
cleanup registry.

`TerminalResizeRegistry.swift:5-7` documents SIGWINCH handling; the `DispatchSource` is at
`:63`. Investigation 005 records that resize notification was factored out of signal
delivery for tests, and that POSIX syscalls use task-local overrides. The POSIX input loop
had a CPU-hang bug (investigation 024; `POSIXInputLoop.swift:85-121`); its regression test
uses an immediate-empty poll stub.

### 3. Deterministic test doubles and snapshot harness

`Sources/TesseraTerminalTestSupport/`:

- `InMemoryTerminalDevice.swift`: `events` enum (`:5-20`: `enterAltScreen`,
  `enterRawMode`, `exitAltScreen`, `exitRawMode`, `flush(bytes)`); `bytes` (`:31`)
  captures all output; `init` (`:67`) seeds `inputBytes`, replayed via `AsyncStream`
  (`:44-60`).
- `resize(to:)` (`:75`) changes the reported size "without emitting a resize event"
  (`:74`). `terminalDevice` passes no `sizeChanges` stream (`:44-60`), so a test cannot
  inject a live `.resize`; it can only change what `io.size()` returns on the next draw.
- `InMemoryTerminalSession.swift:4-56`: `withApplicationTerminal` variant with modes `[]`,
  `colorCapability: noColor`, and an `environment` parameter.
  `ShowcaseTerminalSessionTests.swift:12-45` asserts an inline byte snapshot of a full
  session.

`Sources/TesseraTerminalSnapshotSupport/`:

- `VirtualTerminal.swift:5-100`: a struct of closures (`feed`, `resize`, `text`, `cell`,
  `cursor`, `kittyImages`, `kittyPlacements`, `snapshot`); non-Ghostty placeholders call
  `unimplemented()`.
- `VirtualTerminal+Ghostty.swift:9-29` implements it under `#if canImport(CGhosttyVT)`:
  `max_scrollback` 0 (`:50`), kitty storage limit 64 MiB (`:56`), state behind `Mutex`
  (`:32`), resize via `ghostty_terminal_resize` (`:265-269`).
- `ghosttyUnavailable.swift:9-58` provides `isGhosttyUnavailable` and
  `ghosttyOrUnavailable`; suites such as `ShowcaseFixtureTests.swift` disable themselves
  when libghostty is absent.
- `ScreenSnapshot.swift:4-17` holds cells and cursor only. `FrameSnapshot.swift:10-27`
  renders a `Frame` through `Renderer` into Ghostty ("test-only seam"); this is the bridge
  from `ViewGraph.render` to terminal-observable state.
- `VirtualTerminalSnapshotting.swift:14-59`: `terminalText`, `terminalStyledGrid`,
  `terminalLinksGrid`, `terminalDebugDump`.

The harness observes what libghostty reports after feeding bytes, not the Tessera buffer.
The Spec's debug-dump row is "cells, cursor, modes, selected metadata" (Spec.md:941).

`Sources/TesseraTestSupport/TesseraTestSupport.swift:1` re-exports the terminal test
support. `ViewGraphSnapshotting.swift:4-92` provides `.viewGraph`;
`GraphDiagnosticsSnapshotting.swift:5-152` provides `.diagnostics`, which excludes timing.
`DiagnosticsTests.swift:14` confirms `dump()` excludes view values.

Build: `Package.swift:450-458` makes `CGhosttyVT` unconditional for
`TesseraTerminalSnapshotSupport`. `scripts/build-libghostty-vt.sh` and `.ps1` build the
pinned library (`scripts/ghostty-vt-version.txt`, `ae52f97`); wiring is at
`Package.swift:514-592`. CI builds libghostty on Windows
(`.github/workflows/ci.yml:232-235`).

### 4. Runtime graph and what it exposes

`Sources/TesseraCore/Runtime/ViewGraph.swift` (public):

- `update()` (`:78`) reconciles with the persistent tree; stats use `ContinuousClock`
  (`:81`, `:99`, `:119`).
- `layoutIfNeeded()` (`:93`) measures and places dirty nodes; the cache is per pass
  (`:33`, `:101`).
- `render(into frame: borrowing Frame)` (`:111`) records stats (`:113`) and clears flags
  (`:122`).
- `resize(to:)` (`:127`) invalidates layout only when size changed.
- `dispatch(_:) -> EventDisposition` (`:139`) is a **stub** returning `.ignored` (`:140`);
  its doc comment says it "Does not route input events" (`:138`).
- `dump()` (`:144`); `diagnostics` (`:53`, immutable, `GraphDiagnostics.swift:5-22`);
  `needsRender` (`:43`), `needsLayout` (`:48`), `terminalRequirements` (`:38`).

`NodeDiagnostics.swift` exposes `identity`, `viewType`, `parent`, `children`, `proposal`,
`measuredSize`, `frame`, `clip`, `environmentOverrides`, `handlerKinds`, `requirements`,
`needsLayout`, `needsRender`.

Caveats:

- `RuntimeNode.handlerKinds` (`RuntimeNode.swift:20`) is never populated; always `[]`.
- `GraphStatistics.swift:51-52` declares `focusChanges` and `terminalRequirementChanges`;
  nothing records them.
- `LeafView.handleEvent` (`LeafView.swift:26`, `:40`) is called only by tests
  (`Tests/TesseraCoreTests/ViewTests.swift:51-58`); `ResponderContext.swift` has no
  runtime consumer.
- `RuntimeNode` is `package` (`RuntimeNode.swift:3`). `NodeIdentity.swift:2-20` is a
  string path; keyed `ForEach` reorder preserves node state
  (`ReconciliationTests.swift:169-170`).

Frames and buffers:

- `TesseraTerminalBuffer/Frame.swift:12` defines a `~Copyable` `Frame`, borrowed by
  `render`. `RenderRegion` is at `Sources/TesseraCore/Rendering/RenderRegion.swift:7`.
- `Renderer` is `package` (`Sources/TesseraTerminalRendering/Renderer.swift:13-50`); its
  static `render(previous:current:)` (`:28-46`) is the only isolated diff path.
- `BufferDiff.swift:14` `damageRuns` computes dirty runs, package-only.

### 5. Layout, widgets, views, examples

- `Sources/TesseraLayout/`: public `Layout` protocol (`Layout.swift:5`), `Subviews`
  (`:26`), `LayoutValueKey` (`:18`); `Flex`, `Stacks`, `Geometry`, `FrameModifiers`,
  `Decoration`.
- `Sources/TesseraWidgets/`: only `ScrollView.swift` (129 lines; layout-only, no event
  handling) and `SplitView.swift` (595 lines; package-resolved pane frames).
- `Sources/TesseraCore/Views/`: `Text.swift:5-102` (non-wrapping, sized by cell width),
  `LeafView`, `ForEach`, `ConditionalView`, `IdentifiedView`, `Binding`, `ViewBuilder`,
  `AnyView`.
- No Button, TextField, Toggle, List, Table, or focus manager exists in HEAD. The Showcase
  inspector is static text (`ShowcaseView.swift:135-184`) with `"[Button placeholder]"`
  (`:149`) and `"[Toggle placeholder]"` (`:150`).
- Phase 4 designs (investigations 027, 028, 034, 035, 036) describe `FocusManager`,
  responder ownership, `TextField`, `Button`, `Table`, and scroll focus. They exist only
  in `archive/phase4` (e.g.
  `git show archive/phase4:Sources/TesseraCore/Runtime/ViewGraph.swift`, `dispatch` near
  `:162`).
- `Examples/Tests/`: `TesseraShowcaseTests`, `Phase3ProtocolsDemoSupportTests`.
  `ShowcaseFixtureTests.swift` uses `VirtualTerminal.snapshot(size:)` with inline
  snapshots, reads clips via `graph.diagnostics.nodes` (`:258-273`), and tests a
  responsive boundary table (`:159-201`).
- `@Test` counts (grep, not line-cited): Core 29, Layout 24, ANSI 68, Buffer 38, Terminal
  139, TerminalIO 144 (151 with parameterized attributes), Input 95, Rendering 82,
  SnapshotSupport 15, Widgets 21, Architecture 1; Showcase 9 (11 attributes), Phase 3 13.

### 6. Determinism inventory

Deterministic today: layout (integer math with documented rounding, Spec.md:6799-6800);
in-memory device and session replay fixed input and record bytes; `GraphDiagnostics`
excludes timing; keyed reconciliation preserves identity; Ghostty snapshots have no
scrollback.

Not deterministic or not injectable:

- `ViewGraph` stats read `ContinuousClock` directly (`ViewGraph.swift:81,99,119`).
- Probe sleep is seamed (`TerminalSession.swift:233-234`); `probeImageID` is random
  (`:232`), so Kitty IDs differ per run.
- Capability detection reads `WT_SESSION` (`TerminalCapabilityDetector.swift:66,83-84`)
  and `TERM`/`TERMINFO` (`TerminfoDatabase.swift:174-201`); tests override by passing a
  dictionary.
- No `TESSERA_*` runtime debug flags exist.
- Spec.md:8381-8455 leaves the Phase 5 clock question open, leaning toward an owned-seam
  pattern.

### 7. Logging, tracing, telemetry

- A grep of `Sources/` for `print`, `Logger`, `os_log`, and `OSLog` finds nothing.
- The Spec allows only immutable, local diagnostics: no serialization, persistence,
  logging, telemetry, or remote transport (Spec.md:7422-7441, 7437, 7551).
- The only raw-protocol debug path is `InputEvent.unknown(bytes:)` ("surface for
  debugging", Spec.md:2736). Spec.md:3145 calls byte-visible events "enormous for
  debugging".

### 8. Architecture enforcement

- `Tests/TesseraArchitectureTests/ImportBoundaryTests.swift:11-16` forbids `AppKit`,
  `CTesseraTerminalPlatform`, `SwiftUI`, `TesseraTerminalIO`, and `UIKit` in Core, Layout,
  Widgets, and Tessera.
- `scripts/check-package-boundaries.py:8-30` declares `ALLOWED_DIRECT_DEPENDENCIES`
  (`:12`) and `ALLOWED_PRODUCT_DEPENDENCIES` (`:25`) for Core, Layout, Widgets, Tessera,
  and TesseraTestSupport; the check runs at `:102`.
- `justfiles/quality.just:48-55` `architecture` runs the boundary check and
  `scripts/check-frame-region-ownership.sh`, a compile-fail probe for `FrameRegion` escape
  (`Tests/CompileFailFixtures/FrameRegionEscape.swift`). Spec.md:6952-6970 documents
  these.

### 9. Tooling entry points

- `Justfile` modules: `core`, `linux`, `windows-utm`, `windows-frost`, `quality`, `ci`,
  `docs`, `setup`.
- `justfiles/core.just`: `build` (`:7`) depends on `build-libghostty-vt` (`:11`); `doctor`
  (`:15`) runs `scripts/dev-state.sh`, which prints paths for Ghostty, the Linux VM, and
  Windows Frost, not app state; `test` (`:27`) runs `swift test --no-parallel`;
  `test-coverage` (`:31`); `coverage-summary` (`:35`); `example` (`:39`); `showcase`
  (`:57`); `examples` (`:61`).
- `justfiles/linux.just`: `start` (`:21`), `shell` (`:29`), `stop` (`:37`), `delete`
  (`:41`), `test *args` (`:45`) runs `scripts/linux-test.sh` in a Lima VM. The VM name
  comes from `TESSERA_LINUX_VM_NAME` (`docs/LocalDevelopmentState.md:79-82`).
- `justfiles/ci.just`: `check` (`:10`) is core test plus quality lint; `ci-windows`
  (`:21`).
- `DevTools/Sources/LinuxVMTests/LinuxVMTests.swift:1-46` is a thin wrapper around
  `just linux test`.

### 10. Cross-platform constraints

- Linux: tests run in a Lima VM (`justfiles/linux.just:45`). Terminal PTY tests are
  macOS-first (investigation 005).
- Windows: `Tests/TesseraTerminalIOTests` has `#elseif os(Windows)` branches
  (`PlatformHandlesTests.swift:32`, `CleanupRegistryTests.swift:173`,
  `PlatformIOSizeTests.swift:76`). Windows work runs in the UTM Frost VM
  (`justfiles/windows-frost.just`; investigations 007, 008, 012).
- `TesseraCore`, `TesseraLayout`, and `TesseraWidgets` contain no `#if` conditionals (grep
  count 0). Platform differences stay in the terminal and snapshot layers.
- SIGWINCH is POSIX-only (`TerminalResizeRegistry.swift:63`).
- [INFERENCE] Windows size changes likely pass through the same
  `PlatformIO`/`TerminalDevice` seam (not verified here), and Windows resize uses console
  events rather than signals.

### 11. Documentation state

- `LocalDevelopmentState.md:17-20` says Windows skips Ghostty. **Stale**:
  `Package.swift:450-458` and `ci.yml:232-235` build it on Windows.
- `ProjectStatus.md:40-46` says the Showcase is "being retired";
  `Examples/Sources/TesseraShowcase` exists.
- `ProjectStatus.md:22-23` (full suite on three platforms with Ghostty snapshots) and
  `Testing-Terminal-Output.md:63-65` agree with CI.
- `Spec.md:8381-8390` calls the Windows snapshot story a "remaining gap". **Stale**.

## Capability table

| Capability                                            | Status  | Evidence                                                                      |
| ----------------------------------------------------- | ------- | ----------------------------------------------------------------------------- |
| Run a Tessera app in a real terminal                  | Have    | `TerminalSession.swift:345`; `TesseraShowcaseApp.swift:17-61`                 |
| Run headless with scripted input bytes                | Have    | `InMemoryTerminalDevice.swift:67`; `InMemoryTerminalSession.swift:4-56`       |
| Capture every byte written                            | Have    | `InMemoryTerminalDevice.swift:31`; `ShowcaseTerminalSessionTests.swift:12-45` |
| Record lifecycle events (alt screen, raw mode, flush) | Have    | `InMemoryTerminalDevice.swift:5-20`                                           |
| Render a view tree to a frame without a terminal      | Have    | `ViewGraph.swift:111`; `FrameSnapshot.swift:10-27`                            |
| Assert terminal text, styles, links, cursor           | Have    | `VirtualTerminalSnapshotting.swift:14-59`; `ScreenSnapshot.swift:4-17`        |
| Snapshot the view graph tree                          | Have    | `ViewGraphSnapshotting.swift:4-92`                                            |
| Snapshot diagnostics without timing                   | Have    | `GraphDiagnosticsSnapshotting.swift:5-152`                                    |
| Per-node identity, frame, clip, proposal, size        | Have    | `NodeDiagnostics.swift`; `ViewGraph.swift:53`                                 |
| Textual dump of the runtime tree                      | Have    | `ViewGraph.swift:144`; `DiagnosticsTests.swift:14`                            |
| Read a node's clip in a test                          | Have    | `ShowcaseFixtureTests.swift:258-273`                                          |
| Deterministic layout                                  | Have    | Spec.md:6799-6800                                                             |
| Deterministic keyed reconciliation                    | Have    | `ReconciliationTests.swift:169-170`                                           |
| Skip Ghostty-dependent suites when absent             | Have    | `ghosttyUnavailable.swift:9-58`                                               |
| Import and layering enforcement                       | Have    | `ImportBoundaryTests.swift:11-16`; `check-package-boundaries.py:8-30`         |
| FrameRegion escape compile-fail probe                 | Have    | `scripts/check-frame-region-ownership.sh`                                     |
| Snapshot tests on macOS, Linux, Windows               | Have    | `ci.yml:232-235`; `ProjectStatus.md:22-23`                                    |
| Inject terminal size without a resize event           | Partial | `InMemoryTerminalDevice.swift:75`                                             |
| Dirty-region inspection at runtime                    | Partial | `BufferDiff.swift:14`, package-only                                           |
| Frame diff inspection at runtime                      | Partial | `Renderer.swift:28-46`, package-only                                          |
| Clock injection for terminal probes                   | Partial | `TerminalSession.swift:233-234`                                               |
| Cross-platform terminal tests                         | Partial | Windows branches in `Tests/TesseraTerminalIOTests`; Linux via Lima            |
| Doctor report of dev state (not app state)            | Partial | `scripts/dev-state.sh` via `justfiles/core.just:15`                           |
| Live resize injection in in-memory path               | Missing | `InMemoryTerminalDevice.swift:44-60` passes no `sizeChanges`                  |
| Clock injection into runtime stats                    | Missing | `ViewGraph.swift:81,99,119`                                                   |
| Deterministic probe IDs                               | Missing | `TerminalSession.swift:232`                                                   |
| Route input through the view graph                    | Missing | `ViewGraph.swift:139-140` stub                                                |
| Focus model and focus inspection                      | Missing | Absent from HEAD; only `archive/phase4`                                       |
| Interactive controls (Button, TextField, Toggle)      | Missing | `ShowcaseView.swift:149-150` placeholders                                     |
| Live inspector data in Showcase                       | Missing | `ShowcaseView.swift:135-184` static text                                      |
| Handler/responder inventory per node                  | Missing | `RuntimeNode.swift:20` never populated                                        |
| Focus and requirement change counts                   | Missing | `GraphStatistics.swift:51-52` declared, unused                                |
| Public API for graph, layout frames, dirty regions    | Missing | `RuntimeNode.swift:3` is `package`                                            |
| Logging or trace channel                              | Missing | No logging in `Sources/`                                                      |
| Debug env flags (`TESSERA_*`)                         | Missing | Env used only for capability detection                                        |
| Control socket or remote inspection                   | Missing | Forbidden, Spec.md:7437, 7551                                                 |
| Headless step/drain runtime harness                   | Missing | Sketched only, Spec.md:8381-8455                                              |
| Scripted worlds or deterministic screenshot command   | Missing | Per-example fixtures only                                                     |

## Gap list

1. **Input routing**: `ViewGraph.dispatch` is a stub (`ViewGraph.swift:139-140`).
2. **Focus and controls**: no focus model, Button, TextField, Toggle, List, or Table in
   HEAD; Phase 4 designs live only in `archive/phase4` and investigations 027, 028, 034.
3. **Live resize injection**: the in-memory device cannot emit `.resize`
   (`InMemoryTerminalDevice.swift:44-60, 75`).
4. **Runtime clock**: `ViewGraph` reads `ContinuousClock` directly
   (`ViewGraph.swift:81,99,119`).
5. **Deterministic probe IDs**: `probeImageID` is random (`TerminalSession.swift:232`).
6. **Public inspection surface**: `RuntimeNode` and `Renderer` are `package`; frames,
   dirty regions, and diffs are not public.
7. **Dead diagnostics**: `handlerKinds`, `focusChanges`, `terminalRequirementChanges`
   (`RuntimeNode.swift:20`, `GraphStatistics.swift:51-52`).
8. **Logging and tracing**: no channel; a local opt-in trace is unspecified.
9. **Headless step/drain harness**: sketched at Spec.md:8381-8455, not built.
10. **Scripted worlds and deterministic screenshots**: per-example fixtures only.
11. **Live Showcase inspector**: static placeholder text (`ShowcaseView.swift:135-184`).
12. **Windows resize path**: SIGWINCH is POSIX-only; the Windows mechanism is undocumented
    in tooling docs.
13. **Doc drift**: `LocalDevelopmentState.md:17-20`, `ProjectStatus.md:40-46`,
    `Spec.md:8381-8390`.
14. **Spec canonical loop**: `Spec.md:7394-7409` uses a nonexistent API.
15. **Doctor scope**: `scripts/dev-state.sh` reports environment, not a running app.

## Implications for Tessera devtools

[INFERENCE] These follow from the facts above and are not verified outcomes.

Ideas worth carrying over:

- **Reuse the immutable diagnostics projection.** `GraphDiagnostics`
  (`GraphDiagnostics.swift:5-22`) is already timing-free and value-typed. An inspector can
  read it rather than inventing a second model.
- **Use the in-memory terminal as the headless host.** `InMemoryTerminalDevice` plus
  `VirtualTerminal` give deterministic bytes and a rendered grid. Scripted input bytes
  match Tern's headless-session pattern without a socket.
- **Make the Showcase the first scripted world.** `ShowcaseScript` and `ShowcaseFixture`
  already name scenarios with sizes. A `just` recipe that replays one and prints grid,
  cursor, and diagnostics covers the deterministic-shot case with little new runtime code.
- **Add one seam at a time.** The cheapest is a `sizeChanges` pass-through in
  `InMemoryTerminalDevice.terminalDevice` (`:44-60`), since `TerminalDevice` already
  accepts a stream (`TerminalDevice.swift:50`). A runtime clock would follow the
  `probeSleep` pattern (`TerminalSession.swift:233-234`).
- **Keep devtools outside the view layer.** The import-boundary test and
  `check-package-boundaries.py` keep Core, Layout, and Widgets free of terminal I/O. A
  devtool target should depend on `TesseraTestSupport` or a new support target, not
  `TesseraCore` internals.
- **Expose read-only projections, not handles.** Keep `RuntimeNode` package-internal and
  add a public value-typed API mirroring `NodeDiagnostics`, matching the "immutable local"
  contract (Spec.md:7422-7441).
- **Wire or delete dead fields** (`RuntimeNode.swift:20`, `GraphStatistics.swift:51-52`)
  so a devtool does not show permanent zeros.

Pitfalls:

- **Output is measured through Ghostty, not the buffer.** A "what the app drew" report
  must say whether it means the buffer, emitted bytes, or the terminal's view
  (`FrameSnapshot.swift:10-27`).
- **libghostty is a hard build dependency** for the snapshot target
  (`Package.swift:450-458`); keep the diagnostics path free of it where possible.
- **SIGWINCH is POSIX-only.** A resize-driven devtool must go through `TerminalDevice`
  (`sizeChanges`) to work on Windows.
- **Probe randomness and timing leak into bytes.** `probeImageID`
  (`TerminalSession.swift:232`) changes output across runs; fix the ID or exclude probe
  bytes from snapshots.
- **Doc drift misleads agents.** Cite code, not `LocalDevelopmentState.md:17-20` or
  `Spec.md:8381-8390`, until they are corrected.
- **No remote control socket without a Spec decision.** Spec.md:7437 and 7551 forbid it
  for diagnostics.
- **Copy `withApplicationTerminal`, not the Spec loop** (`TerminalSession.swift:345` vs
  Spec.md:7394-7409).
- **Showcase inspector is placeholder.** Tests against it would assert placeholder text;
  wire real data first.
