/// The region affected by an erase-in-display control sequence.
public enum EraseMode: Equatable, Sendable {
  /// Erase the whole display.
  case all

  /// Erase the whole display and scrollback history.
  case allAndScrollback

  /// Erase from the cursor back to the beginning of the display.
  case toBeginning

  /// Erase from the cursor through the end of the display.
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
}

/// The region affected by an erase-in-line control sequence.
///
/// A separate type from ``EraseMode`` because ECMA-48 EL (`CSI Ps K`) has no scrollback
/// variant; sharing the enum would make `eraseInLine(.allAndScrollback)` representable
/// but meaningless.
public enum LineEraseMode: Equatable, Sendable {
  /// Erase the whole line.
  case all

  /// Erase from the cursor back to the beginning of the line.
  case toBeginning

  /// Erase from the cursor through the end of the line.
  case toEnd

  /// The `Ps` parameter for ECMA-48 erase-in-line (`CSI Ps K`).
  ///
  /// Standard values are `0`/omitted for cursor-to-end, `1` for cursor-to-beginning,
  /// and `2` for the full line.
  var lineEraseParameter: String {
    switch self {
    case .all:
      "2"
    case .toBeginning:
      "1"
    case .toEnd:
      ""
    }
  }
}
