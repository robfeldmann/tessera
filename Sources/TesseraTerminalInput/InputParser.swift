import TesseraTerminalCore

/// Parses raw terminal input bytes into semantic terminal events.
public struct InputParser: Sendable {
  private enum State: Sendable {
    case bracketedPaste(matchedEndMarkerBytes: Int)
    case csi(accumulated: [UInt8])
    case escape
    case ground
    case ss3(accumulated: [UInt8])
    case utf8(expectedCount: Int, accumulated: [UInt8])
  }

  private static let bracketedPasteStartMarker: [UInt8] = [
    0x1B, 0x5B, 0x32, 0x30, 0x30, 0x7E,
  ]
  private static let bracketedPasteEndMarker: [UInt8] = [
    0x1B, 0x5B, 0x32, 0x30, 0x31, 0x7E,
  ]

  private var state: State = .ground
  private var bracketedPasteBuffer: [UInt8] = []

  /// Whether the parser is waiting to disambiguate a bare Escape byte.
  package var isWaitingForEscape: Bool {
    if case .escape = state {
      return true
    }

    return false
  }

  /// Creates an empty parser.
  public init() {}

  /// Parses a single raw byte using a fresh parser.
  public static func parse(_ byte: UInt8) -> InputEvent? {
    var parser = Self()
    return parser.feed(byte).first
  }

  /// Feeds one byte into the parser.
  public mutating func feed(_ byte: UInt8) -> [InputEvent] {
    switch state {
    case .bracketedPaste(let matchedEndMarkerBytes):
      guard
        let event = parseBracketedPaste(
          byte,
          matchedEndMarkerBytes: matchedEndMarkerBytes
        )
      else {
        return []
      }
      return [event]

    case .csi(let accumulated):
      return parseCSI(byte, accumulated: accumulated)

    case .escape:
      return parseEscape(byte)

    case .ground:
      return parseGround(byte)

    case .ss3(let accumulated):
      return parseSS3(byte, accumulated: accumulated)

    case .utf8(let expectedCount, var accumulated):
      guard byte.isUTF8Continuation else {
        state = .ground
        return [.unknown(accumulated + [byte])]
      }

      accumulated.append(byte)
      guard accumulated.count == expectedCount else {
        state = .utf8(expectedCount: expectedCount, accumulated: accumulated)
        return []
      }

      state = .ground
      guard
        let string = String(validating: accumulated, as: UTF8.self),
        let character = string.first
      else {
        return [.unknown(accumulated)]
      }

      return [.key(Key(code: .character(character)))]
    }
  }

  /// Feeds a sequence of bytes into the parser.
  public mutating func feed<S: Sequence>(
    contentsOf bytes: S
  ) -> [InputEvent] where S.Element == UInt8 {
    if case .bracketedPaste = state {
      bracketedPasteBuffer.reserveCapacity(
        bracketedPasteBuffer.count + bytes.underestimatedCount
      )
    }

    var events: [InputEvent] = []
    events.reserveCapacity(1)
    for byte in bytes {
      switch state {
      case .bracketedPaste(let matchedEndMarkerBytes):
        if let event = parseBracketedPaste(
          byte,
          matchedEndMarkerBytes: matchedEndMarkerBytes
        ) {
          events.append(event)
        }

      case .csi, .escape, .ground, .ss3, .utf8:
        events.append(contentsOf: feed(byte))
      }
    }
    return events
  }

  /// Flushes a pending bare Escape byte, if present.
  package mutating func flushPendingEscape() -> [InputEvent] {
    guard isWaitingForEscape else {
      return []
    }

    state = .ground
    return [.key(Key(code: .escape))]
  }

