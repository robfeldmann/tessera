import InlineSnapshotTesting
import TesseraCore
import TesseraLayout
import TesseraTerminalCore
import TesseraTestSupport
import Testing

private struct SizedLeaf: LeafView, Equatable {
  let minimum: TerminalSize
  let ideal: TerminalSize

  init(
    minimumColumns: Int,
    minimumRows: Int,
    idealColumns: Int,
    idealRows: Int
  ) {
    minimum = TerminalSize(columns: minimumColumns, rows: minimumRows)
    ideal = TerminalSize(columns: idealColumns, rows: idealRows)
  }

  func sizeThatFits(
    _ proposal: ProposedSize,
    state: inout Void,
    environment: EnvironmentValues
  ) -> TerminalSize {
    TerminalSize(
      columns: resolved(proposal.width, minimum: minimum.columns, ideal: ideal.columns),
      rows: resolved(proposal.height, minimum: minimum.rows, ideal: ideal.rows)
    )
  }

  func render(
    in region: inout RenderRegion,
    state: inout Void,
    environment: EnvironmentValues
  ) {}

  private func resolved(_ proposal: Int?, minimum: Int, ideal: Int) -> Int {
    guard let proposal else {
      return ideal
    }
    return min(max(proposal, minimum), ideal)
  }
}

private struct LeadingLayout: Layout {
  func sizeThatFits(_ proposal: ProposedSize, subviews: Subviews) -> TerminalSize {
    subviews.reduce(into: TerminalSize(columns: 0, rows: 0)) { size, subview in
      let child = subview.sizeThatFits(.unspecified)
      size = TerminalSize(
        columns: size.columns + child.columns,
        rows: max(size.rows, child.rows)
      )
    }
  }

  func placeSubviews(in bounds: Rect, proposal: ProposedSize, subviews: Subviews) {
    var column = bounds.origin.column
    for subview in subviews {
      let size = subview.sizeThatFits(.unspecified)
      subview.place(
        at: TerminalPosition(column: column, row: bounds.origin.row),
        proposal: .unspecified
      )
      column += size.columns
    }
  }
}

private func laidOut<Root: View>(
  size: TerminalSize,
  @ViewBuilder root: @escaping () -> Root
) -> ViewGraph {
  let graph = ViewGraph(root: root, size: size)
  graph.layoutIfNeeded()
  return graph
}

private func frames<T>(of type: T.Type, in graph: ViewGraph) -> [Rect] {
  graph.diagnostics.nodes.compactMap { node in
    node.viewType == String(reflecting: type) ? node.frame : nil
  }
}

private func sizedFrames(in graph: ViewGraph) -> [Rect] {
  frames(of: SizedLeaf.self, in: graph)
}

private struct StackFrameCase: Sendable {
  let name: String
  let expected: [Rect]
}

