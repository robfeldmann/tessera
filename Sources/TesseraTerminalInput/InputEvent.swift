import TesseraTerminalCore

/// A terminal input event parsed from raw terminal bytes.
public enum InputEvent: Equatable, Sendable {
  /// The user pressed a key.
  case key(Key)

  /// The terminal changed size.
  case resize(TerminalSize)

  /// The terminal sent an unrecognized input sequence.
  case unknown([UInt8])
}
