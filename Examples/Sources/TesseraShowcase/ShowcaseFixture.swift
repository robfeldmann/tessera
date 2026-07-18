import Tessera

public enum ShowcaseFixture: CaseIterable, Sendable {
  case compact
  case guardSize
  case regular
  case standard
  case standardShort

  public var size: TerminalSize {
    switch self {
    case .regular:
      TerminalSize(columns: 120, rows: 24)
    case .standard:
      TerminalSize(columns: 80, rows: 24)
    case .standardShort:
      TerminalSize(columns: 80, rows: 16)
    case .compact:
      TerminalSize(columns: 40, rows: 16)
    case .guardSize:
      TerminalSize(columns: 39, rows: 11)
    }
  }
}

public struct ShowcaseScript: Equatable, Sendable {
  public var events: [InputEvent]

  public init(events: [InputEvent]) {
    self.events = events
  }
}
