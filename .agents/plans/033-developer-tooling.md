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
  - [x] A.1 Run the five spikes; record findings below (`939beb0`, `ce0a046`, `30e4bbf`)
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
controls, and collections (plan 032 Phases 8–17), where the abandoned attempts went wrong
unnoticed (036 lessons 1, 3, 4, 7). This plan gives agents and humans the loop that caught
such defects for Tern and Ternbook (037) and that Lattice designed (038), sized to HEAD
and sequenced so each tool lands in the phase that first needs it. Phase B here _is_ plan
032 step 8.2 with its headless driver generalised into a harness library; later phases
ride along with the component phases they instrument.

## Goals and principles

1. **One grammar, two hosts.** A scenario is a text file, one statement per line, shell
   quoting, `#` comments (037 §3; 038); it runs in-process against `VirtualTerminal` and
   later against a live session, and is a test, a bug report, and a catalog fixture. Verbs
   the runner cannot yet honour are listed, never faked (038 Findings 1).
2. **The runner evaluates expectations from a projection the runtime returns**
   (`GraphDiagnostics` plus `ScreenSnapshot`); the runtime holds no assertion state.
3. **Text first, pixels as a review aid.** The Ghostty cell grid is the golden; SVG and
   PNG are never compared as goldens (038 Decision 3; 041 Implications 2, 5).
4. **Time is injected; `wait` advances a clock, never sleeps** (Spec 8339–8346).
5. **Dull agent contract.** One JSON object per command on stdout when stdout is not a
   terminal (`--json`/`--pretty` force either); exit 0 pass, 1 an expectation or check
   failed, 2 usage or parse error, 3 harness error (app would not start, socket missing,
   Ghostty unavailable). Errors name the accepted vocabulary; a selector that matches
   nothing is an error, not an empty list (037 §5; 038 Findings 4).
6. **No test affordances in product API.** Everything lives in support targets or
   `Examples/`; `TesseraCore` gains only value-typed diagnostics fields, each by Spec
   amendment (036 lesson 5; Spec 7422–7441).
7. **The agent tool is a thin wrapper over the protocol the tests use** (041 Implications
   9). Demos find library bugs; the harness never compensates (036 lesson 7).

## Tool surface

| Piece                                                                                                             | User  | Lands      | Needs (039 gap list)                                                                               |
| ----------------------------------------------------------------------------------------------------------------- | ----- | ---------- | -------------------------------------------------------------------------------------------------- |
| `TesseraHarness` library: driver, scenario parser/runner, projection, locators, invariants, shot encoders, report | both  | B          | 3 (`keepsInputOpen`/`deliverResize`), 4 (clock), 6 (`Renderer`, `lastDrawn`), `RenderedCell` width |
| `tessera-dev` CLI: `demo list\|run`, `run`, `shot`, `tree`, `check`, `conform`, `attach`, `replay`                | agent | B, C, F    | —                                                                                                  |
| Scenario language `.scn`                                                                                          | both  | B, D, E, G | 1 (dispatch) for `key` reaching views                                                              |
| Locators `type= id= text= nth= focused role= label=`                                                              | agent | B, D, G    | focus and semantics in schema                                                                      |
| Shots: `NAME.txt`, `NAME.grid.txt`, `NAME.tree.json`, `NAME.svg` (light, dark)                                    | both  | B, C       | —                                                                                                  |
| Trace: per-event JSONL of event, counters delta, changed nodes, focus, changed rows                               | both  | D, F       | 4 (clock), 7 (dead counters)                                                                       |
| Invariants `check [rule…]`: pure function over projection + screen                                                | both  | B, D, G    | —                                                                                                  |
| Keyboard coverage walk                                                                                            | agent | D          | focus in schema                                                                                    |
| Live endpoint `TESSERA_DEBUG_SOCKET` + `attach`                                                                   | agent | F          | owner decision 2; `lastDrawn` + `size` seams                                                       |
| Catalog conformance `expect wireframe` / `conform`                                                                | both  | C          | —                                                                                                  |

