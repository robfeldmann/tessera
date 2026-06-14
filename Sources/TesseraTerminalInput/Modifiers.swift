/// Modifier keys attached to a terminal key press.
public struct Modifiers: OptionSet, Sendable {
  /// The Alt/Option modifier.
  public static let alt = Self(rawValue: 1 << 1)

  /// The Control modifier.
  public static let control = Self(rawValue: 1 << 2)

  /// The Shift modifier.
  public static let shift = Self(rawValue: 1 << 0)

  /// The raw modifier bit mask.
  public let rawValue: UInt8

  /// Creates modifiers from a raw bit mask.
  public init(rawValue: UInt8) {
    self.rawValue = rawValue
  }
}
