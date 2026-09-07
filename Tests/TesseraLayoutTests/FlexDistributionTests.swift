import InlineSnapshotTesting
import TesseraCore
import TesseraLayout
import TesseraTerminalCore
import Testing

private struct FlexibleLeaf: LeafView, Equatable {
  let ideal: TerminalSize
  let minimum: TerminalSize

  init(minimum: Int = 0, ideal: Int, cross: Int = 1, axis: Axis = .horizontal) {
    switch axis {
    case .horizontal:
      self.minimum = TerminalSize(columns: minimum, rows: cross)
      self.ideal = TerminalSize(columns: ideal, rows: cross)
    case .vertical:
      self.minimum = TerminalSize(columns: cross, rows: minimum)
      self.ideal = TerminalSize(columns: cross, rows: ideal)
    }
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
    return max(proposal, minimum)
  }
}

private struct IntrinsicLeaf: LeafView, Equatable {
  let ideal: TerminalSize
  let minimum: TerminalSize

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
    subviews.reduce(into: TerminalSize(columns: 0, rows: 0)) { result, subview in
      let size = subview.sizeThatFits(.unspecified)
      result = TerminalSize(
        columns: result.columns + size.columns,
        rows: max(result.rows, size.rows)
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

private func nodes<T>(of type: T.Type, in graph: ViewGraph) -> [NodeDiagnostics] {
  graph.diagnostics.nodes.filter { $0.viewType == String(reflecting: type) }
}

private func flexibleFrames(in graph: ViewGraph) -> [Rect] {
  nodes(of: FlexibleLeaf.self, in: graph).map(\.frame)
}

private func flexibleFrameSummary(in graph: ViewGraph) -> String {
  flexibleFrames(in: graph)
    .enumerated()
    .map { index, frame in
      "\(index): (\(frame.origin.column),\(frame.origin.row),\(frame.size.columns)x\(frame.size.rows))"
    }
    .joined(separator: "\n")
}

private func flexibleGeometrySummary(in graph: ViewGraph) -> String {
  nodes(of: FlexibleLeaf.self, in: graph)
    .enumerated()
    .map { index, node in
      "\(index): frame=(\(node.frame.origin.column),\(node.frame.origin.row),\(node.frame.size.columns)x\(node.frame.size.rows)), clip=(\(node.clip.origin.column),\(node.clip.origin.row),\(node.clip.size.columns)x\(node.clip.size.rows))"
    }
    .joined(separator: "\n")
}

private struct ConstraintFixture: Sendable {
  let constraint: FlexConstraint?
  let expectedWidth: Int
  let ideal: Int
  let name: String
}

@Test(arguments: [
  ConstraintFixture(constraint: .length(4), expectedWidth: 4, ideal: 8, name: "length"),
  ConstraintFixture(
    constraint: .percentage(25), expectedWidth: 5, ideal: 8, name: "percentage"),
  ConstraintFixture(constraint: .ratio(1, 4), expectedWidth: 5, ideal: 8, name: "ratio"),
  ConstraintFixture(constraint: .max(4), expectedWidth: 4, ideal: 8, name: "max"),
  ConstraintFixture(constraint: .min(3), expectedWidth: 20, ideal: 6, name: "min"),
  ConstraintFixture(constraint: .fill(2), expectedWidth: 20, ideal: 6, name: "fill"),
  ConstraintFixture(constraint: nil, expectedWidth: 20, ideal: 6, name: "default"),
])
private func `flex resolves every public constraint and the default constraint`(
  _ fixture: ConstraintFixture
) {
  let graph = laidOut(size: TerminalSize(columns: 20, rows: 3)) {
    Flex(.horizontal) {
      if let constraint = fixture.constraint {
        FlexibleLeaf(minimum: 1, ideal: fixture.ideal).flex(constraint)
      } else {
        FlexibleLeaf(minimum: 1, ideal: fixture.ideal)
      }
    }
  }

  #expect(
    flexibleFrames(in: graph).map(\.size.columns) == [fixture.expectedWidth],
    Comment(rawValue: fixture.name)
  )
}

@Test
func `flex rejects invalid public constraints`() async {
  await #expect(processExitsWith: .failure) {
    _ = FlexibleLeaf(ideal: 1).flex(.length(-1))
  }
  await #expect(processExitsWith: .failure) {
    _ = FlexibleLeaf(ideal: 1).flex(.min(-1))
  }
  await #expect(processExitsWith: .failure) {
    _ = FlexibleLeaf(ideal: 1).flex(.max(-1))
  }
  await #expect(processExitsWith: .failure) {
    _ = FlexibleLeaf(ideal: 1).flex(.percentage(-1))
  }
  await #expect(processExitsWith: .failure) {
    _ = FlexibleLeaf(ideal: 1).flex(.percentage(101))
  }
  await #expect(processExitsWith: .failure) {
    _ = FlexibleLeaf(ideal: 1).flex(.ratio(-1, 1))
  }
  await #expect(processExitsWith: .failure) {
    _ = FlexibleLeaf(ideal: 1).flex(.ratio(1, 0))
  }
  await #expect(processExitsWith: .failure) {
    _ = FlexibleLeaf(ideal: 1).flex(.fill(-1))
  }
}

