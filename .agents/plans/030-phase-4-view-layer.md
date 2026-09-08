---
name: Phase 4 View Layer and Specimen Integration
description:
  Reconcile delivered view-layer work with remaining selection, contract, catalog,
  tooling, and platform-validation requirements using directly runnable specimens.
status: pending
approved: 2026-09-08
created: 2026-07-17
updated: 2026-09-08
---

<!-- Allowed status values: planning, in-review, pending, in-progress, complete. -->

## Progress

- [x] **Phase 0 — Core ownership and deterministic rendering**
  - [x] 0.1 Establish package boundaries and the value/graph model
  - [x] 0.2 Implement reconciliation, environments, diagnostics, and borrowed rendering
  - [x] 0.3 Establish deterministic graph and terminal test support
- [x] **Phase 1 — Geometry and visual primitives**
  - [x] 1.1 Implement stacks, modifiers, clipping, and shared Flex allocation
  - [x] 1.2 Implement wrapping, style inheritance, decoration, and ScrollIndicator
- [x] **Phase 2 — Direct review loop**
  - [x] 2.1 Share the live and headless application driver
  - [x] 2.2 Capture actual output with explicit export permission and provenance
- [x] **Phase 3 — Focus, appearance, and one operable Button**
  - [x] 3.1 Implement focus routing and environment-derived control focus
  - [x] 3.2 Implement delegated focus appearance
  - [x] 3.3 Complete Button key/pointer activation and cancellation
- [x] **Phase 4 — Interactive viewports and pointer lifecycle**
  - [x] 4.1 Complete ScrollView offsets, reveal, indicators, and boundary bubbling
  - [x] 4.2 Complete hover, motion requirements, and pointer lifecycle coverage
- [x] **Phase 5 — Controlled editing and settings**
  - [x] 5.1 Complete single-line TextField editing and hardware cursor behavior
  - [x] 5.2 Integrate Toggle, Stepper, and Picker in a settings editor
- [x] **Phase 6 — Collections and pane composition**
  - [x] 6.1 Implement Section, List, Grid, and Table
  - [x] 6.2 Complete negotiated SplitView and adjacent-pair resizing
  - [x] 6.3 Implement scoped regular/compact navigation and record browsing
- [x] **Phase 7 — Delivered host evidence**
  - [x] 7.1 Exercise eight live specimens and deterministic replay
  - [x] 7.2 Record host quality, architecture, and performance results
- [ ] **Phase 8 — Remaining selection and contract work**
  - [ ] 8.1 Specify application-owned cross-view selection and copy
  - [ ] 8.2 Implement and verify semantic selection and policy-gated copy
  - [ ] 8.3 Reconcile the retained navigation tier and chrome requirements
  - [ ] 8.4 Resolve deferred style contracts and capability coverage
- [ ] **Phase 9 — Catalog graduation and human approval**
  - [ ] 9.1 Reconcile catalog status, DocC contracts, and fixtures
  - [ ] 9.2 Review public APIs and approve visual references
- [ ] **Phase 10 — Retained developer-tooling proposals**
  - [ ] 10.1 Decide the remaining interactive gallery scope
  - [ ] 10.2 Deliver or explicitly retire the standalone Flex/Grid explorer proposal
  - [ ] 10.3 Make the performance experiment reproducible
- [ ] **Phase 11 — Platform verification and final closure**
  - [ ] 11.1 Run Linux compilation with a matching toolchain
  - [ ] 11.2 Exercise Linux and Windows runtime paths
  - [ ] 11.3 Rerun final gates and reconcile the definition of done

## Overview

This is the **approved, authoritative plan for remaining Phase 4 work**, accepted on
2026-09-08. It reconciles the `phase4` plan at `f1061a0224bbbfe01a04d95f74ad660acc40454a`
with the review-loop implementation at `5a22022150df0676a5d0f8b6d69c7bd77743a91e` and its
packet at `18f80a4`. The original worktree and its dirty files remain read-only inputs.
This consolidation is a separate documentation commit, not a rewrite of implementation
history.

