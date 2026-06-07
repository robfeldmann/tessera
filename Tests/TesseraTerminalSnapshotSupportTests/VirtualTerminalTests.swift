import Dependencies
import DependenciesTestSupport
import TesseraTerminalCore
import TesseraTerminalSnapshotSupport
import Testing

@Test(
  .dependencies {
    $0.virtualTerminal = .ghostty(cols: 4, rows: 2)
  }
)
func `initial screen is blank`() {
  @Dependency(\.virtualTerminal) var terminal

  #expect(terminal.text(row: 0) == "    ")
  #expect(terminal.text(row: 1) == "    ")
  #expect(terminal.snapshot().cells.count == 2)
}

@Test(
  .dependencies {
    $0.virtualTerminal = .ghostty(cols: 5, rows: 2)
  }
)
func `characters write into visible cells`() {
  @Dependency(\.virtualTerminal) var terminal

  terminal.feed("Hi")

  #expect(terminal.text(row: 0) == "Hi   ")
  #expect(terminal.cell(row: 0, column: 0).character == "H")
  #expect(terminal.cell(row: 0, column: 1).character == "i")
}

@Test(
  .dependencies {
    $0.virtualTerminal = .ghostty(cols: 5, rows: 3)
  }
)
func `cursor movement writes at requested position`() {
  @Dependency(\.virtualTerminal) var terminal

  terminal.feed("\u{1B}[2;3HX")

  #expect(terminal.text(row: 1) == "  X  ")
  #expect(terminal.cell(row: 1, column: 2).character == "X")
}

@Test(
  .dependencies {
    $0.virtualTerminal = .ghostty(cols: 5, rows: 1)
  }
)
func `erase in line clears visible cells`() {
  @Dependency(\.virtualTerminal) var terminal

  terminal.feed("Hello")
  terminal.feed("\u{1B}[1;2H\u{1B}[K")

  #expect(terminal.text(row: 0) == "H    ")
}

@Test(
  .dependencies {
    $0.virtualTerminal = .ghostty(cols: 4, rows: 1)
  }
)
func `sgr style and colors are inspectable`() {
  @Dependency(\.virtualTerminal) var terminal

  terminal.feed("\u{1B}[1;3;4;7;38;5;196;48;2;1;2;3mX")
  let cell = terminal.cell(row: 0, column: 0)

  #expect(cell.character == "X")
  #expect(cell.bold)
  #expect(cell.italic)
  #expect(cell.underline)
  #expect(cell.reverse)
  #expect(cell.foreground == RenderedColor.indexed(196))
  #expect(cell.background == RenderedColor.rgb(1, 2, 3))
}

@Test(
  .dependencies {
    $0.virtualTerminal = .ghostty(cols: 8, rows: 3)
  }
)
func `cursor position is inspectable`() {
  @Dependency(\.virtualTerminal) var terminal

  terminal.feed("\u{1B}[3;5H")

  #expect(terminal.cursorPosition() == TerminalPosition(column: 4, row: 2))
}
