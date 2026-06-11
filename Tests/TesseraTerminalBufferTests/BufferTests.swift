import InlineSnapshotTesting
import SnapshotTestingCustomDump
import TesseraTerminalCore
import TesseraTerminalTestSupport
import Testing

@testable import TesseraTerminalBuffer

@Test
func `buffer initializes every cell with blank fill`() {
  let buffer = Buffer(size: TerminalSize(columns: 3, rows: 2))

  assertInlineSnapshot(of: buffer, as: .customDump) {
    """
    ···
    ···
    """
  }
}

@Test
func `buffer initializes every cell with custom fill`() {
  let fill = Cell(character: ".")
  let buffer = Buffer(size: TerminalSize(columns: 2, rows: 2), fill: fill)

  assertInlineSnapshot(of: buffer, as: .customDump) {
    """
    ..
    ..
    """
  }
}

@Test
func `package set writes cells by row and column`() throws {
  var buffer = Buffer(size: TerminalSize(columns: 3, rows: 2))
  let cell = Cell(character: "X")

  try buffer.set(cell, row: 1, column: 2)

  assertInlineSnapshot(of: buffer, as: .customDump) {
    """
    ···
    ··X
    """
  }
}

@Test
func `write stores characters from the requested position`() {
  var buffer = Buffer(size: TerminalSize(columns: 5, rows: 2))

  buffer.write("hey", at: TerminalPosition(column: 1, row: 1))

  assertInlineSnapshot(of: buffer, as: .customDump) {
    """
    ·····
    ·hey·
    """
  }
}

@Test
func `write clips text past the right edge`() {
  var buffer = Buffer(size: TerminalSize(columns: 5, rows: 2))

  buffer.write("hello", at: TerminalPosition(column: 3, row: 0))

  assertInlineSnapshot(of: buffer, as: .customDump) {
    """
    ···he
    ·····
    """
  }
}

@Test
func `write clips text before the left edge`() {
  var buffer = Buffer(size: TerminalSize(columns: 5, rows: 1))

  buffer.write("hello", at: TerminalPosition(column: -2, row: 0))

  assertInlineSnapshot(of: buffer, as: .customDump) {
    """
    llo··
    """
  }
}

@Test
func `write outside the vertical bounds does nothing`() {
  var buffer = Buffer(size: TerminalSize(columns: 3, rows: 2))

  buffer.write("top", at: TerminalPosition(column: 0, row: -1))
  buffer.write("end", at: TerminalPosition(column: 0, row: 2))

  assertInlineSnapshot(of: buffer, as: .customDump) {
    """
    ···
    ···
    """
  }
}
