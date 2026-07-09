---
name: Phase 3 Modern Terminal Protocols
description:
  Coordinate the eleven Phase 3 protocol slices so parser, lifecycle, renderer, tests, and
  the example app evolve consistently.
status: pending
created: 2026-07-02
updated: 2026-07-08
---

## Progress

- [x] **Phase 1 — Approve shared Phase 3 contracts**
  - [x] 1.1 Review the expanded Phase 3 plan bundle and confirm slice order
  - [x] 1.2 Approve shared parser, lifecycle, renderer, and example-app rules
- [x] **Phase 2 — Execute input protocol slices**
  - [x] 2.1 Implement bracketed paste from plan 016
  - [x] 2.2 Implement focus events from plan 017
  - [x] 2.3 Implement SGR mouse tracking from plan 018
  - [x] 2.4 Implement Kitty keyboard and dynamic mode apply from plan 019
- [ ] **Phase 3 — Execute output, capability, and advanced styling slices**
  - [x] 3.1 Implement OSC 8 hyperlinks from plan 020
  - [x] 3.2 Implement terminal capability detection from plan 021
  - [x] 3.3 Implement Kitty graphics protocol from plan 022
  - [x] 3.4 Refactor capability detection to active, non-hard-coded probes
  - [x] 3.5 Implement color degradation baseline from plan 024
  - [ ] 3.6 Implement OSC 52 clipboard from plan 025
  - [ ] 3.7 Implement cursor styling from plan 026
  - [ ] 3.8 Implement underline extensions from plan 027
- [ ] **Phase 4 — Close Phase 3 as one integrated substrate**
  - [ ] 4.1 Run the full Phase 3 validation sweep
  - [ ] 4.2 Review the example app across every protocol panel

## Overview

This is the coordination plan for `docs/Spec.md` Phase 3. Phase 3 keeps the work inside
`TesseraTerminal`: modern terminal protocols are added to input parsing, terminal mode
lifecycle, rendering, configuration, tests, and examples. It does not introduce `View`,
layout, widgets, shortcut routing, hit testing, or runtime state management.

The executable slice plans are separate review units:

- `016-phase-3-slice-1-bracketed-paste-mode.md`
- `017-phase-3-slice-2-focus-events.md`
- `018-phase-3-slice-3-sgr-mouse-tracking.md`
- `019-phase-3-slice-4-kitty-keyboard-protocol.md`
- `020-phase-3-slice-5-osc-8-hyperlinks.md`
- `021-phase-3-slice-6-terminal-capability-detection.md`
- `022-phase-3-slice-7-kitty-graphics-protocol.md`
- `024-phase-3-slice-8-color-degradation-baseline.md`
- `025-phase-3-slice-9-osc-52-clipboard.md`
- `026-phase-3-slice-10-cursor-styling.md`
- `027-phase-3-slice-11-underline-extensions.md`

Implement them in numeric order. The order matters because each slice proves a contract
that later slices reuse: bracketed paste establishes parser-mode isolation, focus proves
small CSI event decoding, mouse expands event payloads, Kitty keyboard changes keyboard
semantics, hyperlinks exercise output-side metadata, capabilities settle policy, Kitty
graphics builds on all of it, color degradation makes rendering capability-aware, OSC 52
adds the first policy-gated session side effect, cursor styling extends lifecycle-owned
terminal preferences, and underline extensions finish the modern text-decoration baseline.

## Implementation prompts

Use these prompts one slice at a time. The umbrella plan is a shared contract; the active
slice plan is the executable checklist. After finishing one slice, stop for review and
feedback before starting the next slice.

### Slice 1 prompt — Bracketed paste

