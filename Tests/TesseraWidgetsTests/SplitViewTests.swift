import InlineSnapshotTesting
import TesseraCore
import TesseraLayout
import TesseraTerminalBuffer
import TesseraTerminalCore
import TesseraTestSupport
import Testing

@testable import TesseraWidgets

private func renderSplitView(
  size: TerminalSize,
  _ body: (borrowing Frame) -> Void
) -> Buffer {
  var buffer = Buffer(size: size)
  var cursorPosition: TerminalPosition?
  withUnsafeMutablePointer(to: &buffer) { bufferStorage in
    withUnsafeMutablePointer(to: &cursorPosition) { cursorStorage in
      body(Frame(buffer: bufferStorage, cursorPosition: cursorStorage))
    }
  }
  return buffer
}

private final class SplitViewModel {
  var axis: Axis = .horizontal
  var panes: [SplitViewPane]

  var axisBinding: Binding<Axis> {
    Binding(get: { self.axis }, set: { self.axis = $0 })
  }

  var panesBinding: Binding<[SplitViewPane]> {
    Binding(get: { self.panes }, set: { self.panes = $0 })
  }

  init(_ panes: [SplitViewPane]) {
    self.panes = panes
  }
}

private func paneFrame(_ graph: ViewGraph, id: String) throws -> Rect {
  try #require(
    graph.diagnostics.nodes.first { $0.identity.description == "root/id(\(id))" }
  ).frame
}

@Test
func `split view renders two horizontal panes and divider`() {
  let size = TerminalSize(columns: 8, rows: 2)
  let model = SplitViewModel([
    SplitViewPane(id: "left", sizing: .init(requestedIdeal: 3)),
    SplitViewPane(id: "right", sizing: .init(requestedIdeal: 4)),
  ])
  let graph = ViewGraph(
    root: {
      SplitView(axis: model.axisBinding, panes: model.panesBinding) {
        Text("L")
        Text("R")
      }
    },
    size: size
  )

  let buffer = renderSplitView(size: size) { graph.render(into: $0) }
  assertInlineSnapshot(of: buffer, as: .bufferState) {
    """
    L · · │ R · · ·
    · · · │ · · · ·
    """
  }
  assertInlineSnapshot(of: graph, as: .viewGraph) {
    """
    root SplitView [proposal=(8,2), measured=(8x2), frame=(0,0,8x2), clip=(0,0,8x2)]
      id(left) _SplitPane [proposal=(3,2), measured=(3x2), frame=(0,0,3x2), clip=(0,0,3x2), environmentOverrides=1]
        index(0) Text [proposal=(3,2), measured=(1x1), frame=(0,0,1x1), clip=(0,0,1x1), environmentOverrides=1]
      explicit(_SplitViewDividerID(leading: AnyHashable("left"), trailing: AnyHashable("right"))) Divider [proposal=(1,2), measured=(1x2), frame=(3,0,1x2), clip=(3,0,1x2), environmentOverrides=1]
      id(right) _SplitPane [proposal=(4,2), measured=(4x2), frame=(4,0,4x2), clip=(4,0,4x2), environmentOverrides=1]
        index(0) Text [proposal=(4,2), measured=(1x1), frame=(4,0,1x1), clip=(4,0,1x1), environmentOverrides=1]
    statistics: created=6 destroyed=0 updated=0 bodies=0 equatableSkips=0 leaves=0 measurements=6 placements=6 renders=3 reasons=["renderRequested"]
    requirements: requested=[] effective=unavailable
    """
  }
}

