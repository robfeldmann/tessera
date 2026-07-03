---
name: Phase 3 Slice 4 Kitty Keyboard Protocol
description:
  Add Kitty keyboard parsing and lifecycle support, expand key metadata, and introduce
  dynamic application-mode reconciliation for Phase 4 requirements.
status: in-review
created: 2026-07-02
updated: 2026-07-02
---

## Progress

- [ ] **Phase 1 — Keyboard API expansion**
  - [ ] 1.1 Add key event kind and richer modifier support
  - [ ] 1.2 Add Kitty keyboard option-set values and encoder bytes
- [ ] **Phase 2 — Kitty keyboard parsing**
  - [ ] 2.1 Add colon-aware CSI parameter parsing
  - [ ] 2.2 Decode Kitty key reports without regressing legacy input
- [ ] **Phase 3 — Lifecycle, dynamic apply, and example app**
  - [ ] 3.1 Enable, disable, and cleanup `.kittyKeyboard`
  - [ ] 3.2 Add `ModeLifecycle.apply(applicationModes:)`
  - [ ] 3.3 Add the keyboard panel to `Phase3ProtocolsDemo`
  - [ ] 3.4 Run narrow parser, encoder, lifecycle, session, and example checks

## Overview

This plan implements `docs/Spec.md` Phase 3 Slice 4. Kitty keyboard is the largest input
slice because it changes keyboard semantics rather than adding an orthogonal event type.
It adds key event kind, richer modifiers, Kitty protocol enable/disable bytes, parser
support for Kitty key reports, and the dynamic application-mode reconciliation that Phase
4 view requirements will need.

This plan does not remove the Phase 2 legacy parser. Legacy ESC, CSI, SS3, UTF-8, and bare
Escape behavior remain the fallback path for terminals that do not send Kitty reports.

## Phase 1 — Keyboard API expansion

**Goal**: public keyboard data can represent press/repeat/release and Kitty-only modifier
bits without breaking existing key-event consumers.

### Step 1.1 — Add key event kind and richer modifier support

- Files:
  - `Sources/TesseraTerminalInput/Key.swift`
  - `Sources/TesseraTerminalInput/Modifiers.swift`
  - `Tests/TesseraTerminalInputTests/InputParserTests.swift`
- Add `KeyEventKind`:

```swift
public enum KeyEventKind: Equatable, Sendable {
  case press
  case repeat
  case release
}
```

- Add `public var kind: KeyEventKind` to `Key`.
- Update `Key.init` with a default `kind: .press` so existing call sites stay source
  compatible.
- Preserve existing equality semantics through the new stored property. A repeated key is
  not equal to a pressed key.
- Extend `Modifiers` with additional Kitty-capable flags:
  - `.super`
  - `.hyper`
  - `.meta`
- Keep existing raw bits for `.shift`, `.alt`, and `.control` stable.
- Add raw bits for new modifiers above the current bits. Do not reorder existing bits.
- Update parser event-log formatting so key events include `kind` only when it is not the
  default press, or include it consistently if the snapshot output is clearer.

Acceptance:

- Existing tests that construct `Key(code:modifiers:)` still compile.
- Tests prove `.press`, `.repeat`, and `.release` are distinguishable values.
- Tests prove new modifier flags compose with existing flags.

### Step 1.2 — Add Kitty keyboard option-set values and encoder bytes

- Files:
  - new `Sources/TesseraTerminalANSI/KittyKeyboardFlags.swift`
  - `Sources/TesseraTerminalANSI/ControlSequence.swift`
  - `Tests/TesseraTerminalANSITests/ANSIEncoderTests.swift`
- Add a public `KittyKeyboardFlags: OptionSet, Equatable, Sendable` value type with the
  protocol flags Tessera can request:
  - `disambiguateEscapeCodes` = 1
  - `reportEventTypes` = 2
  - `reportAlternateKeys` = 4
  - `reportAllKeysAsEscapeCodes` = 8
  - `reportAssociatedText` = 16
- Add a conservative default used by lifecycle:

```swift
public static let tesseraDefault: Self = [
  .disambiguateEscapeCodes,
  .reportEventTypes,
  .reportAlternateKeys,
]
```

- Do not enable `reportAllKeysAsEscapeCodes` by default in this plan. It changes ordinary
  text input shape enough that capability policy should decide it later.
