---
name: Phase 3 Slice 9 OSC 52 Clipboard
description:
  Add policy-gated OSC 52 clipboard writes with semantic encoding, session integration,
  multiplexer-aware defaults, tests, docs, and demo coverage.
status: in-review
created: 2026-07-07
updated: 2026-07-07
---

<!-- Allowed status values: planning, in-review, pending, in-progress, complete. -->

## Progress

- [ ] **Phase 1 — Clipboard model and OSC 52 encoder**
  - [ ] 1.1 Add semantic clipboard value types
  - [ ] 1.2 Encode OSC 52 writes exactly and safely
- [ ] **Phase 2 — Policy, configuration, and session integration**
  - [ ] 2.1 Add safe default clipboard policy to application configuration
  - [ ] 2.2 Add session-scoped clipboard write API and result semantics
  - [ ] 2.3 Handle SSH, tmux, and screen-oriented behavior through explicit policy
- [ ] **Phase 3 — Tests, docs, and example updates**
  - [ ] 3.1 Add focused encoder, policy, and session tests
  - [ ] 3.2 Update docs and `Phase3ProtocolsDemo`
  - [ ] 3.3 Run narrow validation commands

## Overview

This plan implements `docs/Spec.md` Phase 3 Slice 9. OSC 52 clipboard writes are
session-scoped terminal side effects: they send base64-encoded bytes to the terminal host
clipboard and have no visible cell footprint, no frame lifetime, and no terminal
acknowledgement. Because clipboard writes can surprise or exfiltrate user data, Tessera
must default to denied, require explicit application and user intent, bound payload size,
and report denials without emitting bytes. Before editing, read
`.agents/plans/015-phase-3-modern-terminal-protocols.md`, the Phase 3 overview in
`docs/Spec.md`, the `docs/Spec.md` Slice 9 section, and this plan.

## Non-goals

- Do not implement OSC 52 clipboard reads or queries (`Pd = ?`). Clipboard reads are a
  different security surface and remain out of scope.
- Do not add native pasteboard integration (`NSPasteboard`, Win32 clipboard APIs,
  Wayland/X11 APIs). This slice is terminal-protocol-only.
- Do not add Sixel, iTerm2 file transfer, OSC 1337, or any other unrelated terminal
  protocol.
- Do not make clipboard writes frame-scoped, renderer-scoped, or buffer-backed.
- Do not silently bypass tmux/screen/user terminal clipboard policy.
- Do not chunk oversized clipboard payloads. OSC 52 chunking is not a portable contract
  for terminal clipboard writes; reject before writing instead.

## Phase 1 — Clipboard model and OSC 52 encoder

**Goal**: `TesseraTerminalANSI` can represent a safe clipboard write and encode exactly
one OSC 52 sequence without accepting pre-encoded or delimiter-bearing payloads.

### Step 1.1 — Add semantic clipboard value types

- Files:
  - new `Sources/TesseraTerminalANSI/Clipboard.swift`
  - `Sources/TesseraTerminalANSI/ControlSequence.swift`
  - `Tests/TesseraTerminalANSITests/ANSIEncoderTests.swift` or a focused new
    `ClipboardTests.swift` in the same test target
- Add public, `Equatable`, `Hashable` where practical, `Sendable` value types:

```swift
public enum ClipboardTarget: Equatable, Hashable, Sendable {
  case clipboard       // Pc character "c"
  case primary         // Pc character "p"
  case secondary       // Pc character "q"
  case select          // Pc character "s"
  case cutBuffer(UInt8) // 0...7 only
}

public struct ClipboardSelection: Equatable, Hashable, Sendable {
  public static let clipboard: Self
  public static let primary: Self
  public static let clipboardAndPrimary: Self

  public let targets: [ClipboardTarget]
}

public struct ClipboardWrite: Equatable, Sendable {
  public let selection: ClipboardSelection
  public let bytes: [UInt8]
}
```

- Keep `ClipboardSelection` non-empty in the semantic API. Xterm assigns an empty `Pc` a
  configurable primary/clipboard plus cut-buffer meaning; Tessera should not make that
  surprising default easy.
- Preserve target order in `ClipboardSelection`. Crossterm documents that terminals differ
  for multi-target strings such as `cp` versus `pc`, so order is observable behavior.
- Validate `cutBuffer` is `0...7` and reject duplicate targets unless an implementation
  has a specific, tested reason to preserve duplicates.