@Test
func `flex rejects negative spacing`() async {
  await #expect(processExitsWith: .failure) {
    _ = Flex(.horizontal, spacing: -1) {
      FlexibleLeaf(ideal: 1)
    }
  }
}

@Test
func `flex saturates overflowing relative allocation without wrapping negative`() throws {
  let graph = laidOut(size: TerminalSize(columns: Int.max, rows: 1)) {
    Flex(.horizontal) {
      FlexibleLeaf(ideal: 1).flex(.ratio(Int.max, 1))
    }
  }

  #expect(
    try #require(flexibleFrames(in: graph).first)
      == Rect(column: 0, row: 0, columns: Int.max, rows: 1))
}

@Test
func `flex resolves fixed fill and capped children in normative order`() {
  let exact = laidOut(size: TerminalSize(columns: 16, rows: 1)) {
    Flex(.horizontal, spacing: 1) {
      FlexibleLeaf(ideal: 4).flex(.length(4))
      FlexibleLeaf(ideal: 6).flex(.fill(1))
      FlexibleLeaf(ideal: 8).flex(.max(4))
    }
  }
  let tight = laidOut(size: TerminalSize(columns: 8, rows: 1)) {
    Flex(.horizontal, spacing: 1) {
      FlexibleLeaf(ideal: 4).flex(.length(4))
      FlexibleLeaf(ideal: 6).flex(.fill(1))
      FlexibleLeaf(ideal: 8).flex(.max(4))
    }
  }
  let capped = laidOut(size: TerminalSize(columns: 30, rows: 1)) {
    Flex(.horizontal, spacing: 1) {
      FlexibleLeaf(ideal: 8).flex(.max(4))
      FlexibleLeaf(ideal: 8).flex(.max(6))
    }
  }

  assertInlineSnapshot(of: flexibleFrameSummary(in: exact), as: .lines) {
    """
    0: (0,0,4x1)
    1: (5,0,6x1)
    2: (12,0,4x1)
    """
  }
  assertInlineSnapshot(of: flexibleFrameSummary(in: tight), as: .lines) {
    """
    0: (0,0,4x1)
    1: (5,0,0x1)
    2: (6,0,4x1)
    """
  }
  assertInlineSnapshot(of: flexibleFrameSummary(in: capped), as: .lines) {
    """
    0: (0,0,4x1)
    1: (5,0,6x1)
    """
  }
}

@Test
func `flex gives positive weighted remainder cells to earlier children first`() {
  let equal = laidOut(size: TerminalSize(columns: 5, rows: 1)) {
    Flex(.horizontal) {
      FlexibleLeaf(ideal: 0).flex(.fill(1))
      FlexibleLeaf(ideal: 0).flex(.fill(1))
      FlexibleLeaf(ideal: 0).flex(.fill(1))
    }
  }
  let weighted = laidOut(size: TerminalSize(columns: 4, rows: 1)) {
    Flex(.horizontal) {
      FlexibleLeaf(ideal: 0).flex(.fill(2))
      FlexibleLeaf(ideal: 0).flex(.fill(1))
    }
  }

  assertInlineSnapshot(of: flexibleFrameSummary(in: equal), as: .lines) {
    """
    0: (0,0,2x1)
    1: (2,0,2x1)
    2: (4,0,1x1)
    """
  }
  assertInlineSnapshot(of: flexibleFrameSummary(in: weighted), as: .lines) {
    """
    0: (0,0,3x1)
    1: (3,0,1x1)
    """
  }
}

@Test
func `flex allocates higher priority growth before lower priority growth`() {
  let graph = laidOut(size: TerminalSize(columns: 5, rows: 1)) {
    Flex(.horizontal) {
      FlexibleLeaf(ideal: 0).flex(.fill(1))
      FlexibleLeaf(ideal: 0).flex(.fill(1)).layoutPriority(1)
    }
  }

  assertInlineSnapshot(of: flexibleFrameSummary(in: graph), as: .lines) {
    """
    0: (0,0,0x1)
    1: (0,0,5x1)
    """
  }
}

