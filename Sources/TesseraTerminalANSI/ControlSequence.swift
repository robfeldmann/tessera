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
    case .bell, .raw, .text:
      self.encodePayload(into: &buffer)

    case .cursorBack,
      .cursorDown,
      .cursorForward,
      .cursorPosition,
      .cursorRestore,
      .cursorSave,
      .cursorUp,
      .cursorVisible:
      self.encodeCursor(into: &buffer)

    case .eraseInDisplay, .eraseInLine:
      self.encodeErase(into: &buffer)

    case .resetAttributes,
      .setBackground,
      .setBold,
      .setDim,
      .setForeground,
      .setItalic,
      .setReverse,
      .setStrikethrough,
      .setUnderline:
      self.encodeSGR(into: &buffer)

    case .enableLineWrap,
      .enterAltScreen,
      .enterSynchronizedOutput,
      .exitAltScreen,
      .exitSynchronizedOutput,
      .setWindowTitle:
      break
    }
  }

  /// Encodes cursor sequences using ECMA-48 cursor movement, DEC save/restore,
  /// and DEC private mode 25 for cursor visibility.
  private func encodeCursor(into buffer: inout [UInt8]) {
    switch self {
    case .cursorBack(let columns):
      // ECMA-48 CUB: cursor backward, `CSI Ps D`.
      ANSIByteEncoding.appendCSI("\(columns)D", into: &buffer)

    case .cursorDown(let rows):
      // ECMA-48 CUD: cursor down, `CSI Ps B`.
      ANSIByteEncoding.appendCSI("\(rows)B", into: &buffer)

    case .cursorForward(let columns):
      // ECMA-48 CUF: cursor forward, `CSI Ps C`.
      ANSIByteEncoding.appendCSI("\(columns)C", into: &buffer)

    case .cursorPosition(let position):
      // ECMA-48 CUP: cursor position, `CSI row;column H`, with 1-based wire
      // coordinates.
      ANSIByteEncoding.appendCSI(
        "\(position.row + 1);\(position.column + 1)H",
        into: &buffer
      )

    case .cursorRestore:
      // DEC private DECRC: restore cursor, `ESC 8`.
      buffer.append(ANSIByteEncoding.escape)
      buffer.append(0x38)

    case .cursorSave:
      // DEC private DECSC: save cursor, `ESC 7`.
      buffer.append(ANSIByteEncoding.escape)
      buffer.append(0x37)

    case .cursorUp(let rows):
      // ECMA-48 CUU: cursor up, `CSI Ps A`.
      ANSIByteEncoding.appendCSI("\(rows)A", into: &buffer)

    case .cursorVisible(let isVisible):
      // DEC private mode 25: show/hide cursor, `CSI ? 25 h/l`.
      ANSIByteEncoding.appendCSI(isVisible ? "?25h" : "?25l", into: &buffer)

    case .bell,
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

  /// Encodes ECMA-48 erase sequences: erase-in-display (`CSI Ps J`) and
  /// erase-in-line (`CSI Ps K`).
  private func encodeErase(into buffer: inout [UInt8]) {
    switch self {
    case .eraseInDisplay(let mode):
      ANSIByteEncoding.appendCSI(mode.displayEraseParameter + "J", into: &buffer)

    case .eraseInLine(let mode):
      ANSIByteEncoding.appendCSI(mode.lineEraseParameter + "K", into: &buffer)

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

  /// Encodes literal payloads. Text and raw payloads are appended exactly; the
  /// encoder does not escape, sanitize, or interpret them.
  /// Encodes ECMA-48 Select Graphic Rendition (`CSI Ps ... m`) sequences for
  /// color and text attributes.
  private func encodeSGR(into buffer: inout [UInt8]) {
    switch self {
    case .resetAttributes:
      // ECMA-48 SGR 0: reset all graphic rendition attributes.
      ANSIByteEncoding.appendSGR([0], into: &buffer)

    case .setBackground(let color):
      ANSIByteEncoding.appendSGR(color.backgroundSGRParameters, into: &buffer)

    case .setBold(let isEnabled):
      // ECMA-48 SGR 1 enables bold/intense; SGR 22 returns to normal intensity.
      ANSIByteEncoding.appendSGR([isEnabled ? 1 : 22], into: &buffer)

    case .setDim(let isEnabled):
      // ECMA-48 SGR 2 enables faint/dim; SGR 22 returns to normal intensity.
      // Bold and dim share the same off code, so reapply policy belongs above.
      ANSIByteEncoding.appendSGR([isEnabled ? 2 : 22], into: &buffer)

    case .setForeground(let color):
      ANSIByteEncoding.appendSGR(color.foregroundSGRParameters, into: &buffer)

    case .setItalic(let isEnabled):
      // ECMA-48 SGR 3 enables italic; SGR 23 disables italic/fraktur.
      ANSIByteEncoding.appendSGR([isEnabled ? 3 : 23], into: &buffer)

    case .setReverse(let isEnabled):
      // ECMA-48 SGR 7 enables inverse video; SGR 27 disables it.
      ANSIByteEncoding.appendSGR([isEnabled ? 7 : 27], into: &buffer)

    case .setStrikethrough(let isEnabled):
      // ECMA-48 SGR 9 enables crossed-out text; SGR 29 disables it.
      ANSIByteEncoding.appendSGR([isEnabled ? 9 : 29], into: &buffer)

    case .setUnderline(let isEnabled):
      // ECMA-48 SGR 4 enables underline; SGR 24 disables underline.
      ANSIByteEncoding.appendSGR([isEnabled ? 4 : 24], into: &buffer)

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
      .setWindowTitle,
      .text:
      break
    }
  }

  private func encodePayload(into buffer: inout [UInt8]) {
    switch self {
    case .bell:
      // C0 BEL control character.
      buffer.append(ANSIByteEncoding.bell)

    case .raw(let payload):
      // Raw payloads are an explicit byte-for-byte escape hatch.
      buffer.append(contentsOf: payload.bytes)

    case .text(let text):
      // Crossterm's Print analogue: append the string's UTF-8 bytes directly.
      buffer.append(contentsOf: text.utf8)

    case .cursorBack,
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
      .resetAttributes,
      .setBackground,
      .setBold,
      .setDim,
      .setForeground,
      .setItalic,
      .setReverse,
      .setStrikethrough,
      .setUnderline,
      .setWindowTitle:
      break
    }
  }
}
