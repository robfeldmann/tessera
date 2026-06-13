/// Parses raw terminal input bytes into semantic terminal events.
public struct InputParser: Sendable {
  private enum State: Sendable {
    case ground
    case utf8(expectedCount: Int, accumulated: [UInt8])
  }

  private var state: State = .ground

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
    case .ground:
      return parseGround(byte)

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
    bytes.flatMap { feed($0) }
  }

  /// Flushes any pending partial input.
  public mutating func flush() -> [InputEvent] {
    switch state {
    case .ground:
      return []

    case .utf8(_, let accumulated):
      state = .ground
      return [.unknown(accumulated)]
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
}

extension UInt8 {
  fileprivate var isUTF8Continuation: Bool {
    (0x80...0xBF).contains(self)
  }
}
