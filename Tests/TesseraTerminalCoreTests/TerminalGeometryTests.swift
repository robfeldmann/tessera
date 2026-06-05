import Testing

@testable import TesseraTerminalCore

@Test
func `terminal size stores columns and rows`() {
  let size = TerminalSize(columns: 80, rows: 24)

  #expect(size.columns == 80)
  #expect(size.rows == 24)
}

@Test
func `terminal position stores column and row`() {
  let position = TerminalPosition(column: 4, row: 2)

  #expect(position.column == 4)
  #expect(position.row == 2)
}
