---
name: Phase 4 View Layer and Tessera Showcase
description:
  Implement the seven-slice Tessera view layer with design-catalog readiness gates and a
  progressively executable Showcase integration app.
status: pending
created: 2026-07-17
updated: 2026-07-17
---

<!-- Allowed status values: planning, in-review, pending, in-progress, complete. -->

## Progress

- [x] **Phase 0 — Contract, package graph, and design-catalog readiness**
  - [x] 0.1 Freeze the cross-slice contracts and dependency direction
  - [x] 0.2 Promote the first-slice catalog prerequisites to `ready`
  - [x] 0.3 Establish the deterministic test and Showcase fixture harness
- [ ] **Phase 1 — Slice 1: TesseraCore, ViewGraph, reconciliation, and Text**
  - [ ] 1.1 Replace the `View` placeholder with the core value/graph model
  - [ ] 1.2 Implement reconciliation, environments, diagnostics, and render regions
  - [ ] 1.3 Build the first executable Showcase scaffold
  - [ ] 1.4 Verify identity, ownership, and terminal rendering contracts
- [ ] **Phase 2 — Slice 2: Layout, stacks, static SplitView, and ScrollView**
  - [ ] 2.1 Promote layout and viewport catalog documents before coding
  - [ ] 2.2 Add the layout target and deterministic stack algorithm
  - [ ] 2.3 Add static SplitView and ScrollView foundations
  - [ ] 2.4 Replace the Showcase vertical scaffold with real layout composition
- [ ] **Phase 3 — Slice 3: Styling, wrapping, decoration, and ScrollIndicator**
  - [ ] 3.1 Complete style/token and decoration catalog contracts
  - [ ] 3.2 Implement one-style environment inheritance and text measurement
  - [ ] 3.3 Implement borders, Box, overlay/background, Divider styling, and indicators
  - [ ] 3.4 Add styled, Unicode, and degenerate-geometry Showcase fixtures
- [ ] **Phase 4 — Slice 4: Focus, key routing, and controlled responders**
  - [ ] 4.1 Promote control and focus catalog documents to `ready`
  - [ ] 4.2 Implement FocusManager, responder routing, and requirements aggregation
  - [ ] 4.3 Land controlled Button, Toggle, Picker, Stepper, TextField focus, and keyboard
        viewport behavior
  - [ ] 4.4 Add visible-control and keyboard Showcase scenarios
- [ ] **Phase 5 — Slice 5: Mouse and hit testing**
  - [ ] 5.1 Complete pointer, hit-testing, and boundary-bubbling catalog contracts
  - [ ] 5.2 Implement deepest-first hit testing and mouse responder APIs
  - [ ] 5.3 Add pointer behavior to controls, TextField, SplitView, and ScrollView
  - [ ] 5.4 Add deterministic pointer and tracking-mode Showcase scenarios
- [ ] **Phase 6 — Slice 6: Flex, Grid, Table, final SplitView, and NavigationSplitView**
  - [ ] 6.1 Wireframe and specify Flex/Grid plus final navigation contracts
  - [ ] 6.2 Implement the shared Flex solver and Grid
  - [ ] 6.3 Replace static SplitView geometry and add Table indicator parity
  - [ ] 6.4 Implement regular/compact NavigationSplitView and update Showcase breakpoints
- [ ] **Phase 7 — Slice 7: List, Section, controlled cutover, and complete Showcase**
  - [ ] 7.1 Promote List, Section, tokens, and all remaining component documents to
        `ready`
  - [ ] 7.2 Implement List/Section catalog composition and final styles
  - [ ] 7.3 Complete controlled TextField editing and hardware cursor behavior
  - [ ] 7.4 Finish the Showcase and immutable diagnostics Inspector
  - [ ] 7.5 Delete every temporary scaffold and complete catalog graduation
- [ ] **Phase 8 — Phase 4 closure and quality evidence**
  - [ ] 8.1 Run the complete Phase 4 contract and architecture test matrix
  - [ ] 8.2 Produce performance and cross-platform evidence
  - [ ] 8.3 Run the repository quality gate and review the Phase 4 definition of done

## Overview

Implement Phase 4 as the seven dependency-ordered slices in `docs/Spec.md`, starting from
an explicit, inspectable `ViewGraph` and ending with all accepted 1.0 components composed
in the runnable Tessera Showcase described by `design/showcase.md`. Before each slice that
consumes a catalog component, promote its design document through the catalog ladder
(`sketch` → `wireframed` → `specified` → `ready`); do not implement against a sketch or
silently invent a second component contract. The Showcase is an integration specimen that
lands incrementally with each slice, and its temporary scaffold is deleted at each cutover
rather than becoming a parallel API.

The current repository has a real terminal substrate but only a placeholder
`Sources/TesseraCore/View.swift`, a placeholder core test, and no Phase 4 layout/widget
targets. The plan therefore includes SwiftPM graph work, architecture-boundary tests,
negative ownership tests, deterministic buffer/virtual-terminal tests, design-document
promotion, DocC graduation, and the final repository quality gate. Phase 5 runtime,
animation, and future image views are explicitly out of scope.

## Phase 0 — Contract, package graph, and design-catalog readiness

**Goal**: Resolve the cross-slice seams before implementation, establish the target graph
and deterministic proof strategy, and make the first implementation slice eligible under
the design-catalog process.

### Step 0.1 — Freeze the cross-slice contracts and dependency direction

- Files: `Package.swift`, `Sources/TesseraTerminal/Frame.swift`,
  `Sources/TesseraTerminal/TesseraTerminal.swift`, `docs/Spec.md` (Phase 4 proposed module
  layout), the future `Sources/TesseraCore/*`, `Sources/TesseraLayout/*`, and
  `Sources/TesseraWidgets/*` target declarations,
  `Tests/TesseraArchitectureTests/ImportBoundaryTests.swift`, new
  `scripts/check-package-boundaries.py`, new `scripts/test_check_package_boundaries.py`,
  and `justfiles/quality.just`.
