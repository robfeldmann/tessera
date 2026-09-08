# Project Status

Tessera is an early, pre-1.0 Swift foundation for terminal applications. It is useful for
local experimentation, but it is not ready for production use. The terminal substrate
(`TesseraTerminal`) is usable today; the view and application-programming layer
(`Tessera`) is under active development and does not yet offer a stable public API.

This document is the canonical status, roadmap, and documentation-boundary reference. The
root [README](../README.md) stays intentionally light and defers here for detail.

## Current Phase 4 review status

Phase 4 remains **in progress and provisional**. The accepted implementation surface
P4.3–P4.8 is integrated through the shared caller/session-isolated review path, and
host-gate validation has passed for root and Examples; all eight live-app smoke runs
exited cleanly. Visual outputs remain provisional pending maintainer approval. The current
surface includes:

- the Button key/pointer path with provenance-aware phases, clipped hit testing, focus,
  same-node capture, cancellation, and node-owned press state;
- a clamped ScrollView viewport with keyboard and wheel movement, focus reveal, indicator
  rendering, and nested-boundary bubbling;
- controlled single-line TextField editing with grapheme-safe local cursor and selection;
- controlled Toggle, Stepper, and Picker values;
- keyed List, Section, and Table selection/sort intent (the app owns actual sorting);
- row-major Grid, negotiated SplitView panes, and regular/compact NavigationSplitView
  roles;
- `onHover` motion enter/exit delivery and normalized `onPointer`/`onTap` routing.

All application values and bindings remain caller-owned. This status does not claim
complete Phase 4, catalog graduation, human visual approval, or platform runtime
graduation. The Linux static build failed because the installed Swift 6.3.2 SDK cannot be
imported by the available Swift 6.3.3 compiler; no matching compiler is installed. Linux
and Windows runtime validation is unavailable under the no-bootstrap policy. The Showcase
remains an integration reference rather than a mandatory acceptance vehicle.

The review-loop commands are available for focused evidence when the parent gate is ready:

```sh
swift run --package-path Examples TesseraLab run layout
swift run --package-path Examples TesseraLab run button
scripts/capture-specimen.sh layout .artifacts/review/layout
scripts/capture-specimen.sh button .artifacts/review/button
```

Developer export, when used, is opt-in, versioned, local-only, and limited to built-in
synthetic specimens; it has no telemetry, reflection, network transport, or raw terminal
authority.

## Supported Today

Tessera targets macOS, Linux, and Windows with Swift 6.3 or later. Host validation covers
the integrated implementation, but this document does not claim a tested platform matrix
or platform graduation. The Linux static build failed because the installed Swift 6.3.2
SDK cannot be imported by the available Swift 6.3.3 compiler; no matching compiler is
installed. Linux and Windows runtime validation is unavailable under the no-bootstrap
policy. The terminal substrate and package build remain useful for local experimentation,
but the view API is not stable.

### Planned platform widening

As the view layer matures, Tessera will broaden the supported and _tested_ range along
these axes. None of the following are guaranteed yet; each lands when it is verified in CI
or by a contributor:

- Older and newer macOS releases beyond the single pinned version, and Intel (`x86_64`)
  coverage alongside Apple silicon.
- Additional Linux distributions and releases beyond the pinned Ubuntu VM, and `x86_64`
  alongside ARM64.
- Windows `x86_64` alongside ARM64.

Contributions that validate other OS versions, distributions, or architectures are welcome
— see [CONTRIBUTING.md](../CONTRIBUTING.md).

## The Tessera Showcase

The Tessera **Showcase** is the project's historical full-featured integration design: a
dense terminal application that composes the public view surface, demonstrates one
component contract at a time, and presents a read-only diagnostics Inspector. It is not a
second specification or tutorial, and under the adopted review loop it is no longer
mandatory acceptance. Small complete specimens, driven through the shared
caller/session-isolated path and reviewed at completed checkpoints, are the current
acceptance unit.

The target shape and responsive fixtures remain documented as a historical integration
reference in [`design/showcase.md`](../design/showcase.md). Focused review uses the
following commands when the gate is ready:

```sh
swift run --package-path Examples TesseraLab run layout
```

The capture CLI is still integrating; no completed capture or visual-export evidence is
claimed here.

Its target shape:

- A three-role workspace — **Catalog**, **Playground**, and **Inspector** — composed
  through `NavigationSplitView` and the negotiated `SplitView` geometry.
- Responsive presentation that adapts from a dense `120x24` desktop down to a canonical
  `40x16` mobile fixture, collapsing from three roles to two to one and finally to a
  resize guard below `23x10`, always keeping critical material inside a `ScrollView`
  rather than clipping it.
- Every user operation driven by visible, labeled public controls (including Catalog,
  Inspector, and open/close affordances at compact sizes) with keyboard and pointer paths.
- An Inspector rendered purely over the most recent completed, immutable graph snapshot:
  it can never mutate the graph, trigger a render pass, or capture controlled values.

