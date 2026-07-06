import TesseraTerminalCore

/// A semantic terminal operation that can be encoded as ANSI/VT bytes.
public enum ControlSequence: Equatable, Sendable {
  /// Ring the terminal bell using the C0 BEL control character.
  case bell

  /// Move the cursor backward using ECMA-48 CUB (`CSI Ps D`).
  case cursorBack(Int)

  /// Move the cursor down using ECMA-48 CUD (`CSI Ps B`).
  case cursorDown(Int)

  /// Move the cursor forward using ECMA-48 CUF (`CSI Ps C`).
  case cursorForward(Int)

  /// Move the cursor to a zero-based position using ECMA-48 CUP (`CSI row;column H`).
  case cursorPosition(TerminalPosition)

  /// Restore the cursor with DEC DECRC (`ESC 8`).
  case cursorRestore

  /// Save the cursor with DEC DECSC (`ESC 7`).
  case cursorSave

  /// Move the cursor up using ECMA-48 CUU (`CSI Ps A`).
  case cursorUp(Int)

  /// Show or hide the cursor using DEC private mode 25 (`CSI ? 25 h/l`).
  case cursorVisible(Bool)

  /// Disable all SGR mouse tracking modes defensively.
  case disableMouseTracking

  /// Enable or disable bracketed paste using DEC private mode 2004.
  case enableBracketedPaste(Bool)

  /// Enable or disable focus event reports using DEC private mode 1004.
  case enableFocusTracking(Bool)

  /// Enable or disable automatic line wrap using DEC private mode 7.
  case enableLineWrap(Bool)

  /// Enable SGR mouse tracking at the requested granularity.
  case enableMouseTracking(MouseTracking)

  /// Enter the alternate screen buffer using DEC private mode 1049.
  case enterAltScreen

  /// Begin synchronized output using DEC private mode 2026.
  case enterSynchronizedOutput

  /// Erase part or all of the display using ECMA-48 ED (`CSI Ps J`).
  case eraseInDisplay(EraseMode)

  /// Erase part or all of the current line using ECMA-48 EL (`CSI Ps K`).
  case eraseInLine(LineEraseMode)

  /// Leave the alternate screen buffer using DEC private mode 1049.
  case exitAltScreen

  /// End synchronized output using DEC private mode 2026.
  case exitSynchronizedOutput

  /// Pop one Kitty keyboard protocol level.
  case popKittyKeyboard

  /// Push one Kitty keyboard protocol level with the requested flags.
  case pushKittyKeyboard(KittyKeyboardFlags)

  /// Append explicit raw bytes Tessera does not semantically model yet.
  case raw(RawTerminalPayload)

  /// Reset all graphic rendition attributes using ECMA-48 SGR 0.
  case resetAttributes

  /// Set the background color using ECMA-48 SGR color parameters.
  case setBackground(Color)

  /// Enable or disable bold/intense text using ECMA-48 SGR 1/22.
  case setBold(Bool)

  /// Enable or disable dim/faint text using ECMA-48 SGR 2/22.
  case setDim(Bool)

  /// Set the foreground color using ECMA-48 SGR color parameters.
  case setForeground(Color)

  /// Enable or disable italic text using ECMA-48 SGR 3/23.
  case setItalic(Bool)

  /// Enable or disable inverse video using ECMA-48 SGR 7/27.
  case setReverse(Bool)

  /// Enable or disable crossed-out text using ECMA-48 SGR 9/29.
  case setStrikethrough(Bool)

  /// Enable or disable underline using ECMA-48 SGR 4/24.
  case setUnderline(Bool)

  /// Set the terminal window title using OSC 2 terminated by BEL.
  case setWindowTitle(String)

  /// Append literal UTF-8 text bytes.
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

    case .disableMouseTracking,
      .enableBracketedPaste,
      .enableFocusTracking,
      .enableLineWrap,
      .enableMouseTracking,
      .popKittyKeyboard,
      .pushKittyKeyboard,
      .enterAltScreen,
      .enterSynchronizedOutput,
      .exitAltScreen,
      .exitSynchronizedOutput:
      self.encodeMode(into: &buffer)

    case .setWindowTitle:
      self.encodeOSC(into: &buffer)
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
      .disableMouseTracking,
      .enableBracketedPaste,
      .enableFocusTracking,
      .enableMouseTracking,
      .enableLineWrap,
      .popKittyKeyboard,
      .pushKittyKeyboard,
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
      .enableBracketedPaste,
      .disableMouseTracking,
      .enableFocusTracking,
      .enableMouseTracking,
      .enableLineWrap,
      .popKittyKeyboard,
      .pushKittyKeyboard,
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
      .enableBracketedPaste,
      .disableMouseTracking,
      .enableFocusTracking,
      .enableMouseTracking,
      .enableLineWrap,
      .popKittyKeyboard,
      .pushKittyKeyboard,
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

