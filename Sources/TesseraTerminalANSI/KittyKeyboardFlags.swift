/// Kitty keyboard protocol flags Tessera can request.
public struct KittyKeyboardFlags: OptionSet, Equatable, Sendable {
  /// Disambiguates escape-coded keys from legacy byte sequences.
  public static let disambiguateEscapeCodes = Self(rawValue: 1 << 0)

  /// Reports press, repeat, and release event types.
  public static let reportEventTypes = Self(rawValue: 1 << 1)

  /// Reports alternate key encodings.
  public static let reportAlternateKeys = Self(rawValue: 1 << 2)

  /// Reports all keys as escape codes.
  public static let reportAllKeysAsEscapeCodes = Self(rawValue: 1 << 3)

  /// Reports associated text.
  public static let reportAssociatedText = Self(rawValue: 1 << 4)

  /// Conservative Tessera default flags for application sessions.
  public static let tesseraDefault: Self = [
    .disambiguateEscapeCodes,
    .reportEventTypes,
    .reportAlternateKeys,
  ]

  /// The raw flag mask.
  public let rawValue: Int

  /// Creates flags from a raw mask.
  public init(rawValue: Int) {
    self.rawValue = rawValue
  }
}
