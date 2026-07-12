---
name: Phase 3 Slice 10 Cursor Styling
description:
  Add first-class session-scoped cursor shape and cursor color policy using DECSCUSR and
  OSC 12/112, with deterministic enter/apply/restore behavior and cleanup.
status: complete
created: 2026-07-07
updated: 2026-07-09
---

## Progress

- [x] **Phase 1 — Cursor style model and ANSI encoding**
  - [x] 1.1 Add cursor shape and color policy types
  - [x] 1.2 Encode DECSCUSR, OSC 12, and OSC 112 as semantic `ControlSequence` cases
  - [x] 1.3 Add exact byte encoder tests
- [x] **Phase 2 — Application/session policy resolution**
  - [x] 2.1 Add explicit cursor styling opt-in to `TerminalApplicationConfiguration`
  - [x] 2.2 Carry the resolved cursor style through `TerminalApplicationResolution` and
        `TerminalSession`
  - [x] 2.3 Add configuration and session resolution tests
- [x] **Phase 3 — Lifecycle application and cleanup**
  - [x] 3.1 Teach `ModeLifecycle` to enter, apply, normalize, and disable cursor styling
  - [x] 3.2 Include cursor style reset bytes in emergency cleanup only when Tessera owns
        cursor styling
  - [x] 3.3 Add lifecycle ordering, rollback, apply, and emergency cleanup tests
- [x] **Phase 4 — Demo and validation**
  - [x] 4.1 Add a cursor styling panel to `Phase3ProtocolsDemo`
  - [x] 4.2 Run the narrow validation commands for encoder, configuration, session,
        lifecycle, and demo coverage

## Overview

This plan implements `docs/Spec.md` Phase 3 Slice 10 after the docs slice has been merged.
Tessera should model cursor styling as application/session policy, not as arbitrary raw
terminal bytes in a frame. The app explicitly enables cursor styling for the session; once
enabled, live application or future view-layer focus changes use
`TerminalSession.setCursorStyle(_:)` through lifecycle reconciliation. The slice adds
shapes (`CSI Ps SP q`) and OSC 12 cursor color (`OSC 12;Pt BEL`), restores shape with
DECSCUSR `0`, restores cursor color with OSC 112, and includes those resets in
abnormal-exit cleanup only after an app explicitly opts in.

Read before editing:

1. `.agents/plans/015-phase-3-modern-terminal-protocols.md`
2. `docs/Spec.md` Phase 3 overview and `### Slice 10: Cursor styling`
3. This plan
4. Existing cursor/lifecycle code in `Sources/TesseraTerminal/Frame.swift`,
   `Sources/TesseraTerminal/TerminalSession.swift`,
   `Sources/TesseraTerminalANSI/ControlSequence.swift`, and
   `Sources/TesseraTerminalIO/ModeLifecycle.swift`

Current behavior already hides the cursor at the end of frames unless
`Frame.setCursorPosition(_:)` is called, then restores visibility on normal session exit
and in emergency cleanup. This slice must preserve that per-frame visibility behavior
while adding session-owned shape/color policy around it. Unsupported terminals are not
startup failures: because there is no reliable support probe for either DECSCUSR or OSC 12
in Tessera's current capability model, opted-in sequences are best-effort and ignored by
terminals that do not understand them.

Phase 4 may later let focused components declare cursor style requirements, such as a text
input requesting a steady bar while focused. This slice must provide the session/lifecycle
machinery those requests will use, but it must not implement the Phase 4 view API itself.

## Non-goals

- No Sixel work; Sixel remains out of scope for Phase 3 cursor styling.
- No arbitrary OSC color strings, raw cursor escape writes, or app-provided terminal byte
  payloads for cursor styling.
- No attempt to query and restore the user's exact pre-existing cursor color; OSC 12
  queries are not required, can block or vary by terminal, and do not fit the current
  bounded capability-probe model. Restore means terminal/user default via OSC 112.
- No per-cell or per-frame cursor styling. `Frame.setCursorPosition(_:)` continues to
  control visibility/position only; focused component requests use the live session setter
  rather than draw-buffer bytes.
- No terminal-name allowlist that treats passive identity hints as proof of support.
- No failure when cursor styling is unsupported by the terminal; local I/O write/flush
  errors still behave like existing mode lifecycle errors.
- No Windows console API cursor-shape/color implementation. Windows Terminal with VT
  enabled receives the same VT sequences; legacy console hosts may ignore them.

## Phase 1 — Cursor style model and ANSI encoding

