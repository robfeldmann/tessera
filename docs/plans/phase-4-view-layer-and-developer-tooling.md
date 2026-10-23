---
type: plan
stage: planned
created: 2026-10-22
order: 36
description: Build the Phase 4 view layer from the omp2-reviewed catalog and the developer tooling that drives, pictures, and checks it, in one slice order where each component lands with its demo, its scenario, and the harness capability it needs.
---

# Build the Phase 4 view layer with the tooling that proves it

Goal: Tessera's 1.0 view layer (styling, focus, pointer, scrolling, controls, collections, SplitView, the remaining views, and an intro app) lands component by component from the `ready` catalog docs, and every component arrives with a demo that runs live and headlessly, a scenario that an agent can run without prose, and the harness checks that catch the defect classes the archived attempts missed. When this is done, `mise run dev:run Examples/Scenarios` passes on macOS and Linux, `conform` gates every `implemented` catalog page, and a fresh agent given only the `tessera-devtools` skill can drive a demo, read a failure, and take a shot.

This plan merges plan 032 (Phases 8-17, its open implementation phases; Phases 1-7 are complete and stay there as history) and plan 033 (the developer tooling, with its spikes, decisions, and owner feedback). Both are cancelled and link here (plan 035 Step 6.3).

## Progress

- [ ] 1 Terminal colour reports
- [ ] 2 Seams for the harness
- [ ] 3 Harness target and Showcase retirement
- [ ] 4 Demo contract, registry, viewports, and the headless driver
- [ ] 5 Scenario language, runner, `tessera-dev`, and the CI corpus
- [ ] 6 Projection, locators, invariants, cost, trace, and shots, with the first demos
- [ ] 7 Flow layout and `ViewThatFits`
- [ ] 8 Styling and decoration, with pictures, roles, and catalog review
- [ ] 9 Focus, key routing, and KeyLegend, with focus tooling
- [ ] 10 Mouse, hit testing, and hover, with pointer tooling
- [ ] 11 Interactive ScrollView, with scroll checks
- [ ] 12 Roles and labels in the projection
- [ ] 13 Controls
- [ ] 14 Collections
- [ ] 15 Interactive SplitView
- [ ] 16 The animation path and the schedulable clock
- [ ] 17 Remaining 1.0 views
- [ ] 18 Live inspection
- [ ] 19 Docs, skill, and the conformance gate
- [ ] 20 Intro app and Phase 4 closure

