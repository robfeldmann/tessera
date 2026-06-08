/// The region affected by an erase control sequence.
public enum EraseMode: Equatable, Sendable {
  /// Erase the whole display or line.
  case all

  /// Erase the whole display and scrollback history.
  case allAndScrollback

  /// Erase from the cursor back to the beginning of the display or line.
  case toBeginning

  /// Erase from the cursor through the end of the display or line.
  case toEnd
}
