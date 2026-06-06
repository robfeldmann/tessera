/// A terminal input event parsed from raw terminal bytes.
public enum InputEvent: Equatable, Sendable {
  /// The user pressed a printable ASCII character.
  case character(Character)

  /// The user pressed `q` to request exit.
  case quit
}
