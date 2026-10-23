import TesseraTerminalSnapshotSupport
import Testing

@Test func `Ghostty renders the fed bytes through the published bundle`() {
  let terminal = VirtualTerminal.ghostty(cols: 20, rows: 3)
  terminal.feed("hello\r\n\u{1B}[31mred\u{1B}[0m")

  #expect(terminal.text(row: 0) == "hello" + String(repeating: " ", count: 15))
  #expect(terminal.text(row: 1) == "red" + String(repeating: " ", count: 17))
  let cell = terminal.cell(row: 1, column: 0)
  #expect(cell.character == "r")
  #expect(cell.foreground == .indexed(1))
  let cursor = terminal.cursorPosition()
  #expect(cursor.column == 3)
  #expect(cursor.row == 1)
}
