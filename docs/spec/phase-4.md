---
type: spec
description: "Phase 4 — View layer (the Tessera module)"
---

# Phase 4 — View layer (the `Tessera` module)

Phase 4 builds the declarative view layer on top of the Phase 2–3 terminal substrate. It is the largest phase: seven slices of technical contract plus Phase 2.5, built in the order that [Prerequisites and scheduling](phase-4/prerequisites-and-scheduling.md) sets. The API should read like SwiftUI to a Swift developer — `body`, result builders, modifier chains, environment — while the machinery underneath stays a plain, inspectable system you can dump, step, and unit test.

The design thesis is **declarative at the edge, explicit in the core**:

1. **Views are cheap value descriptions.** A `View` is a value type whose only job is to describe UI for the current state. Evaluating `body` allocates no terminal resources and has no side effects.
2. **Views lower into an explicit runtime tree.** A `ViewGraph` owns a tree of `RuntimeNode`s produced by a documented reconciliation algorithm. Identity rules are written down, the tree is dumpable (`graph.dump()`), and every pass — update, layout, render, event routing — is a synchronous, separately testable function over that tree. There is no attribute graph, no hidden dependency tracking, no magic.
3. **State management is the app's job.** Composite views have no `@State`. Tessera never owns business state; it consumes snapshots of it. The graph re-evaluates the root when the app says so. This is what makes the layer equally comfortable under TCA, `@Observable`, reducers, actors, or a plain `while` loop.
4. **Terminal authority stays in the session.** Views declare requirements (`TerminalRequirements`) and render into borrowed regions; they never see file descriptors, mode toggles, or raw writers. The graph aggregates requirements and the session/`ModeLifecycle` arbitrates, exactly as the ownership thesis demands.

The load-bearing concurrency rule carries over from the provisional design: **views render into a borrowed region; views do not own terminal capabilities.** Views, nodes, and the `ViewGraph` are non-`Sendable` and live in one isolation domain (the caller's in Phase 4; the optional `@MainActor` runtime in Phase 5). Rendering is synchronous while a region is held — no suspension points inside a render pass. Do not make `View: Sendable` to silence diagnostics; non-sendability is a feature here.

## Sections

- [Phase 0 frozen module and ownership contract](phase-4/frozen-module-and-ownership-contract.md)
- [What Tessera keeps from SwiftUI, and what it deliberately rejects](phase-4/what-tessera-keeps-from-swiftui.md)
- [Prerequisites and scheduling](phase-4/prerequisites-and-scheduling.md)
- [Architecture: three layers, four passes](phase-4/architecture.md)
- [Testing posture: Tessera-native oracles](phase-4/testing-posture.md)
- [Executable architecture boundaries](phase-4/executable-architecture-boundaries.md)
- [Geometry](phase-4/geometry.md)
- [Identity model](phase-4/identity-model.md)
- [State model: bring your own](phase-4/state-model.md)
- [Slice 1: TesseraCore — `View`, `ViewGraph`, reconciliation, `Text`](phase-4/slice-01-tesseracore.md)
- [Slice 2: The `Layout` protocol and stack containers](phase-4/slice-02-layout-protocol-and-stacks.md)
- [Phase 2.5: Flex and final SplitView negotiation](phase-4/slice-02-5-flex-and-splitview-negotiation.md)
- [Slice 3: Styling, text wrapping, and decoration](phase-4/slice-03-styling-and-decoration.md)
- [Slice 4: Focus and key routing (the responder system)](phase-4/slice-04-focus-and-key-routing.md)
- [Slice 5: Mouse and hit testing](phase-4/slice-05-mouse-and-hit-testing.md)
- [Slice 6: `Grid`, `Table`, and fitting](phase-4/slice-06-grid-table-and-fitting.md)
- [Slice 7: Catalog integration — List, Section, and controlled widgets](phase-4/slice-07-catalog-integration.md)
- [Motion views and the tick requirement](phase-4/motion-views-and-the-tick-requirement.md)
- [Phase 4 performance posture](phase-4/performance-posture.md)
- [Definition of done for Phase 4](phase-4/definition-of-done.md)