- Expose the safe presets (`.clipboard`, `.primary`, `.clipboardAndPrimary`) as static
  `let`s, and gate custom target lists behind a failable
  `public init?(_ targets: [ClipboardTarget])` that returns `nil` for empty lists,
  out-of-range `cutBuffer`, and duplicate targets. "Invalid construction fails" then has
  one concrete meaning tests can assert against, and no trapping/`fatalError` path reaches
  callers.
- Add convenience initializers for `String` by storing the string's UTF-8 bytes. Also
  allow byte payloads for applications that intentionally copy non-text bytes; base64
  makes the OSC syntax safe either way.
- Do not accept pre-base64 strings through the semantic API. The encoder owns base64 so
  the byte-count limit and exact escaping contract stay centralized.

Acceptance:

- `ClipboardSelection` cannot represent empty or invalid `Pc` data through public safe
  initializers.
- String and byte payloads preserve caller data exactly before base64 encoding.
- The type names leave room for future read/query support without naming this first write
  primitive as a general clipboard API.

### Step 1.2 — Encode OSC 52 writes exactly and safely

- Files:
  - `Sources/TesseraTerminalANSI/ANSIByteEncoding.swift`
  - `Sources/TesseraTerminalANSI/ControlSequence.swift`
  - `Tests/TesseraTerminalANSITests/ANSIEncoderTests.swift` or
    `Tests/TesseraTerminalANSITests/ClipboardTests.swift`
- Add a new control sequence case in alphabetical order, for example:

```swift
public enum ControlSequence: Equatable, Sendable {
  case copyToClipboard(ClipboardWrite)
}
```

- Add the case to every exhaustive `ControlSequence.encode*` switch. It should encode in
  `encodeOSC`, not `encodePayload`, because this is a semantic terminal operation rather
  than an arbitrary raw escape hatch.
- Encode one OSC 52 write as:

```text
ESC ] 52 ; <Pc> ; <RFC-4648-base64-payload> ESC \
```

using ST termination (`ESC \\`) to match the existing OSC 8 policy. Do not use BEL unless
the implementation adds an explicit terminator choice and tests both.

- Use RFC 4648 standard base64 with padding. Swift's `Data(bytes).base64EncodedString()`
  is acceptable; if used, keep the `Foundation` import local to the new clipboard file or
  encoder helper.
- Add a private byte helper if useful, such as
  `ANSIByteEncoding.appendOSC52(selection:bytes:into:)`, but keep base64 and `Pc` assembly
  behind tested semantic types.
- Exact byte tests:
  - `"hello"` to `.clipboard` encodes `ESC ] 52 ; c ; aGVsbG8= ESC \\`.
  - primary selection uses `p`.
  - `clipboardAndPrimary` preserves target order as `cp`.
  - bytes containing BEL, ESC, NUL, newline, and non-UTF-8 values are base64 encoded and
    cannot terminate or branch the OSC sequence.
  - empty payload behavior is deliberate: either reject at `ClipboardWrite` initialization
    or encode an empty base64 field only if tests and docs call out that it clears/sets an
    empty selection in terminal implementations.

Acceptance:

- OSC 52 bytes match the xterm wire shape exactly.
- Caller data never enters the OSC body unencoded.
- Raw clipboard escape bytes remain possible only through `RawTerminalPayload`, not
  through the semantic clipboard API.

## Phase 2 — Policy, configuration, and session integration

**Goal**: applications get a session-scoped clipboard write API that is denied by default,
requires explicit app/user intent, handles nested terminal policy predictably, and never
pretends terminal acceptance is observable.

### Step 2.1 — Add safe default clipboard policy to application configuration

- Files:
  - `Sources/TesseraTerminal/TerminalApplicationConfiguration.swift`
  - `Sources/TesseraTerminal/TerminalCapabilities.swift` if exposing advisory display
    state
  - `Sources/TesseraTerminal/TerminalCapabilityDetector.swift` if adding a capability
    field
  - `Tests/TesseraTerminalTests/TerminalCapabilityTests.swift`
- Add a public policy with a denied default. Suggested shape:

```swift
public enum ClipboardWriteMode: Equatable, Sendable {
  case disabled
  case enabled(ClipboardWritePolicy)
}

public struct ClipboardWritePolicy: Equatable, Sendable {
  public var maximumPayloadBytes: Int
  public var allowedTargets: Set<ClipboardTarget>
  public var allowsNestedTerminalPassthrough: Bool
}
```

