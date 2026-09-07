import InlineSnapshotTesting
import TesseraTerminalBuffer
import TesseraTerminalCore
import TesseraTerminalInput
import Testing

@testable import TesseraCore

private final class FocusBox {
  var focused: FocusID?
  var includesPrimary = true
  var trace: [String] = []
}

private struct RecordingLeaf: LeafView {
  let name: String
  let disposition: EventDisposition
  let box: FocusBox

  func sizeThatFits(
    _ proposal: ProposedSize,
    state: inout Void,
    environment: EnvironmentValues
  ) -> TerminalSize {
    TerminalSize(columns: 3, rows: 1)
  }

  func render(
    in region: inout RenderRegion,
    state: inout Void,
    environment: EnvironmentValues
  ) {}

  func handleEvent(
    _ event: InputEvent,
    state: inout Void,
    context: inout ResponderContext
  ) -> EventDisposition {
    box.trace.append(
      "\(name):focused=\(context.isFocused):bounds=\(context.nodeBounds.size.columns)x\(context.nodeBounds.size.rows)"
    )
    return disposition
  }
}

private struct FocusFixture: View {
  let box: FocusBox
  let primary = FocusID("primary")
  let secondary = FocusID("secondary")

  var body: some View {
    if box.includesPrimary {
      RecordingLeaf(name: "leaf", disposition: .ignored, box: box)
        .focusable(primary)
        .focused(
          Binding(get: { box.focused }, set: { box.focused = $0 }),
          equals: primary
        )
        .onKey { _, _ in
          box.trace.append("inner")
          return .ignored
        }
        .onKey { _, _ in
          box.trace.append("outer")
          return .handled
        }
    }
    RecordingLeaf(name: "secondary", disposition: .ignored, box: box)
      .focusable(secondary)
      .focused(
        Binding(get: { box.focused }, set: { box.focused = $0 }),
        equals: secondary

      )
  }
}

private struct TabFixture: View {
  let box: FocusBox
  let ids = [FocusID("first"), FocusID("second")]

  var body: some View {
    ForEach(ids, id: \.self) { id in
      RecordingLeaf(name: "tab", disposition: .ignored, box: box)
        .focusable(id)
        .focused(
          Binding(get: { box.focused }, set: { box.focused = $0 }),
          equals: id
        )
    }
    .onKey(.tab) { context in
      context.focusAdvance(.forward)
    }
    .onKey(.shift(.tab)) { context in
      context.focusAdvance(.backward)
    }
  }
}

private final class FocusEnvironmentModel {
  var focused: FocusID?
  var id = FocusID("primary")
  var isVisible = true
  var isDisabled = false
}

private struct FocusEnvironmentLeaf: LeafView {
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
  ) {
    region.write(
      environment.isFocused ? "F" : "U", at: TerminalPosition(column: 0, row: 0))
  }
}

private struct FocusEnvironmentFixture: View {
  let model: FocusEnvironmentModel

  var body: some View {
    if model.isVisible {
      FocusEnvironmentLeaf()
        .focusable(model.id)
        .focused(
          Binding(get: { model.focused }, set: { model.focused = $0 }),
          equals: model.id
        )
        .focusAppearance(.none)
        .disabled(model.isDisabled)
    }
  }
}

@Test
func `focused environment follows focus replacement and removal`() {
  let model = FocusEnvironmentModel()
  let graph = ViewGraph(
    root: { FocusEnvironmentFixture(model: model) },
    size: TerminalSize(columns: 1, rows: 1)
  )

  graph.focus.focus(model.id)
  let focused = withTestFrame(size: TerminalSize(columns: 1, rows: 1)) {
    graph.render(into: $0)
  }.buffer
  #expect(focused[0, 0].content == .grapheme("F"))

  model.id = FocusID("replacement")
  graph.update()
  let replaced = withTestFrame(size: TerminalSize(columns: 1, rows: 1)) {
    graph.render(into: $0)
  }.buffer
  #expect(graph.focus.focused == nil)
  #expect(replaced[0, 0].content == .grapheme("U"))

  graph.focus.focus(model.id)
  let refocused = withTestFrame(size: TerminalSize(columns: 1, rows: 1)) {
    graph.render(into: $0)
  }.buffer
  #expect(refocused[0, 0].content == .grapheme("F"))

  model.isVisible = false
  graph.update()
  #expect(graph.focus.focused == nil)
}