@Test
func `split view renders three panes in vertical order`() {
  let size = TerminalSize(columns: 3, rows: 8)
  let model = SplitViewModel([
    SplitViewPane(id: "top", sizing: .init(requestedIdeal: 2)),
    SplitViewPane(id: "middle", sizing: .init(requestedIdeal: 2)),
    SplitViewPane(id: "bottom", sizing: .init(requestedIdeal: 2)),
  ])
  model.axis = .vertical
  let graph = ViewGraph(
    root: {
      SplitView(axis: model.axisBinding, panes: model.panesBinding) {
        Text("T")
        Text("M")
        Text("B")
      }
    },
    size: size
  )

  let buffer = renderSplitView(size: size) { graph.render(into: $0) }
  assertInlineSnapshot(of: buffer, as: .bufferState) {
    """
    T · ·
    · · ·
    ─ ─ ─
    M · ·
    · · ·
    ─ ─ ─
    B · ·
    · · ·
    """
  }
  assertInlineSnapshot(of: graph, as: .viewGraph) {
    """
    root SplitView [proposal=(3,8), measured=(3x8), frame=(0,0,3x8), clip=(0,0,3x8)]
      id(top) _SplitPane [proposal=(3,2), measured=(3x2), frame=(0,0,3x2), clip=(0,0,3x2), environmentOverrides=1]
        index(0) Text [proposal=(3,2), measured=(1x1), frame=(0,0,1x1), clip=(0,0,1x1), environmentOverrides=1]
      explicit(_SplitViewDividerID(leading: AnyHashable("top"), trailing: AnyHashable("middle"))) Divider [proposal=(3,1), measured=(3x1), frame=(0,2,3x1), clip=(0,2,3x1), environmentOverrides=1]
      id(middle) _SplitPane [proposal=(3,2), measured=(3x2), frame=(0,3,3x2), clip=(0,3,3x2), environmentOverrides=1]
        index(0) Text [proposal=(3,2), measured=(1x1), frame=(0,3,1x1), clip=(0,3,1x1), environmentOverrides=1]
      explicit(_SplitViewDividerID(leading: AnyHashable("middle"), trailing: AnyHashable("bottom"))) Divider [proposal=(3,1), measured=(3x1), frame=(0,5,3x1), clip=(0,5,3x1), environmentOverrides=1]
      id(bottom) _SplitPane [proposal=(3,2), measured=(3x2), frame=(0,6,3x2), clip=(0,6,3x2), environmentOverrides=1]
        index(0) Text [proposal=(3,2), measured=(1x1), frame=(0,6,1x1), clip=(0,6,1x1), environmentOverrides=1]
    statistics: created=9 destroyed=0 updated=0 bodies=0 equatableSkips=0 leaves=0 measurements=9 placements=9 renders=5 reasons=["renderRequested"]
    requirements: requested=[] effective=unavailable
    """
  }
}

@Test
func `split view leaves collapsed panes unplaced and removes their dividers`() {
  let size = TerminalSize(columns: 8, rows: 1)
  let model = SplitViewModel([
    SplitViewPane(id: "left", sizing: .init(requestedIdeal: 2)),
    SplitViewPane(id: "middle", sizing: .init(requestedIdeal: 2), isCollapsed: true),
    SplitViewPane(id: "right", sizing: .init(requestedIdeal: 5)),
  ])
  let graph = ViewGraph(
    root: {
      SplitView(axis: model.axisBinding, panes: model.panesBinding) {
        Text("L")
        Text("M")
        Text("R")
      }
    },
    size: size
  )

  let buffer = renderSplitView(size: size) { graph.render(into: $0) }
  assertInlineSnapshot(of: buffer, as: .bufferState) {
    """
    L · │ R · · · ·
    """
  }
  assertInlineSnapshot(of: graph, as: .viewGraph) {
    """
    root SplitView [proposal=(8,1), measured=(8x1), frame=(0,0,8x1), clip=(0,0,8x1)]
      id(left) _SplitPane [proposal=(2,1), measured=(2x1), frame=(0,0,2x1), clip=(0,0,2x1), environmentOverrides=1]
        index(0) Text [proposal=(2,1), measured=(1x1), frame=(0,0,1x1), clip=(0,0,1x1), environmentOverrides=1]
      explicit(_SplitViewDividerID(leading: AnyHashable("left"), trailing: AnyHashable("right"))) Divider [proposal=(1,1), measured=(1x1), frame=(2,0,1x1), clip=(2,0,1x1), environmentOverrides=1]
      id(middle) _SplitPane [environmentOverrides=1]
        index(0) Text [proposal=(0,0), measured=(1x1), frame=(0,0,1x1), clip=(0,0,0x0), environmentOverrides=1]
      id(right) _SplitPane [proposal=(5,1), measured=(5x1), frame=(3,0,5x1), clip=(3,0,5x1), environmentOverrides=1]
        index(0) Text [proposal=(5,1), measured=(1x1), frame=(3,0,1x1), clip=(3,0,1x1), environmentOverrides=1]
    statistics: created=8 destroyed=0 updated=0 bodies=0 equatableSkips=0 leaves=0 measurements=7 placements=8 renders=3 reasons=["renderRequested"]
    requirements: requested=[] effective=unavailable
    """
  }
}

