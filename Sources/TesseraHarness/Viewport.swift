import TesseraTerminalCore

/// A named terminal size that an application is run and checked at.
public enum Viewport: Hashable, Sendable {
  /// An explicit size.
  case custom(TerminalSize)

  /// 80 columns by 24 rows.
  case desktop

  /// 40 columns at the height the application's content needs.
  ///
  /// The harness measures that natural height. An application whose content grows to any
  /// height it is offered has none, so running it at `mobile` fails with an error that names
  /// ``mobileScreen``.
  case mobile

  /// 40 columns by 16 rows, for compositions meant to fill a screen.
  case mobileScreen
}

extension Viewport {
  /// The width of ``mobile`` and ``mobileScreen``.
  package static let mobileColumns = 40

  /// The size a viewport names, or `nil` for ``mobile``, whose height must be measured.
  package var fixedSize: TerminalSize? {
    switch self {
    case .custom(let size): size
    case .desktop: TerminalSize(columns: 80, rows: 24)
    case .mobile: nil
    case .mobileScreen: TerminalSize(columns: Self.mobileColumns, rows: 16)
    }
  }

  /// The spelling a scenario header and the `apps` listing use.
  package var name: String {
    switch self {
    case .custom(let size): "\(size.columns)x\(size.rows)"
    case .desktop: "desktop"
    case .mobile: "mobile"
    case .mobileScreen: "mobileScreen"
    }
  }
}
