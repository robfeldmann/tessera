import InlineSnapshotTesting
import TesseraTerminalANSI
import TesseraTerminalBuffer
import TesseraTerminalCore
import TesseraTestSupport
import Testing

@testable import TesseraCore

@Test
func `styled text applies its style only to written cells`() {
  let size = TerminalSize(columns: 4, rows: 1)
  let style = Style(
    foreground: .indexed(196),
    background: .indexed(42),
    attributes: [.bold, .italic]
  )
  let graph = ViewGraph(root: { Text("Hi", style: style) }, size: size)
  let buffer = withTestFrame(size: size) { graph.render(into: $0) }.buffer

  assertInlineSnapshot(of: buffer, as: .bufferState) {
    """
    H{fg=indexed(196),bg=indexed(42),bold,italic} i{fg=indexed(196),bg=indexed(42),bold,italic} · ·
    """
  }
}