- Add `public var clipboardWriting: ClipboardWriteMode` to
  `TerminalApplicationConfiguration` and carry it through `TerminalApplicationResolution`
  into `TerminalSession`.
- Set `.default` and both `TerminalApplicationConfiguration` initializers to
  `clipboardWriting: .disabled` unless the caller passes an explicit value. Clipboard is
  more sensitive than OSC 8 hyperlinks and must not turn on automatically.
- The first enabled preset should be conservative:
  - `maximumPayloadBytes`: 64 KiB raw payload bytes before base64.
  - `allowedTargets`: `[.clipboard]`.
  - `allowsNestedTerminalPassthrough`: `false`.
- Add `public var osc52Clipboard: CapabilityStatus` to `TerminalCapabilities`, defaulting
  to `.notDetectable` for parity with `osc8Hyperlinks`, so the capabilities panel can list
  every Phase 3 protocol uniformly. Never set it to `.supported`: there is no portable
  acknowledgement for OSC 52 write success, and a terminal or multiplexer may ignore or
  deny it silently. Passive detection and active probes must leave it `.notDetectable`.
- Note the base64 expansion when documenting `maximumPayloadBytes`: a 64 KiB raw cap
  becomes roughly 87 KiB of base64 on the wire, and some terminals/multiplexers bound the
  OSC payload further. The value is policy, not a protocol guarantee; keep it
  configurable.
- Existing capability behavior must remain conservative: no startup failure because
  clipboard support is unknown or denied.

Acceptance:

- Existing applications receive no clipboard-write capability unless they opt in.
- Policy is visible on the session for examples/debug panels without changing mode
  lifecycle behavior.
- Capability detection does not claim OSC 52 write support from terminal names alone.

### Step 2.2 — Add session-scoped clipboard write API and result semantics

- Files:
  - `Sources/TesseraTerminal/TerminalSession.swift`
  - `Sources/TesseraTerminal/Frame.swift` only if adding documentation that clipboard is
    intentionally absent from `Frame`
  - `Sources/TesseraTerminalTestSupport/InMemoryTerminalDevice.swift` if event formatting
    needs a clipboard-friendly name
  - `Tests/TesseraTerminalTests/TerminalSessionTests.swift`
- Add public result and denial types in `TesseraTerminal` or `TesseraTerminalANSI`
  depending on dependency direction:

```swift
public enum ClipboardWriteResult: Equatable, Sendable {
  case sent(bytesWritten: Int)
  case denied(ClipboardWriteDenialReason)
}

public enum ClipboardWriteDenialReason: Equatable, Sendable {
  case disabledByConfiguration
  case missingUserIntent
  case selectionNotAllowed(ClipboardSelection)
  case payloadTooLarge(actualBytes: Int, maximumBytes: Int)
  case nestedTerminalRequiresExplicitPassthrough(TerminalIdentity)
}

public enum ClipboardUserIntent: Equatable, Sendable {
  case userInitiated
}
```

- Add `TerminalSession.copyToClipboard` overloads for strings and bytes. Default
  `selection: ClipboardSelection = .clipboard` so the common call is
  `copyToClipboard("text", intent: .userInitiated)`. Require the caller to pass
  `intent: .userInitiated`; do not provide a no-intent overload. This cannot prove a human
  clicked a button, but it makes unattended clipboard writes explicit and testable.
- On denial, return `.denied(...)` and write no bytes to `PlatformIO`.
- On allowed writes, encode `ControlSequence.copyToClipboard(...)`, write it through
  `PlatformIO.write`, flush immediately, and return `.sent(bytesWritten:)` after
  successful flush. If `flush()` throws, propagate the I/O error; do not convert I/O
  failure into a policy denial.
- Do not update `lastDrawnBuffer`, renderer state, cursor state, or mode lifecycle state.
  Clipboard writes are session side effects like `transmitImage`, not frame output.
- Do not wrap clipboard writes in synchronized output. OSC 52 is not visible frame
  painting, and wrapping it may make terminal/multiplexer handling less predictable.
- Document that `.sent` means Tessera flushed bytes to the terminal device, not that the
  host clipboard changed. Terminal emulators, SSH clients, tmux, screen, or user settings
  may ignore or deny the sequence without reporting back.