### `TesseraHarness` (root package target and product)

A library beside `TesseraTestSupport`, depending on `Tessera`, `TesseraTerminal`,
`TesseraTerminalSnapshotSupport`, `TesseraTerminalTestSupport`, and `Foundation`
(JSONEncoder, sorted keys). It is in the root package because it needs `package` seams
(`Renderer.render`, `InMemoryTerminalDevice.deliverResize`, `TerminalSession.lastDrawn`
and `init(configuration:io:environment:)`), which a path-dependent package cannot see
(Spike 5 Finding 4); it ships as a product so app authors run scenarios in their own tests
and embed the same CLI (`HarnessCLI.main(registry:)`). `check-package-boundaries.py` and
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
runner (040 req. 2); `Driver` state lives in a non-Sendable class whose methods take
`isolated TerminalSession` (Spike 4). `desktop` is 80x24; `mobile` is 40 columns at the
natural height the driver measures, and is an error for height-greedy demos (owner
decision 1); `mobileScreen` is 40x16. Scenario verbs produce `InputEvent` values; a
`bytes` verb feeds `InputParser` when parser coverage is the point (040 req. 4).

### Scenario grammar v0 (HEAD-capable) and later verbs

```text
app text-wrap    size 80x24 | size mobile | size mobileScreen    clock manual   # header
resize 40x16     key Tab | key Shift+Tab | key Ctrl+C     type "hi"    paste "…"
bytes "\x1b[A"   wait 250     focus SEL (D)     mouse click|move|scroll 3,4 (E)
shot NAME        dump [SEL]   tree [SEL]
expect text ROW "…"     expect screen <<EOF … EOF     expect cell R,C bold
expect node SEL frame X,Y WxH     expect node SEL visible|clipped|count N
expect focused SEL (D)  expect wireframe design/widgets/button.md 2 (C)    check [rule…]
```

`SEL` is `key=value` pairs: `type=Text` (short name; `layout=` for `_LayoutContainer`
algorithms), `id=X` (a user `.id`/`ForEach` key, or a full path), `text="Submit"` (screen
text attributed to the topmost leaf; obscured text does not match), `nth=2`; Phase D adds
`focused`, `focusable`; Phase G adds `role=button`, `label="Submit"`. Locators re-resolve
on every statement (041 Implications 4). Key names follow Playwright (`Enter`,
`ArrowLeft`, `Meta+k`), normalised by the harness (`Ctrl+C` is `c` + control); an unknown
name lists the accepted set. `wait` advances the injected clock only. A failing `expect`
is recorded with the screen and the run continues; `check` failures are expectations too.

### Projection, locators, diffs, invariants

`Projection` is sorted-key JSON of `GraphDiagnostics` (short `type` and `layout`, never
the reflected name; counters without durations; a pass marker) plus the screen (`rows`,
per-cell style runs, `cursor` under its own key). `diff(a, b)` lists nodes added, removed,
and changed by field, and screen rows changed; it ignores the cursor unless asked.
Invariants are a pure
`check(projection, screen, rules:) -> [Violation{rule, node, detail}]` with stable
kebab-case ids:

- v0 (B): `no-dirty-after-pass`, `frame-inside-clip` (warns on clipped content),
  `measured-within-proposal`, `siblings-disjoint` (stack children; `ZStack` and overlays
  exempt by type), `requirements-aggregate`.
- D: `exactly-one-focus`, `focus-resolves`, `focused-visible` (frame ∩ clip non-empty, the
  investigation 034 bug), `tab-cycle-terminates`.
- G: `scroll-offset-within-content`, `selection-visible`, `unique-collection-ids`.

`NodeState` single ownership is not checkable from the projection (the schema excludes
`NodeState`); it stays a review rule, backed by an `ast_grep` lint in `just quality` that
flags responder or wrapper stores mirroring a `NodeState` row (design/README.md:240).

