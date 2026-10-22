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

- [ ] 1 Seams for the harness
- [ ] 2 Harness target and Showcase retirement
- [ ] 3 Demo contract, registry, viewports, and the headless driver
- [ ] 4 Scenario language, runner, `tessera-dev`, and the CI corpus
- [ ] 5 Projection, locators, invariants, cost, trace, and shots, with the first demos
- [ ] 6 Styling and decoration, with pictures, roles, and catalog review
- [ ] 7 Focus, key routing, and KeyLegend, with focus tooling
- [ ] 8 Mouse, hit testing, and hover, with pointer tooling
- [ ] 9 Interactive ScrollView, with scroll checks
- [ ] 10 Flow layout and `ViewThatFits`
- [ ] 11 Roles and labels in the projection
- [ ] 12 Controls
- [ ] 13 Collections
- [ ] 14 Interactive SplitView
- [ ] 15 The animation path and the schedulable clock
- [ ] 16 Remaining 1.0 views
- [ ] 17 Live inspection (optional)
- [ ] 18 Docs, skill, and the conformance gate
- [ ] 19 Intro app and Phase 4 closure

Next: Slice 1.

## Approach

Current state. `main` carries Phase 4 Slices 1, 2, and 2.5 (`TesseraCore`, `TesseraLayout`, the first `TesseraWidgets`: `ViewGraph` reconciliation, stacks, Flex, static `SplitView` and `ScrollView`), the omp2-reviewed design catalog in `docs/design/` (every component doc is `ready` or close to it), the amended spec (`docs/spec/phase-4/`), and the four tooling spikes under `spikes/` with the seams spike saved as `spikes/Seams/30e4bbf.patch`. Plan 034 fixed the two defects the spikes found in the runtime: nested view lists now lay out element by element (so demos can use `ForEach`), and the Examples package builds in CI. The toolchain lanes are Swift 6.3.3 (baseline) and 6.4 (`docs/architecture/toolchain-lanes.md`); tasks are mise tasks (`mise run …`), and the docs are the `docs/` IWE workspace.

End state. The components of `docs/spec/phase-4/` "The 1.0 surface" are implemented and graduated into DocC, each demo is a snapshot fixture at its declared viewports, `Examples/Scenarios/` is the behaviour corpus that CI runs on macOS and Linux, and `TesseraHarness` (root package, test support), `Examples/Sources/DemoSupport`, and `Examples/Sources/TesseraDev` (`tessera-dev`) are the tooling that plan 033 designed.

Patterns to follow. Each step starts from a `ready` catalog doc (finishing it is the first part of the step). Each component lands with its tests, its demo, and its scenario in one reviewable step; port from the archive tags (`archive/phase4`, `archive/phase4-review-loop`, `archive/phase4-unicode-demo-stash`, `archive/catalog-workbench`) only after reading the code against the doc, using the port map in `docs/research/phase-4-salvage-review.md`. Measurement and `body` stay pure; every `NodeState` row has one owner; collections key by stable IDs and fail closed on duplicates. The harness never compensates for a library bug (demos find bugs; the library is fixed). Text goldens are the only committed artefacts; drift fails without `--record`. No test affordances in product API: `TesseraCore` gains only value-typed diagnostics fields, each by spec amendment.

Patterns to avoid. The Showcase (a monolithic demo app) and the archived batch attempts; porting review bundles or committed captures; a `wait` that sleeps; prints as the way to answer "why".

Files that orient a newcomer. `docs/spec/phase-4/architecture.md`, `docs/spec/phase-4/testing-posture.md`, `docs/design.md` (status ladder, wireframes, table schemas, graduation), `docs/design/tokens.md` (viewports, roles), `docs/design/translation-key.md`, `docs/research/phase-4-salvage-review.md`, the four spike READMEs under `spikes/`, and plan 033's "Tool surface" section (kept verbatim in the cancelled plan, which this plan cites rather than repeats).

Non-goals. The Phase 3 colour-report probe (OSC 10/11/4, mode 2031) that the spec's Phase 3 Slice 6 now specifies is not in this plan; Slice 6 renders the attribute fallbacks until the owner places that probe (Decision 5). A `TesseraTern` backend, modal overlays, and post-1.0 views stay out. Windows runs the Examples build in CI (plan 034 Step 10.3) but not the scenario corpus until Decision 7 is made.

