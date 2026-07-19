import InlineSnapshotTesting
import TesseraTerminalCore
import TesseraTestSupport
import Testing

@testable import TesseraCore

private final class ProbeRecorder {
  var bodyEvaluations = 0
  var identities: [Int: ObjectIdentifier] = [:]
}

private final class ProbeState {}

private struct ProbeLeaf: LeafView {
  typealias NodeState = ProbeState

  let key: Int
  let recorder: ProbeRecorder

  func makeState() -> ProbeState {
    ProbeState()
  }

  func sizeThatFits(
    _ proposal: ProposedSize,
    state: inout ProbeState,
    environment: EnvironmentValues
  ) -> TerminalSize {
    TerminalSize(columns: 1, rows: 1)
  }

  func render(
    in region: inout RenderRegion,
    state: inout ProbeState,
    environment: EnvironmentValues
  ) {
    recorder.identities[key] = ObjectIdentifier(state)
  }
}

private final class RowModel {
  let recorder = ProbeRecorder()
  var ids = [1, 2]
  var resetID = 1
}

private struct RowsView: View {
  let model: RowModel

  var body: some View {
    ForEach(model.ids, id: \.self) { id in
      ProbeLeaf(key: id, recorder: model.recorder)
    }
  }
}

private struct ResetView: View {
  let model: RowModel

  var body: some View {
    ProbeLeaf(key: 0, recorder: model.recorder)
      .id(model.resetID)
  }
}

private struct CountedEquatableView: Equatable, View {
  let value: Int
  let recorder: ProbeRecorder

  var body: some View {
    recorder.bodyEvaluations += 1
    return Text("value \(value)")
  }

  static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.value == rhs.value
  }
}

private final class EquatableModel {
  let recorder = ProbeRecorder()
  var value = 1
}

private struct AlternateProbeLeaf: LeafView {
  typealias NodeState = ProbeState

  let key: Int
  let recorder: ProbeRecorder

  func makeState() -> ProbeState {
    ProbeState()
  }

  func sizeThatFits(
    _ proposal: ProposedSize,
    state: inout ProbeState,
    environment: EnvironmentValues
  ) -> TerminalSize {
    TerminalSize(columns: 1, rows: 1)
  }

  func render(
    in region: inout RenderRegion,
    state: inout ProbeState,
    environment: EnvironmentValues
  ) {
    recorder.identities[key] = ObjectIdentifier(state)
  }
}

private final class AnyViewModel {
  let recorder = ProbeRecorder()
  var usesAlternative = false

  func content() -> AnyView {
    if usesAlternative {
      AnyView(AlternateProbeLeaf(key: 1, recorder: recorder))
    } else {
      AnyView(ProbeLeaf(key: 1, recorder: recorder))
    }
  }
}

private final class TupleOrderModel {
  let recorder = ProbeRecorder()
  var isReversed = false

  func first() -> AnyView {
    if isReversed {
      AnyView(AlternateProbeLeaf(key: 1, recorder: recorder))
    } else {
      AnyView(ProbeLeaf(key: 1, recorder: recorder))
    }
  }

  func second() -> AnyView {
    if isReversed {
      AnyView(ProbeLeaf(key: 2, recorder: recorder))
    } else {
      AnyView(AlternateProbeLeaf(key: 2, recorder: recorder))
    }
  }
}

private struct TupleOrderView: View {
  let model: TupleOrderModel

  var body: some View {
    model.first()
    model.second()
  }
}

private struct DuplicateIdentityView: View {
  let recorder: ProbeRecorder

  var body: some View {
    ProbeLeaf(key: 1, recorder: recorder)
      .id(1)
      .id("left")
    ProbeLeaf(key: 2, recorder: recorder)
      .id(1)
      .id("right")
  }
}

