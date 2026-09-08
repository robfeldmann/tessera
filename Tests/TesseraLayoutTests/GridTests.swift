import TesseraCore
import TesseraTerminalBuffer
import TesseraTerminalCore
import Testing

@testable import TesseraLayout

private func gridTestFrame(size: TerminalSize, _ body: (borrowing Frame) -> Void) -> Buffer
{
  var buffer = Buffer(size: size)
  var cursorPosition: TerminalPosition?
  withUnsafeMutablePointer(to: &buffer) { bufferStorage in
    withUnsafeMutablePointer(to: &cursorPosition) { cursorStorage in
      body(Frame(buffer: bufferStorage, cursorPosition: cursorStorage))
    }
  }
  return buffer
}

private final class GridMeasurementTrace {
  var proposals: [ProposedSize] = []
}

private struct GridTraceLeaf: LeafView {
  let width: Int
  let height: Int
  let trace: GridMeasurementTrace

  func sizeThatFits(
    _ proposal: ProposedSize,
    state: inout Void,
    environment: EnvironmentValues
  ) -> TerminalSize {
    trace.proposals.append(proposal)
    return TerminalSize(columns: min(width, proposal.width ?? width), rows: height)
  }

  func render(
    in region: inout RenderRegion,
    state: inout Void,
    environment: EnvironmentValues
  ) {}
}

@Test
func `Grid resolves columns through shared Flex and derives row heights`() {
  let trace = GridMeasurementTrace()
  let graph = ViewGraph(
    root: {
      Grid(columns: [.fill(1), .fill(1)], spacing: 1) {
        GridTraceLeaf(width: 9, height: 1, trace: trace)
        GridTraceLeaf(width: 9, height: 2, trace: trace)
        GridTraceLeaf(width: 9, height: 3, trace: trace)
      }
    },
    size: TerminalSize(columns: 9, rows: 8)
  )

  graph.layoutIfNeeded()

  #expect(trace.proposals.contains(ProposedSize(width: 4, height: 8)))
  #expect(graph.dump().contains("Grid"))
  #expect(graph.dump().contains("measured=(9x8)"))
}

@Test
func `Grid handles empty and incomplete rows without creating phantom children`() {
  let graph = ViewGraph(
    root: {
      Grid(columns: [.length(3), .length(3)], spacing: 1) {
        Text("one")
        Text("two")
        Text("three")
      }
    },
    size: TerminalSize(columns: 7, rows: 4)
  )

  let buffer = gridTestFrame(size: TerminalSize(columns: 7, rows: 4)) {
    graph.render(into: $0)
  }
  #expect(buffer[0, 0].content == Cell.Content.grapheme("o"))
  #expect(buffer[0, 4].content == Cell.Content.grapheme("t"))
  #expect(buffer[1, 0].content == Cell.Content.blank)
  #expect(buffer[2, 0].content == Cell.Content.grapheme("t"))
}