Checked steps describe the **bounded implementation or evidence named in that step**. They
do not certify every original catalog promise, every platform, or human visual approval.
Unchecked steps retain missing work or an explicit scope decision. The original Phase 3
and focus/appearance completion history is preserved, but whole-catalog readiness is
separated from implemented behavior where current documents still disagree.

Small directly runnable specimens are the integration unit. No large demonstration app,
mandatory in-app inspector, or fixed application-wide breakpoint matrix is required. This
revision removes those delivery requirements, not existing example source files. The
independent gallery/explorer proposals from current `phase4` remain visible in Phase 10
rather than being silently counted as delivered by a registry of small specimens.

This plan supersedes [the archived execution plan](phase4-review-loop/PLAN.md) and
[execution brief](phase4-review-loop/START-HERE.md); neither grants current execution
authority. [STATE.md](phase4-review-loop/STATE.md) and
[REVIEW.md](phase4-review-loop/REVIEW.md) remain historical evidence, including the
source-preservation caveat. No implementation step is currently active (`pending`).
Approval of this roadmap does not approve unresolved API/style choices or visual
baselines.

Work only in the destination feature worktree. Do not modify the original `phase4`,
rewrite history, bootstrap VMs, install system tools, merge, release, or push to main
without separate authorization. Retain these safeguards independently of the archived
brief. Resume implementation only when requested; this consolidation starts no new step.

## Reconciliation with the previous numbering

| Previous phase/step                     | Revised location and disposition                                                                                                      |
| --------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| 0–1                                     | Phase 0: package graph, ownership, graph/rendering, and test support retained.                                                        |
| 2 and 2.5                               | Phase 1 geometry; Phase 4 complete viewport; Phase 6 final pane negotiation. Intermediate allocators are not work to recreate.        |
| 3                                       | Phase 1 delivered visual behavior; Phase 9 remaining catalog graduation. Current `phase4` already marked the implementation complete. |
| 4.1–4.4                                 | Phases 3–5 routing and controlled components, plus specimen integration instead of app-specific scenarios.                            |
| 4.5–4.6, added on `phase4`              | Phase 3 explicitly retains delegated appearance and environment-derived focus.                                                        |
| 4.7, added on `phase4`                  | Step 10.1 retains the separate gallery proposal and its plan 032 dependency.                                                          |
| 5.1–5.2, 5.4–5.5                        | Phases 3–4 pointer behavior and replay; selection requirements remain in Phase 8. `onPointer` is the delivered name, not `onMouse`.   |
| 5.3                                     | Steps 8.1–8.2: cross-view selection/copy remains unimplemented. TextField selection does not satisfy it.                              |
| 6.1–6.4                                 | Phase 6 scoped collections/navigation; Step 8.3 retains the distinct standard-tier discrepancy from current `phase4`.                 |
| 6.5 and earlier Flex explorer additions | Step 10.2 retains the independent layout-experiment requirements without a parent app.                                                |
| 7.1–7.3                                 | Phases 5–6 implemented controls/collections; style and catalog residue moves to Steps 8.4 and 9.1.                                    |
| 7.4                                     | Dedicated app/inspector delivery removed; immutable diagnostics and direct integration evidence remain.                               |
| 7.5                                     | Phase 9: final contract/fixture graduation is not inferred from a successful DocC build.                                              |
| 8                                       | Phase 7 delivered host evidence; Steps 10.3 and 11 retain reproducibility and platform/final-closure gaps.                            |

## Enduring contracts

- For future capabilities, use the catalog ladder
  `sketch → wireframed → specified → ready` and establish an accepted public shape,
  ownership, geometry, interactions, and acceptance scenarios before coding. Do not invent
  a second contract. The review-loop readiness adjustment permits a bounded capability
  with explicit deferred residue; it does not certify an incomplete whole component or let
  unrelated catalog work block it.
