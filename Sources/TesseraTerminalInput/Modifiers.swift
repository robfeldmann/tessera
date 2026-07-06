/// Modifier keys attached to a terminal key press.
public struct Modifiers: OptionSet, Sendable {
  /// The Alt/Option modifier.
  public static let alt = Self(rawValue: 1 << 1)

  /// The Caps Lock modifier.
  public static let capsLock = Self(rawValue: 1 << 6)

  /// The Control modifier.
  public static let control = Self(rawValue: 1 << 2)

  /// The Hyper modifier.
  public static let hyper = Self(rawValue: 1 << 4)

  /// The Meta modifier.
  public static let meta = Self(rawValue: 1 << 5)

  /// The Num Lock modifier.
  public static let numLock = Self(rawValue: 1 << 7)

  /// The Shift modifier.
  public static let shift = Self(rawValue: 1 << 0)

  /// The Super modifier.
  public static let `super` = Self(rawValue: 1 << 3)

  /// The raw modifier bit mask.
  public let rawValue: UInt8

  /// Creates modifiers from a raw bit mask.
  public init(rawValue: UInt8) {
    self.rawValue = rawValue
  }
}