Open questions: Decisions 2, 4, 5, 7, and 8 below.

## Slices

### 1 Seams for the harness

Plan 033 Step A.2. Apply `spikes/Seams/30e4bbf.patch` by hand against today's sources (it was written on `cb8d143`; plan 034 changed `PlatformIO` size fan-out and `TerminalSession` since): `InMemoryTerminalDevice` `package init(…keepsInputOpen:)`, `deliverResize(to:)`, `closeInput()`; `withApplicationTerminal` forwarding `probeImageID` and `probeSleep`; the `ViewGraph` clock seam as is; `TerminalSession` `package private(set) var lastDrawn: DrawnFrame?` set after a successful flush, `package var size`, and `package var outputTap` teed before `io.write`. Plan 034 already made `PlatformIO` fan one size subscription out newest-only, so the patch's fan-out hunk is replaced by the landed one, and `events`/`nextEvent()` already drain one queue. Nothing new is `public`.

Delivers: a mid-session `.resize` through `InMemoryTerminalDevice` redraws at the new size; `lastDrawn` and `outputTap` match the device's bytes. Verify: `mise run core:test -- --filter TerminalSessionTests` with the seam tests from the patch adapted and green; `grep -rn "public" <changed files>` shows no new public API.

### 2 Harness target and Showcase retirement

Plan 033 Step A.3 and plan 032 Step 8.1. Add `TesseraHarness` as a root-package test-support target (beside `TesseraTestSupport`; boundary allowlist rows in `scripts/check-package-boundaries.py` and the shared `swiftSettings`), move the spike code with its goldens byte-identical before any addition, platform code into per-OS `sources:` shims. Delete `Examples/Sources/TesseraShowcase/`, its tests, the `core:showcase` task, and its mentions in `README.md`, `docs/project-status.md`, `CONTRIBUTING.md`, and the changelog's unreleased notes.

Delivers: `swift build` and `mise run quality:architecture` green with the new target; nothing builds, runs, or links the Showcase. Verify: `mise run ci:check`; `spikes/README.md` says nothing new goes there.

### 3 Demo contract, registry, viewports, and the headless driver