- Add `case pushKittyKeyboard(KittyKeyboardFlags)` and `case popKittyKeyboard` to
  `ControlSequence`.
- Encode push as `ESC [ > {flags} u`.
- Encode pop as `ESC [ < u`.
- Add exact byte tests for default flags, custom flag combinations, and pop.

Acceptance:

- Encoder tests pin the bytes for every new Kitty control-sequence case.
- Lifecycle code never writes raw Kitty keyboard escape strings.

## Phase 2 — Kitty keyboard parsing

**Goal**: valid Kitty key reports produce richer `.key` events and invalid or unsupported
CSI reports remain lossless `.unknown` events.

### Step 2.1 — Add colon-aware CSI parameter parsing

- File: `Sources/TesseraTerminalInput/InputParser.swift`.
- The current `csiParameterValues(_:)` parses semicolon-separated integers only. Kitty
  reports can contain subparameters separated by `:`.
- Add a small private parser for CSI parameters that preserves:
  - full raw CSI bytes for unknown fallback
  - semicolon-separated parameters
  - colon-separated subparameters
  - missing parameter values where the protocol permits defaults
- Keep this helper private until a public parser type is justified.
- Existing legacy key parsing may continue to use the old integer helper if that keeps the
  diff smaller. Do not rewrite legacy parsing for style.

Acceptance:

- Legacy CSI and SS3 tests pass unchanged.
- New unit tests cover colon subparameters, empty subparameters, malformed integers, and
  raw-byte preservation for `.unknown`.

### Step 2.2 — Decode Kitty key reports without regressing legacy input

- Files:
  - `Sources/TesseraTerminalInput/InputParser.swift`
  - `Sources/TesseraTerminalInput/KeyCode.swift`
  - `Tests/TesseraTerminalInputTests/InputParserTests.swift`
- Decode Kitty key reports with final byte `u`.
- Interpret the first parameter as the primary key code.
- Interpret the second parameter as Kitty modifiers, where the wire value is offset by
  one. Subtract one before mapping bits into `Modifiers`.
- Interpret event type subparameter values when present:
  - 1 = press
  - 2 = repeat
  - 3 = release
- Missing event type defaults to `.press`.
- Map Unicode scalar key codes to `.character(Character)` when representable.
- Map standard special keys to existing `KeyCode` values where possible.
- Add only the extra `KeyCode` cases needed to represent tested Kitty special keys. Do not
  add a large untested enum dump.
- Preserve alternate-key and associated-text subparameters as non-public parser inputs for
  now unless a concrete public use is implemented and tested in this slice.
- Malformed Kitty reports emit `.unknown(rawBytes)`.
- Kitty-looking reports inside bracketed paste remain paste payload.

Add parser tests for:

- printable character with no modifiers
- printable character with shift, alt, control, super, hyper, and meta
- combined modifier bitmasks
- press, repeat, and release event kinds
- Escape disambiguation through a Kitty report
- Tab, Enter, Backspace, and arrow keys if represented by Kitty reports
- malformed modifier values become `.unknown`
- malformed event-kind values become `.unknown`
- missing optional values use documented defaults
- byte-by-byte Kitty report
- Kitty report between mouse and focus events
- Kitty-looking sequence inside paste payload
- legacy Phase 2 sequences still decode as before

Use inline event-log snapshots for full streams and direct assertions for individual `Key`
fields.

Acceptance:

- Valid Kitty key reports surface richer key metadata.
- Terminals that only emit legacy sequences remain supported.

## Phase 3 — Lifecycle, dynamic apply, and example app

**Goal**: Kitty keyboard mode can be requested safely, cleaned up reliably, and changed
dynamically alongside the other Phase 3 application modes.

### Step 3.1 — Enable, disable, and cleanup `.kittyKeyboard`

- Files:
  - `Sources/TesseraTerminalIO/ModeLifecycle.swift`
  - `Tests/TesseraTerminalIOTests/ModeLifecycleTests.swift`
- Move `.kittyKeyboard` out of the unsupported path.
- Extend `acquisitionOrder` after mouse tracking: raw mode, alternate screen, bracketed
  paste, focus events, mouse tracking, Kitty keyboard.
