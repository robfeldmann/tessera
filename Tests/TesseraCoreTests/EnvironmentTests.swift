import InlineSnapshotTesting
import TesseraTerminalBuffer
import TesseraTerminalCore
import TesseraTestSupport
import Testing

@testable import TesseraCore

private enum TestNumberKey: EnvironmentKey {
  static let defaultValue = 0
}

extension EnvironmentValues {
  fileprivate var testNumber: Int {
    get { self[TestNumberKey.self] }
    set { self[TestNumberKey.self] = newValue }
  }
}

private final class EnvironmentModel {
  var number = 1
}

private struct EnvironmentFixture: View {
  let model: EnvironmentModel

  var body: some View {
    EnvironmentReader { environment in
      Text("\(environment.testNumber)")
    }
    .environment(\.testNumber, model.number)
  }
}

@Test
func `environment values use copy on write storage`() {
  var original = EnvironmentValues()
  original.testNumber = 1
  var copy = original
  copy.testNumber = 2

  #expect(original.testNumber == 1)
  #expect(copy.testNumber == 2)
  #expect(EnvironmentValues().testNumber == 0)
}

@Test
func `environment changes invalidate and reach descendants`() {
  let model = EnvironmentModel()
  let size = TerminalSize(columns: 2, rows: 1)
  let graph = ViewGraph(root: { EnvironmentFixture(model: model) }, size: size)
  let first = withTestFrame(size: size) { graph.render(into: $0) }.buffer
  assertInlineSnapshot(of: first, as: .bufferState) {
    """
    1 ·
    """
  }

  model.number = 2
  graph.update()
  assertInlineSnapshot(of: graph, as: .viewGraph) {
    """
    root EnvironmentFixture [proposal=(2,1), measured=(1x1), frame=(0,0,2x1), clip=(0,0,2x1), needsLayout, needsRender]
      body TupleView [proposal=(2,nil), measured=(1x1), frame=(0,0,1x1), clip=(0,0,1x1), needsLayout, needsRender]
        index(0) _EnvironmentModifier [proposal=(2,nil), measured=(1x1), frame=(0,0,1x1), clip=(0,0,1x1), needsLayout, needsRender]
          index(0) EnvironmentReader [proposal=(2,nil), measured=(1x1), frame=(0,0,1x1), clip=(0,0,1x1), needsLayout, needsRender, environmentOverrides=1]
            index(0) TupleView [proposal=(2,nil), measured=(1x1), frame=(0,0,1x1), clip=(0,0,1x1), needsLayout, needsRender, environmentOverrides=1]
              index(0) Text [proposal=(2,nil), measured=(1x1), frame=(0,0,1x1), clip=(0,0,1x1), needsLayout, needsRender, environmentOverrides=1]
    statistics: created=0 destroyed=0 updated=6 bodies=1 equatableSkips=0 leaves=1 measurements=0 placements=0 renders=0 reasons=["layoutEnvironmentChanged", "layoutViewChanged", "renderEnvironmentChanged", "renderViewChanged", "updateRequested"]
    requirements: requested=[] effective=unavailable
    """
  }

  let second = withTestFrame(size: size) { graph.render(into: $0) }.buffer
  assertInlineSnapshot(of: second, as: .bufferState) {
    """
    2 ·
    """
  }
}
