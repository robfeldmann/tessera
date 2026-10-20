---
name: Developer tooling for agents and humans
description:
  A headless harness, a scenario language, semantic queries over the view graph,
  deterministic text/grid/SVG shots, invariant checks, event traces, and an opt-in live
  inspection endpoint, built on plan 032's Phase 8 demo runner and landing one capability
  per Phase 4 phase so agents can build, debug, and evaluate Tessera apps unattended.
status: planning
created: 2026-10-19
updated: 2026-10-19
---

<!-- Allowed status values: planning, in-review, pending, in-progress, complete, superseded. -->

## Progress

- [ ] **Phase A — Spikes and seams (before plan 032 Phase 8)**
  - [ ] A.1 Run the five spikes; record findings below
  - [ ] A.2 Land the runtime seams the spikes prove necessary
  - [ ] A.3 Create `TesseraHarness` and migrate spike code mechanically
- [ ] **Phase B — Harness, scenarios, and the demo runner (extends plan 032 Phase 8.2)**
  - [ ] B.1 `Demo` protocol, registry, viewports, and one update policy
  - [ ] B.2 Scenario grammar v0, runner, JSON report, exit codes
  - [ ] B.3 `tessera-dev` executable and `just dev` recipes
  - [ ] B.4 Graph projection, locators v0, invariants v0, text and grid shots
- [ ] **Phase C — Pictures and catalog conformance (with plan 032 Phase 9)**
  - [ ] C.1 SVG shots, light and dark, from the Ghostty screen
  - [ ] C.2 `expect wireframe` and `tessera-dev conform`
- [ ] **Phase D — Focus tooling (with plan 032 Phase 10)**
  - [ ] D.1 Focus fields in the diagnostics projection; `focused` locator; focus verbs
  - [ ] D.2 Focus invariants and the keyboard coverage walk
  - [ ] D.3 Per-event trace with node, focus, and screen diffs
- [ ] **Phase E — Pointer tooling (with plan 032 Phase 11)**
  - [ ] E.1 `mouse` verbs and the `hit` query
- [ ] **Phase F — Live inspection (after Phase D, before plan 032 Phase 13)**
  - [ ] F.1 Debug endpoint in the live runner; `tessera-dev attach`
  - [ ] F.2 Record a live session; replay it headless
- [ ] **Phase G — Semantics and scroll checks (with plan 032 Phases 12–14)**
  - [ ] G.1 Role and label in the projection; `role=`/`label=` locators
  - [ ] G.2 Scroll and collection invariants
- [ ] **Phase H — Docs, skill, and CI gate (closes with plan 032 Phase 17)**
  - [ ] H.1 `docs/DeveloperTools.md`, the `tessera-devtools` skill, AGENTS.md loop
  - [ ] H.2 Scenario corpus in CI; conformance gate for `implemented` docs

## Overview

Tessera renders a view tree headlessly and asserts on cells, styles, cursor, and the
diagnostics tree (investigation 039 §3–4). It cannot drive an app from a script, address
an element by meaning, picture a screen, check invariants, trace an event to a redraw, or
look inside a running app. Phase 4 is about to build focus, pointer input, ScrollView,
controls, and collections (plan 032 Phases 8–17), where the abandoned attempts went
wrong unnoticed (036 lessons 1, 3, 4, 7). This plan gives agents and humans the loop that
caught such defects for Tern and Ternbook (037) and that Lattice designed (038), sized to
HEAD and sequenced so each tool lands in the phase that first needs it. Phase B here *is*
plan 032 step 8.2 with its headless driver generalised into a harness library; later
phases ride along with the component phases they instrument.

## Goals and principles

1. **One grammar, two hosts.** A scenario is a text file, one statement per line, shell
   quoting, `#` comments (037 §3; 038). The same file runs in-process against
   `VirtualTerminal` and later against a live session; it is a test, a bug report, and a
   catalog fixture. Verbs the runner cannot yet honour are listed in a "not yet
   expressible" table, never faked (038 Findings 1).