```text
Implement .agents/plans/016-phase-3-slice-1-bracketed-paste-mode.md.

Before editing, read these fully:
- .agents/plans/015-phase-3-modern-terminal-protocols.md
- docs/Spec.md lines 3644-4009, covering the Phase 3 overview and Slice 1
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
- docs/Spec.md lines 3644-3826, covering the Phase 3 overview
- docs/Spec.md lines 4010-4198, covering Slice 2
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
- docs/Spec.md lines 3644-3826, covering the Phase 3 overview
- docs/Spec.md lines 4199-4645, covering Slice 3
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
- docs/Spec.md lines 3644-3826, covering the Phase 3 overview
- docs/Spec.md lines 4646-4903, covering Slice 4
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
- docs/Spec.md lines 3644-3826, covering the Phase 3 overview
- docs/Spec.md lines 4904-5151, covering Slice 5
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
- docs/Spec.md lines 3644-3826, covering the Phase 3 overview
- docs/Spec.md lines 5152-5490, covering Slice 6
- .agents/plans/021-phase-3-slice-6-terminal-capability-detection.md

Treat plan 015 as the shared contract and completed prior slice code as source of truth.
Execute only plan 021. Do not implement Phase 4 view-layer work.

Write tests close to the production code they cover. Keep capability detection passive
unless the plan has been updated and approved to include active queries. Add only the
capabilities panel to Phase3ProtocolsDemo. Run the validation commands from plan 021.

When complete, update plan progress, report changed files and validation results, then stop
and wait for review.
```

### Slice 7 prompt — Kitty graphics

```text
Implement .agents/plans/022-phase-3-slice-7-kitty-graphics-protocol.md.

Before editing, read these fully:
- .agents/plans/015-phase-3-modern-terminal-protocols.md
- docs/Spec.md lines 3644-3826, covering the Phase 3 overview
- docs/Spec.md lines 5491-6029, covering Slice 7
- .agents/plans/022-phase-3-slice-7-kitty-graphics-protocol.md
- Sources/CGhosttyVT/include/ghostty/vt/kitty_graphics.h, before the harness step

Treat plan 015 as the shared contract and completed prior slice code as source of truth.
Execute only plan 022. Do not implement Sixel, iTerm2 inline images, Unicode
placeholders, animation, active capability probing, or Phase 4 view-layer work.

Write tests close to the production code they cover. Prefer Ghostty-backed placement
assertions over byte snapshots for harness-facing behavior; keep exact byte tests for the
encoder surface. Add only the image panel to Phase3ProtocolsDemo. Run the validation
commands from plan 022 and the integrated validation sweep from this umbrella plan.

When complete, update plan progress, report changed files and validation results, then stop
and wait for review.
```

### Step 3.4 prompt — Active capability detection refactor

