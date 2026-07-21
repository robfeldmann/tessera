import InlineSnapshotTesting
import TesseraTerminalCore
import TesseraTestSupport
import Testing

@testable import TesseraCore

private final class LifetimeTracker {
  var destroyedStates = 0
}

private final class LifetimeState {
  let tracker: LifetimeTracker

  init(tracker: LifetimeTracker) {
    self.tracker = tracker
  }

  deinit {
    tracker.destroyedStates += 1
  }
}

private struct LifetimeLeaf: LeafView {
  typealias NodeState = LifetimeState

  let tracker: LifetimeTracker

  func makeState() -> LifetimeState {
    LifetimeState(tracker: tracker)
  }

  func sizeThatFits(
    _ proposal: ProposedSize,
    state: inout LifetimeState,
    environment: EnvironmentValues
  ) -> TerminalSize {
    TerminalSize(columns: 1, rows: 1)
  }

  func render(
    in region: inout RenderRegion,
    state: inout LifetimeState,
    environment: EnvironmentValues
  ) {}
}

private final class LifetimeModel {
  var identity = 1
  var showsLeaf = true
}

private struct IdentityLifetimeView: View {
  let model: LifetimeModel
  let tracker: LifetimeTracker

  var body: some View {
    LifetimeLeaf(tracker: tracker)
      .id(model.identity)
  }
}

private struct BranchLifetimeView: View {
  let model: LifetimeModel
  let tracker: LifetimeTracker

  var body: some View {
    if model.showsLeaf {
      LifetimeLeaf(tracker: tracker)
    } else {
      Text("replacement")
    }
  }
}

@Test
func `node state dies when explicit identity changes`() {
  let tracker = LifetimeTracker()
  let model = LifetimeModel()
  let graph = ViewGraph(
    root: { IdentityLifetimeView(model: model, tracker: tracker) },
    size: TerminalSize(columns: 4, rows: 1)
  )
  let before = tracker.destroyedStates
  model.identity = 2
  graph.update()
  assertInlineSnapshot(of: graph, as: .viewGraph) {
    """
    root IdentityLifetimeView [needsLayout, needsRender]
      body TupleView [needsLayout, needsRender]
        index(0) _IDView [needsLayout, needsRender]
          explicit(2) LifetimeLeaf [needsLayout, needsRender]
    statistics: created=1 destroyed=1 updated=3 bodies=1 equatableSkips=0 leaves=0 measurements=0 placements=0 renders=0 reasons=["layoutViewChanged", "renderViewChanged", "updateRequested"]
    requirements: requested=[] effective=unavailable
    """
  }
  #expect(before == 0)
  #expect(tracker.destroyedStates == 1)
}

@Test
func `node state dies when conditional branch changes`() {
  let tracker = LifetimeTracker()
  let model = LifetimeModel()
  let graph = ViewGraph(
    root: { BranchLifetimeView(model: model, tracker: tracker) },
    size: TerminalSize(columns: 12, rows: 1)
  )
  let before = tracker.destroyedStates
  model.showsLeaf = false
  graph.update()
  assertInlineSnapshot(of: graph, as: .viewGraph) {
    """
    root BranchLifetimeView [needsLayout, needsRender]
      body TupleView [needsLayout, needsRender]
        index(0) ConditionalView [needsLayout, needsRender]
          branch(false) TupleView [needsLayout, needsRender]
            index(0) Text [needsLayout, needsRender]
    statistics: created=2 destroyed=2 updated=3 bodies=1 equatableSkips=0 leaves=0 measurements=0 placements=0 renders=0 reasons=["layoutViewChanged", "renderViewChanged", "updateRequested"]
    requirements: requested=[] effective=unavailable
    """
  }
  #expect(before == 0)
  #expect(tracker.destroyedStates == 1)
}
