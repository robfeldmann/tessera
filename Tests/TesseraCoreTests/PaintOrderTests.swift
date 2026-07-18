import InlineSnapshotTesting
import TesseraTerminalCore
import Testing

@testable import TesseraCore

private final class RenderTrace {
  var entries: [String] = []
}

private struct TraceLeaf: LeafView {
  let label: String
  let trace: RenderTrace

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
    trace.entries.append(label)
  }
}

private struct SourceOrderedTrace: View {
  let trace: RenderTrace

  var body: some View {
    TraceLeaf(label: "first", trace: trace)
    TraceLeaf(label: "second", trace: trace)
    TraceLeaf(label: "third", trace: trace)
  }
}

@Test
func `leaf rendering follows source order`() {
  let trace = RenderTrace()
  let size = TerminalSize(columns: 1, rows: 3)
  let graph = ViewGraph(root: { SourceOrderedTrace(trace: trace) }, size: size)

  _ = withTestFrame(size: size) { graph.render(into: $0) }

  assertInlineSnapshot(of: trace.entries.joined(separator: "\n"), as: .lines) {
    """
    first
    second
    third
    """
  }
}