@Test
func `keyed foreach reorder preserves node state`() {
  let model = RowModel()
  let size = TerminalSize(columns: 8, rows: 2)
  let graph = ViewGraph(root: { RowsView(model: model) }, size: size)
  _ = withTestFrame(size: size) { graph.render(into: $0) }
  let initial = model.recorder.identities

  model.ids.reverse()
  graph.update()
  assertInlineSnapshot(of: graph, as: .viewGraph) {
    """
    root RowsView [proposal=(8,2), measured=(1x1), frame=(0,0,8x2), clip=(0,0,8x2), needsLayout, needsRender]
      body TupleView [proposal=(8,nil), measured=(1x1), frame=(0,0,1x1), clip=(0,0,1x1), needsLayout, needsRender]
        index(0) ForEach [proposal=(8,nil), measured=(1x1), frame=(0,0,1x1), clip=(0,0,1x1), needsLayout, needsRender]
          id(2) TupleView [proposal=(8,nil), measured=(1x1), frame=(0,0,1x1), clip=(0,0,1x1), needsLayout, needsRender]
            index(0) ProbeLeaf [proposal=(8,nil), measured=(1x1), frame=(0,0,1x1), clip=(0,0,1x1), needsLayout, needsRender]
          id(1) TupleView [proposal=(8,nil), measured=(1x1), frame=(0,0,1x1), clip=(0,0,1x1), needsLayout, needsRender]
            index(0) ProbeLeaf [proposal=(8,nil), measured=(1x1), frame=(0,0,1x1), clip=(0,0,1x1), needsLayout, needsRender]
    statistics: created=0 destroyed=0 updated=7 bodies=1 equatableSkips=0 leaves=2 measurements=0 placements=0 renders=0 reasons=["layoutViewChanged", "renderViewChanged", "updateRequested"]
    requirements: requested=[] effective=unavailable
    """
  }

  _ = withTestFrame(size: size) { graph.render(into: $0) }
  #expect(model.recorder.identities[1] == initial[1])
  #expect(model.recorder.identities[2] == initial[2])
}

@Test
func `explicit identity change replaces descendant state`() {
  let model = RowModel()
  let size = TerminalSize(columns: 4, rows: 1)
  let graph = ViewGraph(root: { ResetView(model: model) }, size: size)
  _ = withTestFrame(size: size) { graph.render(into: $0) }
  let initial = model.recorder.identities[0]

  model.resetID = 2
  graph.update()
  assertInlineSnapshot(of: graph, as: .viewGraph) {
    """
    root ResetView [proposal=(4,1), measured=(1x1), frame=(0,0,4x1), clip=(0,0,4x1), needsLayout, needsRender]
      body TupleView [proposal=(4,nil), measured=(1x1), frame=(0,0,1x1), clip=(0,0,1x1), needsLayout, needsRender]
        index(0) _IDView [proposal=(4,nil), measured=(1x1), frame=(0,0,1x1), clip=(0,0,1x1), needsLayout, needsRender]
          explicit(2) ProbeLeaf [needsLayout, needsRender]
    statistics: created=1 destroyed=1 updated=3 bodies=1 equatableSkips=0 leaves=0 measurements=0 placements=0 renders=0 reasons=["layoutViewChanged", "renderViewChanged", "updateRequested"]
    requirements: requested=[] effective=unavailable
    """
  }

  _ = withTestFrame(size: size) { graph.render(into: $0) }
  #expect(model.recorder.identities[0] != initial)
}

@Test
func `equatable root skips its complete subtree`() {
  let model = EquatableModel()
  let graph = ViewGraph(
    root: { CountedEquatableView(value: model.value, recorder: model.recorder) },
    size: TerminalSize(columns: 20, rows: 1)
  )
  let initialBodyCount = model.recorder.bodyEvaluations
  graph.update()
  assertInlineSnapshot(of: graph, as: .viewGraph) {
    """
    root CountedEquatableView [needsLayout, needsRender]
      body Text [needsLayout, needsRender]
    statistics: created=0 destroyed=0 updated=0 bodies=0 equatableSkips=1 leaves=0 measurements=0 placements=0 renders=0 reasons=["updateRequested"]
    requirements: requested=[] effective=unavailable
    """
  }
  #expect(initialBodyCount == 1)
  #expect(model.recorder.bodyEvaluations == 1)
}

@Test
func `body evaluates during update but never layout or render`() {
  let model = EquatableModel()
  let size = TerminalSize(columns: 20, rows: 1)
  let graph = ViewGraph(
    root: { CountedEquatableView(value: model.value, recorder: model.recorder) },
    size: size
  )
  let afterBuild = model.recorder.bodyEvaluations
  graph.layoutIfNeeded()
  _ = withTestFrame(size: size) { graph.render(into: $0) }
  let afterRender = model.recorder.bodyEvaluations

  model.value = 2
  graph.update()
  assertInlineSnapshot(of: graph, as: .viewGraph) {
    """
    root CountedEquatableView [proposal=(20,1), measured=(7x1), frame=(0,0,20x1), clip=(0,0,20x1), needsLayout, needsRender]
      body Text [proposal=(20,nil), measured=(7x1), frame=(0,0,7x1), clip=(0,0,7x1), needsLayout, needsRender]
    statistics: created=0 destroyed=0 updated=2 bodies=1 equatableSkips=0 leaves=1 measurements=0 placements=0 renders=0 reasons=["layoutViewChanged", "renderViewChanged", "updateRequested"]
    requirements: requested=[] effective=unavailable
    """
  }
  #expect(afterBuild == 1)
  #expect(afterRender == 1)
  #expect(model.recorder.bodyEvaluations == 2)
}

