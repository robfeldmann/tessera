---
name: Phase 3 Modern Terminal Protocols
description:
  Coordinate the six Phase 3 protocol slices so parser, lifecycle, renderer, tests, and
  the example app evolve consistently.
status: in-progress
created: 2026-07-02
updated: 2026-07-03
---

## Progress

- [x] **Phase 1 — Approve shared Phase 3 contracts**
  - [x] 1.1 Review the seven-plan bundle and confirm slice order
  - [x] 1.2 Approve shared parser, lifecycle, renderer, and example-app rules
- [ ] **Phase 2 — Execute input protocol slices**
  - [x] 2.1 Implement bracketed paste from plan 016
  - [ ] 2.2 Implement focus events from plan 017
  - [ ] 2.3 Implement SGR mouse tracking from plan 018
  - [ ] 2.4 Implement Kitty keyboard and dynamic mode apply from plan 019
- [ ] **Phase 3 — Execute output and capability slices**
  - [ ] 3.1 Implement OSC 8 hyperlinks from plan 020
  - [ ] 3.2 Implement terminal capability detection from plan 021
- [ ] **Phase 4 — Close Phase 3 as one integrated substrate**
  - [ ] 4.1 Run the full Phase 3 validation sweep
  - [ ] 4.2 Review the example app across every protocol panel

## Overview

This is the coordination plan for `docs/Spec.md` Phase 3, lines 3639-5342. Phase 3 keeps
the work inside `TesseraTerminal`: modern terminal protocols are added to input parsing,
terminal mode lifecycle, rendering, configuration, tests, and examples. It does not
introduce `View`, layout, widgets, shortcut routing, hit testing, or runtime state
management.

The executable slice plans are separate review units:

- `016-phase-3-slice-1-bracketed-paste-mode.md`
- `017-phase-3-slice-2-focus-events.md`
- `018-phase-3-slice-3-sgr-mouse-tracking.md`
- `019-phase-3-slice-4-kitty-keyboard-protocol.md`
- `020-phase-3-slice-5-osc-8-hyperlinks.md`
- `021-phase-3-slice-6-terminal-capability-detection.md`

Implement them in numeric order. The order matters because each slice proves a contract
that later slices reuse: bracketed paste establishes parser-mode isolation, focus proves
small CSI event decoding, mouse expands event payloads, Kitty keyboard changes keyboard
semantics, hyperlinks exercise output-side metadata, and capabilities settle policy.

## Implementation prompts

Use these prompts one slice at a time. The umbrella plan is a shared contract; the active
slice plan is the executable checklist. After finishing one slice, stop for review and
feedback before starting the next slice.

### Slice 1 prompt — Bracketed paste

```text
Implement .agents/plans/016-phase-3-slice-1-bracketed-paste-mode.md.

Before editing, read these fully:
- .agents/plans/015-phase-3-modern-terminal-protocols.md
- docs/Spec.md lines 3639-3984, covering the Phase 3 overview and Slice 1
- .agents/plans/016-phase-3-slice-1-bracketed-paste-mode.md

Treat plan 015 as the shared contract. Execute only plan 016. Do not implement focus
events, mouse tracking, Kitty keyboard, hyperlinks, capability detection, or Phase 4 view
layer work.

Write tests close to the production code they cover. Prefer snapshot-style tests for event
logs and lifecycle transcripts where the plan requests them. Add only the paste panel to
Phase3ProtocolsDemo. Run the validation commands from plan 016.

When complete, update plan progress, report changed files and validation results, then stop
and wait for review.
```

### Slice 2 prompt — Focus events

```text
Implement .agents/plans/017-phase-3-slice-2-focus-events.md.

Before editing, read these fully:
- .agents/plans/015-phase-3-modern-terminal-protocols.md
- docs/Spec.md lines 3639-3815, covering the Phase 3 overview
- docs/Spec.md lines 3985-4173, covering Slice 2
- .agents/plans/017-phase-3-slice-2-focus-events.md

Treat plan 015 as the shared contract and the completed Slice 1 code as source of truth.
Execute only plan 017. Do not implement mouse tracking, Kitty keyboard, hyperlinks,
capability detection, or Phase 4 view-layer work.

Write tests close to the production code they cover. Preserve bracketed-paste isolation in
all focus parser changes. Add only the focus panel to Phase3ProtocolsDemo. Run the
validation commands from plan 017.

When complete, update plan progress, report changed files and validation results, then stop
and wait for review.
```

### Slice 3 prompt — SGR mouse tracking

```text
Implement .agents/plans/018-phase-3-slice-3-sgr-mouse-tracking.md.

Before editing, read these fully:
- .agents/plans/015-phase-3-modern-terminal-protocols.md
- docs/Spec.md lines 3639-3815, covering the Phase 3 overview
- docs/Spec.md lines 4174-4483, covering Slice 3
- .agents/plans/018-phase-3-slice-3-sgr-mouse-tracking.md

Treat plan 015 as the shared contract and completed prior slice code as source of truth.
Execute only plan 018. Do not implement Kitty keyboard, hyperlinks, capability detection,
or Phase 4 view-layer work.

Write tests close to the production code they cover. Keep SGR mouse byte parsing inside
the existing input parser and keep mouse tracking opt-in. Add only the mouse panel to
Phase3ProtocolsDemo. Run the validation commands from plan 018.

When complete, update plan progress, report changed files and validation results, then stop
and wait for review.
```