  /// Flushes any pending partial input.
  public mutating func flush() -> [InputEvent] {
    switch state {
    case .bracketedPaste(let matchedEndMarkerBytes):
      state = .ground
      let bytes =
        Self.bracketedPasteStartMarker + bracketedPasteBuffer
        + Self.bracketedPasteEndMarker.prefix(matchedEndMarkerBytes)
      bracketedPasteBuffer.removeAll(keepingCapacity: true)
      return [.unknown(Array(bytes))]
    case .csi(let accumulated), .ss3(let accumulated):
      state = .ground
      return [.unknown(accumulated)]

    case .escape:
      state = .ground
      return [.key(Key(code: .escape))]

    case .ground:
      return []

    case .utf8(_, let accumulated):
      state = .ground
      return [.unknown(accumulated)]
    }
  }

  private mutating func parseBracketedPaste(
    _ byte: UInt8,
    matchedEndMarkerBytes: Int
  ) -> InputEvent? {
    let endMarker = Self.bracketedPasteEndMarker
    var matchedEndMarkerBytes = matchedEndMarkerBytes

    if byte == endMarker[matchedEndMarkerBytes] {
      matchedEndMarkerBytes += 1

      if matchedEndMarkerBytes == endMarker.count {
        state = .ground
        // swiftlint:disable:next optional_data_string_conversion
        let payload = String(decoding: bracketedPasteBuffer, as: UTF8.self)
        bracketedPasteBuffer.removeAll(keepingCapacity: true)
        return .paste(payload)
      }

      state = .bracketedPaste(matchedEndMarkerBytes: matchedEndMarkerBytes)
      return nil
    }

    if matchedEndMarkerBytes > 0 {
      bracketedPasteBuffer.append(contentsOf: endMarker.prefix(matchedEndMarkerBytes))
      matchedEndMarkerBytes = 0
    }

    if byte == endMarker[0] {
      state = .bracketedPaste(matchedEndMarkerBytes: 1)
      return nil
    }

    bracketedPasteBuffer.append(byte)
    state = .bracketedPaste(matchedEndMarkerBytes: 0)
    return nil
  }

  private func csiCode(finalByte: UInt8, params: String) -> Key? {
    switch finalByte {
    case 0x41:
      return modifiedCSIKey(defaultCode: .up, params: params)
    case 0x42:
      return modifiedCSIKey(defaultCode: .down, params: params)
    case 0x43:
      return modifiedCSIKey(defaultCode: .right, params: params)
    case 0x44:
      return modifiedCSIKey(defaultCode: .left, params: params)
    case 0x46:
      return modifiedCSIKey(defaultCode: .end, params: params)
    case 0x48:
      return modifiedCSIKey(defaultCode: .home, params: params)
    case 0x5A where params.isEmpty:
      return Key(code: .tab, modifiers: .shift)
    case 0x7E:
      return tildeCSIKey(params: params)
    default:
      return nil
    }
  }

  // swiftlint:disable cyclomatic_complexity
  private func keyCode(forTildeParameter parameter: Int) -> KeyCode? {
    switch parameter {
    case 1, 7:
      return .home
    case 2:
      return .insert
    case 3:
      return .delete
    case 4, 8:
      return .end
    case 5:
      return .pageUp
    case 6:
      return .pageDown
    case 11:
      return .function(1)
    case 12:
      return .function(2)
    case 13:
      return .function(3)
    case 14:
      return .function(4)
    case 15:
      return .function(5)
    case 17:
      return .function(6)
    case 18:
      return .function(7)
    case 19:
      return .function(8)
    case 20:
      return .function(9)
    case 21:
      return .function(10)
    case 23:
      return .function(11)
    case 24:
      return .function(12)
    default:
      return nil
    }
  }
  // swiftlint:enable cyclomatic_complexity

  private func modifiedCSIKey(defaultCode: KeyCode, params: String) -> Key? {
    if params.isEmpty {
      return Key(code: defaultCode)
    }

    let values = csiParameterValues(params)
    guard
      values.count == 2,
      values[0] == 1,
      let modifiers = modifiers(encodedAs: values[1])
    else {
      return nil
    }

    return Key(code: defaultCode, modifiers: modifiers)
  }

