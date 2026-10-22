---
type: spec
description: "Slice 9: OSC 52 clipboard"
---

# Slice 9: OSC 52 clipboard

OSC 52 lets an application ask the terminal emulator to place data on the host clipboard by emitting an operating-system-command sequence:

```text
ESC ] 52 ; <Pc> ; <base64-data> ESC \
```

`Pc` selects the destination (`c` for the normal clipboard, `p` for primary selection, and other xterm-defined selections), and `base64-data` is the payload encoded with RFC 4648 base64. This is useful precisely in remote terminal sessions: a Tessera app running over SSH can copy text to the user's local terminal clipboard without knowing anything about the local desktop environment.

That usefulness is also the risk. Clipboard writes are side effects outside Tessera's screen model. A malicious or careless app could overwrite a user's clipboard unexpectedly. Tessera supports OSC 52 only as an explicit, policy-gated session operation: not renderer output, not a raw payload convenience, and not a default-on feature.

`TesseraTerminalANSI` models OSC 52 writes with semantic types:

```swift
public enum ClipboardTarget: Equatable, Hashable, Sendable {
  case clipboard
  case cutBuffer(UInt8)
  case primary
  case secondary
  case select
}

public struct ClipboardSelection: Equatable, Hashable, Sendable {
  public static let clipboard: Self
  public static let primary: Self
  public static let clipboardAndPrimary: Self

  public let targets: [ClipboardTarget]
}

public struct ClipboardWrite: Equatable, Sendable {
  public init(selection: ClipboardSelection = .clipboard, text: String)
  public init(selection: ClipboardSelection = .clipboard, bytes: [UInt8])
}
```

`ClipboardSelection` is non-empty. Xterm gives an empty `Pc` a legacy configurable primary/clipboard-plus-cut-buffer meaning, which is too surprising for Tessera's safe semantic API. The default target is `.clipboard`, encoded as `c`.

Order matters for multi-target selections. Terminals differ for ordered target strings such as `cp` and `pc`, so Tessera preserves caller order rather than normalizing to a set. The common presets are `.clipboard`, `.primary`, and `.clipboardAndPrimary`; less common xterm targets are validated instead of accepting arbitrary characters.

String convenience APIs copy the string's UTF-8 bytes. Byte APIs are available for applications that intentionally copy non-text payloads. The semantic API does not accept a caller-supplied pre-base64 string; the encoder owns base64 so delimiter safety, size accounting, and exact bytes are centralized.

The control sequence layer exposes the semantic encoder case:

```swift
case copyToClipboard(ClipboardWrite)
```