  /// Encodes terminal modes using DEC private mode set/reset (`CSI ? Ps h/l`).
  private func encodeMode(into buffer: inout [UInt8]) {
    switch self {
    case .disableMouseTracking:
      // SGR mouse teardown is deliberately defensive and idempotent: reset
      // any-event tracking, button-event tracking, then SGR encoding.
      ANSIByteEncoding.appendCSI("?1003l", into: &buffer)
      ANSIByteEncoding.appendCSI("?1002l", into: &buffer)
      ANSIByteEncoding.appendCSI("?1006l", into: &buffer)

    case .enableBracketedPaste(let isEnabled):
      // DEC private mode 2004: bracketed paste, `CSI ? 2004 h/l`.
      ANSIByteEncoding.appendCSI(isEnabled ? "?2004h" : "?2004l", into: &buffer)

    case .enableFocusTracking(let isEnabled):
      // DEC private mode 1004: focus event reports, `CSI ? 1004 h/l`.
      ANSIByteEncoding.appendCSI(isEnabled ? "?1004h" : "?1004l", into: &buffer)

    case .enableMouseTracking(let granularity):
      switch granularity {
      case .anyEvent:
        // DEC private mode 1003: any-event mouse tracking.
        ANSIByteEncoding.appendCSI("?1003h", into: &buffer)

      case .buttonEvents:
        // DEC private mode 1002: button-event mouse tracking.
        ANSIByteEncoding.appendCSI("?1002h", into: &buffer)
      }
      // DEC private mode 1006: SGR mouse report encoding.
      ANSIByteEncoding.appendCSI("?1006h", into: &buffer)

    case .enableLineWrap(let isEnabled):
      // DEC private mode 7 (DECAWM): automatic line wrap, `CSI ? 7 h/l`.
      ANSIByteEncoding.appendCSI(isEnabled ? "?7h" : "?7l", into: &buffer)

    case .popKittyKeyboard:
      // Kitty keyboard protocol: pop one flags level, `CSI < u`.
      ANSIByteEncoding.appendCSI("<u", into: &buffer)

    case .pushKittyKeyboard(let flags):
      // Kitty keyboard protocol: push requested flags, `CSI > Ps u`.
      ANSIByteEncoding.appendCSI(">\(flags.rawValue)u", into: &buffer)

    case .enterAltScreen:
      // DEC private mode 1049: enter alternate screen, `CSI ? 1049 h`.
      ANSIByteEncoding.appendCSI("?1049h", into: &buffer)

    case .enterSynchronizedOutput:
      // DEC private mode 2026: begin synchronized output, `CSI ? 2026 h`.
      ANSIByteEncoding.appendCSI("?2026h", into: &buffer)

    case .exitAltScreen:
      // DEC private mode 1049: leave alternate screen, `CSI ? 1049 l`.
      ANSIByteEncoding.appendCSI("?1049l", into: &buffer)

    case .exitSynchronizedOutput:
      // DEC private mode 2026: end synchronized output, `CSI ? 2026 l`.
      ANSIByteEncoding.appendCSI("?2026l", into: &buffer)

    case .bell,
      .cursorBack,
      .cursorDown,
      .cursorForward,
      .cursorPosition,
      .cursorRestore,
      .cursorSave,
      .cursorUp,
      .cursorVisible,
      .eraseInDisplay,
      .eraseInLine,
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

  /// Encodes operating system commands.
  private func encodeOSC(into buffer: inout [UInt8]) {
    switch self {
    case .setWindowTitle(let title):
      // OSC 2 sets the window title. BEL terminates the OSC; embedded BEL and
      // ESC are stripped so title text cannot terminate or branch the sequence.
      ANSIByteEncoding.appendOSC("2;" + title.oscSafeTitle, into: &buffer)
      buffer.append(ANSIByteEncoding.bell)

    case .bell,
      .disableMouseTracking,
      .cursorBack,
      .cursorDown,
      .cursorForward,
      .cursorPosition,
      .cursorRestore,
      .cursorSave,
      .cursorUp,
      .cursorVisible,
      .enableBracketedPaste,
      .enableFocusTracking,
      .enableMouseTracking,
      .enableLineWrap,
      .popKittyKeyboard,
      .pushKittyKeyboard,
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
      .text:
      break
    }
  }

  /// Encodes literal payloads. Text and raw payloads are appended exactly; the
  /// encoder does not escape, sanitize, or interpret them.
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
      .disableMouseTracking,
      .enableBracketedPaste,
      .enableFocusTracking,
      .enableMouseTracking,
      .enableLineWrap,
      .popKittyKeyboard,
      .pushKittyKeyboard,
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

extension String {
  /// Returns an OSC-safe title by stripping bytes that can terminate or branch an OSC.
  fileprivate var oscSafeTitle: String {
    String(
      unicodeScalars.filter { scalar in
        scalar.value != UInt32(ANSIByteEncoding.bell)
          && scalar.value != UInt32(ANSIByteEncoding.escape)
      }
    )
  }
}
