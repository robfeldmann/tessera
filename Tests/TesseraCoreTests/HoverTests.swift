import TesseraCore
import TesseraTerminalCore
import TesseraTerminalInput
import Testing

private final class HoverModel {
  var states: [Bool] = []
}

@Test
func `hover enters and exits only on motion transitions`() {
  let model = HoverModel()
  let graph = ViewGraph(
    root: {
      Text("hover").onHover { isHovered, _ in
        model.states.append(isHovered)
      }
    },
    size: TerminalSize(columns: 6, rows: 1)
  )

  graph.layoutIfNeeded()
  #expect(graph.terminalRequirements.wantsMouse)
  #expect(graph.terminalRequirements.wantsMouseMotion)
  #expect(
    graph.dispatch(
      PointerEvent(phase: .move, position: TerminalPosition(column: 1, row: 0)))
      == .handled)
  #expect(
    graph.dispatch(
      PointerEvent(phase: .move, position: TerminalPosition(column: 2, row: 0)))
      == .ignored)
  #expect(model.states == [true])
  #expect(
    graph.dispatch(
      PointerEvent(phase: .move, position: TerminalPosition(column: 8, row: 0)))
      == .handled)
  #expect(model.states == [true, false])
}

@Test
func `focus loss clears a hovered responder without duplicate exit`() {
  let model = HoverModel()
  let graph = ViewGraph(
    root: {
      Text("hover").onHover { isHovered, _ in
        model.states.append(isHovered)
      }
    },
    size: TerminalSize(columns: 6, rows: 1)
  )

  graph.layoutIfNeeded()
  _ = graph.dispatch(
    PointerEvent(phase: .move, position: TerminalPosition(column: 0, row: 0)))
  #expect(graph.dispatch(.focusLost) == .handled)
  #expect(graph.dispatch(.focusLost) == .handled)
  #expect(model.states == [true, false])
}
