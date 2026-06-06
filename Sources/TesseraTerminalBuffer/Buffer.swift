import TesseraTerminalCore

/// Display attributes for a terminal cell.
public struct Style: Sendable, Equatable {
  public init() {}
}

/// A single terminal character cell.
public struct Cell: Sendable, Equatable {
  public static let blank = Self(character: " ")

  public var character: Character
  public var style: Style
  public var width: Int

  public init(character: Character, style: Style = Style(), width: Int = 1) {
    self.character = character
    self.style = style
    self.width = width
  }
}

/// A rectangular terminal buffer backed by flat row-major cell storage.
public struct Buffer: Sendable, Equatable {
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

      self[position.row, column] = Cell(character: character, style: style)
    }
  }

  private func index(row: Int, column: Int) -> Int {
    row * size.columns + column
  }

  public subscript(row: Int, column: Int) -> Cell {
    get {
      cells[index(row: row, column: column)]
    }
    set {
      cells[index(row: row, column: column)] = newValue
    }
  }
}