Plan 032 Step 8.2 and plan 033 Step B.1. `Examples/Sources/DemoSupport`: `HeadlessApp` (in `TesseraHarness`), `Demo`, `DemoRegistry` (one selection point, fails closed on duplicates), `Viewport` (`desktop` 80x24, `mobile`, `mobileScreen` 40x16, `custom`); each demo declares its `fixtures`, no default. One `Driver` with one update policy (ported from the review loop's `ApplicationDriver`) and `DemoHost.isQuitKey` whole-key matching; live and headless share the `Driver` and the `TerminalSession.draw` path. The `mobile` rule is decided (Decision 1, (b)): `mobile` is 40 columns at natural height, derived through a package-level nil-height proposal on `ViewGraph` plus two-height detection, so a height-greedy demo fails `size mobile` with an error naming `mobileScreen` (40x16). The "Demo rules" from `docs/research/phase-4-salvage-review.md` go into the harness documentation.

Delivers: a demo runs live in a terminal and renders identically headless. Verify: registry tests cover duplicates and lookup; a greedy demo fails `size mobile`; one demo's snapshot test is a few lines.

### 4 Scenario language, runner, `tessera-dev`, and the CI corpus

Plan 033 Steps B.2 and B.3. `Examples/Scenarios/README.md` is the grammar (one statement per line, shell quoting, `#` comments; `app`, `size`, `term` header; `resize`, `key`, `type`, `paste`, `bytes`; `shot`, `tree`, `dump`; `expect text|screen|cell|node|cost`; `check`; the "not yet expressible" table for `wait`, `settle`, `focus`, `mouse`). Header-binding, fail-fast parser (`FILE:LINE: error:`); the runner continues after a failed expectation; one `ScenarioReport` yields the human and JSON forms; `--record`, `--repeat N`, `--timing`; exit 0 pass, 1 expectation failed, 2 usage or parse error, 3 harness error; one JSON object per command on stdout when stdout is not a terminal. `Examples/Sources/TesseraDev` is `HarnessCLI.main(registry:)` with `demo list|run`, `run`, `shot`, `tree`, `check`, `replay`; `mise-tasks/dev/*` mirror it (`dev:run`, `dev:shot`, …, each with `#USAGE`); `help COMMAND` prints real text. CI: the `test` matrix's macOS and Linux legs run `swift test --package-path Examples` and `tessera-dev run Examples/Scenarios` (the Examples build already runs on every leg).

Delivers: an agent runs and reads a scenario without prose; a deliberately broken scenario fails CI. Verify: two runs give identical bytes; a parse error under `--json` is a failure with verb `parse`; a drifted golden fails without `--record`; the CI probe (break a scenario, watch the run fail, revert).

### 5 Projection, locators, invariants, cost, trace, and shots, with the first demos

Plan 033 Step B.4 and plan 032 Step 8.3. `Projection` (sorted-key JSON of `GraphDiagnostics` with short `type` and `layout`, counters and `invalidationReasons`, no durations, a pass marker, plus the screen), `SEL` locators v0 (`type=`, `layout=`, `id=`, `text=`, `nth=`), invariants v0 (`no-dirty-after-pass`, `frame-inside-clip`, `measured-within-proposal`, `siblings-disjoint`, `requirements-aggregate`), `expect cost`, trace v0 (one JSONL record per step with `reasons`, changed nodes and rows, `cost`), and `shot` as `NAME.txt` plus `NAME.grid.txt`. Demos for the landed primitives: Text (including the archived Unicode demo), stacks and `Spacer`, `frame`/`padding`, `ZStack`, and Flex, each with a scenario that takes a `shot` at `desktop` and `mobile` and asserts one `expect node … frame`.

Delivers: each landed primitive has snapshot coverage at both sizes and reads well at 40 columns; a demo's trace names the invalidation reason for each redraw. Verify: `mise run dev:run Examples/Scenarios` green; `siblings-disjoint` passes on a `ForEach` demo (the defect plan 034 fixed stays fixed).

### 6 Styling and decoration, with pictures, roles, and catalog review

Plan 032 Phase 9 (Steps 9.1-9.4) and plan 033 Phase C. Style environment, tones, and `Text + Text` styled runs measured once (9.1; attribute fallbacks until Decision 5 places the colour-report probe); word wrapping that breaks inside a word only when the word is wider than the line, `.lineLimit`, `.truncationMode` (9.2); border glyph families with ASCII fallbacks, `Box` with a View title, `background`, `overlay`, the focus border style (9.3); the shared output-only `ScrollIndicator` with thumb and track styles (9.4). Tooling: `RenderedCell.width` from Ghostty's wide flag, SVG shots as a review aid, the `theme=probe` role palette with `fg=ROLE`/`bg=ROLE` cell assertions (C.1); `expect wireframe PATH N [at SEL]`, `shot NAME SEL`, `conform`, and the gallery's Current and Previous slots fed by role-styled grids in the catalog's dialect (C.2).

Delivers: demos for text styling, truncation, borders, and indicators; styled-grid snapshots cover every glyph family and its ASCII fallback; `conform docs/design/primitives` reports pinned and unpinned fences in JSON. Verify: a focus-border demo asserts `fg=focus` under `theme=probe` and reads identically in SVG and `.txt`; SVG determinism by SHA-256 across macOS and Lima Linux.

### 7 Focus, key routing, and KeyLegend, with focus tooling

Plan 032 Phase 10 (Steps 10.1-10.3) and plan 033 Phase D. Document-order focus with wrap, removal handling, and leaf-to-ancestor bubbling (ported from `phase4` `Focus.swift`, `Responder.swift`, `FocusRoutingTests`); Step 10.1 also wires the dead `focusChanges` counter (`GraphStatistics.swift`), `handlerKinds`, and `terminalRequirementChanges`. Focus appearance hosts and focus scopes (10.2); `KeyLegend` from responder key bindings, `plain` by default, `keycaps` optional, dropping whole entries by priority when narrow (10.3). Tooling: the spec amendment that adds `isFocusable` and `isFocused` to the projection, `focused`/`focusable` locators, `focus SEL`, `expect focused SEL` (D.1); the rules `exactly-one-focus`, `focus-resolves`, `focused-visible`, `focus-indicated`, `tab-cycle-terminates`, `legend-keys-handled`, and `tessera-dev coverage --app NAME` in its narrow form (D.2; Decision 8); trace `dispatch{disposition, handledBy, path}` and `focus{from, to, cause}` (D.3).

Delivers: a focus demo and a KeyLegend demo with scenarios asserting `focused`; routing tables cover focused, bubbled, ignored, and removed responders. Verify: coverage reports no `unreachable` focusable in any demo; a swallowed key's trace names the node that consumed it; an invisible-focus fixture fails `focused-visible`; a `colors=none` run fails `focus-indicated` when focus has no glyph.

### 8 Mouse, hit testing, and hover, with pointer tooling

Plan 032 Phase 11 (Steps 11.1-11.3) and plan 033 Phase E. Clipped, deepest-first hit testing in paint order, click-to-focus, pointer capture (ported from review-loop `ab272c2`); hover state with any-event tracking requested only while a handler needs it, cleared on focus loss; application-owned text selection and copy per `docs/design/primitives/text-selection.md`, or an explicit deferral recorded in the spec. Tooling: `mouse click|move|scroll|down|up R,C`, `hit R,C` returning the deepest node path and whether it captured; traces record capture changes.

Delivers: a pointer demo; the overlap, clipping, capture, and de-escalation tests exist as scenarios. Verify: `mise run dev:run` over the pointer scenarios; the requirement de-escalation shows in the trace.

### 9 Interactive ScrollView, with scroll checks

Plan 032 Phase 12 (Steps 12.1-12.2) and plan 033 Step G.2. Keyboard and wheel scrolling, boundary bubbling to an enclosing viewport, focus only while scrollable; indicators stay output-only (a click or drag on one returns `.ignored`); reveal on focus change (`docs/research/focus-appearance-host-inside-scroll-content.md`). Rules `scroll-offset-within-content`, `selection-visible`, `unique-collection-ids`; `expect node SEL visible` understands scroll clips.

Delivers: a ScrollView demo with nested viewports at both sizes, ending with `check`. Verify: moving focus into hidden content scrolls it into view in a scenario.

### 10 Flow layout and `ViewThatFits`

Plan 032 Step 14.1, moved before the controls (Decision 2): Picker's radio group wraps with Flow and `ViewThatFits` chooses its title and menu layouts, and Form, LabeledContent, ProgressView, and TabView need both. A wrapping row layout and `ViewThatFits` with layout priority, from the `ready` docs `docs/design/primitives/flow.md` and `view-that-fits.md`; the rule that unchosen candidates leave focus and hit testing is testable now that Slices 7 and 8 exist.

Delivers: Flow and ViewThatFits demos with scenarios at both sizes. Verify: `check` passes with `siblings-disjoint` and `focus-resolves` on a ViewThatFits demo that swaps arrangements on resize.

### 11 Roles and labels in the projection

Plan 033 Step G.1 (before the first control). `role` and `label` as value-typed, optional projection fields set by library controls through an internal hook (no public view API); `role=`/`label=` locators; the v0 fallback derives role from `type` (Decision 4). Decide here whether an app-facing label modifier is 1.0.

Delivers: locators address controls by meaning. Verify: a scenario finds a Button by `role=button label="Submit"` before Slice 12 lands.

### 12 Controls

Plan 032 Phase 13 (Steps 13.1-13.4). Each control lands with its demo, keyboard and pointer paths, and disabled state, driven by `role=`/`label=` locators, never coordinates. Button with the three emphases and the shape set with ASCII ends, the pressed state reaching rendering; Toggle (`.checkbox`, `.circle`) with the Form row focus rule; Picker as radio group (chips wrap with Flow), menu (with the "Other" row), and segmented (icons-only and tail truncation when narrow), and MultiPicker; Stepper (arrows visible unfocused, the limit arrow disabled, clamped stepping and overflow tests); TextField on a shared grapheme-safe text editing core with the character counter (ported from review-loop `TextFieldEditor.swift`).

Delivers: four control demos with scenarios. Verify: every control scenario uses semantic locators; `check` passes; the pressed Button state is visible in a shot.

### 13 Collections

Plan 032 Steps 14.2-14.4. List and Section (one focus stop, controlled selection, the shared indicator, badges on rows); Outline with path mode (expanders, guides, a root folder icon, badges before icons, path folding); Grid on the shared Flex solver and Table with `.plain`, `.bordered`, and `.grid` styles plus alternating row backgrounds, sorted by column identity.

Delivers: List, Outline, Grid, and Table demos ending with `check`. Verify: `unique-collection-ids` fails closed on a duplicate-ID fixture; `selection-visible` holds while scrolling a List.

### 14 Interactive SplitView

Plan 032 Step 15.1. Divider keyboard and mouse resizing (arrow and Shift+arrow steps, a wider grab target, double-click or `=` to reset), the focus style, clipping without automatic collapse, the ASCII junctions, nesting, and content-minimum sizing; ported from review-loop `SplitView.swift` after fixing its duplicate-ID trap and its binding writes during update. Also settle the pane-content rule plan 034 discovered (a pane whose content is a nested multi-view list places only the first view): one view per pane is an error or a documented rule.

Delivers: a SplitView demo covering the five edge cases. Verify: scenarios drive the divider by keyboard and pointer and assert pane frames.

### 15 The animation path and the schedulable clock

Plan 032 Step 16.1 and plan 033 Decision 7. A clock in the environment that the harness can advance, and a declared tick requirement aggregated like `TerminalRequirements`; with it, the scenario verbs `wait` and `settle` and the motion views become expressible (they are listed as not expressible until here). The seams-spike clock feeds pass durations only, so this is a design step, not a port.

Delivers: a spinner demo whose scenario advances the clock deterministically. Verify: two runs give identical bytes; no scenario sleeps.

### 16 Remaining 1.0 views

Plan 032 Steps 16.2-16.3. `ProgressView` (determinate and indeterminate spinner sets), `Callout`, `LabeledContent`, `Label` with the icon catalog, `Badge`, `ContentUnavailableView`; then TabView, Form, Markdown, the code view, and `Image`, per `docs/spec/phase-4/` "The 1.0 surface".

Delivers: a demo per view with scenarios at both sizes. Verify: `conform` pins every `implemented` fence these views graduate.

### 17 Live inspection (optional)

Plan 033 Phase F, only when the owner takes Decision 3's option (b). The Unix-domain NDJSON endpoint behind `TESSERA_DEBUG_SOCKET` (`text`, `grid`, `tree`, `stats`, `shot`, `key`, `type`, `mouse`, `resize`, `quit`), `tessera-dev attach`, `quit` unlinking before replying, `ctl` exit 3 for missing, stale, silent, and unsupported; excluded on Windows. Nothing else depends on it.

Delivers: a demo in a real terminal answers `text`, `tree focused`, and `key Tab` from a second shell. Verify: the transport-parity test runs every scenario in-process and over the socket with identical reports.

### 18 Docs, skill, and the conformance gate

Plan 033 Phase H. `docs/guides/developer-tools.md`, `.agents/skills/tessera-devtools/SKILL.md` (the loop: `demo run` → `run` → read JSON → `shot` → `tree` → trace → `check` → fix the library, never the demo; never `--record` to make a failing run pass), an `AGENTS.md` pointer, the spec's diagnostics paragraph amended per Decisions 3 and 4, and the doc drift `docs/research/tui-devtools-prior-art.md` names fixed. `mise run ci:check` and CI run `conform` on `implemented` docs.

Delivers: a fresh agent given only the skill drives a demo, reads a failure, and produces a shot without reading source. Verify: that run, recorded in this plan; CI fails on an unpinned `implemented` wireframe (probe and revert).

### 19 Intro app and Phase 4 closure

Plan 032 Steps 17.1-17.2. A Textual-style intro app that composes the per-component demos (navigation only, no component behaviour), with a scenario per screen; move each implemented doc's durable content into DocC, mark it `implemented`, run the performance and platform checks, and the full quality gate.

Delivers: Phase 4 closed. Verify: every catalog page for a shipped view is `implemented` and pinned; `mise run ci:check`, `mise run docs:lint`, and the Lima and Windows suites green.

## Acceptance

- [ ] Every open step of plans 032 (Phases 8-17) and 033 (A.2 onward) is covered by a slice above, and no step remains only in the cancelled plans.
- [ ] Each component lands with its tests, its demo, and its scenario in one reviewable step, from a `ready` catalog doc.
- [ ] `mise run dev:run Examples/Scenarios` passes on macOS and Linux in CI; committed goldens are text only and drift fails without `--record`; two runs give identical bytes.
- [ ] By Slice 7, focus is addressable, traced with cause, invariant-checked, and coverage-walked; by Slice 12, control demos use semantic locators; by Slice 19, `conform` gates `implemented` docs.
- [ ] The spec's diagnostics paragraph carries every amendment this plan makes, and no test affordance is public API.

## Decisions

- 2026-10-10 Keep `main`'s Slices 1, 2, and 2.5 and restart the rest in this order, porting archived code only where it survives review against the updated catalog doc. (owner, plan 032)
- 2026-10-10 Each component lands with a small standalone demo that runs live and renders headlessly; demo renders are snapshot fixtures; the Showcase is abandoned. (owner, plan 032)
- 2026-10-18 Form, Picker, MultiPicker, LabeledContent, ProgressView, and TabView wrap or choose between arrangements with Flow and `ViewThatFits`. (owner, plan 032)
- 2026-10-20 The review site's Tessera pages and `/tokens` page are the gallery seed; the regression review view shows wireframe, current, and previous from committed `.grid.txt`. (owner, plan 033 Decision 5)
- 2026-10-20 Scenario input is typed `InputEvent` verbs with a `bytes` escape hatch. (owner, plan 033 Decision 6)
- 2026-10-21 The headless driver lives in the harness library (`TesseraHarness`, root-package test support), and each demo declares its viewports. (owner, plan 034 R-10 and plan 033 Decision 3)
- 2026-10-21 Plan 032 Step 10.1 wires the dead `focusChanges` counter; the role and label hook lands before the first control; the environment clock is a `Clock` the harness can advance. (owner, plan 035 Step 6.1)
- 2026-10-22 Flow and `ViewThatFits` (plan 032 Step 14.1) move before the controls, after focus and hit testing exist (Slice 10), because the Picker family and the Phase 16 views depend on them and their focus rule is only testable once Slices 7 and 8 land. (this plan, from the 2026-10-21 owner review note under plan 032 Step 13.2; the owner confirms on review)
- 2026-10-22 Decision 1, the `mobile` viewport: (b), 40 columns at the component's natural height, with `mobileScreen` (40x16) declared per demo for screen-filling compositions; the harness derives natural height with the package nil-height probe and two-height detection, and a height-greedy demo fails `size mobile` naming `mobileScreen`. This confirms the 2026-10-10 catalog decision; `docs/design/templates/widget.md`, `docs/design/widgets/stepper.md`, and Slice 3 were brought into line, and plan 032 Step 8.2 stays as history in the cancelled plan. (owner, plan 035 Step 6.2)
- Open, Decision 2: Slice 10's position, as proposed above.
- Open, Decision 3: live inspection versus the spec's prohibition on serialising from `TesseraCore`: (a) keep the prohibition, (b) amend the spec so a dev runner may expose an opt-in loopback endpoint that also injects input, (c) a TCP port like Textual, (d) no transport. Slice 17 happens only under (b).
- Open, Decision 4: `role` and `label` as derived values (a) or as optional fields set by library controls through an internal hook (b). Plan 033 recommends (a) in Slice 5 and (b) in Slice 11.
- Open, Decision 5: where the Phase 3 colour-report probe lands (a step before or inside Slice 6, or a separate plan); Slice 6 renders attribute fallbacks until then.
- Open, Decision 7: Windows in CI for the scenario corpus: required from Slice 4, non-blocking until first green, or macOS and Linux only. Plan 033 recommends non-blocking until first green.
- Open, Decision 8: the shape of the coverage walk's output (Ternbook's route data or the narrow form); the narrow form is Slice 7's default.

## Discoveries

- `ForEach` and other view lists inside stacks laid every item at the same frame (spikes 1, 2, and 4; plan 033) — fixed by plan 034 Step 10.1 (`f4172e8`), with `siblings-disjoint` as the harness rule that would have caught it.
- A `SplitView` pane whose content is a nested multi-view list now places only its first view (plan 034 Step 10.1 discovery) — Slice 14 settles the rule.
- `Text` does not wrap at HEAD and ignores its width proposal (plan 033) — Slice 6.
- `handlerKinds` and the focus and requirement counters are dead at HEAD (plan 033; `focusChanges` confirmed in plan 034 R-10) — Slice 7.
- The seams spike's `sizeChanges` fan-out was superseded by plan 034 Step 6.6, which fans one subscription out newest-only — Slice 1 adapts the patch rather than applying it.

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
