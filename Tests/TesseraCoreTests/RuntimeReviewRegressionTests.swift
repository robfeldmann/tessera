import InlineSnapshotTesting
import TesseraTerminalCore
import TesseraTestSupport
import Testing

@testable import TesseraCore

private final class RuntimeReviewRecorder {
  var bodyEvaluations = 0
  var stateIdentity: ObjectIdentifier?
}

private final class RuntimeReviewState {}

private struct RuntimeReviewLeaf: LeafView {
  typealias NodeState = RuntimeReviewState

  let recorder: RuntimeReviewRecorder

  func makeState() -> RuntimeReviewState {
    RuntimeReviewState()
  }

  func sizeThatFits(
    _ proposal: ProposedSize,
    state: inout RuntimeReviewState,
    environment: EnvironmentValues
  ) -> TerminalSize {
    TerminalSize(columns: 1, rows: 1)
  }

  func render(
    in region: inout RenderRegion,
    state: inout RuntimeReviewState,
    environment: EnvironmentValues
  ) {
    recorder.stateIdentity = ObjectIdentifier(state)
  }
}

private final class RuntimeReviewModel {
  var usesText = false
  var environmentEnabled = false
  var text = "one"
}

private struct RuntimeReviewEquatableView: Equatable, View {
  let recorder: RuntimeReviewRecorder

  var body: some View {
    recorder.bodyEvaluations += 1
    return Text("stable")
  }

  static func == (lhs: Self, rhs: Self) -> Bool {
    true
  }
}

private enum RuntimeReviewEnvironmentKey: EnvironmentKey {
  static let defaultValue = false
}

extension EnvironmentValues {
  fileprivate var runtimeReviewEnabled: Bool {
    get { self[RuntimeReviewEnvironmentKey.self] }
    set { self[RuntimeReviewEnvironmentKey.self] = newValue }
  }
}

@Test
func `any view preserves state for its dynamic type and replaces it on type change`() {
  let model = RuntimeReviewModel()
  let recorder = RuntimeReviewRecorder()
  let size = TerminalSize(columns: 8, rows: 1)
  let graph = ViewGraph(
    root: {
      if model.usesText {
        AnyView(Text("replacement"))
      } else {
        AnyView(RuntimeReviewLeaf(recorder: recorder))
      }
    },
    size: size
  )
  _ = withTestFrame(size: size) { graph.render(into: $0) }
  let initialState = recorder.stateIdentity

  graph.update()
  assertInlineSnapshot(of: graph, as: .viewGraph) {
    """
    root AnyView [proposal=(8,1), measured=(1x1), frame=(0,0,8x1), clip=(0,0,8x1), needsLayout, needsRender]
      index(0) RuntimeReviewLeaf [proposal=(8,nil), measured=(1x1), frame=(0,0,1x1), clip=(0,0,1x1), needsLayout, needsRender]
    statistics: created=0 destroyed=0 updated=2 bodies=0 equatableSkips=0 leaves=1 measurements=0 placements=0 renders=0 reasons=["layoutViewChanged", "renderViewChanged", "updateRequested"]
    requirements: requested=[] effective=unavailable
    """
  }
  _ = withTestFrame(size: size) { graph.render(into: $0) }
  let preservedState = recorder.stateIdentity
  #expect(preservedState == initialState)

  model.usesText = true
  graph.update()
  assertInlineSnapshot(of: graph, as: .viewGraph) {
    """
    root AnyView [proposal=(8,1), measured=(1x1), frame=(0,0,8x1), clip=(0,0,8x1), needsLayout, needsRender]
      index(0) Text [needsLayout, needsRender]
    statistics: created=1 destroyed=1 updated=1 bodies=0 equatableSkips=0 leaves=0 measurements=0 placements=0 renders=0 reasons=["layoutViewChanged", "renderViewChanged", "updateRequested"]
    requirements: requested=[] effective=unavailable
    """
  }
}