### Shots

`shot NAME` writes `NAME.txt` (`.terminalText(trim: .trailing)`), `NAME.grid.txt`
(`.terminalStyledGrid`), `NAME.tree.json`, and from Phase C `NAME.svg` and `NAME-dark.svg`
(see C.1), byte-stable across platforms. PNG is an optional macOS-only review aid, never a
golden. Files are written only when bytes differ (037 §4).

### Trace and replay

`Driver` records one JSONL record per step: `seq`, `event`, counters delta, changed node
identities, focus before/after, changed screen rows. The scenario _is_ the replay file for
headless runs; Phase F records a live session's events (`TESSERA_TRACE=<file>`) for
`tessera-dev replay FILE --app NAME`. `InputEvent` stays non-`Codable` in Core; the
harness owns a codable mirror.

### Live inspection (Phase F, owner decision 2)

The live runner (the same `Driver` under `TerminalSession.withApplicationTerminal`) opens,
when `TESSERA_DEBUG_SOCKET=<path>` is set, a Unix-domain NDJSON endpoint, one request per
connection, one reply (`{"ok":…}`): `text`, `grid`, `tree [SEL]`, `stats`, `shot`, `key`,
`type`, `mouse`, `resize`, `quit`. A pump forwards `nextEvent()` into the same stream as
control requests, so injected input takes the normal `step` path with no `TesseraTerminal`
change (Spike 4); queries run between steps and read `lastDrawn`, never a second render.
Serialisation happens in `TesseraHarness`, never in `TesseraCore`. The in-process
transport stays primary so Windows CI runs every scenario.

### Catalog conformance (Phase C)

`expect wireframe PATH N` compares the current screen (trimmed rows) with the N-th
`wireframe WxH` fence in a catalog doc at matching size; the grid is pristine by rule
(design/README.md:138), so the compare is cell-for-cell with a per-cell diff on failure.
`tessera-dev conform [DOC…]` lists every fence in `ready`/`implemented` docs with the
scenario that pins it, or `unpinned`; from Phase H the gate fails for `implemented` docs
with unpinned fences (design/README.md:318).

## Sequencing against plan 032

| This plan | Runs                                               | Why there                                                                    |
| --------- | -------------------------------------------------- | ---------------------------------------------------------------------------- |
| A         | now, before 032 Phase 8                            | seams and the harness skeleton must exist before the runner is written twice |
| B         | = 032 step 8.2; 8.3 demos are written as scenarios | one runner, one registry, one update policy                                  |
| C         | with 032 Phase 9                                   | borders and styles are what SVG and wireframes show                          |
| D         | with 032 Phase 10                                  | focus enters the schema; coverage walk needs Tab routing                     |
| E         | with 032 Phase 11                                  | pointer verbs need hit testing                                               |
| F         | after D, before 032 Phase 13                       | controls get built with live inspection available                            |
| G         | with 032 Phases 12–14                              | roles and labels appear with controls; scroll invariants with ScrollView     |
| H         | through 032 Phase 17                               | the corpus and conformance gate close Phase 4                                |

Plan 032 amendments this plan asks for: step 8.2 reads "`mobile` is 40 columns at natural
height, declared per demo; `mobileScreen` is 40x16" and names `TesseraHarness` as the
headless driver's home; Phase 10–14 acceptances each gain "and its scenario corpus passes
under `tessera-dev run`".

## Phase A — Spikes and seams

**Goal**: de-risk the design with code against HEAD, then land the minimal seams.

### Step A.1 — Run the five spikes

- Done 2026-10-19; see "Spikes" for verdicts and findings.

### Step A.2 — Land the runtime seams