@Test
func `flex compresses fill then minimum items by ascending priority`() {
  let priority = laidOut(size: TerminalSize(columns: 6, rows: 1)) {
    Flex(.horizontal) {
      FlexibleLeaf(ideal: 5).flex(.fill(1)).layoutPriority(1)
      FlexibleLeaf(ideal: 5).flex(.fill(1))
    }
  }
  let phases = laidOut(size: TerminalSize(columns: 4, rows: 1)) {
    Flex(.horizontal) {
      FlexibleLeaf(minimum: 2, ideal: 5).flex(.min(2))
      FlexibleLeaf(ideal: 4).flex(.fill(1))
    }
  }
  let laterRemainder = laidOut(size: TerminalSize(columns: 8, rows: 1)) {
    Flex(.horizontal) {
      FlexibleLeaf(ideal: 3)
      FlexibleLeaf(ideal: 3)
      FlexibleLeaf(ideal: 3)
    }
  }

  assertInlineSnapshot(of: flexibleFrameSummary(in: priority), as: .lines) {
    """
    0: (0,0,5x1)
    1: (5,0,1x1)
    """
  }
  assertInlineSnapshot(of: flexibleFrameSummary(in: phases), as: .lines) {
    """
    0: (0,0,4x1)
    1: (4,0,0x1)
    """
  }
  assertInlineSnapshot(of: flexibleFrameSummary(in: laterRemainder), as: .lines) {
    """
    0: (0,0,3x1)
    1: (3,0,3x1)
    2: (6,0,2x1)
    """
  }
}

@Test
func `flex clips trailing fixed children when hard floors exceed the proposal`() {
  let graph = laidOut(size: TerminalSize(columns: 6, rows: 1)) {
    Flex(.horizontal, spacing: 1) {
      FlexibleLeaf(ideal: 4).flex(.length(4))
      FlexibleLeaf(ideal: 4).flex(.length(4))
    }
  }

  assertInlineSnapshot(of: flexibleGeometrySummary(in: graph), as: .lines) {
    """
    0: frame=(0,0,4x1), clip=(0,0,4x1)
    1: frame=(5,0,4x1), clip=(5,0,1x1)
    """
  }
}

@Test
func `flex reports initial allocations when its main axis is unspecified`() {
  let graph = laidOut(size: TerminalSize(columns: 30, rows: 2)) {
    LeadingLayout {
      Flex(.horizontal, spacing: 1) {
        FlexibleLeaf(ideal: 4).flex(.length(4))
        FlexibleLeaf(ideal: 6).flex(.fill(1))
        FlexibleLeaf(ideal: 8).flex(.max(4))
      }
    }
  }

  assertInlineSnapshot(of: flexibleFrameSummary(in: graph), as: .lines) {
    """
    0: (0,0,4x1)
    1: (5,0,6x1)
    2: (12,0,4x1)
    """
  }
}

@Test
func `flex handles empty single and vertical content without outer spacing`() {
  let empty = laidOut(size: TerminalSize(columns: 8, rows: 5)) {
    Flex(.horizontal, spacing: 3) {
      ForEach([Int](), id: \.self) { _ in
        FlexibleLeaf(ideal: 1)
      }
    }
  }
  let single = laidOut(size: TerminalSize(columns: 8, rows: 5)) {
    LeadingLayout {
      Flex(.horizontal, spacing: 3) {
        FlexibleLeaf(ideal: 2).flex(.length(2))
      }
    }
  }
  let vertical = laidOut(size: TerminalSize(columns: 4, rows: 7)) {
    Flex(.vertical, spacing: 1) {
      FlexibleLeaf(ideal: 2, cross: 2, axis: .vertical).flex(.length(2))
      FlexibleLeaf(ideal: 4, cross: 3, axis: .vertical).flex(.fill(1))
    }
  }

  #expect(flexibleFrames(in: empty).isEmpty)
  #expect(flexibleFrames(in: single) == [Rect(column: 0, row: 0, columns: 2, rows: 1)])
  assertInlineSnapshot(of: flexibleFrameSummary(in: vertical), as: .lines) {
    """
    0: (0,0,4x2)
    1: (0,3,4x4)
    """
  }
}

@Test
func `flex flattens dynamic view lists into independently constrained children`() {
  let graph = laidOut(size: TerminalSize(columns: 15, rows: 1)) {
    Flex(.horizontal, spacing: 1) {
      ForEach([8, 6], id: \.self) { length in
        FlexibleLeaf(ideal: 1).flex(.length(length))
      }
    }
  }

  assertInlineSnapshot(of: flexibleFrameSummary(in: graph), as: .lines) {
    """
    0: (0,0,8x1)
    1: (9,0,6x1)
    """
  }
}

