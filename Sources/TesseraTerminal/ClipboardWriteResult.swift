import TesseraTerminalANSI

/// Explicit per-call intent. There is no no-intent public overload.
public enum ClipboardUserIntent: Equatable, Sendable {
  case userInitiated
}

/// Outcome of a session clipboard write. `.sent` means bytes were flushed to the terminal
/// device, NOT that the host clipboard changed (OSC 52 has no acknowledgement).
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
