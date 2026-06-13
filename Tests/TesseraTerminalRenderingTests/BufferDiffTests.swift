import TesseraTerminalBuffer
import TesseraTerminalCore
import Testing

@testable import TesseraTerminalRendering

@Test
func `diff returns no runs for identical buffers`() {
  var previous = Buffer(size: TerminalSize(columns: 4, rows: 2))
  previous.write("same", at: TerminalPosition(column: 0, row: 0))
  let current = previous

  #expect(BufferDiff.damageRuns(previous: previous, current: current).isEmpty)
}

@Test
func `diff returns a single changed cell`() {
  let previous = Buffer(size: TerminalSize(columns: 4, rows: 1))
  var current = previous
  current.write("x", at: TerminalPosition(column: 2, row: 0))

  expectRuns(
    previous: previous,
    current: current,
    expected: [
      RowDamageRun(row: 0, columns: 2..<3)
    ]
  )
}

@Test
func `diff coalesces changed run`() {
  let previous = Buffer(size: TerminalSize(columns: 5, rows: 1))
  var current = previous
  current.write("abc", at: TerminalPosition(column: 1, row: 0))

  expectRuns(
    previous: previous,
    current: current,
    expected: [
      RowDamageRun(row: 0, columns: 1..<4)
    ]
  )
}

@Test
func `diff skips equal rows`() {
  var previous = Buffer(size: TerminalSize(columns: 4, rows: 2))
  previous.write("same", at: TerminalPosition(column: 0, row: 0))
  var current = previous
  current.write("x", at: TerminalPosition(column: 1, row: 1))

  expectRuns(
    previous: previous,
    current: current,
    expected: [
      RowDamageRun(row: 1, columns: 1..<2)
    ]
  )
}

@Test
func `always repaint pierces equality`() throws {
  var previous = Buffer(size: TerminalSize(columns: 3, rows: 1))
  try previous.set(
    Cell(content: .grapheme("x"), diffPolicy: .alwaysRepaint),
    row: 0,
    column: 1
  )
  let current = previous

  expectRuns(
    previous: previous,
    current: current,
    expected: [
      RowDamageRun(row: 0, columns: 1..<2)
    ]
  )
}

@Test
func `opaque cells split and skip dirty runs`() {
  let previous = Buffer(size: TerminalSize(columns: 5, rows: 1))
  var current = previous
  current.write("abcde", at: TerminalPosition(column: 0, row: 0))
  current.markOpaque(Rect(column: 2, row: 0, columns: 1, rows: 1))

  expectRuns(
    previous: previous,
    current: current,
    expected: [
      RowDamageRun(row: 0, columns: 0..<2),
      RowDamageRun(row: 0, columns: 3..<5),
    ]
  )
}

@Test
func `size mismatch produces full repaint runs`() {
  let previous = Buffer(size: TerminalSize(columns: 2, rows: 1))
  let current = Buffer(size: TerminalSize(columns: 3, rows: 2))

  expectRuns(
    previous: previous,
    current: current,
    expected: [
      RowDamageRun(row: 0, columns: 0..<3),
      RowDamageRun(row: 1, columns: 0..<3),
    ]
  )
}

@Test
func `style only changes are dirty`() throws {
  let previous = Buffer(size: TerminalSize(columns: 3, rows: 1))
  var current = previous
  try current.set(
    Cell(content: .blank, style: Style(attributes: [.bold])),
    row: 0,
    column: 1
  )

  expectRuns(
    previous: previous,
    current: current,
    expected: [
      RowDamageRun(row: 0, columns: 1..<2)
    ]
  )
}

@Test
func `wide grapheme continuations participate in damage`() {
  var previous = Buffer(size: TerminalSize(columns: 4, rows: 1))
  previous.write("你", at: TerminalPosition(column: 1, row: 0))
  var current = previous
  current.write("x", at: TerminalPosition(column: 2, row: 0))

  expectRuns(
    previous: previous,
    current: current,
    expected: [
      RowDamageRun(row: 0, columns: 1..<3)
    ]
  )
}

@Test
func `variation selector wide replacement damages trailing clear cell`() {
  var previous = Buffer(size: TerminalSize(columns: 4, rows: 1))
  previous.write("♥️", at: TerminalPosition(column: 1, row: 0))
  var current = previous
  current.write("x", at: TerminalPosition(column: 1, row: 0))

  expectRuns(
    previous: previous,
    current: current,
    expected: [
      RowDamageRun(row: 0, columns: 1..<3)
    ]
  )
}

@Test
func `full repaint skips opaque gaps`() {
  var current = Buffer(size: TerminalSize(columns: 4, rows: 1))
  current.markOpaque(Rect(column: 1, row: 0, columns: 2, rows: 1))

  #expect(
    BufferDiff.damageRuns(previous: nil, current: current) == [
      RowDamageRun(row: 0, columns: 0..<1),
      RowDamageRun(row: 0, columns: 3..<4),
    ]
  )
}

private func expectRuns(
  previous: Buffer,
  current: Buffer,
  expected: [RowDamageRun]
) {
  #expect(BufferDiff.damageRuns(previous: previous, current: current) == expected)
}
