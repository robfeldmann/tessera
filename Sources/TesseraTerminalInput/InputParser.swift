import TesseraTerminalCore

/// Parses raw terminal input bytes into semantic terminal events.
public struct InputParser: Sendable {
  private enum State: Sendable {
    case apc(accumulated: [UInt8])
    case bracketedPaste(matchedEndMarkerBytes: Int)
    case csi(accumulated: [UInt8])
    case escape
    case ground
    case ss3(accumulated: [UInt8])
    case utf8(expectedCount: Int, accumulated: [UInt8])
  }

  private enum AssociatedTextResult: Equatable {
    case invalid
    case valid(String?)

    var value: String? {
      guard case .valid(let value) = self else {
        return nil
      }
      return value
    }
  }

  private struct CSIParameters: Sendable {
    var rawBytes: [UInt8]
    var parameters: [[Int?]]

    init?(rawBytes: [UInt8]) {
      self.rawBytes = rawBytes
      parameters = []
      var currentParameter: [Int?] = []
      var value: Int?
      var hasDigits = false

      func finishSubparameter() {
        currentParameter.append(hasDigits ? value : nil)
        value = nil
        hasDigits = false
      }

      func finishParameter() {
        finishSubparameter()
        parameters.append(currentParameter)
        currentParameter = []
      }

      for byte in rawBytes {
        switch byte {
        case 0x30...0x39:
          let digit = Int(byte - 0x30)
          value = (value ?? 0) * 10 + digit
          hasDigits = true

        case 0x3A:
          finishSubparameter()

        case 0x3B:
          finishParameter()

        default:
          return nil
        }
      }

      finishParameter()
    }
  }

  private static let bracketedPasteStartMarker: [UInt8] = [
    0x1B, 0x5B, 0x32, 0x30, 0x30, 0x7E,
  ]
  private static let bracketedPasteEndMarker: [UInt8] = [
    0x1B, 0x5B, 0x32, 0x30, 0x31, 0x7E,
  ]

  private static let apcByteCap = 4_096

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
    case .apc(let accumulated):
      return parseAPC(byte, accumulated: accumulated)

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

      case .apc, .csi, .escape, .ground, .ss3, .utf8:
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
    case .apc(let accumulated):
      state = .ground
      return [.unknown(accumulated)]

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

  private mutating func parseAPC(_ byte: UInt8, accumulated: [UInt8]) -> [InputEvent] {
    if byte == 0x18 || byte == 0x1A {
      state = .ground
      return [.unknown(accumulated)]
    }

    let sequence = accumulated + [byte]

    if sequence.count >= 4, Array(sequence.suffix(2)) == [0x1B, 0x5C] {
      state = .ground
      return [decodeAPC(sequence)]
    }

    guard sequence.count < Self.apcByteCap else {
      state = .ground
      return [.unknown(sequence)]
    }

    state = .apc(accumulated: sequence)
    return []
  }

  private func decodeAPC(_ sequence: [UInt8]) -> InputEvent {
    let payload = sequence.dropFirst(2).dropLast(2)
    guard payload.first == 0x47,
      let response = KittyGraphicsResponse(decoding: payload.dropFirst())
    else {
      return .unknown(sequence)
    }
    return .kittyGraphicsResponse(response)
  }

  private func csiCode(finalByte: UInt8, params: String, parameterBytes: [UInt8]) -> Key? {
    switch finalByte {
    case 0x41:
      return modifiedCSIKey(defaultCode: .up, parameterBytes: parameterBytes)
    case 0x42:
      return modifiedCSIKey(defaultCode: .down, parameterBytes: parameterBytes)
    case 0x43:
      return modifiedCSIKey(defaultCode: .right, parameterBytes: parameterBytes)
    case 0x44:
      return modifiedCSIKey(defaultCode: .left, parameterBytes: parameterBytes)
    case 0x45:
      return modifiedCSIKey(defaultCode: .keypad(.begin), parameterBytes: parameterBytes)
    case 0x46:
      return modifiedCSIKey(defaultCode: .end, parameterBytes: parameterBytes)
    case 0x48:
      return modifiedCSIKey(defaultCode: .home, parameterBytes: parameterBytes)
    case 0x50:
      return modifiedCSIKey(defaultCode: .function(1), parameterBytes: parameterBytes)
    case 0x51:
      return modifiedCSIKey(defaultCode: .function(2), parameterBytes: parameterBytes)
    case 0x53:
      return modifiedCSIKey(defaultCode: .function(4), parameterBytes: parameterBytes)
    case 0x5A where params.isEmpty:
      return Key(code: .tab, modifiers: .shift)
    case 0x75:
      guard let parameters = CSIParameters(rawBytes: parameterBytes) else {
        return nil
      }
      return kittyKey(parameters: parameters)
    case 0x7E:
      return tildeCSIKey(parameterBytes: parameterBytes)
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
    case 57_427:
      return .keypad(.begin)
    default:
      return nil
    }
  }
  // swiftlint:enable cyclomatic_complexity

