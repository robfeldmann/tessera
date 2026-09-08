import InlineSnapshotTesting
import TesseraCore
import TesseraTerminalBuffer
import TesseraTerminalCore
import TesseraTerminalInput
import Testing

@testable import TesseraWidgets

private final class PickerModel {
  var selection: String
  var focus: FocusID?

  init(selection: String, focus: FocusID? = nil) {
    self.selection = selection
    self.focus = focus
  }
}

private func pickerBinding(_ model: PickerModel) -> Binding<String> {
  Binding(get: { model.selection }, set: { model.selection = $0 })
}

private func pickerFocusBinding(_ model: PickerModel) -> Binding<FocusID?> {
  Binding(get: { model.focus }, set: { model.focus = $0 })
}

private func renderPicker(
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

@Test
func `picker writes its controlled selection for enabled directional cycles`() {
  let model = PickerModel(selection: "medium")
  let id = FocusID("picker")
  let graph = ViewGraph(
    root: {
      Picker(
        selection: pickerBinding(model),
        options: ["small", "medium", "large"],
      ) { Text($0) }
      .focusable(id)
      .focused(pickerFocusBinding(model), equals: id)
    },
    size: TerminalSize(columns: 20, rows: 1),
  )

  #expect(graph.focus.focusableIDs == [id])
  #expect(
    graph.terminalRequirements
      == TerminalRequirements(wantsKeyboardEnhancement: true, wantsMouse: true),
  )
  graph.focus.focus(id)
  #expect(model.focus == id)

  #expect(graph.dispatch(.key(Key(code: .right))) == .handled)
  #expect(model.selection == "large")
  #expect(graph.dispatch(.key(Key(code: .left))) == .handled)
  #expect(model.selection == "medium")
}

@Test
func `picker repairs an absent selection only on a valid directional activation`() {
  let model = PickerModel(selection: "absent")
  let id = FocusID("picker")
  let graph = ViewGraph(
    root: {
      Picker(
        selection: pickerBinding(model),
        options: ["small", "medium"],
      ) { Text($0) }
      .focusable(id)
      .focused(pickerFocusBinding(model), equals: id)
    },
    size: TerminalSize(columns: 20, rows: 1),
  )

  graph.focus.focus(id)
  #expect(graph.dispatch(.key(Key(code: .character("x")))) == .ignored)
  #expect(model.selection == "absent")
  #expect(graph.dispatch(.key(Key(code: .up))) == .handled)
  #expect(model.selection == "small")
}

@Test
func `picker bubbles at boundaries and with no options`() {
  let model = PickerModel(selection: "small")
  let id = FocusID("picker")
  let graph = ViewGraph(
    root: {
      Picker(
        selection: pickerBinding(model),
        options: ["small", "large"],
      ) { Text($0) }
      .focusable(id)
      .focused(pickerFocusBinding(model), equals: id)
    },
    size: TerminalSize(columns: 20, rows: 1),
  )

  graph.focus.focus(id)
  #expect(graph.dispatch(.key(Key(code: .left))) == .ignored)
  #expect(model.selection == "small")

  model.selection = "large"
  #expect(graph.dispatch(.key(Key(code: .right))) == .ignored)
  #expect(model.selection == "large")

  let emptyModel = PickerModel(selection: "absent")
  let emptyID = FocusID("empty-picker")
  let emptyGraph = ViewGraph(
    root: {
      Picker(
        selection: pickerBinding(emptyModel),
        options: [],
      ) { Text($0) }
      .focusable(emptyID)
      .focused(pickerFocusBinding(emptyModel), equals: emptyID)
    },
    size: TerminalSize(columns: 20, rows: 1),
  )
  emptyGraph.focus.focus(emptyID)
  #expect(emptyGraph.dispatch(.key(Key(code: .right))) == .ignored)
  #expect(emptyModel.selection == "absent")
}

@Test
func `disabled picker is not focusable and leaves its binding unchanged`() {
  let model = PickerModel(selection: "small")
  let id = FocusID("picker")
  let graph = ViewGraph(
    root: {
      Picker(
        selection: pickerBinding(model),
        options: ["small", "large"],
      ) { Text($0) }
      .focusable(id)
      .focused(pickerFocusBinding(model), equals: id)
      .disabled()
    },
    size: TerminalSize(columns: 20, rows: 1),
  )

  #expect(graph.focus.focusableIDs.isEmpty)
  graph.focus.focus(id)
  #expect(graph.dispatch(.key(Key(code: .right))) == .ignored)
  #expect(model.selection == "small")
  #expect(model.focus == nil)
}

