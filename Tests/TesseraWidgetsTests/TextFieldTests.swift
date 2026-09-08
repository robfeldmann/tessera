import TesseraCore
import TesseraLayout
import TesseraTerminalBuffer
import TesseraTerminalCore
import TesseraTerminalInput
import Testing

@testable import TesseraWidgets

private func renderTextField(
  _ graph: ViewGraph,
  size: TerminalSize
) -> (Buffer, TerminalPosition?) {
  var buffer = Buffer(size: size)
  var cursorPosition: TerminalPosition?
  withUnsafeMutablePointer(to: &buffer) { bufferStorage in
    withUnsafeMutablePointer(to: &cursorPosition) { cursorStorage in
      graph.render(into: Frame(buffer: bufferStorage, cursorPosition: cursorStorage))
    }
  }
  return (buffer, cursorPosition)
}

private final class TextFieldModel {
  var text: String
  var focused: FocusID?
  var submissions: [String] = []
  var bubbled = 0

  var textBinding: Binding<String> {
    Binding(get: { self.text }, set: { self.text = $0 })
  }

  var focusBinding: Binding<FocusID?> {
    Binding(get: { self.focused }, set: { self.focused = $0 })
  }
  init(text: String = "") {
    self.text = text
  }
}

private func fieldGraph(
  model: TextFieldModel,
  focus: FocusID = FocusID("field"),
  size: TerminalSize = TerminalSize(columns: 24, rows: 4),
  onSubmit: Bool = true
) -> ViewGraph {
  if onSubmit {
    return ViewGraph(
      root: {
        TextField(
          "Name",
          text: model.textBinding,
          prompt: Text("Required")
        ) { model.submissions.append($0) }
        .focusable(focus)
        .focused(model.focusBinding, equals: focus)
      },
      size: size
    )
  }
  return ViewGraph(
    root: {
      TextField("Name", text: model.textBinding)
        .onKey { key, _ in
          guard key.code == .enter else {
            return .ignored
          }
          model.bubbled += 1
          return .handled
        }
        .focusable(focus)
        .focused(model.focusBinding, equals: focus)
    },
    size: size
  )
}

private func focus(_ graph: ViewGraph, _ id: FocusID = FocusID("field")) {
  graph.focus.focus(id)
}

@Test
func `text field writes printable edits and deletes whole graphemes`() {
  let model = TextFieldModel()
  let graph = fieldGraph(model: model)
  focus(graph)
  #expect(
    graph.dispatch(
      .key(Key(code: .character("a"), modifiers: [.control], source: .kitty))
    ) == .ignored)
  #expect(model.text.isEmpty)
  #expect(
    graph.dispatch(
      .key(
        Key(
          code: .character("A"), modifiers: [.shift, .capsLock, .numLock], source: .kitty))
    ) == .handled)
  #expect(model.text == "A")

  #expect(graph.dispatch(.key(Key(code: .character("a")))) == .handled)
  #expect(graph.dispatch(.key(Key(code: .character("界")))) == .handled)
  #expect(graph.dispatch(.key(Key(code: .character("e")))) == .handled)
  #expect(model.text == "Aa界e")

  #expect(graph.dispatch(.key(Key(code: .left))) == .handled)
  #expect(graph.dispatch(.key(Key(code: .backspace))) == .handled)
  #expect(model.text == "Aae")
}

@Test
func `text field replaces selected graphemes and normalizes committed paste`() {
  let model = TextFieldModel(text: "abc")
  let graph = fieldGraph(model: model)
  focus(graph)

  #expect(graph.dispatch(.key(Key(code: .home))) == .handled)
  #expect(
    graph.dispatch(.key(Key(code: .right, modifiers: [.shift]))) == .handled)
  #expect(graph.dispatch(.key(Key(code: .character("X")))) == .handled)
  #expect(model.text == "Xbc")

  #expect(graph.dispatch(.paste("one\r\ntwo\nthree")) == .handled)
  #expect(model.text == "Xone two threebc")
}

