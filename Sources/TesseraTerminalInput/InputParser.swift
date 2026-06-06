/// Parses raw terminal input bytes.
public enum InputParser {
  /// Parses a single raw byte using the current minimal input rules.
  public static func parse(_ byte: UInt8) -> InputEvent? {
    if byte == 0x71 {
      return .quit
    }

    guard (0x20...0x7E).contains(byte), let scalar = Unicode.Scalar(UInt32(byte)) else {
      return nil
    }

    return .character(Character(scalar))
  }
}
