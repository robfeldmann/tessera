// swiftlint:disable sorted_enum_cases
/// The semantic kind of a terminal key event.
public enum KeyEventKind: Equatable, Sendable {
  /// A key press.
  case press

  /// A repeated key press.
  case `repeat`

  /// A key release.
  case release
}

/// A semantic terminal key press.
public struct Key: Equatable, Sendable {
  /// The key's semantic code.
  public var code: KeyCode

  /// Modifier keys active for this key press.
  public var modifiers: Modifiers

  /// The semantic kind of key event.
  public var kind: KeyEventKind

  /// The shifted alternate code reported by Kitty keyboard protocol.
  public var shiftedCode: KeyCode?

  /// The base-layout alternate code reported by Kitty keyboard protocol.
  public var baseLayoutCode: KeyCode?

  /// The associated text reported by Kitty keyboard protocol.
  public var associatedText: String?

  /// Creates a semantic key press.
  public init(
    code: KeyCode,
    modifiers: Modifiers = [],
    kind: KeyEventKind = .press,
    shiftedCode: KeyCode? = nil,
    baseLayoutCode: KeyCode? = nil,
    associatedText: String? = nil
  ) {
    self.code = code
    self.modifiers = modifiers
    self.kind = kind
    self.shiftedCode = shiftedCode
    self.baseLayoutCode = baseLayoutCode
    self.associatedText = associatedText
  }
}
// swiftlint:enable sorted_enum_cases