- Preserve the existing terminal ownership boundary: `TerminalSession` owns mode
  lifecycle, terminal requirements, and presentation; views only render through a borrowed
  `Frame`/`RenderRegion` and report declarative `TerminalRequirements`.
- Add the Phase 4 targets and dependency edges without allowing a view target to depend on
  `TesseraTerminalIO`, platform shims, SwiftUI, AppKit, or UIKit. Decide and document the
  narrow seam by which `TesseraCore` can use `Frame`, `Buffer`, `InputEvent`, and `Style`
  without importing the terminal IO implementation. Keep `Tessera` and `TesseraTerminal`
  as thin public re-export surfaces.
- Resolve the proposed-layout inconsistency: the spec places `ScrollView` and text input
  in `TesseraWidgets` but describes `TesseraWidgets` as Slice 7-only, while ScrollView and
  controlled responders land in Slices 2 and 4. Start the target when the first widget
  lands (Slice 2), keep `ScrollView`/controls there, and update the proposed layout
  comments if necessary; do not create parallel temporary widget targets.
- Define, before implementation, the immutable diagnostics schema used by `graph.dump()`,
  `GraphStatistics`, and the Showcase Inspector. It must include identity/type,
  parent/child order, proposal, measured size, frame, clip, environment override names,
  handler kinds, requested/effective terminal requirements, and reconciliation counters;
  it must exclude controlled values and raw values and have no serialization, persistence,
  logging, telemetry, or remote transport.
- Define the one-style model before Slice 3: semantic roles are complete `Style` values,
  system/custom styles are environment-resolved, and there is no second view-layer style
  type or color-only alias. Define controlled initializer/action signatures from the
  catalog contracts, preserving app-owned `Binding` and keeping widget `NodeState`
  ephemeral only.
- Add both executable architecture gates required by the spec. The Swift Testing import
  test scans the declared view-layer source roots and reports every forbidden import with
  its file and line. The separately unit-tested package-boundary script parses
  `swift package describe --type json`, rejects forbidden dependency edges, and is wired
  into `just quality lint`; do not invoke SwiftPM recursively from `swift test`.
- Acceptance: `swift package describe --type json` shows the intended acyclic graph; a
  short Swift 6 compile probe validates parameter-pack iteration, `~Copyable`/
  `~Escapable` region lending, and existential opening. If parameter packs or lifetimes
  fail on the toolchain, choose the documented fixed-arity/generic fallback before Slice 1
  and record the decision in the plan/spec rather than weakening ownership.

### Step 0.2 — Promote the first-slice catalog prerequisites to `ready`

- Files: `design/README.md`, `design/tokens.md`, `design/primitives/text.md`,
  `design/primitives/frame.md`, `design/primitives/stacks.md`,
  `design/primitives/padding.md`, `design/primitives/z-stack.md`, and any required catalog
  DocC links.
- Apply the design-catalog gates exactly: all anatomy wireframes use `wireframe WxH`, all
  widgets eventually include canonical `mobile` and `min` states, interaction/state/
  sizing tables use the closed schemas, requirements are backticked sentence-style Swift
  Testing names traced to a table or wireframe, and prior art cites local Ratatui paths.
- Promote `Text` and the geometry primitives needed by Slice 1/2 from `specified` to
  `ready` after resolving their listed open questions. `stacks`, `Frame`, `Padding`, and
  `ZStack` are already specified but still require the dependency/readiness review.
- Do not mark a component `ready` merely because it has a wireframe. A component is
  implementation-eligible only when primitive dependencies are `ready`/`implemented` and
  its open questions are resolved or explicitly recorded in `docs/Spec.md` or an issue.
- Correct `design/README.md`'s stale Validation commands to name the repository-local
  pinned gates. Acceptance: `just quality wireframes` and `npm run check:markup` pass for
  the catalog changes, and the README index accurately reports every promotion.

### Step 0.3 — Establish the deterministic test and Showcase fixture harness

- Files: `Package.swift`, `Tests/TesseraCoreTests/`, new `Tests/TesseraLayoutTests/`, new
  `Tests/TesseraWidgetsTests/`, `Sources/TesseraTerminalSnapshotSupport/` only if a small
  reusable helper is missing, `Examples/Package.swift`, and new
  `Examples/Sources/TesseraShowcase/`.
- Reuse `VirtualTerminal`, `ScreenSnapshot`, `RenderedCell`, and the existing terminal
  test support rather than exposing Ghostty types through the view API. Keep graph/widget
  tests synchronous and deterministic: constructed trees, explicit key/mouse/paste/ resize
  scripts, buffer snapshots, and diagnostics snapshots; no sleeps, `Task.yield()`, or live
  terminal dependence.
- Define fixture metadata for every Showcase wireframe dimension: `120x24`, `80x24`,
  `80x16`, `40x16`, and the below-`40x12` resize guard. Store model state and scripted
  input separately from snapshot expectations so the same app model can be exercised at
  regular, compact, and guard sizes.
- Acceptance: a test can instantiate a fixture at each declared size, dispatch a finite
  script, render into a real `Frame`/buffer, and compare a `VirtualTerminal` snapshot; no
  view-layer target imports terminal IO.

## Phase 1 — Slice 1: TesseraCore, ViewGraph, reconciliation, and Text

**Goal**: Replace the placeholder with a declarative, non-`Sendable`, explicitly
reconcilable graph that renders Text through the real frame seam and exposes immutable
local diagnostics.

### Step 1.1 — Replace the `View` placeholder with the core value/graph model