2. **The runner evaluates expectations from a projection the runtime returns.** The
   runtime holds no assertion state (038 Findings 1). The projection is
   `GraphDiagnostics` plus `ScreenSnapshot`; nothing else enters it.
3. **Text first, pixels as a review aid.** The Ghostty cell grid is the golden; SVG and
   PNG are never compared as goldens (038 Decision 3; 041 Implications 2, 5).
4. **Time is injected; `wait` advances a clock, never sleeps** (Spec 8339–8346; 041
   Implications 7).
5. **Dull agent contract.** One JSON object per command on stdout when stdout is not a
   terminal (`--json`/`--pretty` force either); exit 0 pass, 1 an expectation or check
   failed, 2 usage or parse error, 3 harness error (app would not start, socket missing,
   Ghostty unavailable). Errors name the accepted vocabulary; a selector that matches
   nothing is an error, not an empty list (037 §5; 038 Findings 4).
6. **No test affordances in product API.** Everything lives in support targets or
   `Examples/`; `TesseraCore` gains only value-typed diagnostics fields, each by Spec
   amendment (036 lesson 5; Spec 7422–7441; 040 req. 8, 10).
7. **The agent tool is a thin wrapper over the protocol the tests use** (041
   Implications 9). Demos find library bugs; the harness never compensates (036 lesson
   7). Spike code and generated artefacts are committed only as tagged evidence.

## Tool surface

| Piece | User | Lands | Needs (039 gap list) |
| --- | --- | --- | --- |
| `TesseraHarness` library: driver, scenario parser/runner, projection, locators, invariants, shot encoders, report | both | B | 6 (package access to `Renderer`), 3, 4 |
| `tessera-dev` CLI: `demo list\|run`, `run`, `shot`, `tree`, `check`, `conform`, `attach`, `replay` | agent | B, C, F | — |
| Scenario language `.scn` | both | B, D, E, G | 1 (dispatch) for `key` reaching views |
| Locators `type= id= text= nth= focused role= label=` | agent | B, D, G | focus and semantics in schema |
| Shots: `NAME.txt`, `NAME.grid.txt`, `NAME.tree.json`, `NAME.svg` (light, dark) | both | B, C | — |
| Trace: per-event JSONL of event, counters delta, changed nodes, focus, changed rows | both | D, F | 4 (clock), 7 (dead counters) |
| Invariants `check [rule…]`: pure function over projection + screen | both | B, D, G | — |
| Keyboard coverage walk | agent | D | focus in schema |
| Live endpoint `TESSERA_DEBUG_SOCKET` + `attach` | agent | F | owner decision 2; draw tap seam |
| Catalog conformance `expect wireframe` / `conform` | both | C | — |

### `TesseraHarness` (root package target and product)

A library beside `TesseraTestSupport`, depending on `Tessera`, `TesseraTerminal`,
`TesseraTerminalSnapshotSupport`, `TesseraTerminalTestSupport`, and `Foundation`
(JSONEncoder, sorted keys). It is in the root package because it needs package-visible
seams (`Renderer.render`, `InMemoryTerminalDevice.terminalDevice`,
`TerminalSession.init(configuration:io:environment:)`), which a path-dependent package
cannot see; it ships as a product so app authors run scenarios in their own tests and
embed the same CLI (`HarnessCLI.main(registry:)`). `check-package-boundaries.py` and
`ImportBoundaryTests` gain its allowlist row. It never imports SnapshotTesting; the
`.scenario` snapshot strategy lives in `TesseraTestSupport` and wraps the harness.

### The driver and the `Demo` contract (shared with plan 032 Phase 8.2)

```swift
public protocol HeadlessApp {                // in TesseraHarness
  associatedtype Root: View
  init()
  var root: Root { get }                     // called by the graph's root closure
  mutating func apply(_ event: InputEvent)   // app-owned model update
}
public protocol Demo: HeadlessApp {          // in Examples/DemoSupport
  static var name: String { get }            // registry key, kebab-case
  static var minimum: TerminalSize { get }   // the catalog `min`
  static var fixtures: [Viewport] { get }    // default [.desktop, .mobile]
}
public enum Viewport { case desktop, mobile, mobileScreen, custom(TerminalSize) }
```