- Define the associated values precisely so tests and callers agree:
  `.sent(bytesWritten:)` reports the count of encoded OSC 52 bytes flushed to the terminal
  device (the wire sequence), consistent with "flushed, not acknowledged"; it is not the
  raw payload length. `payloadTooLarge(actualBytes:maximumBytes:)` compares raw payload
  bytes before base64 against `maximumPayloadBytes`.

Acceptance:

- Disabled/default sessions deny without output.
- Enabled sessions write exactly one OSC 52 sequence and flush it.
- Oversized payloads, disallowed selections, missing user intent, and nested-terminal
  denials happen before any write.
- A failed flush follows existing `PlatformIO` error behavior.

### Step 2.3 — Handle SSH, tmux, and screen-oriented behavior through explicit policy

- Files:
  - `Sources/TesseraTerminal/TerminalSession.swift`
  - `Sources/TesseraTerminal/TerminalApplicationConfiguration.swift`
  - `Sources/TesseraTerminal/TerminalCapabilityDetector.swift`
  - `Tests/TesseraTerminalTests/TerminalCapabilityTests.swift`
  - `Tests/TesseraTerminalTests/TerminalSessionTests.swift`
- SSH behavior: do not special-case `SSH_CONNECTION`/`SSH_TTY` for denial. OSC 52 is
  useful specifically because bytes emitted by a remote app can reach the user's local
  terminal through SSH. The terminal host remains the enforcement point.
- tmux/screen behavior: use existing local hints (`TerminalCapabilities.identity` and
  `isNested`) to apply policy before writing.
  - Default enabled policy should deny when `isNested == true` or identity is `.tmux` or
    `.screen`, returning `.nestedTerminalRequiresExplicitPassthrough(...)`.
  - Applications may opt in with `allowsNestedTerminalPassthrough: true` after warning the
    user that the multiplexer must permit clipboard writes.
- Do not automatically add DCS passthrough wrappers for tmux or screen in this slice.
  Current tmux can accept OSC 52 when `set-clipboard` is `on`/`external` and a terminal
  `Ms` or `clipboard` feature exists; screen/tmux passthrough wrappers can bypass
  multiplexer policy and differ by version. If a future slice adds
  `ClipboardTransport.tmuxPassthrough` or `.screenPassthrough`, it must be a separate
  explicit policy with exact byte tests.
- If implementers decide that explicit passthrough wrappers are necessary for the demo,
  keep them off by default and gated by both app configuration and
  `intent: .userInitiated`. Test the exact wrapper bytes separately from plain OSC 52 and
  never select them from terminal names alone.

Acceptance:

- SSH environments are allowed by policy when clipboard writing is otherwise enabled.
- tmux/screen/nested environments are denied by the conservative enabled preset.
- Nested passthrough is possible only through explicit configuration and still produces
  standard OSC 52 in this slice unless a separately reviewed transport enum is added.

## Phase 3 — Tests, docs, and example updates

**Goal**: the feature is covered by exact byte and policy tests, documented as a security-
sensitive opt-in, and demonstrated without changing production code beyond the planned
API.

### Step 3.1 — Add focused encoder, policy, and session tests

- Files:
  - `Tests/TesseraTerminalANSITests/ANSIEncoderTests.swift` or
    `Tests/TesseraTerminalANSITests/ClipboardTests.swift`
  - `Tests/TesseraTerminalTests/TerminalSessionTests.swift`
  - `Tests/TesseraTerminalTests/TerminalCapabilityTests.swift`
- Encoder tests:
  - exact `.clipboard`, `.primary`, and ordered multi-target bytes
  - arbitrary bytes are base64 encoded with no raw control bytes in the OSC payload
  - invalid `ClipboardSelection` construction fails
  - oversized limits are enforced outside the encoder so encoder tests stay pure
- Configuration/policy tests:
  - `.default` denies clipboard writes
  - explicit enabled policy allows `.clipboard` with `.userInitiated`
  - missing user intent is impossible through public API or denied through a package test
    seam if an internal optional intent is used
  - disallowed `.primary` returns `.selectionNotAllowed`
  - `maximumPayloadBytes` boundary: exactly limit succeeds, limit + 1 denies
  - nested/tmux/screen hints deny unless `allowsNestedTerminalPassthrough` is true
  - SSH-only environment does not deny by itself