@Test
func `text field supports word movement selection and deletion`() {
  let model = TextFieldModel(text: "one two three")
  let graph = fieldGraph(model: model)
  focus(graph)

  #expect(graph.dispatch(.key(Key(code: .end))) == .handled)
  #expect(
    graph.dispatch(.key(Key(code: .left, modifiers: [.alt], source: .kitty))) == .handled)
  #expect(
    graph.dispatch(.key(Key(code: .backspace, modifiers: [.alt], source: .kitty)))
      == .handled)
  #expect(model.text == "one three")

  #expect(graph.dispatch(.key(Key(code: .home))) == .handled)
  #expect(
    graph.dispatch(.key(Key(code: .right, modifiers: [.shift, .alt], source: .kitty)))
      == .handled)
  #expect(graph.dispatch(.key(Key(code: .delete))) == .handled)
  #expect(model.text == " three")
}

@Test
func `text field submit bubbles when no handler and invokes app closure otherwise`() {
  let submittedModel = TextFieldModel(text: "ready")
  let submittedGraph = fieldGraph(model: submittedModel)
  focus(submittedGraph)
  #expect(submittedGraph.dispatch(.key(Key(code: .enter))) == .handled)
  #expect(submittedModel.submissions == ["ready"])
  #expect(submittedModel.text == "ready")

  let bubblingModel = TextFieldModel(text: "ready")
  let bubblingGraph = fieldGraph(model: bubblingModel, onSubmit: false)
  focus(bubblingGraph)
  #expect(bubblingGraph.dispatch(.key(Key(code: .enter))) == .handled)
  #expect(bubblingModel.submissions.isEmpty)
  #expect(bubblingModel.bubbled == 1)
}

@Test
func
  `text field clamps external replacement, intrinsic sizing, and requests hardware cursor`()
{
  let model = TextFieldModel(text: "abcdef")
  let graph = fieldGraph(model: model, size: TerminalSize(columns: 80, rows: 24))
  focus(graph)
  #expect(graph.dispatch(.key(Key(code: .end))) == .handled)

  model.text = "x"
  let (buffer, cursor) = renderTextField(graph, size: TerminalSize(columns: 80, rows: 24))
  #expect(buffer[0, 0].content == .grapheme("N"))
  #expect(buffer[1, 0].content == .grapheme("╭"))
  #expect(cursor != nil)
  #expect(cursor?.row == 2)
  #expect(cursor?.column == 2)
}

@Test
func `disabled text field leaves binding and pointer routing untouched`() {
  let model = TextFieldModel()
  let id = FocusID("disabled-field")
  let graph = ViewGraph(
    root: {
      TextField("Disabled", text: model.textBinding)
        .focusable(id)
        .disabled()
        .focused(model.focusBinding, equals: id)
    },
    size: TerminalSize(columns: 18, rows: 4)
  )

  #expect(graph.focus.focusableIDs.isEmpty)
  #expect(graph.dispatch(.key(Key(code: .character("x")))) == .ignored)
  #expect(model.text.isEmpty)
  #expect(
    graph.dispatch(
      PointerEvent(
        phase: .down,
        button: .left,
        position: TerminalPosition(column: 3, row: 2)
      )
    ) == .ignored)
  #expect(model.text.isEmpty)
}

@Test
func `text field click maps to a grapheme boundary and focuses the field`() {
  let model = TextFieldModel(text: "abc")
  let id = FocusID("clicked-field")
  let graph = ViewGraph(
    root: {
      TextField("Name", text: model.textBinding)
        .focusable(id)
        .focused(model.focusBinding, equals: id)
    },
    size: TerminalSize(columns: 14, rows: 4)
  )

  let click = TerminalPosition(column: 4, row: 2)
  #expect(
    graph.dispatch(PointerEvent(phase: .down, button: .left, position: click)) == .handled)
  #expect(
    graph.dispatch(PointerEvent(phase: .up, button: .left, position: click)) == .handled)
  #expect(model.focused == id)

  let (_, cursor) = renderTextField(graph, size: TerminalSize(columns: 14, rows: 4))
  #expect(cursor?.column == 4)
  #expect(cursor?.row == 2)
}