- Files: `Sources/TesseraCore/View.swift`, `ViewBuilder.swift`, `ForEach.swift`,
  `LeafView.swift`, `Binding.swift`, `Text.swift`, and `Environment.swift`.
- Implement `View`, `ViewBuilder`, `TupleView`, `ConditionalView`, `Optional`,
  `EmptyView`, `ForEach`, `AnyView`, `EquatableView`, `ProposedSize`, and
  `EventDisposition` with the public shapes in `docs/Spec.md`. Keep composites pure and
  app-state-owned; do not add `@State` or make views `Sendable`.
- Implement `LeafView` defaults and `Text` as a grapheme-width-aware leaf using the Phase
  2 width tables. Slice 1 Text truncates at its region edge; wrapping and fluent styling
  wait for Slice 3.
- Acceptance: the public symbols compile under Swift 6; a custom third-party-style leaf
  can implement only its documented required methods; Text measures and renders the same
  simple single-line content.

### Step 1.2 — Implement reconciliation, environments, diagnostics, and render regions

- Files: `Sources/TesseraCore/RuntimeNode.swift`, `NodeIdentity.swift`, `ViewGraph.swift`,
  `RenderRegion.swift`, `Environment.swift`, plus
  `Tests/TesseraCoreTests/ ReconciliationTests.swift`, `NodeStateLifetimeTests.swift`,
  `EnvironmentTests.swift`, `DiagnosticsTests.swift`, and `ImportBoundaryTests.swift`.
- Implement the six normative reconciliation rules: equatable fast path, dynamic-type
  replacement, leaf update, structural slot diff, keyed `ForEach` identity preservation,
  and composite body evaluation exactly during update. `AnyView` is an explicit identity
  barrier. `ViewGraph.update`, `layoutIfNeeded`, `render`, `resize`, `dump`, statistics,
  and dirty flags remain synchronous and observable.
- Implement borrowed, clipped, translated `RenderRegion` with `write`, `setCell`, `fill`,
  `with`, `raw`, and cursor-request support. Out-of-bounds writes clip silently; region
  capabilities cannot be copied, stored, escaped, or used to reach session authority.
- Implement environment copy-on-write values and modifier propagation without adding
  property-wrapper sugar before the explicit mechanism is proven.
- Acceptance: golden graph dumps and statistics prove create/destroy/update/body-count,
  tuple and keyed reorder behavior, branch/type/`.id` replacement, equatable skips,
  NodeState lifetime, environment invalidation, clipped/wide-grapheme rendering, and no
  hidden terminal imports. Add negative tests proving a view cannot import IO or mutate
  terminal modes and lifecycle tests proving a borrowed region cannot escape its
  synchronous render closure.

### Step 1.3 — Build the first executable Showcase scaffold

- Files: `Examples/Package.swift`, `Examples/Sources/TesseraShowcase/`, and
  `Examples/Tests/TesseraShowcaseTests/` (or the existing example-test convention).
- Add a `TesseraShowcase` executable that uses a plain model object and the canonical
  immediate-mode loop. At this slice it may use only `Text` and the explicitly temporary
  no-layout vertical stacking rule to show a title, selected specimen, and diagnostic
  placeholder. It must not introduce fake widget APIs or app-owned behavior into core.
- Keep a `ShowcaseModel` responsible for catalog selection, viewport/role selection,
  control values, and visibility; later widgets retain only documented ephemeral state.
- Acceptance: the executable renders through a real `TerminalSession` on supported
  platforms, and a deterministic fixture renders the Slice 1 temporary composition. The
  next slice must delete this scaffold rather than extend it indefinitely.

### Step 1.4 — Verify identity, ownership, and terminal rendering contracts

- Files: `Tests/TesseraCoreTests/*`, `Tests/TesseraArchitectureTests/*`,
  `Tests/TesseraTerminalRenderingTests/*` only for integration seams, and the package
  boundary checker wired into `just quality lint` by Step 0.1.
- Verify `ViewGraph` → `Frame`/`Buffer` → `VirtualTerminal` output, paint order, clipping,
  wide-grapheme boundary behavior, dump immutability, and explicit requested-versus-
  effective terminal requirements representation (requirements become populated in Slice
  4, but the snapshot seam must not conflate the two).
- Acceptance: focused `swift test --filter TesseraCoreTests` and the example smoke
  scenario pass before Slice 2 begins.

## Phase 2 — Slice 2: Layout, stacks, static SplitView, and ScrollView

**Goal**: Replace vertical scaffolding with an integer-cell `Layout` protocol and real
stack/viewport geometry while retaining controlled state and clipping.

### Step 2.1 — Promote layout and viewport catalog documents before coding

- Files: `design/primitives/divider.md`, `design/primitives/frame.md`,
  `design/primitives/padding.md`, `design/primitives/stacks.md`,
  `design/primitives/z-stack.md`, `design/widgets/split-view.md`,
  `design/widgets/scroll-view.md`, and `design/README.md`.
- Finish the `Divider`, `SplitView`, and `ScrollView` anatomy, mobile/min states where
  applicable, key/mouse/state/sizing tables, requirements, degradation rules, and open
  question decisions. Promote each to `specified`, then `ready`, before its code lands.
- Acceptance: the catalog index lists exact blockers and each implementation dependency is
  `ready`/`implemented`; no Slice 2 code is written against a sketch or wireframed-only
  behavior table.

### Step 2.2 — Add the layout target and deterministic stack algorithm

- Files: `Package.swift`, `Sources/TesseraLayout/Layout.swift`, `Stacks.swift`,
  `FrameModifiers.swift`, `Sources/TesseraCore/` layout integration, and
  `Tests/TesseraLayoutTests/StackDistributionTests.swift`.