### Slice 4 prompt — Kitty keyboard protocol

```text
Implement .agents/plans/019-phase-3-slice-4-kitty-keyboard-protocol.md.

Before editing, read these fully:
- .agents/plans/015-phase-3-modern-terminal-protocols.md
- docs/Spec.md lines 3639-3815, covering the Phase 3 overview
- docs/Spec.md lines 4484-4741, covering Slice 4
- .agents/plans/019-phase-3-slice-4-kitty-keyboard-protocol.md

Treat plan 015 as the shared contract and completed prior slice code as source of truth.
Execute only plan 019. Do not implement OSC 8 hyperlinks, capability detection, or Phase 4
view-layer work.

Write tests close to the production code they cover. Preserve legacy keyboard parsing while
adding Kitty reports. Implement dynamic application-mode apply only where plan 019 requires
it. Add only the keyboard panel to Phase3ProtocolsDemo. Run the validation commands from
plan 019.

When complete, update plan progress, report changed files and validation results, then stop
and wait for review.
```

### Slice 5 prompt — OSC 8 hyperlinks

```text
Implement .agents/plans/020-phase-3-slice-5-osc-8-hyperlinks.md.

Before editing, read these fully:
- .agents/plans/015-phase-3-modern-terminal-protocols.md
- docs/Spec.md lines 3639-3815, covering the Phase 3 overview
- docs/Spec.md lines 4742-4989, covering Slice 5
- .agents/plans/020-phase-3-slice-5-osc-8-hyperlinks.md

Treat plan 015 as the shared contract and completed prior slice code as source of truth.
Execute only plan 020. Do not implement terminal capability detection or Phase 4 view-layer
work.

Write tests close to the production code they cover. Prefer VirtualTerminal snapshots for
screen/link state and exact byte tests only for the encoder and transition-order contracts.
Add only the links panel to Phase3ProtocolsDemo. Run the validation commands from plan 020.

When complete, update plan progress, report changed files and validation results, then stop
and wait for review.
```

### Slice 6 prompt — Terminal capability detection

```text
Implement .agents/plans/021-phase-3-slice-6-terminal-capability-detection.md.

Before editing, read these fully:
- .agents/plans/015-phase-3-modern-terminal-protocols.md
- docs/Spec.md lines 3639-3815, covering the Phase 3 overview
- docs/Spec.md lines 4990-5342, covering Slice 6
- .agents/plans/021-phase-3-slice-6-terminal-capability-detection.md

Treat plan 015 as the shared contract and completed prior slice code as source of truth.
Execute only plan 021. Do not implement Phase 4 view-layer work.

Write tests close to the production code they cover. Keep capability detection passive
unless the plan has been updated and approved to include active queries. Add only the
capabilities panel to Phase3ProtocolsDemo. Run the validation commands from plan 021 and
the integrated validation sweep from this umbrella plan.

When complete, update plan progress, report changed files and validation results, then stop
and wait for review.
```

## Shared source contracts

### Input parser and event model

- Extend the existing `Sources/TesseraTerminalInput` types. Do not create parallel
  protocol-specific parsers.
- `InputParser.feed(_:)`, `feed(contentsOf:)`, `flushPendingEscape()`, and `flush()`
  remain the parser surface.
- `InputEvent.unknown([UInt8])` remains the lossless malformed-input escape hatch.
- Bracketed paste is a parser mode. While inside paste, ANSI-looking bytes are payload
  unless they match the exact bracketed-paste end marker.
- Focus, mouse, and Kitty reports are recognized only in normal parser mode.
- Byte splitting is part of every parser contract. Each protocol gets byte-by-byte tests.
- Parser protocol modes must avoid hot-path heap churn. Use bounded marker state and
  private buffers for large payload modes; do not reintroduce `bytes.flatMap { feed($0) }`
  or per-byte event-array allocation in `feed(contentsOf:)`.
- `PlatformIO` remains the single raw-byte-to-`InputEvent` pipeline. Empty byte chunks
  keep their current meaning: input-idle notifications for bare-Escape disambiguation.

### ANSI encoder and lifecycle

- Extend `Sources/TesseraTerminalANSI/ControlSequence.swift`; do not scatter literal
  escape strings through lifecycle or renderer code.
- Every new `ControlSequence` case must be listed in every exhaustive encoder switch.
- DEC private modes with symmetric set/reset use one `Bool`-parameterized case.
- Kitty keyboard is the exception: it uses explicit push/pop cases because the protocol is
  stack-shaped.
- `ModeLifecycle` owns all terminal mode enable/disable bytes.
- `rawMode` and `altScreen` stay session-fixed. Bracketed paste, focus, mouse, and Kitty
  keyboard are application protocol modes.