**Goal**: Cursor styling has typed, semantic encoder coverage for shape and color, with no
escape hatch or caller-controlled OSC payloads.

### Step 1.1 — Add cursor shape and color policy types

- Files:
  - new `Sources/TesseraTerminalANSI/CursorStyle.swift`
  - `Sources/TesseraTerminalANSI/ControlSequence.swift`
  - `Sources/TesseraTerminalANSI/ANSIByteEncoding.swift` if its OSC helper must be reused
    or clarified
- Add these public value types in `TesseraTerminalANSI`, alphabetizing conformances as the
  surrounding codebase does:

  ```swift
  public enum CursorShape: Equatable, Hashable, Sendable {
    case defaultUserShape      // DECSCUSR 0
    case blinkingBlock         // DECSCUSR 1
    case steadyBlock           // DECSCUSR 2
    case blinkingUnderline     // DECSCUSR 3
    case steadyUnderline       // DECSCUSR 4
    case blinkingBar           // DECSCUSR 5
    case steadyBar             // DECSCUSR 6
  }

  public struct CursorColor: Equatable, Hashable, Sendable {
    public var red: UInt8
    public var green: UInt8
    public var blue: UInt8

    public init(red: UInt8, green: UInt8, blue: UInt8) {
      self.red = red
      self.green = green
      self.blue = blue
    }
  }

  public struct CursorStyle: Equatable, Hashable, Sendable {
    public var shape: CursorShape?
    public var color: CursorColor?

    public init(shape: CursorShape? = nil, color: CursorColor? = nil) {
      self.shape = shape
      self.color = color
    }
  }
  ```

- `shape == nil` means Tessera must not emit DECSCUSR for this session. `color == nil`
  means Tessera must not emit OSC 12 or OSC 112 for this session.
- `CursorShape.defaultUserShape` is allowed only as an explicit opt-in shape request or as
  the restore shape. It is not the same as `nil`; `nil` means untouched.
- `CursorColor` is RGB-only and encodes as `#RRGGBB`. Do not reuse `Color` directly for
  OSC 12: SGR defaults, 16-color names, and 256-color palette indexes are terminal palette
  semantics and should not be smuggled into xterm color strings.
- Acceptance: the new types compile in `TesseraTerminalANSI`, are `Hashable` so they can
  be stored in lifecycle modes, and do not expose arbitrary strings or raw bytes.

### Step 1.2 — Encode DECSCUSR, OSC 12, and OSC 112 as semantic `ControlSequence` cases

- Files:
  - `Sources/TesseraTerminalANSI/ControlSequence.swift`
  - `Tests/TesseraTerminalANSITests/ANSIEncoderTests.swift`
- Add semantic control-sequence cases:

  ```swift
  /// Reset the text cursor color to the terminal default using OSC 112.
  case resetCursorColor

  /// Set the text cursor color using OSC 12.
  case setCursorColor(CursorColor)

  /// Set the cursor shape using DECSCUSR (`CSI Ps SP q`).
  case setCursorShape(CursorShape)
  ```

- Keep enum cases and exhaustive break lists consistent with the current `ControlSequence`
  grouping. `setCursorShape` belongs in the cursor encoder group; OSC 12/112 belong in the
  OSC encoder group, not in `.raw`.
- DECSCUSR encoding:
  - `.defaultUserShape` -> `ESC [ 0 SP q`
  - `.blinkingBlock` -> `ESC [ 1 SP q`
  - `.steadyBlock` -> `ESC [ 2 SP q`
  - `.blinkingUnderline` -> `ESC [ 3 SP q`
  - `.steadyUnderline` -> `ESC [ 4 SP q`
  - `.blinkingBar` -> `ESC [ 5 SP q`
  - `.steadyBar` -> `ESC [ 6 SP q`
- OSC cursor-color encoding. Terminate with ST (`ESC \`), not BEL, reusing the existing
  `ANSIByteEncoding.appendOSC(_:terminator: .stringTerminator, …)` helper that OSC 8
  hyperlinks already use. ST is the ECMA-48 standard terminator, is silent if a parser
  desyncs (a stray BEL would beep/flash), and keeps both data-bearing OSCs in this
  codebase consistent. `.stringTerminator` is the two-byte `ESC \` (`0x1B 0x5C`), never
  the UTF-8-illegal single-byte C1 `0x9C`:
  - `.setCursorColor(CursorColor(red: 0x12, green: 0xAB, blue: 0xF0))` ->
    `ESC ] 12;#12ABF0 ST`
  - `.resetCursorColor` -> `ESC ] 112 ST`
  - Leave OSC 2 (window title) on BEL; migrating it is separate, pre-existing cleanup.