- Add public `Layout`, `Subviews`, `LayoutValueKey`, `VStack`, `HStack`, `ZStack`,
  `Spacer`, alignments, `frame`, `padding`, `layoutPriority`, and `id` APIs. Implement the
  normative rigid/flexible/priority/fair-share algorithm, earliest-child integer remainder
  rule, minimum probing, and non-negative overflow clipping. `Subview.place` must hide a
  subview with a zero rect and measurement must be memoized per node/proposal.
- Acceptance: parameterized exact frame tables cover spacing, priority tiers, spacer
  minimums, remainder distribution, tight proposals, overflow, cross-axis alignment, and a
  custom user-defined layout works using only public API.

### Step 2.3 — Add static SplitView and ScrollView foundations

- Files: `Sources/TesseraWidgets/ScrollView.swift`, `SplitView.swift`,
  `Sources/TesseraLayout/Decoration.swift` for Divider placement if appropriate, and
  `Tests/TesseraWidgetsTests/ScrollViewTests.swift`, `SplitViewTests.swift`.
- Implement controlled static pane geometry, divider placement, clipped child rendering,
  ScrollView ideal measurement on scrollable axes, translated/clipped content, and
  programmatic offset clamping. Reserve indicator space only once overflow indicators land
  in Slice 3; do not add keyboard/pointer handling yet.
- Acceptance: exact graph/buffer snapshots prove no content paints outside parent clips,
  offsets clamp on bound changes, hidden/overflow panes do not create invalid rectangles,
  and the controlled pane state survives resize.

### Step 2.4 — Replace the Showcase vertical scaffold with real layout composition

- Files: `Examples/Sources/TesseraShowcase/` and its tests/fixtures.
- Compose the first title/catalog/playground/inspector regions with stacks and the static
  viewport/pane foundation. Use visible `Text` affordance placeholders only where the real
  component is not yet landed; mark them as temporary in code and tests.
- Acceptance: the 120x24 and 80x24 fixture scripts render stable geometry and scrollable
  content; the Slice 1 vertical scaffold is removed, and no temporary node shape is kept
  as a public component contract.

## Phase 3 — Slice 3: Styling, wrapping, decoration, and ScrollIndicator

**Goal**: Add inherited complete Styles, exact wrapping/truncation, decoration, and shared
output-only overflow geometry without creating a second style system.

### Step 3.1 — Complete style/token and decoration catalog contracts

- Files: `design/tokens.md`, `design/primitives/border.md`, `box.md`, `background.md`,
  `overlay.md`, `style-modifiers.md`, `scroll-indicator.md`, and `design/README.md`.
- Wireframe every sketch primitive needed by this slice, including degenerate/minimum
  geometry and indicator overflow states; complete schema-valid sizing/state/requirements
  tables and promote all primitive dependencies to `ready`. Resolve capability-default
  values for accent/destructive semantic styles and document token degradation rather than
  hard-coding RGB in widgets.
- Acceptance: wireframe checker, Markdown, and Prettier checks pass; every Slice 3 fixture
  has an exact source wireframe or a linked token contract.

### Step 3.2 — Implement one-style environment inheritance and text measurement

- Files: `Sources/TesseraTerminalBuffer/Style.swift`,
  `Sources/TesseraLayout/Styling.swift`, `Sources/TesseraCore/Text.swift`, and
  `Tests/TesseraLayoutTests/StyleTests.swift`, `TextWrappingTests.swift`.
- Extend the existing buffer `Style` with fluent value operations. Add nearest-ancestor
  per-attribute merge, explicit `.bold(false)` semantics, complete five-role system/custom
  environment values, `wrapped(.none/.word/.character)`, and `.truncation(.clip/.tail)`.
  Reuse Phase 2 grapheme/display-width machinery; do not reimplement width in the view
  layer.
- Acceptance: styled-grid snapshots cover inheritance/override/merge and capability
  degradation; property tests over ASCII, CJK, emoji/ZWJ, combining marks, and long words
  prove `sizeThatFits` and render agree with no out-of-bounds writes.

### Step 3.3 — Implement decoration and output-only indicators

- Files: `Sources/TesseraLayout/Decoration.swift`, `Styling.swift`, and tests.
- Implement `BorderStyle`, border, `Box`, `overlay`, `background`, styled Divider, and the
  shared `ScrollIndicator` geometry. Indicators own no input or state and are reused by
  ScrollView now and List/Table later. Clamp 0x0, 1x1, and narrow rectangles without
  crashing; preserve source-order paint behavior.
- Acceptance: VirtualTerminal/buffer snapshots cover every border glyph family, overlays,
  backgrounds, degenerate frames, and indicator track/thumb geometry.

### Step 3.4 — Add styled, Unicode, and degenerate-geometry Showcase fixtures

- Files: `Examples/Sources/TesseraShowcase/`, fixture snapshots, and tests.
- Add the style sheet, TextField-shaped text/Unicode specimen (without claiming editable
  behavior yet), border/Box specimens, and ScrollView overflow/indicator demonstrations at
  80x24 and 40x16. Keep the catalog document as the component contract.
- Acceptance: snapshots match declared grids, indicator strips reserve only overflowing
  axes, and no Showcase palette duplicates the token/style environment.

## Phase 4 — Slice 4: Focus, key routing, and controlled responders

**Goal**: Add document-order focus and exact responder bubbling, then land controlled
responders without giving the graph or widgets ownership of application state.

### Step 4.1 — Promote control and focus catalog documents to `ready`

- Files: `design/widgets/button.md`, `design/widgets/toggle.md`,
  `design/widgets/picker.md`, `design/widgets/stepper.md`, `design/widgets/text-field.md`,
  `design/widgets/scroll-view.md`, `design/widgets/split-view.md`, `design/tokens.md`, and
  `design/README.md`.
