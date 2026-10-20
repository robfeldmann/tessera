import Testing
import Tessera
import TesseraTerminalSnapshotSupport

@testable import LiveSocketKit

/// The render mirror calls `ViewGraph.render(into:)` a second time. These tests pin the
/// side effects that make the mirror a stopgap for a draw tap on `TerminalSession`.
private func mirrorRender(_ graph: ViewGraph) {
  _ = VirtualTerminal.snapshot(size: TerminalSize(columns: 80, rows: 24)) { frame in
    graph.render(into: frame)
  }
}

@Test
func `a mirror render clears the dirty flag the real draw depends on`() {
  let graph = CounterApp().graph
  mirrorRender(graph)
  #expect(!graph.needsRender)

  graph.update()
  #expect(graph.needsRender)

  // A query that mirrors between `update()` and the real draw would make the loop skip it.
  mirrorRender(graph)
  #expect(!graph.needsRender)
}

@Test
func `a mirror render records a render request in the graph statistics`() {
  let graph = CounterApp().graph
  mirrorRender(graph)
  graph.update()
  #expect(!graph.diagnostics.statistics.invalidationReasons.values.contains(.renderRequested))

  mirrorRender(graph)
  #expect(graph.diagnostics.statistics.invalidationReasons.values.contains(.renderRequested))
}

@Test
func `the mirror snapshot drops the cursor the frame requested`() {
  var requested: TerminalPosition?
  let snapshot = VirtualTerminal.snapshot(size: TerminalSize(columns: 20, rows: 3)) { frame in
    frame.write("hi", at: TerminalPosition(column: 0, row: 0))
    frame.setCursorPosition(TerminalPosition(column: 7, row: 2))
    requested = TerminalPosition(column: 7, row: 2)
  }
  #expect(requested == TerminalPosition(column: 7, row: 2))
  #expect(snapshot.cursor != requested)
}
