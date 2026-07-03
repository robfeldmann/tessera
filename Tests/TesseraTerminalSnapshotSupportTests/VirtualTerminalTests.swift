import TesseraTerminalCore
import TesseraTerminalSnapshotSupport
import Testing

@Test(
  .disabled(
    if: VirtualTerminal.isGhosttyUnavailable,
    "Windows snapshot coverage is deferred until libghostty-vt builds on Windows."
  )
)
func `initial screen is blank`() {
  let terminal = VirtualTerminal.ghosttyOrUnavailable(cols: 4, rows: 2)

  #expect(terminal.text(row: 0) == "    ")
  #expect(terminal.text(row: 1) == "    ")
  #expect(terminal.snapshot().cells.count == 2)
}

@Test(
  .disabled(
    if: VirtualTerminal.isGhosttyUnavailable,
    "Windows snapshot coverage is deferred until libghostty-vt builds on Windows."
  )
)
func `characters write into visible cells`() {
  let terminal = VirtualTerminal.ghosttyOrUnavailable(cols: 5, rows: 2)

  terminal.feed("Hi")

  #expect(terminal.text(row: 0) == "Hi   ")
  #expect(terminal.cell(row: 0, column: 0).character == "H")
  #expect(terminal.cell(row: 0, column: 1).character == "i")
}

@Test(
  .disabled(
    if: VirtualTerminal.isGhosttyUnavailable,
    "Windows snapshot coverage is deferred until libghostty-vt builds on Windows."
  )
)
func `cursor movement writes at requested position`() {
  let terminal = VirtualTerminal.ghosttyOrUnavailable(cols: 5, rows: 3)

  terminal.feed("\u{1B}[2;3HX")

  #expect(terminal.text(row: 1) == "  X  ")
  #expect(terminal.cell(row: 1, column: 2).character == "X")
}

@Test(
  .disabled(
    if: VirtualTerminal.isGhosttyUnavailable,
    "Windows snapshot coverage is deferred until libghostty-vt builds on Windows."
  )
)
func `erase in line clears visible cells`() {
  let terminal = VirtualTerminal.ghosttyOrUnavailable(cols: 5, rows: 1)

  terminal.feed("Hello")
  terminal.feed("\u{1B}[1;2H\u{1B}[K")

  #expect(terminal.text(row: 0) == "H    ")
}

@Test(
  .disabled(
    if: VirtualTerminal.isGhosttyUnavailable,
    "Windows snapshot coverage is deferred until libghostty-vt builds on Windows."
  )
)
func `sgr style and colors are inspectable`() {
  let terminal = VirtualTerminal.ghosttyOrUnavailable(cols: 4, rows: 1)

  terminal.feed("\u{1B}[1;2;3;4;7;9;38;5;196;48;2;1;2;3mX")
  let cell = terminal.cell(row: 0, column: 0)

  #expect(cell.character == "X")
  #expect(cell.bold)
  #expect(cell.dim)
  #expect(cell.italic)
  #expect(cell.underline)
  #expect(cell.reverse)
  #expect(cell.strikethrough)
  #expect(cell.foreground == RenderedColor.indexed(196))
  #expect(cell.background == RenderedColor.rgb(1, 2, 3))
}

@Test(
  .disabled(
    if: VirtualTerminal.isGhosttyUnavailable,
    "Windows snapshot coverage is deferred until libghostty-vt builds on Windows."
  )
)
func `cursor position is inspectable`() {
  let terminal = VirtualTerminal.ghosttyOrUnavailable(cols: 8, rows: 3)

  terminal.feed("\u{1B}[3;5H")

  #expect(terminal.cursorPosition() == TerminalPosition(column: 4, row: 2))
}