`Driver.step(event)` runs the canonical loop once: `resize` → `graph.dispatch` →
`app.apply` → `graph.update()` → `Buffer` → `Renderer.render` → the Ghostty
`VirtualTerminal`. One update per event, presentation after it, identical in the live
runner (040 req. 2). `desktop` is 80x24; `mobile` is 40 columns at the natural height
the driver measures (tokens.md:21; owner decision 1); `mobileScreen` is 40x16 for
screen-filling demos. Scenario verbs produce `InputEvent` values; a `bytes` verb feeds
`InputParser` when parser coverage is the point (040 req. 4).

### Scenario grammar v0 (HEAD-capable) and later verbs

```text
# header (before the first statement)
app text-wrap                 size 80x24 | size mobile      clock manual
# world and input
resize 40x16                  key Tab | key Shift+Tab | key Ctrl+C    type "hi"
paste "…"                     bytes "\x1b[A"                wait 250
mouse click 3,4 | mouse move 3,4 | mouse scroll down 3,4    (Phase E)
focus SEL                                                   (Phase D)
# observation
shot NAME                     dump [SEL]                    tree [SEL]
# expectation
expect text ROW "…"           expect screen <<EOF … EOF     expect cell R,C bold
expect node SEL frame X,Y WxH expect node SEL visible|clipped|count N
expect focused SEL            expect wireframe design/widgets/button.md 2   (C, D)
check [rule…]
```

