/// A minimal Phase 1 input event parsed from a raw terminal byte.
public enum InputEvent: Equatable, Sendable {
  /// The user pressed a printable ASCII character.
  case character(Character)

  /// The user pressed `q` to request exit.
  case quit
}