  private func modifiedCSIKey(defaultCode: KeyCode, parameterBytes: [UInt8]) -> Key? {
    guard let parameters = CSIParameters(rawBytes: parameterBytes) else {
      return nil
    }

    if parameterBytes.isEmpty {
      return Key(code: defaultCode)
    }

    guard
      let primaryParameter = parameters.parameters.first,
      primaryParameter.count == 1,
      primaryParameter.first.flatMap(\.self) == 1
    else {
      return nil
    }

    var modifiers: Modifiers = []
    var kind: KeyEventKind = .press
    guard parseModifierAndKind(parameters: parameters, into: &modifiers, and: &kind) else {
      return nil
    }

    return Key(code: defaultCode, modifiers: modifiers, kind: kind)
  }

  private func parseModifierAndKind(
    parameters: CSIParameters,
    into modifiers: inout Modifiers,
    and kind: inout KeyEventKind
  ) -> Bool {
    guard parameters.parameters.count <= 3 else {
      return false
    }

    guard parameters.parameters.count >= 2 else {
      modifiers = []
      kind = .press
      return true
    }

    let modifierParameter = parameters.parameters[1]
    guard
      let encodedModifiers = modifierParameter.first.flatMap(\.self),
      encodedModifiers > 0
    else {
      return false
    }

    let rawModifiers = encodedModifiers - 1
    guard rawModifiers >= 0, rawModifiers <= Int(UInt8.max) else {
      return false
    }
    modifiers = Modifiers(rawValue: UInt8(rawModifiers))

    if modifierParameter.count > 1 {
      guard let encodedKind = modifierParameter[1], modifierParameter.count == 2 else {
        return false
      }
      guard let parsedKind = kittyEventKind(encodedKind) else {
        return false
      }
      kind = parsedKind
    } else {
      kind = .press
    }

    return true
  }

