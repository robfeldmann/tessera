import InlineSnapshotTesting
import TesseraTerminalANSI
import TesseraTerminalBuffer
import TesseraTerminalCore
import TesseraTestSupport
import Testing

@testable import TesseraCore

private struct OverflowLeaf: LeafView {
  func sizeThatFits(
    _ proposal: ProposedSize,
    state: inout Void,
    environment: EnvironmentValues
  ) -> TerminalSize {
    TerminalSize(columns: 1, rows: 1)
  }

  func render(
    in region: inout RenderRegion,
    state: inout Void,
    environment: EnvironmentValues
  ) {
    region.write("XYZ", at: TerminalPosition(column: 0, row: 0))
  }
}

private struct OverflowHost: View {
  var body: some View {
    OverflowLeaf()
  }
}

@Test
func `text rendering clips a wide grapheme at the region edge`() {
  let size = TerminalSize(columns: 2, rows: 1)
  let graph = ViewGraph(root: { Text("A界B") }, size: size)
  let buffer = withTestFrame(size: size) { graph.render(into: $0) }.buffer

  assertInlineSnapshot(of: buffer, as: .bufferState) {
    """
    A ·
    """
  }
}

@Test
func `leaf writes cannot escape their placed frame`() {
  let size = TerminalSize(columns: 4, rows: 1)
  let graph = ViewGraph(root: { OverflowHost() }, size: size)
  let buffer = withTestFrame(size: size) { graph.render(into: $0) }.buffer

  assertInlineSnapshot(of: buffer, as: .bufferState) {
    """
    X · · ·
    """
  }
}

@Test
func `render regions translate nest clip fill and request cursors`() {
  let size = TerminalSize(columns: 6, rows: 2)
  let result = withTestFrame(size: size) { frame in
    frame.withRenderRegion(
      in: Rect(column: 1, row: 0, columns: 4, rows: 2),
      clip: Rect(column: 1, row: 0, columns: 3, rows: 2)
    ) { region in
      #expect(region.bounds == Rect(column: 0, row: 0, columns: 4, rows: 2))
      region.write("ABCD", at: TerminalPosition(column: 0, row: 0))
      region.with(Rect(column: 1, row: 1, columns: 2, rows: 1)) { child in
        child.fill(Cell(character: "#"), in: child.bounds)
      }
      region.requestCursor(at: TerminalPosition(column: 2, row: 1))
    }
  }

  assertInlineSnapshot(of: result.buffer, as: .bufferState) {
    """
    · A B C · ·
    · · # # · ·
    """
  }
  #expect(result.cursor == TerminalPosition(column: 3, row: 1))
}

@Test
func `fill preserves wide cell clusters`() {
  let size = TerminalSize(columns: 4, rows: 1)
  let buffer = withTestFrame(size: size) { frame in
    frame.withRenderRegion(in: Rect(column: 0, row: 0, columns: 4, rows: 1)) { region in
      region.fill(Cell(character: "界"), in: region.bounds)
    }
  }.buffer

  assertInlineSnapshot(of: buffer, as: .bufferState) {
    """
    界 ◌ 界 ◌
    """
  }
}

@Test
func `raw payloads remain clipped to their region`() {
  let size = TerminalSize(columns: 5, rows: 1)
  let payload = RawTerminalPayload(bytes: [0x41], declaredWidth: 2)
  let buffer = withTestFrame(size: size) { frame in
    frame.withRenderRegion(in: Rect(column: 1, row: 0, columns: 3, rows: 1)) { region in
      region.raw(payload, at: TerminalPosition(column: 1, row: 0))
    }
  }.buffer

  assertInlineSnapshot(of: buffer, as: .bufferState) {
    """
    · · R2! ◌! ·
    """
  }
}
