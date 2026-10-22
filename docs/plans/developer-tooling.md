---
type: plan
stage: proposed
created: 2026-10-19
order: 33
description: A headless harness, a scenario language, semantic queries over the view graph, deterministic text/grid/SVG shots, invariant and cost checks, "why" traces, and a catalog review view, built on plan 032's Phase 8 demo runner and landing one capability per Phase 4 phase so agents can build, debug, and evaluate Tessera apps unattended.
---

# Developer tooling for agents and humans

## Progress

- [ ] **Phase A — Spikes and seams (before plan 032 Phase 8)**
  - [x] A.1 Run the five spikes; record findings below (`939beb0`, `ce0a046`, `30e4bbf`)
  - [ ] A.2 Land the device, probe, draw-tap, and events-buffer seams
  - [ ] A.3 Create `TesseraHarness` and migrate spike code mechanically
- [ ] **Phase B — Harness, scenarios, and the demo runner (= plan 032 step 8.2)**
  - [ ] B.1 `HeadlessApp`/`Demo` contract, registry, viewports, one update policy
  - [ ] B.2 Scenario grammar v0, runner, report, exit codes, golden policy
  - [ ] B.3 `tessera-dev`, `just dev`, and CI jobs for Examples and the corpus
  - [ ] B.4 Projection, locators v0, invariants v0, cost, trace v0, text and grid shots
- [ ] **Phase C — Pictures, roles, and catalog review (with plan 032 Phase 9)**
  - [ ] C.1 SVG shots, role probe palette, `RenderedCell` width
  - [ ] C.2 `expect wireframe … at SEL`, `conform`, and the gallery review view
- [ ] **Phase D — Focus tooling (with plan 032 Phase 10)**
  - [ ] D.1 Focus and handler fields in the projection; focus verbs and locators
  - [ ] D.2 Focus invariants and the keyboard coverage walk
  - [ ] D.3 Trace "why" fields: dispatch path and focus cause
- [ ] **Phase E — Pointer tooling (with plan 032 Phase 11)**
  - [ ] E.1 `mouse` verbs and the `hit` query
- [ ] **Phase F — Live inspection (optional; off the critical path)**
  - [ ] F.1 Debug endpoint in the live runner; `tessera-dev attach`
- [ ] **Phase G — Semantics and scroll checks (G.1 before plan 032 step 13.1)**
  - [ ] G.1 Role and label in the projection; `role=`/`label=` locators
  - [ ] G.2 Scroll and collection invariants
- [ ] **Phase H — Docs, skill, and conformance gate (closes with plan 032 Phase 17)**
  - [ ] H.1 `docs/DeveloperTools.md`, the `tessera-devtools` skill, AGENTS.md loop
  - [ ] H.2 `conform` gate for `implemented` docs

## Overview

Tessera renders a view tree headlessly and asserts on cells, styles, cursor, and the diagnostics tree (investigation 039 §3–4). It cannot drive an app from a script, address an element by meaning, picture a screen, check invariants, explain a redraw or a focus move, or look inside a running app. Plan 032 Phases 8–17 are about to build focus, pointer input, ScrollView, controls, and collections, where the abandoned attempts went wrong unnoticed (036 lessons 1, 3, 4, 7). This plan gives agents and humans the loop that caught such defects for Tern and Ternbook (037) and that Lattice designed (038). Phase B here _is_ plan 032 step 8.2; later phases ride along with the component phases they instrument.

## Goals and principles