- Cleanup may over-disable optional protocol modes. It must never leave a mode enabled
  after normal or abnormal exit.
- `ModeLifecycle.apply(applicationModes:)` is implemented after the four input modes
  exist, in the Kitty plan. Earlier slices shape their enable/disable helpers so `apply`
  can reuse them.

### Renderer and output metadata

- Hyperlinks are style-like metadata on rendered cells, not raw OSC bytes inside strings.
- OSC 8 state is independent of SGR state. `resetAttributes` does not close hyperlinks.
- `Renderer.invalidate()` must forget any believed hyperlink state once hyperlinks exist.
- `VirtualTerminal` is the preferred renderer verification path. Exact byte tests remain
  for the encoder surface.

### Windows and platform boundaries

- Phase 3 protocols are bytes-in and bytes-out through the existing `PlatformIO` seam.
- Do not add Win32 `FOCUS_EVENT_RECORD` or `MOUSE_EVENT_RECORD` public semantics.
- `WindowsInputLoop` continues to drain legacy console records and deliver VT byte input.
- Snapshot-backed renderer tests should run wherever
  `VirtualTerminal.ghosttyOrUnavailable` is available; no new platform skip convention is
  introduced.

## Shared test strategy

Tests are written close to the production code they protect:

- `Tests/TesseraTerminalInputTests`: parser and event-model tests.
- `Tests/TesseraTerminalANSITests`: exact `ControlSequence` byte tests and small
  virtual-terminal round trips when useful.
- `Tests/TesseraTerminalIOTests`: `ModeLifecycle`, cleanup, ordering, and dynamic apply.
- `Tests/TesseraTerminalRenderingTests`: renderer bytes, visual equivalence, and hyperlink
  damage behavior.
- `Tests/TesseraTerminalBufferTests`: structural style/cell behavior.
- `Tests/TesseraTerminalSnapshotSupportTests`: Ghostty bridge behavior needed by renderer
  snapshots.
- `Tests/TesseraTerminalTests`: session/configuration integration.

Prefer snapshot-style tests when the value is structured and human-inspectable as a whole:

- event logs for multi-event parser scenarios
- lifecycle event/byte transcripts
- terminal text, styled-grid, debug, and hyperlink snapshots
- example-app-independent render states

Prefer direct assertions for scalar API behavior:

- one `ControlSequence` exact byte string
- one `MouseEvent` field
- one capability enum result
- one rejected hyperlink initializer input

## Example application strategy

Add one evolving example executable instead of six small apps:

- Product and target: `Phase3ProtocolsDemo` in `Examples/Package.swift`.
- Source: `Examples/Sources/Phase3ProtocolsDemo/Phase3ProtocolsDemo.swift`.
- Dependencies: `ExampleSupport` and `TesseraTerminal`.
- Validation command: `swift build --package-path Examples --product Phase3ProtocolsDemo`.
- The app stays terminal-substrate-only. It writes directly through `Frame`, like the
  current examples, and does not introduce a view layer.

High-level wireframe:

```text
┌─ Phase3ProtocolsDemo ───────────────────────────────────────────────────────┐
│ q quit · 1 paste · 2 focus · 3 mouse · 4 keys · 5 links · 6 capabilities    │
├─ Active protocol panel ─────────────────────────────────────────────────────┤
│ Status line for the selected protocol                                       │
│                                                                            │
│ Panel-specific visualization                                                │
│                                                                            │
├─ Recent terminal events ────────────────────────────────────────────────────┤
│ 0001 key code=character("a") modifiers=none kind=press                     │
│ 0002 paste chars=42 lines=3                                                 │
│ 0003 focus lost                                                             │
└────────────────────────────────────────────────────────────────────────────┘
```

Each slice plan includes a panel-specific wireframe. The app should be useful during
review, but it is not the primary verification mechanism; tests remain the authority.

## Cross-slice defaults and policy decisions

- `TerminalApplicationConfiguration.default` enables bracketed paste and focus events once
  those slices land.
- Mouse tracking stays opt-in until configuration policy is settled. It changes selection
  and scrollback behavior.
- Kitty keyboard stays out of the default until the capability slice settles policy. The
  parser still decodes valid Kitty reports if a terminal sends them.
- OSC 8 rendering is enabled when style metadata asks for it. Unsupported terminals still
  show the visible text.
- Capability detection starts conservative. It exposes hints and policy, not promises.
  Startup must not fail because a terminal does not answer a query.

## Integrated validation sweep

Run narrow validation inside each slice first. After plan 021 is implemented, run:

```fish
swift test --filter TesseraTerminalInputTests
swift test --filter TesseraTerminalANSITests
swift test --filter TesseraTerminalIOTests
swift test --filter TesseraTerminalRenderingTests
swift test --filter TesseraTerminalSnapshotSupportTests
swift test --filter TesseraTerminalTests
swift build --package-path Examples --product Phase3ProtocolsDemo
just quality changed
```

Before committing Phase 3, run `just quality lint`.