- Button, TextField, ScrollView, and SplitView are only `wireframed` today; Toggle,
  Picker, and Stepper are `sketch`. Preserve and promote the existing Toggle contract. Add
  the required anatomy/mobile/min wireframes to every sketch control, and add the missing
  declared minimum wireframe fence to Button; its `40x16` mobile fixture already exists.
  Complete controlled-binding state models, key tables, sizing tables, degradation, prior
  art, and traceable requirements, then promote the documents through `specified` to
  `ready` in dependency order. Add the existing but unindexed `design/tokens.md` to the
  README index.
- Acceptance: the catalog contains no sketch/wireframed contract consumed by Slice 4;
  every visible Showcase action has a documented Button contract rather than a hidden key
  command.

### Step 4.2 — Implement FocusManager, responder routing, and requirements aggregation

- Files: `Sources/TesseraCore/Focus.swift`, `Responder.swift`,
  `TerminalRequirements.swift`, `HitTesting.swift` (key-independent pieces only),
  `Tests/TesseraCoreTests/FocusRoutingTests.swift`, `RequirementsTests.swift`.
- Implement `focusable`, `focused`, `onKey`, `ResponderContext`, document-order advance
  with wrap, focused-node cleanup, and leaf-first → wrapper → ancestor bubbling. The graph
  never consumes an event without a handler. Aggregate requested requirements over live
  nodes and leave effective capability/session decisions to `TerminalSession`.
- Acceptance: exact recording-tree routing tables prove focused, bubble, ignored, removal,
  and unhandled cases; compile/runtime negative tests prove ResponderContext cannot
  render, access a Frame, mutate terminal modes, or see app state. Include
  cancellation/teardown tests for any event/task bridge so removed nodes cannot retain
  handlers or focus.

### Step 4.3 — Land controlled responders and keyboard viewport behavior

- Files: `Sources/TesseraWidgets/Button.swift`, `Toggle.swift`, `Picker.swift`,
  `Stepper.swift`, `TextField.swift`, `ScrollView.swift`, `SplitView.swift`, and
  `Tests/TesseraWidgetsTests/*`.
- Implement controlled actions/bindings for the four controls, TextField focus-only
  behavior, ScrollView keyboard movement/clamping, and focused SplitView divider resize.
  Keep TextField text in the app binding; NodeState may contain only cursor/reveal state
  once the final cutover happens. Do not add dual truth between a widget-owned text copy
  and the binding.
- Acceptance: scripted key/paste state-machine tests assert binding writes, ephemeral
  state retention, focus traversal, viewport edge behavior, and no activation of disabled
  controls. Tests cover visible Buttons/Enter/Space and keyboard fallback paths.

### Step 4.4 — Add visible-control and keyboard Showcase scenarios

- Files: `Examples/Sources/TesseraShowcase/`, fixture snapshots, and tests.
- Replace temporary text affordances with public Buttons and controlled controls where the
  contracts exist. Exercise Tab, arrows, Enter/Space, focus replacement,
  disabled/destructive roles, ScrollView keyboard movement, and SplitView keyboard
  resizing at 80x24 and 40x16.
- Acceptance: every compact role transition has a visible labeled Button as well as a
  keyboard path; scripted focus paths match `design/showcase.md`, and resize preserves the
  app model rather than partially reconstructing it.

## Phase 5 — Slice 5: Mouse and hit testing

**Goal**: Route mouse input through clipped, ordered graph hit testing and complete
pointer interaction without leaking terminal tracking authority into views.

### Step 5.1 — Complete pointer, hit-testing, and boundary-bubbling catalog contracts

- Files: `design/widgets/button.md`, `text-field.md`, `scroll-view.md`, `split-view.md`,
  `list.md` (for future parity), and relevant primitive documents.
- Ensure anatomy callout region names are the exact mouse-table `Region` values; specify
  click, drag, wheel, move/hover, focus-on-tap, edge bubbling, and disabled/hit-testing
  behavior. Resolve signed two-axis wheel normalization and paste/dictation normalization
  as explicit input decisions before coding.
- Acceptance: all pointer rows reference declared state and callout regions, and each
  requirement is traceable to a row or fixture. Promote dependencies to `ready`.

### Step 5.2 — Implement deepest-first hit testing and mouse responder APIs

- Files: `Sources/TesseraCore/HitTesting.swift`, `Responder.swift`,
  `TerminalRequirements.swift`, and `Tests/TesseraCoreTests/HitTestingTests.swift`.
- Implement clipped/deepest-first hit testing, ZStack topmost order, disabled subtree
  skipping, `.onTap`, `.onMouse`, `.onHover`, `allowsHitTesting`, click-to-focus, and
  leaf/wrapper/ancestor bubbling. Escalate requirements from button events to any-event
  motion for hover, and clear hover on focus loss/tracking disable.
- Acceptance: constructed-tree tables cover overlap, clipping, disabled subtrees, click
  focus, drag/scroll routing, ignored bubbling, hover enter/exit, and independent
  `wantsMouse`/`wantsMouseMotion` enable/disable against the session.

### Step 5.3 — Add pointer behavior to controls, TextField, SplitView, and ScrollView

- Files: `Sources/TesseraWidgets/{Button,TextField,SplitView,ScrollView}.swift` and tests.
- Make pointer activation use the same controlled binding/action path as keys; map
  click-to-caret to grapheme-cell positions without retaining bound text; implement static
  divider drag and viewport wheel/track behavior. Return `.ignored` at a viewport boundary
  so eligible parent viewports can consume the event.
- Acceptance: no drag threshold or hidden alternative semantics are introduced; exact
  pointer scripts prove control clicks, caret mapping, divider bindings, nested viewport
  bubbling, and requirement de-escalation after handler removal.

### Step 5.4 — Add deterministic pointer and tracking-mode Showcase scenarios