@Test
func `flex publishes its axis to descendant Divider and Spacer views`() throws {
  let horizontal = laidOut(size: TerminalSize(columns: 8, rows: 4)) {
    Flex(.horizontal) {
      Divider().flex(.length(1))
      Spacer().flex(.fill(1))
    }
  }
  let vertical = laidOut(size: TerminalSize(columns: 4, rows: 8)) {
    Flex(.vertical) {
      Divider().flex(.length(1))
      Spacer().flex(.fill(1))
    }
  }

  #expect(
    try #require(nodes(of: Divider.self, in: horizontal).first).frame.size.columns == 1)
  #expect(try #require(nodes(of: Divider.self, in: vertical).first).frame.size.rows == 1)
}

private struct PublicConstraintConsumer: Layout {
  func sizeThatFits(_ proposal: ProposedSize, subviews: Subviews) -> TerminalSize {
    guard let subview = subviews.first else {
      return TerminalSize(columns: 0, rows: 0)
    }
    let constraint: FlexConstraint? = subview[FlexConstraint.self]
    return constraint == .length(7)
      ? TerminalSize(columns: 7, rows: 1)
      : TerminalSize(columns: 0, rows: 0)
  }

  func placeSubviews(in bounds: Rect, proposal: ProposedSize, subviews: Subviews) {
    subviews.first?.place(
      at: bounds.origin,
      proposal: ProposedSize(width: bounds.size.columns, height: bounds.size.rows)
    )
  }
}

@Test
func `custom layouts consume Flex constraints through public layout value APIs`() {
  let graph = laidOut(size: TerminalSize(columns: 10, rows: 2)) {
    PublicConstraintConsumer {
      FlexibleLeaf(ideal: 7).flex(.length(7))
    }
  }

  #expect(graph.diagnostics.nodes.first?.measuredSize == TerminalSize(columns: 7, rows: 1))
}

private final class MeasurementRecorder: @unchecked Sendable {
  var proposals: [ProposedSize] = []
}

private struct CountingLeaf: LeafView {
  let recorder: MeasurementRecorder

  func sizeThatFits(
    _ proposal: ProposedSize,
    state: inout Void,
    environment: EnvironmentValues
  ) -> TerminalSize {
    recorder.proposals.append(proposal)
    return TerminalSize(columns: proposal.width ?? 4, rows: proposal.height ?? 1)
  }

  func render(
    in region: inout RenderRegion,
    state: inout Void,
    environment: EnvironmentValues
  ) {}
}

@Test
func `flex reuses per pass measurements for repeated proposals`() {
  let recorder = MeasurementRecorder()
  _ = laidOut(size: TerminalSize(columns: 4, rows: 1)) {
    Flex(.horizontal) {
      CountingLeaf(recorder: recorder).flex(.length(4))
    }
  }

  #expect(
    Set(recorder.proposals)
      == Set([
        ProposedSize(width: nil, height: nil),
        ProposedSize(width: 0, height: nil),
        ProposedSize(width: 4, height: nil),
      ]))
  #expect(recorder.proposals.count == 3)
}

private struct DisjointClipLayout: Layout {
  func sizeThatFits(_ proposal: ProposedSize, subviews: Subviews) -> TerminalSize {
    TerminalSize(columns: proposal.width ?? 1, rows: proposal.height ?? 1)
  }

  func placeSubviews(in bounds: Rect, proposal: ProposedSize, subviews: Subviews) {
    subviews.first?.place(
      at: bounds.origin,
      proposal: ProposedSize(width: 1, height: 1),
      clip: Rect(
        column: bounds.origin.column + bounds.size.columns + 1,
        row: bounds.origin.row,
        columns: 1,
        rows: 1
      )
    )
  }
}

@Test
func `explicit child clip disjoint from its parent produces an empty clip`() throws {
  let graph = laidOut(size: TerminalSize(columns: 1, rows: 1)) {
    DisjointClipLayout {
      Text("X")
    }
  }

  #expect(try #require(nodes(of: Text.self, in: graph).first).clip.isEmpty)
}

@Test
func `showcase flex scenario resolves the documented sixty eight cell canvas`() {
  let graph = laidOut(size: TerminalSize(columns: 68, rows: 1)) {
    Flex(.horizontal, spacing: 1) {
      FlexibleLeaf(ideal: 4).flex(.length(8))
      FlexibleLeaf(ideal: 4).flex(.percentage(10))
      FlexibleLeaf(ideal: 4).flex(.ratio(1, 8))
      FlexibleLeaf(ideal: 12).flex(.max(9))
      FlexibleLeaf(ideal: 7).flex(.min(7))
      FlexibleLeaf(ideal: 6).flex(.fill(2))
    }
  }

  assertInlineSnapshot(of: flexibleFrameSummary(in: graph), as: .lines) {
    """
    0: (0,0,8x1)
    1: (9,0,6x1)
    2: (16,0,7x1)
    3: (24,0,9x1)
    4: (34,0,14x1)
    5: (49,0,19x1)
    """
  }
}
