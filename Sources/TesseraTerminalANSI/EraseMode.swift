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

  /// The `Ps` parameter for ECMA-48 erase-in-display (`CSI Ps J`).
  ///
  /// Standard values are `0`/omitted for cursor-to-end, `1` for cursor-to-beginning,
  /// and `2` for the full display. `3` is the common xterm/crossterm scrollback purge
  /// extension.
  var displayEraseParameter: String {
    switch self {
    case .all:
      "2"
    case .allAndScrollback:
      "3"
    case .toBeginning:
      "1"
    case .toEnd:
      ""
    }
  }

  /// The `Ps` parameter for ECMA-48 erase-in-line (`CSI Ps K`).
  ///
  /// Standard values are `0`/omitted for cursor-to-end, `1` for cursor-to-beginning,
  /// and `2` for the full line. There is no line-scrollback equivalent, so
  /// `.allAndScrollback` intentionally aliases `.all`.
  var lineEraseParameter: String {
    switch self {
    case .all, .allAndScrollback:
      "2"
    case .toBeginning:
      "1"
    case .toEnd:
      ""
    }
  }
}