@Test
func `picker renders selected and absent values deterministically`() {
  let model = PickerModel(selection: "medium")
  let id = FocusID("picker")
  let graph = ViewGraph(
    root: {
      Picker(
        selection: pickerBinding(model),
        options: ["small", "medium"],
      ) { Text($0) }
      .focusable(id)
      .focused(pickerFocusBinding(model), equals: id)
    },
    size: TerminalSize(columns: 10, rows: 1),
  )

  let selected = renderPicker(size: TerminalSize(columns: 10, rows: 1)) {
    graph.render(into: $0)
  }
  assertInlineSnapshot(of: selected, as: .bufferState) {
    """
    ‹   m e d i u m  {dim} ›{dim}
    """
  }

  model.selection = "absent"
  graph.update()
  let absent = renderPicker(size: TerminalSize(columns: 5, rows: 1)) {
    graph.render(into: $0)
  }
  assertInlineSnapshot(of: absent, as: .bufferState) {
    """
    ‹   —   ›
    """
  }
}

@Test
func `picker pointer cycles only from the value slot`() {
  let model = PickerModel(selection: "medium")
  let id = FocusID("pointer-picker")
  let graph = ViewGraph(
    root: {
      Picker(selection: pickerBinding(model), options: ["small", "medium", "large"]) {
        Text($0)
      }
      .focusable(id)
      .focused(pickerFocusBinding(model), equals: id)
    },
    size: TerminalSize(columns: 10, rows: 1),
  )

  #expect(
    graph.dispatch(
      .mouse(
        MouseEvent(
          kind: .press(.left), position: TerminalPosition(column: 2, row: 0),
        ),
      ),
    ) == .handled,
  )
  #expect(model.selection == "medium")
  #expect(
    graph.dispatch(
      .mouse(
        MouseEvent(
          kind: .release(.left), position: TerminalPosition(column: 2, row: 0),
        ),
      ),
    ) == .handled,
  )
  #expect(model.selection == "large")

  #expect(
    graph.dispatch(
      .mouse(
        MouseEvent(
          kind: .press(.left), position: TerminalPosition(column: 0, row: 0),
        ),
      ),
    ) == .ignored,
  )
  #expect(model.selection == "large")
}

@Test
func `picker pointer repairs absent selection only through a valid value click`() {
  let model = PickerModel(selection: "absent")
  let id = FocusID("absent-pointer-picker")
  let graph = ViewGraph(
    root: {
      Picker(selection: pickerBinding(model), options: ["small", "large"]) {
        Text($0)
      }
      .focusable(id)
      .focused(pickerFocusBinding(model), equals: id)
    },
    size: TerminalSize(columns: 9, rows: 1),
  )

  #expect(
    graph.dispatch(
      .mouse(
        MouseEvent(
          kind: .press(.left), position: TerminalPosition(column: 2, row: 0),
        ),
      ),
    ) == .handled,
  )
  #expect(
    graph.dispatch(
      .mouse(
        MouseEvent(
          kind: .release(.left), position: TerminalPosition(column: 2, row: 0),
        ),
      ),
    ) == .handled,
  )
  #expect(model.selection == "small")
}

@Test
func `picker pointer leaves endpoints and disabled controls unconsumed`() {
  let model = PickerModel(selection: "large")
  let id = FocusID("endpoint-pointer-picker")
  let graph = ViewGraph(
    root: {
      Picker(selection: pickerBinding(model), options: ["small", "large"]) {
        Text($0)
      }
      .focusable(id)
      .focused(pickerFocusBinding(model), equals: id)
    },
    size: TerminalSize(columns: 9, rows: 1),
  )

  let cancelModel = PickerModel(selection: "small")
  let cancelGraph = ViewGraph(
    root: {
      Picker(selection: pickerBinding(cancelModel), options: ["small", "large"]) {
        Text($0)
      }
      .focusable(FocusID("cancel-pointer-picker"))
      .focused(pickerFocusBinding(cancelModel), equals: FocusID("cancel-pointer-picker"))
    },
    size: TerminalSize(columns: 9, rows: 1),
  )
  #expect(
    cancelGraph.dispatch(
      .mouse(
        MouseEvent(
          kind: .press(.left), position: TerminalPosition(column: 2, row: 0),
        ),
      ),
    ) == .handled,
  )
  #expect(
    cancelGraph.dispatch(
      .mouse(
        MouseEvent(
          kind: .release(.left), position: TerminalPosition(column: 20, row: 0),
        ),
      ),
    ) == .ignored,
  )
  #expect(cancelModel.selection == "small")
}