```text
Refactor Phase 3 capability detection so production protocol support decisions are active,
protocol-native, and not inferred from hard-coded terminal names.

Before editing, read these fully:
- .agents/plans/015-phase-3-modern-terminal-protocols.md
- docs/Spec.md lines 3644-3826, covering the Phase 3 overview
- docs/Spec.md lines 5152-5490, covering Slice 6
- docs/Spec.md lines 5491-6029, covering Slice 7
- Sources/TesseraTerminal/TerminalCapabilityDetector.swift
- Sources/TesseraTerminal/TerminalApplicationConfiguration.swift
- Sources/TesseraTerminal/TerminalSession.swift
- Sources/TesseraTerminalInput/InputParser.swift
- Examples/Sources/Phase3ProtocolsDemo/Phase3ProtocolsDemo.swift

Treat completed Slice 6 and Slice 7 code as source of truth, but remove their remaining
passive terminal-name protocol assumptions. The final production capability system must not
branch on concrete terminal names such as Ghostty, kitty, WezTerm, Apple Terminal, Windows
Terminal, iTerm2, foot, xterm, Konsole, or VTE to decide whether a protocol is supported or
unsupported. Terminal identity may remain as diagnostic/display metadata only if capability
policy does not depend on specific terminal names.

Keep the KGP active probe added during Slice 7: send `a=q` Kitty graphics query bytes
immediately followed by DA1 (`ESC [ c`). A KGP response before DA1 means supported; DA1
first means unsupported; no response keeps the result unknown/probing. Do not replace this
with a terminal-name allowlist.

Add equivalent active-probe infrastructure for the other queryable protocols:
- Kitty keyboard: use the documented `CSI ? u` query plus DA1 sentinel. A keyboard-protocol
  response before DA1 means supported; DA1 first means unsupported.
- DEC private modes: add DECRQM request/response support (`CSI ? Ps $ p` request and
  `CSI ? Ps ; Pm $ y` response) and use it for bracketed paste (`2004`), focus events
  (`1004`), SGR mouse / mouse protocol modes that Tessera enables (`1000`, `1002`,
  `1003`, `1006` as applicable), and synchronized output (`2026`) only after verifying the
  mode is queryable. Unrecognized DECRQM responses must preserve an unknown result, not
  silently report support.
- OSC 8 hyperlinks: do not invent detection. OSC 8 has no standard support query; keep it
  as safe-to-emit style metadata with visible text fallback, and present it in capability
  UI as not actively detectable unless a future standard probe is added.
- Color depth and `NO_COLOR`/`COLORTERM` handling may remain environment-based because
  those are generic environment conventions rather than terminal-name protocol support
  tables. Do not add named-terminal color special cases.

Update configuration policy so `.kittyIfAvailable` and any future "if available" mode
intents consume active probe results rather than passive terminal-name confidence. Startup
must not block indefinitely: probes must be represented as probing/unknown until terminal
input produces responses. Unsupported or unknown probes must prevent enabling protocols
that can corrupt input/output when blindly enabled.

Revisit `Phase3ProtocolsDemo`:
- Panel 6 (capabilities) must show active probe state per protocol: probing, supported,
  unsupported, unknown, or not detectable. It must not imply support because of the
  terminal name.
- Panel 4 (keyboard) must still make sense after Kitty keyboard support becomes actively
  detected rather than passively inferred.
- Panel 7 (graphics) must continue to use the KGP query + DA1 sentinel and must not
  transmit image bytes until support is observed or the user explicitly opts in.
- Any other panel affected by dynamic mode enablement must be reviewed and updated.

Update tests close to the code they protect:
- Parser tests for DA1, Kitty keyboard query responses, and DECRQM responses, including
  byte-by-byte parsing, malformed responses, and ordering around DA1 sentinels.
- Session/configuration tests proving active probe results drive application mode
  resolution.
- Capability tests proving named terminal identities do not imply protocol support or
  unsupported status. Tests should fail if protocol support is reintroduced through
  hard-coded terminal-name branches.
- Phase3ProtocolsDemo-focused tests or smoke checks proving panel 6 displays active probe
  state and panel 7 gates image output on the KGP probe.

Update docs/Spec.md so Slice 6 and Slice 7 describe the active, non-hard-coded detection
model. Remove outdated language saying capability detection is passive or terminal-name
based.

Acceptance criteria:
- Production capability support decisions contain no hard-coded references to specific
  terminal brands or emulator names.
- KGP support uses `a=q` + DA1 sentinel and never relies on a terminal-name allowlist.
- Queryable protocols use their native active query mechanism or remain unknown; no
  protocol silently falls back to terminal-name inference.
- OSC 8 is explicitly documented and tested as not actively detectable, while remaining
  safe because visible link text still renders.
- `Phase3ProtocolsDemo` panel 6 and all affected protocol panes reflect active probe state
  and do not display hard-coded confidence from terminal identity.
- Unit tests cover parser responses, session/config resolution, and the no-hard-coded-name
  contract.
- docs/Spec.md matches the implemented behavior.
- Run:
  swift test --filter TesseraTerminalInputTests
  swift test --filter TesseraTerminalIOTests
  swift test --filter TesseraTerminalTests
  swift build --package-path Examples --product Phase3ProtocolsDemo
  just quality changed

When complete, update plan progress, report changed files and validation results, then stop
and wait for review.
```

### Slice 8 prompt — Color degradation baseline

```text
Implement .agents/plans/024-phase-3-slice-8-color-degradation-baseline.md.

Before editing, read these fully:
- .agents/plans/015-phase-3-modern-terminal-protocols.md
- docs/Spec.md lines 3644 through the end of Slice 8, covering the Phase 3 overview and
  color degradation baseline
- .agents/plans/024-phase-3-slice-8-color-degradation-baseline.md

Treat plan 015 as the shared contract and completed prior slices as source of truth.
Execute only plan 024. Do not implement OSC 52 clipboard, cursor styling, underline
extensions, Sixel, or Phase 4 view-layer work.

Write tests close to the production code they cover. Keep color degradation at the
renderer/SGR emission boundary: buffers keep semantic colors, and the active color
capability chooses the emitted SGR form. Run the validation commands from plan 024.

When complete, update plan progress, report changed files and validation results, then stop
and wait for review.
```

### Slice 9 prompt — OSC 52 clipboard

```text
Implement .agents/plans/025-phase-3-slice-9-osc-52-clipboard.md.

Before editing, read these fully:
- .agents/plans/015-phase-3-modern-terminal-protocols.md
- docs/Spec.md lines 3644 through the end of Slice 9, covering the Phase 3 overview and
  OSC 52 clipboard
- .agents/plans/025-phase-3-slice-9-osc-52-clipboard.md

Treat plan 015 as the shared contract and completed prior slices as source of truth.
Execute only plan 025. Do not implement cursor styling, underline extensions, clipboard
reads, Sixel, or Phase 4 view-layer work.

Write tests close to the production code they cover. Keep OSC 52 as a policy-gated
session side effect, disabled by default, never as frame rendering or automatic startup
behavior. Run the validation commands from plan 025.

When complete, update plan progress, report changed files and validation results, then stop
and wait for review.
```

### Slice 10 prompt — Cursor styling

```text
Implement .agents/plans/026-phase-3-slice-10-cursor-styling.md.

Before editing, read these fully:
- .agents/plans/015-phase-3-modern-terminal-protocols.md
- docs/Spec.md lines 3644 through the end of Slice 10, covering the Phase 3 overview and
  cursor styling
- .agents/plans/026-phase-3-slice-10-cursor-styling.md

Treat plan 015 as the shared contract and completed prior slices as source of truth.
Execute only plan 026. Do not implement underline extensions, OSC 52 clipboard reads,
Sixel, or Phase 4 view-layer work.

Write tests close to the production code they cover. Cursor styling must be explicit
application/session policy with lifecycle-owned restore behavior; draw frames must not
re-emit shape or color. The session/lifecycle seam must be ready for future focused
components to request cursor-style changes when the application has enabled cursor styling.
Run the validation commands from plan 026.

When complete, update plan progress, report changed files and validation results, then stop
and wait for review.
```

### Slice 11 prompt — Underline extensions

```text
Implement .agents/plans/027-phase-3-slice-11-underline-extensions.md.

Before editing, read these fully:
- .agents/plans/015-phase-3-modern-terminal-protocols.md
- docs/Spec.md lines 3644 through the end of Slice 11, covering the Phase 3 overview and
  underline extensions
- .agents/plans/027-phase-3-slice-11-underline-extensions.md

Treat plan 015 as the shared contract and completed prior slices as source of truth.
Execute only plan 027. Do not implement Sixel, cursor styling beyond any completed slice,
or Phase 4 view-layer work.

Write tests close to the production code they cover. Prefer the clean underline API over
source compatibility: remove the old boolean underline attribute if it still exists, update
demos/tests/call sites to `UnderlineStyle.single`, and add semantic underline variants,
underline colors, and precise `24`/`59` reset behavior. Run the validation commands from
plan 027.

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
- Focus, mouse, Kitty keyboard, and APC graphics reports are recognized only in normal
  parser mode.
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
  keyboard are application protocol modes. Kitty graphics is not a mode: there is nothing
  to enable, only teardown bytes.
- Cleanup may over-disable optional protocol modes and always includes the Kitty graphics
  delete-all sequence. It must never leave a mode enabled — or an image placed — after
  normal or abnormal exit.
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

Add one evolving example executable instead of seven small apps:

- Product and target: `Phase3ProtocolsDemo` in `Examples/Package.swift`.
- Source: `Examples/Sources/Phase3ProtocolsDemo/Phase3ProtocolsDemo.swift`.
- Dependencies: `ExampleSupport` and `TesseraTerminal`.
- Validation command: `swift build --package-path Examples --product Phase3ProtocolsDemo`.
- The app stays terminal-substrate-only. It writes directly through `Frame`, like the
  current examples, and does not introduce a view layer.

High-level wireframe:

```text
┌─ Phase3ProtocolsDemo ───────────────────────────────────────────────────────┐
│ q quit · 1 paste · 2 focus · 3 mouse · 4 keys · 5 links · 6 caps · 7 image  │
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
- Kitty graphics is never probed or transmitted by default. Apps opt in by calling the
  session/frame graphics API; teardown always over-cleans with delete-all, and blind
  emission is safe on terminals that ignore APC.

## Integrated validation sweep

Run narrow validation inside each slice first. After plan 027 is implemented, run:

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