- Merge `devtools-seams-spike` (`30e4bbf`): `InMemoryTerminalDevice`
  `package init(…keepsInputOpen:)`, `deliverResize(to:)`, `closeInput()`, fan-out to
  `PlatformIO`'s two `sizeChanges` subscriptions; `ViewGraph`
  `package init(root:size:environment:now:)`; `withApplicationTerminal` forwarding
  `probeImageID`. Decide "since subscription" versus replay semantics for late subscribers
  before the harness depends on it (Spike 5 "Does not prove").
- `TerminalSession`: `package private(set) var lastDrawn: DrawnFrame?` (buffer, cursor,
  sequence) set after a successful flush in `draw`, a `package var size`, and an optional
  `outputTap` for byte-exact mirrors (Spike 4 "The seam, named").
- `RenderedCell`: a `width`/continuation field filled from Ghostty's wide flag, so SVG and
  text attribution stop guessing (Spike 3 Finding 1, Spike 2 Finding 8).
- Dead counters: wire `focusChanges` and `terminalRequirementChanges`; drop `handlerKinds`
  until Phase 10 populates it (`RuntimeNode.swift:20`, `GraphStatistics.swift:51-52`).
- Acceptance: the Seams spike tests pass on main; a live-runner test reads `lastDrawn`
  after `draw` and matches the bytes the device received; a wide grapheme's spacer is
  marked in `ScreenSnapshot`; no new `public` API outside the diagnostics projection.

### Step A.3 — Create `TesseraHarness` and migrate spikes mechanically

- Add the target, product, boundary allowlist rows, and `swiftSettings` entry; move spike
  code with goldens byte-identical before any addition (038 Lessons).
- Acceptance: `swift build` and `just quality architecture` green; `spikes/README.md` says
  "nothing new goes here".

## Phase B — Harness, scenarios, and the demo runner

**Goal**: plan 032 step 8.2 delivered through the harness; a demo's snapshot is a few
lines; an agent runs and reads a scenario without prose.

### Step B.1 — `Demo` protocol, registry, viewports, one update policy

- `Examples/Sources/DemoSupport`: `Demo`, `DemoRegistry` (one selection point, fails
  closed on duplicates), `Viewport`. Port `ApplicationDriver`'s update policy and
  `DemoHost.isQuitKey` whole-key matching (036 lesson 6).
- Acceptance: registry tests cover duplicates and lookup; live and headless share the one
  `Driver`.

### Step B.2 — Scenario grammar v0, runner, JSON report, exit codes

