/// A semantic terminal key press.
public struct Key: Equatable, Sendable {
  /// The key's semantic code.
  public var code: KeyCode

  /// Modifier keys active for this key press.
  public var modifiers: Modifiers

  /// Creates a semantic key press.
  public init(code: KeyCode, modifiers: Modifiers = []) {
    self.code = code
    self.modifiers = modifiers
  }
}