1. **One grammar, two hosts.** A scenario is a text file, one statement per line, shell quoting, `#` comments (037 §3; 038); it runs in-process against `VirtualTerminal` and later against a live session, and is a test, a bug report, and a catalog fixture. Verbs the runner cannot yet honour are listed, never faked (038 Findings 1).
2. **The runner evaluates expectations from a projection the runtime returns** (`GraphDiagnostics` plus `ScreenSnapshot`); the runtime holds no assertion state.
3. **Text first, pixels as a review aid.** The Ghostty cell grid is the golden; SVG and PNG never are (038 Decision 3; 041 Implications 2, 5).
4. **Time is injected; `wait` advances a clock, never sleeps** (Spec 8417–8419, 8440–8441). Until a schedulable clock exists, `wait` and `settle` are not expressible.
5. **Dull agent contract.** One JSON object per command on stdout when stdout is not a terminal (`--json`/`--pretty` force either); exit 0 pass, 1 an expectation or check failed, 2 usage or parse error, 3 harness error. Errors name the accepted vocabulary; a selector that matches nothing is an error, not an empty list (037 §5; 038 Findings 4).
6. **No test affordances in product API** (036 lesson 5; Spec 7422–7441); `TesseraCore` gains only value-typed diagnostics fields, each by Spec amendment. Text goldens are the only committed artefacts; drift fails unless `--record` is passed (036 lesson 8).
7. **"Why" is answered by the trace, not by prints** (Spec 7419–7420). Demos find library bugs; the harness never compensates (036 lesson 7).

## Tool surface

Pieces, their users, and the phase each lands in: `TesseraHarness` (driver, scenario runner, projection, locators, checks, shots; both; B); `tessera-dev` CLI (`demo list|run`, `run`, `shot`, `tree`, `check`, `coverage`, `conform`, `replay`, `attach`; agents; B–F); the `.scn` language with a `term` capability header (both; B–G); locators (agents; B, D, G); text and grid goldens plus SVG and tree artefacts (both; B, C); the per-step trace with "why" fields and cost (both; B, D); invariants and `expect cost` (both; B, D, G); the keyboard coverage walk (agents; D); catalog conformance and the gallery review view (both; C); the optional live endpoint (agents; F).

### `TesseraHarness` (root package test-support target)

A library beside `TesseraTestSupport`, in the root package because it needs `package` seams (`Renderer.render`, `InMemoryTerminalDevice.deliverResize`, `TerminalSession.lastDrawn`, `withApplicationTerminal(configuration:io:environment:_:)`) that a path-dependent package cannot see (Spike 5 Finding 4). It is test support with no 1.0 stability promise and is not offered to app authors as a remote dependency: it needs `CGhosttyVT`, whose `unsafeFlags` make it unusable from another package (`Package.swift:590-591`, [INFERENCE]). It never imports SnapshotTesting; the `.scenario` strategy lives in `TesseraTestSupport` and wraps it. Platform divergence (sockets, `SO_NOSIGPIPE`/`MSG_NOSIGNAL`, `getpeereid`/`SO_PEERCRED`) lives in one shim per OS through a `sources:` split (AGENTS.md:15-17).

### App contract and driver (shared with plan 032 step 8.2)

```swift
public protocol HeadlessApp: AnyObject {       // TesseraHarness
  associatedtype Root: View
  init()
  var root: Root { get }                         // reads the model; hands out Bindings
  func apply(_ event: InputEvent, disposition: EventDisposition)
}
public protocol Demo: HeadlessApp {              // Examples/DemoSupport
  static var name: String { get }                // registry key, kebab-case
  static var minimum: TerminalSize { get }       // the catalog `min`
  static var fixtures: [Viewport] { get }        // declared per demo; no default
}
public enum Viewport { case desktop /* 80x24 */, mobile /* 40 x natural */,
                       mobileScreen /* 40x16 */, custom(TerminalSize) }
```

`AnyObject` because both spikes needed a reference model and because controlled controls (plan 032 Phases 13–14) write back through `Binding`s a value `root` cannot hand out (Spike 1 README "How key/type are handled"). `Driver.step(event)` runs the canonical loop once: `resize` → `graph.dispatch` → `app.apply(event, disposition)` (the app acts only on `.ignored` events; the disposition is traced) → `graph.update()` → `TerminalSession.draw` on the in-memory device → `outputTap` bytes into one persistent Ghostty `VirtualTerminal`. Headless therefore takes the live path, including the session's colour, underline, and hyperlink policy (Spike 4); the live runner is the same `Driver` over the real device, its state in a non-Sendable class whose methods take `isolated TerminalSession`.

### Scenario language (sketch; the grammar lives in `Examples/Scenarios/README.md`)