- Header-binding, fail-fast parser (`FILE:LINE: error:`); the runner continues after a
  failed expectation; `ScenarioReport` is the single source of human and JSON forms, with
  the screen reported once per scenario. The harness owns key normalisation (Spike 1
  Finding 7). Two render modes: `snapshot` (fresh VT per step, Spike 1's path) and
  `persistent` (the renderer's actual diff bytes fed into one Ghostty terminal across
  steps, compared against a full repaint), so differential-rendering bugs surface in
  scenarios; the persistent VT uses `VirtualTerminal.resize` (commit `85898ca`).
- Acceptance: two runs give identical bytes; a parse error under `--json` is a failure
  with verb `parse`; exit codes match the contract; a crafted diff-renderer fault fails in
  `persistent` mode; `Scenarios/README.md` carries the grammar, the events-not-bytes
  decision, and the "not yet expressible" table.

### Step B.3 — `tessera-dev` executable and `just dev` recipes

- `Examples/Sources/TesseraDev` is `HarnessCLI.main(registry: DemoRegistry.all)`:
  `demo list`, `demo run NAME`, `run FILE…`, `shot FILE… --out DIR`, `tree --app NAME`,
  `check --app NAME`; `justfiles/dev.just` mirrors them. `help COMMAND` prints real text
  (037 pitfalls).
- Acceptance: every command honours `--json`; `just dev scenarios` runs the corpus.

### Step B.4 — Projection, locators v0, invariants v0, text and grid shots

- Projection fields per Spike 2: short `type` and `layout` (never the reflected name in
  goldens), text attribution with `textOverlaps`, a pass marker, counters without
  durations, cursor under its own key and ignored by `diff` by default.
- Acceptance: step 8.3's demos (Text, stacks, frame/padding, ZStack, Flex) each have a
  scenario with `shot` at `desktop` and `mobile` and one `expect node … frame`; the
  `.scenario` strategy makes a demo's snapshot test three lines.

## Phase C — Pictures and catalog conformance

**Goal**: a human reviews a border or style change from an image; a wireframe is pinned by
the scenario that renders it.

- C.1 SVG light and dark from `ScreenSnapshot`: a `<style>` block of theme classes so both
  themes share one body, one `<text>` per row with `<tspan>` per style run, and
  box-drawing and block glyphs drawn as geometry rather than font glyphs (Spike 3). Needs
  the `RenderedCell` width seam from A.2. Determinism proved by SHA-256 across macOS and
  Lima Linux; a dense 80x24 worst case stays under 100 KB.
- C.2 `expect wireframe` and `conform`; the first pinned fences are Border, Box, and
  Divider from plan 032 step 9.3.
- Acceptance: `tessera-dev shot` emits four files per shot; `conform design/primitives`
  reports pinned and unpinned fences in JSON; heavy and rounded boxes rasterise correctly
  in the review PNG; Phase 9 demos read identically in SVG and `.txt`.

## Phase D — Focus tooling

**Goal**: "why did focus move" is answerable from a trace, and every focusable control is
proved reachable by keyboard.

- D.1 Spec amendment adds `isFocusable`, `isFocused`, and populated `handlerKinds` to the
  projection (Spec 7416–7418 already promises them in `dump()`); `focused`/`focusable`
  locators; `focus SEL` and `expect focused SEL` verbs.
- D.2 Rules `exactly-one-focus`, `focus-resolves`, `focused-visible`,
  `tab-cycle-terminates`; `tessera-dev coverage --app NAME`: from initial focus press Tab
  and Shift+Tab until the walk returns or stalls, arrows inside containers, shortest route
  per focusable with levels `landmark`, `tab_only`, `unreachable`, and a stop reason (037
  §7). Output is one sorted-key JSON per app, diffable per release.
- D.3 Per-step trace with focus before/after; `tessera-dev run --trace FILE`.
- Acceptance: the Phase 10 focus and KeyLegend demos ship with scenarios asserting
  `focused`; coverage reports no `unreachable` focusable in any demo; a deliberate
  invisible-focus fixture fails `focused-visible`.

## Phase E — Pointer tooling

- `mouse click|move|scroll|down|up`, `hit X,Y` query returning the deepest node path and
  whether it captured; traces record capture changes.
- Acceptance: plan 032 Phase 11's overlap, clipping, capture, and de-escalation tests are
  scenarios too.

## Phase F — Live inspection

- F.1 The endpoint described above in the live runner, migrated from Spike 4 (`0600`
  socket in a `0700` directory, peer-uid check, `sun_path` limit reported, stale socket
  replaced, bounded connections and request size); `tessera-dev attach PATH CMD…` and
  `--file SCENARIO` against a live app; `quit` unlinks before replying; `ctl` exit 3
  covers missing, stale, and silent sockets. POSIX-first.
- F.2 `TESSERA_TRACE` recording in the live runner; `replay` reruns headless and reports
  the first diverging screen row.
- Acceptance: a Phase 10 demo running in a real terminal answers `text`, `tree focused`,
  and `key Tab` from a second shell; the transport-parity test runs every scenario
  in-process and over the socket with identical reports.

## Phase G — Semantics and scroll checks

- G.1 Owner decision 4: `role` and `label` as value-typed, optional projection fields set
  by library controls through an internal hook (not public view API); `role=`/`label=`
  locators; v0 fallback derives role from `viewType`.
- G.2 Rules `scroll-offset-within-content`, `selection-visible`, `unique-collection-ids`;
  `expect node SEL visible` understands scroll clips.
- Acceptance: every Phase 13 control demo is driven by `role=`/`label=` locators, never
  coordinates; Phase 12 and 14 demos end with `check`.

## Phase H — Docs, skill, and CI gate

- H.1 `docs/DeveloperTools.md`, `.agents/skills/tessera-devtools/SKILL.md` (the loop:
  `demo run` → `run` → read JSON → `shot` → `tree` → `check` → fix the library, never the
  demo), an AGENTS.md pointer, the Spec's diagnostics paragraph amended per decisions 2
  and 4, and the doc drift 039 §11 names fixed.
- H.2 `just ci check` runs `just dev scenarios` and `conform` on `implemented` docs; plan
  032 step 17.1's intro app has a scenario per screen.
- Acceptance: a fresh agent given only the skill drives a demo, reads a failure, and
  produces a shot without reading source; CI fails on an unpinned `implemented` wireframe.

## Discoveries

Found by the spikes, outside this plan's scope:

- **`ForEach` inside a stack is not flattened at HEAD.** `VStack { ForEach(…) }` lays
  every keyed item at the same frame, so rows overlay and only the last paints. Seen
  independently by Spikes 1, 2, and 4 (`_visitLayoutChildren` flattens only a top-level
  `_ViewList`); `siblings-disjoint` caught it unprompted. Likely a bug; needs an issue
  before plan 032 step 8.3 uses `ForEach` in demos.
- **`Text` does not wrap at HEAD** and ignores its width proposal, so narrow fixtures clip
  and two invariants fire per truncated Text. Expected until plan 032 step 9.2.
- **`handlerKinds` is `[]` everywhere; `focusChanges` and `terminalRequirementChanges`
  never increment** (039 gap 7); A.2 wires or removes them.
- **`TerminalSession.events` is never drained by `nextEvent()` callers**, so its unbounded
  buffer grows for the session's lifetime (Spike 4 "API surprises").

## Spikes

Spikes 1–4 are standalone packages under `spikes/<Name>/` depending on Tessera by path
(`../..`), public API only, as Lattice did (038 Findings 7); Spike 5 edits root sources
and lives on branch `devtools-seams-spike` with only its README here. All five ran on
2026-10-19 (`939beb0`, `ce0a046`, `30e4bbf`). Each README holds the hypothesis, read list,
pass/fail criteria, and "proves / does not prove"; this section keeps the verdict and the
findings that changed the plan. Nothing in `spikes/` is imported by the root package;
Phase A.3 migrates by copy, and nothing new goes into `spikes/` after that.

### Spike 1 — HeadlessRunner

- Hypothesis: a `.scn` file drives a HEAD app through `ViewGraph` +
  `VirtualTerminal.snapshot` with the JSON/exit contract, byte-identically, and derives
  `mobile` natural height from `GraphDiagnostics`.
- Findings: **pass** (`939beb0`; 18 tests; corpus byte-identical over two runs; exit 0/1/2
  observed; 0.117 s). Public API sufficed for text-only scenarios. Natural height is
  unreadable for height-greedy demos (README "Mobile natural height"; owner decision 1).
  The harness owns key normalisation (`Ctrl+C` → `.character("c")` + `.control`;
  `Shift+Tab` vs backtab is open; Finding 7). Failure payload
  `{line, statement, verb, message, expected, actual, screen[]}` worked; report the screen
  once per scenario (9). `VirtualTerminal.snapshot` re-renders a full frame per step, so
  differential rendering is never exercised; B.2 adds a persistent-VT mode. Grammar
  details to confirm are in Finding 8.

### Spike 2 — GraphQuery

- Hypothesis: locators, a field-level diff, and v0 invariants run over `GraphDiagnostics`
  - `ScreenSnapshot` with no `RuntimeNode` access.
- Findings: **pass** (`939beb0`; 30 tests). Paths are stable across `update()` on an
  unchanged tree; text attribution from the screen works (last leaf in pre-order owning a
  cell; obscured text does not match; `textOverlaps` plus an `ambiguous` flag; README "How
  text-to-node attribution works"). Reflected `typeName` is not golden-safe (addresses for
  private types, `Pack{…}`), so the projection carries short `type` and `layout` (Findings
  3–4); `id=X` matches a user id component because `NodeIdentity` strings are brittle;
  `no-dirty-after-pass` needs a pass marker; `effectiveTerminalRequirements` is always nil
  from `ViewGraph.diagnostics` (9); `screen.cursor` is excluded from diffs by default (7);
  until Text wraps, two invariants fire per truncated Text (6); durations are excluded
  from the projection (10).

### Spike 3 — SvgShot

- Hypothesis: `ScreenSnapshot` → SVG, byte-stable, under 100 KB at 80x24, legible.
- Findings: **partial** (`939beb0`; 10 tests; 17,500 bytes per theme, SHA-256 stable;
  light/dark differ only in palette; per-glyph `x` aligns without font metrics). Size
  scales with style churn (250 KB dense worst case), so C.1 uses a `<style>` block of
  theme classes and one `<text>` per row with `<tspan>` per run (Finding 3). Rasterisers
  substitute fonts for heavy, rounded, and mixed box glyphs (`out/demo-dark.png`), so C.1
  draws box-drawing and block elements as geometry. `RenderedCell` has no width flag and
  Ghostty's spacer reads as `" "` (1); `RenderedColor` lives in
  `TesseraTerminalSnapshotSupport` (4). Linux cross-check not run.

### Spike 4 — LiveSocket

- Hypothesis: a dev-owned loop serves `text`/`tree`/`key`/`quit` over a Unix socket with
  injected keys on the normal `step` path, and names the seam that removes the mirror.
- Findings: **pass** (`939beb0`; 35 tests; real-pty transcript in README "Evidence").
  Input merge needs no seam: a pump forwards `nextEvent()` into the control stream, and a
  typed Tab and an injected Tab reached the same `step`. The render mirror is harmful: a
  second `graph.render` clears dirty flags so the loop can skip the real draw, loses the
  cursor, and ignores the session's color/underline/hyperlink policy ("The seam, named"
  2). Required seam: `package private(set) var lastDrawn: DrawnFrame?` (buffer, cursor,
  sequence) in `TerminalSession.draw`, ~8 lines, plus a `package` size accessor (3) and an
  optional `outputTap`. Socket details for Phase F: `sun_path` 103 usable bytes (default
  under `/tmp`), `SOMAXCONN` backlog, stale-socket replacement, `0600` in `0700`,
  `getpeereid`/`SO_PEERCRED`, one request per connection, `quit` unlinks before replying.
  `Driver` state lives in a non-Sendable class taking `isolated TerminalSession`.

