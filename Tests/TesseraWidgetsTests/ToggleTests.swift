import InlineSnapshotTesting
import TesseraCore
import TesseraTerminalBuffer
import TesseraTerminalCore
import TesseraTerminalInput
import TesseraTestSupport
import Testing

@testable import TesseraWidgets

private func withToggleTestFrame(
  size: TerminalSize,
  _ body: (borrowing Frame) -> Void,
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

private final class ToggleModel {
  var bubbles = 0
  var focused: FocusID?
  var isOn = false
  var writes = 0

  var focusBinding: Binding<FocusID?> {
    Binding(get: { self.focused }, set: { self.focused = $0 })
  }

  var isOnBinding: Binding<Bool> {
    Binding(
      get: { self.isOn },
      set: {
        self.writes += 1
        self.isOn = $0
      },
    )
  }
}

private struct DisabledToggleBubbleHost: View {
  let model: ToggleModel
  let parentFocus: FocusID

  var body: some View {
    Toggle(isOn: model.isOnBinding) {
      Text("Receive mail")
    }
    .disabled()
    .onKey { _, _ in
      model.bubbles += 1
      return .handled
    }
    .focusable(parentFocus)
    .focused(model.focusBinding, equals: parentFocus)
  }
}

@Test
func
  `toggle registers focus synchronizes binding and writes once for phased and legacy keys`()
{
  let model = ToggleModel()
  let focus = FocusID("toggle")
  let graph = ViewGraph(
    root: {
      Toggle(isOn: model.isOnBinding) {
        Text("Receive mail")
      }
      .focusable(focus)
      .focused(model.focusBinding, equals: focus)
    },
    size: TerminalSize(columns: 20, rows: 1),
  )

  #expect(graph.focus.focusableIDs == [focus])
  graph.focus.focus(focus)
  #expect(model.focused == focus)

  #expect(graph.dispatch(.key(Key(code: .enter, kind: .press))) == .handled)
  #expect(model.isOn)
  #expect(model.writes == 1)
  // Legacy input has no pending release; the release bubbles after the immediate action.
  #expect(graph.dispatch(.key(Key(code: .enter, kind: .release))) == .ignored)
  #expect(model.isOn)
  #expect(model.writes == 1)

  // A legacy terminal supplies only the press, which remains an activation.
  #expect(graph.dispatch(.key(Key(code: .character(" "), kind: .press))) == .handled)
  #expect(model.isOn == false)
  #expect(model.writes == 2)
}

@Test
func `disabled toggle omits focus and bubbles input without binding mutation`() {
  let model = ToggleModel()
  let parentFocus = FocusID("parent")
  let graph = ViewGraph(
    root: { DisabledToggleBubbleHost(model: model, parentFocus: parentFocus) },
    size: TerminalSize(columns: 20, rows: 1),
  )

  #expect(graph.focus.focusableIDs == [parentFocus])
  graph.focus.focus(parentFocus)
  #expect(graph.dispatch(.key(Key(code: .character(" ")))) == .handled)
  #expect(model.bubbles == 1)
  #expect(model.isOn == false)
  #expect(model.writes == 0)
  #expect(model.focused == parentFocus)
}

@Test
func `toggle renders checkbox marker and label deterministically`() {
  let model = ToggleModel()
  let size = TerminalSize(columns: 8, rows: 1)
  let graph = ViewGraph(
    root: {
      Toggle(isOn: model.isOnBinding) {
        Text("Mail")
      }
      .focusable(FocusID("render-toggle"))
      .focused(model.focusBinding, equals: FocusID("render-toggle"))
    },
    size: size,
  )

  let first = withToggleTestFrame(size: size) { graph.render(into: $0) }
  let second = withToggleTestFrame(size: size) { graph.render(into: $0) }

  #expect(first == second)
  assertInlineSnapshot(of: first, as: .bufferState) {
    """
    [{dim}  {dim} ]{dim}   M a i l
    """
  }
}

@Test
func `string label convenience renders a toggle`() {
  let model = ToggleModel()
  let size = TerminalSize(columns: 8, rows: 1)
  let graph = ViewGraph(
    root: {
      Toggle("Mail", isOn: model.isOnBinding)
        .focusable(FocusID("string-label-toggle"))
        .focused(model.focusBinding, equals: FocusID("string-label-toggle"))
    },
    size: size,
  )

  let buffer = withToggleTestFrame(size: size) { graph.render(into: $0) }
  assertInlineSnapshot(of: buffer, as: .bufferState) {
    """
    [{dim}  {dim} ]{dim}   M a i l
    """
  }
}

@Test
func `toggle pointer activates through Button capture and cancels outside release`() {
  let model = ToggleModel()
  let id = FocusID("pointer-toggle")
  let graph = ViewGraph(
    root: {
      Toggle("Mail", isOn: model.isOnBinding)
        .focusable(id)
        .focused(model.focusBinding, equals: id)
    },
    size: TerminalSize(columns: 8, rows: 1),
  )

  #expect(
    graph.dispatch(
      .mouse(
        MouseEvent(
          kind: .press(.left), position: TerminalPosition(column: 0, row: 0),
        ),
      ),
    ) == .handled,
  )
  #expect(model.isOn == false)
  #expect(model.writes == 0)
  #expect(
    graph.dispatch(
      .mouse(
        MouseEvent(
          kind: .release(.left), position: TerminalPosition(column: 0, row: 0),
        ),
      ),
    ) == .handled,
  )
  #expect(model.isOn)
  #expect(model.writes == 1)

  #expect(
    graph.dispatch(
      .mouse(
        MouseEvent(
          kind: .press(.left), position: TerminalPosition(column: 0, row: 0),
        ),
      ),
    ) == .handled,
  )
  #expect(
    graph.dispatch(
      .mouse(
        MouseEvent(
          kind: .release(.left), position: TerminalPosition(column: 8, row: 0),
        ),
      ),
    ) == .ignored,
  )
  #expect(model.isOn)
  #expect(model.writes == 1)
}

@Test
func `toggle external binding replacement is rendered without reconciliation write`() {
  let model = ToggleModel()
  let graph = ViewGraph(
    root: { Toggle("Mail", isOn: model.isOnBinding) },
    size: TerminalSize(columns: 8, rows: 1),
  )

  #expect(model.writes == 0)
  model.isOn = true
  graph.update()
  #expect(model.writes == 0)
  let buffer = withToggleTestFrame(size: TerminalSize(columns: 8, rows: 1)) {
    graph.render(into: $0)
  }
  #expect(buffer[0, 1].content == .grapheme("x"))
}