@Test
func `any view preserves state for an unchanged erased type`() {
  let recorder = ProbeRecorder()
  let size = TerminalSize(columns: 2, rows: 1)
  let graph = ViewGraph(
    root: { AnyView(ProbeLeaf(key: 1, recorder: recorder)) },
    size: size
  )
  _ = withTestFrame(size: size) { graph.render(into: $0) }
  let initial = recorder.identities[1]

  graph.update()
  assertInlineSnapshot(of: graph, as: .viewGraph) {
    """
    root AnyView [proposal=(2,1), measured=(1x1), frame=(0,0,2x1), clip=(0,0,2x1), needsLayout, needsRender]
      index(0) ProbeLeaf [proposal=(2,nil), measured=(1x1), frame=(0,0,1x1), clip=(0,0,1x1), needsLayout, needsRender]
    statistics: created=0 destroyed=0 updated=2 bodies=0 equatableSkips=0 leaves=1 measurements=0 placements=0 renders=0 reasons=["layoutViewChanged", "renderViewChanged", "updateRequested"]
    requirements: requested=[] effective=unavailable
    """
  }

  _ = withTestFrame(size: size) { graph.render(into: $0) }
  #expect(recorder.identities[1] == initial)
}

@Test
func `any view replaces state when its erased type changes`() {
  let model = AnyViewModel()
  let size = TerminalSize(columns: 2, rows: 1)
  let graph = ViewGraph(root: { model.content() }, size: size)
  _ = withTestFrame(size: size) { graph.render(into: $0) }
  let initial = model.recorder.identities[1]

  model.usesAlternative = true
  graph.update()
  assertInlineSnapshot(of: graph, as: .viewGraph) {
    """
    root AnyView [proposal=(2,1), measured=(1x1), frame=(0,0,2x1), clip=(0,0,2x1), needsLayout, needsRender]
      index(0) AlternateProbeLeaf [needsLayout, needsRender]
    statistics: created=1 destroyed=1 updated=1 bodies=0 equatableSkips=0 leaves=0 measurements=0 placements=0 renders=0 reasons=["layoutViewChanged", "renderViewChanged", "updateRequested"]
    requirements: requested=[] effective=unavailable
    """
  }

  _ = withTestFrame(size: size) { graph.render(into: $0) }
  #expect(model.recorder.identities[1] != initial)
}

@Test
func `tuple type reordering replaces affected positional slots`() {
  let model = TupleOrderModel()
  let size = TerminalSize(columns: 2, rows: 2)
  let graph = ViewGraph(root: { TupleOrderView(model: model) }, size: size)
  _ = withTestFrame(size: size) { graph.render(into: $0) }
  let initialFirst = model.recorder.identities[1]
  let initialSecond = model.recorder.identities[2]

  model.isReversed = true
  graph.update()
  assertInlineSnapshot(of: graph, as: .viewGraph) {
    """
    root TupleOrderView [proposal=(2,2), measured=(1x1), frame=(0,0,2x2), clip=(0,0,2x2), needsLayout, needsRender]
      body TupleView [proposal=(2,nil), measured=(1x1), frame=(0,0,1x1), clip=(0,0,1x1), needsLayout, needsRender]
        index(0) AnyView [proposal=(2,nil), measured=(1x1), frame=(0,0,1x1), clip=(0,0,1x1), needsLayout, needsRender]
          index(0) AlternateProbeLeaf [needsLayout, needsRender]
        index(1) AnyView [proposal=(2,nil), measured=(1x1), frame=(0,0,1x1), clip=(0,0,1x1), needsLayout, needsRender]
          index(0) ProbeLeaf [needsLayout, needsRender]
    statistics: created=2 destroyed=2 updated=4 bodies=1 equatableSkips=0 leaves=0 measurements=0 placements=0 renders=0 reasons=["layoutViewChanged", "renderViewChanged", "updateRequested"]
    requirements: requested=[] effective=unavailable
    """
  }

  _ = withTestFrame(size: size) { graph.render(into: $0) }
  #expect(model.recorder.identities[1] != initialFirst)
  #expect(model.recorder.identities[2] != initialSecond)
}