### Spike 5 — Seams (branch `devtools-seams-spike`)

- Hypothesis: live resize, an injected clock, and an injectable `probeImageID` are each
  under 40 lines, `package`-visible, with every snapshot byte-identical.
- Findings: **pass**, over budget (`30e4bbf`; full `swift test` and
  `just quality architecture` green). `PlatformIO` and `TerminalDevice` needed no change,
  but a `sizeChanges` stream alone delivers nothing: `PlatformIO.events` ends with the
  byte stream, so the device holds input open (`keepsInputOpen`, `closeInput`,
  `deliverResize`) and fans out to `PlatformIO`'s two subscriptions; ~80 lines, replaying
  sizes to late subscribers (Findings 1–3). Clock: `package init(…now:)`, +19/−10;
  `GraphDiagnostics` equality includes durations, so only a fixed clock makes two graphs
  comparable (5). Probe ID: the init seam existed; `withApplicationTerminal` now forwards
  it (+7/−1). Finding 4 is load-bearing: a public-API runner cannot drive resize, so the
  harness lives in the root package (owner decision 3).

## Owner decisions

1. **`mobile` viewport: 40x16 or 40 x natural.** (a) 40x16 everywhere (plan 032 step 8.2,
   widget template); (b) 40 columns at natural height, 40x16 only for screen-filling
   compositions (tokens.md:21, design/README.md:64, owner decision 2026-10-10). Spike 1
   evidence: natural height is readable for leaf-and-stack demos (`stack` → 40x6) but any
   demo containing a height-greedy view (ScrollView, SplitView) fills whatever is
   proposed, and public API cannot propose a nil height, so the driver cannot measure it.
   Recommendation: (b), with no default: each demo declares `fixtures` explicitly, and
   `size mobile` on a greedy demo is an error naming `mobileScreen`. Amend plan 032 step
   8.2 and `design/templates/widget.md:38`.
