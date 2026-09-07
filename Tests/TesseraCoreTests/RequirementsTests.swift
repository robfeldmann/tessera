import TesseraTerminalCore
import Testing

@testable import TesseraCore

private final class RequirementsBox {
  var includesHandler = true
}

private struct RequirementsFixture: View {
  let box: RequirementsBox

  var body: some View {
    if box.includesHandler {
      Text("interactive")
        .focusable(FocusID("interactive"))
        .onKey { _, _ in .ignored }
    }
    Text("static")
  }
}

@Test
func `live responder requirements aggregate and disappear with their subtree`() {
  let box = RequirementsBox()
  let graph = ViewGraph(
    root: { RequirementsFixture(box: box) },
    size: TerminalSize(columns: 20, rows: 2)
  )

  #expect(
    graph.terminalRequirements
      == TerminalRequirements(wantsKeyboardEnhancement: true)
  )

  box.includesHandler = false
  graph.update()

  #expect(graph.terminalRequirements == TerminalRequirements())
  #expect(graph.statistics.terminalRequirementChanges == 1)
}

@Test
func `terminal requirement union preserves every independent request`() {
  let keyboard = TerminalRequirements(
    wantsKeyboardEnhancement: true,
    wantsBracketedPaste: true
  )
  let pointer = TerminalRequirements(
    wantsMouse: true,
    wantsFocusReporting: true
  )

  #expect(
    TerminalRequirements.union(keyboard, pointer)
      == TerminalRequirements(
        wantsKeyboardEnhancement: true,
        wantsMouse: true,
        wantsBracketedPaste: true,
        wantsFocusReporting: true
      )
  )
}