- Files: `Examples/Sources/TesseraShowcase/`, fixtures, and tests.
- Exercise primary click, hover, wheel at interior and boundary, divider drag, click-to-
  caret, handler removal, and focus-loss transitions. Cover both real `InputEvent` scripts
  and the resulting graph-requested/session-effective tracking modes.
- Acceptance: Showcase never relies on live pointer timing; snapshots and state assertions
  prove visible controls remain reachable and the terminal mode is disabled when no
  handler requires it.

## Phase 6 — Slice 6: Flex, Grid, Table, final SplitView, and NavigationSplitView

**Goal**: Add the non-stack solver and compose final pane/navigation semantics without
creating a competing Table solver or squeezing compact layouts.

### Step 6.1 — Wireframe and specify Flex/Grid plus final navigation contracts

- Files: new `design/primitives/flex.md` and `grid.md` (or an explicitly documented
  extension of the layout catalog), `design/widgets/table.md`,
  `design/widgets/navigation-split-view.md`, `split-view.md`, and `design/README.md`.
- The catalog currently has no dedicated Flex/Grid documents even though both are public
  Phase 4 APIs. Create them from the primitive template, add them to the README index,
  cite prior art, and include exact constraint/state/sizing/requirements tables. Finish
  Table and NavigationSplitView readiness; NavigationSplitView must wait for final
  SplitView negotiation, responsive layout, generic role children, and controlled
  visibility.
- Acceptance: every Flex branch (`length`, `min`, `max`, `percentage`, `ratio`, `fill`,
  default, over-constrained shrink, earliest remainder) has a table row/test name; no
  NavigationSplitView implementation starts from a wireframe-only document.

### Step 6.2 — Implement the shared Flex solver and Grid

- Files: `Sources/TesseraLayout/Flex.swift`, `Grid.swift`, and
  `Tests/TesseraLayoutTests/FlexDistributionTests.swift`, `GridTests.swift`.
- Implement the normative resolution order and integer remainder assignment once. Grid
  resolves columns once, derives each row height as the max child height at its column
  width, and explicitly rejects spanning in v1.
- Acceptance: exact tables cover every branch and negative remainder path; Grid snapshots
  prove resolved columns, row heights, clipping, and paint order; Table can consume the
  same public constraint representation without a duplicate allocator.

### Step 6.3 — Replace static SplitView geometry and add Table indicator parity

- Files: `Sources/TesseraWidgets/SplitView.swift`, `Table.swift`, `Sources/TesseraLayout/`
  shared indicator/solver seams, and tests.
- Delete the Slice 2 static pane allocator and implement final multi-pane min/ideal/max
  negotiation. Preserve stable pane IDs, controlled requested sizes/collapse flags,
  neighboring-pair divider behavior, and keyboard/pointer integration. Make Table use Flex
  constraints and the same output-only ScrollIndicator geometry as ScrollView.
- Acceptance: final SplitView has one geometry path, exact negotiation tests cover
  collapse, restoration, min/ideal/max, resize, and remainder rules, and Table/ScrollView
  indicator snapshots are geometrically identical for equivalent extents.

### Step 6.4 — Implement regular/compact NavigationSplitView and update Showcase breakpoints

- Files: `Sources/TesseraWidgets/NavigationSplitView.swift`, tests, and
  `Examples/Sources/TesseraShowcase/`.
- Compose generic Catalog/Playground/Inspector role children through final SplitView in
  regular layouts. At compact sizes use the catalog-defined replacement presentation: one
  supplied role at a time, visible labeled open/close Buttons, ScrollView around critical
  overflow, and no squeezed three-pane layout. When a binding names an unavailable role,
  apply a deterministic supplied-role fallback without mutating the binding.
- Acceptance: regular `120x24`/`80x24`, compact `40x16`, short-height `80x16`, and below
  `40x12` resize guard snapshots prove role visibility, selection/model preservation,
  visible affordances, and no partial workspace. Navigation tests prove List/Section are
  Showcase composition rather than hidden NavigationSplitView dependencies.

## Phase 7 — Slice 7: List, Section, controlled cutover, and complete Showcase

**Goal**: Complete the accepted 1.0 catalog, move all remaining state to bindings where
required, and make the Showcase the canonical Phase 4 integration proof.

### Step 7.1 — Promote List, Section, tokens, and all remaining component documents to `ready`

- Files: `design/widgets/list.md`, `section.md`, `design/tokens.md`, and every component
  document not already promoted; update `design/README.md`.
- List and Section are currently `sketch`; tokens are `sketch`; several primitives remain
  `sketch`. Complete flat grouping, selection, empty state, scrolling, section anatomy,
  system/custom styles, focus/mouse tables, min/mobile wireframes, requirements, and
  degradation. Promote dependencies before implementation and resolve all remaining open
  questions or record explicit deferrals.
- Acceptance: the 1.0 inventory in `design/showcase.md` maps one-to-one to catalog docs
  (plus the newly documented Flex/Grid APIs), and all accepted components are `ready` or
  `implemented` before final cutover.

### Step 7.2 — Implement List/Section catalog composition and final styles

- Files: `Sources/TesseraWidgets/List.swift`, `Section.swift`, final style plumbing, and
  `Tests/TesseraWidgetsTests/ListTests.swift`, `SectionTests.swift`.
- Implement the flat List selection binding, Section grouping, empty/overflow behavior,
  ScrollView/ScrollIndicator reuse, selection visibility, and controlled app-owned state.
  Apply the complete system/custom semantic roles consistently across all 1.0 controls.
- Acceptance: deterministic key/mouse scripts cover selection, out-of-range selection,
  section headers, empty records, scrolling/clamping, disabled rows, and indicator parity;
  no widget invents a business value or duplicates a component contract.

### Step 7.3 — Complete controlled TextField editing and hardware cursor behavior

