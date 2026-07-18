import TesseraTerminalANSI
import TesseraTerminalCore

/// A rectangular terminal buffer backed by flat row-major cell storage.
public struct Buffer: Equatable, Sendable {
  public let size: TerminalSize
  private var cells: [Cell]

  public init(size: TerminalSize, fill: Cell = .blank) {
    self.size = size
    self.cells = Array(repeating: fill, count: size.columns * size.rows)
  }

  public mutating func clear(fill: Cell = .blank) {
    cells = Array(repeating: fill, count: size.columns * size.rows)
  }

  public mutating func write(
    _ string: String,
    at position: TerminalPosition,
    style: Style = Style()
  ) {
    guard position.row >= 0, position.row < size.rows else {
      return
    }

    var column = position.column
    for character in string {
      let grapheme = String(character)
      let width = terminalCellWidth(of: grapheme)

      guard isSupportedStoredGrapheme(grapheme) else {
        continue
      }

      guard column >= 0 else {
        column += width
        continue
      }

      let result = write(
        grapheme: grapheme,
        at: TerminalPosition(column: column, row: position.row),
        style: style
      )

      switch result {
      case .clipped:
        return
      case .unsupported:
        continue
      case .written(let nextColumn):
        column = nextColumn
      }
    }
  }

  /// Writes one printable grapheme and reports how the write advanced.
  public mutating func write(
    grapheme: String,
    at position: TerminalPosition,
    style: Style = Style()
  ) -> GraphemeWriteResult {
    guard isSupportedStoredGrapheme(grapheme) else {
      return .unsupported
    }

    guard contains(row: position.row, column: position.column) else {
      return .clipped
    }

    let width = terminalCellWidth(of: grapheme)
    guard width > 0, position.column + width <= size.columns else {
      return .clipped
    }

    // Clearing every touched cluster prevents stale wide or raw content from surviving
    // beneath the newly written grapheme.
    for column in position.column..<(position.column + width) {
      clearCluster(atRow: position.row, column: column)
    }

    uncheckedSet(
      Cell(content: .grapheme(grapheme), style: style),
      row: position.row,
      column: position.column
    )

    if width == 2 {
      uncheckedSet(
        Cell(content: .continuation, style: style),
        row: position.row,
        column: position.column + 1
      )
    }

    return .written(nextColumn: position.column + width)
  }

  public mutating func writeRaw(
    _ payload: RawTerminalPayload,
    at position: TerminalPosition,
    occupying occupied: Rect,
    repaintPolicy: CellDiffPolicy = .alwaysRepaint
  ) {
    let clippedRegion = occupied.clipped(to: size)

    if let clippedRegion {
      clearClusters(in: clippedRegion)
    }
    clearCluster(atRow: position.row, column: position.column)

    // Zero-width raw payloads are anchored and emitted without advancing the cursor;
    // anchoring replaces any previous visible content at the cell.
    if contains(row: position.row, column: position.column) {
      uncheckedSet(
        Cell(content: .raw(payload), diffPolicy: repaintPolicy),
        row: position.row,
        column: position.column
      )
    }

    guard let clippedRegion else {
      return
    }

    for row in clippedRegion.rowRange {
      for column in clippedRegion.columnRange
      where row != position.row || column != position.column {
        uncheckedSet(
          Cell(content: .continuation, diffPolicy: repaintPolicy),
          row: row,
          column: column
        )
      }
    }
  }

  public mutating func markOpaque(_ region: Rect) {
    guard let clippedRegion = region.clipped(to: size) else {
      return
    }

    for row in clippedRegion.rowRange {
      for column in clippedRegion.columnRange {
        let cell = self[row, column]
        if cell.content == .continuation || cell.width != 1 {
          clearCluster(atRow: row, column: column)
        }

        var opaqueCell = self[row, column]
        opaqueCell.diffPolicy = .opaque
        uncheckedSet(opaqueCell, row: row, column: column)
      }
    }
  }

  private mutating func clearClusters(in region: Rect) {
    for row in region.rowRange {
      for column in region.columnRange {
        clearCluster(atRow: row, column: column)
      }
    }
  }

  package mutating func clearCluster(atRow row: Int, column: Int) {
    guard contains(row: row, column: column),
      let leadingColumn = leadingColumnForCluster(atRow: row, column: column)
    else {
      return
    }

    let width = self[row, leadingColumn].width
    guard width > 0 else {
      uncheckedSet(.blank, row: row, column: column)
      return
    }

    for clearColumn in leadingColumn..<min(leadingColumn + width, size.columns) {
      uncheckedSet(.blank, row: row, column: clearColumn)
    }
  }

  private func leadingColumnForCluster(atRow row: Int, column: Int) -> Int? {
    guard contains(row: row, column: column) else {
      return nil
    }

    if self[row, column].content != .continuation {
      return column
    }

    var candidate = column - 1
    while candidate >= 0 {
      let cell = self[row, candidate]
      if cell.content != .continuation {
        return candidate + cell.width > column ? candidate : column
      }
      candidate -= 1
    }

    return column
  }

  private func index(row: Int, column: Int) -> Int {
    row * size.columns + column
  }

  private func contains(row: Int, column: Int) -> Bool {
    row >= 0 && row < size.rows && column >= 0 && column < size.columns
  }

  private mutating func uncheckedSet(_ cell: Cell, row: Int, column: Int) {
    cells[index(row: row, column: column)] = cell
  }

  public func cell(row: Int, column: Int) -> Cell? {
    guard contains(row: row, column: column) else {
      return nil
    }

    return cells[index(row: row, column: column)]
  }

  package mutating func set(_ cell: Cell, row: Int, column: Int) throws {
    guard contains(row: row, column: column) else {
      throw BufferBoundsError(row: row, column: column, size: size)
    }

    clearCluster(atRow: row, column: column)
    uncheckedSet(cell, row: row, column: column)
  }

  package mutating func setClusterCell(
    _ cell: Cell,
    row: Int,
    column: Int
  ) {
    guard contains(row: row, column: column) else {
      return
    }

    let contentWidth: Int
    switch cell.content {
    case .blank, .continuation:
      contentWidth = 1
    case .grapheme(let grapheme):
      guard isSupportedStoredGrapheme(grapheme) else {
        return
      }
      contentWidth = terminalCellWidth(of: grapheme)
    case .raw(let payload):
      guard let declaredWidth = payload.declaredWidth else {
        contentWidth = 0
        break
      }
      guard let exactWidth = Int(exactly: declaredWidth) else {
        return
      }
      contentWidth = exactWidth
    }
    let width = max(contentWidth, 1)
    let (endColumn, overflow) = column.addingReportingOverflow(width)
    guard !overflow, endColumn <= size.columns else {
      return
    }

    for targetColumn in column..<endColumn {
      clearCluster(atRow: row, column: targetColumn)
    }
    uncheckedSet(cell, row: row, column: column)

    guard width > 1 else {
      return
    }
    for continuationColumn in (column + 1)..<(column + width) {
      uncheckedSet(
        Cell(
          content: .continuation,
          style: cell.style,
          diffPolicy: cell.diffPolicy
        ),
        row: row,
        column: continuationColumn
      )
    }
  }

  public subscript(row: Int, column: Int) -> Cell {
    guard let cell = cell(row: row, column: column) else {
      preconditionFailure("Buffer cell position is out of bounds")
    }

    return cell
  }
}