@Test
func `split view clips over constrained allocations without mutating panes`() {
  let size = TerminalSize(columns: 5, rows: 1)
  let model = SplitViewModel([
    SplitViewPane(id: "leading", sizing: .init(minimum: 3, requestedIdeal: 3)),
    SplitViewPane(id: "trailing", sizing: .init(minimum: 3, requestedIdeal: 3)),
  ])
  let graph = ViewGraph(
    root: {
      SplitView(axis: model.axisBinding, panes: model.panesBinding) {
        Text("A")
        Text("B")
      }
    },
    size: size
  )

  let buffer = renderSplitView(size: size) { graph.render(into: $0) }
  assertInlineSnapshot(of: buffer, as: .bufferState) {
    """
    A · · │ B
    """
  }
  assertInlineSnapshot(of: graph, as: .viewGraph) {
    """
    root SplitView [proposal=(5,1), measured=(7x1), frame=(0,0,5x1), clip=(0,0,5x1)]
      id(leading) _SplitPane [proposal=(3,1), measured=(3x1), frame=(0,0,3x1), clip=(0,0,3x1), environmentOverrides=1]
        index(0) Text [proposal=(3,1), measured=(1x1), frame=(0,0,1x1), clip=(0,0,1x1), environmentOverrides=1]
      explicit(_SplitViewDividerID(leading: AnyHashable("leading"), trailing: AnyHashable("trailing"))) Divider [proposal=(1,1), measured=(1x1), frame=(3,0,1x1), clip=(3,0,1x1), environmentOverrides=1]
      id(trailing) _SplitPane [proposal=(3,1), measured=(3x1), frame=(4,0,3x1), clip=(4,0,1x1), environmentOverrides=1]
        index(0) Text [proposal=(3,1), measured=(1x1), frame=(4,0,1x1), clip=(4,0,1x1), environmentOverrides=1]
    statistics: created=6 destroyed=0 updated=0 bodies=0 equatableSkips=0 leaves=0 measurements=6 placements=6 renders=3 reasons=["renderRequested"]
    requirements: requested=[] effective=unavailable
    """
  }
  #expect(model.panes.map(\.sizing.requestedIdeal) == [3, 3])
}

@Test
func `split view keeps a requested pane smaller than its child ideal`() throws {
  let model = SplitViewModel([
    SplitViewPane(id: "left", sizing: .init(requestedIdeal: 0)),
    SplitViewPane(id: "right", sizing: .init(requestedIdeal: 2)),
  ])
  let graph = ViewGraph(
    root: {
      SplitView(axis: model.axisBinding, panes: model.panesBinding) {
        Text("wider")
        Text("B")
      }
    },
    size: TerminalSize(columns: 3, rows: 1)
  )

  graph.layoutIfNeeded()
  let left = try #require(
    graph.diagnostics.nodes.first { $0.identity.description == "root/id(left)" }
  )
  #expect(left.frame.size.columns == 0)
  #expect(model.panes[0].sizing.requestedIdeal == 0)
}

