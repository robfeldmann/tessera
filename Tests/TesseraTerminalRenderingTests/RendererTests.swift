import InlineSnapshotTesting
import SnapshotTestingCustomDump
import TesseraTerminalBuffer
import TesseraTerminalCore
import TesseraTerminalTestSupport
import Testing

@testable import TesseraTerminalRendering

@Test
func `rendering an empty buffer emits a full repaint`() {
  let buffer = Buffer(size: TerminalSize(columns: 3, rows: 2))
  let bytes = Renderer.render(buffer)

  assertInlineSnapshot(of: RendererCustomDump(bytes: bytes), as: .customDump) {
    """
    [home]
    bytes: 1B 5B 31 3B 31 48
    text:  ␛[1;1H

    [row 0]
    bytes: 20 20 20 0D 0A
    text:  ···␍␊

    [row 1]
    bytes: 20 20 20
    text:  ···
    """
  }
}

@Test
func `rendering a buffer with text emits row major cell bytes`() {
  var buffer = Buffer(size: TerminalSize(columns: 4, rows: 2))
  buffer.write("Hi", at: TerminalPosition(column: 1, row: 0))
  buffer.write("q", at: TerminalPosition(column: 3, row: 1))

  let bytes = Renderer.render(buffer)

  assertInlineSnapshot(of: RendererCustomDump(bytes: bytes), as: .customDump) {
    """
    [home]
    bytes: 1B 5B 31 3B 31 48
    text:  ␛[1;1H

    [row 0]
    bytes: 20 48 69 20 0D 0A
    text:  ·Hi·␍␊

    [row 1]
    bytes: 20 20 20 71
    text:  ···q
    """
  }
}