It terminates with ST (`ESC \`) to match Tessera's OSC 8 hyperlink policy. First-class clipboard writes do not use `RawTerminalPayload`; raw payloads remain the explicit escape hatch for terminal bytes Tessera does not model.

Clipboard writing is safely disabled by default. Applications must opt in for a session by setting `TerminalApplicationConfiguration.clipboardWriting` to `.enabled(ClipboardWritePolicy)`, commonly `.enabled(.default)`:

```swift
public enum ClipboardWriteMode: Equatable, Sendable {
  case disabled
  case enabled(ClipboardWritePolicy)
}

public struct ClipboardWritePolicy: Equatable, Sendable {
  public static let `default`: Self

  public var maximumPayloadBytes: Int
  public var allowedTargets: Set<ClipboardTarget>
  public var allowsNestedTerminalPassthrough: Bool

  public init(
    maximumPayloadBytes: Int = 64 * 1024,
    allowedTargets: Set<ClipboardTarget> = [.clipboard],
    allowsNestedTerminalPassthrough: Bool = false
  )
}

public struct TerminalApplicationConfiguration {
  public var clipboardWriting: ClipboardWriteMode
}
```

The conservative enabled preset allows only the normal clipboard, caps raw payloads at 64 KiB before base64 encoding, and denies nested-terminal passthrough unless explicitly enabled. Enabling the session policy is not enough to copy: every public write must also pass explicit per-call intent, `intent: .userInitiated`, so unattended writes are visible in code review and testable in policy tests.

`TerminalSession` exposes the active policy and writes:

```swift
public let clipboardWriting: ClipboardWriteMode

public func copyToClipboard(
  _ text: String,
  selection: ClipboardSelection = .clipboard,
  intent: ClipboardUserIntent
) async throws -> ClipboardWriteResult

public func copyToClipboard(
  _ bytes: [UInt8],
  selection: ClipboardSelection = .clipboard,
  intent: ClipboardUserIntent
) async throws -> ClipboardWriteResult

public enum ClipboardUserIntent: Equatable, Sendable {
  case userInitiated
}
```

OSC 52 writes are session-scoped side effects, similar to `TerminalSession.transmitImage`, not frame-scoped rendering operations. `Frame` does not gain clipboard methods. Clipboard writes do not write cells, reserve regions, mark opaque regions, alter cursor state, update `lastDrawnBuffer`, or get wrapped in synchronized output. Allowed writes emit exactly one OSC 52 sequence and flush immediately. Denied writes emit no bytes.

A successful call can only mean Tessera flushed the OSC 52 bytes to the terminal device. It does not mean the host clipboard changed, because terminals and multiplexers may ignore or deny OSC 52 without acknowledgement. Policy denials are expected behavior, not I/O failures:

```swift
public enum ClipboardWriteResult: Equatable, Sendable {
  case denied(ClipboardWriteDenialReason)
  case sent(bytesWritten: Int)
}

public enum ClipboardWriteDenialReason: Equatable, Sendable {
  case disabledByConfiguration
  case missingUserIntent
  case nestedTerminalRequiresExplicitPassthrough(TerminalIdentity)
  case payloadTooLarge(actualBytes: Int, maximumBytes: Int)
  case selectionNotAllowed(ClipboardSelection)
}
```

`.sent(bytesWritten:)` reports the count of encoded OSC 52 bytes flushed to the terminal device, not the raw payload length and not proof the host clipboard changed. `payloadTooLarge(actualBytes:maximumBytes:)` compares raw payload bytes before base64 against `ClipboardWritePolicy.maximumPayloadBytes`.

The size limit is applied to raw payload bytes before base64 encoding. Tessera uses RFC 4648 standard base64 with padding. Caller bytes may include BEL, ESC, NUL, newlines, or invalid UTF-8; those bytes are safe because only base64 text enters the OSC body. Tessera does not automatically chunk clipboard writes: portable OSC 52 clipboard writes are one sequence, and partial/chunked clipboard updates are not a reliable terminal contract.

OSC 52 is often used over SSH, and Tessera does not deny solely because `SSH_CONNECTION` or `SSH_TTY` exists. Multiplexers need more care: the default enabled policy denies writes when identity is `.tmux` or `.screen`, or when `TerminalCapabilities.isNested == true`. Applications may set `allowsNestedTerminalPassthrough` after warning the user that tmux/screen must also permit clipboard writes. Tessera does not automatically wrap OSC 52 in tmux/screen DCS passthrough sequences.

There is no portable acknowledgement that an OSC 52 write succeeded. Tessera exposes `TerminalCapabilities.osc52Clipboard` for parity with `osc8Hyperlinks`, and the value is `.notDetectable`; neither passive detection nor active probing may promote it to `.supported`. Tessera does not implement OSC 52 reads, queries, or active clipboard probes.

Tests cover encoder exact bytes, selection validation, base64 safety for arbitrary bytes, default policy denial, explicit opt-in, selection and size denial, SSH versus nested-terminal policy, no-output-on-denial behavior, and the guarantee that clipboard writes do not perturb renderer damage state.

`Phase3ProtocolsDemo` includes a clipboard panel. It never copies on startup or during a plain draw. It copies only in response to an explicit keypress while the clipboard UI is active, passes `intent: .userInitiated`, shows the last `ClipboardWriteResult`, shows the active policy, and warns that `.sent` means bytes were flushed rather than acknowledged by the host clipboard.

## Non-goals

Do not add clipboard reads, OSC 52 read/query probes, pasteboard-native APIs, terminal-specific clipboard probes, auto-detected tmux/screen passthrough wrappers, Phase 4 view-layer copy widgets, or Sixel.

## End of Slice 9

`TesseraTerminal` can perform safe, bounded, explicitly user-initiated OSC 52 clipboard writes as session side effects, while default applications remain unable to mutate the clipboard and nested terminal/multiplexer policy is respected.