@Test(arguments: [
  StackFrameCase(
    name: "spacing",
    expected: [
      Rect(column: 0, row: 0, columns: 2, rows: 1),
      Rect(column: 4, row: 0, columns: 3, rows: 1),
    ]
  ),
  StackFrameCase(
    name: "rigid minimum",
    expected: [
      Rect(column: 0, row: 0, columns: 3, rows: 1),
      Rect(column: 3, row: 0, columns: 2, rows: 1),
    ]
  ),
  StackFrameCase(
    name: "tight overflow",
    expected: [
      Rect(column: 0, row: 0, columns: 3, rows: 1),
      Rect(column: 4, row: 0, columns: 3, rows: 1),
    ]
  ),
  StackFrameCase(
    name: "earliest remainder",
    expected: [
      Rect(column: 0, row: 0, columns: 3, rows: 1),
      Rect(column: 3, row: 0, columns: 2, rows: 1),
    ]
  ),
  StackFrameCase(
    name: "priority",
    expected: [
      Rect(column: 0, row: 0, columns: 5, rows: 1),
      Rect(column: 5, row: 0, columns: 0, rows: 1),
    ]
  ),
  StackFrameCase(
    name: "spacer minimum and fill",
    expected: [
      Rect(column: 0, row: 0, columns: 2, rows: 1),
      Rect(column: 3, row: 0, columns: 8, rows: 0),
      Rect(column: 12, row: 0, columns: 2, rows: 1),
    ]
  ),
])
private func `HStack frame tables preserve main axis distribution`(
  _ fixture: StackFrameCase
) throws {
  let graph: ViewGraph

  switch fixture.name {
  case "spacing":
    graph = laidOut(size: TerminalSize(columns: 12, rows: 4)) {
      HStack(spacing: 2) {
        SizedLeaf(minimumColumns: 2, minimumRows: 1, idealColumns: 2, idealRows: 1)
        SizedLeaf(minimumColumns: 3, minimumRows: 1, idealColumns: 3, idealRows: 1)
      }
    }
  case "rigid minimum":
    graph = laidOut(size: TerminalSize(columns: 5, rows: 4)) {
      HStack {
        SizedLeaf(minimumColumns: 3, minimumRows: 1, idealColumns: 3, idealRows: 1)
        SizedLeaf(minimumColumns: 0, minimumRows: 1, idealColumns: 10, idealRows: 1)
      }
    }
  case "tight overflow":
    graph = laidOut(size: TerminalSize(columns: 4, rows: 4)) {
      HStack(spacing: 1) {
        SizedLeaf(minimumColumns: 3, minimumRows: 1, idealColumns: 6, idealRows: 1)
        SizedLeaf(minimumColumns: 3, minimumRows: 1, idealColumns: 6, idealRows: 1)
      }
    }
  case "earliest remainder":
    graph = laidOut(size: TerminalSize(columns: 5, rows: 4)) {
      HStack {
        SizedLeaf(minimumColumns: 0, minimumRows: 1, idealColumns: 10, idealRows: 1)
        SizedLeaf(minimumColumns: 0, minimumRows: 1, idealColumns: 10, idealRows: 1)
      }
    }
  case "priority":
    graph = laidOut(size: TerminalSize(columns: 5, rows: 4)) {
      HStack {
        SizedLeaf(minimumColumns: 0, minimumRows: 1, idealColumns: 8, idealRows: 1)
          .layoutPriority(1)
        SizedLeaf(minimumColumns: 0, minimumRows: 1, idealColumns: 8, idealRows: 1)
      }
    }
  case "spacer minimum and fill":
    graph = laidOut(size: TerminalSize(columns: 14, rows: 4)) {
      HStack(spacing: 1) {
        SizedLeaf(minimumColumns: 2, minimumRows: 1, idealColumns: 2, idealRows: 1)
        Spacer(minLength: 3)
        SizedLeaf(minimumColumns: 2, minimumRows: 1, idealColumns: 2, idealRows: 1)
      }
    }
  default:
    Issue.record("Unknown stack frame fixture: \(fixture.name)")
    return
  }

  let actual: [Rect]
  if fixture.name == "spacer minimum and fill" {
    let spacer = try #require(frames(of: Spacer.self, in: graph).first)
    actual = [
      sizedFrames(in: graph)[0],
      spacer,
      sizedFrames(in: graph)[1],
    ]
  } else {
    actual = sizedFrames(in: graph)
  }
  #expect(actual == fixture.expected)
}

@Test
func `VStack preserves spacing rigid minima and cross axis alignment`() {
  let graph = laidOut(size: TerminalSize(columns: 10, rows: 10)) {
    VStack(alignment: .trailing, spacing: 1) {
      SizedLeaf(minimumColumns: 4, minimumRows: 2, idealColumns: 4, idealRows: 2)
      SizedLeaf(minimumColumns: 2, minimumRows: 3, idealColumns: 2, idealRows: 3)
    }
  }

  #expect(
    sizedFrames(in: graph) == [
      Rect(column: 6, row: 0, columns: 4, rows: 2),
      Rect(column: 8, row: 3, columns: 2, rows: 3),
    ])
}

@Test
func `HStack honors bottom cross axis alignment`() {
  let graph = laidOut(size: TerminalSize(columns: 10, rows: 5)) {
    HStack(alignment: .bottom) {
      SizedLeaf(minimumColumns: 2, minimumRows: 1, idealColumns: 2, idealRows: 1)
      SizedLeaf(minimumColumns: 3, minimumRows: 3, idealColumns: 3, idealRows: 3)
    }
  }

  #expect(
    sizedFrames(in: graph) == [
      Rect(column: 0, row: 4, columns: 2, rows: 1),
      Rect(column: 2, row: 2, columns: 3, rows: 3),
    ])
}

@Test
func `stacks handle no layout children and one child`() {
  let empty = laidOut(size: TerminalSize(columns: 8, rows: 5)) {
    HStack {
      ForEach([Int](), id: \.self) { _ in
        SizedLeaf(minimumColumns: 1, minimumRows: 1, idealColumns: 1, idealRows: 1)
      }
    }
  }
  let single = laidOut(size: TerminalSize(columns: 8, rows: 5)) {
    VStack(alignment: .center) {
      SizedLeaf(minimumColumns: 2, minimumRows: 3, idealColumns: 2, idealRows: 3)
    }
  }

  #expect(empty.diagnostics.nodes[0].measuredSize == TerminalSize(columns: 0, rows: 0))
  #expect(sizedFrames(in: empty).isEmpty)
  #expect(sizedFrames(in: single) == [Rect(column: 3, row: 0, columns: 2, rows: 3)])
}

