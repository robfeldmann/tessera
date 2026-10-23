# Project Status

Tessera is an early, pre-1.0 Swift foundation for terminal applications. It is useful for local experimentation, but it is not ready for production use. The terminal substrate (`TesseraTerminal`) is usable today; the view and application-programming layer (`Tessera`) is under active development and does not yet offer a stable public API.

This document is the canonical status, roadmap, and documentation-boundary reference. The root [README](../README.md) stays intentionally light and defers here for detail.

## Supported Today

Tessera targets macOS, Linux, and Windows with Swift 6.3 or later. The baseline toolchain is Swift 6.3.3 (`.swift-version`; Xcode 26.6 on macOS), which every lane must pass; Swift 6.4 (Xcode 27) is a second supported lane. Current continuous testing covers only these environments:

| Platform | Tested configuration | Toolchains | Architecture |
| --- | --- | --- | --- |
| macOS | 26.6 (CI); 27 (local, project macOS VM planned) | Xcode 26.6; Xcode 27.1 | Apple silicon |
| Linux | Ubuntu 24.04 (CI and project Linux VM) | Swift 6.3.3; Swift 6.4.1 | x86_64 (CI), ARM64 |
| Windows | Windows 11 25H2 (CI); Windows 11 ARM64 UTM guest (local, 651 tests passed on 2026-10-22) | Swift 6.3.3 (`.swift-version`) | x86_64 (CI), ARM64 |

Continuous integration runs the full test suite on all three platforms with Ghostty-backed output snapshot coverage (via `libghostty-vt`), including Windows. The Xcode 27 leg runs on GitHub's `xcode-27` preview image and is not yet a required check.

### Planned platform widening

As the view layer matures, Tessera will broaden the supported and _tested_ range along these axes. None of the following are guaranteed yet; each lands when it is verified in CI or by a contributor:

- Older and newer macOS releases beyond the single pinned version, and Intel (`x86_64`) coverage alongside Apple silicon.
- Additional Linux distributions and releases beyond the pinned Ubuntu VM, and `x86_64` alongside ARM64.
- Windows `x86_64` alongside ARM64.

Contributions that validate other OS versions, distributions, or architectures are welcome — see [CONTRIBUTING.md](../CONTRIBUTING.md).

## Component Demos

Each view component will ship with a small standalone demo that shows what it does and how to use it. The demos also render headlessly at fixed sizes, so they double as the snapshot fixtures that test each component, and they will later be assembled into an introductory demo app. They replace the earlier plan for a single Showcase app, whose example is being retired.

## View Components (in development)

The view layer is under active construction and has no stable public API yet. Foundations have landed; controls, collections, and styling are in progress toward the accepted 1.0 inventory below.

**Landed foundations** (`TesseraCore`, `TesseraLayout`, `TesseraWidgets`):

- An explicit, inspectable `ViewGraph` with reconciliation, identity, environments, and immutable diagnostics.
- `View`, `ViewBuilder`, `ForEach`, `AnyView`, `EquatableView`, and `Text` (grapheme/width-aware).
- The integer-cell `Layout` protocol, `VStack`/`HStack`/`ZStack`, `Spacer`, `frame`, `padding`, `layoutPriority`, and the shared `Flex` solver.
- `ScrollView` and `SplitView` foundations with negotiated pane geometry.

**Planned for 1.0:**

- Styling and decoration: inherited semantic `Style` values and tones, styled text, borders, `Box`, `overlay`, `background`, a focus border, and the shared `ScrollIndicator`.
- Focus and input: document-order focus, key routing, responder bubbling, a `KeyLegend` built from key bindings, and mouse hit testing with hover.
- Controls: `Button`, `Toggle`, `Picker`, `Stepper`, and `TextField`.
- Collections and layout: `List`, `Section`, `Outline`, `Grid`, `Table`, flow layout, `ViewThatFits`, and interactive `SplitView`.
- Status and content: `ProgressView`, `Callout`, `LabeledContent`, `Label`, `Badge`, `TabView`, `Form`, Markdown, a code view, `Image`, and `ContentUnavailableView`, with a small animation path for spinners and elapsed time.

The [design catalog](design.md) (`docs/design/`) is the authoritative contract for each component's anatomy, state, sizing, input, and degradation.

## Roadmap

The active milestone is the Phase 4 view layer. Each step lands its components with tests, a demo, and a scenario, and the [developer tools](architecture/developer-tooling.md) grow alongside them:

1. Core view graph, reconciliation, and `Text` — **done**.
2. Layout, stacks, static `SplitView`, and `ScrollView` — **done**.
3. Flex sizing and final `SplitView` negotiation — **done**.
4. Component designs revised against a reference TUI — _in progress_.
5. The demo harness, scenarios, checks, and `tessera-dev` — _planned_.
6. Styling and decoration — _planned_.
7. Focus, key routing, and `KeyLegend` — _planned_.
8. Mouse, hit testing, and hover — _planned_.
9. Interactive `ScrollView` — _planned_.
10. Flow layout and `ViewThatFits` — _planned_.
11. Controls — _planned_.
12. Collections — _planned_.
13. Interactive `SplitView` — _planned_.
14. The remaining 1.0 views — _planned_.
15. Live inspection — _planned_.
16. The intro demo app — _planned_.

After the view layer (spec Phase 5, "Runtime + polish") the work turns to:

- The immediate-mode API (you own the loop and call `terminal.draw { … }`) and an optional, architecture-agnostic `@MainActor` convenience runtime for event delivery, responder routing, focus, invalidation, and render scheduling.
- Example apps (counter, file browser, chat client) that double as integration tests.
- DocC tutorial content and a performance pass.
- 1.0 release preparation.

That work will also broaden the OS versions Tessera supports and tests. The first public source release will follow the release gate. The complete design and implementation plan lives in [`docs/spec.md`](spec.md).

## Documentation Boundaries

- The root [README](../README.md) is the starting point for installation, product choice, and project maturity.
- The package's DocC catalogs describe source APIs. They are not hosted yet: Swift Package Index publication is deferred, and static GitHub Pages documentation is planned. Read them in the checkout or generate them locally with `mise run docs:preview`.
- The [spec](spec.md) and the [design catalog](design.md) are design and architecture references, not a supported API contract.
- [CONTRIBUTING.md](../CONTRIBUTING.md) and the [guides](guides.md) are for contributors and local development; [plans](plans.md), [research](research.md), and [architecture decisions](architecture.md) are the project's working memory, mapped by [`docs/index.md`](index.md).

## Communication

Use [Q&A](https://github.com/robfeldmann/tessera/discussions/new?category=q-a) for usage questions, [Feature Requests and Ideas](https://github.com/robfeldmann/tessera/discussions/new?category=feature-requests-ideas) for proposed behavior, and [Issue Triage](https://github.com/robfeldmann/tessera/discussions/new?category=issue-triage) for behavior that still needs confirmation. Open a [bug report](https://github.com/robfeldmann/tessera/issues/new?template=bug.yml) once a defect is reproducible. Do not open an unsolicited pull request: wait for maintainer agreement and complete the [vouched contributor workflow](../CONTRIBUTING.md#vouched-contributor-workflow).

Report vulnerabilities through the private process in the [Security Policy](../SECURITY.md), never through a public issue or Discussion.