  private func modifiers(encodedAs value: Int) -> Modifiers? {
    guard value > 0 else {
      return nil
    }
    let rawModifiers = value - 1
    guard rawModifiers >= 0, rawModifiers <= Int(UInt8.max) else {
      return nil
    }
    return Modifiers(rawValue: UInt8(rawModifiers))
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
      if byte == 0x63, let event = primaryDeviceAttributesEvent(params) {
        return [event]
      }
      guard
        let code = csiCode(finalByte: byte, params: params, parameterBytes: parameterBytes)
      else {
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

    case 0x5F:
      state = .apc(accumulated: [0x1B, byte])
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

  private func kittyKey(parameters: CSIParameters) -> Key? {
    guard
      let primaryParameter = parameters.parameters.first,
      let primary = primaryParameter.first.flatMap(\.self)
    else {
      return nil
    }

    let associatedText = associatedText(parameters: parameters)
    guard associatedText != .invalid else {
      return nil
    }

    guard
      let code = kittyKeyCode(
        primary,
        allowUnidentifiedZero: associatedText.value != nil
      )
    else {
      return nil
    }

    let shiftedCode: KeyCode?
    if primaryParameter.count > 1, let shifted = primaryParameter[1] {
      guard let code = kittyKeyCode(shifted) else {
        return nil
      }
      shiftedCode = code
    } else {
      shiftedCode = nil
    }

    let baseLayoutCode: KeyCode?
    if primaryParameter.count > 2, let baseLayout = primaryParameter[2] {
      guard let code = kittyKeyCode(baseLayout) else {
        return nil
      }
      baseLayoutCode = code
    } else {
      baseLayoutCode = nil
    }

    guard primaryParameter.count <= 3 else {
      return nil
    }

    var modifiers: Modifiers = []
    var kind: KeyEventKind = .press
    guard parseModifierAndKind(parameters: parameters, into: &modifiers, and: &kind) else {
      return nil
    }

    return Key(
      code: code,
      modifiers: modifiers,
      kind: kind,
      shiftedCode: shiftedCode,
      baseLayoutCode: baseLayoutCode,
      associatedText: associatedText.value
    )
  }

  private func associatedText(parameters: CSIParameters) -> AssociatedTextResult {
    guard parameters.parameters.count > 2 else {
      return .valid(nil)
    }
    guard parameters.parameters.count == 3 else {
      return .invalid
    }

    let textParameter = parameters.parameters[2]
    if textParameter == [nil] {
      // A present-but-empty text field is zero code points, not a malformed one.
      return .valid("")
    }

    var scalars = String.UnicodeScalarView()
    for value in textParameter {
      guard
        let value,
        let scalar = Unicode.Scalar(value),
        !isControlAssociatedTextScalar(value)
      else {
        return .invalid
      }
      scalars.append(scalar)
    }
    return .valid(String(scalars))
  }

  private func isControlAssociatedTextScalar(_ value: Int) -> Bool {
    (0x00...0x1F).contains(value) || (0x7F...0x9F).contains(value)
  }

  private func kittyEventKind(_ value: Int) -> KeyEventKind? {
    switch value {
    case 1:
      return .press
    case 2:
      return .repeat
    case 3:
      return .release
    default:
      return nil
    }
  }

  // swiftlint:disable cyclomatic_complexity function_body_length
  private func kittyKeyCode(
    _ value: Int,
    allowUnidentifiedZero: Bool = false
  ) -> KeyCode? {
    switch value {
    case 0 where allowUnidentifiedZero:
      return .unidentified(0)
    case 0:
      return nil
    case 9:
      return .tab
    case 13:
      return .enter
    case 27:
      return .escape
    case 127:
      return .backspace
    case 57_358:
      return .capsLock
    case 57_359:
      return .scrollLock
    case 57_360:
      return .numLock
    case 57_361:
      return .printScreen
    case 57_362:
      return .pause
    case 57_363:
      return .menu
    case 57_376...57_398:
      return .function(value - 57_363)
    case 57_399...57_408:
      let keypads: [KeyCode.Keypad] = [
        .zero, .one, .two, .three, .four, .five, .six, .seven, .eight, .nine,
      ]
      return .keypad(keypads[value - 57_399])
    case 57_409...57_416:
      let keypads: [KeyCode.Keypad] = [
        .decimal, .divide, .multiply, .subtract, .add, .enter, .equal, .separator,
      ]
      return .keypad(keypads[value - 57_409])
    case 57_417...57_427:
      let keypads: [KeyCode.Keypad] = [
        .left, .right, .up, .down, .pageUp, .pageDown, .home, .end, .insert,
        .delete, .begin,
      ]
      return .keypad(keypads[value - 57_417])
    case 57_428...57_437:
      let media: [KeyCode.Media] = [
        .play, .pause, .playPause, .reverse, .stop, .fastForward, .rewind,
        .trackNext, .trackPrevious, .record,
      ]
      return .media(media[value - 57_428])
    case 57_438:
      return .media(.lowerVolume)
    case 57_439:
      return .media(.raiseVolume)
    case 57_440:
      return .media(.muteVolume)
    case 57_441...57_446:
      let modifiers: [KeyCode.Modifier] = [
        .leftShift, .leftControl, .leftAlt, .leftSuper, .leftHyper, .leftMeta,
      ]
      return .modifier(modifiers[value - 57_441])
    case 57_447...57_452:
      let modifiers: [KeyCode.Modifier] = [
        .rightShift, .rightControl, .rightAlt, .rightSuper, .rightHyper,
        .rightMeta,
      ]
      return .modifier(modifiers[value - 57_447])
    case 57_453:
      return .modifier(.isoLevel3Shift)
    case 57_454:
      return .modifier(.isoLevel5Shift)
    case 57_344...63_743:
      return .unidentified(value)
    default:
      guard let scalar = Unicode.Scalar(value) else {
        return nil
      }
      return .character(Character(scalar))
    }
  }
  // swiftlint:enable cyclomatic_complexity function_body_length

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

  private func tildeCSIKey(parameterBytes: [UInt8]) -> Key? {
    guard let parameters = CSIParameters(rawBytes: parameterBytes) else {
      return nil
    }
    guard
      let firstParameter = parameters.parameters.first,
      firstParameter.count == 1,
      let first = firstParameter.first.flatMap(\.self),
      let code = keyCode(forTildeParameter: first)
    else {
      return nil
    }

    var modifiers: Modifiers = []
    var kind: KeyEventKind = .press
    guard parseModifierAndKind(parameters: parameters, into: &modifiers, and: &kind) else {
      return nil
    }

    return Key(code: code, modifiers: modifiers, kind: kind)
  }
}

extension KittyGraphicsResponse {
  fileprivate init?(decoding payload: ArraySlice<UInt8>) {
    guard let text = String(validating: Array(payload), as: UTF8.self),
      let semicolon = text.firstIndex(of: ";")
    else {
      return nil
    }

    var id: KittyImageID?
    var placement: KittyPlacementID?
    for pair in text[..<semicolon].split(separator: ",") {
      let parts = pair.split(separator: "=", maxSplits: 1)
      guard parts.count == 2 else {
        return nil
      }
      switch parts[0] {
      case "i":
        guard let value = UInt32(parts[1]) else {
          return nil
        }
        id = KittyImageID(rawValue: value)
      case "p":
        guard let value = UInt32(parts[1]) else {
          return nil
        }
        placement = KittyPlacementID(rawValue: value)
      default:
        break
      }
    }

    self.init(
      id: id,
      placement: placement,
      message: String(text[text.index(after: semicolon)...])
    )
  }
}

extension UInt8 {
  fileprivate var isUTF8Continuation: Bool {
    (0x80...0xBF).contains(self)
  }
}

private func primaryDeviceAttributesEvent(_ params: String) -> InputEvent? {
  guard params.first == "?" else {
    return nil
  }
  let fields = params.dropFirst().split(separator: ";", omittingEmptySubsequences: false)
  var values: [Int] = []
  values.reserveCapacity(fields.count)
  for field in fields {
    guard let value = Int(field) else {
      return nil
    }
    values.append(value)
  }
  return .primaryDeviceAttributes(values)
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