- Files: `Sources/TesseraWidgets/TextField.swift`,
  `Sources/TesseraCore/RenderRegion.swift`, `Sources/TesseraTerminal/Frame.swift` only if
  the existing cursor seam needs a narrow compatible extension, and tests.
- Complete binding edits, grapheme-safe cursor movement, reveal-offset clamping on every
  bound-value replacement, focused paste/dictation commits, submit action, and
  `RenderRegion.requestCursor(at:)`/session forwarding. Treat host software-keyboard and
  dictation behavior as an injected semantic text-commit event in deterministic tests; do
  not claim Phase 4 can verify platform host UI or real dictation without a host harness.
- Acceptance: state-machine tests cover Unicode grapheme boundaries, wide/combining/ZWJ
  text, replacement, insertion/deletion, paste/dictation normalization, submit, cursor
  visibility, and absence of controlled text in NodeState/diagnostics. The Showcase uses
  the same focused input path for hardware text, host text, paste, and dictation commits.

### Step 7.4 — Finish the Showcase and immutable diagnostics Inspector

- Files: `Examples/Package.swift`, all `Examples/Sources/TesseraShowcase/` files,
  `Examples/Tests/TesseraShowcaseTests/`, `design/showcase.md` only for factual fixture
  corrections, and `.agents/investigations/020-phase-4-tessera-showcase.md` only to record
  implementation progress/decisions if its status remains the project record.
- Compose every accepted 1.0 component: Button, Toggle, Picker, Stepper, TextField, List,
  ScrollView, Section, Table, SplitView, and NavigationSplitView, plus Text, Frame,
  stacks, Padding, ZStack, Divider, Border/Box/background/overlay, styles, and
  ScrollIndicator. Keep Catalog as a flat List grouped by Section; make Catalog,
  Inspector, and open/close actions visible public Buttons at compact sizes.
- Implement the Inspector as presentation over the most recent completed immutable graph
  snapshot. Selection changes only app selection; Inspector cannot mutate the graph,
  retain a borrowed region, trigger update/layout/render/present, serialize data, or
  capture raw controlled values. Render selected frame/clip overlays as presentation only.
- Exercise all declared fixtures: dense 120x24 Overview, 80x24 ScrollView/Inspector/style
  views, 80x16 SplitView/TextField, 40x16 compact Catalog/Playground/Inspector, and the
  below-40x12 resize guard. Dispatch deterministic key, mouse, wheel, paste/text-commit,
  and resize scripts and assert both buffer snapshots and app bindings.
- Acceptance: the Showcase executable runs through `TerminalSession`; every temporary
  scaffold named in the spec's slice map is deleted; snapshots prove compact roles are
  reachable through visible Buttons, critical material scrolls rather than clips, the
  inspector is read-only, and requested/effective requirements remain distinct.

### Step 7.5 — Delete every temporary scaffold and complete catalog graduation

- Files: every implemented `design/**/*.md`, `Sources/Tessera/Tessera.docc/Extensions/`,
  new DocC extension files per component, fixture directories, and `design/README.md`.
- For each implemented component, move durable overview/anatomy/tables into its DocC
  extension beginning with the symbol-link heading, retain wireframes as snapshot
  fixtures, mark the catalog document `implemented`, and shrink it to a link/stated
  deferred residue. Do not leave stale duplicate component contracts in `design/`.
- Acceptance: each 1.0 catalog component has a live DocC contract and snapshot fixture;
  README index/status/links are accurate; `design/showcase.md` remains the integration
  composition document rather than a second widget specification.

## Phase 8 — Phase 4 closure and quality evidence

**Goal**: Prove the complete Phase 4 contract, architecture, performance posture, and
quality gates before handing the plan's implementation to review.

### Step 8.1 — Run the complete Phase 4 contract and architecture test matrix

- Files: `Tests/TesseraCoreTests/`, `Tests/TesseraLayoutTests/`,
  `Tests/TesseraWidgetsTests/`, `Tests/TesseraTerminalRenderingTests/`, and the package
  graph checker used by `just quality lint`.
- Run reconciliation/work-accounting/NodeState/diagnostics tests; exact layout and solver
  tables; style/wrap/decoration snapshots; focus/hit/event-routing scripts; controlled
  widget state machines; Showcase fixture snapshots; architecture import and package-edge
  checks; and negative ownership/lifecycle tests.
- Acceptance: all seven slice definitions of done pass, no view target imports forbidden
  modules, no view/node/graph is `Sendable`, and no test depends on timing or an actual
  terminal except the explicitly scoped executable smoke test.

### Step 8.2 — Produce performance and cross-platform evidence

- Files: `Package.swift`, new `Benchmarks/TesseraViewLayerBenchmark/main.swift`, the
  benchmark's focused unit tests, and generated `.build-benchmark/phase4-view-layer.json`
  evidence.
- Add a dedicated `TesseraViewLayerBenchmark` executable target; the repository has no
  existing view-layer benchmark harness to reuse. Build one fixed 200-node tree at
  `200x50`, run documented warm-up and sample counts in release mode, and emit toolchain,
  host, sample-count, median/p95 update/layout/render durations, and `GraphStatistics`
  counters as JSON. Keep full passes as the baseline; do not optimize before evidence
  shows the stated budget is missed.
- Run supported terminal/example smoke paths on macOS and Linux. Treat Windows view-layer
  compile/test coverage and the direct Ghostty snapshot backing as an explicit platform
  limitation unless the existing Windows Ghostty gate is proven; do not imply parity from
  the macOS/Linux result. Verify event/task teardown and cancellation on every supported
  path.
- Acceptance: performance evidence is reviewable and the under-one-frame target is either
  demonstrated or recorded as a concrete blocker; platform skips and host-text/dictation
  limits are documented rather than hidden.