- Session tests:
  - allowed write records exactly one `InMemoryTerminalDeviceEvent.flush([...])`
  - denied writes record no flush
  - successful write does not alter renderer draw state; a draw before and after clipboard
    write should not force a repaint beyond normal damage behavior
  - I/O flush failure propagates as an error if an existing test seam can model it without
    broad infrastructure changes

Acceptance:

- Tests distinguish policy denials from terminal/I/O failures.
- Tests never require the host clipboard to actually change.
- Tests use exact byte assertions for the wire protocol and semantic equality for policy.

### Step 3.2 — Update docs and `Phase3ProtocolsDemo`

- Files:
  - `docs/Spec.md` Slice 9
  - `Examples/Sources/Phase3ProtocolsDemo/Phase3ProtocolsDemo.swift`
  - `Tests` snapshots only if the demo has snapshot coverage
- Keep `docs/Spec.md` aligned with the final API names chosen by the implementation. Call
  out:
  - safe default disabled
  - app opt-in via configuration
  - per-call user intent requirement
  - size limit before base64
  - `.sent` is not terminal acknowledgement
  - SSH/tmux/screen policy
  - no OSC 52 reads
- Add a clipboard panel or extend the capabilities panel in `Phase3ProtocolsDemo`:
  - The demo must not copy on startup or on draw.
  - Copy only on an explicit keypress, such as `c`, while the clipboard panel is selected.
  - Show the last `ClipboardWriteResult` as `sent`, `denied`, or `error`.
  - Show current policy and a warning when nested terminal hints are present.
  - Keep graphics/Sixel out of the clipboard panel.
- Configure the demo with clipboard writing enabled only for the demo and only with the
  conservative max size. Do not change `TerminalApplicationConfiguration.default`.

Acceptance:

- Documentation and demo describe the security model before showing the API.
- The example cannot mutate the clipboard without an explicit user keypress.
- The demo remains useful when the terminal ignores OSC 52: it reports `.sent`/denied
  state rather than promising clipboard contents.

### Step 3.3 — Run narrow validation commands

- Run only focused commands; do not run project-wide suites unless a focused command is
  not available.
- Suggested commands:

```bash
swift test --filter TesseraTerminalANSITests
swift test --filter TesseraTerminalTests
swift test --filter Phase3ProtocolsDemo
```

- If the example target cannot be tested through
  `swift test --filter Phase3ProtocolsDemo`, use the narrowest available build or test
  command for the example package, for example:

```bash
swift build --package-path Examples --product Phase3ProtocolsDemo
```

- Do not run formatters as part of this plan unless the implementation agent made broad
  style changes and the main agent explicitly asks for formatting.

Acceptance:

- Encoder and session tests pass with the new clipboard API.
- Example code compiles under the narrowest practical example command.
- No validation step requires a real clipboard or a terminal that permits OSC 52.

## References

- `.agents/plans/015-phase-3-modern-terminal-protocols.md` — Phase 3 shared contracts.
- `docs/Spec.md` Phase 3 overview and new Slice 9 — user-facing protocol contract.
- Xterm control sequences, OSC 52: `OSC 52 ; Pc ; Pd ST`, where `Pc` selects clipboard,
  primary, secondary, select, or cut buffers, and `Pd` is normally RFC 4648 base64. Xterm
  also documents `Pd = ?` query/read behavior and `allowWindowOps`; this plan
  intentionally implements writes only.
- Crossterm `clipboard::CopyToClipboard` 0.29.0 — precedent for `c`/`p` targets, ordered
  target strings, RFC 4648 base64, and the warning that terminal and multiplexer support
  must be enabled by the user.
- Tmux manual, `set-clipboard` and `Ms` terminfo extension — tmux may accept or forward
  OSC 52 only when configured (`on`/`external`, terminal `Ms`/`clipboard` support).
- Local Tessera precedents:
  - `Sources/TesseraTerminalANSI/ControlSequence.swift` for grouped exhaustive encoding.
  - `Sources/TesseraTerminalANSI/ANSIByteEncoding.swift` for ST-terminated OSC helpers.
  - `Sources/TesseraTerminal/TerminalApplicationConfiguration.swift` for explicit protocol
    policy carried into `TerminalApplicationResolution`.
  - `Sources/TesseraTerminal/TerminalSession.swift` for session-scoped side effects such
    as `transmitImage` and `deleteImages`.
  - `Sources/TesseraTerminalTestSupport/InMemoryTerminalDevice.swift` for exact flush byte
    assertions.