@Test
func `equatable environment overrides reuse unchanged storage and invalidate changes`() {
  let model = RuntimeReviewModel()
  let recorder = RuntimeReviewRecorder()
  let size = TerminalSize(columns: 8, rows: 1)
  let graph = ViewGraph(
    root: {
      RuntimeReviewEquatableView(recorder: recorder)
        .environment(\.runtimeReviewEnabled, model.environmentEnabled)
    },
    size: size
  )
  _ = withTestFrame(size: size) { graph.render(into: $0) }

  graph.update()
  assertInlineSnapshot(of: graph, as: .viewGraph) {
    """
    root _EnvironmentModifier [proposal=(8,1), measured=(6x1), frame=(0,0,8x1), clip=(0,0,8x1), needsLayout, needsRender]
      index(0) RuntimeReviewEquatableView [proposal=(8,nil), measured=(6x1), frame=(0,0,6x1), clip=(0,0,6x1), environmentOverrides=1]
        body Text [proposal=(8,nil), measured=(6x1), frame=(0,0,6x1), clip=(0,0,6x1), environmentOverrides=1]
    statistics: created=0 destroyed=0 updated=1 bodies=0 equatableSkips=1 leaves=0 measurements=0 placements=0 renders=0 reasons=["layoutViewChanged", "renderViewChanged", "updateRequested"]
    requirements: requested=[] effective=unavailable
    """
  }

  model.environmentEnabled = true
  graph.update()
  assertInlineSnapshot(of: graph, as: .viewGraph) {
    """
    root _EnvironmentModifier [proposal=(8,1), measured=(6x1), frame=(0,0,8x1), clip=(0,0,8x1), needsLayout, needsRender]
      index(0) RuntimeReviewEquatableView [proposal=(8,nil), measured=(6x1), frame=(0,0,6x1), clip=(0,0,6x1), needsLayout, needsRender, environmentOverrides=1]
        body Text [proposal=(8,nil), measured=(6x1), frame=(0,0,6x1), clip=(0,0,6x1), needsLayout, needsRender, environmentOverrides=1]
    statistics: created=0 destroyed=0 updated=3 bodies=1 equatableSkips=0 leaves=1 measurements=0 placements=0 renders=0 reasons=["layoutEnvironmentChanged", "layoutViewChanged", "renderEnvironmentChanged", "renderViewChanged", "updateRequested"]
    requirements: requested=[] effective=unavailable
    """
  }

}

@Test
func `statistics record value free invalidation causes and latest render work`() {
  let model = RuntimeReviewModel()
  let size = TerminalSize(columns: 8, rows: 1)
  let graph = ViewGraph(root: { Text(model.text) }, size: size)
  _ = withTestFrame(size: size) { graph.render(into: $0) }

  model.text = "two"
  graph.update()
  assertInlineSnapshot(of: graph, as: .viewGraph) {
    """
    root Text [proposal=(8,1), measured=(3x1), frame=(0,0,8x1), clip=(0,0,8x1), needsLayout, needsRender]
    statistics: created=0 destroyed=0 updated=1 bodies=0 equatableSkips=0 leaves=1 measurements=0 placements=0 renders=0 reasons=["layoutViewChanged", "renderViewChanged", "updateRequested"]
    requirements: requested=[] effective=unavailable
    """
  }

  _ = withTestFrame(size: size) { graph.render(into: $0) }
  assertInlineSnapshot(of: graph, as: .viewGraph) {
    """
    root Text [proposal=(8,1), measured=(3x1), frame=(0,0,8x1), clip=(0,0,8x1)]
    statistics: created=0 destroyed=0 updated=1 bodies=0 equatableSkips=0 leaves=1 measurements=1 placements=1 renders=1 reasons=["layoutViewChanged", "renderRequested", "renderViewChanged", "updateRequested"]
    requirements: requested=[] effective=unavailable
    """
  }
  _ = withTestFrame(size: size) { graph.render(into: $0) }
  assertInlineSnapshot(of: graph, as: .viewGraph) {
    """
    root Text [proposal=(8,1), measured=(3x1), frame=(0,0,8x1), clip=(0,0,8x1)]
    statistics: created=0 destroyed=0 updated=1 bodies=0 equatableSkips=0 leaves=1 measurements=1 placements=1 renders=1 reasons=["layoutViewChanged", "renderRequested", "renderViewChanged", "updateRequested"]
    requirements: requested=[] effective=unavailable
    """
  }

}