```text
app NAME   size 80x24|mobile|mobileScreen   term colors=none|16|256|true glyphs=ascii
   keyboard=legacy|kitty theme=light|dark                                   # header
resize 40x16   key Tab   type "hi"   paste "…"   bytes "\x1b[A"   focus SEL (D)
mouse click|move|scroll R,C (E)     shot NAME [SEL]     tree [SEL]     dump [SEL]
expect text ROW "…"   expect screen <<EOF…EOF   expect cell R,C bold fg=ROLE bg=ROLE (C)
expect node SEL frame X,Y WxH|visible|clipped|count N   expect focused SEL (D)
expect wireframe PATH N [at SEL] (C)   expect cost bodies<=N measures<=N bytes<=N
check [rule…]
```

`SEL` is `key=value` pairs: `type=Text` (short name), `layout=_FrameLayout`, `id=X` (a user `.id`/`ForEach` key, or a full path), `text="Submit"` (screen text attributed to the topmost leaf; obscured text does not match), `nth=2`; D adds `focused`, `focusable`; G adds `role=`, `label=`. Locators re-resolve on every statement. Key names follow Playwright, normalised by the harness (`Ctrl+C` is `c` + control). The `term` header maps onto the `TerminalSession` package init (`colorCapability`, `hasNoColorEnvironment`, `keyboardProtocol`; `TerminalSession.swift:215-236`) so ASCII fallbacks, `NO_COLOR`, and backtab-versus-`Shift+Tab` are scenario facts. A failing `expect` is recorded with the screen (once per scenario) and the run continues. The README keeps a "not yet expressible" table from day one: `wait`, `settle`, and motion verbs until plan 032 step 16.1 lands a clock the harness can advance; `mouse` until E; `focus` until D.

### Projection, locators, diffs, invariants

`Projection` is sorted-key JSON of `GraphDiagnostics` (short `type` and `layout`, never the reflected name; counters and `invalidationReasons`, no durations; a pass marker) plus the screen (`rows`, style runs, `cursor` under its own key). `diff(a, b)` lists nodes added, removed, and changed by field, and screen rows changed; it ignores the cursor unless asked. Invariants are a pure `check(projection, screen, rules:) -> [Violation{rule, node, detail}]` with stable kebab-case ids:

- v0 (B): `no-dirty-after-pass`, `frame-inside-clip` (warning), `measured-within-proposal`, `siblings-disjoint` (`ZStack` and overlays exempt by type), `requirements-aggregate`.
- D: `exactly-one-focus`, `focus-resolves`, `focused-visible` (frame ∩ clip non-empty, investigation 034), `focus-indicated` (the focused node's cells differ from its unfocused cells, including under `colors=none`), `tab-cycle-terminates`, `legend-keys-handled` (every key KeyLegend advertises is handled by the focused chain).
- G: `scroll-offset-within-content`, `selection-visible`, `unique-collection-ids`.

`NodeState` single ownership is not checkable from the projection; it stays a review rule backed by an `ast_grep` lint in `just quality` (docs/design.md:240).

### Shots and goldens

`shot NAME [SEL]` records the screen, or the node's frame region, as `NAME.txt` and `NAME.grid.txt` (`.terminalText(trim: .trailing)`, `.terminalStyledGrid`), the only committed artefacts, beside the scenario. Drift from a committed golden fails the statement; `run --record` rewrites goldens and prints what changed. `NAME.tree.json`, the SVGs, and the optional macOS PNG go to `.build/tessera-dev/`, never committed. SVG (C.1): a `<style>` block of theme classes, one `<text>` per row with `<tspan>` per style run, box-drawing and block glyphs drawn as geometry (Spike 3). Style by role: the `theme=probe` palette gives every semantic role a unique colour that the projection maps back, so `expect cell R,C fg=focus` speaks in roles, not RGB (040 Implications; omp2's technique).

### Trace and cost