`SEL` is `key=value` pairs: `type=Text`, `id=root/1/0`, `text="Submit"` (rendered text
inside the node's frame), `nth=2`; Phase D adds `focused`, `focusable`; Phase G adds
`role=button`, `label="Submit"`. Locators re-resolve on every statement (041
Implications 4). Key names follow Playwright (`Enter`, `ArrowLeft`, `Meta+k`); an unknown
name lists the accepted set, as Tern's error does. `wait` advances the injected clock
only. A failing `expect` is recorded with the screen text at that moment and the run
continues; `check` failures are expectations too.

### Projection, locators, diffs, invariants

`Projection` is sorted-key JSON of `GraphDiagnostics` plus the screen (`rows`, `cursor`,
per-cell style runs). `diff(a, b)` lists nodes added, removed, and changed by field, and
screen rows changed. Invariants are a pure `check(projection, screen, rules:) ->
[Violation{rule, node, detail}]` with stable kebab-case ids:

- v0 (B): `no-dirty-after-pass`, `frame-inside-clip` (warns on clipped content),
  `measured-within-proposal`, `siblings-disjoint` (stack children; `ZStack` and overlays
  exempt by type), `requirements-aggregate`.
- D: `exactly-one-focus`, `focus-resolves`, `focused-visible` (frame ∩ clip non-empty,
  the investigation 034 bug), `tab-cycle-terminates`.
- G: `scroll-offset-within-content`, `selection-visible`, `unique-collection-ids`.

`NodeState` single ownership is not checkable from the projection (the schema excludes
`NodeState`); it stays a review rule, backed by an `ast_grep` lint in `just quality` that
flags responder or wrapper stores mirroring a `NodeState` row (design/README.md:240).

### Shots

`shot NAME` writes `NAME.txt` (`.terminalText(trim: .trailing)`), `NAME.grid.txt`
(`.terminalStyledGrid`), `NAME.tree.json`, and from Phase C `NAME.svg` and
`NAME-dark.svg`: rect-per-cell backgrounds, text runs, a fixed palette per theme, no font
rasterisation, byte-stable across platforms. PNG is an optional macOS-only review aid
behind `#if canImport(CoreGraphics)`, never a golden. Files are written only when bytes
differ (037 §4).

### Trace and replay

`Driver` records one JSONL record per step: `seq`, `event`, statistics delta, changed
node identities, focus before/after, changed screen rows. The scenario *is* the replay
file for headless runs; Phase F records the events a live session delivered
(`TESSERA_TRACE=<file>`) for `tessera-dev replay FILE --app NAME`. `InputEvent` stays
non-`Codable` in Core; the harness owns a codable mirror.

### Live inspection (Phase F, owner decision 2)

The live runner (the same `Driver` under `TerminalSession.withApplicationTerminal`)
opens, when `TESSERA_DEBUG_SOCKET=<path>` is set, a Unix-domain NDJSON endpoint in a
`0700` directory, one request one reply (`{"ok":…}`): `text`, `grid`, `tree [SEL]`,
`stats`, `shot`, `key`, `type`, `mouse`, `resize`, `quit`. Injected input enters the
runner's event merge before `step`, so it takes the normal path (oh-my-pi, 041 §3).
Serialisation happens in `TesseraHarness`, never in `TesseraCore`. The in-process
transport stays primary so Windows CI runs every scenario; the socket is POSIX-first.

### Catalog conformance (Phase C)

`expect wireframe PATH N` compares the current screen (trimmed rows) with the N-th
`wireframe WxH` fence in a catalog doc at matching size; the grid is pristine by rule
(design/README.md:138), so the compare is cell-for-cell with a per-cell diff on failure.
`tessera-dev conform [DOC…]` lists every fence in `ready`/`implemented` docs with the
scenario that pins it, or `unpinned`; from Phase H the gate fails for `implemented` docs
with unpinned fences (design/README.md:318).

## Sequencing against plan 032

| This plan | Runs | Why there |
| --- | --- | --- |
| A | now, before 032 Phase 8 | seams and the harness skeleton must exist before the runner is written twice |
| B | = 032 step 8.2; 8.3 demos are written as scenarios | one runner, one registry, one update policy |
| C | with 032 Phase 9 | borders and styles are what SVG and wireframes show |
| D | with 032 Phase 10 | focus enters the schema; coverage walk needs Tab routing |
| E | with 032 Phase 11 | pointer verbs need hit testing |
| F | after D, before 032 Phase 13 | controls get built with live inspection available |
| G | with 032 Phases 12–14 | roles and labels appear with controls; scroll invariants with ScrollView |
| H | through 032 Phase 17 | the corpus and conformance gate close Phase 4 |

Plan 032 amendments this plan asks for: step 8.2 reads "`mobile` is 40 columns at natural
height; `mobileScreen` is 40x16" (tokens.md:21); step 8.2 names `TesseraHarness` as the
headless driver's home; the Phase 10–14 acceptances each gain "and its scenario corpus
passes under `tessera-dev run`".

## Phase A — Spikes and seams

**Goal**: de-risk the design with code against HEAD, then land the minimal seams.

### Step A.1 — Run the five spikes

- See "Spikes": half a day each, a "proves / does not prove" README, findings recorded
  below. Standalone spikes use only public API, which is itself evidence of missing seams.

### Step A.2 — Land the runtime seams

- `InMemoryTerminalDevice`: a `sizeChanges` continuation so `resize(to:)` emits a live
  `.resize` through `PlatformIO` (`InMemoryTerminalDevice.swift:44-60`,
  `TerminalDevice.swift:50`); `InMemoryTerminalSession.resize(to:)` exposes it.
- `ViewGraph`: pass durations read an injected `Clock` (`ViewGraph.swift:81,99,119`),
  defaulting to `ContinuousClock`, following `probeSleep` (`TerminalSession.swift:233`).
- `TerminalSession`: `probeImageID` injectable; a package-visible draw observer handing
  the harness each `draw`'s encoded bytes (Phase F's mirror).
- Dead counters: wire `focusChanges` and `terminalRequirementChanges`; drop `handlerKinds`
  until Phase 10 populates it (`RuntimeNode.swift:20`, `GraphStatistics.swift:51-52`).