2. **Live inspection versus Spec 7437/7551.** (a) keep the prohibition, headless only; (b)
   amend the Spec so `TesseraCore` still serialises nothing while `TesseraHarness` may
   expose an opt-in loopback endpoint in dev runners; (c) a TCP port like Textual.
   Recommendation: (b), Unix socket, `0600` under a `0700` directory, peer-uid checked,
   only under `TESSERA_DEBUG_SOCKET`, POSIX-first; Spike 4 ran it end to end in a real pty
   with public API plus an 8-line `TesseraTerminal` seam. [INFERENCE] If rejected, agents
   fall back to print debugging in demos, which the Spec also forbids.
3. **Where devtools live.** `DevTools/`, `Examples/`, or a root target. Recommendation:
   harness library in the root package; Spike 5 finding 4 settles it: a runner outside the
   package cannot deliver a resize or inject the probe ID without promoting `package`
   seams to public. Demos, registry, and `tessera-dev` in `Examples/`; `DevTools/` stays
   for environment wrappers.
4. **Role and label in the frozen diagnostics schema.** (a) derive role from `viewType`
   and label from rendered text (no schema change; brittle for custom controls); (b) add
   optional `role`/`label` fields set by library controls through an internal hook (Spec
   amendment; no public view API). Recommendation: (a) in Phase B, (b) in Phase G, while
   deciding whether an app-facing label modifier is 1.0 (036 lesson 5 is the warning).