  private func modifiers(encodedAs value: Int) -> Modifiers? {
    switch value {
    case 2:
      return .shift
    case 3:
      return .alt
    case 4:
      return [.shift, .alt]
    case 5:
      return .control
    case 6:
      return [.shift, .control]
    case 7:
      return [.alt, .control]
    case 8:
      return [.shift, .alt, .control]
    default:
      return nil
    }
  }

  private mutating func parseCSI(_ byte: UInt8, accumulated: [UInt8]) -> [InputEvent] {
    let sequence = accumulated + [byte]

    switch byte {
    case 0x20...0x3F:
      state = .csi(accumulated: sequence)
      return []

    case 0x40...0x7E:
      state = .ground
      let parameterBytes = Array(sequence.dropFirst(2).dropLast())
      guard let params = String(validating: parameterBytes, as: UTF8.self) else {
        return [.unknown(sequence)]
      }
      if byte == 0x7E, params == "200" {
        bracketedPasteBuffer.removeAll(keepingCapacity: true)
        state = .bracketedPaste(matchedEndMarkerBytes: 0)
        return []
      }
      if byte == 0x49, params.isEmpty {
        return [.focusGained]
      }
      if byte == 0x4F, params.isEmpty {
        return [.focusLost]
      }
      if byte == 0x4D || byte == 0x6D {
        guard let event = mouseEvent(finalByte: byte, params: params) else {
          return [.unknown(sequence)]
        }
        return [.mouse(event)]
      }
      guard let code = csiCode(finalByte: byte, params: params) else {
        return [.unknown(sequence)]
      }
      return [.key(code)]

    default:
      state = .ground
      return [.unknown(sequence)]
    }
  }

  private mutating func parseEscape(_ byte: UInt8) -> [InputEvent] {
    switch byte {
    case 0x5B:
      state = .csi(accumulated: [0x1B, byte])
      return []

    case 0x4F:
      state = .ss3(accumulated: [0x1B, byte])
      return []

    case 0x20...0x7E:
      state = .ground
      guard let scalar = Unicode.Scalar(UInt32(byte)) else {
        return [.unknown([0x1B, byte])]
      }
      return [.key(Key(code: .character(Character(scalar)), modifiers: .alt))]

    default:
      state = .ground
      return [.unknown([0x1B, byte])]
    }
  }

  // swiftlint:disable cyclomatic_complexity
  private mutating func parseGround(_ byte: UInt8) -> [InputEvent] {
    switch byte {
    case 0x00:
      return [.key(Key(code: .character(" "), modifiers: .control))]

    case 0x01...0x1A where byte != 0x09 && byte != 0x0A && byte != 0x0D:
      guard let scalar = Unicode.Scalar(UInt32(byte + 0x40)) else {
        return [.unknown([byte])]
      }
      return [.key(Key(code: .character(Character(scalar)), modifiers: .control))]

    case 0x09:
      return [.key(Key(code: .tab))]

    case 0x0A, 0x0D:
      return [.key(Key(code: .enter))]

    case 0x1B:
      state = .escape
      return []

    case 0x20...0x7E:
      guard let scalar = Unicode.Scalar(UInt32(byte)) else {
        return [.unknown([byte])]
      }
      return [.key(Key(code: .character(Character(scalar))))]

    case 0x7F:
      return [.key(Key(code: .backspace))]

    case 0xC2...0xDF:
      state = .utf8(expectedCount: 2, accumulated: [byte])
      return []

    case 0xE0...0xEF:
      state = .utf8(expectedCount: 3, accumulated: [byte])
      return []

    case 0xF0...0xF4:
      state = .utf8(expectedCount: 4, accumulated: [byte])
      return []

    default:
      return [.unknown([byte])]
    }
  }
  // swiftlint:enable cyclomatic_complexity