- Acceptance: a test delivers a mid-session `.resize` through `InMemoryTerminalSession`
  and observes a redraw at the new size; durations are deterministic under a manual
  clock; no new `public` API outside the diagnostics projection.

### Step A.3 — Create `TesseraHarness` and migrate spikes mechanically

- Add the target, product, boundary allowlist rows, and `swiftSettings` entry; move spike
  code with goldens byte-identical before any addition (038 Lessons).
- Acceptance: `swift build` and `just quality architecture` green; `spikes/README.md`
  says "nothing new goes here".

## Phase B — Harness, scenarios, and the demo runner

**Goal**: plan 032 step 8.2 delivered through the harness; a demo's snapshot is a few
lines; an agent runs and reads a scenario without prose.

### Step B.1 — `Demo` protocol, registry, viewports, one update policy

- `Examples/Sources/DemoSupport`: `Demo`, `DemoRegistry` (one selection point, fails
  closed on duplicates), `Viewport`. Port `ApplicationDriver`'s update policy and
  `DemoHost.isQuitKey` whole-key matching (036 lesson 6).
- Acceptance: registry tests cover duplicates and lookup; live and headless share the
  one `Driver`.

### Step B.2 — Scenario grammar v0, runner, JSON report, exit codes

- Header-binding, fail-fast parser (`FILE:LINE: error:`); the runner continues after a
  failed expectation; `ScenarioReport` is the single source of human and JSON forms.
- Acceptance: two runs give identical bytes; a parse error under `--json` is a failure
  with verb `parse`; exit codes match the contract; `Scenarios/README.md` carries the
  grammar, the events-not-bytes decision, and the "not yet expressible" table.

### Step B.3 — `tessera-dev` executable and `just dev` recipes

- `Examples/Sources/TesseraDev` is `HarnessCLI.main(registry: DemoRegistry.all)`:
  `demo list`, `demo run NAME`, `run FILE…`, `shot FILE… --out DIR`, `tree --app NAME`,
  `check --app NAME`; `justfiles/dev.just` mirrors them. `help COMMAND` prints real text
  (037 pitfalls).
- Acceptance: every command honours `--json`; `just dev scenarios` runs the corpus.

### Step B.4 — Projection, locators v0, invariants v0, text and grid shots

- Acceptance: step 8.3's demos (Text, stacks, frame/padding, ZStack, Flex) each have a
  scenario with `shot` at `desktop` and `mobile` and one `expect node … frame`; the
  `.scenario` strategy makes a demo's snapshot test three lines.

## Phase C — Pictures and catalog conformance

**Goal**: a human reviews a border or style change from an image; a wireframe is pinned
by the scenario that renders it.

- C.1 SVG light and dark from `ScreenSnapshot`; palette and theme mapping documented;
  `pixel`-free determinism proved by SHA-256 across macOS and Lima Linux.
- C.2 `expect wireframe` and `conform`; the first pinned fences are Border, Box, and
  Divider from plan 032 step 9.3.
- Acceptance: `tessera-dev shot` emits four files per shot; `conform design/primitives`
  reports pinned and unpinned fences in JSON; Phase 9 demos read identically in SVG and
  `.txt`.

## Phase D — Focus tooling

**Goal**: "why did focus move" is answerable from a trace, and every focusable control is
proved reachable by keyboard.

- D.1 Spec amendment adds `isFocusable`, `isFocused`, and populated `handlerKinds` to the
  projection (Spec 7416–7418 already promises them in `dump()`); `focused`/`focusable`
  locators; `focus SEL` and `expect focused SEL` verbs.
- D.2 Rules `exactly-one-focus`, `focus-resolves`, `focused-visible`,
  `tab-cycle-terminates`; `tessera-dev coverage --app NAME`: from initial focus press
  Tab and Shift+Tab until the walk returns or stalls, arrows inside containers, shortest
  route per focusable with levels `landmark`, `tab_only`, `unreachable`, and a stop reason
  (037 §7). Output is one sorted-key JSON per app, diffable per release.