5. **omp2 capture program.** Uncommitted; step 7.4 deletes it (040). Recommendation: tag
   `archive/omp2-gallery` before 7.4 and port nothing; its `#!` fixture directives and
   review site are prior art only; the probe-theme trick is unnecessary.
6. **Scenario input: events or bytes.** Typed `InputEvent` verbs with a `bytes` escape
   hatch (one grammar, parser coverage on demand).
7. **Animation clock timing.** Spec 8358 says not Phase 4; plan 032 step 16.1 says 1.0.
   The clock seam landed in Spike 5 either way; only motion `wait` semantics wait on this.

## Acceptance

- A.2 seams landed with no public API growth outside the diagnostics projection.
- `TesseraHarness` passes the boundary gates and is plan 032 step 8.2's headless driver;
  `tessera-dev` runs every demo live and headless from one registry; every command honours
  the JSON and exit-code contract; two runs give identical bytes.
- By plan 032 Phase 10: focus is addressable, traced, invariant-checked, and
  coverage-walked; by Phase 13: every control demo is driven by semantic locators; by
  Phase 17: the corpus and `conform` run in CI and the skill lets a fresh agent complete
  the loop unaided. The Spec's diagnostics paragraph and plan 032 carry the amendments.

## References

- Investigations 036–041; `docs/Spec.md:7382-7441, 7545-7551, 8339-8346`;
  `design/README.md:60-67, 115-143, 240-245, 272-282, 318-319`; `design/tokens.md:14-26`;
  plan 032 `:501-543`; Lattice `docs/design/devtools.md` (Principles, `lattice dev`
  family, Decisions 2–3); Tern `tern help dev` as recorded in 037.