@Test
func `frame padding and ZStack place children in retained slack`() {
  let framed = laidOut(size: TerminalSize(columns: 10, rows: 7)) {
    SizedLeaf(minimumColumns: 2, minimumRows: 1, idealColumns: 2, idealRows: 1)
      .frame(width: 6, height: 4, alignment: .bottomTrailing)
  }
  let padded = laidOut(size: TerminalSize(columns: 12, rows: 10)) {
    SizedLeaf(minimumColumns: 2, minimumRows: 1, idealColumns: 2, idealRows: 1)
      .padding(EdgeInsets(top: 1, leading: 2, bottom: 3, trailing: 4))
  }
  let overlaid = laidOut(size: TerminalSize(columns: 10, rows: 6)) {
    ZStack(alignment: .bottomTrailing) {
      SizedLeaf(minimumColumns: 2, minimumRows: 1, idealColumns: 2, idealRows: 1)
      SizedLeaf(minimumColumns: 4, minimumRows: 3, idealColumns: 4, idealRows: 3)
    }
  }

  #expect(sizedFrames(in: framed) == [Rect(column: 8, row: 6, columns: 2, rows: 1)])
  #expect(sizedFrames(in: padded) == [Rect(column: 2, row: 1, columns: 2, rows: 1)])
  #expect(
    sizedFrames(in: overlaid) == [
      Rect(column: 8, row: 5, columns: 2, rows: 1),
      Rect(column: 6, row: 3, columns: 4, rows: 3),
    ])
}

@Test
func `Divider takes the enclosing stack orientation`() {
  let horizontal = laidOut(size: TerminalSize(columns: 10, rows: 5)) {
    HStack {
      Divider()
      SizedLeaf(minimumColumns: 2, minimumRows: 1, idealColumns: 2, idealRows: 1)
    }
  }
  let vertical = laidOut(size: TerminalSize(columns: 10, rows: 5)) {
    VStack {
      Divider()
      SizedLeaf(minimumColumns: 2, minimumRows: 1, idealColumns: 2, idealRows: 1)
    }
  }

  #expect(
    frames(of: Divider.self, in: horizontal) == [
      Rect(column: 0, row: 0, columns: 1, rows: 5)
    ])
  #expect(
    frames(of: Divider.self, in: vertical) == [
      Rect(column: 0, row: 0, columns: 10, rows: 1)
    ])
}

@Test
func `custom Layout uses only public subview API`() {
  let graph = laidOut(size: TerminalSize(columns: 12, rows: 4)) {
    LeadingLayout {
      SizedLeaf(minimumColumns: 2, minimumRows: 1, idealColumns: 2, idealRows: 1)
      SizedLeaf(minimumColumns: 3, minimumRows: 2, idealColumns: 3, idealRows: 2)
    }
  }

  #expect(
    sizedFrames(in: graph) == [
      Rect(column: 0, row: 0, columns: 2, rows: 1),
      Rect(column: 2, row: 0, columns: 3, rows: 2),
    ])
}

@Test
func `measurement cache memoizes each node proposal during a layout pass`() {
  let graph = laidOut(size: TerminalSize(columns: 8, rows: 3)) {
    HStack {
      SizedLeaf(minimumColumns: 0, minimumRows: 1, idealColumns: 10, idealRows: 1)
    }
  }

  #expect(graph.statistics.measurements == 5)
}

@Test
func `complex HStack geometry remains inspectable`() {
  let graph = laidOut(size: TerminalSize(columns: 14, rows: 4)) {
    HStack(alignment: .bottom, spacing: 1) {
      SizedLeaf(minimumColumns: 2, minimumRows: 1, idealColumns: 2, idealRows: 1)
      Spacer(minLength: 3)
      SizedLeaf(minimumColumns: 2, minimumRows: 2, idealColumns: 2, idealRows: 2)
    }
  }

  assertInlineSnapshot(of: graph, as: .viewGraph) {
    """
    root TupleView [proposal=(14,4), measured=(14x2), frame=(0,0,14x4), clip=(0,0,14x4), needsRender]
      index(0) HStack [proposal=(14,4), measured=(14x2), frame=(0,0,14x4), clip=(0,0,14x4), needsRender]
        index(0) SizedLeaf [proposal=(2,4), measured=(2x1), frame=(0,3,2x1), clip=(0,3,2x1), needsRender, environmentOverrides=1]
        index(1) Spacer [proposal=(8,4), measured=(8x0), frame=(3,4,8x0), clip=(3,4,0x0), needsRender, environmentOverrides=1]
        index(2) SizedLeaf [proposal=(2,4), measured=(2x2), frame=(12,2,2x2), clip=(12,2,2x2), needsRender, environmentOverrides=1]
    statistics: created=5 destroyed=0 updated=0 bodies=0 equatableSkips=0 leaves=0 measurements=11 placements=5 renders=0 reasons=[]
    requirements: requested=[] effective=unavailable
    """
  }
}
