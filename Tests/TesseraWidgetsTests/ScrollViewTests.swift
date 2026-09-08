import InlineSnapshotTesting
import TesseraCore
import TesseraLayout
import TesseraTerminalBuffer
import TesseraTerminalCore
import TesseraTerminalInput
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
  var measuredSizes: [TerminalSize] = []
  var proposals: [ProposedSize] = []
}
private struct IntrinsicSizingCase: Sendable {
  let axes: Axis.Set
  let contentSize: TerminalSize
  let expectedSize: TerminalSize
  let proposal: ProposedSize
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

private struct FlexibleLeaf: LeafView {
  let rows: Int
  let recorder: MeasurementRecorder

  func sizeThatFits(
    _ proposal: ProposedSize,
    state: inout Void,
    environment: EnvironmentValues
  ) -> TerminalSize {
    recorder.proposals.append(proposal)
    return TerminalSize(columns: proposal.width ?? 1, rows: rows)
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

private struct ProposalHost<Content: View>: View, _LayoutView {
  typealias Body = Never

  let content: Content
  let childProposal: ProposedSize
  let recorder: MeasurementRecorder?

  init(
    _ childProposal: ProposedSize,
    recorder: MeasurementRecorder? = nil,
    @ViewBuilder content: () -> Content
  ) {
    self.childProposal = childProposal
    self.recorder = recorder
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
    let size = subviews[0].measure(childProposal)
    recorder?.measuredSizes.append(size)
    return size
  }
  func _placeSubviews(
    in bounds: Rect,
    proposal: ProposedSize,
    subviews: _LayoutSubviewsProxy
  ) {
    subviews[0].place(bounds.origin, childProposal)
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

  var focus: FocusID?

  var focusBinding: Binding<FocusID?> {
    Binding(get: { self.focus }, set: { self.focus = $0 })
  }

  init(content: String, position: TerminalPosition) {
    self.content = content
    self.position = position
  }
}

@Test
func
  `vertical scrolling measures unbounded content height before reserving a trailing indicator`()
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

  #expect(
    recorder.proposals == [
      ProposedSize(width: 4, height: nil),
      ProposedSize(width: 3, height: nil),
    ]
  )
  assertInlineSnapshot(of: graph, as: .viewGraph) {
    """
    root ScrollView [proposal=(4,2), measured=(4x2), frame=(0,0,4x2), clip=(0,0,4x2), needsRender, handlers=["event", "pointer"], requirements=["mouse"]]
      index(0) SizedLeaf [proposal=(3,nil), measured=(7x5), frame=(0,0,7x5), clip=(0,0,3x2), needsRender]
      index(1) ScrollIndicator [proposal=(1,2), measured=(1x2), frame=(3,0,1x2), clip=(3,0,1x2), needsRender]
      index(2) ScrollIndicator [needsRender]
    statistics: created=4 destroyed=0 updated=0 bodies=0 equatableSkips=0 leaves=0 measurements=4 placements=4 renders=0 reasons=[]
    requirements: requested=["mouse"] effective=unavailable
    """
  }
}

@Test
func `content is re-proposed the reserved width when the vertical indicator appears`() {
  let recorder = MeasurementRecorder()
  let size = TerminalSize(columns: 4, rows: 2)
  let graph = ViewGraph(
    root: {
      ScrollView(.vertical) {
        FlexibleLeaf(rows: 5, recorder: recorder)
      }
    },
    size: size
  )

  graph.layoutIfNeeded()

  #expect(
    recorder.proposals == [
      ProposedSize(width: 4, height: nil),
      ProposedSize(width: 3, height: nil),
    ]
  )
  assertInlineSnapshot(of: graph, as: .viewGraph) {
    """
    root ScrollView [proposal=(4,2), measured=(4x2), frame=(0,0,4x2), clip=(0,0,4x2), needsRender, handlers=["event", "pointer"], requirements=["mouse"]]
      index(0) FlexibleLeaf [proposal=(3,nil), measured=(3x5), frame=(0,0,3x5), clip=(0,0,3x2), needsRender]
      index(1) ScrollIndicator [proposal=(1,2), measured=(1x2), frame=(3,0,1x2), clip=(3,0,1x2), needsRender]
      index(2) ScrollIndicator [needsRender]
    statistics: created=4 destroyed=0 updated=0 bodies=0 equatableSkips=0 leaves=0 measurements=4 placements=4 renders=0 reasons=[]
    requirements: requested=["mouse"] effective=unavailable
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
    A B C ┃{fg=indexed(14),bold}
    E F G │{dim}
    """
  }
  assertInlineSnapshot(of: graph, as: .viewGraph) {
    """
    root ScrollView [proposal=(4,2), measured=(4x2), frame=(0,0,4x2), clip=(0,0,4x2), handlers=["event", "pointer"], requirements=["mouse"]]
      index(0) Text [proposal=(3,nil), measured=(4x3), frame=(0,0,4x3), clip=(0,0,3x2)]
      index(1) ScrollIndicator [proposal=(1,2), measured=(1x2), frame=(3,0,1x2), clip=(3,0,1x2)]
      index(2) ScrollIndicator
    statistics: created=4 destroyed=0 updated=0 bodies=0 equatableSkips=0 leaves=0 measurements=4 placements=4 renders=2 reasons=["renderRequested"]
    requirements: requested=["mouse"] effective=unavailable
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
    ─{dim} ─{dim} ━{fg=indexed(14),bold}
    """
  }
  assertInlineSnapshot(of: graph, as: .viewGraph) {
    """
    root ScrollView [proposal=(3,2), measured=(3x2), frame=(0,0,3x2), clip=(0,0,3x2), handlers=["event", "pointer"], requirements=["mouse"]]
      index(0) Text [proposal=(nil,1), measured=(5x2), frame=(-2,0,5x2), clip=(0,0,3x1)]
      index(1) ScrollIndicator
      index(2) ScrollIndicator [proposal=(3,1), measured=(3x1), frame=(0,1,3x1), clip=(0,1,3x1)]
    statistics: created=4 destroyed=0 updated=0 bodies=0 equatableSkips=0 leaves=0 measurements=4 placements=4 renders=2 reasons=["renderRequested"]
    requirements: requested=["mouse"] effective=unavailable
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
    H I ┃{fg=indexed(14),bold}
    ━{fg=indexed(14),bold} ─{dim} ·
    """
  }
  assertInlineSnapshot(of: graph, as: .viewGraph) {
    """
    root ScrollView [proposal=(3,2), measured=(3x2), frame=(0,0,3x2), clip=(0,0,3x2), handlers=["event", "pointer"], requirements=["mouse"]]
      index(0) Text [proposal=(nil,nil), measured=(5x3), frame=(-2,-1,5x3), clip=(0,0,2x1)]
      index(1) ScrollIndicator [proposal=(1,1), measured=(1x1), frame=(2,0,1x1), clip=(2,0,1x1)]
      index(2) ScrollIndicator [proposal=(2,1), measured=(2x1), frame=(0,1,2x1), clip=(0,1,2x1)]
    statistics: created=4 destroyed=0 updated=0 bodies=0 equatableSkips=0 leaves=0 measurements=4 placements=4 renders=3 reasons=["renderRequested"]
    requirements: requested=["mouse"] effective=unavailable
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
      index(0) ScrollView [proposal=(nil,nil), measured=(7x5), frame=(0,0,7x5), clip=(0,0,2x2), needsRender, handlers=["event", "pointer"], requirements=["mouse"]]
        index(0) SizedLeaf [proposal=(nil,nil), measured=(7x5), frame=(0,0,7x5), clip=(0,0,2x2), needsRender]
        index(1) ScrollIndicator [needsRender]
        index(2) ScrollIndicator [needsRender]
    statistics: created=5 destroyed=0 updated=0 bodies=0 equatableSkips=0 leaves=0 measurements=3 placements=5 renders=0 reasons=[]
    requirements: requested=["mouse"] effective=unavailable
    """
  }
}

@Test
func `intrinsic height includes a horizontal overflow indicator`() {
  let recorder = MeasurementRecorder()
  let graph = ViewGraph(
    root: {
      ProposalHost(ProposedSize(width: 3, height: nil)) {
        ScrollView(.horizontal) {
          SizedLeaf(size: TerminalSize(columns: 5, rows: 2), recorder: recorder)
        }
      }
    },
    size: TerminalSize(columns: 3, rows: 3)
  )

  graph.layoutIfNeeded()

  #expect(recorder.proposals == [.unspecified])
  assertInlineSnapshot(of: graph, as: .viewGraph) {
    """
    root ProposalHost [proposal=(3,3), measured=(3x3), frame=(0,0,3x3), clip=(0,0,3x3), needsRender]
      index(0) ScrollView [proposal=(3,nil), measured=(3x3), frame=(0,0,3x3), clip=(0,0,3x3), needsRender, handlers=["event", "pointer"], requirements=["mouse"]]
        index(0) SizedLeaf [proposal=(nil,nil), measured=(5x2), frame=(0,0,5x2), clip=(0,0,3x2), needsRender]
        index(1) ScrollIndicator [needsRender]
        index(2) ScrollIndicator [proposal=(3,1), measured=(3x1), frame=(0,2,3x1), clip=(0,2,3x1), needsRender]
    statistics: created=5 destroyed=0 updated=0 bodies=0 equatableSkips=0 leaves=0 measurements=4 placements=5 renders=0 reasons=[]
    requirements: requested=["mouse"] effective=unavailable
    """
  }
}

@Test
func `intrinsic width includes a vertical overflow indicator`() {
  let recorder = MeasurementRecorder()
  let graph = ViewGraph(
    root: {
      ProposalHost(ProposedSize(width: nil, height: 2)) {
        ScrollView(.vertical) {
          SizedLeaf(size: TerminalSize(columns: 2, rows: 4), recorder: recorder)
        }
      }
    },
    size: TerminalSize(columns: 3, rows: 2)
  )

  graph.layoutIfNeeded()

  #expect(recorder.proposals == [.unspecified])
  assertInlineSnapshot(of: graph, as: .viewGraph) {
    """
    root ProposalHost [proposal=(3,2), measured=(3x2), frame=(0,0,3x2), clip=(0,0,3x2), needsRender]
      index(0) ScrollView [proposal=(nil,2), measured=(3x2), frame=(0,0,3x2), clip=(0,0,3x2), needsRender, handlers=["event", "pointer"], requirements=["mouse"]]
        index(0) SizedLeaf [proposal=(nil,nil), measured=(2x4), frame=(0,0,2x4), clip=(0,0,2x2), needsRender]
        index(1) ScrollIndicator [proposal=(1,2), measured=(1x2), frame=(2,0,1x2), clip=(2,0,1x2), needsRender]
        index(2) ScrollIndicator [needsRender]
    statistics: created=5 destroyed=0 updated=0 bodies=0 equatableSkips=0 leaves=0 measurements=4 placements=5 renders=0 reasons=[]
    requirements: requested=["mouse"] effective=unavailable
    """
  }
}

@Test(
  arguments: [
    IntrinsicSizingCase(
      axes: .vertical,
      contentSize: TerminalSize(columns: 64, rows: 24),
      expectedSize: TerminalSize(columns: 65, rows: 12),
      proposal: ProposedSize(width: nil, height: 12)
    ),
    IntrinsicSizingCase(
      axes: .horizontal,
      contentSize: TerminalSize(columns: 64, rows: 24),
      expectedSize: TerminalSize(columns: 52, rows: 25),
      proposal: ProposedSize(width: 52, height: nil)
    ),
    IntrinsicSizingCase(
      axes: .horizontal,
      contentSize: TerminalSize(columns: 5, rows: 1),
      expectedSize: TerminalSize(columns: 3, rows: 2),
      proposal: ProposedSize(width: 3, height: nil)
    ),
    IntrinsicSizingCase(
      axes: .vertical,
      contentSize: TerminalSize(columns: 1, rows: 5),
      expectedSize: TerminalSize(columns: 2, rows: 3),
      proposal: ProposedSize(width: nil, height: 3)
    ),
  ]
)
private func `intrinsic sizing reserves indicator edges only for overflowing axes`(
  testCase: IntrinsicSizingCase
) {
  let recorder = MeasurementRecorder()
  let graph = ViewGraph(
    root: {
      ProposalHost(testCase.proposal, recorder: recorder) {
        ScrollView(testCase.axes) {
          SizedLeaf(size: testCase.contentSize, recorder: MeasurementRecorder())
        }
      }
    },
    size: testCase.expectedSize
  )

  graph.layoutIfNeeded()

  #expect(recorder.measuredSizes.last == testCase.expectedSize)
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
  assertInlineSnapshot(of: graph, as: .viewGraph) {
    """
    root ScrollView [proposal=(4,2), measured=(4x2), frame=(0,0,4x2), clip=(0,0,4x2), handlers=["event", "pointer"], requirements=["mouse"]]
      index(0) Text [proposal=(3,nil), measured=(1x3), frame=(0,-1,1x3), clip=(0,0,1x2)]
      index(1) ScrollIndicator [proposal=(1,2), measured=(1x2), frame=(3,0,1x2), clip=(3,0,1x2)]
      index(2) ScrollIndicator
    statistics: created=4 destroyed=0 updated=0 bodies=0 equatableSkips=0 leaves=0 measurements=4 placements=4 renders=2 reasons=["renderRequested"]
    requirements: requested=["mouse"] effective=unavailable
    """
  }
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

@Test
func
  `vertical overflow reserves a trailing indicator and clips content to the reduced viewport`()
{
  let size = TerminalSize(columns: 4, rows: 2)
  let graph = ViewGraph(
    root: {
      ScrollView(.vertical) {
        Text("ABCD\nEFGH\nIJKL")
      }
    },
    size: size
  )

  let buffer = withTestFrame(size: size) { graph.render(into: $0) }

  assertInlineSnapshot(of: buffer, as: .bufferState) {
    """
    A B C ┃{fg=indexed(14),bold}
    E F G │{dim}
    """
  }
  assertInlineSnapshot(of: graph, as: .viewGraph) {
    """
    root ScrollView [proposal=(4,2), measured=(4x2), frame=(0,0,4x2), clip=(0,0,4x2), handlers=["event", "pointer"], requirements=["mouse"]]
      index(0) Text [proposal=(3,nil), measured=(4x3), frame=(0,0,4x3), clip=(0,0,3x2)]
      index(1) ScrollIndicator [proposal=(1,2), measured=(1x2), frame=(3,0,1x2), clip=(3,0,1x2)]
      index(2) ScrollIndicator
    statistics: created=4 destroyed=0 updated=0 bodies=0 equatableSkips=0 leaves=0 measurements=4 placements=4 renders=2 reasons=["renderRequested"]
    requirements: requested=["mouse"] effective=unavailable
    """
  }
}

@Test
func `two axis overflow reserves both indicators and leaves their corner unpainted`() {
  let size = TerminalSize(columns: 3, rows: 2)
  let graph = ViewGraph(
    root: {
      ScrollView(.all, offset: Binding.constant(TerminalPosition(column: 2, row: 1))) {
        Text("ABCDE\nFGHIJ\nKLMNO")
      }
    },
    size: size
  )

  let buffer = withTestFrame(size: size) { graph.render(into: $0) }

  assertInlineSnapshot(of: buffer, as: .bufferState) {
    """
    H I ┃{fg=indexed(14),bold}
    ━{fg=indexed(14),bold} ─{dim} ·
    """
  }
  assertInlineSnapshot(of: graph, as: .viewGraph) {
    """
    root ScrollView [proposal=(3,2), measured=(3x2), frame=(0,0,3x2), clip=(0,0,3x2), handlers=["event", "pointer"], requirements=["mouse"]]
      index(0) Text [proposal=(nil,nil), measured=(5x3), frame=(-2,-1,5x3), clip=(0,0,2x1)]
      index(1) ScrollIndicator [proposal=(1,1), measured=(1x1), frame=(2,0,1x1), clip=(2,0,1x1)]
      index(2) ScrollIndicator [proposal=(2,1), measured=(2x1), frame=(0,1,2x1), clip=(0,1,2x1)]
    statistics: created=4 destroyed=0 updated=0 bodies=0 equatableSkips=0 leaves=0 measurements=4 placements=4 renders=3 reasons=["renderRequested"]
    requirements: requested=["mouse"] effective=unavailable
    """
  }
}

@Test
func `no overflow leaves the whole viewport available to content`() {
  let size = TerminalSize(columns: 4, rows: 2)
  let graph = ViewGraph(
    root: {
      ScrollView(.vertical) {
        Text("ABCD\nEFGH")
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
    root ScrollView [proposal=(4,2), measured=(4x2), frame=(0,0,4x2), clip=(0,0,4x2), handlers=["event", "pointer"], requirements=["mouse"]]
      index(0) Text [proposal=(4,nil), measured=(4x2), frame=(0,0,4x2), clip=(0,0,4x2)]
      index(1) ScrollIndicator
      index(2) ScrollIndicator
    statistics: created=4 destroyed=0 updated=0 bodies=0 equatableSkips=0 leaves=0 measurements=2 placements=4 renders=1 reasons=["renderRequested"]
    requirements: requested=["mouse"] effective=unavailable
    """
  }
}

@Test
func `focused arrows move only along enabled scroll axes`() {
  let id = FocusID("vertical")
  let model = ScrollModel(
    content: "ABCD\nEFGH\nIJKL\nMNOP\nQRST",
    position: TerminalPosition(column: 7, row: 0)
  )
  model.focus = id
  let graph = ViewGraph(
    root: {
      ScrollView(.vertical, offset: model.binding) {
        Text(model.content)
      }
      .focusable(id)
      .focused(model.focusBinding, equals: id)
    },
    size: TerminalSize(columns: 4, rows: 3)
  )

  graph.layoutIfNeeded()

  #expect(graph.focus.focused == id)
  #expect(graph.dispatch(.key(Key(code: .right))) == .ignored)
  #expect(model.position == TerminalPosition(column: 7, row: 0))
  #expect(graph.dispatch(.key(Key(code: .down))) == .handled)
  #expect(model.position == TerminalPosition(column: 7, row: 1))
  #expect(graph.dispatch(.key(Key(code: .up))) == .handled)
  #expect(model.position == TerminalPosition(column: 7, row: 0))

  let horizontalID = FocusID("horizontal")
  let horizontal = ScrollModel(
    content: "ABCDE\nFGHIJ",
    position: TerminalPosition(column: 0, row: 7)
  )
  horizontal.focus = horizontalID
  let horizontalGraph = ViewGraph(
    root: {
      ScrollView(.horizontal, offset: horizontal.binding) {
        Text(horizontal.content)
      }
      .focusable(horizontalID)
      .focused(horizontal.focusBinding, equals: horizontalID)
    },
    size: TerminalSize(columns: 3, rows: 2)
  )

  horizontalGraph.layoutIfNeeded()

  #expect(horizontalGraph.dispatch(.key(Key(code: .down))) == .ignored)
  #expect(horizontal.position == TerminalPosition(column: 0, row: 7))
  #expect(horizontalGraph.dispatch(.key(Key(code: .right))) == .handled)
  #expect(horizontal.position == TerminalPosition(column: 1, row: 7))
  #expect(horizontalGraph.dispatch(.key(Key(code: .left))) == .handled)
  #expect(horizontal.position == TerminalPosition(column: 0, row: 7))
}

@Test
func `page home and end keys clamp to the laid out scroll bounds`() {
  let id = FocusID("all")
  let model = ScrollModel(
    content: Array(repeating: "ABCDEFGHIJ", count: 10).joined(separator: "\n"),
    position: TerminalPosition(column: 1, row: 1)
  )
  model.focus = id
  let graph = ViewGraph(
    root: {
      ScrollView(.all, offset: model.binding) {
        Text(model.content)
      }
      .focusable(id)
      .focused(model.focusBinding, equals: id)
    },
    size: TerminalSize(columns: 5, rows: 4)
  )

  graph.layoutIfNeeded()

  #expect(graph.dispatch(.key(Key(code: .pageDown))) == .handled)
  #expect(model.position == TerminalPosition(column: 1, row: 4))
  #expect(graph.dispatch(.key(Key(code: .pageUp))) == .handled)
  #expect(model.position == TerminalPosition(column: 1, row: 1))
  #expect(graph.dispatch(.key(Key(code: .end))) == .handled)
  #expect(model.position == TerminalPosition(column: 6, row: 7))
  #expect(graph.dispatch(.key(Key(code: .pageDown))) == .ignored)
  #expect(graph.dispatch(.key(Key(code: .pageUp))) == .handled)
  #expect(model.position == TerminalPosition(column: 6, row: 4))
  #expect(graph.dispatch(.key(Key(code: .home))) == .handled)
  #expect(model.position == TerminalPosition(column: 0, row: 0))
}

@Test
func `scroll keys bubble at bounds and when disabled`() {
  let id = FocusID("enabled")
  let model = ScrollModel(
    content: "A\nB\nC\nD\nE",
    position: TerminalPosition(column: 0, row: 0)
  )
  model.focus = id
  let graph = ViewGraph(
    root: {
      ScrollView(.vertical, offset: model.binding) {
        Text(model.content)
      }
      .focusable(id)
      .focused(model.focusBinding, equals: id)
    },
    size: TerminalSize(columns: 4, rows: 2)
  )

  graph.layoutIfNeeded()

  #expect(graph.dispatch(.key(Key(code: .up))) == .ignored)
  #expect(graph.dispatch(.key(Key(code: .pageUp))) == .ignored)
  #expect(graph.dispatch(.key(Key(code: .home))) == .ignored)

  let disabledID = FocusID("disabled")
  let disabledModel = ScrollModel(
    content: "A\nB\nC\nD\nE",
    position: TerminalPosition(column: 0, row: 0)
  )
  disabledModel.focus = disabledID
  let disabledGraph = ViewGraph(
    root: {
      ScrollView(.vertical, offset: disabledModel.binding) {
        Text(disabledModel.content)
      }
      .focusable(disabledID)
      .focused(disabledModel.focusBinding, equals: disabledID)
      .disabled()
    },
    size: TerminalSize(columns: 4, rows: 2)
  )

  disabledGraph.layoutIfNeeded()

  #expect(disabledGraph.focus.focused == nil)
  #expect(disabledGraph.dispatch(.key(Key(code: .down))) == .ignored)
  #expect(disabledModel.position == TerminalPosition(column: 0, row: 0))
}

@Test
func `disabled scroll view inside a focusable modifier ignores directional keys`() {
  let id = FocusID("disabled-inside-focusable")
  let model = ScrollModel(
    content: "A\nB\nC\nD\nE",
    position: TerminalPosition(column: 0, row: 0)
  )
  model.focus = id
  let graph = ViewGraph(
    root: {
      ScrollView(.vertical, offset: model.binding) {
        Text(model.content)
      }
      .disabled()
      .focusable(id)
      .focused(model.focusBinding, equals: id)
    },
    size: TerminalSize(columns: 4, rows: 2)
  )

  graph.layoutIfNeeded()

  #expect(graph.focus.focused == id)
  #expect(graph.dispatch(.key(Key(code: .down))) == .ignored)
  #expect(model.position == TerminalPosition(column: 0, row: 0))
  #expect(model.writes == 0)

  let rendered = withTestFrame(size: TerminalSize(columns: 4, rows: 2)) {
    graph.render(into: $0)
  }
  let focusStyle = EnvironmentValues().semanticStyles.focus
  for position in [
    TerminalPosition(column: 0, row: 0),
    TerminalPosition(column: 1, row: 0),
    TerminalPosition(column: 2, row: 0),
    TerminalPosition(column: 3, row: 0),
    TerminalPosition(column: 0, row: 1),
    TerminalPosition(column: 1, row: 1),
    TerminalPosition(column: 2, row: 1),
    TerminalPosition(column: 3, row: 1),
  ] {
    let style = rendered[position.row, position.column].style
    #expect(
      style.foreground != focusStyle.foreground
        || style.background != focusStyle.background
        || style.attributes != focusStyle.attributes
    )
  }
}

@Test
func `focus traversal routes scrolling to the focused scroll view`() {
  let firstID = FocusID("first")
  let secondID = FocusID("second")
  let first = ScrollModel(
    content: "A\nB\nC",
    position: TerminalPosition(column: 0, row: 0)
  )
  let second = ScrollModel(
    content: "D\nE\nF",
    position: TerminalPosition(column: 0, row: 0)
  )
  let graph = ViewGraph(
    root: {
      VStack {
        ScrollView(.vertical, offset: first.binding) {
          Text(first.content)
        }
        .focusable(firstID)
        .focused(first.focusBinding, equals: firstID)
        ScrollView(.vertical, offset: second.binding) {
          Text(second.content)
        }
        .focusable(secondID)
        .focused(second.focusBinding, equals: secondID)
      }
    },
    size: TerminalSize(columns: 4, rows: 4)
  )

  graph.layoutIfNeeded()

  #expect(graph.focus.focusableIDs == [firstID, secondID])
  graph.focus.advance(.forward)
  #expect(first.focus == firstID)
  #expect(graph.dispatch(.key(Key(code: .down))) == .handled)
  #expect(first.position == TerminalPosition(column: 0, row: 1))
  #expect(second.position == TerminalPosition(column: 0, row: 0))
  graph.focus.advance(.forward)
  #expect(second.focus == secondID)
  #expect(graph.dispatch(.key(Key(code: .down))) == .handled)
  #expect(first.position == TerminalPosition(column: 0, row: 1))
  #expect(second.position == TerminalPosition(column: 0, row: 1))
}

@Test
func `repeat key events scroll exactly like presses`() {
  let id = FocusID("vertical")
  let model = ScrollModel(
    content: "A\nB\nC\nD\nE",
    position: TerminalPosition(column: 0, row: 0)
  )
  model.focus = id
  let graph = ViewGraph(
    root: {
      ScrollView(.vertical, offset: model.binding) {
        Text(model.content)
      }
      .focusable(id)
      .focused(model.focusBinding, equals: id)
    },
    size: TerminalSize(columns: 4, rows: 2)
  )

  graph.layoutIfNeeded()

  #expect(graph.dispatch(.key(Key(code: .down, kind: .repeat))) == .handled)
  #expect(model.position == TerminalPosition(column: 0, row: 1))
  #expect(graph.dispatch(.key(Key(code: .up, kind: .repeat))) == .handled)
  #expect(model.position == TerminalPosition(column: 0, row: 0))
  #expect(graph.dispatch(.key(Key(code: .down, kind: .release))) == .ignored)
  #expect(model.position == TerminalPosition(column: 0, row: 0))
}

@Test
func `an owned focus identity registers only while content overflows`() {
  let id = FocusID("viewport")
  let model = ScrollModel(
    content: "A\nB",
    position: TerminalPosition(column: 0, row: 0)
  )
  let graph = ViewGraph(
    root: {
      ScrollView(.vertical, offset: model.binding) {
        Text(model.content)
      }
      .focusable(whileScrollable: id)
    },
    size: TerminalSize(columns: 4, rows: 4)
  )

  graph.layoutIfNeeded()
  #expect(graph.focus.focusableIDs.isEmpty, "fitting content must not take a focus stop")

  model.content = "A\nB\nC\nD\nE\nF"
  graph.update()
  graph.layoutIfNeeded()
  #expect(
    graph.focus.focusableIDs == [id],
    "overflow must register as soon as layout settles, without another update"
  )

  graph.focus.focus(id)
  #expect(graph.dispatch(.key(Key(code: .down))) == .handled)
  #expect(model.position == TerminalPosition(column: 0, row: 1))

  model.content = "A"
  graph.update()
  graph.layoutIfNeeded()
  #expect(
    graph.focus.focusableIDs.isEmpty,
    "fitting again must withdraw as soon as layout settles"
  )
  #expect(graph.focus.focused == nil, "withdrawal must release focus held by the viewport")
}

@Test
func `a resize transition republishes focus eligibility after layout alone`() {
  let id = FocusID("viewport")
  let model = ScrollModel(
    content: "A\nB\nC",
    position: TerminalPosition(column: 0, row: 0)
  )
  let graph = ViewGraph(
    root: {
      ScrollView(.vertical, offset: model.binding) {
        Text(model.content)
      }
      .focusable(whileScrollable: id)
    },
    size: TerminalSize(columns: 4, rows: 4)
  )

  graph.layoutIfNeeded()
  #expect(graph.focus.focusableIDs.isEmpty, "content fits the initial viewport")

  graph.resize(to: TerminalSize(columns: 4, rows: 2))
  graph.layoutIfNeeded()
  #expect(
    graph.focus.focusableIDs == [id],
    "shrinking the viewport must register the stop after layout alone"
  )

  graph.resize(to: TerminalSize(columns: 4, rows: 6))
  graph.layoutIfNeeded()
  #expect(
    graph.focus.focusableIDs.isEmpty,
    "growing the viewport must withdraw the stop after layout alone"
  )
}

@Test
func `an offset-less whileScrollable viewport never takes a focus stop`() {
  let id = FocusID("viewport")
  let graph = ViewGraph(
    root: {
      ScrollView(.vertical) {
        VStack {
          Text("A")
          Text("B")
          Text("C")
          Text("D")
          Text("E")
        }
      }
      .focusable(whileScrollable: id)
    },
    size: TerminalSize(columns: 4, rows: 2)
  )

  graph.layoutIfNeeded()
  graph.update()
  #expect(
    graph.focus.focusableIDs.isEmpty,
    "a viewport with no offset binding cannot act on focus and must not register"
  )
}

@Test
func `unconsumed scroll keys bubble to an enclosing focused-within viewport`() {
  let innerID = FocusID("inner")
  let inner = ScrollModel(
    content: "ABCDEFGH",
    position: TerminalPosition(column: 0, row: 0)
  )
  let outer = ScrollModel(
    content: "",
    position: TerminalPosition(column: 0, row: 0)
  )
  let graph = ViewGraph(
    root: {
      ScrollView(.vertical, offset: outer.binding) {
        VStack {
          ScrollView(.horizontal, offset: inner.binding) {
            Text(inner.content)
          }
          .focusable(whileScrollable: innerID)
          Text("row 1")
          Text("row 2")
          Text("row 3")
          Text("row 4")
        }
      }
      .focusable(whileScrollable: FocusID("outer"))
    },
    size: TerminalSize(columns: 4, rows: 3)
  )

  graph.layoutIfNeeded()
  graph.update()
  graph.focus.focus(innerID)

  #expect(graph.dispatch(.key(Key(code: .right))) == .handled)
  #expect(inner.position == TerminalPosition(column: 1, row: 0), "focused inner pans")
  #expect(outer.position == TerminalPosition(column: 0, row: 0))

  #expect(graph.dispatch(.key(Key(code: .down))) == .handled)
  #expect(
    outer.position == TerminalPosition(column: 0, row: 1),
    "vertical key the inner viewport cannot use must bubble to the outer viewport"
  )
  #expect(inner.position == TerminalPosition(column: 1, row: 0))
}
@Test
func `a bounded vertical child at its lower edge bubbles to an overflowing parent`() {
  let innerID = FocusID("bounded-inner")
  let inner = ScrollModel(content: "", position: TerminalPosition(column: 0, row: 0))
  let outer = ScrollModel(content: "", position: TerminalPosition(column: 0, row: 0))
  let graph = ViewGraph(
    root: {
      ScrollView(.vertical, offset: outer.binding) {
        VStack(spacing: 0) {
          ScrollView(.vertical, offset: inner.binding) {
            SizedLeaf(
              size: TerminalSize(columns: 20, rows: 11),
              recorder: MeasurementRecorder()
            )
          }
          .focusable(whileScrollable: innerID)
          .frame(height: 5)
          Text(String(repeating: "tail\n", count: 10))
        }
      }
      .focusable(whileScrollable: FocusID("bounded-outer"))
    },
    size: TerminalSize(columns: 40, rows: 10)
  )

  graph.layoutIfNeeded()
  graph.update()
  graph.focus.focus(innerID)

  for _ in 0..<6 {
    _ = graph.dispatch(.key(Key(code: .down)))
  }
  #expect(inner.position.row == 6)
  #expect(outer.position.row == 0)

  #expect(graph.dispatch(.key(Key(code: .down))) == .handled)
  #expect(inner.position.row == 6)
  #expect(outer.position.row == 1)
}

@Test
func `focused scroll view keeps its identity as overflow changes and ignores edge keys`() {
  let id = FocusID("scroll")
  let model = ScrollModel(
    content: "AB\nCD",
    position: TerminalPosition(column: 0, row: 0)
  )
  let size = TerminalSize(columns: 6, rows: 4)
  let graph = ViewGraph(
    root: {
      ScrollView(.vertical, offset: model.binding) {
        Text(model.content)
      }
      .focusable(id)
      .focused(model.focusBinding, equals: id)
    },
    size: size
  )

  graph.layoutIfNeeded()
  #expect(graph.focus.focusableIDs == [id])
  let fittingIndicators = graph.diagnostics.nodes.filter {
    $0.viewType.hasSuffix(".ScrollIndicator")
  }
  #expect(fittingIndicators.count == 2)
  #expect(fittingIndicators[0].clip.isEmpty)
  #expect(fittingIndicators[1].clip.isEmpty)

  graph.focus.focus(id)
  let fittingBuffer = withTestFrame(size: size) { graph.render(into: $0) }
  // A fitting viewport paints no local focus treatment: focus visibility rides the
  // overflow indicators, and none are visible when everything fits.
  #expect(fittingBuffer[0, 0].content == .grapheme("A"))
  #expect(fittingBuffer[0, 0].style == Style())

  model.content = "ABCD\nEFGH\nIJKL\nMNOP\nQRST\nUVWX"
  graph.update()
  graph.layoutIfNeeded()

  #expect(graph.focus.focusableIDs == [id])
  #expect(graph.focus.focused == id)
  #expect(model.focus == id)
  let overflowingIndicators = graph.diagnostics.nodes.filter {
    $0.viewType.hasSuffix(".ScrollIndicator")
  }
  #expect(overflowingIndicators.count == 2)
  #expect(overflowingIndicators[0].clip.isEmpty == false)
  #expect(overflowingIndicators[1].clip.isEmpty)
  #expect(graph.dispatch(.key(Key(code: .up))) == .ignored)
  #expect(model.position == TerminalPosition(column: 0, row: 0))

  let overflowingBuffer = withTestFrame(size: size) { graph.render(into: $0) }
  #expect(overflowingBuffer[0, 0].content == .grapheme("A"))
  #expect(overflowingBuffer[0, size.columns - 1].content == .grapheme("┃"))

  let fittingSize = TerminalSize(columns: 6, rows: 8)
  graph.resize(to: fittingSize)
  graph.layoutIfNeeded()
  let resizedFittingBuffer = withTestFrame(size: fittingSize) { graph.render(into: $0) }
  #expect(graph.focus.focusableIDs == [id])
  #expect(graph.focus.focused == id)
  #expect(resizedFittingBuffer[0, 0].content == .grapheme("A"))
  let resizedIndicators = graph.diagnostics.nodes.filter {
    $0.viewType.hasSuffix(".ScrollIndicator")
  }
  #expect(resizedIndicators.count == 2)
  #expect(resizedIndicators[0].clip.isEmpty)
  #expect(resizedIndicators[1].clip.isEmpty)

  graph.resize(to: size)
  graph.layoutIfNeeded()
  let resizedOverflowingBuffer = withTestFrame(size: size) { graph.render(into: $0) }
  #expect(graph.focus.focusableIDs == [id])
  #expect(graph.focus.focused == id)
  #expect(resizedOverflowingBuffer[0, size.columns - 1].content == .grapheme("┃"))
}