- `View`, nodes, and `ViewGraph` remain non-`Sendable`. The app owns business values and
  bindings; `NodeState` owns only documented ephemeral interaction state. No shadow text
  value, automatic observation, private widget store, or second focus authority is added.
- `TerminalSession` owns lifecycle, effective terminal modes, and presentation. Views
  report declarative requirements and render only through borrowed `Frame`/`RenderRegion`
  capabilities. View targets cannot import IO, platform UI frameworks, or raw authority.
- Reconciliation preserves the existing equatable/type/structural/keyed identity rules.
  Composite bodies evaluate during explicit updates. Diagnostics observe the most recent
  completed pass and cannot trigger update, layout, render, or presentation.
- Production diagnostics remain immutable and local, without persistence, logging,
  telemetry, reflection, network listeners, or remote control. Explicit developer/test
  capture may export a versioned, sanitized local projection to a caller-selected path.
  Never serialize closures, borrowed capabilities, NodeState, raw handles, or controlled
  values in graph diagnostics. Synthetic app-state checkpoints and opt-in protocol traces
  are separately permissioned capture data, not production diagnostics.
- Real application images, labels, state checkpoints, and scripts require explicit
  permission and redaction. Repository fixtures remain synthetic; raw traces are not
  ambient attachments. Observation grants no input-injection authority.
- Geometry uses nonnegative integer cells, shared Flex negotiation, per-pass measurement
  caching, clipping, and the existing grapheme-width machinery. Zero/one-cell and extreme
  proposals must not trap. No duplicate allocator or width implementation is introduced.
- Styles remain complete `Style` values with per-attribute inheritance. Focus appearance
  is presentation, not ownership. Requested mouse modes remain distinct from effective
  session modes and restore the host baseline on teardown.
- Prefer snapshots for inspectable structured state and direct assertions for scalar
  behavior. Tests must be deterministic and defend consumer-visible contracts; live
  terminal timing does not belong in unit tests. Use actual rendered output for visual
  review; a passing snapshot is not human design approval.
- Durable source comments describe behavior, not phase numbers or temporary status. Public
  prior-art citations use pinned source permalinks checked against local sources. Broad
  gestures, IME pre-edit, animation, image views, and the full Phase 5 application runtime
  remain outside this view-layer plan.

## Phase 0 — Core ownership and deterministic rendering

**Goal**: Preserve the completed substrate, not recreate early scaffolds.

### Step 0.1 — Establish package boundaries and the value/graph model

- Delivered: `Package.swift`, `Sources/TesseraCore/Views/`, explicit `Binding`, structural
  builders, keyed identity, and leaf APIs; thin public re-exports and architecture gates.
- Evidence: existing Core tests, `Tests/TesseraArchitectureTests/`, and
  `scripts/check-package-boundaries.py`. The terminal/frame seam does not grant views IO.

### Step 0.2 — Implement reconciliation, environments, diagnostics, and borrowed rendering

- Delivered: `Sources/TesseraCore/{Runtime,Environment,Diagnostics,Rendering}/`.
  Reconciliation, environment propagation, dirty flags, statistics, clipped translated
  rendering, and cursor requests use the real frame seam.
- Preserve `ViewGraph.render(into:)`'s borrowing-compatible ownership and synchronous
  region lending. Identity, replacement, lifecycle, and diagnostics tests remain evidence.

### Step 0.3 — Establish deterministic graph and terminal test support

- Delivered: `Sources/TesseraTestSupport/` and terminal snapshot support connect graph
  output to buffers and a persistent virtual terminal, without IO imports in view targets.
- Use public test seams and explicit finite input/resize scripts. Example tests remain in
  `Examples/Tests`; root package tests must not depend on the Examples package.

## Phase 1 — Geometry and visual primitives

**Goal**: Retain the completed layout/style behavior while keeping final design approval
separate.

### Step 1.1 — Implement stacks, modifiers, clipping, and shared Flex allocation

- Delivered: `Sources/TesseraLayout/` stacks, frames, padding, layout priority, ZStack,
  and shared Flex constraints. Exact layout/solver tests cover minima, maxima, priorities,
  integer remainders, clipping, and degenerate proposals.