### Step 8.3 — Run the repository quality gate and review the Phase 4 definition of done

- Files: all changed implementation, catalog, DocC, fixture, test, manifest, and example
  files.
- After implementation and smoke validation, run the required gate in order:
  `just quality format`, complete `swift test`, then `just quality lint`. The final lint
  command already runs the pinned markup, spelling, wireframe, and package-boundary
  checks; do not add unpinned duplicate CLI invocations.
- Acceptance: all commands pass; the Phase 4 checklist in `docs/Spec.md` is demonstrably
  complete, and review confirms the Showcase is canonical integration proof rather than an
  undocumented alternate API.

## Risks, inconsistencies, and explicit limitations

- **Catalog readiness and indexing are currently inconsistent.** `TextField`,
  `ScrollView`, `SplitView`, and `NavigationSplitView` have complete wireframe matrices.
  Button has an explicit `40x16` mobile fixture but is labeled `wireframed` without the
  declared minimum wireframe fence required by the status gate. Toggle, Picker, Stepper,
  List, Section, several decoration primitives, and `tokens.md` remain `sketch`;
  `tokens.md` exists but is absent from the status index. Only a subset of primitives and
  widgets is `specified`. The plan repairs the catalog inventory and blocks each consuming
  implementation slice on promotion instead of treating an index label as sufficient.
- **Flex/Grid have no catalog documents.** The spec makes them public but the catalog
  index does not. This plan adds primitive docs and index entries before Slice 6;
  alternatively, that decision must be recorded explicitly before implementation.
- **The proposed module layout and component landing map disagree.** Widgets appear as
  Slice 7 files although ScrollView and controls land earlier. The plan starts
  `TesseraWidgets` at the first widget landing and requires a graph decision before code.
- **Terminal/frame seam is a package-graph hazard.** The existing `Frame` is in the
  `TesseraTerminal` umbrella, which re-exports IO. The plan requires a narrow
  import/dependency decision plus source/package graph checks so core view code cannot
  gain terminal authority.
- **Host text, software keyboard, and dictation are not fully reproducible in a pure
  terminal test.** Model them as injected semantic text-commit events and separately
  record the absence of a real host integration harness; do not fake platform behavior.
- **Swift 6 parameter packs, existential opening, and lifetime restrictions are toolchain
  risks.** Probe them before Slice 1 and use fixed-arity/generated fallback only where the
  spec allows it; never weaken `~Copyable`/`~Escapable` ownership to make compilation
  easy.
- **Diagnostics can accidentally become a data leak or a second state store.** Enforce
  immutable completed-pass snapshots, redaction tests, and no serialization/logging/
  telemetry/raw controlled values. Inspector tests must prove it cannot trigger a pass.
- **Controlled-only widgets are easy to regress.** No TextField or other widget may retain
  business data in NodeState or maintain a shadow value; test binding replacement and
  state lifetime at every cutover.
- **Responsive behavior is a matrix, not one breakpoint.** Preserve the app model through
  `120x24`, `80x24`, `80x16`, `40x16`, and resize guard paths; compact role replacement
  must use visible Buttons and ScrollView rather than squeezing or silently clipping.
- **NavigationSplitView has a hard dependency on final SplitView negotiation.** Do not
  compose compact/regular navigation on Slice 2 static geometry; delete that allocator at
  Slice 6 cutover.
- **Mouse and terminal capabilities are requested/effective values.** Tests must
  distinguish graph aggregation from session capability policy and verify dynamic
  tracking-mode teardown.
- **Windows and Ghostty coverage may remain asymmetric.** Document actual build/test
  coverage and skips; do not label Phase 4 cross-platform-complete without proof.
- **The Showcase can become a second spec.** Keep its rows and fixtures linked to catalog
  contracts, keep app composition/state/diagnostics responsibility there, and reject any
  component-specific behavior table added to the Showcase.
- **Performance optimizations are deliberately deferred.** Retain full-pass simplicity and
  use `GraphStatistics` plus a 200-node/200x50 benchmark artifact before changing the
  model.
- **The existing investigation is an open record, not an implementation.** Use
  `.agents/investigations/020-phase-4-tessera-showcase.md` and `design/showcase.md` as the
  accepted Showcase boundary and decision record; update only when implementation produces
  a concrete reconciliation, never as a substitute for catalog contracts or tests.

## References

- `docs/Spec.md#phase-4--view-layer-the-tessera-module`
- `docs/Spec.md#slice-1-tesseracore--view-viewgraph-reconciliation-text`
- `docs/Spec.md#slice-2-the-layout-protocol-and-stack-containers`
- `docs/Spec.md#slice-3-styling-text-wrapping-and-decoration`
- `docs/Spec.md#slice-4-focus-and-key-routing-the-responder-system`
- `docs/Spec.md#slice-5-mouse-and-hit-testing`
- `docs/Spec.md#slice-6-flex-grid-and-composition`
- `docs/Spec.md#slice-7-catalog-integration--list-section-controlled-widgets-and-the-showcase`
- `docs/Spec.md#testing-posture-tessera-native-oracles`
- `docs/Spec.md#executable-architecture-boundaries`
- `docs/Spec.md#proposed-module-and-file-layout`
- `design/README.md#status-ladder`
- `design/README.md#wireframe-conventions`
- `design/README.md#table-schemas`
- `design/README.md#graduation`
- `design/showcase.md`
- `.agents/investigations/020-phase-4-tessera-showcase.md`
- `Package.swift`
- `Examples/Package.swift`
- `Sources/TesseraTerminal/Frame.swift`
- `Sources/TesseraTerminal/TerminalSession.swift`
- `Sources/TesseraCore/View.swift`
- `Tests/TesseraCoreTests/ViewTests.swift`
- `justfiles/quality.just`