`Driver` writes one JSONL record per step: `seq`, `event`, `dispatch{disposition, handledBy, path}` (D), `focus{from, to, cause}` (D), `reasons` (the pass's `invalidationReasons`), changed node identities, changed rows, and `cost{bodies, measures, placements, renderedNodes, bytes}` where `bytes` is the `outputTap` length. Cost is deterministic and assertable (`expect cost`); wall-clock durations appear only under `run --timing` and are never goldens. The scenario is the replay file; `run --repeat N` reruns and reports any divergence. Live sessions record their events to `TESSERA_TRACE=<file>` for `tessera-dev replay FILE --app NAME` (Phase B).

### Catalog conformance and the gallery review view (Phase C)

`expect wireframe PATH N [at SEL]` compares the screen, or a node's frame region, with the N-th `wireframe WxH` fence in a catalog doc; the grid is pristine by rule (docs/design.md:136-137), so the compare is cell-for-cell with a per-cell diff on failure. `tessera-dev conform [DOC…]` lists every fence in `ready`/`implemented` docs with the scenario that pins it, or `unpinned`; from Phase H the gate fails for `implemented` docs with unpinned fences (docs/design.md:314-315). The kept review pages (plan 032 step 7.4 amendment) become the gallery: per component, the wireframe, the current render (SVG from the working tree), and the previous render (SVG rendered from the committed `.grid.txt`), so a human reviews a regression as three pictures without any committed image.

### Live inspection (Phase F, owner decision 2)

Optional. Only when `TESSERA_DEBUG_SOCKET=<path>` is set, the live runner opens a Unix-domain NDJSON endpoint (`0600` in a `0700` directory, peer-uid checked, one request per connection): `text`, `grid`, `tree [SEL]`, `stats`, `shot`, `key`, `type`, `mouse`, `resize`, `quit`. A pump forwards `nextEvent()` into the control stream, so injected input takes the normal `step` path (Spike 4); queries run between steps and read `lastDrawn`. Windows exits 3 as unsupported. Nothing in Phases B–E depends on it; the transport-free alternative (decision 2d) is the trace plus `lastDrawn` dumps, with input through the pty or tmux.

## Sequencing against plan 032

Phase headings above name the plan 032 phase each rides with; A precedes Phase 8, B is step 8.2, G.1 precedes step 13.1, F waits on nothing. Amendments this plan asks of plan 032: step 8.2 reads "`mobile` is 40 columns at natural height, declared per demo; `mobileScreen` is 40x16" and names `TesseraHarness` as the headless driver's home; step 10.1 wires `focusChanges`, `handlerKinds`, and `terminalRequirementChanges`; step 16.1's environment clock is a `Clock` the harness can advance, so `wait`/`settle` become expressible; Phase 10–14 acceptances each gain "and its scenario corpus passes under `tessera-dev run`".

## Phase A — Spikes and seams

**Goal**: land the smallest seams the spikes proved necessary, nothing more.

### Step A.1 — Run the five spikes

- Done 2026-10-19; see "Spikes".

### Step A.2 — Land the device, probe, draw-tap, and events-buffer seams

- From the seams spike (`spikes/Seams/30e4bbf.patch`, commit `30e4bbf`): `InMemoryTerminalDevice` `package init(…keepsInputOpen:)`, `deliverResize(to:)`, `closeInput()`, fan-out to `PlatformIO`'s two `sizeChanges` subscriptions with since-subscription semantics (drop the `deliveredSizes` replay; live platforms deliver only after subscription); `withApplicationTerminal` forwarding `probeImageID` and `probeSleep` (so the seam test stops waiting on a wall-clock timeout); the `ViewGraph` clock seam as is.
- `TerminalSession`: `package private(set) var lastDrawn: DrawnFrame?` (buffer, cursor, sequence) set after a successful flush, `package var size`, `package var outputTap` teed before `io.write` (Spike 4); bound or drain the `events` buffer a `nextEvent()` consumer never reads.
- Not here: `handlerKinds` stays (frozen, Spec 7430); counters wire in 032 step 10.1; `RenderedCell` width lands in C.1.
- Acceptance: a mid-session `.resize` through `InMemoryTerminalSession` redraws at the new size; `lastDrawn` and `outputTap` match the device's bytes; no new `public` API.

### Step A.3 — Create `TesseraHarness` and migrate spikes mechanically

- Add the target, boundary allowlist rows, and `swiftSettings` entry; move spike code with goldens byte-identical before any addition (038 Lessons); platform code into per-OS `sources:` shims.
- Acceptance: `swift build` and `just quality architecture` green; `spikes/README.md` says "nothing new goes here".

## Phase B — Harness, scenarios, and the demo runner

**Goal**: plan 032 step 8.2 delivered through the harness; a demo's snapshot test is a few lines; an agent runs and reads a scenario without prose; CI gates all of it.

### Step B.1 — `HeadlessApp`/`Demo` contract, registry, viewports, one update policy

- `Examples/Sources/DemoSupport`: `Demo`, `DemoRegistry` (one selection point, fails closed on duplicates), `Viewport`. Port `ApplicationDriver`'s update policy and `DemoHost.isQuitKey` whole-key matching (036 lesson 6). Natural height: a package-level nil-height proposal on `ViewGraph` for the probe, plus two-height detection (measure at two heights; if the results differ the demo is height-greedy and `size mobile` is an error naming `mobileScreen`).
- Acceptance: registry tests cover duplicates and lookup; live and headless share the one `Driver` and the `TerminalSession.draw` path; a greedy demo fails `size mobile`.

### Step B.2 — Scenario grammar v0, runner, report, exit codes, golden policy

- Deliverable `Examples/Scenarios/README.md`: grammar, `term` header, locator rules, key names, the events-not-bytes decision, the golden policy, the "not yet expressible" table. Header-binding, fail-fast parser (`FILE:LINE: error:`); the runner continues after a failed expectation; one `ScenarioReport` yields the human and JSON forms; `--record`, `--repeat N`, `--timing`.
- Acceptance: two runs give identical bytes; a parse error under `--json` is a failure with verb `parse`; exit codes match the contract; a drifted golden fails without `--record`; a crafted diff-renderer fault fails in the persistent VT.

### Step B.3 — `tessera-dev`, `just dev`, and CI

- `Examples/Sources/TesseraDev` is `HarnessCLI.main(registry: DemoRegistry.all)` (`demo list|run`, `run`, `shot`, `tree`, `check`, `replay`); `justfiles/dev.just` mirrors it; `help COMMAND` prints real text (037 pitfalls).
- CI: `ci.yml` gains `swift test --package-path Examples` and `tessera-dev run` over the corpus on macOS and Linux from this step (today only the root package runs, `ci.yml:256,270`); Windows per owner decision 8.
- Acceptance: every command honours `--json`; a deliberately broken scenario fails CI.

### Step B.4 — Projection, locators v0, invariants v0, cost, trace v0, text and grid shots

- Projection fields per Spike 2; trace v0 with `reasons` and `cost`; `expect cost`.
- Acceptance: step 8.3's demos (Text, stacks, frame/padding, ZStack, Flex) each have a scenario with `shot` at `desktop` and `mobile` and one `expect node … frame`; the `.scenario` strategy makes a demo's snapshot test three lines; a demo's trace names the invalidation reason for each redraw.

## Phase C — Pictures, roles, and catalog review

- C.1 `RenderedCell.width`/continuation filled from Ghostty's wide flag (Spike 3 Finding 1); SVG as designed; the `theme=probe` role palette and `fg=ROLE`/`bg=ROLE` cell assertions. Determinism proved by SHA-256 across macOS and Lima Linux; a dense 80x24 worst case stays under 100 KB.
- C.2 `expect wireframe … at SEL`, `shot NAME SEL`, `conform`, and the gallery's Current and Previous slots (main `c8ab409`: `scripts/gallery-serve.py`, `DevTools/gallery/`, reading fences straight from the catalog). The harness emits a role-styled grid in the catalog's dialect (`── chars ──`, `── style ──`, `── legend ──` with token role specs, recovered through `theme=probe`), so `expect wireframe` compares characters and roles, and the gallery draws Current and Previous with its own renderer on any of its themes; SVG stays a review artefact. Fence ids (`wireframe WxH id=NAME`) and the styled-grid lint landed on main in `39d793c`; pinning adds an `id=` to each pinned fence, and the gallery's slots accept `.grid.txt` as well as `.svg`. First pinned fences: Border and Box (plan 032 step 9.3).
- Acceptance: `conform docs/design/primitives` reports pinned and unpinned fences in JSON; heavy and mixed boxes rasterise correctly in the review PNG; a Phase 9 focus-border demo asserts `fg=focus` under `theme=probe` and reads identically in SVG and `.txt`.

## Phase D — Focus tooling

- D.1 Spec amendment adds `isFocusable` and `isFocused` to the projection (Spec 7416–7418 already promises them in `dump()`); `handlerKinds` populated by 032 step 10.1; `focused`/`focusable` locators; `focus SEL`, `expect focused SEL`.
- D.2 Rules `exactly-one-focus`, `focus-resolves`, `focused-visible`, `focus-indicated`, `tab-cycle-terminates`, `legend-keys-handled`; `tessera-dev coverage --app NAME`: from initial focus press Tab and Shift+Tab until the walk returns or stalls, arrows inside containers, shortest route per focusable with levels `shortcut` (a KeyLegend binding), `tab`, `unreachable`, and a stop reason (037 §7); one sorted-key JSON per app.
- D.3 Trace `dispatch{disposition, handledBy, path}` and `focus{from, to, cause}`.
- Acceptance: the Phase 10 focus and KeyLegend demos ship with scenarios asserting `focused`; coverage reports no `unreachable` focusable in any demo; a swallowed key's trace names the node that consumed it; an invisible-focus fixture fails `focused-visible`; a `colors=none` run fails `focus-indicated` if focus has no glyph.

## Phase E — Pointer tooling

- `mouse click|move|scroll|down|up R,C`, `hit R,C` returning the deepest node path and whether it captured; traces record capture changes.
- Acceptance: plan 032 Phase 11's overlap, clipping, capture, and de-escalation tests are scenarios too.

## Phase F — Live inspection (optional)

- F.1 The endpoint described above, migrated from Spike 4 (`sun_path` limit reported, stale socket replaced, bounded connections and request size); `tessera-dev attach PATH CMD…` and `--file SCENARIO`; `quit` unlinks before replying; `ctl` exit 3 covers missing, stale, silent, and unsupported.
- Acceptance: a Phase 10 demo in a real terminal answers `text`, `tree focused`, and `key Tab` from a second shell; the transport-parity test runs every scenario in-process and over the socket with identical reports.

## Phase G — Semantics and scroll checks

- G.1 (before plan 032 step 13.1) Owner decision 4: `role` and `label` as value-typed, optional projection fields set by library controls through an internal hook (no public view API); `role=`/`label=` locators; the v0 fallback derives role from `type`.
- G.2 Rules `scroll-offset-within-content`, `selection-visible`, `unique-collection-ids`; `expect node SEL visible` understands scroll clips.
- Acceptance: every Phase 13 control demo is driven by `role=`/`label=` locators, never coordinates; Phase 12 and 14 demos end with `check`.

## Phase H — Docs, skill, and conformance gate

- H.1 `docs/DeveloperTools.md`, `.agents/skills/tessera-devtools/SKILL.md` (the loop: `demo run` → `run` → read JSON → `shot` → `tree` → trace → `check` → fix the library, never the demo; never `--record` to make a failing run pass), an AGENTS.md pointer, the Spec's diagnostics paragraph amended per decisions 2 and 4, the doc drift 039 §11 names fixed.
- H.2 `just ci check` and CI run `conform` on `implemented` docs; plan 032 step 17.1's intro app has a scenario per screen.
- Acceptance: a fresh agent given only the skill drives a demo, reads a failure, and produces a shot without reading source; CI fails on an unpinned `implemented` wireframe.

## Discoveries

Found by the spikes, outside this plan's scope:

- **`ForEach` inside a stack is not flattened at HEAD.** `VStack { ForEach(…) }` lays every keyed item at the same frame, so only the last paints. Seen independently by Spikes 1, 2, and 4; `siblings-disjoint` caught it unprompted. Likely a bug; needs an issue before plan 032 step 8.3 uses `ForEach` in demos.
- **`Text` does not wrap at HEAD** and ignores its width proposal (expected until plan 032 step 9.2); **`handlerKinds` and the focus and requirement counters are dead** (039 gap 7; plan 032 step 10.1 wires them).

## Spikes

Standalone packages under `spikes/<Name>/` (path dependency `../..`, public API only, as Lattice did, 038 Findings 7); Spike 5 edits root sources and is saved as `spikes/Seams/30e4bbf.patch`. All ran 2026-10-19 (`939beb0`, `ce0a046`, `30e4bbf`); each README holds the hypothesis, criteria, and "proves / does not prove". Nothing new goes into `spikes/` after A.3.

| Spike | Verdict | Findings that changed the plan |
| --- | --- | --- |
| [HeadlessRunner](../../spikes/HeadlessRunner/README.md) | pass | Natural height unreadable for height-greedy demos (decision 1); the app must be a reference type whose `apply` sees dispositions (README :49-61); harness owns key normalisation (Finding 7); report the screen once per scenario (9); `VirtualTerminal.snapshot` never exercises differential rendering (B.2 persistent VT); `NodeIdentity` strings brittle for `id=` (4). |
| [GraphQuery](../../spikes/GraphQuery/README.md) | pass | Reflected `typeName` not golden-safe; short `type` and `layout` (Findings 3–4); text attribution from the screen with `textOverlaps` works; `no-dirty-after-pass` needs a pass marker; `effectiveTerminalRequirements` always nil (9); cursor excluded from diffs (7); two invariants per truncated Text until wrap (6); durations excluded (10). |
| [SvgShot](../../spikes/SvgShot/README.md) | partial | Per-glyph `x` aligns without font metrics; size scales with style churn (250 KB dense worst case → `<style>` classes and `<tspan>`s, Finding 3); heavy and mixed box glyphs fall back to other fonts → geometry; `RenderedCell` lacks width and Ghostty's spacer reads as `" "` (1). |
| [LiveSocket](../../spikes/LiveSocket/README.md) | pass | Input merge needs no seam (`nextEvent()` pump); a render mirror is harmful (clears dirty flags, loses cursor, ignores session colour policy) → `lastDrawn` + `outputTap` seams, also used headless; `package` size accessor; socket hardening list; `Driver` state in a non-Sendable class taking `isolated TerminalSession`; `#if canImport(Darwin)` must become per-OS shims. |
| [Seams](../../spikes/Seams/README.md) | pass, over budget | `sizeChanges` alone delivers nothing: input must stay open and fan out to two subscribers (~80 lines, Findings 1–3; replay semantics to be replaced); clock seam feeds durations only; probe ID only needed forwarding; a public-API runner cannot drive resize (4) → harness in the root package (decision 3). |

## Owner decisions

1. **`mobile` viewport.** (a) 40x16 everywhere (plan 032 step 8.2, widget template); (b) 40 columns at natural height, 40x16 for screen-filling compositions (tokens.md:21, docs/design.md:64). Spike 1: natural height reads cleanly for leaf-and-stack demos; height-greedy views fill any proposal, and only a package-level option can propose a nil height. Recommendation: (b), with the package nil-height probe and two-height detection in B.1, `fixtures` declared per demo, and an error naming `mobileScreen`.
2. **Live inspection versus Spec 7437–7440, 7550–7551.** (a) keep the prohibition; (b) amend the Spec so `TesseraCore` still serialises nothing while a dev runner may expose an opt-in loopback endpoint that also injects input (the amendment must cover input, not only serialisation); (c) a TCP port like Textual; (d) no transport: trace and `lastDrawn` dumps to a directory, input through the pty or tmux, works on Windows. Precedent: Tern ships (b) and (c) together. `tern --control EP` and `tern serve` answer `ctl` on a Unix socket or a 127.0.0.1 TCP port with input (`key`, `click`), `state`, `tree`, `perf`, `trace`, and `quit`; no access control is documented (037 §1, §8; `tern help dev`). The Spec's rule targets the library's diagnostics snapshot (no controlled values or raw input leaving the process); a same-user socket under a `0700` directory adds no authority the user's shell lacks. Recommendation: (b), worded so the prohibition stays on `TesseraCore` and the endpoint stays opt-in, local, and dev-only; (d) arrives with Phase B regardless, and Phase F stays off plan 032's critical path.
3. **Where devtools live.** Root-package test-support target for the harness (Spike 5 Finding 4); demos, registry, and `tessera-dev` in `Examples/`; `DevTools/` stays for environment wrappers.
4. **Role and label in the frozen diagnostics schema.** (a) derive role from `type` and label from screen text (brittle for custom controls); (b) optional `role`/`label` fields set by library controls through an internal hook. Recommendation: (a) in Phase B, (b) in G.1 before plan 032 step 13.1, deciding then whether an app-facing label modifier is 1.0 (036 lesson 5).
5. **omp2 scaffolding and the kept review pages.** Settled by the owner (2026-10-20): the review site's Tessera pages and `/tokens` page are preserved and committed in some form as the gallery seed (plan 032 step 7.4 amendment). C.2 makes the kept pages the regression review view (wireframe, current, previous) wherever they land.
6. **Scenario input: events or bytes.** Typed `InputEvent` verbs with a `bytes` escape hatch (one grammar, parser coverage on demand).
7. **Schedulable clock.** The Spike 5 clock seam feeds pass durations only; `wait`, `settle`, and motion verbs need plan 032 step 16.1's environment clock to be one the harness can advance (Spec 8443–8448 leaves the mechanism open). Decide at 16.1; until then the verbs are listed as not expressible.
8. **Windows in CI.** CI already builds libghostty on Windows (039 §11). (a) required job from Phase B; (b) non-blocking until first green, then required; (c) macOS and Linux only. Recommendation: (b); the live socket is excluded on Windows regardless.
9. **Shape of the coverage walk.** The idea is Ternbook's (`ternbook coverage`, built on Tern's `ctl key` and `ctl a11y`), not a Tern feature, and the owner has not settled its shape there either. D.2 as written is the narrow form: per focusable, the shortest route at levels `shortcut`, `tab`, `unreachable`, plus why a walk stopped. Decide its output and how much of Ternbook's route data to keep before D.2 starts; until then the D.2 invariants (`tab-cycle-terminates`, `legend-keys-handled`) carry the checking.