- The current `phase4` completion of geometry and Flex is retained. App-specific
  23/48/73-column policy is not a universal component contract.

### Step 1.2 — Implement wrapping, style inheritance, decoration, and ScrollIndicator

- Delivered: Text wrapping/truncation, inherited styles, borders, Box, overlay/background,
  Divider styling, and shared output-only indicator geometry.
- Evidence: layout style/wrapping/decoration tests and the original completed Phase 3
  history. Width/measurement agreement covers Unicode and clipped geometry.
- This checkbox does not claim all custom style semantics, catalog labels, or visual
  references are finalized; Steps 8.4 and 9.1 retain that work.

## Phase 2 — Direct review loop

**Goal**: Make real behavior runnable and reviewable without an application shell.

### Step 2.1 — Share the live and headless application driver

- Delivered: `Examples/Sources/SpecimenSupport/ApplicationDriver.swift`, registry/models,
  and `Examples/Sources/TesseraLab/`. Live runs use actual terminal size; headless runs
  inject explicit size. Both drive the same app-owned root and update/layout/render path.
- The narrow caller/session-isolated driver is not the full Phase 5 runtime. Plain
  settings ownership and reducer-style record ownership require no observation dependency.

### Step 2.2 — Capture actual output with explicit export permission and provenance

- Delivered: `Examples/Sources/{SpecimenCaptureSupport,TesseraCapture}/` and
  `scripts/capture-specimen.sh`. Captures include checkpoints, text, input, diagnostics,
  SVG, and manifests through real rendering/encoding and persistent terminal projection.
- Unicode cell export uses canonical cell widths. Browser font rasterization is not the
  canonical oracle; exact cells are. Unsupported claims and cursor-overlay limitations
  remain explicit. Provenance distinguishes revision, dirty state, dimensions, and
  profile.

## Phase 3 — Focus, appearance, and one operable Button

**Goal**: Preserve the newer `phase4` focus work as well as review-loop input integration.

### Step 3.1 — Implement focus routing and environment-derived control focus

- Delivered: `Sources/TesseraCore/Input/`, `Runtime/ViewGraph.swift`, and live focus
  environment propagation. `FocusManager` is the single authority; control initializers do
  not duplicate identity and focused bindings. `.focusable`/`.focused` retain explicit
  ownership while rendering reads the runtime-provided focused state.
- Preserve leaf/wrapper/ancestor bubbling, document-order traversal, disabled/removal
  cleanup, first-placement focus eligibility, and invalidation of old/new focused
  subtrees.
- Evidence: focus routing, requirements, ownership, and lifecycle regressions in Core.

### Step 3.2 — Implement delegated focus appearance

- Delivered: `Input/FocusAppearance.swift`, graph/runtime host resolution, layout
  decoration, and control responders. This retains original steps 4.5 and 4.6, not just
  the earlier focus-routing checkbox.
- Resolve outward from the focused node: `handled` chooses one host, `deferred` continues,
  and `suppressed` stops. Controls have first refusal. Re-resolve for focus, hierarchy,
  policy, replacement, and removal; invalidate old/new hosts without changing identity.
- Box repaints existing border/title cells without owning focus, taking child events,
  tinting content, or adding a second border. ScrollView delegates or falls back to a
  clipped one-cell ring without changing measurement; indicators remain overflow-only.
- Preserve the established distinction between border-focus glyph styling and full
  borderless-control focus styling. Evidence includes focus appearance tests and the
  TextField regression keeping its label above a single editor border.

### Step 3.3 — Complete Button key/pointer activation and cancellation

- Delivered: controlled Button actions, provenance-aware key phases, clipped hit testing,
  click-to-focus, capture, same-node release, and cancellation on outside/blur/disable/
  removal. The public pointer modifier is `onPointer`; no compatibility `onMouse` alias or
  public hit-test query is required merely to match an old proposed filename.
- Evidence: Core pointer tests, Button tests, and held/cancellation replay checkpoints.

