import TesseraTerminalCore

/// A visible terminal screen reconstructed by the virtual terminal.
public struct ScreenSnapshot: Sendable, Equatable {
  public static let empty = Self(
    cells: [],
    cursor: TerminalPosition(column: 0, row: 0)
  )

  public let cells: [[RenderedCell]]
  public let cursor: TerminalPosition

  public init(cells: [[RenderedCell]], cursor: TerminalPosition) {
    self.cells = cells
    self.cursor = cursor
  }
}
