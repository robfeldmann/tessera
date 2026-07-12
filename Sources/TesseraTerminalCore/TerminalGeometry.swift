/// The terminal's visible character-cell dimensions.
public struct TerminalSize: Equatable, Hashable, Sendable {
  public let columns: Int
  public let rows: Int

  public init(columns: Int, rows: Int) {
    self.columns = columns
    self.rows = rows
  }
}

/// The terminal's per-cell pixel dimensions, when the platform reports them.
public struct CellPixelSize: Equatable, Hashable, Sendable {
  public var height: Int
  public var width: Int

  public init(height: Int, width: Int) {
    self.height = height
    self.width = width
  }
}

/// A zero-based position in terminal character-cell coordinates.
public struct TerminalPosition: Equatable, Hashable, Sendable {
  public let column: Int
  public let row: Int

  public init(column: Int, row: Int) {
    self.column = column
    self.row = row
  }
}

/// A rectangle in terminal character-cell coordinates.
///
/// Rectangles are half-open: `origin` is included and `maxColumn`/`maxRow` are excluded.
/// Negative origins are allowed so callers can describe partially visible regions and clip
/// them to a terminal size before iterating cells.
public struct Rect: Equatable, Hashable, Sendable {
  public let origin: TerminalPosition
  public let size: TerminalSize

  public var columnRange: Range<Int> {
    origin.column..<maxColumn
  }

  public var isEmpty: Bool {
    size.columns <= 0 || size.rows <= 0
  }

  public var maxColumn: Int {
    origin.column + max(size.columns, 0)
  }

  public var maxRow: Int {
    origin.row + max(size.rows, 0)
  }

  public var rowRange: Range<Int> {
    origin.row..<maxRow
  }

  public init(origin: TerminalPosition, size: TerminalSize) {
    self.origin = origin
    self.size = size
  }

  public init(column: Int, row: Int, columns: Int, rows: Int) {
    self.init(
      origin: TerminalPosition(column: column, row: row),
      size: TerminalSize(columns: columns, rows: rows)
    )
  }

  public func clipped(to terminalSize: TerminalSize) -> Self? {
    intersection(
      Self(
        origin: TerminalPosition(column: 0, row: 0),
        size: terminalSize
      )
    )
  }

  public func contains(column: Int, row: Int) -> Bool {
    guard !isEmpty else {
      return false
    }

    return columnRange.contains(column) && rowRange.contains(row)
  }

  public func contains(_ position: TerminalPosition) -> Bool {
    contains(column: position.column, row: position.row)
  }

  public func intersection(_ other: Self) -> Self? {
    guard !isEmpty, !other.isEmpty else {
      return nil
    }

    let column = max(origin.column, other.origin.column)
    let row = max(origin.row, other.origin.row)
    let maxColumn = min(maxColumn, other.maxColumn)
    let maxRow = min(maxRow, other.maxRow)

    guard column < maxColumn, row < maxRow else {
      return nil
    }

    return Self(
      column: column,
      row: row,
      columns: maxColumn - column,
      rows: maxRow - row
    )
  }
}