## Phase 4 — Interactive viewports and pointer lifecycle

**Goal**: Complete scrolling and motion independently of future text selection.

### Step 4.1 — Complete ScrollView offsets, reveal, indicators, and boundary bubbling

- Delivered: `Sources/TesseraWidgets/ScrollView.swift`, controlled offsets and clamps,
  clipped translation, focus reveal, wheel/track/thumb input, and keyboard movement.
- Unconsumed boundary input bubbles to eligible ancestors. Final replay at both sizes
  reaches inner offset `0,6`, then moves the outer viewport to `0,1`.
- Preserve focus identity across fitting/overflow content and indicator appearance
  changes.

### Step 4.2 — Complete hover, motion requirements, and pointer lifecycle coverage

- Delivered: `onHover`, pointer motion requirements, clipped/topmost routing, capture
  lifecycle, and session mode aggregation/restoration. Hover clears on terminal focus
  loss.
- Evidence: enter, blur, reenter, leave checkpoints and dynamic requirement tests. Mouse
  protocol replay is not physical-mouse validation on untested operating systems.

## Phase 5 — Controlled editing and settings

**Goal**: Complete single-line input before making navigation depend on it.

### Step 5.1 — Complete single-line TextField editing and hardware cursor behavior

- Delivered: TextField and its editor implementation, binding edits, grapheme-safe caret
  and local selection, word movement/deletion, paste/text commits, submit, click-to-caret,
  horizontal reveal, external-value clamping, and hardware cursor forwarding.
- Node state contains interaction state, not a second business text value. The focused
  editor receives printable q instead of the application's quit action. Bracketed-paste
  requirements preserve the session baseline.
- Local field selection is not cross-view selection. Semantic commit tests do not prove
  host software-keyboard UI, real dictation, IME pre-edit, or secure-entry masking.

### Step 5.2 — Integrate Toggle, Stepper, and Picker in a settings editor

- Delivered: controlled values/actions, disabled and boundary behavior, keyboard/pointer
  paths, and `SettingsSpecimen.swift`. The app owns text, toggle, numeric, and choice
  state.
- Evidence: widget tests and actual settings replay/PTY paste yielding `Grace` and one
  submission. Built-in appearances remain provisional; custom contracts stay in Step 8.4.

## Phase 6 — Collections and pane composition

**Goal**: Compose existing geometry and input without a second allocator or state store.

### Step 6.1 — Implement Section, List, Grid, and Table

- Delivered: `Sources/TesseraLayout/Grid.swift` and Widgets List/Section/Table. Grid uses
  shared Flex columns and row heights; Table uses shared constraints/indicators and
  controlled selection/sort intent. List preserves keyed identity and controlled
  selection.
- Section reserves header/spacing before proposing content height and clamps arithmetic.
  The captured multiline List/Grid overlap has a regression and before/after evidence.
- Exact source tests remain authoritative; interactive layout tooling is separate.

### Step 6.2 — Complete negotiated SplitView and adjacent-pair resizing

- Delivered: one min/ideal/max/priority negotiation path through Flex, stable pane IDs,
  collapse/restoration, clipped frames, keyboard resize, and captured divider dragging.
- Preserve adjacent-pair identity, bounded binding writes, replacement/cancellation, both
  axes, and non-writing reconciliation. Do not restore an obsolete static allocator.

### Step 6.3 — Implement scoped regular/compact navigation and record browsing

- Delivered: controlled semantic roles through SplitView in regular composition and
  supplied-role replacement in compact composition, with visibility and focus handling.
  Record browser selection/reduction and retained pane sizing stay app-owned.
- Evidence: navigation/pane tests and actual record replay selecting ID 2 and retaining
  requested pane ideals `36,40` after drag/release.
- This is not a completion claim for the older distinct standard tier or its revised
  chrome-free policy. Step 8.3 reconciles that contract difference explicitly.

## Phase 7 — Delivered host evidence

**Goal**: Preserve measured evidence without implying full platform or design graduation.

