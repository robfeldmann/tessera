import InlineSnapshotTesting
import SnapshotTesting
import TesseraTerminalBuffer
import TesseraTerminalCore
import TesseraTerminalSnapshotSupport
import TesseraTerminalTestSupport
import Testing

@testable import TesseraTerminalRendering

@Test(
  .disabled(
    if: VirtualTerminal.isGhosttyUnavailable,
    "Windows snapshot coverage is deferred until libghostty-vt builds on Windows."
  )
)
func `renderer output can be inspected as terminal text`() {
  var buffer = Buffer(size: TerminalSize(columns: 4, rows: 2))
  buffer.write("Hi", at: TerminalPosition(column: 0, row: 0))
  buffer.write("q", at: TerminalPosition(column: 0, row: 1))

  let terminal = VirtualTerminal.ghosttyOrUnavailable(cols: 4, rows: 2)
  terminal.feed(Renderer.render(buffer))

  assertInlineSnapshot(of: terminal.snapshot(), as: .terminalText()) {
    """
    Hi
    q
    """
  }
}

@Test(
  .disabled(
    if: VirtualTerminal.isGhosttyUnavailable,
    "Windows snapshot coverage is deferred until libghostty-vt builds on Windows."
  )
)
func `renderer output can be inspected as styled terminal state`() {
  var buffer = Buffer(size: TerminalSize(columns: 3, rows: 2))
  buffer.write("H", at: TerminalPosition(column: 0, row: 0))
  buffer.write("i", at: TerminalPosition(column: 2, row: 0))
  buffer.write("q", at: TerminalPosition(column: 0, row: 1))
  buffer.write("r", at: TerminalPosition(column: 2, row: 1))

  let terminal = VirtualTerminal.ghosttyOrUnavailable(cols: 3, rows: 2)
  terminal.feed(Renderer.render(buffer))

  assertInlineSnapshot(of: terminal.snapshot(), as: .terminalStyledGrid(trim: .none)) {
    """
    ── chars ──
    H i
    q r
    ── style ──
    T.T
    T.T
    """
  }
}

@Test(
  .disabled(
    if: VirtualTerminal.isGhosttyUnavailable,
    "Windows snapshot coverage is deferred until libghostty-vt builds on Windows."
  )
)
func `terminal debug dump includes cursor and styled cell metadata`() {
  let terminal = VirtualTerminal.ghosttyOrUnavailable(cols: 4, rows: 2)

  terminal.feed("\u{1B}[2;2H\u{1B}[1;3;4;7;38;5;196;48;2;1;2;3mX")

  assertInlineSnapshot(of: terminal.snapshot(), as: .terminalDebugDump) {
    """
    cursor: row 1, column 2
    rows: 2
    row 0: ····
    row 1: ·X··
      [1,1] X fg=indexed(196),bg=rgb(1,2,3),bold,italic,underline,reverse
    """
  }
}