@Test
func `split view retains controlled pane sizes across resize`() {
  let model = SplitViewModel([
    SplitViewPane(id: "left", sizing: .init(requestedIdeal: 2)),
    SplitViewPane(id: "right", sizing: .init(requestedIdeal: 4)),
  ])
  let graph = ViewGraph(
    root: {
      SplitView(axis: model.axisBinding, panes: model.panesBinding) {
        Text("L")
        Text("R")
      }
    },
    size: TerminalSize(columns: 7, rows: 1)
  )

  _ = renderSplitView(size: TerminalSize(columns: 7, rows: 1)) { graph.render(into: $0) }
  graph.resize(to: TerminalSize(columns: 3, rows: 1))
  let buffer = renderSplitView(size: TerminalSize(columns: 3, rows: 1)) {
    graph.render(into: $0)
  }

  assertInlineSnapshot(of: buffer, as: .bufferState) {
    """
    │ R ·
    """
  }
  #expect(model.panes.map(\.sizing.requestedIdeal) == [2, 4])
}

@Test
func `split view omits dividers with fewer than two visible panes`() {
  let size = TerminalSize(columns: 2, rows: 1)
  let model = SplitViewModel([
    SplitViewPane(id: "hidden", sizing: .init(requestedIdeal: 2), isCollapsed: true),
    SplitViewPane(id: "visible", sizing: .init(requestedIdeal: 2)),
  ])
  let graph = ViewGraph(
    root: {
      SplitView(axis: model.axisBinding, panes: model.panesBinding) {
        Text("H")
        Text("V")
      }
    },
    size: size
  )

  let buffer = renderSplitView(size: size) { graph.render(into: $0) }
  assertInlineSnapshot(of: buffer, as: .bufferState) {
    """
    V ·
    """
  }
  assertInlineSnapshot(of: graph, as: .viewGraph) {
    """
    root SplitView [proposal=(2,1), measured=(2x1), frame=(0,0,2x1), clip=(0,0,2x1)]
      id(hidden) _SplitPane [environmentOverrides=1]
        index(0) Text [proposal=(0,0), measured=(1x1), frame=(0,0,1x1), clip=(0,0,0x0), environmentOverrides=1]
      id(visible) _SplitPane [proposal=(2,1), measured=(2x1), frame=(0,0,2x1), clip=(0,0,2x1), environmentOverrides=1]
        index(0) Text [proposal=(2,1), measured=(1x1), frame=(0,0,1x1), clip=(0,0,1x1), environmentOverrides=1]
    statistics: created=5 destroyed=0 updated=0 bodies=0 equatableSkips=0 leaves=0 measurements=4 placements=5 renders=1 reasons=["renderRequested"]
    requirements: requested=[] effective=unavailable
    """
  }
}

@Test
func `split view rejects duplicate IDs and count mismatches without placing children`() {
  let size = TerminalSize(columns: 4, rows: 1)
  let model = SplitViewModel([
    SplitViewPane(id: "duplicate", sizing: .init(requestedIdeal: 2)),
    SplitViewPane(id: "duplicate", sizing: .init(requestedIdeal: 2)),
  ])
  let graph = ViewGraph(
    root: {
      SplitView(axis: model.axisBinding, panes: model.panesBinding) {
        Text("A")
        Text("B")
      }
    },
    size: size
  )

  let buffer = renderSplitView(size: size) { graph.render(into: $0) }
  assertInlineSnapshot(of: buffer, as: .bufferState) {
    """
    · · · ·
    """
  }

  model.panes = [SplitViewPane(id: "only", sizing: .init(requestedIdeal: 2))]
  graph.update()
  let countMismatchBuffer = renderSplitView(size: size) { graph.render(into: $0) }
  assertInlineSnapshot(of: countMismatchBuffer, as: .bufferState) {
    """
    · · · ·
    """
  }
}

@Test
func `split view pane sizing clamps to a valid range`() {
  var sizing = SplitViewPaneSizing(minimum: -1, requestedIdeal: 8, maximum: 3)
  #expect(sizing.minimum == 0)
  #expect(sizing.maximum == 3)
  #expect(sizing.requestedIdeal == 3)

  sizing.requestedIdeal = -1
  #expect(sizing.requestedIdeal == 0)
}

