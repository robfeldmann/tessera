import TesseraTerminalCore
import TesseraTestSupport
import Testing

@testable import TesseraCore

/// A leaf that takes the height it is offered, and three rows when it is offered none.
private struct FillingLeaf: LeafView {
  func sizeThatFits(
    _ proposal: ProposedSize,
    state: inout Void,
    environment: EnvironmentValues
  ) -> TerminalSize {
    TerminalSize(columns: proposal.width ?? 1, rows: proposal.height ?? 3)
  }

  func render(
    in region: inout RenderRegion, state: inout Void, environment: EnvironmentValues
  ) {}
}

private let size = TerminalSize(columns: 20, rows: 6)

@Test
func `a nil height proposal measures the content and a finite one measures the offer`() {
  let graph = ViewGraph(root: { FillingLeaf() }, size: size)

  #expect(
    graph.measuredRootSize(proposing: ProposedSize(width: 10, height: nil))
      == TerminalSize(columns: 10, rows: 3))
  #expect(
    graph.measuredRootSize(proposing: ProposedSize(width: 10, height: 500))
      == TerminalSize(columns: 10, rows: 500))
  #expect(
    graph.measuredRootSize(proposing: ProposedSize(width: 10, height: 1_000))
      == TerminalSize(columns: 10, rows: 1_000))
}

@Test
func `fixed-height content answers every height the same way`() {
  let graph = ViewGraph(root: { Text("two\nlines") }, size: size)

  let short = graph.measuredRootSize(proposing: ProposedSize(width: 10, height: 500))
  let tall = graph.measuredRootSize(proposing: ProposedSize(width: 10, height: 1_000))

  #expect(short == tall)
  #expect(short.rows == 2)
}

@Test
func `measuring leaves the statistics alone and makes the next pass measure again`() {
  let graph = ViewGraph(root: { Text("steady") }, size: size)
  _ = withTestFrame(size: size) { graph.render(into: $0) }
  #expect(graph.needsLayout == false)
  let measurements = graph.statistics.measurements

  _ = graph.measuredRootSize(proposing: ProposedSize(width: 3, height: nil))

  #expect(graph.statistics.measurements == measurements)
  #expect(graph.needsLayout)
  #expect(graph.needsRender)
  _ = withTestFrame(size: size) { graph.render(into: $0) }
  #expect(graph.needsLayout == false)
  #expect(
    graph.diagnostics.nodes.first { $0.parentIdentity == nil }?.measuredSize?.columns == 6
  )
}