@Test
func `focused environment refreshes when its focusable view becomes disabled`() {
  let model = FocusEnvironmentModel()
  let graph = ViewGraph(
    root: { FocusEnvironmentFixture(model: model) },
    size: TerminalSize(columns: 1, rows: 1)
  )

  graph.focus.focus(model.id)
  let focused = withTestFrame(size: TerminalSize(columns: 1, rows: 1)) {
    graph.render(into: $0)
  }.buffer
  #expect(focused[0, 0].content == .grapheme("F"))

  model.isDisabled = true
  graph.update()
  #expect(graph.focus.focused == nil)
  #expect(model.focused == nil)

  let disabled = withTestFrame(size: TerminalSize(columns: 1, rows: 1)) {
    graph.render(into: $0)
  }.buffer
  #expect(disabled[0, 0].content == .grapheme("U"))
}

@Test
func `focus advances in document order wraps and synchronizes its binding`() {
  let box = FocusBox()
  let graph = ViewGraph(
    root: { FocusFixture(box: box) },
    size: TerminalSize(columns: 20, rows: 4)
  )
  let primary = FocusID("primary")
  let secondary = FocusID("secondary")

  #expect(graph.focus.focusableIDs == [primary, secondary])
  graph.focus.advance(.forward)
  #expect(graph.focus.focused == primary)
  #expect(box.focused == primary)
  graph.focus.advance(.forward)
  #expect(graph.focus.focused == secondary)
  #expect(box.focused == secondary)
  graph.focus.advance(.forward)
  #expect(graph.focus.focused == primary)
  graph.focus.advance(.backward)
  #expect(graph.focus.focused == secondary)
}

@Test
func `focused routing visits leaf then wrappers and stops when handled`() {
  let box = FocusBox()
  box.focused = FocusID("primary")
  let graph = ViewGraph(
    root: { FocusFixture(box: box) },
    size: TerminalSize(columns: 20, rows: 4)
  )

  let disposition = graph.dispatch(.key(Key(code: .character("x"))))

  #expect(disposition == .handled)
  assertInlineSnapshot(of: box.trace.joined(separator: "\n"), as: .lines) {
    """
    leaf:focused=true:bounds=3x1
    inner
    outer
    """
  }
}

@Test
func `removed focused node clears focus without choosing a neighbor`() {
  let box = FocusBox()
  box.focused = FocusID("primary")
  let graph = ViewGraph(
    root: { FocusFixture(box: box) },
    size: TerminalSize(columns: 20, rows: 4)
  )

  box.includesPrimary = false
  graph.update()

  #expect(graph.focus.focused == nil)
  #expect(box.focused == nil)
  #expect(graph.focus.focusableIDs == [FocusID("secondary")])
  #expect(graph.statistics.focusChanges == 1)
}

@Test
func `unfocused and non responder events remain unhandled`() {
  let graph = ViewGraph(
    root: { Text("plain") },
    size: TerminalSize(columns: 20, rows: 4)
  )

  #expect(graph.dispatch(.key(Key(code: .enter))) == .ignored)
  #expect(graph.dispatch(.resize(TerminalSize(columns: 10, rows: 2))) == .ignored)
}

@Test
func `tab traversal occurs only through installed key handlers`() {
  let box = FocusBox()
  let graph = ViewGraph(
    root: { TabFixture(box: box) },
    size: TerminalSize(columns: 20, rows: 4)
  )
  graph.focus.focus(FocusID("first"))

  #expect(graph.dispatch(.key(Key(code: .tab))) == .handled)
  #expect(graph.focus.focused == FocusID("second"))
  #expect(
    graph.dispatch(.key(Key(code: .tab, modifiers: .shift))) == .handled
  )
  #expect(graph.focus.focused == FocusID("first"))
}

private struct NestedFocusFixture: View {
  let box: FocusBox
  let container = FocusID("container")
  let inner = FocusID("inner")

  var body: some View {
    // The inner leaf is independently focusable and would consume the event if routing
    // ever descended into it while the container owns focus.
    RecordingLeaf(name: "inner", disposition: .handled, box: box)
      .focusable(inner)
      .focused(Binding(get: { box.focused }, set: { box.focused = $0 }), equals: inner)
      .focusable(container)
      .focused(Binding(get: { box.focused }, set: { box.focused = $0 }), equals: container)
      .onKey { _, _ in
        box.trace.append("container")
        return .handled
      }
  }
}

@Test
func `a focused container does not route keys into a nested focusable control`() {
  let box = FocusBox()
  box.focused = FocusID("container")
  let graph = ViewGraph(
    root: { NestedFocusFixture(box: box) },
    size: TerminalSize(columns: 20, rows: 4)
  )

  #expect(graph.focus.focusableIDs == [FocusID("container"), FocusID("inner")])
  let disposition = graph.dispatch(.key(Key(code: .character("x"))))

  #expect(disposition == .handled)
  // The container's own key handler runs; the nested leaf never sees the event.
  #expect(box.trace == ["container"])
}