### Step 7.1 — Exercise eight live specimens and deterministic replay

- Delivered IDs: `layout`, `button`, `viewport`, `settings`, `collections`, `panes`,
  `navigation`, `records`. All eight PTY runs exited cleanly.
- Final implementation captures contain 232 checkpoints in 16 manifests, starting at 40x16
  and 80x24, with clean revision provenance. Two full bundle runs were byte-identical.
  Selected real SVGs were inspected; approval remains provisional.
- Run: `swift run --package-path Examples TesseraLab run <id>` and
  `scripts/capture-specimen.sh <id> <output-directory>`.

### Step 7.2 — Record host quality, architecture, and performance results

- Recorded after the final source edit: 786 root tests, 37 Examples tests, formatting,
  lint, architecture, DocC, and Markdown checks passed. These are historical results for
  `5a22022`, not a substitute for testing subsequent implementation changes.
- A temporary release harness measured 200 keyed leaves plus root at 200x50, seven samples
  each. Median wall times: initial 2.577 ms, forced unchanged presentation 1.330 ms,
  visible one-leaf update 1.357 ms, resize 1.870 ms. Counters were stable.
- Raw results and methodology are in `phase4-review-loop/artifacts/p48-performance*.json`.
  The forced unchanged draw emitted ten control bytes; it was not an idle-driver test. No
  permanent benchmark target was added; Step 10.3 retains that original requirement.

## Phase 8 — Remaining selection and contract work

**Goal**: Retain undelivered framework requirements instead of hiding them behind checked
mouse/control steps. Establish each relevant contract before implementing its dependent
capability. Steps 8.1–8.2 are sequential; 8.3 and 8.4 can be resolved independently.

### Step 8.1 — Specify application-owned cross-view selection and copy

- Files: `design/primitives/text-selection.md`, relevant Text/viewport/collection
  catalogs, and `docs/Spec.md`. Promote the selection sketch through explicit readiness
  review.
- Define controlled semantic endpoints, scope identity, cross-fragment/container bounds,
  pointer capture, cell-to-grapheme mapping, wrapped/truncated/wide text, clipping,
  scrolling, highlights, terminal-native coexistence, and clipboard policy.
- Acceptance: exact adjacent-column, scrolled, wrapped, combining/ZWJ, wide-cell,
  drag-boundary, removal, and denied-copy contracts. Decide shared TextField primitives
  deliberately; neither terminal-native selection nor `onPointer` substitutes for this.

### Step 8.2 — Implement and verify semantic selection and policy-gated copy

- Depends on 8.1. Files: a new Core selection implementation under `Input/`, graph/Text/
  rendering seams selected by the approved contract, and focused Core/Layout tests.
- Keep Text immutable and pointer-free. Resolve coordinates from completed frames/clips
  into app-owned semantic ranges; scope policy determines extension across siblings,
  overlays, columns, and viewports. Highlights must not change intrinsic layout.
- Copy only selected semantic text through the existing policy-gated terminal operation.
  Denial/unavailability must not invalidate the range or select unrelated terminal text.
- Acceptance: deterministic scripts across SplitView/Grid/Table-style adjacent columns,
  scrolling/wrapping/replacement/capture cancellation, and exact copy output excluding
  neighboring columns. Selected text must not enter diagnostics or telemetry. Add a
  directly runnable selection specimen and inspect actual rendered checkpoints.

### Step 8.3 — Reconcile the retained navigation tier and chrome requirements

- Files: `design/widgets/navigation-split-view.md`, `docs/Spec.md`,
  `Sources/TesseraWidgets/NavigationSplitView.swift`, its tests and navigation specimen.
- Current `phase4` added regular/standard/compact tiers: standard retains center plus
  mutually exclusive side columns; compact replaces the whole composition. Its later
  contract makes the container chrome-free and visibility controls app-owned. The
  review-loop contract instead describes regular/compact composition with container
  controls. These are materially different contracts, not equivalent spelling.
