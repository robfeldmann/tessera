import TesseraCore
import TesseraLayout
import TesseraTerminalCore
import TesseraTerminalInput
import TesseraWidgets
import Testing

private final class ViewportInteractionModel {
  var offset = TerminalPosition(column: 0, row: 0)

  var binding: Binding<TerminalPosition> {
    Binding(get: { self.offset }, set: { self.offset = $0 })
  }
}

@Test
func `wheel consumes local scroll and ignores at boundary`() {
  let model = ViewportInteractionModel()
  let graph = ViewGraph(
    root: {
      ScrollView(.vertical, offset: model.binding) {
        Text("A\nB\nC\nD\nE")
      }
    },
    size: TerminalSize(columns: 4, rows: 2)
  )
  graph.layoutIfNeeded()

  #expect(
    graph.dispatch(
      PointerEvent(phase: .scrollDown, position: TerminalPosition(column: 0, row: 0)))
      == .handled)
  #expect(model.offset.row == 1)
  _ = graph.dispatch(
    PointerEvent(phase: .scrollDown, position: TerminalPosition(column: 0, row: 0)))
  _ = graph.dispatch(
    PointerEvent(phase: .scrollDown, position: TerminalPosition(column: 0, row: 0)))
  #expect(model.offset.row == 3)
  #expect(
    graph.dispatch(
      PointerEvent(phase: .scrollDown, position: TerminalPosition(column: 0, row: 0)))
      == .ignored)
}

@Test
func `vertical indicator thumb drag reaches clamped end`() {
  let model = ViewportInteractionModel()
  let graph = ViewGraph(
    root: {
      ScrollView(.vertical, offset: model.binding) {
        Text("A\nB\nC\nD\nE")
      }
    },
    size: TerminalSize(columns: 4, rows: 2)
  )
  graph.layoutIfNeeded()

  #expect(
    graph.dispatch(
      PointerEvent(
        phase: .down, button: .left, position: TerminalPosition(column: 3, row: 0)))
      == .handled)
  #expect(
    graph.dispatch(
      PointerEvent(
        phase: .move, button: .left, position: TerminalPosition(column: 3, row: 1)))
      == .handled)
  #expect(model.offset.row == 3)
  #expect(
    graph.dispatch(
      PointerEvent(
        phase: .up, button: .left, position: TerminalPosition(column: 3, row: 1)))
      == .handled)
}

@Test
func `focused descendant is revealed by the shared graph driver policy`() {
  let model = ViewportInteractionModel()
  let id = FocusID("last")
  let graph = ViewGraph(
    root: {
      ScrollView(.vertical, offset: model.binding) {
        Text("A\nB\nC\nD").focusable(id)
      }
    },
    size: TerminalSize(columns: 4, rows: 2)
  )
  graph.layoutIfNeeded()
  graph.focus.focus(id)

  #expect(graph.revealFocusedContent())
  #expect(model.offset.row == 2)
}
