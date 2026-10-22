---
type: hub
stage: living
description: The Tessera specification, one page per section, in reading order.
---

# Tessera specification

Tessera is the Swift counterpart to Ratatui — a cell-buffer rendering and view layer for
terminal apps — with a compositional layout API inspired by Lip Gloss's Join/Place/Compose
primitives. Architecture-agnostic; bring your own state management.

- A cell buffer ✓
- A renderer with damage tracking ✓
- A View protocol and built-in views ✓
- Layout primitives ✓
- Input parsing ✓
- An optional runtime, architecture-agnostic ✓

## How to use this spec

This spec is both a design document and an implementation plan. It is intentionally more
verbose than a normal roadmap because future-you and future agents need enough context to
make local changes without re-litigating terminal architecture from scratch.

Use it selectively:

- **Implementing a slice:** read the current phase intro, the current slice, and any
  referenced prior slices. Follow the Ratatui/crossterm callouts for comparable designs.
- **Changing a public type:** search the whole spec for that type first. Many Phase 2
  types are intentionally extended by Phase 3 and consumed by Phase 4.
- **Debugging behavior:** start with the slice that introduced the behavior, then read its
  tests section and references. Avoid loading unrelated phases unless the bug crosses a
  boundary.
- **Planning a phase boundary:** read the whole previous phase, the next phase intro, and
  the risk/decision notes near the end of relevant slices.
- **Using AI assistance:** give the model the smallest relevant slice plus referenced type
  definitions. Do not ask it to ingest the whole spec unless the task is architectural.
- **Implementing early phases:** prefer the real public API shape as soon as it is
  knowable. Keep behavior small and incomplete, but do not introduce placeholder,
  temporary, or phase-named public API unless there is a specific bootstrap reason.

## Pages

The spec was one file, `docs/Spec.md`, until 2026-10-22; it is now one page per section in
`docs/spec/`, with the three large phases split again by slice. The order below is the
original reading order, and concatenating the pages in this order reproduces the original
text apart from heading levels and links. Research records and completed plans written
before the split cite `docs/Spec.md:NNNN` by line; those citations hold at the commit they
cite and are not rewritten. Living documents link to pages and headings instead.

- [Terminal citizenship thesis: be composable, not a compatibility ceiling](spec/terminal-citizenship-thesis.md)
- [Ownership and isolation thesis: illegal terminal operations should be unrepresentable](spec/ownership-and-isolation-thesis.md)
- [Phase 0: Foundation](spec/phase-0-foundation.md)
- [Phase 1: The Walking Skeleton](spec/phase-1-walking-skeleton.md)
- [Phase 2: Real terminal foundation](spec/phase-2.md)
  - [Slice 1: The snapshot harness](spec/phase-2/slice-01-the-snapshot-harness.md)
  - [Slice 2: ANSI Encoder](spec/phase-2/slice-02-ansi-encoder.md)
  - [Slice 3: mode lifecycle + real PlatformIO + signal handling](spec/phase-2/slice-03-mode-lifecycle-and-platformio.md)
  - [Slice 4: Width-aware `Buffer` + damage-tracking renderer](spec/phase-2/slice-04-width-aware-buffer-and-renderer.md)
  - [Slice 5: Legacy input parser (escape sequences, arrow keys, function keys, modifiers)](spec/phase-2/slice-05-legacy-input-parser.md)
  - [Slice 6: Windows support for `PlatformIO` (SetConsoleMode, ReadConsoleInput, Windows signal equivalents)](spec/phase-2/slice-06-windows-support.md)
  - [End of Phase 2](spec/phase-2/end-of-phase-2.md)
- [Phase 3: Modern terminal protocols](spec/phase-3.md)
  - [Phase 3 ground truth: the implemented substrate](spec/phase-3/ground-truth.md)
  - [Dynamic mode changes (`ModeLifecycle.apply`)](spec/phase-3/dynamic-mode-changes.md)
  - [Slice 1: Bracketed paste mode](spec/phase-3/slice-01-bracketed-paste-mode.md)
  - [Slice 2: Focus events](spec/phase-3/slice-02-focus-events.md)
  - [Slice 3: SGR mouse tracking](spec/phase-3/slice-03-sgr-mouse-tracking.md)
  - [Slice 4: Kitty keyboard protocol](spec/phase-3/slice-04-kitty-keyboard-protocol.md)
  - [Slice 5: OSC 8 hyperlinks](spec/phase-3/slice-05-osc-8-hyperlinks.md)
  - [Slice 6: Terminal capability detection](spec/phase-3/slice-06-terminal-capability-detection.md)
  - [Slice 7: Kitty graphics protocol](spec/phase-3/slice-07-kitty-graphics-protocol.md)
  - [Slice 8: Color degradation baseline](spec/phase-3/slice-08-color-degradation-baseline.md)
  - [Slice 9: OSC 52 clipboard](spec/phase-3/slice-09-osc-52-clipboard.md)
  - [Slice 10: Cursor styling](spec/phase-3/slice-10-cursor-styling.md)
  - [Slice 11: Underline extensions](spec/phase-3/slice-11-underline-extensions.md)
  - [Slice 12: Runtime protocol control](spec/phase-3/slice-12-runtime-protocol-control.md)
- [Phase 4 — View layer (the `Tessera` module)](spec/phase-4.md)
  - [Phase 0 frozen module and ownership contract](spec/phase-4/frozen-module-and-ownership-contract.md)
  - [What Tessera keeps from SwiftUI, and what it deliberately rejects](spec/phase-4/what-tessera-keeps-from-swiftui.md)
  - [Prerequisites and scheduling](spec/phase-4/prerequisites-and-scheduling.md)
  - [Architecture: three layers, four passes](spec/phase-4/architecture.md)
  - [Testing posture: Tessera-native oracles](spec/phase-4/testing-posture.md)
  - [Executable architecture boundaries](spec/phase-4/executable-architecture-boundaries.md)
  - [Geometry](spec/phase-4/geometry.md)
  - [Identity model](spec/phase-4/identity-model.md)
  - [State model: bring your own](spec/phase-4/state-model.md)
  - [Slice 1: TesseraCore — `View`, `ViewGraph`, reconciliation, `Text`](spec/phase-4/slice-01-tesseracore.md)
  - [Slice 2: The `Layout` protocol and stack containers](spec/phase-4/slice-02-layout-protocol-and-stacks.md)
  - [Phase 2.5: Flex and final SplitView negotiation](spec/phase-4/slice-02-5-flex-and-splitview-negotiation.md)
  - [Slice 3: Styling, text wrapping, and decoration](spec/phase-4/slice-03-styling-and-decoration.md)
  - [Slice 4: Focus and key routing (the responder system)](spec/phase-4/slice-04-focus-and-key-routing.md)
  - [Slice 5: Mouse and hit testing](spec/phase-4/slice-05-mouse-and-hit-testing.md)
  - [Slice 6: `Grid`, `Table`, and fitting](spec/phase-4/slice-06-grid-table-and-fitting.md)
  - [Slice 7: Catalog integration — List, Section, and controlled widgets](spec/phase-4/slice-07-catalog-integration.md)
  - [Motion views and the tick requirement](spec/phase-4/motion-views-and-the-tick-requirement.md)
  - [Phase 4 performance posture](spec/phase-4/performance-posture.md)
  - [Definition of done for Phase 4](spec/phase-4/definition-of-done.md)
- [Phase 5 — Runtime + polish](spec/phase-5-runtime-and-polish.md)
- [Risk register](spec/risk-register.md)
- [Proposed module and file layout](spec/module-and-file-layout.md)