- Acceptance: choose and document one contract with maintainer approval. If retaining the
  original tiers, implement missing behavior and fixtures; if retiring them, record that
  scope decision explicitly. Test supplied/missing roles, short height, focus return,
  replacement, and binding preservation. Do not import old app breakpoints as defaults.

### Step 8.4 — Resolve deferred style contracts and capability coverage

- Files: `design/tokens.md`, relevant style/decoration/control catalogs, current style
  implementations, and their existing tests/fixtures.
- Reconcile implemented defaults with unresolved system/custom semantic roles, background
  inheritance, control customization, and known light/dark, NO_COLOR, and ASCII behavior.
  Keep a single complete-Style model and existing focus-border/content distinction.
- Acceptance: accepted behavior is documented and exercised under representative profiles;
  genuine deferrals are named rather than whole components relabeled complete. No second
  style system or exhaustive cross-product fixture burden is introduced.

## Phase 9 — Catalog graduation and human approval

**Goal**: Distinguish documentation builds from completed contracts and accepted visuals.

### Step 9.1 — Reconcile catalog status, DocC contracts, and fixtures

- Files: `design/README.md`, component catalogs, view-layer DocC bundles, `docs/Spec.md`,
  `docs/ProjectStatus.md`, and focused fixtures. Depends on accepted Phase 8 decisions.
- Some documents still carry sketch/wireframed statuses despite implemented source; public
  documentation additions and a clean DocC build do not prove whole-catalog graduation.
- Acceptance: audit each accepted component against actual source/tests; resolve open
  questions or state deferrals; put enduring contracts in the owning module's DocC; retain
  anatomy as linked fixtures; remove duplicate/stale contracts and fix index links.
  Preserve pinned public prior-art citations verified against local sources.

### Step 9.2 — Review public APIs and approve visual references

- Depends on 9.1. Review the direct specimens and per-specimen API-friction notes, not an
  additional application shell. Inspect actual representative-size/profile images and
  focus/press/disabled/selection transitions, including narrow and minimum geometry.
- Acceptance: maintainer API/style decisions and baseline approval are explicit. Candidate
  artifacts remain distinct from approved baselines. Do not infer approval from test
  success, elapsed time, or a numerical self-rating.

## Phase 10 — Retained developer-tooling proposals

**Goal**: Expose original `phase4` work not delivered by the current specimen registry.
These are scope decisions before new tooling work, not prerequisites for already completed
components. Explicit retirement can close a proposal; silent omission cannot.

### Step 10.1 — Decide the remaining interactive gallery scope

- Inputs: `.agents/plans/032-view-layer-gallery.md` on current `phase4`, including its
  preserved dirty draft, and the existing TesseraLab/SpecimenSupport APIs.
- Original step 4.7 remained unchecked and requested a runner, core inspectors, layout/
  style playgrounds, and focus tooling. Eight direct specimens do not prove that whole
  proposal complete. Treat the original draft as a read-only design input, not code to
  bulk-import or a prerequisite to mouse support.
- Acceptance: retain a bounded standalone gallery increment or explicitly retire it in
  favor of the registry. Any retained implementation must use public APIs, avoid a second
  widget library, and prove direct launch/replay before becoming an advertised command.

### Step 10.2 — Deliver or explicitly retire the standalone Flex/Grid explorer proposal

The original plan records the earlier embedded Flex experiment as completed; this open
step concerns its standalone replacement and the unfinished Grid mode, not undoing that
history or requiring the old experiment to be rebuilt from scratch.

- Depends on 10.1's tooling decision; existing Flex/Grid and controls are available. Files
  if retained: new Examples-local specimen/model and tests using public layout APIs.
- Preserve the original useful experiments without their former surrounding application:
  stable draft IDs `a`–`f`, editable constraint/priority inputs, validation,
  empty/invalid/ reset states, a scrollable fixed canvas, and keyboard/pointer parity via
  public controls. The original 68-cell fixture allocates `[8,6,7,9,14,19]` at starts
  `[0,9,16,24,34,49]`.
