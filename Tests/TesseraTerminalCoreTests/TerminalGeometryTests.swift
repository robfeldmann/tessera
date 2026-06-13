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

@Test
func `rect stores origin and size`() {
  let rect = Rect(column: 2, row: 3, columns: 4, rows: 5)

  #expect(rect.origin == TerminalPosition(column: 2, row: 3))
  #expect(rect.size == TerminalSize(columns: 4, rows: 5))
  #expect(rect.columnRange == 2..<6)
  #expect(rect.rowRange == 3..<8)
}

@Test
func `rect contains positions in half open bounds`() {
  let rect = Rect(column: 2, row: 3, columns: 4, rows: 5)

  #expect(rect.contains(column: 2, row: 3))
  #expect(rect.contains(TerminalPosition(column: 5, row: 7)))
  #expect(rect.contains(column: 6, row: 7) == false)
  #expect(rect.contains(column: 5, row: 8) == false)
}

@Test
func `rect intersection returns overlapping region`() {
  let first = Rect(column: 2, row: 3, columns: 5, rows: 4)
  let second = Rect(column: 5, row: 1, columns: 4, rows: 4)

  #expect(first.intersection(second) == Rect(column: 5, row: 3, columns: 2, rows: 2))
}

@Test
func `rect intersection returns nil for empty or disjoint regions`() {
  let rect = Rect(column: 0, row: 0, columns: 2, rows: 2)

  #expect(rect.intersection(Rect(column: 2, row: 0, columns: 2, rows: 2)) == nil)
  #expect(rect.intersection(Rect(column: 0, row: 0, columns: 0, rows: 2)) == nil)
  #expect(rect.intersection(Rect(column: 0, row: 0, columns: 2, rows: -1)) == nil)
}

@Test
func `rect clips to terminal size`() {
  let rect = Rect(column: -2, row: 1, columns: 5, rows: 4)

  #expect(
    rect.clipped(to: TerminalSize(columns: 4, rows: 3))
      == Rect(column: 0, row: 1, columns: 3, rows: 2)
  )
}

@Test
func `rect clipping returns nil when out of bounds`() {
  let rect = Rect(column: 4, row: 0, columns: 2, rows: 2)

  #expect(rect.clipped(to: TerminalSize(columns: 4, rows: 3)) == nil)
}

@Test
func `rect supports negative origins`() {
  let rect = Rect(column: -3, row: -2, columns: 4, rows: 3)

  #expect(rect.contains(column: -3, row: -2))
  #expect(rect.contains(column: 0, row: 0))
  #expect(rect.contains(column: 1, row: 0) == false)
}
