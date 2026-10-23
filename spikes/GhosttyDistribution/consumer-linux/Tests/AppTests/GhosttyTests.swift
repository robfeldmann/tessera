import TesseraTerminalSnapshotSupport
import Testing

@Test func ghosttyRendersFedBytes() {
  let terminal = VirtualTerminal.ghostty(cols: 10, rows: 2)
  terminal.feed("hi\r\n\u{1B}[31mx")
  #expect(terminal.text(row: 0).hasPrefix("hi"))
  #expect(terminal.cell(row: 1, column: 0).foreground == .indexed(1))
}
