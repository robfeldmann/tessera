import InlineSnapshotTesting
import TesseraTerminalCore
import TesseraTestSupport
import Testing

@testable import TesseraCore

private struct MinimalLeaf: LeafView {
  func sizeThatFits(
    _ proposal: ProposedSize,
    state: inout Void,
    environment: EnvironmentValues
  ) -> TerminalSize {
    TerminalSize(columns: 1, rows: 1)
  }

  func render(
    in region: inout RenderRegion,
    state: inout Void,
    environment: EnvironmentValues
  ) {}
}

private struct BuilderFixture: View {
  let includesOptional: Bool

  var body: some View {
    Text("first")
    if includesOptional {
      MinimalLeaf()
    }
    if includesOptional {
      EmptyView()
    } else {
      Text("fallback")
    }
    ForEach([1, 2], id: \.self) { value in
      Text("\(value)")
    }
  }
}

private final class BindingBox {
  var value = 1
}

@Test
func `render only leaf uses documented defaults`() {
  let leaf = MinimalLeaf()
  var state: Void = ()
  var context = ResponderContext()

  let size = leaf.sizeThatFits(
    .unspecified,
    state: &state,
    environment: EnvironmentValues()
  )
  let disposition = leaf.handleEvent(
    .resize(TerminalSize(columns: 1, rows: 1)),
    state: &state,
    context: &context
  )
  #expect(size == TerminalSize(columns: 1, rows: 1))
  #expect(disposition == .ignored)
}

@Test
func `builder supports tuples conditionals optionals and keyed collections`() {
  let graph = ViewGraph(
    root: { BuilderFixture(includesOptional: true) },
    size: TerminalSize(columns: 20, rows: 5)
  )

  assertInlineSnapshot(of: graph, as: .viewGraph) {
    """
    root BuilderFixture [needsLayout, needsRender]
      body TupleView [needsLayout, needsRender]
        index(0) Text [needsLayout, needsRender]
        index(1) Optional [needsLayout, needsRender]
          index(0) TupleView [needsLayout, needsRender]
            index(0) MinimalLeaf [needsLayout, needsRender]
        index(2) ConditionalView [needsLayout, needsRender]
          branch(true) TupleView [needsLayout, needsRender]
            index(0) EmptyView [needsLayout, needsRender]
        index(3) ForEach [needsLayout, needsRender]
          id(1) TupleView [needsLayout, needsRender]
            index(0) Text [needsLayout, needsRender]
          id(2) TupleView [needsLayout, needsRender]
            index(0) Text [needsLayout, needsRender]
    statistics: created=14 destroyed=0 updated=0 bodies=1 equatableSkips=0 leaves=0 measurements=0 placements=0 renders=0 reasons=[]
    requirements: requested=[] effective=unavailable
    """
  }
}

@Test
func `binding forwards reads writes and constant values`() {
  let box = BindingBox()
  let binding = Binding(get: { box.value }, set: { box.value = $0 })

  let initial = binding.wrappedValue
  binding.wrappedValue = 2
  #expect(initial == 1)
  #expect(box.value == 2)
  #expect(binding.projectedValue.wrappedValue == 2)
  #expect(Binding.constant(7).wrappedValue == 7)
}

@Test(
  arguments: [
    ("", TerminalSize(columns: 0, rows: 1)),
    ("abc", TerminalSize(columns: 3, rows: 1)),
    ("A界", TerminalSize(columns: 3, rows: 1)),
    ("a\r\nbb\n", TerminalSize(columns: 2, rows: 3)),
  ]
)
func `text measures source rows in terminal cells`(
  content: String,
  expected: TerminalSize
) {
  var state: Void = ()
  let measured = Text(content).sizeThatFits(
    ProposedSize(width: 1, height: 1),
    state: &state,
    environment: EnvironmentValues()
  )

  #expect(measured == expected)
}
