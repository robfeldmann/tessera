import CustomDump
import TesseraTerminalBuffer
import TesseraTerminalCore
import Testing

@testable import TesseraTerminal

@Test
func `frame exposes configured terminal size`() {
  let size = TerminalSize(columns: 12, rows: 3)
  let frame = Frame(size: size)

  expectNoDifference(frame.size, size)
}

@Test
func `frame write stores styled cells in backing buffer`() {
  let style = Style()
  let frame = Frame(size: TerminalSize(columns: 4, rows: 2))

  frame.write("Hi", at: TerminalPosition(column: 1, row: 1), style: style)

  expectNoDifference(frame.buffer[1, 1], Cell(character: "H", style: style))
  expectNoDifference(frame.buffer[1, 2], Cell(character: "i", style: style))
}
