import TesseraTerminalCore
import TesseraTestSupport
import Testing

@testable import TesseraCore

@Test
func `injected clock supplies every graph pass duration`() {
  let size = TerminalSize(columns: 4, rows: 1)
  let origin = ContinuousClock.now
  var readings = 0
  let steppingClock = {
    readings += 1
    return origin.advanced(by: .milliseconds(10 * readings))
  }
  let graph = ViewGraph(root: { Text("tick") }, size: size, now: steppingClock)

  graph.update()
  expectDurations(
    graph.statistics, update: .milliseconds(10), layout: .zero, render: .zero)

  _ = withTestFrame(size: size) { graph.render(into: $0) }
  expectDurations(
    graph.statistics,
    update: .milliseconds(10),
    layout: .milliseconds(10),
    render: .milliseconds(10)
  )
}

@Test
func `graphs sharing deterministic clocks produce equal diagnostics`() {
  let size = TerminalSize(columns: 4, rows: 1)
  let origin = ContinuousClock.now
  let fixedClock = { origin }
  func makeGraph() -> ViewGraph {
    ViewGraph(root: { Text("same") }, size: size, now: fixedClock)
  }
  let first = makeGraph()
  let second = makeGraph()

  _ = withTestFrame(size: size) { first.render(into: $0) }
  _ = withTestFrame(size: size) { second.render(into: $0) }

  #expect(first.diagnostics == second.diagnostics)
  #expect(first.diagnostics.statistics.renderDuration == .zero)
}

private func expectDurations(
  _ statistics: GraphStatistics,
  update: Duration,
  layout: Duration,
  render: Duration
) {
  #expect(statistics.updateDuration == update)
  #expect(statistics.layoutDuration == layout)
  #expect(statistics.renderDuration == render)
}
