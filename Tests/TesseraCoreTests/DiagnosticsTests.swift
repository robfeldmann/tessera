import InlineSnapshotTesting
import TesseraTerminalCore
import TesseraTestSupport
import Testing

@testable import TesseraCore

@Test
func `graph dump is stable and excludes view values`() {
  let size = TerminalSize(columns: 4, rows: 1)
  let graph = ViewGraph(root: { Text("private value") }, size: size)
  _ = withTestFrame(size: size) { graph.render(into: $0) }

  #expect(!graph.dump().contains("private value"))
  assertInlineSnapshot(of: graph.dump(), as: .lines) {
    """
    root TesseraCore.Text proposal=(4,1) measured=(13x1) frame=(0,0,4x1) clip=(0,0,4x1) dirty=[layout:false,render:false] environment=[] handlers=[] requirements=TerminalRequirements(wantsKeyboardEnhancement: false, wantsMouse: false, wantsBracketedPaste: false, wantsFocusReporting: false)
    statistics created=1 destroyed=0 updated=0 bodies=0 equatableSkips=0 leaves=0 measurements=1 placements=1 renders=1
    requirements requested=TerminalRequirements(wantsKeyboardEnhancement: false, wantsMouse: false, wantsBracketedPaste: false, wantsFocusReporting: false) effective=unavailable
    """
  }
}

@Test
func `diagnostics are immutable local snapshots with explicit requirements`() {
  var content = "one"
  let size = TerminalSize(columns: 4, rows: 1)
  let graph = ViewGraph(root: { Text(content) }, size: size)
  _ = withTestFrame(size: size) { graph.render(into: $0) }
  let initial = graph.diagnostics

  content = "two"
  graph.update()
  let updated = graph.diagnostics

  assertInlineSnapshot(of: initial, as: .diagnostics) {
    """
    StableGraphDiagnostics(
      nodes: [
        [0]: StableGraphDiagnostics.Node(
          identity: "root",
          viewType: "Text",
          parentIdentity: nil,
          childIdentities: [],
          proposal: StableGraphDiagnostics.Node.Proposal(
            width: 4,
            height: 1
          ),
          measuredSize: StableGraphDiagnostics.Node.Size(
            columns: 3,
            rows: 1
          ),
          frame: StableGraphDiagnostics.Node.Rectangle(
            column: 0,
            row: 0,
            columns: 4,
            rows: 1
          ),
          clip: StableGraphDiagnostics.Node.Rectangle(
            column: 0,
            row: 0,
            columns: 4,
            rows: 1
          ),
          environmentOverrideCount: 0,
          handlerKinds: [],
          requestedTerminalRequirements: [],
          needsLayout: false,
          needsRender: false
        )
      ],
      statistics: StableGraphDiagnostics.Statistics(
        nodesCreated: 1,
        nodesDestroyed: 0,
        nodesUpdated: 0,
        bodyEvaluations: 0,
        equatableSkips: 0,
        leafUpdates: 0,
        measurements: 1,
        placements: 1,
        renderedNodes: 1,
        focusChanges: 0,
        terminalRequirementChanges: 0,
        invalidationReasons: [
          [0]: "renderRequested"
        ]
      ),
      requestedTerminalRequirements: [],
      effectiveTerminalRequirements: .unavailable
    )
    """
  }
  assertInlineSnapshot(of: updated, as: .diagnostics) {
    """
    StableGraphDiagnostics(
      nodes: [
        [0]: StableGraphDiagnostics.Node(
          identity: "root",
          viewType: "Text",
          parentIdentity: nil,
          childIdentities: [],
          proposal: StableGraphDiagnostics.Node.Proposal(
            width: 4,
            height: 1
          ),
          measuredSize: StableGraphDiagnostics.Node.Size(
            columns: 3,
            rows: 1
          ),
          frame: StableGraphDiagnostics.Node.Rectangle(
            column: 0,
            row: 0,
            columns: 4,
            rows: 1
          ),
          clip: StableGraphDiagnostics.Node.Rectangle(
            column: 0,
            row: 0,
            columns: 4,
            rows: 1
          ),
          environmentOverrideCount: 0,
          handlerKinds: [],
          requestedTerminalRequirements: [],
          needsLayout: true,
          needsRender: true
        )
      ],
      statistics: StableGraphDiagnostics.Statistics(
        nodesCreated: 0,
        nodesDestroyed: 0,
        nodesUpdated: 1,
        bodyEvaluations: 0,
        equatableSkips: 0,
        leafUpdates: 1,
        measurements: 0,
        placements: 0,
        renderedNodes: 0,
        focusChanges: 0,
        terminalRequirementChanges: 0,
        invalidationReasons: [
          [0]: "layoutViewChanged",
          [1]: "renderViewChanged",
          [2]: "updateRequested"
        ]
      ),
      requestedTerminalRequirements: [],
      effectiveTerminalRequirements: .unavailable
    )
    """
  }
  #expect(!String(describing: initial).contains("one"))
  #expect(!String(describing: updated).contains("two"))
}