- Hex digits should be uppercase and exactly two digits per component.
- Do not add a `ControlSequence.raw` convenience for cursor styling.
- Acceptance: every new sequence is reachable through `ANSIEncoder.encode(_:)` and
  `ControlSequence.bytes`; no app-facing API needs to construct bytes manually.

### Step 1.3 — Add exact byte encoder tests

- File: `Tests/TesseraTerminalANSITests/ANSIEncoderTests.swift`
- Add table-driven Swift Testing coverage for all seven cursor shapes, one RGB cursor
  color, black (`#000000`), white (`#FFFFFF`), and cursor-color reset.
- Assert exact bytes, including the DECSCUSR space byte (`0x20`) before `q` and ST
  (`ESC \`, `0x1B 0x5C`) termination for OSC 12/112.
- Acceptance: the narrow ANSI tests fail before the implementation and pass after it.

## Phase 2 — Application/session policy resolution

**Goal**: Cursor styling is an explicit app/session opt-in carried through Tessera's
existing configuration and session-resolution path.

### Step 2.1 — Add explicit cursor styling policy to `TerminalApplicationConfiguration`

- File: `Sources/TesseraTerminal/TerminalApplicationConfiguration.swift`
- Add a public `cursorStyling` field typed as a dedicated policy enum, following the
  existing per-protocol policy convention in this file (`HyperlinkRenderingMode`,
  `KeyboardProtocolMode`, `MouseTrackingMode`, `CapabilityDetectionMode`). Do not invent a
  bespoke shape; mirror those types:

  ```swift
  public enum CursorStylingPolicy: Equatable, Sendable {
    /// Tessera emits no DECSCUSR/OSC 12/OSC 112 bytes and ignores cursor style requests.
    case disabled

    /// Tessera owns cursor styling. `default` is applied when no focused component or
    /// runtime request overrides it; `.enabled(default: nil)` owns styling for future
    /// dynamic requests but emits nothing at startup.
    case enabled(default: CursorStyle?)
  }
  ```

- Add `cursorStyling: CursorStylingPolicy = .disabled` to the intent initializer, keeping
  the disabled default so existing behavior emits no cursor-style bytes.
- The explicit `init(modes:)` initializer must round-trip cursor styling out of the mode
  set exactly as it already derives `enableBracketedPaste`/`mouseTracking`: derive
  `cursorStyling` from the resolved `.cursorStyle` mode (see Step 3.1), defaulting to
  `.disabled` when absent. Keep `modes` a faithful low-level view in both directions.
- In intent resolution, include `.cursorStyle(effectiveStyle)` only when policy is enabled
  and the effective default/requested style has at least one non-`nil` facet. If both
  `shape` and `color` are `nil`, treat the effective style like no active lifecycle mode.
- Do not gate this on `TerminalCapabilities.color`; `NO_COLOR` and SGR color-depth policy
  do not govern cursor shape/color. Cursor color is an explicit application request.
- Acceptance: default configuration resolves to the same base modes as today; enabled
  policy is visible in resolution/session state; cursor styling bytes appear only when an
  effective style is requested explicitly.

### Step 2.2 — Carry cursor styling policy and effective style through resolution/session

- Files:
  - `Sources/TesseraTerminal/TerminalApplicationConfiguration.swift`
  - `Sources/TesseraTerminal/TerminalSession.swift`
- Add package-level policy/introspection values to `TerminalApplicationResolution` so
  tests and demos can distinguish disabled, enabled/no-default, and currently effective
  style.
- Add `nonisolated public` session introspection for the configured policy and effective
  cursor style.
- Pass the resolved policy/style through
  `TerminalSession.withApplicationTerminal(configuration:io:environment:_:)` into the
  session initializer.
- Expose the live `TerminalSession.setCursorStyle(_:)` setter for enabled cursor-styling
  policy. It reconciles through `ModeLifecycle.apply`, preserves unrelated application
  modes and requested/effective/possibly-active lifecycle state, and never writes raw
  bytes from a view.
- Keep per-frame cursor visibility untouched: `TerminalSession.draw` still appends
  `cursorVisible(false)` when no frame cursor position is requested and
  `cursorVisible(true)` plus CUP when one is requested. It must not append shape/color on
  every draw.
- Acceptance: session introspection reports the configured policy and effective style, but
  draw output is unchanged unless lifecycle entered/applied cursor styling.

### Step 2.3 — Add configuration and session resolution tests

- Files:
  - `Tests/TesseraTerminalTests/TerminalCapabilityTests.swift`
  - `Tests/TesseraTerminalTests/TerminalSessionTests.swift`
- Add tests proving:
  - default intent and exact-mode configurations leave cursor styling disabled and do not
    add `.cursorStyle` to `modes`;
  - enabled policy with no default style is carried through resolution/session but emits
    no startup cursor-style bytes;
  - enabled policy with a shape-only default resolves to one `.cursorStyle` mode;
  - enabled policy with a color-only default resolves to one `.cursorStyle` mode;
  - `setCursorStyle(_:)` overrides or clears the default through the live serialized
    lifecycle transaction and then can restore the default style;
  - `withApplicationTerminal` exposes cursor-style policy/effective-style introspection.
- Update existing exact `TerminalApplicationResolution` expectations to include the new
  cursor styling policy/effective-style fields.
- Acceptance: existing resolution semantics for bracketed paste, focus, mouse, keyboard,
  hyperlinks, synchronized output, and capabilities are unchanged except for the added
  cursor styling policy/effective-style fields.

## Phase 3 — Lifecycle application and cleanup

**Goal**: Cursor styling is applied once when the app session acquires it, can be
reconciled through lifecycle `apply`, and is restored on normal, rollback, and abnormal
exits.

### Step 3.1 — Teach `ModeLifecycle` to enter, apply, normalize, and disable cursor styling

- File: `Sources/TesseraTerminalIO/ModeLifecycle.swift`
- Add `case cursorStyle(CursorStyle)` to `ModeLifecycle.Mode` and add a matching
  `.cursorStyle` acquisition slot.
- Add the slot after `.altScreen` and before `.bracketedPaste` in `acquisitionOrder`.
  Rationale: raw mode and alternate screen are fixed session setup; cursor style is an
  application-owned terminal presentation attribute that should be active before
  input-protocol modes and reset before leaving alternate screen on teardown.
- Model `.cursorStyle(CursorStyle)` on the existing `.mouseTracking(MouseTracking)`
  precedent already in this file — a payload-carrying mode collapsed to a single slot. Do
  NOT introduce a throwing `modesAlreadyActive` path for duplicates; that would be
  inconsistent with how mouse tracking (the direct analog) already tolerates a set holding
  more than one payload. Specifically:
  - `slot(for: .cursorStyle)` returns the single `.cursorStyle` slot, ignoring the payload
    (exactly like `slot(for: .mouseTracking)`).
  - Add a `requestedCursorStyle(in:)` extractor mirroring `requestedMouseTracking(in:)`;
    `mode(for: .cursorStyle, in:)` reconstructs the winning mode through it.
  - `normalized(_:)` strips all `.cursorStyle` modes, drops any whose `shape` and `color`
    are both `nil`, then re-inserts at most one. Two distinct styles is a resolution bug,
    not a lifecycle error: pick deterministically and rely on configuration resolving
    exactly one. There is no "broadest wins" superset for cursor styles as there is for
    mouse granularity, so document the deterministic tiebreak the extractor uses.
  - The extractor's exhaustive `switch` must add `.cursorStyle` to every existing
    `case .rawMode, .altScreen, …:` continue arm so the code still compiles.
- Note: `normalized(_:)` and `requestedMouseTracking(in:)` are duplicated in BOTH
  `ModeLifecycle.swift` and `TerminalApplicationConfiguration.swift`. Update both copies,
  and keep the config copy in sync so `init(modes:)` round-trips cursor styling (Step
  2.1).
- Update `slot(for:)`, `mode(for:in:)`, `normalized(_:)`, `isSupported(_:)`, fixed/
  application mode filtering in `apply(applicationModes:)`, `enable(_:)`, and
  `disable(_:)`.
- `enable(.cursorStyle(style))` must build one flush containing, in order:
  1. `setCursorShape(style.shape)` if `shape != nil`
  2. `setCursorColor(style.color)` if `color != nil`
- `disable(.cursorStyle(style))` must build one flush containing, in order:
  1. `setCursorShape(.defaultUserShape)` if `shape != nil`
  2. `resetCursorColor` if `color != nil`
- `apply(applicationModes:)` should allow `.cursorStyle` along with bracketed paste,
  focus, mouse, and kitty keyboard. It should reject raw mode and alternate screen exactly
  as today.
- `apply` must be idempotent: if the requested cursor style equals the active one, emit no
  bytes (spec: "applying the same style is idempotent"). When switching styles, reset the
  facets the old style owned before applying the new style's facets. A correct-but-simple
  implementation disables the old `.cursorStyle` mode via the reversed acquisition pass
  and enables the new one via the forward pass.
- Refinement (optional, preferred): diff at the facet level so a shape-only change does
  not reset then immediately re-set an unchanged color (a visible cursor-color flash).
  Reset only facets the new style drops or changes; leave unchanged facets alone.
- Acceptance: lifecycle active modes include cursor styling only after successful enable;
  failed writes roll back like other application modes and leave `exit()` safe.

### Step 3.2 — Include cursor style reset bytes in emergency cleanup only when Tessera owns cursor styling

- Files:
  - `Sources/TesseraTerminalIO/ModeLifecycle.swift`
  - `Tests/TesseraTerminalIOTests/CleanupRegistryTests.swift`
  - `Tests/TesseraTerminalIOTests/ModeLifecycleTests.swift`
- Extend `installCleanup()` so teardown bytes include cursor style resets only when
  `requestedCursorStyle(in: modes.union(requestedModes))` yields a style with an owned
  facet. Match the existing mouse-tracking cleanup, which uses
  `requestedMouseTracking(in: modes.union(requestedModes))` rather than `contains` — the
  payload means exact `.contains(.cursorStyle(style))` is the wrong test:
  - `setCursorShape(.defaultUserShape)` if any requested/active cursor style set a shape;
  - `resetCursorColor` if any requested/active cursor style set a color.
- Place cursor style reset bytes before `exitAltScreen` and before the final unconditional
  `cursorVisible(true)` in the existing cleanup order. Keep Kitty Graphics delete-all
  first and keep cursor visibility restore last.
- Do not emit OSC 112 or DECSCUSR 0 for sessions that never opted into cursor styling;
  otherwise Tessera would overwrite the user's pre-existing terminal cursor preferences
  after an unrelated app session.
- Normal `TerminalSession.withApplicationTerminal` should still call
  `restoreCursorVisibility()` before `lifecycle.exit()` as it does now. `lifecycle.exit()`
  then resets shape/color and leaves modes; visibility restore in emergency cleanup
  remains the last-resort backstop for abnormal exits.
- Acceptance: emergency cleanup is broad enough to restore owned cursor facets after
  process death but narrow enough not to touch unowned cursor style/color.

### Step 3.3 — Add lifecycle ordering, rollback, apply, and emergency cleanup tests

- Files:
  - `Tests/TesseraTerminalIOTests/ModeLifecycleTests.swift`
  - `Tests/TesseraTerminalIOTests/CleanupRegistryTests.swift`
  - `Tests/TesseraTerminalTestSupport/InMemoryTerminalDevice.swift` only if additional
    test seams are needed
- Add tests proving:
  - entering `[.rawMode, .altScreen, .cursorStyle(...), .bracketedPaste]` enables raw,
    enters alt screen, then flushes cursor style before bracketed paste;
  - exit resets cursor style before leaving alternate screen and before raw mode restore;
  - shape-only style does not emit OSC 12/112;
  - color-only style does not emit DECSCUSR;
  - switching styles through `apply(applicationModes:)` resets old owned facets before
    applying new facets;
  - failed cursor style enable rolls back previously acquired modes and clears cleanup
    state like other enable failures;
  - emergency cleanup bytes include DECSCUSR 0 and/or OSC 112 only for sessions that
    requested those facets;
  - unsupported terminals are represented by ignored bytes/no responses, not by capability
    or startup failures.
- Acceptance: tests cover normal success, dynamic apply, failure rollback, and
  abnormal-exit cleanup semantics.

## Phase 4 — Demo and validation

**Goal**: The Phase 3 demo exposes cursor styling as an explicit opt-in and narrow
commands verify the slice.

### Step 4.1 — Add a cursor styling panel to `Phase3ProtocolsDemo`

- File: `Examples/Sources/Phase3ProtocolsDemo/Phase3ProtocolsDemo.swift`
- Keep the shared live-control legend (`d/y/h/t/f/k/s/c/x`, with global `q/g/m`) rather
  than numeric panel navigation; cursor presentation uses the session's live setter.
- Configure the demo's `TerminalApplicationConfiguration` with a visible opt-in style, for
  example:

  ```swift
  cursorStyling: .enabled(
    default: CursorStyle(
      shape: .steadyBar,
      color: CursorColor(red: 0x7D, green: 0xFF, blue: 0xAF)
    )
  )
  ```

- The panel should explain that cursor shape/color are session policy and are restored on
  exit; it should not call `Frame.writeRaw` or write `RawTerminalPayload` bytes.
- Keep `Frame.setCursorPosition(_:)` examples focused on cursor position/visibility, not
  shape/color.
- Acceptance: the example app compiles after implementation and demonstrates opt-in cursor
  styling without raw writes.

### Step 4.2 — Run narrow validation commands

- Commands to run after implementation, not while drafting this plan:

  ```sh
  swift test --filter TesseraTerminalANSITests/ANSIEncoderTests
  swift test --filter TesseraTerminalTests/TerminalCapabilityTests
  swift test --filter TesseraTerminalTests/TerminalSessionTests
  swift test --filter TesseraTerminalIOTests/ModeLifecycleTests
  swift test --filter TesseraTerminalIOTests/CleanupRegistryTests
  swift build --package-path Examples --product Phase3ProtocolsDemo
  ```

- If a narrow filter name needs adjustment for Swift Testing discovery, use the nearest
  package-supported filter that runs only the touched test file or target.
- Do not run project-wide suites unless a narrow command exposes a cross-target issue that
  cannot be isolated.
- Acceptance: all touched targets pass their narrow checks and no
  formatter/linter/project-wide command is required by this plan.

## Acceptance Criteria

- `docs/Spec.md` contains `### Slice 10: Cursor styling` before implementation starts, and
  implementers have read the umbrella plan, Phase 3 overview, the slice, and this plan.
- Cursor styling is represented by public semantic APIs (`CursorShape`, `CursorColor`,
  `CursorStyle`, and `ControlSequence` cases), not raw writes.
- DECSCUSR encodes all seven supported values exactly, including `CSI Ps SP q`.
- OSC 12 accepts only RGB cursor colors encoded as `#RRGGBB`; OSC 112 resets cursor color.
- Default configuration emits no cursor shape/color bytes and does not reset cursor color
  on exit.
- Explicit opt-in applies cursor style after raw/alt-screen setup and restores owned
  shape/color before alternate-screen teardown.
- Normal exit, failed startup rollback, dynamic lifecycle apply, and emergency cleanup
  have deterministic reset semantics.
- Unsupported terminals do not make session startup fail solely because cursor styling is
  requested.
- `Frame.setCursorPosition(_:)` continues to control only cursor visibility and position;
  shape/color are session/runtime policy, including future focused-component requests.
- Sixel remains out of scope.

## References

- `docs/Spec.md` Phase 3 overview and Slice 10 cursor styling section.
- `.agents/plans/015-phase-3-modern-terminal-protocols.md` umbrella plan.
- Existing Tessera code: `Sources/TesseraTerminal/Frame.swift`,
  `Sources/TesseraTerminal/TerminalSession.swift`,
  `Sources/TesseraTerminal/TerminalApplicationConfiguration.swift`,
  `Sources/TesseraTerminalANSI/ControlSequence.swift`,
  `Sources/TesseraTerminalIO/ModeLifecycle.swift`,
  `Sources/TesseraTerminalIO/CleanupRegistry.swift`.
- Existing Tessera tests: `Tests/TesseraTerminalANSITests/ANSIEncoderTests.swift`,
  `Tests/TesseraTerminalTests/TerminalCapabilityTests.swift`,
  `Tests/TesseraTerminalTests/TerminalSessionTests.swift`,
  `Tests/TesseraTerminalIOTests/ModeLifecycleTests.swift`,
  `Tests/TesseraTerminalIOTests/CleanupRegistryTests.swift`.
- Ratatui precedent: `~/Developer/ratatui/ratatui/main/ratatui-core/src/terminal/frame.rs`
  documents cursor position as frame-scoped and shape/style as separate from frame
  drawing; `~/Developer/ratatui/ratatui/main/ratatui-core/src/terminal/cursor.rs` warns
  that direct cursor APIs can be overwritten by draw.
- Crossterm precedent: `crossterm::cursor::SetCursorStyle` encodes `ESC [ 0 q` through
  `ESC [ 6 q` for default, block, underline, and bar shapes.
- XTerm control sequences: DECSCUSR (`CSI Ps SP q`) for cursor style, OSC 12 for text
  cursor color, and OSC 112 for resetting text cursor color.
