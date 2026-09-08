import InlineSnapshotTesting
import TesseraCore
import TesseraLayout
import TesseraTerminalBuffer
import TesseraTerminalCore
import TesseraTerminalInput
import TesseraTestSupport
import Testing

@testable import TesseraWidgets

private func withButtonTestFrame(
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

private final class ButtonModel {
  var actionCount = 0
  var bubbles = 0
  var focused: FocusID?

  var focusBinding: Binding<FocusID?> {
    Binding(get: { self.focused }, set: { self.focused = $0 })
  }
}

private struct DisabledButtonBubbleHost: View {
  let model: ButtonModel
  let parentFocus: FocusID

  var body: some View {
    Button(
      action: { model.actionCount += 1 },
      label: {
        Text("Delete")
      }
    )
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
  `button composes focus, synchronizes binding, and activates once for phased and legacy keys`()
{
  let model = ButtonModel()
  let focus = FocusID("button")
  let graph = ViewGraph(
    root: {
      Button(
        action: { model.actionCount += 1 },
        label: {
          Text("Save")
        }
      )
      .focusable(focus)
      .focused(model.focusBinding, equals: focus)
    },
    size: TerminalSize(columns: 12, rows: 1)
  )

  #expect(graph.focus.focusableIDs == [focus])
  graph.focus.focus(focus)
  #expect(model.focused == focus)

  #expect(
    graph.dispatch(.key(Key(code: .enter, kind: .press, source: .kitty))) == .handled)
  #expect(model.actionCount == 0)
  #expect(
    graph.dispatch(.key(Key(code: .enter, kind: .release, source: .kitty))) == .handled)
  #expect(model.actionCount == 1)

  // A legacy terminal supplies only the press, which remains an activation.
  #expect(graph.dispatch(.key(Key(code: .character(" "), kind: .press))) == .handled)
  #expect(model.actionCount == 2)
}

@Test
func `string button convenience renders and activates`() {
  let model = ButtonModel()
  let focus = FocusID("string-button")
  let size = TerminalSize(columns: 8, rows: 1)
  let graph = ViewGraph(
    root: {
      Button("Save") { model.actionCount += 1 }
        .focusable(focus)
        .focused(model.focusBinding, equals: focus)
    },
    size: size
  )

  let buffer = withButtonTestFrame(size: size) { graph.render(into: $0) }
  assertInlineSnapshot(of: buffer, as: .bufferState) {
    """
    [{dim} S a v e ]{dim} · ·
    """
  }

  graph.focus.focus(focus)
  #expect(graph.dispatch(.key(Key(code: .enter, kind: .press))) == .handled)
  #expect(model.actionCount == 1)
}

@Test
func `disabled button omits focus and bubbles input without action mutation`() {
  let model = ButtonModel()
  let parentFocus = FocusID("parent")
  let graph = ViewGraph(
    root: { DisabledButtonBubbleHost(model: model, parentFocus: parentFocus) },
    size: TerminalSize(columns: 12, rows: 1)
  )

  #expect(graph.focus.focusableIDs == [parentFocus])
  graph.focus.focus(parentFocus)
  #expect(graph.dispatch(.key(Key(code: .enter))) == .handled)
  #expect(model.bubbles == 1)
  #expect(model.actionCount == 0)
  #expect(model.focused == parentFocus)
}

@Test
func `button renders compact label deterministically`() {
  let model = ButtonModel()
  let size = TerminalSize(columns: 8, rows: 1)
  let graph = ViewGraph(
    root: {
      Button(
        action: {},
        label: {
          Text("Save")
        }
      )
      .focusable(FocusID("render-button"))
      .focused(model.focusBinding, equals: FocusID("render-button"))
    },
    size: size
  )

  let first = withButtonTestFrame(size: size) { graph.render(into: $0) }
  let second = withButtonTestFrame(size: size) { graph.render(into: $0) }

  #expect(first == second)
  graph.focus.focus(FocusID("render-button"))
  let focused = withButtonTestFrame(size: size) { graph.render(into: $0) }
  #expect(focused != first)
  let focusStyle = EnvironmentValues().semanticStyles.focus
  #expect(focused[0, 0].style.foreground == focusStyle.foreground)
  #expect(focused[0, 0].style.background == focusStyle.background)
  #expect(focused[0, 0].style.attributes == focusStyle.attributes)
  #expect(focused[0, 0].style.underlineStyle == .none)
  assertInlineSnapshot(of: first, as: .bufferState) {
    """
    [{dim} S a v e ]{dim} · ·
    """
  }
}

@Test
func `plain button renders an unadorned focusable label`() {
  let model = ButtonModel()
  let size = TerminalSize(columns: 4, rows: 1)
  let graph = ViewGraph(
    root: {
      Button(
        action: {},
        label: { Text("Go") }
      )
      .buttonStyle(.plain)
      .focusable(FocusID("plain"))
      .focused(model.focusBinding, equals: FocusID("plain"))
    },
    size: size
  )

  let buffer = withButtonTestFrame(size: size) { graph.render(into: $0) }
  assertInlineSnapshot(of: buffer, as: .bufferState) {
    """
    G o · ·
    """
  }
}

@Test
func `focused destructive button uses focus role without destructive underline`() {
  let model = ButtonModel()
  let focus = FocusID("destructive")
  let size = TerminalSize(columns: 10, rows: 1)
  let graph = ViewGraph(
    root: {
      Button(
        role: .destructive,
        action: {},
        label: { Text("Delete") }
      )
      .focusable(focus)
      .focused(model.focusBinding, equals: focus)
    },
    size: size
  )
  graph.focus.focus(focus)

  let buffer = withButtonTestFrame(size: size) { graph.render(into: $0) }
  let focusStyle = EnvironmentValues().semanticStyles.focus
  #expect(buffer[0, 0].style.foreground == focusStyle.foreground)
  #expect(buffer[0, 0].style.background == focusStyle.background)
  #expect(buffer[0, 0].style.attributes == focusStyle.attributes)
  #expect(buffer[0, 0].style.underlineStyle == .none)
}