- Grid mode stays a real public Grid consumer; exact Flex/Grid frame tests remain the
  solver oracle. No tile dragging, direct allocation manipulation, private solver API, or
  pointer-only operation is implied. Retain app draft state across resize/replacement.
- Acceptance: if retained, inspect 80x24, 40x16, and useful wider/one-cell-boundary cases
  with rendered output and independent expected geometry; otherwise record retirement.
  Former application-specific role thresholds are not inherited as framework policy.

### Step 10.3 — Make the performance experiment reproducible

- Files: `Benchmarks/TesseraViewLayerBenchmark/main.swift`, `Package.swift` if an explicit
  benchmark target is retained, or an approved developer-tool location; generated local
  benchmark evidence. The prior temporary harness was removed after measurement.
- Preserve the original requirement for rerunnable evidence: fixed 200-node/200x50
  workload definition, warm-up/sample counts, release configuration, machine/toolchain,
  median/p95 update/layout/render timing and graph counters. Distinguish forced rendering
  from idle-driver work and make the changed leaf visible.
- Acceptance: one documented command recreates reviewable evidence. Agree the target/tool
  location before adding dependencies. The current median/min/max artifact is useful
  evidence, but not completion of the original dedicated harness/p95 requirement. Do not
  optimize full passes unless measurements demonstrate a budget problem.

## Phase 11 — Platform verification and final closure

**Goal**: Close actual environmental and acceptance gaps without claiming host parity.
Steps 11.1–11.2 can proceed independently of design review when prerequisites are
available; 11.3 depends on all retained requirements and explicit disposition of optional
tooling.

### Step 11.1 — Run Linux compilation with a matching toolchain

- Current evidence: `just linux build` failed because Swift 6.3.3 cannot import the
  installed Swift 6.3.2 SDK modules. No matching compiler was found locally.
- Acceptance: with authorized matching compiler/SDK provisioning, rerun the repository
  Linux build and record exact versions/result. Do not patch production code to bypass
  compiler incompatibility or describe the failed build as merely unrun.

### Step 11.2 — Exercise Linux and Windows runtime paths

- Files/tools: existing `justfiles/linux.just`, Windows recipes/scripts, and direct
  specimens. Current Linux VM is stopped; usable Windows/Frost tooling was unavailable.
  This plan prohibits VM bootstrap or tool installation without separate authorization.
- Acceptance: exercise relevant live launch, terminal sizing/resize, key/paste/mouse
  input, requirements restoration, cancellation, and exit paths on supported environments.
  Distinguish Windows build/test coverage from direct Ghostty-backed capture support.
  Missing host dictation/UI harnesses remain explicit, not simulated claims of host UI.

### Step 11.3 — Rerun final gates and reconcile the definition of done

- After all approved retained implementation and smoke work: run focused checks first,
  then `just quality format`, complete `swift test`, and `just quality lint` in order;
  also run Examples tests, architecture and DocC checks, and changed Markdown validation.
- Refresh changed specimen captures with accurate provenance, inspect actual images, and
  keep artifacts separate from approved baselines. Recheck permission/redaction and
  source-worktree preservation; update spec/status/changelog for actual delivered changes.
- Acceptance: every retained requirement is implemented and verified or explicitly removed
  by an approved scope decision; platform skips are not green gates; human approval is
  recorded. Update this authoritative plan to reflect completion and preserve the evidence
  trail; do not rewrite historical implementation commits.

## References

- [Archived execution plan](phase4-review-loop/PLAN.md)
- [Archived execution brief](phase4-review-loop/START-HERE.md)
- [Implementation ledger](phase4-review-loop/STATE.md)
- [Review evidence](phase4-review-loop/REVIEW.md)
- `docs/Spec.md` and `docs/ProjectStatus.md`
- `design/README.md`, `design/tokens.md`, `design/primitives/text-selection.md`
- `design/widgets/navigation-split-view.md`
- `Package.swift`, `Examples/Package.swift`, `justfiles/quality.just`