@Test
func `split view grows capped sides before flexible middle`() throws {
  let model = SplitViewModel([
    SplitViewPane(id: "left", sizing: .init(minimum: 1, requestedIdeal: 2, maximum: 3)),
    SplitViewPane(id: "middle", sizing: .init(minimum: 1, requestedIdeal: 2)),
    SplitViewPane(id: "right", sizing: .init(minimum: 1, requestedIdeal: 2, maximum: 3)),
  ])
  let graph = ViewGraph(
    root: {
      SplitView(panes: model.panesBinding) {
        Text("L")
        Text("M")
        Text("R")
      }
    },
    size: TerminalSize(columns: 14, rows: 1)
  )

  graph.layoutIfNeeded()
  #expect(try paneFrame(graph, id: "left").size.columns == 3)
  #expect(try paneFrame(graph, id: "middle").size.columns == 6)
  #expect(try paneFrame(graph, id: "right").size.columns == 3)
}

@Test
func `split view resolves priorities and deterministic remainder`() throws {
  let prioritized = SplitViewModel([
    SplitViewPane(id: "priority", sizing: .init(requestedIdeal: 1)),
    SplitViewPane(id: "ordinary", sizing: .init(requestedIdeal: 1)),
  ])
  let prioritizedGraph = ViewGraph(
    root: {
      SplitView(panes: prioritized.panesBinding) {
        Text("P").layoutPriority(1)
        Text("O")
      }
    },
    size: TerminalSize(columns: 6, rows: 1)
  )
  prioritizedGraph.layoutIfNeeded()
  #expect(try paneFrame(prioritizedGraph, id: "priority").size.columns == 4)
  #expect(try paneFrame(prioritizedGraph, id: "ordinary").size.columns == 1)

  let equal = SplitViewModel([
    SplitViewPane(id: "first", sizing: .init(requestedIdeal: 0)),
    SplitViewPane(id: "second", sizing: .init(requestedIdeal: 0)),
    SplitViewPane(id: "third", sizing: .init(requestedIdeal: 0)),
  ])
  let equalGraph = ViewGraph(
    root: {
      SplitView(panes: equal.panesBinding) {
        Text("1")
        Text("2")
        Text("3")
      }
    },
    size: TerminalSize(columns: 6, rows: 1)
  )
  equalGraph.layoutIfNeeded()
  #expect(try paneFrame(equalGraph, id: "first").size.columns == 2)
  #expect(try paneFrame(equalGraph, id: "second").size.columns == 1)
  #expect(try paneFrame(equalGraph, id: "third").size.columns == 1)
}

@Test
func `split view uses one cell dividers symmetrically on both axes`() throws {
  let horizontal = SplitViewModel([
    SplitViewPane(id: "leading", sizing: .init(requestedIdeal: 2)),
    SplitViewPane(id: "trailing", sizing: .init(requestedIdeal: 2)),
  ])
  let horizontalGraph = ViewGraph(
    root: {
      SplitView(panes: horizontal.panesBinding) {
        Text("L")
        Text("R")
      }
    },
    size: TerminalSize(columns: 5, rows: 2)
  )
  horizontalGraph.layoutIfNeeded()
  #expect(try paneFrame(horizontalGraph, id: "leading").origin.column == 0)
  #expect(try paneFrame(horizontalGraph, id: "trailing").origin.column == 3)

  let vertical = SplitViewModel([
    SplitViewPane(id: "leading", sizing: .init(requestedIdeal: 2)),
    SplitViewPane(id: "trailing", sizing: .init(requestedIdeal: 2)),
  ])
  vertical.axis = .vertical
  let verticalGraph = ViewGraph(
    root: {
      SplitView(axis: vertical.axisBinding, panes: vertical.panesBinding) {
        Text("T")
        Text("B")
      }
    },
    size: TerminalSize(columns: 2, rows: 5)
  )
  verticalGraph.layoutIfNeeded()
  #expect(try paneFrame(verticalGraph, id: "leading").origin.row == 0)
  #expect(try paneFrame(verticalGraph, id: "trailing").origin.row == 3)
}