@Test
func `duplicate explicit identities under different parents remain distinct`() {
  let recorder = ProbeRecorder()
  let size = TerminalSize(columns: 2, rows: 2)
  let graph = ViewGraph(
    root: { DuplicateIdentityView(recorder: recorder) },
    size: size
  )
  _ = withTestFrame(size: size) { graph.render(into: $0) }
  let initialLeft = recorder.identities[1]
  let initialRight = recorder.identities[2]

  graph.update()
  assertInlineSnapshot(of: graph, as: .viewGraph) {
    """
    root DuplicateIdentityView [proposal=(2,2), measured=(1x1), frame=(0,0,2x2), clip=(0,0,2x2), needsLayout, needsRender]
      body TupleView [proposal=(2,nil), measured=(1x1), frame=(0,0,1x1), clip=(0,0,1x1), needsLayout, needsRender]
        index(0) _IDView [proposal=(2,nil), measured=(1x1), frame=(0,0,1x1), clip=(0,0,1x1), needsLayout, needsRender]
          explicit(left) _IDView [proposal=(2,nil), measured=(1x1), frame=(0,0,1x1), clip=(0,0,1x1), needsLayout, needsRender]
            explicit(1) ProbeLeaf [proposal=(2,nil), measured=(1x1), frame=(0,0,1x1), clip=(0,0,1x1), needsLayout, needsRender]
        index(1) _IDView [proposal=(2,nil), measured=(1x1), frame=(0,0,1x1), clip=(0,0,1x1), needsLayout, needsRender]
          explicit(right) _IDView [proposal=(2,nil), measured=(1x1), frame=(0,0,1x1), clip=(0,0,1x1), needsLayout, needsRender]
            explicit(1) ProbeLeaf [proposal=(2,nil), measured=(1x1), frame=(0,0,1x1), clip=(0,0,1x1), needsLayout, needsRender]
    statistics: created=0 destroyed=0 updated=8 bodies=1 equatableSkips=0 leaves=2 measurements=0 placements=0 renders=0 reasons=["layoutViewChanged", "renderViewChanged", "updateRequested"]
    requirements: requested=[] effective=unavailable
    """
  }

  _ = withTestFrame(size: size) { graph.render(into: $0) }
  #expect(initialLeft != initialRight)
  #expect(recorder.identities[1] == initialLeft)
  #expect(recorder.identities[2] == initialRight)
}

@Test
func `update and layout remain separate synchronous passes`() {
  var content = "a"
  let size = TerminalSize(columns: 3, rows: 1)
  let graph = ViewGraph(root: { Text(content) }, size: size)
  _ = withTestFrame(size: size) { graph.render(into: $0) }
  assertInlineSnapshot(of: graph, as: .viewGraph) {
    """
    root Text [proposal=(3,1), measured=(1x1), frame=(0,0,3x1), clip=(0,0,3x1)]
    statistics: created=1 destroyed=0 updated=0 bodies=0 equatableSkips=0 leaves=0 measurements=1 placements=1 renders=1 reasons=["renderRequested"]
    requirements: requested=[] effective=unavailable
    """
  }

  content = "bb"
  graph.update()
  assertInlineSnapshot(of: graph, as: .viewGraph) {
    """
    root Text [proposal=(3,1), measured=(1x1), frame=(0,0,3x1), clip=(0,0,3x1), needsLayout, needsRender]
    statistics: created=0 destroyed=0 updated=1 bodies=0 equatableSkips=0 leaves=1 measurements=0 placements=0 renders=0 reasons=["layoutViewChanged", "renderViewChanged", "updateRequested"]
    requirements: requested=[] effective=unavailable
    """
  }
  graph.layoutIfNeeded()
  assertInlineSnapshot(of: graph, as: .viewGraph) {
    """
    root Text [proposal=(3,1), measured=(2x1), frame=(0,0,3x1), clip=(0,0,3x1), needsRender]
    statistics: created=0 destroyed=0 updated=1 bodies=0 equatableSkips=0 leaves=1 measurements=1 placements=1 renders=0 reasons=["layoutViewChanged", "renderViewChanged", "updateRequested"]
    requirements: requested=[] effective=unavailable
    """
  }
}
