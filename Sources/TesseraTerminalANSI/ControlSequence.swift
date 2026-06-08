import TesseraTerminalCore

/// A semantic terminal operation that can be encoded as ANSI/VT bytes.
public enum ControlSequence: Equatable, Sendable {
  case bell
  case cursorBack(Int)
  case cursorDown(Int)
  case cursorForward(Int)
  case cursorPosition(TerminalPosition)
  case cursorRestore
  case cursorSave
  case cursorUp(Int)
  case cursorVisible(Bool)
  case enableLineWrap(Bool)
  case enterAltScreen
  case enterSynchronizedOutput
  case eraseInDisplay(EraseMode)
  case eraseInLine(EraseMode)
  case exitAltScreen
  case exitSynchronizedOutput
  case raw(RawTerminalPayload)
  case resetAttributes
  case setBackground(Color)
  case setBold(Bool)
  case setDim(Bool)
  case setForeground(Color)
  case setItalic(Bool)
  case setReverse(Bool)
  case setStrikethrough(Bool)
  case setUnderline(Bool)
  case setWindowTitle(String)
  case text(String)

  /// The bytes for this sequence.
  public var bytes: [UInt8] {
    var bytes: [UInt8] = []
    self.encode(into: &bytes)
    return bytes
  }

  /// Appends the bytes for this sequence to `buffer`.
  public func encode(into buffer: inout [UInt8]) {
    switch self {
    case .bell,
      .cursorBack,
      .cursorDown,
      .cursorForward,
      .cursorPosition,
      .cursorRestore,
      .cursorSave,
      .cursorUp,
      .cursorVisible,
      .enableLineWrap,
      .enterAltScreen,
      .enterSynchronizedOutput,
      .eraseInDisplay,
      .eraseInLine,
      .exitAltScreen,
      .exitSynchronizedOutput,
      .raw,
      .resetAttributes,
      .setBackground,
      .setBold,
      .setDim,
      .setForeground,
      .setItalic,
      .setReverse,
      .setStrikethrough,
      .setUnderline,
      .setWindowTitle,
      .text:
      break
    }
  }
}
