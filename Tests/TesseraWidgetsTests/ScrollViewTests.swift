import InlineSnapshotTesting
import TesseraCore
import TesseraLayout
import TesseraTerminalBuffer
import TesseraTerminalCore
import TesseraTestSupport
import Testing

@testable import TesseraWidgets

private func withTestFrame(
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

private final class MeasurementRecorder {
  var proposals: [ProposedSize] = []
}

private struct SizedLeaf: LeafView {
  let size: TerminalSize
  let recorder: MeasurementRecorder

  func sizeThatFits(
    _ proposal: ProposedSize,
    state: inout Void,
    environment: EnvironmentValues
  ) -> TerminalSize {
    recorder.proposals.append(proposal)
    return size
  }

  func render(
    in region: inout RenderRegion,
    state: inout Void,
    environment: EnvironmentValues
  ) {}
}

private struct UnspecifiedHost<Content: View>: View, _LayoutView {
  typealias Body = Never

  let content: Content

  init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  func _visitChildren(
    in environment: EnvironmentValues,
    environmentOverrides: [String],
    _ visit: (_ViewChild) -> Void
  ) {
    _visitLayoutChildren(
      content,
      in: environment,
      environmentOverrides: environmentOverrides,
      visit
    )
  }

  func _sizeThatFits(
    _ proposal: ProposedSize,
    subviews: _LayoutSubviewsProxy
  ) -> TerminalSize {
    subviews[0].measure(.unspecified)
  }

  func _placeSubviews(
    in bounds: Rect,
    proposal: ProposedSize,
    subviews: _LayoutSubviewsProxy
  ) {
    subviews[0].place(bounds.origin, .unspecified)
  }
}

private final class ScrollModel {
  var content: String
  var position: TerminalPosition
  var writes = 0

  var binding: Binding<TerminalPosition> {
    Binding(
      get: { self.position },
      set: {
        self.writes += 1
        self.position = $0
      }
    )
  }

  init(content: String, position: TerminalPosition) {
    self.content = content
    self.position = position
  }
}

@Test
func `vertical scrolling measures unbounded content height without indicator reservation`()
{
  let recorder = MeasurementRecorder()
  let size = TerminalSize(columns: 4, rows: 2)
  let graph = ViewGraph(
    root: {
      ScrollView(.vertical) {
        SizedLeaf(size: TerminalSize(columns: 7, rows: 5), recorder: recorder)
      }
    },
    size: size
  )

  graph.layoutIfNeeded()

  #expect(recorder.proposals == [ProposedSize(width: 4, height: nil)])
  assertInlineSnapshot(of: graph, as: .viewGraph) {
    """
    root ScrollView [proposal=(4,2), measured=(4x2), frame=(0,0,4x2), clip=(0,0,4x2), needsRender]
      index(0) SizedLeaf [proposal=(4,nil), measured=(7x5), frame=(0,0,7x5), clip=(0,0,4x2), needsRender]
    statistics: created=2 destroyed=0 updated=0 bodies=0 equatableSkips=0 leaves=0 measurements=2 placements=2 renders=0 reasons=[]
    requirements: requested=[] effective=unavailable
    """
  }
}

@Test
func `a vertical scroll view without input remains at the origin and clips content`() {
  let size = TerminalSize(columns: 4, rows: 2)
  let graph = ViewGraph(
    root: {
      ScrollView {
        Text("ABCD\nEFGH\nIJKL")
      }
    },
    size: size
  )

  let buffer = withTestFrame(size: size) { graph.render(into: $0) }

  assertInlineSnapshot(of: buffer, as: .bufferState) {
    """
    A B C D
    E F G H
    """
  }
  assertInlineSnapshot(of: graph, as: .viewGraph) {
    """
    root ScrollView [proposal=(4,2), measured=(4x2), frame=(0,0,4x2), clip=(0,0,4x2)]
      index(0) Text [proposal=(4,nil), measured=(4x3), frame=(0,0,4x3), clip=(0,0,4x2)]
    statistics: created=2 destroyed=0 updated=0 bodies=0 equatableSkips=0 leaves=0 measurements=2 placements=2 renders=1 reasons=["renderRequested"]
    requirements: requested=[] effective=unavailable
    """
  }
}

@Test
func `horizontal scrolling translates only the enabled axis without binding writeback`() {
  let model = ScrollModel(
    content: "ABCDE\nFGHIJ",
    position: TerminalPosition(column: 2, row: 9)
  )
  let size = TerminalSize(columns: 3, rows: 2)
  let graph = ViewGraph(
    root: {
      ScrollView(.horizontal, offset: model.binding) {
        Text(model.content)
      }
    },
    size: size
  )

  let buffer = withTestFrame(size: size) { graph.render(into: $0) }

  assertInlineSnapshot(of: buffer, as: .bufferState) {
    """
    C D E
    H I J
    """
  }
  assertInlineSnapshot(of: graph, as: .viewGraph) {
    """
    root ScrollView [proposal=(3,2), measured=(3x2), frame=(0,0,3x2), clip=(0,0,3x2)]
      index(0) Text [proposal=(nil,2), measured=(5x2), frame=(-2,0,5x2), clip=(0,0,3x2)]
    statistics: created=2 destroyed=0 updated=0 bodies=0 equatableSkips=0 leaves=0 measurements=2 placements=2 renders=1 reasons=["renderRequested"]
    requirements: requested=[] effective=unavailable
    """
  }
  #expect(model.position == TerminalPosition(column: 2, row: 9))
  #expect(model.writes == 0)
}

@Test
func `two axis scrolling translates and clips both axes`() {
  let model = ScrollModel(
    content: "ABCDE\nFGHIJ\nKLMNO",
    position: TerminalPosition(column: 2, row: 1)
  )
  let size = TerminalSize(columns: 3, rows: 2)
  let graph = ViewGraph(
    root: {
      ScrollView(.all, offset: model.binding) {
        Text(model.content)
      }
    },
    size: size
  )

  let buffer = withTestFrame(size: size) { graph.render(into: $0) }

  assertInlineSnapshot(of: buffer, as: .bufferState) {
    """
    H I J
    M N O
    """
  }
  assertInlineSnapshot(of: graph, as: .viewGraph) {
    """
    root ScrollView [proposal=(3,2), measured=(3x2), frame=(0,0,3x2), clip=(0,0,3x2)]
      index(0) Text [proposal=(nil,nil), measured=(5x3), frame=(-2,-1,5x3), clip=(0,0,3x2)]
    statistics: created=2 destroyed=0 updated=0 bodies=0 equatableSkips=0 leaves=0 measurements=2 placements=2 renders=1 reasons=["renderRequested"]
    requirements: requested=[] effective=unavailable
    """
  }
}

@Test
func `an unspecified viewport adopts the content ideal size`() {
  let recorder = MeasurementRecorder()
  let size = TerminalSize(columns: 2, rows: 2)
  let graph = ViewGraph(
    root: {
      UnspecifiedHost {
        ScrollView {
          SizedLeaf(size: TerminalSize(columns: 7, rows: 5), recorder: recorder)
        }
      }
    },
    size: size
  )

  graph.layoutIfNeeded()

  #expect(recorder.proposals == [.unspecified])
  assertInlineSnapshot(of: graph, as: .viewGraph) {
    """
    root UnspecifiedHost [proposal=(2,2), measured=(7x5), frame=(0,0,2x2), clip=(0,0,2x2), needsRender]
      index(0) ScrollView [proposal=(nil,nil), measured=(7x5), frame=(0,0,7x5), clip=(0,0,2x2), needsRender]
        index(0) SizedLeaf [proposal=(nil,nil), measured=(7x5), frame=(0,0,7x5), clip=(0,0,2x2), needsRender]
    statistics: created=3 destroyed=0 updated=0 bodies=0 equatableSkips=0 leaves=0 measurements=3 placements=3 renders=0 reasons=[]
    requirements: requested=[] effective=unavailable
    """
  }
}

@Test
func `offsets clamp after binding content and viewport changes without writeback`() {
  let model = ScrollModel(
    content: "A\nB\nC",
    position: TerminalPosition(column: 4, row: 1)
  )
  let graph = ViewGraph(
    root: {
      ScrollView(.vertical, offset: model.binding) {
        Text(model.content)
      }
    },
    size: TerminalSize(columns: 4, rows: 2)
  )

  _ = withTestFrame(size: TerminalSize(columns: 4, rows: 2)) { graph.render(into: $0) }
  #expect(
    graph.diagnostics.nodes[1].frame == Rect(column: 0, row: -1, columns: 1, rows: 3))

  model.position = TerminalPosition(column: 7, row: 20)
  graph.update()
  _ = withTestFrame(size: TerminalSize(columns: 4, rows: 2)) { graph.render(into: $0) }
  #expect(
    graph.diagnostics.nodes[1].frame == Rect(column: 0, row: -1, columns: 1, rows: 3))

  model.content = "A\nB\nC\nD\nE"
  graph.update()
  _ = withTestFrame(size: TerminalSize(columns: 4, rows: 2)) { graph.render(into: $0) }
  #expect(
    graph.diagnostics.nodes[1].frame == Rect(column: 0, row: -3, columns: 1, rows: 5))

  graph.resize(to: TerminalSize(columns: 4, rows: 4))
  _ = withTestFrame(size: TerminalSize(columns: 4, rows: 4)) { graph.render(into: $0) }
  #expect(
    graph.diagnostics.nodes[1].frame == Rect(column: 0, row: -1, columns: 1, rows: 5))
  #expect(model.position == TerminalPosition(column: 7, row: 20))
  #expect(model.writes == 0)
}