- Enable with `ControlSequence.pushKittyKeyboard(.tesseraDefault)`.
- Disable with `ControlSequence.popKittyKeyboard`.
- Cleanup bytes include Kitty pop whenever the mode was requested or active.
- Rollback after partial startup pops Kitty keyboard if it was pushed.
- Keep Kitty keyboard out of `TerminalApplicationConfiguration.default` until plan 021
  settles capability policy.

Add lifecycle tests for:

- explicit startup emits Kitty push after other optional modes
- teardown emits Kitty pop before mouse, focus, and paste disable bytes
- cleanup bytes include Kitty pop for Kitty-enabled sessions
- rollback pops Kitty when later startup work fails
- default configuration still omits Kitty keyboard

Acceptance:

- `.kittyKeyboard` works when requested.
- Cleanup is symmetric with stack-shaped Kitty enablement.

### Step 3.2 — Add `ModeLifecycle.apply(applicationModes:)`

- Files:
  - `Sources/TesseraTerminalIO/ModeLifecycle.swift`
  - `Sources/TesseraTerminal/TerminalSession.swift`
  - `Tests/TesseraTerminalIOTests/ModeLifecycleTests.swift`
  - `Tests/TesseraTerminalTests/TerminalSessionTests.swift`
- Add a public or package-visible lifecycle method that changes only application protocol
  modes after startup.
- Valid application modes:
  - `.bracketedPaste`
  - `.focusEvents`
  - `.mouseTracking`
  - `.kittyKeyboard`
- Reject `.rawMode` and `.altScreen`; those remain session lifecycle modes.
- Compute deltas against currently active application modes:
  - disabling modes use reverse acquisition order
  - enabling modes use acquisition order
  - no-op apply emits no bytes
- Update registered cleanup bytes after every successful apply.
- If a partial apply fails, leave lifecycle state consistent with the operations that
  actually succeeded and make a later `exit()` still safe.
- Expose a `TerminalSession` method only if it is needed before Phase 4. Otherwise keep
  the lifecycle API package-scoped and add tests through package seams.

Add tests for:

- enabling one application mode after startup
- disabling one application mode after startup
- switching mouse and Kitty together uses deterministic order
- applying the same set twice emits no bytes
- rejecting raw mode and alternate screen
- cleanup registry reflects the newest active application modes
- failure during apply remains safe to exit

Prefer snapshot-style transcripts for byte order.

Acceptance:

- Phase 4 can request protocol-mode changes without touching raw mode or alternate screen.
- Session-fixed modes are unrepresentable through dynamic apply.

### Step 3.3 — Add the keyboard panel to `Phase3ProtocolsDemo`

- File: `Examples/Sources/Phase3ProtocolsDemo/Phase3ProtocolsDemo.swift`.
- Run the demo with a configuration that requests `.kittyKeyboard` explicitly for this
  panel demo. Plan 021 decides whether Kitty becomes default.
- Add panel navigation: `1` paste, `2` focus, `3` mouse, `4` keys.
- Show the latest key code, modifiers, and event kind.
- Show whether the event looked legacy or Kitty only if that distinction is observable
  without adding public parser internals. Otherwise show the semantic key only.
- Keep raw unknown events in the shared log so unsupported Kitty terminals are visible.

Wireframe:

```text
Phase3ProtocolsDemo — Keyboard                                   80x24
q quit · 1 paste · 2 focus · 3 mouse · 4 keys · press keys now

Latest key
  code: character("K")
  kind: repeat
  modifiers: shift+super

Kitty protocol notes
  Press Escape, Tab, arrows, modified letters, and hold a key for repeat.
  Unsupported terminals should still show legacy key events below.

Recent events
  0042 key code=escape modifiers=none kind=press
  0043 key code=character("k") modifiers=super kind=press
  0044 key code=character("k") modifiers=super kind=repeat
```

Acceptance:

- The panel demonstrates richer key metadata where the terminal supports Kitty keyboard.
- Legacy terminals still produce useful key events.

### Step 3.4 — Run narrow parser, encoder, lifecycle, session, and example checks

Run:

```fish
swift test --filter TesseraTerminalInputTests
swift test --filter TesseraTerminalANSITests
swift test --filter TesseraTerminalIOTests
swift test --filter TesseraTerminalTests
swift build --package-path Examples --product Phase3ProtocolsDemo
just quality changed
```

Acceptance:

- Kitty tests pass with paste, focus, mouse, and legacy input tests still green.
- Dynamic application-mode apply is covered before Phase 4 depends on it.