## Review response

Findings from the 2026-10-19 review were applied; two were adjusted:

- #3: the "previous render" view is rendered from the committed `.grid.txt`, not from a stored SVG, so the review view and the golden policy (#10) do not conflict.
- #13: `RenderedCell.width` is still added, but in C.1 and on a test-support type; A.2 keeps its "no new public API" acceptance.

## Acceptance

- A.2 seams landed with no new public API; `TesseraHarness` passes the boundary gates and is plan 032 step 8.2's headless driver through `TerminalSession.draw`; from Phase B, CI runs the Examples tests and the corpus on macOS and Linux; committed goldens are text only and drift fails without `--record`; two runs give identical bytes.
- By plan 032 Phase 10: focus is addressable, traced with cause, invariant-checked, and coverage-walked; by step 13.1: control demos use semantic locators; by Phase 17: `conform` gates `implemented` docs and the skill lets a fresh agent complete the loop unaided. The Spec's diagnostics paragraph and plan 032 carry the amendments.

## References

- Investigations 036–041; the spec's [Slice 1: TesseraCore](../spec/phase-4/slice-01-tesseracore.md) (what it proves, `RuntimeNode` and `ViewGraph`), [Slice 4: focus and key routing](../spec/phase-4/slice-04-focus-and-key-routing.md#things-to-flag), and [Slice 5: mouse and hit testing](../spec/phase-4/slice-05-mouse-and-hit-testing.md); `docs/design.md:60-67, 115-143, 240-245, 272-282, 314-315`; `docs/design/tokens.md:14-26`; plan 032 `:481-488, 501-543`; Lattice `docs/design/devtools.md` (Principles, `lattice dev` family, Decisions 2–3); Tern `tern help dev` as recorded in 037.
