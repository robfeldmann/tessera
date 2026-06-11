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

    for (offset, character) in string.enumerated() {
      let column = position.column + offset

      if column >= size.columns {
        return
      }

      guard column >= 0 else {
        continue
      }

      uncheckedSet(
        Cell(character: character, style: style),
        row: position.row,
        column: column
      )
    }
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

    uncheckedSet(cell, row: row, column: column)
  }

  public subscript(row: Int, column: Int) -> Cell {
    guard let cell = cell(row: row, column: column) else {
      preconditionFailure("Buffer cell position is out of bounds")
    }

    return cell
  }
}