Next: Slice 1 and Slice 2, in parallel, under [Unattended execution](#unattended-execution); Slice 3 follows Slice 2. Slice 4 waits for Decision 9 (i).

## Approach

Current state. `main` carries Phase 4 Slices 1, 2, and 2.5 (`TesseraCore`, `TesseraLayout`, the first `TesseraWidgets`: `ViewGraph` reconciliation, stacks, Flex, static `SplitView` and `ScrollView`), the omp2-reviewed design catalog in `docs/design/` (every component doc is `ready` or close to it), the amended spec (`docs/spec/phase-4/`), and the five tooling spikes under `spikes/` with the seams spike saved as `spikes/Seams/30e4bbf.patch`. Plan 034 fixed the two defects the spikes found in the runtime: nested view lists now lay out element by element (so demos can use `ForEach`), and the Examples package builds in CI. libghostty-vt comes from a prebuilt artifact bundle ([libghostty-vt distribution](../architecture/libghostty-vt-distribution.md)), so no build or test job runs Zig. The toolchain lanes are Swift 6.3.3 (baseline) and 6.4 (`docs/architecture/toolchain-lanes.md`); tasks are mise tasks (`mise run …`), and the docs are the `docs/` IWE workspace.

End state. The components of `docs/spec/phase-4/` "The 1.0 surface" are implemented and graduated into DocC, each demo is a snapshot fixture at its declared viewports, `Examples/Scenarios/` is the behaviour corpus that CI runs on macOS, Linux, and Windows, and `TesseraHarness` (root package; the library app authors import to drive and check their own apps), `Examples/Sources/DemoSupport`, and `Examples/Sources/TesseraDev` (`tessera-dev`) are the tooling that plan 033 designed.

Patterns to follow. Each step starts from a `ready` catalog doc (finishing it is the first part of the step). Each component lands with its tests, its demo, and its scenario in one reviewable step; port from the archive tags (`archive/phase4`, `archive/phase4-review-loop`, `archive/phase4-unicode-demo-stash`, `archive/catalog-workbench`) only after reading the code against the doc, using the port map in `docs/research/phase-4-salvage-review.md`. Measurement and `body` stay pure; every `NodeState` row has one owner; collections key by stable IDs and fail closed on duplicates. The harness never compensates for a library bug (demos find bugs; the library is fixed). Text goldens are the only committed artefacts; drift fails without `--record`. No test affordances in product API: `TesseraCore` gains only value-typed diagnostics fields, each by spec amendment. A slice that adds or changes a tool updates [Developer tooling](../architecture/developer-tooling.md) (or the per-tool page it links) and the `tessera-devtools` skill before the slice is checked off, so the page describes the tools as built plus what is still only designed, and agents building later slices use the skill as they go.

Patterns to avoid. The Showcase (a monolithic demo app) and the archived batch attempts; porting review bundles or committed captures; a `wait` that sleeps; prints as the way to answer "why".

Files that orient a newcomer. [Developer tooling](../architecture/developer-tooling.md) (what the tools are and how they fit), `docs/spec/phase-4/architecture.md`, `docs/spec/phase-4/testing-posture.md`, `docs/design.md` (status ladder, wireframes, table schemas, graduation), `docs/design/tokens.md` (viewports, roles), `docs/design/translation-key.md`, `docs/research/phase-4-salvage-review.md`, the five spike READMEs under `spikes/`, and plan 033's "Tool surface" section (kept verbatim in the cancelled plan, which this plan cites rather than repeats).

Non-goals. A `TesseraTern` backend (Tern Surface Protocol output), modal overlays, and post-1.0 views stay out.

Open questions: Decision 9 below.

## Slices

### 1 Terminal colour reports

The terminal half of [terminal color reports](../spec/phase-3/slice-06-terminal-capability-detection.md#terminal-color-reports) (spec Phase 3 Slice 6, the 2026-10-19 amendment) and the [probe contract](../design/tokens.md#probe) in the tokens doc: the parser gains an OSC reply path (`rgb:` and `rgba:` bodies, 1 to 4 hex digits per channel scaled to 8 bits, BEL or ST, OSC 4 slots in any order, consumed as probe evidence and never delivered as keys); the active generation sends OSC 10, OSC 11, and OSC 4 for slots 0-15 as one write ended by the round's single DA1; the round's timeout default rises to 1 s; `NO_COLOR` asks only OSC 11; `.passive` and `.disabled` detection send no colour queries; the first frame waits for the round; late replies update the report; mode 2031 is enabled at startup with `CSI ? 2031 l` registered for cleanup, and each `CSI ? 997 ; 1 n` or `; 2 n` notification and each resume re-runs the round; replies fill `TerminalCapabilities.colorReport`. Resolving colour roles from the report (the token tiers) is Slice 8's, not this slice's. This slice depends on no other slice and uses only the existing terminal test support (`InMemoryTerminalDevice` with scripted replies), so it runs in parallel with Slices 2-7.

Delivers: a session against a terminal that answers fills `colorReport` before the first frame, and one that does not leaves every input unknown without delaying past the timeout. Verify: the spec's test list for the round (one write, both reply forms and terminators, DA1 or timeout ending, late replies as updates, OSC 11 only under `NO_COLOR`, notification and resume re-runs, cleanup bytes); the Windows input path parses the same replies (`mise run vm:windows-test`); the spec section's "not yet implemented" note is removed in the same change.

### 2 Seams for the harness

Plan 033 Step A.2. Apply `spikes/Seams/30e4bbf.patch` by hand against today's sources (it was written on `cb8d143`; plan 034 changed `PlatformIO` size fan-out and `TerminalSession` since): `InMemoryTerminalDevice` `package init(…keepsInputOpen:)`, `deliverResize(to:)`, `closeInput()`; `withApplicationTerminal` forwarding `probeImageID` and `probeSleep`; the `ViewGraph` clock seam as is; `TerminalSession` `package private(set) var lastDrawn: DrawnFrame?` set after a successful flush, `package var size`, and `package var outputTap` teed before `io.write`. Plan 034 already made `PlatformIO` fan one size subscription out newest-only, so the patch's fan-out hunk is replaced by the landed one, and `events`/`nextEvent()` already drain one queue. Nothing new is `public`.

Delivers: a mid-session `.resize` through `InMemoryTerminalDevice` redraws at the new size; `lastDrawn` and `outputTap` match the device's bytes. Verify: `mise run core:test -- --filter TerminalSessionTests` with the seam tests from the patch adapted and green; `grep -rn "public" <changed files>` shows no new public API.

### 3 Harness target and Showcase retirement

Plan 033 Step A.3 and plan 032 Step 8.1. Add `TesseraHarness` as a root-package library target (beside `TesseraTestSupport`; boundary allowlist rows in `scripts/check-package-boundaries.py` and the shared `swiftSettings`), move the spike code with its goldens byte-identical before any addition, platform code into per-OS `sources:` shims. App authors will import it (2026-10-22 decision), so its public names are chosen for them from the start, and it uses the root package's `package` seams internally without re-exporting them; its product and stability promise follow Decision 9. Delete `Examples/Sources/TesseraShowcase/`, its tests, the `core:showcase` task, and its mentions in `README.md`, `docs/project-status.md`, `CONTRIBUTING.md`, and the changelog's unreleased notes.

Delivers: `swift build` and `mise run quality:architecture` green with the new target; nothing builds, runs, or links the Showcase. Verify: `mise run ci:check`; `spikes/README.md` says nothing new goes there.

### 4 Demo contract, registry, viewports, and the headless driver

Plan 032 Step 8.2 and plan 033 Step B.1. `Examples/Sources/DemoSupport`: `HeadlessApp` (in `TesseraHarness`), `Demo`, `DemoRegistry` (one selection point, fails closed on duplicates), `Viewport` (`desktop` 80x24, `mobile`, `mobileScreen` 40x16, `custom`); each demo declares its `fixtures`, no default. One `Driver` with one update policy (ported from the review loop's `ApplicationDriver`) and `DemoHost.isQuitKey` whole-key matching; live and headless share the `Driver` and the `TerminalSession.draw` path. The `mobile` rule is decided (Decision 1, (b)): `mobile` is 40 columns at natural height, derived through a package-level nil-height proposal on `ViewGraph` plus two-height detection, so a height-greedy demo fails `size mobile` with an error naming `mobileScreen` (40x16). Demos follow the rules in [Developer tooling](../architecture/developer-tooling.md#demos): interactive, every variable style shown, extra controls allowed for complex components, no workarounds for library bugs. Create `.agents/skills/tessera-devtools/SKILL.md` with what this slice makes usable (`demo run`, a demo's headless snapshot test) and an `AGENTS.md` pointer to it; later slices extend it.

Delivers: a demo runs live in a terminal and renders identically headless. Verify: registry tests cover duplicates and lookup; a greedy demo fails `size mobile`; one demo's snapshot test is a few lines. This slice starts only once Decision 9 (i) is recorded below, since it fixes what `HeadlessApp` is.

### 5 Scenario language, runner, `tessera-dev`, and the CI corpus

Plan 033 Steps B.2 and B.3. `Examples/Scenarios/README.md` is the grammar (one statement per line, shell quoting, `#` comments; `app`, `size`, `term` header; `resize`, `key`, `type`, `paste`, `bytes`; `shot`, `tree`, `dump`; `expect text|screen|cell|node|cost`; `check`; the "not yet expressible" table for `wait`, `settle`, `focus`, `mouse`). Header-binding, fail-fast parser (`FILE:LINE: error:`); the runner continues after a failed expectation; one `ScenarioReport` yields the human and JSON forms; `--record`, `--repeat N`, `--timing`; exit 0 pass, 1 expectation failed, 2 usage or parse error, 3 harness error; one JSON object per command on stdout when stdout is not a terminal. `Examples/Sources/TesseraDev` is `HarnessCLI.main(registry:)` with `demo list|run`, `run`, `shot`, `tree`, `check`, `replay`; `mise-tasks/dev/*` mirror it (`dev:run`, `dev:shot`, …, each with `#USAGE`); `help COMMAND` prints real text. CI: the `test` matrix's macOS, Linux, and Windows legs run `swift test --package-path Examples` and `tessera-dev run Examples/Scenarios`, all required (Decision 7); a `.gitattributes` rule checks goldens out with LF on every platform, so Windows' CRLF checkout cannot drift them. Amend the spec's [testing posture](../spec/phase-4/testing-posture.md) so scenarios, the harness, and `check` sit beside snapshots and unit tests as a testing layer, pointing at [Developer tooling](../architecture/developer-tooling.md) for the design; later tooling slices keep that page current the same way. The harness answers the terminal's colour queries itself, from the scenario's `term` header (colours known with given values, or unknown), so a styled golden never depends on the Ghostty virtual terminal's default colours.

Delivers: an agent runs and reads a scenario without prose; a deliberately broken scenario fails CI. Verify: two runs give identical bytes; a parse error under `--json` is a failure with verb `parse`; a drifted golden fails without `--record`; the CI probe (break a scenario, watch the run fail, revert); the Windows leg passes the corpus with goldens checked out by Git for Windows' defaults.

### 6 Projection, locators, invariants, cost, trace, and shots, with the first demos

Plan 033 Step B.4 and plan 032 Step 8.3. `Projection` (sorted-key JSON of `GraphDiagnostics` with short `type` and `layout`, counters and `invalidationReasons`, no durations, a pass marker, plus the screen), `SEL` locators v0 (`type=`, `layout=`, `id=`, `text=`, `nth=`), invariants v0 (`no-dirty-after-pass`, `frame-inside-clip`, `measured-within-proposal`, `siblings-disjoint`, `requirements-aggregate`), `expect cost`, trace v0 (one JSONL record per step with `reasons`, changed nodes and rows, `cost`), and `shot` as `NAME.txt` plus `NAME.grid.txt`. Demos for the landed primitives: Text (including the archived Unicode demo), stacks and `Spacer`, `frame`/`padding`, `ZStack`, and Flex, each with a scenario that takes a `shot` at `desktop` and `mobile` and asserts one `expect node … frame`.

Delivers: each landed primitive has snapshot coverage at both sizes and reads well at 40 columns; a demo's trace names the invalidation reason for each redraw. Verify: `mise run dev:run Examples/Scenarios` green; `siblings-disjoint` passes on a `ForEach` demo (the defect plan 034 fixed stays fixed).

### 7 Flow layout and `ViewThatFits`

Plan 032 Step 14.1, moved before styling (Decision 2) so every later demo can wrap and switch arrangements at the 40-column `mobile` viewport; Picker's radio group wraps with Flow and `ViewThatFits` chooses its title and menu layouts, and Form, LabeledContent, ProgressView, and TabView need both. A wrapping row layout and `ViewThatFits` with layout priority, from the `ready` docs `docs/design/primitives/flow.md` and `view-that-fits.md`. Their plain requirements land here; the requirements under each doc's `### Focus` and `### Pointer` subsections (unchosen candidates leave focus and hit testing, item focus survives a reflow) are not testable yet, and Slices 9 and 10 finish them. The catalog's capability subsections (2026-10-23 decision) exist before this slice starts; if they do not, this slice adds them for every catalog doc first.

Delivers: Flow and ViewThatFits demos with scenarios at both sizes. Verify: `check` passes with `siblings-disjoint` on a ViewThatFits demo that swaps arrangements on resize; Slice 9 adds `focus-resolves` to that scenario.

### 8 Styling and decoration, with pictures, roles, and catalog review

Plan 032 Phase 9 (Steps 9.1-9.4) and plan 033 Phase C. Style environment, tones, and `Text + Text` styled runs measured once (9.1), resolving each role in the `derived`, `slots`, or `monochrome` tier of `docs/design/tokens.md` from Slice 1's `colorReport`; word wrapping that breaks inside a word only when the word is wider than the line, `.lineLimit`, `.truncationMode` (9.2); border glyph families with ASCII fallbacks, `Box` with a View title, `background`, `overlay`, the focus border style (9.3); the shared output-only `ScrollIndicator` with thumb and track styles (9.4). Tooling: `RenderedCell.width` from Ghostty's wide flag, SVG shots as a review aid, the `theme=probe` role palette with `fg=ROLE`/`bg=ROLE` cell assertions (C.1); `expect wireframe PATH N [at SEL]`, `shot NAME SEL`, `conform`, and the gallery's Current and Previous slots fed by role-styled grids in the catalog's dialect (C.2).

Delivers: demos for text styling, truncation, borders, and indicators; styled-grid snapshots cover every glyph family and its ASCII fallback; `conform docs/design/primitives` reports pinned and unpinned fences in JSON. Verify: a focus-border demo asserts `fg=focus` under `theme=probe` and reads identically in SVG and `.txt`; SVG determinism by SHA-256 across macOS and Lima Linux.

### 9 Focus, key routing, and KeyLegend, with focus tooling

First, every component built before this slice gets the requirements under its catalog doc's `### Focus` subsection (find them with `iwe find --blocks '{ $section: Focus }'` from `docs/`, filtered to built components) as tests, so nothing built earlier skips focus; a component built later handles its own `### Focus` subsection in its own slice. Plan 032 Phase 10 (Steps 10.1-10.3) and plan 033 Phase D. Document-order focus with wrap, removal handling, and leaf-to-ancestor bubbling (ported from `phase4` `Focus.swift`, `Responder.swift`, `FocusRoutingTests`); Step 10.1 also wires the dead `focusChanges` counter (`GraphStatistics.swift`), `handlerKinds`, and `terminalRequirementChanges`. Focus appearance hosts and focus scopes (10.2); `KeyLegend` from responder key bindings, `plain` by default, `keycaps` optional, dropping whole entries by priority when narrow (10.3). Tooling: the spec amendment that adds `isFocusable` and `isFocused` to the projection, `focused`/`focusable` locators, `focus SEL`, `expect focused SEL` (D.1); the rules `exactly-one-focus`, `focus-resolves`, `focused-visible`, `focus-indicated`, `tab-cycle-terminates`, `legend-keys-handled`, and `tessera-dev coverage --app NAME` (D.2; Decision 8: per focusable, the level `shortcut`, `tab`, or `unreachable` and the shortest route as `from` plus key-and-count `steps`, arrow steps counted in the route but not as presses, plus why the walk stopped); trace `dispatch{disposition, handledBy, path}` and `focus{from, to, cause}` (D.3).

Delivers: a focus demo and a KeyLegend demo with scenarios asserting `focused`; routing tables cover focused, bubbled, ignored, and removed responders. Verify: coverage reports no `unreachable` focusable in any demo; a swallowed key's trace names the node that consumed it; an invisible-focus fixture fails `focused-visible`; a `colors=none` run fails `focus-indicated` when focus has no glyph.

### 10 Mouse, hit testing, and hover, with pointer tooling

First, every component built before this slice gets the requirements under its catalog doc's `### Pointer` subsection (find them with `iwe find --blocks '{ $section: Pointer }'` from `docs/`, filtered to built components) as tests, so nothing built earlier skips pointer input; a component built later handles its own `### Pointer` subsection in its own slice. Plan 032 Phase 11 (Steps 11.1-11.3) and plan 033 Phase E. Clipped, deepest-first hit testing in paint order, click-to-focus, pointer capture (ported from review-loop `ab272c2`); hover state with any-event tracking requested only while a handler needs it, cleared on focus loss; application-owned text selection and copy per `docs/design/primitives/text-selection.md`, or an explicit deferral recorded in the spec. Tooling: `mouse click|move|scroll|down|up R,C`, `hit R,C` returning the deepest node path and whether it captured; traces record capture changes.

Delivers: a pointer demo; the overlap, clipping, capture, and de-escalation tests exist as scenarios. Verify: `mise run dev:run` over the pointer scenarios; the requirement de-escalation shows in the trace.

### 11 Interactive ScrollView, with scroll checks

First, every component built before this slice gets the requirements under its catalog doc's `### Scroll` subsection (find them with `iwe find --blocks '{ $section: Scroll }'` from `docs/`, filtered to built components) as tests, so nothing built earlier skips interactive scrolling; a component built later handles its own `### Scroll` subsection in its own slice. Plan 032 Phase 12 (Steps 12.1-12.2) and plan 033 Step G.2. Keyboard and wheel scrolling, boundary bubbling to an enclosing viewport, focus only while scrollable; indicators stay output-only (a click or drag on one returns `.ignored`); reveal on focus change (`docs/research/focus-appearance-host-inside-scroll-content.md`). Rules `scroll-offset-within-content`, `selection-visible`, `unique-collection-ids`; `expect node SEL visible` understands scroll clips.

Delivers: a ScrollView demo with nested viewports at both sizes, ending with `check`. Verify: moving focus into hidden content scrolls it into view in a scenario.

### 12 Roles and labels in the projection

Plan 033 Step G.1 (before the first control). `role` and `label` as value-typed, optional projection fields set by library controls through an internal hook (no public view API), added by spec amendment in this slice; `role=`/`label=` locators; nodes without a role fall back to one derived from `type`, and without a label to their screen text (Decision 4). No app-facing label modifier in 1.0; the fields are shaped so a later accessibility or Tern Surface Protocol export can read them.

Delivers: locators address controls by meaning. Verify: a scenario finds a Button by `role=button label="Submit"` before Slice 13 lands.

### 13 Controls

Plan 032 Phase 13 (Steps 13.1-13.4). Each control lands with its demo, keyboard and pointer paths, and disabled state, driven by `role=`/`label=` locators, never coordinates. Button with the three emphases and the shape set with ASCII ends, the pressed state reaching rendering; Toggle (`.checkbox`, `.circle`) with the Form row focus rule; Picker as radio group (chips wrap with Flow), menu (with the "Other" row), and segmented (icons-only and tail truncation when narrow), and MultiPicker; Stepper (arrows visible unfocused, the limit arrow disabled, clamped stepping and overflow tests); TextField on a shared grapheme-safe text editing core with the character counter (ported from review-loop `TextFieldEditor.swift`).

Delivers: four control demos with scenarios. Verify: every control scenario uses semantic locators; `check` passes; the pressed Button state is visible in a shot.

### 14 Collections

Plan 032 Steps 14.2-14.4. List and Section (one focus stop, controlled selection, the shared indicator, badges on rows); Outline with path mode (expanders, guides, a root folder icon, badges before icons, path folding); Grid on the shared Flex solver and Table with `.plain`, `.bordered`, and `.grid` styles plus alternating row backgrounds, sorted by column identity.

Delivers: List, Outline, Grid, and Table demos ending with `check`. Verify: `unique-collection-ids` fails closed on a duplicate-ID fixture; `selection-visible` holds while scrolling a List.

### 15 Interactive SplitView

Plan 032 Step 15.1. Divider keyboard and mouse resizing (arrow and Shift+arrow steps, a wider grab target, double-click or `=` to reset), the focus style, clipping without automatic collapse, the ASCII junctions, nesting, and content-minimum sizing; ported from review-loop `SplitView.swift` after fixing its duplicate-ID trap and its binding writes during update. Also settle the pane-content rule plan 034 discovered (a pane whose content is a nested multi-view list places only the first view): one view per pane is an error or a documented rule.

Delivers: a SplitView demo covering the five edge cases. Verify: scenarios drive the divider by keyboard and pointer and assert pane frames.

### 16 The animation path and the schedulable clock

First, every component built before this slice gets the requirements under its catalog doc's `### Clock` subsection (find them with `iwe find --blocks '{ $section: Clock }'` from `docs/`, filtered to built components) as tests, so nothing built earlier skips the clock; a component built later handles its own `### Clock` subsection in its own slice. Plan 032 Step 16.1 and plan 033 Decision 7. A clock in the environment that the harness can advance, and a declared tick requirement aggregated like `TerminalRequirements`; with it, the scenario verbs `wait` and `settle` and the motion views become expressible (they are listed as not expressible until here). The seams-spike clock feeds pass durations only, so this is a design step, not a port.

Delivers: a spinner demo whose scenario advances the clock deterministically. Verify: two runs give identical bytes; no scenario sleeps.

### 17 Remaining 1.0 views

Plan 032 Steps 16.2-16.3. `ProgressView` (determinate and indeterminate spinner sets), `Callout`, `LabeledContent`, `Label` with the icon catalog, `Badge`, `ContentUnavailableView`; then TabView, Form, Markdown, the code view, and `Image`, per `docs/spec/phase-4/` "The 1.0 surface".

Delivers: a demo per view with scenarios at both sizes. Verify: `conform` pins every `implemented` fence these views graduate.

### 18 Live inspection

Plan 033 Phase F, under Decision 3 (b). First amend the spec's diagnostics paragraph: `TesseraCore` still serializes nothing; a dev runner outside the library may expose an opt-in, local, same-user endpoint that serializes the harness projection and injects input through the normal step path. Then the Unix-domain NDJSON endpoint behind `TESSERA_DEBUG_SOCKET` (`text`, `grid`, `tree`, `stats`, `shot`, `key`, `type`, `mouse`, `resize`, `quit`), `tessera-dev attach`, `quit` unlinking before replying, `ctl` exit 3 for missing, stale, silent, and unsupported; excluded on Windows for now (Windows 10 and later have `AF_UNIX`, so the spike's exclusion can be revisited). Nothing else depends on it.

Delivers: a demo in a real terminal answers `text`, `tree focused`, and `key Tab` from a second shell. Verify: the transport-parity test runs every scenario in-process and over the socket with identical reports.

### 19 Docs, skill, and the conformance gate

Plan 033 Phase H. The final review and revision of the `tessera-devtools` skill that Slice 4 created and each tooling slice extended (the loop: `demo run` → `run` → read JSON → `shot` → `tree` → trace → `check` → fix the library, never the demo; never `--record` to make a failing run pass); `docs/guides/developer-tools.md` (the human how-to for Tessera contributors and app authors, linking [Developer tooling](../architecture/developer-tooling.md) for the design rather than repeating it); the app-author path from Decision 9 (an app adopts the harness, writes scenarios, and runs `check` in its own CI); the spec's diagnostics paragraph checked against the amendments Slices 12 and 18 made; and the doc drift `docs/research/tui-devtools-prior-art.md` names fixed. `mise run ci:check` and CI run `conform` on `implemented` docs.

Delivers: a fresh agent given only the skill drives a demo, reads a failure, and produces a shot without reading source; an app outside this repository's package graph runs a scenario with `check` against a released or tagged Tessera. Verify: that agent run, recorded in this plan; the external app's CI run; CI fails on an unpinned `implemented` wireframe (probe and revert).

### 20 Intro app and Phase 4 closure

Plan 032 Steps 17.1-17.2. A Textual-style intro app that composes the per-component demos (navigation only, no component behaviour), with a scenario per screen; move each implemented doc's durable content into DocC, mark it `implemented`, run the performance and platform checks, and the full quality gate.

Delivers: Phase 4 closed. Verify: every catalog page for a shipped view is `implemented` and pinned; `mise run ci:check`, `mise run docs:lint`, and the Lima and Windows suites green.

## Unattended execution

Rules for an agent running slices of this plan without the owner.

- Base: this plan's current decisions live on the docs branch `docs/phase-4-decisions` until its pull request merges, and on `main` afterwards. Create each run's worktree from that base with `wt switch --create BRANCH --base origin/docs/phase-4-decisions` (or `--base origin/main` once it has merged), so the worktree hooks run, and do all work there; the `main` worktree is not touched.
- Branches and pull requests: one branch and one draft pull request per slice, with a Conventional Commit title. Slice 1 is `phase-4/01-terminal-colour-reports`; Slice N is `phase-4/NN-<short-name>`. A slice that depends on an unmerged slice branches from that slice's branch and targets it; every other pull request targets the docs branch until it merges and `main` afterwards. Commit at least once per slice and push after each commit so CI runs.
- Never: push to `main`, merge a pull request, force-push a branch another run uses, delete a branch, worktree, tag, or release, create tags or releases, or change repository settings or rulesets.
- Checks before each commit: the `AGENTS.md` gate, `mise run quality:format`, the full `swift test` on the baseline toolchain (`DEVELOPER_DIR=/Applications/Xcode-26.6.0.app/Contents/Developer`), and `mise run quality:lint`; add `mise run docs:lint` when DocC or public API changes, and `swift test --package-path Examples` once the Examples package carries the change. mise is not activated in a plain shell; use `mise exec --` or `mise run`. A new worktree needs `npm ci` before `quality:format`.
- VMs: the Lima guest `tessera-linux` and the UTM guest `tessera-windows-11` are shared between runs; start them with `mise run vm:linux-start` and `mise run vm:windows-start`, deliver a worktree with the `*-push` tasks, run one VM test at a time per guest, and leave them running at the end.
- CI waits: watch runs with `gh run watch` or `gh run view`; a hosted-runner flake (a cancelled leg, a runner that never starts) is retried once with `gh run rerun --failed` and recorded in Discoveries.
- Handoff: after each slice, check its box only with evidence on the line (a SHA, a run ID, a command and its result), update `Next:`, and record Decisions and Discoveries as they happen. The run will outlast one context; the plan is the handoff. Plan edits made on a slice branch land with that slice's pull request.
- Owner decisions: a slice whose text names an open decision (Decision 9 (i) for Slice 4) does not start until the decision is recorded under Decisions. A design question a slice meets that its catalog doc, the spec, and this plan do not answer is recorded in the slice and in Discoveries with a proposed answer, and the slice continues only where the answer cannot change public API or a catalog doc's promises.
- Stuck: before recording a slice as blocked, spawn an `architect` agent at medium effort with the slice, what was tried, and the first error, and try what it proposes. Record its advice and the result in Discoveries either way.
- Blocked slices: record what was tried, the architect's advice, and the first error in the slice, leave the box unchecked, and stop that run's chain; slices that do not depend on it may still run.
- Left for the owner: reviewing and merging the pull requests, and every open decision.

## Acceptance

- [ ] Every open step of plans 032 (Phases 8-17) and 033 (A.2 onward) is covered by a slice above, and no step remains only in the cancelled plans.
- [ ] Each component lands with its tests, its demo, and its scenario in one reviewable step, from a `ready` catalog doc.
- [ ] `mise run dev:run Examples/Scenarios` passes on macOS, Linux, and Windows in CI; committed goldens are text only and drift fails without `--record`; two runs give identical bytes.
- [ ] An app outside this repository's package graph depends on Tessera, adopts the harness, and runs a scenario with `check` in its own CI.
- [ ] By Slice 9, focus is addressable, traced with cause, invariant-checked, and coverage-walked; by Slice 13, control demos use semantic locators; by Slice 20, `conform` gates `implemented` docs.
- [ ] The spec's diagnostics paragraph carries every amendment this plan makes, and no test affordance is public API.
- [ ] [Developer tooling](../architecture/developer-tooling.md) describes every tool as built, and no tool that has landed is still described only as designed.

## Decisions

- 2026-10-10 Keep `main`'s Slices 1, 2, and 2.5 and restart the rest in this order, porting archived code only where it survives review against the updated catalog doc. (owner, plan 032)
- 2026-10-10 Each component lands with a small standalone demo that runs live and renders headlessly; demo renders are snapshot fixtures; the Showcase is abandoned. (owner, plan 032)
- 2026-10-18 Form, Picker, MultiPicker, LabeledContent, ProgressView, and TabView wrap or choose between arrangements with Flow and `ViewThatFits`. (owner, plan 032)
- 2026-10-20 The review site's Tessera pages and `/tokens` page are the gallery seed; the regression review view shows wireframe, current, and previous from committed `.grid.txt`. (owner, plan 033 Decision 5)
- 2026-10-20 Scenario input is typed `InputEvent` verbs with a `bytes` escape hatch. (owner, plan 033 Decision 6)
- 2026-10-21 The headless driver lives in the harness library (`TesseraHarness`, root-package test support), and each demo declares its viewports. (owner, plan 034 R-10 and plan 033 Decision 3)
- 2026-10-21 Plan 032 Step 10.1 wires the dead `focusChanges` counter; the role and label hook lands before the first control; the environment clock is a `Clock` the harness can advance. (owner, plan 035 Step 6.1)
- 2026-10-22 Flow and `ViewThatFits` (plan 032 Step 14.1) move before the controls, after focus and hit testing. (this plan, from the 2026-10-21 owner review note under plan 032 Step 13.2) Superseded 2026-10-23 by Decision 2 below.
- 2026-10-22 Decision 1, the `mobile` viewport: (b), 40 columns at the component's natural height, with `mobileScreen` (40x16) declared per demo for screen-filling compositions; the harness derives natural height with the package nil-height probe and two-height detection, and a height-greedy demo fails `size mobile` naming `mobileScreen`. This confirms the 2026-10-10 catalog decision; `docs/design/templates/widget.md`, `docs/design/widgets/stepper.md`, and Slice 4 were brought into line, and plan 032 Step 8.2 stays as history in the cancelled plan. (owner, plan 035 Step 6.2)
- 2026-10-22 The tools' design lives in `docs/architecture/developer-tooling.md`, written before Slice 2 from plan 033 and the spikes, without plan or slice references; each slice that touches a tool keeps it and the `tessera-devtools` skill current before the slice is checked off, and a tool that outgrows its section moves to its own page under `docs/architecture/developer-tooling/`. The skill is created in Slice 4 so the agents building later slices use it, and Slice 19 is its final review. Demos show their component working (interactive, every variable style, extra controls allowed for complex components) rather than the archived "teach rather than dump" bar. (owner)
- 2026-10-22 Decision 3, live inspection: (b). Amend the spec so a dev runner outside `TesseraCore` may expose an opt-in, local, same-user endpoint that serializes the harness projection and injects input through the normal step path; `TesseraCore` still serializes nothing. Slice 18 is no longer optional. (owner)
- 2026-10-22 Decision 4, `role` and `label`: (b) with (a) as the fallback. Library controls set optional, value-typed fields through an internal hook (spec amendment in Slice 12); nodes without them derive role from `type` and label from screen text. No public label modifier in 1.0; the fields are shaped for a later accessibility or Tern Surface Protocol export, which the owner wants eventually so a Tessera app can render natively in Tern or a similar host. (owner)
- 2026-10-22 Decision 7, Windows: the scenario corpus is required on Windows from Slice 5, with LF goldens through `.gitattributes`. If a Windows toolchain bug ever blocks it, that leg drops to non-blocking for that case and the reason is recorded here. (owner)
- 2026-10-22 App authors get scenarios and checks: `TesseraHarness` becomes a library app authors import to drive and check their own apps, because agent-driven development of Tessera apps depends on it. This reverses plan 033's "not offered to app authors". (owner)
- 2026-10-23 Decision 2, Flow and `ViewThatFits`: they get their own slice (Slice 7) between the projection slice and styling, before focus exists, so every later demo can lay out well at 40 columns; neither needs styling. Their focus and pointer requirements are finished by Slices 9 and 10. (owner)
- 2026-10-23 Capability requirements: each catalog doc's `## Requirements` gains `### Focus` (all keyboard handling and focused appearance included), `### Pointer`, `### Scroll` (interactive scrolling only), and `### Clock` subsections, present only where the component needs that capability, enforced by the IWE design schema. A requirement needing several capabilities goes under the one that lands last; negative assertions ("installs no responder") need the machinery, so they go in the subsection too. Slices 9, 10, 11, and 16 start by making every already-built component's subsection pass. (owner)
- 2026-10-23 Decision 5, the terminal colour-report probe: a slice of this plan (Slice 1) that depends on no other slice and runs in parallel, so styling is built and reviewed in the `derived` tier; the harness answers colour queries from the scenario's `term` header so goldens never depend on Ghostty's defaults. (owner)
- 2026-10-23 Decision 8, the coverage walk: the levels `shortcut`, `tab`, and `unreachable`, the shortest route as key-and-count steps, and the stop reason, without Ternbook's app-only levels and landmarks. The rule behind it covers every tool: an output field earns its place when it lets an agent find and fix a problem in fewer turns with less context. (owner)
- 2026-10-23 Slices renumbered: the colour-report slice is Slice 1, and Flow and `ViewThatFits` move from Slice 10 to Slice 7, so former Slices 1-5 are now 2-6, 6-9 are 8-11, 10 is 7, and 11-19 are 12-20; entries above use the new numbers. (this plan)
- Open, Decision 9: how app authors consume the harness. (i) The public surface: `HeadlessApp` as designed here, or driving the Phase 5 runtime's scene (`TestRuntime(scene:)` in `docs/spec/phase-5-runtime-and-polish.md`), and which names carry a 1.0 stability promise. Deferred by the owner (2026-10-22); on 2026-10-23 the owner asked for a `senior` review (spikes allowed) to settle it before Slice 4, so Slices 4-7 can run unattended; the owner decides from that review. (ii) Distribution of libghostty-vt: decided 2026-10-22 (owner) after [libghostty-vt distribution](../research/libghostty-vt-distribution.md): an SE-0482 static-library artifact bundle built by Tessera's CI once per Ghostty pin and published as a release asset behind `binaryTarget(url:checksum:)`, with the pinned headers committed in `CGhosttyVT`. Taken and implemented 2026-10-22 by [Ship libghostty-vt as a prebuilt binary](libghostty-vt-binary-distribution.md): `Package.swift` links the `ghostty-vt-f54340ad7781` release, no test job builds Zig, and [libghostty-vt distribution](../architecture/libghostty-vt-distribution.md) records the rule. (iii) How an app gets `tessera-dev`: a per-app executable calling `HarnessCLI.main(registry:)`, a prebuilt front end (GitHub releases, Homebrew, mise) that builds and forwards to that executable, or a SwiftPM command plugin. Deferred by the owner (2026-10-22); a per-app executable is needed under every option, so Slices 4-18 build that and nothing forecloses the others; settle before Slice 19.

## Discoveries

- `ForEach` and other view lists inside stacks laid every item at the same frame (spikes 1, 2, and 4; plan 033) — fixed by plan 034 Step 10.1 (`f4172e8`), with `siblings-disjoint` as the harness rule that would have caught it.
- A `SplitView` pane whose content is a nested multi-view list now places only its first view (plan 034 Step 10.1 discovery) — Slice 15 settles the rule.
- `Text` does not wrap at HEAD and ignores its width proposal (plan 033) — Slice 8.
- `handlerKinds` and the focus and requirement counters are dead at HEAD (plan 033; `focusChanges` confirmed in plan 034 R-10) — Slice 9.
- The seams spike's `sizeChanges` fan-out was superseded by plan 034 Step 6.6, which fans one subscription out newest-only — Slice 2 adapts the patch rather than applying it.

## Outcome

Not started.

## References

- Plan 032, [Phase 4 view layer, redesigned from the omp2 reference](omp2-reference-gallery-and-phase-4-redesign.md): Phases 8-17, the decision record, and the implementation rules.
- Plan 033, [Developer tooling for agents and humans](developer-tooling.md): the tool surface, the scenario grammar sketch, the projection and invariant catalogue, the spikes table, and owner decisions 1-9.
- Plan 034, [Terminal I/O concurrency review fixes](terminal-io-concurrency-review-fixes.md): Step 10.1 (layout flattening) and R-10.
- Plan 035, [Toolchain, repository conventions, and plan consolidation](toolchain-conventions-and-plan-consolidation.md): Phase 6.
- The spec: [Phase 4](../spec/phase-4.md), its [architecture](../spec/phase-4/architecture.md) and [testing posture](../spec/phase-4/testing-posture.md), and [Phase 5](../spec/phase-5-runtime-and-polish.md) (the open question on injected clocks).
- The catalog: [design](../design.md), [tokens](../design/tokens.md), [translation key](../design/translation-key.md).
- Research: [Phase 4 salvage review](../research/phase-4-salvage-review.md) (port map and demo rules), [Phase 4 tooling context](../research/phase-4-tooling-context-and-prior-attempts.md), [TUI devtools prior art](../research/tui-devtools-prior-art.md).
- Spikes: `spikes/README.md` and `spikes/Seams/30e4bbf.patch`.