  private mutating func parseSS3(_ byte: UInt8, accumulated: [UInt8]) -> [InputEvent] {
    state = .ground
    let sequence = accumulated + [byte]

    switch byte {
    case 0x41:
      return [.key(Key(code: .up))]
    case 0x42:
      return [.key(Key(code: .down))]
    case 0x43:
      return [.key(Key(code: .right))]
    case 0x44:
      return [.key(Key(code: .left))]
    case 0x50:
      return [.key(Key(code: .function(1)))]
    case 0x51:
      return [.key(Key(code: .function(2)))]
    case 0x52:
      return [.key(Key(code: .function(3)))]
    case 0x53:
      return [.key(Key(code: .function(4)))]
    default:
      return [.unknown(sequence)]
    }
  }

  private func mouseButton(_ code: Int) -> MouseButton? {
    switch code {
    case 0:
      return .left
    case 1:
      return .middle
    case 2:
      return .right
    default:
      return nil
    }
  }

  private func mouseEvent(finalByte: UInt8, params: String) -> MouseEvent? {
    guard params.first == "<" else {
      return nil
    }

    let values = mouseParameterValues(String(params.dropFirst()))
    guard
      values.count == 3,
      let buttonParameter = values.first,
      buttonParameter >= 0,
      buttonParameter <= 127,
      values[1] > 0,
      values[2] > 0
    else {
      return nil
    }

    let finalIsRelease = finalByte == 0x6D
    let hasMotionBit = buttonParameter & 32 != 0
    let hasWheelBit = buttonParameter & 64 != 0
    let lowButtonCode = buttonParameter & 3
    let position = TerminalPosition(column: values[1] - 1, row: values[2] - 1)
    let modifiers = mouseModifiers(encodedAs: buttonParameter)

    if finalIsRelease {
      guard !hasMotionBit, !hasWheelBit else {
        return nil
      }
      return MouseEvent(
        kind: .release(mouseButton(lowButtonCode)),
        position: position,
        modifiers: modifiers
      )
    }

    if hasWheelBit {
      guard !hasMotionBit else {
        return nil
      }
      let direction: MouseScrollDirection
      switch lowButtonCode {
      case 0:
        direction = .up
      case 1:
        direction = .down
      case 2:
        direction = .left
      case 3:
        direction = .right
      default:
        return nil
      }
      return MouseEvent(kind: .scroll(direction), position: position, modifiers: modifiers)
    }

    if hasMotionBit {
      guard let button = mouseButton(lowButtonCode) else {
        return MouseEvent(kind: .move, position: position, modifiers: modifiers)
      }
      return MouseEvent(kind: .drag(button), position: position, modifiers: modifiers)
    }

    guard let button = mouseButton(lowButtonCode) else {
      return nil
    }
    return MouseEvent(kind: .press(button), position: position, modifiers: modifiers)
  }

  private func mouseModifiers(encodedAs value: Int) -> Modifiers {
    var modifiers: Modifiers = []
    if value & 4 != 0 {
      modifiers.insert(.shift)
    }
    if value & 8 != 0 {
      modifiers.insert(.alt)
    }
    if value & 16 != 0 {
      modifiers.insert(.control)
    }
    return modifiers
  }

  private func tildeCSIKey(params: String) -> Key? {
    let values = csiParameterValues(params)
    guard let first = values.first, let code = keyCode(forTildeParameter: first) else {
      return nil
    }

    if values.count == 1 {
      return Key(code: code)
    }

    guard values.count == 2, let modifiers = modifiers(encodedAs: values[1]) else {
      return nil
    }

    return Key(code: code, modifiers: modifiers)
  }
}

extension UInt8 {
  fileprivate var isUTF8Continuation: Bool {
    (0x80...0xBF).contains(self)
  }
}

private func csiParameterValues(_ params: String) -> [Int] {
  params.split(separator: ";").compactMap { Int($0) }
}

private func mouseParameterValues(_ params: String) -> [Int] {
  let fields = params.split(separator: ";", omittingEmptySubsequences: false)
  var values: [Int] = []
  values.reserveCapacity(fields.count)
  for field in fields {
    guard let value = Int(field) else {
      return []
    }
    values.append(value)
  }
  return values
}