- D.3 Per-step trace with focus before/after; `tessera-dev run --trace FILE`.
- Acceptance: the Phase 10 focus and KeyLegend demos ship with scenarios asserting
  `focused`; coverage reports no `unreachable` focusable in any demo; a deliberate
  invisible-focus fixture fails `focused-visible`.

## Phase E — Pointer tooling

- `mouse click|move|scroll|down|up`, `hit X,Y` query returning the deepest node path and
  whether it captured; traces record capture changes.
- Acceptance: plan 032 Phase 11's overlap, clipping, capture, and de-escalation tests
  are scenarios too.

## Phase F — Live inspection

- F.1 The endpoint described above in the live runner; `tessera-dev attach PATH CMD…`
  and `--file SCENARIO` against a live app; socket removed on `quit`; a missing socket is
  a JSON error with exit 3. Documented as POSIX-first.
- F.2 `TESSERA_TRACE` recording in the live runner; `replay` reruns headless and reports
  the first diverging screen row.
- Acceptance: a Phase 10 demo running in a real terminal answers `text`, `tree
  focused`, and `key Tab` from a second shell; the transport-parity test runs every
  scenario in-process and over the socket with identical reports.

## Phase G — Semantics and scroll checks

- G.1 Owner decision 4: `role` and `label` as value-typed, optional projection fields set
  by library controls through an internal hook (not public view API); `role=`/`label=`
  locators; v0 fallback derives role from `viewType`.
- G.2 Rules `scroll-offset-within-content`, `selection-visible`,
  `unique-collection-ids`; `expect node SEL visible` understands scroll clips.
- Acceptance: every Phase 13 control demo is driven by `role=`/`label=` locators, never
  coordinates; Phase 12 and 14 demos end with `check`.

## Phase H — Docs, skill, and CI gate

- H.1 `docs/DeveloperTools.md`, `.agents/skills/tessera-devtools/SKILL.md` (the loop:
  `demo run` → `run` → read JSON → `shot` → `tree` → `check` → fix the library, never
  the demo), an AGENTS.md pointer, the Spec's diagnostics paragraph amended per
  decisions 2 and 4, and the doc drift 039 §11 names fixed.
- H.2 `just ci check` runs `just dev scenarios` and `conform` on `implemented` docs;
  plan 032 step 17.1's intro app has a scenario per screen.
- Acceptance: a fresh agent given only the skill drives a demo, reads a failure, and
  produces a shot without reading source; CI fails on an unpinned `implemented` wireframe.

## Spikes

Spikes 1–4 are standalone packages under `spikes/<Name>/` depending on Tessera by path
(`../..`), public API only, hand-rolled argument parsing, as Lattice did (038 Findings
7); Spike 5 edits root sources, so it is a branch-local target and test. Each README
states what it proves and does not prove. Nothing in `spikes/` is imported by the root
package; Phase A.3 migrates by copy.

### Spike 1 — HeadlessRunner

- Hypothesis: a scenario file with `size`, `resize`, `key`, `type`, `shot`, `expect
  text`, `expect node … frame`, and `tree` can drive a HEAD app (Text, stacks,
  layout-only ScrollView, SplitView) through `ViewGraph` + `VirtualTerminal.snapshot`,
  emit the JSON/exit-code contract byte-identically across two runs, and derive `mobile`
  natural height from `GraphDiagnostics` under a tall proposal.
- Read: `Examples/Tests/TesseraShowcaseTests/ShowcaseFixtureTests.swift:203-289`,
  `Sources/TesseraTerminalSnapshotSupport/FrameSnapshot.swift`,
  `Sources/TesseraCore/Runtime/ViewGraph.swift:53-147`, `Examples/Sources/TesseraShowcase/
  ShowcaseModel.swift:72-84`, investigation 037 §3, §5, 038 Findings 4.
