# Project Status

Tessera is an early, pre-1.0 Swift foundation for terminal applications. It is useful for
local experimentation, but it is not ready for production use. The terminal substrate
(`TesseraTerminal`) is usable today; the view and application-programming layer
(`Tessera`) is under active development and does not yet offer a stable public API.

This document is the canonical status, roadmap, and documentation-boundary reference. The
root [README](../README.md) stays intentionally light and defers here for detail.

## Current Phase 4 review status

Phase 4 remains **in progress and provisional**. P4.3, the operative small-specimen slice,
is complete for one fully operable `Button` path through the shared
caller/session-isolated driver: legacy and Kitty key provenance, phased activation,
normalized pointer hit testing, click-to-focus, same-node capture, cancellation, and
visible press state are implemented. This is not a claim that Phase 4 is complete, that
the whole catalog is graduated, or that a human has approved visual baselines. The
Showcase is no longer mandatory acceptance; it remains an integration reference. The
current local commands are:

```sh
swift run --package-path Examples TesseraLab run layout
swift run --package-path Examples TesseraLab run button
scripts/capture-specimen.sh layout .artifacts/review/layout
scripts/capture-specimen.sh button .artifacts/review/button
```

Both specimens run live and through real renderer bytes fed into a persistent Ghostty
virtual terminal. Two-size captures include styled cells, explicit semantic metadata,
sanitized graph diagnostics, and provisional ASCII SVG images. Repeated bundles have been
compared byte-for-byte. Button covers immediate keyboard activation, repeat/release
non-duplication, and disabled traversal; pointer down/up, outside-release cancellation,
focus/capture loss, and held-key visuals are covered by the P4.3 path. Hover, broad
gestures, ScrollView and TextField pointer behavior, and bordered Button styling remain
open. No human visual approval or complete Phase 4 acceptance is claimed. Developer export
is opt-in, versioned, local-only, and limited to built-in synthetic specimens; it has no
telemetry, reflection, network transport, or raw terminal authority.

## Supported Today

Tessera targets macOS, Linux, and Windows with Swift 6.3 or later. Current continuous
testing covers only these environments:

| Platform | Tested configuration                 | Architecture  |
| -------- | ------------------------------------ | ------------- |
| macOS    | 26.5.2                               | Apple silicon |
| Linux    | Ubuntu 24.04 (project Linux VM)      | ARM64         |
| Windows  | Windows 11 25H2 (project Windows VM) | ARM64         |

Continuous integration runs the full test suite on all three platforms with Ghostty-backed
output snapshot coverage (via `libghostty-vt`), including Windows.

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

The target shape and responsive fixtures remain documented for future integration work in
[`design/showcase.md`](../design/showcase.md). The current planned command is instead:

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

The view layer is under active construction and has no stable public API yet. Foundations
have landed; controls, collections, and styling are in progress toward the accepted 1.0
inventory below.

**Landed foundations** (`TesseraCore`, `TesseraLayout`, `TesseraWidgets`):

- An explicit, inspectable `ViewGraph` with reconciliation, identity, environments, and
  immutable diagnostics.
- `View`, `ViewBuilder`, `ForEach`, `AnyView`, `EquatableView`, and `Text`
  (grapheme/width-aware).
- The integer-cell `Layout` protocol, `VStack`/`HStack`/`ZStack`, `Spacer`, `frame`,
  `padding`, `layoutPriority`, and the shared `Flex` solver.
- `ScrollView` and `SplitView` foundations with negotiated pane geometry.

**Planned for 1.0:**

- Styling and decoration: inherited semantic `Style` values, borders, `Box`, `overlay`,
  `background`, `Divider`, and the shared `ScrollIndicator`.
- Focus and input: document-order focus, key routing, responder bubbling, and P4.3 Button
  pointer hit testing; hover, broad gestures, and application-owned text selection remain
  future work.
- Controls: the P4.3 Button key/pointer path is implemented provisionally; `Toggle`,
  `Picker`, `Stepper`, and `TextField` remain planned.
- Collections and navigation: `Grid`, `Table`, `List`, `Section`, and
  `NavigationSplitView`.

The design catalog under [`design/`](../design/README.md) is the authoritative contract
for each component's anatomy, state, sizing, input, and degradation.

## Roadmap

The active milestone is the provisional Phase 4 small-specimen review loop, not completed
Phase 4 delivery. The numbered sequence below is retained as historical roadmap context;
for remaining order, the
[review-loop execution pack](../.agents/plans/phase4-review-loop/PLAN.md) is
authoritative. It keeps final `SplitView` negotiation with its focused pane specimen,
moves complete single-line `TextField` editing ahead of navigation, and does not require
every increment to grow the Showcase:

1. Core view graph, reconciliation, and `Text` — **done**.
2. Layout, stacks, static `SplitView`, and `ScrollView` — **done**.
3. Flex sizing and final `SplitView` negotiation — **done**.
4. Styling, text wrapping, decoration, and `ScrollIndicator` — _in progress_.
5. Focus, key routing, and controlled responders (`Button`, `Toggle`, `Picker`, `Stepper`,
   `TextField`) — _planned_.
6. Mouse, hit testing, and application-owned text selection — _planned_.
7. `Grid`, `Table`, and `NavigationSplitView` composition — _planned_.
8. `List`, `Section`, controlled cutover, and the complete Showcase — _planned_.

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