@Test
func `split view restores a collapsed pane without mutating its sizing`() throws {
  let model = SplitViewModel([
    SplitViewPane(id: "left", sizing: .init(requestedIdeal: 2)),
    SplitViewPane(id: "middle", sizing: .init(requestedIdeal: 3), isCollapsed: true),
    SplitViewPane(id: "right", sizing: .init(requestedIdeal: 2)),
  ])
  let graph = ViewGraph(
    root: {
      SplitView(panes: model.panesBinding) {
        Text("L")
        Text("M")
        Text("R")
      }
    },
    size: TerminalSize(columns: 9, rows: 1)
  )

  graph.layoutIfNeeded()
  #expect(
    graph.diagnostics.nodes.contains { $0.identity.description == "root/id(middle)" })
  model.panes[1].isCollapsed = false
  graph.update()
  graph.layoutIfNeeded()
  #expect(try paneFrame(graph, id: "middle").size.columns == 3)
  #expect(model.panes[1].sizing.requestedIdeal == 3)
}

private final class ResolvedFrameRecorder {
  var frames: [_SplitViewResolvedPaneFrame] = []
}

private struct ResolvedFrameProbeLayout: Layout {
  let layout: _SplitViewLayout
  let recorder: ResolvedFrameRecorder

  func sizeThatFits(_ proposal: ProposedSize, subviews: Subviews) -> TerminalSize {
    layout.sizeThatFits(proposal, subviews: subviews)
  }

  func placeSubviews(in bounds: Rect, proposal: ProposedSize, subviews: Subviews) {
    recorder.frames = layout.resolvedPaneFrames(
      in: bounds,
      proposal: proposal,
      subviews: subviews
    )
    layout.placeSubviews(in: bounds, proposal: proposal, subviews: subviews)
  }
}

private struct ProposalFillingLeaf: LeafView {
  func sizeThatFits(
    _ proposal: ProposedSize,
    state: inout Void,
    environment: EnvironmentValues
  ) -> TerminalSize {
    TerminalSize(columns: proposal.width ?? 0, rows: proposal.height ?? 0)
  }

  func render(
    in region: inout RenderRegion,
    state: inout Void,
    environment: EnvironmentValues
  ) {}
}

@Test
func `resolved pane frames match the SplitView placement path`() throws {
  let panes = [
    SplitViewPane(id: "left", sizing: .init(requestedIdeal: 3)),
    SplitViewPane(id: "right", sizing: .init(requestedIdeal: 4)),
  ]
  let recorder = ResolvedFrameRecorder()
  let layout = ResolvedFrameProbeLayout(
    layout: _SplitViewLayout(axis: .horizontal, panes: panes),
    recorder: recorder
  )
  let graph = ViewGraph(
    root: {
      layout {
        ProposalFillingLeaf()
        ProposalFillingLeaf()
        ProposalFillingLeaf()
      }
    },
    size: TerminalSize(columns: 8, rows: 2)
  )

  graph.layoutIfNeeded()
  let placed = graph.diagnostics.nodes
    .filter { $0.viewType == String(reflecting: ProposalFillingLeaf.self) }
    .map(\.frame)
  let leading = try #require(placed.first)
  let trailing = try #require(placed.last)

  #expect(recorder.frames.map(\.id) == panes.map(\.id))
  #expect(recorder.frames.map(\.frame) == [leading, trailing])
}

private struct WrappedSplitView: View {
  let panes: Binding<[SplitViewPane]>

  var body: some View {
    VStack {
      Text("Header")
      SplitView(panes: panes) {
        Text("L")
        Text("R")
      }
    }
  }
}

@Test
func `split view divider fills the area proposed through a wrapper view`() {
  let size = TerminalSize(columns: 8, rows: 5)
  let model = SplitViewModel([
    SplitViewPane(id: "left", sizing: .init(requestedIdeal: 3)),
    SplitViewPane(id: "right", sizing: .init(requestedIdeal: 4)),
  ])
  let graph = ViewGraph(
    root: { WrappedSplitView(panes: model.panesBinding) },
    size: size
  )

  let buffer = renderSplitView(size: size) { graph.render(into: $0) }
  assertInlineSnapshot(of: buffer, as: .bufferState) {
    """
    H e a d e r · ·
    L · · │ R · · ·
    · · · │ · · · ·
    · · · │ · · · ·
    · · · │ · · · ·
    """
  }
}