- Pass: `swift run headless run Scenarios/*.scn --json` prints one line per file with
  `scenario`, `passed`, `failures`; exit 0/1/2 as specified; `shasum` equal over two
  runs; a wrong `expect text` fails with expected, actual, and the screen. Fail: any
  statement needs package API, or natural height cannot be read from the projection.
- Findings:

### Spike 2 — GraphQuery

- Hypothesis: `GraphDiagnostics` plus `ScreenSnapshot` support locators `type=`, `id=`,
  `text=`, `nth=`, a field-level node diff across a resize, and v0 invariants, with
  sorted-key JSON output, using no `RuntimeNode` access.
- Read: `Sources/TesseraCore/Diagnostics/{GraphDiagnostics,NodeDiagnostics,
  GraphStatistics}.swift`, `Sources/TesseraCore/Runtime/ViewGraph.swift:144-160`,
  `Sources/TesseraTestSupport/GraphDiagnosticsSnapshotting.swift`, investigation 041
  Implications 3–4, 038 Findings 3.
- Pass: `query 'text="Hello"'` returns exactly one node with frame; a no-match is
  `{"ok":false}` exit 1; `diff before.json after.json` lists changed frames after
  `resize 40x16`; `check` flags a crafted overlap and a clipped Text. Fail: identity paths
  are unstable across `update()` for unchanged trees, or text-in-frame is ambiguous for
  overlapping nodes without a tie-break.
- Findings:

### Spike 3 — SvgShot

- Hypothesis: a `ScreenSnapshot` renders to SVG (rects + text runs, fixed light and dark
  palettes mapped from `RenderedColor`, attributes bold/dim/italic/underline/strike/
  reverse) that is byte-stable, under 100 KB at 80x24, and legible when rasterised.
- Read: `Sources/TesseraTerminalSnapshotSupport/{RenderedCell,ScreenSnapshot}.swift`,
  `RenderedColor` in `TesseraTerminalANSI`, investigation 041 §1 (Textual SVG), 038
  Decision 3, Lattice `docs/design/devtools.md:86`.
- Pass: identical SHA-256 for two renders and for macOS vs Lima Linux; light and dark
  files differ only in palette; a wide grapheme occupies two cells; `read :img` of the SVG
  shows the demo. Fail: text-run SVG needs font metrics to align, or size exceeds budget.
- Findings:

### Spike 4 — LiveSocket

- Hypothesis: a dev-owned run loop over `TerminalSession.withApplicationTerminal` can
  serve `text`, `tree`, `key`, and `quit` over a Unix-domain NDJSON socket with injected
  keys taking the normal `step` path, using only public API plus a render mirror; the
  spike names the one seam (draw tap) that removes the double render.
- Read: `Sources/TesseraTerminal/TerminalSession.swift:99-165, 345-360, 593-647`,
  `Examples/Sources/TesseraShowcase/TesseraShowcaseApp.swift:17-61`, investigation 041 §3
  (oh-my-pi ops), 037 §2, §5 (reply envelope, `quit` removes socket).
- Pass: from a second shell, `printf '{"op":"text"}' | nc -U sock` returns the screen;
  `key Tab` changes the app and the next `text` shows it; `quit` removes the socket; a
  missing socket gives a JSON error, exit 3. Fail: input cannot be merged ahead of
  `nextEvent` without touching `TesseraTerminal`.
- Findings:

### Spike 5 — Seams (branch-local, root package)

- Hypothesis: a `sizeChanges` pass-through in `InMemoryTerminalDevice`, an injected clock
  in `ViewGraph`, and an injectable `probeImageID` are each under 40 lines, package-
  visible, and leave every existing snapshot byte-identical.
- Read: `Sources/TesseraTerminalTestSupport/InMemoryTerminalDevice.swift:41-77`,
  `Sources/TesseraTerminalIO/{TerminalDevice,PlatformIO}.swift`,
  `Sources/TesseraCore/Runtime/ViewGraph.swift:78-125`,
  `Sources/TesseraTerminal/TerminalSession.swift:228-236`, investigation 039 §2, §6.
