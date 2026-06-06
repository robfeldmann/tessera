/// The terminal's visible character-cell dimensions.
public struct TerminalSize: Sendable, Equatable, Hashable {
  public let columns: Int
  public let rows: Int

  public init(columns: Int, rows: Int) {
    self.columns = columns
    self.rows = rows
  }
}

/// A zero-based position in terminal character-cell coordinates.
public struct TerminalPosition: Sendable, Equatable, Hashable {
  public let column: Int
  public let row: Int

  public init(column: Int, row: Int) {
    self.column = column
    self.row = row
  }
}
