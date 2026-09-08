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

/// Identifies the protocol that supplied a key event.
///
/// Legacy terminal input reports a press without a matching release. Kitty's enhanced
/// keyboard protocol may report an explicit event kind, or a press-only report. Consumers
/// must use this provenance rather than guessing that a lone press will eventually be released.
public enum KeyEventSource: Equatable, Sendable {
  /// A byte-oriented legacy terminal report with no release provenance.
  case legacy

  /// A Kitty report with an explicit press/repeat/release event kind.
  case kitty

  /// A Kitty CSI-u report that omitted the event kind and is therefore press-only.
  case kittyPressOnly
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

  /// The protocol provenance of this event.
  public var source: KeyEventSource

  /// Creates a semantic key press.
  public init(
    code: KeyCode,
    modifiers: Modifiers = [],
    kind: KeyEventKind = .press,
    shiftedCode: KeyCode? = nil,
    baseLayoutCode: KeyCode? = nil,
    associatedText: String? = nil,
    source: KeyEventSource = .legacy
  ) {
    self.code = code
    self.modifiers = modifiers
    self.kind = kind
    self.shiftedCode = shiftedCode
    self.baseLayoutCode = baseLayoutCode
    self.associatedText = associatedText
    self.source = source
  }

}
// swiftlint:enable sorted_enum_cases