- Pass: a test delivers `.resize` mid-session through `InMemoryTerminalSession` and
  observes a second draw at the new size; `swift test` green with no golden changes;
  `just quality architecture` green. Fail: `PlatformIO` cannot merge a second stream
  without a public change, or the clock touches `GraphDiagnostics` equality.
- Findings:

## Owner decisions

1. **`mobile` viewport: 40x16 or 40 x natural.** (a) 40x16 everywhere (plan 032 step
   8.2, widget template); (b) 40 columns at natural height, 40x16 only for screen-filling
   compositions (tokens.md:21, design/README.md:64, owner decision 2026-10-10).
   Recommendation: (b), as `Viewport.mobile` and `.mobileScreen`, each demo declaring
   `fixtures`; amend plan 032 step 8.2 and `design/templates/widget.md:38`. Cost of being
   wrong: one fixture regeneration.
2. **Live inspection versus Spec 7437/7551.** (a) keep the prohibition, headless only;
   (b) amend the Spec so `TesseraCore` still serialises nothing while `TesseraHarness`
   may expose an opt-in loopback endpoint in dev runners; (c) a TCP port like Textual.
   Recommendation: (b), Unix socket in a `0700` directory, only under
   `TESSERA_DEBUG_SOCKET`, POSIX-first: the piece Tern, oh-my-pi, and Textual all have
   and the one an agent needs for a running app. [INFERENCE] If rejected, agents fall
   back to print debugging in demos, which the Spec also forbids.
3. **Where devtools live.** `DevTools/`, `Examples/`, or a root target. Recommendation:
   harness library in the root package (needs package seams; ships like
   `TesseraTestSupport`); demos, registry, and `tessera-dev` in `Examples/`, which
   already depends on `tessera` by path; `DevTools/` stays for environment wrappers.
4. **Role and label in the frozen diagnostics schema.** (a) derive role from `viewType`
   and label from rendered text (no schema change; brittle for custom controls); (b) add
   optional `role`/`label` fields set by library controls through an internal hook (Spec
   amendment; no public view API). Recommendation: (a) in Phase B, (b) in Phase G, while
   deciding whether an app-facing label modifier is 1.0 (036 lesson 5 is the warning).
5. **omp2 capture program.** Uncommitted; step 7.4 deletes it (040). Recommendation: tag
   `archive/omp2-gallery` before 7.4 and port nothing; its `#!` fixture directives are
   prior art for scenario headers and its review site for a later shot-review page; the
   probe-theme trick is unnecessary because Tessera knows its own roles.
6. **Scenario input: events or bytes.** Recommendation: typed `InputEvent` verbs with a
   `bytes` escape hatch (one grammar, parser coverage on demand).
7. **Animation clock timing.** Spec 8358 says not Phase 4; plan 032 step 16.1 says 1.0.
   The harness injects a clock from Phase A either way; only motion `wait` semantics
   wait on this.

## Acceptance

- Spikes 1–5 have findings; A.2 seams landed with no public API growth outside the
  diagnostics projection.
- `TesseraHarness` passes the boundary gates and is the headless driver plan 032 step
  8.2 names; `tessera-dev` runs every demo live and headless from one registry; every
  command honours the JSON and exit-code contract and two runs give identical bytes.
- By plan 032 Phase 10: focus is addressable, traced, invariant-checked, and
  coverage-walked; by Phase 13: every control demo is driven by semantic locators; by
  Phase 17: the corpus and `conform` run in CI and the skill lets a fresh agent complete
  the loop unaided. The Spec's diagnostics paragraph and plan 032 carry the amendments.

## References

- Investigations 036–041; `docs/Spec.md:7382-7441, 7545-7551, 8339-8346`;
  `design/README.md:60-67, 115-143, 240-245, 272-282, 318-319`; `design/tokens.md:14-26`;
  plan 032 `:501-543`; Lattice `docs/design/devtools.md` (Principles, `lattice dev`
  family, Decisions 2–3); Tern `tern help dev` as recorded in 037.