The full responsive policy and fixture matrix live in
[`design/showcase.md`](../design/showcase.md).

## View Components (in development)

The view layer is under active construction and has no stable public API yet. The current
P4.3–P4.8 surfaces are integrated provisionally toward the accepted 1.0 inventory; the
design catalog remains authoritative for each component's anatomy, state, sizing, input,
and degradation contract.

**Current provisional surfaces** (`TesseraCore`, `TesseraLayout`, `TesseraWidgets`):

- An explicit, inspectable `ViewGraph` with reconciliation, identity, environments, and
  immutable diagnostics.
- `View`, `ViewBuilder`, `ForEach`, `AnyView`, `EquatableView`, and width-aware `Text`.
- Integer-cell `Layout`, stacks, `Spacer`, `frame`, `padding`, `layoutPriority`, and
  `Flex`.
- `ScrollView` with clamped offset, focus reveal, keyboard/wheel input, and indicator
  state.
- `SplitView` with min/ideal/max pane negotiation, keyboard resize, and divider dragging.
- `Grid`, keyed `List`/`Section`, keyed `Table`, and controlled navigation roles.
- `Button`, `Toggle`, `Picker`, `Stepper`, and single-line `TextField` controlled values.
- Core motion and pointer modifiers: `onHover`, `onPointer`, and `onTap`.

The contracts intentionally defer broad gesture recognition, cross-view text selection,
IME pre-edit, secure-entry masking, and any custom style semantics not accepted by the
catalogs. Built-in rendering and style surfaces are provisional until the review gates
close.

The design catalog under [`design/`](../design/README.md) is the authoritative contract
for each component's anatomy, state, sizing, input, and degradation.

## Roadmap

The active milestone is the provisional Phase 4 small-specimen review loop, not completed
Phase 4 delivery. The numbered sequence below is retained as historical roadmap context;
the [review-loop execution pack](../.agents/plans/phase4-review-loop/PLAN.md) and its
`START-HERE.md` are authoritative for remaining order and gate evidence.

1. Core view graph, reconciliation, and `Text` — **done**.
2. Layout, stacks, static `SplitView`, and `ScrollView` — **done**.
3. Flex sizing and final `SplitView` negotiation — **done**.
4. Styling, text wrapping, decoration, and `ScrollIndicator` — **integrated
   provisionally**.
5. Focus, key routing, and controlled responders — **integrated provisionally**.
6. Pointer phases, hit testing, hover, click-to-caret, divider drag, viewport input, and
   nested-boundary bubbling — **integrated provisionally**.
7. `Grid`, `Table`, and `NavigationSplitView` composition — **integrated provisionally**.
8. `List`, `Section`, controlled cutover, and specimen integration — **integrated
   provisionally**.

Focused test correction, snapshot review, visual approval, and the final
publication/release gates remain outstanding. No platform runtime claim is implied by the
roadmap.

After the view layer (spec Phase 5, "Runtime + polish") the work turns to:

- The immediate-mode API (you own the loop and call `terminal.draw { … }`) and an
  optional, architecture-agnostic `@MainActor` convenience runtime for event delivery,
  responder routing, focus, invalidation, and render scheduling.
- Example apps (counter, file browser, chat client) that double as integration tests.
- DocC tutorial content and a performance pass.
- 1.0 release preparation.

That work will also broaden the OS versions Tessera supports and tests. The first public
source release will follow the release gate. The complete design and implementation plan
lives in [`docs/Spec.md`](Spec.md).

## Documentation Boundaries

- The root [README](../README.md) is the starting point for installation, product choice,
  and project maturity.
- The package's DocC catalogs describe source APIs. They are not hosted yet: Swift Package
  Index publication is deferred, and static GitHub Pages documentation is planned. Read
  them in the checkout or generate them locally with `just docs preview`.
- [`docs/Spec.md`](Spec.md) and the `design/` catalog are design and architecture
  references, not a supported API contract.
- [CONTRIBUTING.md](../CONTRIBUTING.md) and the `docs/` operational guides are for
  contributors and local development.

## Communication

Use [Q&A](https://github.com/robfeldmann/tessera/discussions/new?category=q-a) for usage
questions,
[Feature Requests and Ideas](https://github.com/robfeldmann/tessera/discussions/new?category=feature-requests-ideas)
for proposed behavior, and
[Issue Triage](https://github.com/robfeldmann/tessera/discussions/new?category=issue-triage)
for behavior that still needs confirmation. Open a
[bug report](https://github.com/robfeldmann/tessera/issues/new?template=bug.yml) once a
defect is reproducible. Do not open an unsolicited pull request: wait for maintainer
agreement and complete the
[vouched contributor workflow](../CONTRIBUTING.md#vouched-contributor-workflow).

Report vulnerabilities through the private process in the
[Security Policy](../SECURITY.md), never through a public issue or Discussion.
