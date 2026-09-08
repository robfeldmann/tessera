import TesseraCore
import TesseraLayout
import TesseraTerminalBuffer
import TesseraTerminalCore
import TesseraTerminalInput
import Testing

@testable import TesseraWidgets

private final class PointerModel {
  var actionCount = 0
  var isZero: Bool { actionCount < 1 }
  var focus: FocusID?
  var ancestorPhases: [PointerPhase] = []
}

private struct PressProbeStyle: ButtonStyle {
  func makeBody(configuration: ButtonStyleConfiguration) -> some View {
    Text(configuration.isPressed ? "P" : "I")
  }
}
private struct ReplacementRoot: View {
  let showOriginal: Bool
  let model: PointerModel

  @ViewBuilder
  var body: some View {
    if showOriginal {
      Button("Old") { model.actionCount += 1 }
    } else {
      HStack { Button("New") { model.actionCount += 10 } }
    }
  }
}

private func render(_ graph: ViewGraph, size: TerminalSize) -> Buffer {
  var buffer = Buffer(size: size)
  var cursor: TerminalPosition?
  withUnsafeMutablePointer(to: &buffer) { bufferPointer in
    withUnsafeMutablePointer(to: &cursor) { cursorPointer in
      graph.render(into: Frame(buffer: bufferPointer, cursorPosition: cursorPointer))
    }
  }
  return buffer
}

@Test
func `button pointer press projects state and activates once on matching release`() {
  let model = PointerModel()
  let focus = FocusID("pointer-button")
  let graph = ViewGraph(
    root: {
      Button("Go") { model.actionCount += 1 }
        .buttonStyle(PressProbeStyle())
        .focusable(focus)
        .automationID("go", role: .button)
    }, size: TerminalSize(columns: 4, rows: 1))

  #expect(
    graph.dispatch(
      .mouse(
        MouseEvent(
          kind: .press(.left), position: TerminalPosition(column: 0, row: 0)
        ))) == .handled)
  let pressed = try? graph.automationSnapshot.resolve("go")
  #expect(pressed?.isPressed == true)
  #expect(pressed?.isPointerCaptured == true)
  #expect(
    render(graph, size: TerminalSize(columns: 4, rows: 1))[0, 0].content == .grapheme("P"))

  #expect(
    graph.dispatch(
      .mouse(
        MouseEvent(
          kind: .release(.left), position: TerminalPosition(column: 0, row: 0)
        ))) == .handled)
  #expect(model.actionCount == 1)
  let released = try? graph.automationSnapshot.resolve("go")
  #expect(released?.isPressed == false)
  #expect(released?.isPointerCaptured == false)
}

@Test
func `outside pointer release cancels without activating`() {
  let model = PointerModel()
  let graph = ViewGraph(
    root: {
      Button("Go") { model.actionCount += 1 }
    }, size: TerminalSize(columns: 5, rows: 1))

  #expect(
    graph.dispatch(
      .mouse(
        MouseEvent(
          kind: .press(.left), position: TerminalPosition(column: 0, row: 0)
        ))) == .handled)
  #expect(
    graph.dispatch(
      .mouse(
        MouseEvent(
          kind: .release(.left), position: TerminalPosition(column: 4, row: 0)
        ))) == .ignored)
  #expect(model.isZero)
}

@Test
func `disabled topmost button blocks underlay pointer activation`() {
  let model = PointerModel()
  let graph = ViewGraph(
    root: {
      ZStack {
        Button("Under") { model.actionCount += 1 }
        Button("Disabled") { model.actionCount += 10 }.disabled()
      }
    }, size: TerminalSize(columns: 10, rows: 1))

  #expect(
    graph.dispatch(
      .mouse(
        MouseEvent(
          kind: .press(.left), position: TerminalPosition(column: 0, row: 0)
        ))) == .ignored)
  #expect(model.isZero)
}

@Test
func `phased Button key reports suppress repeat and activate on release`() {
  let model = PointerModel()
  let focus = FocusID("phased-button")
  let graph = ViewGraph(
    root: {
      Button("Go") { model.actionCount += 1 }
        .focusable(focus)
    }, size: TerminalSize(columns: 4, rows: 1))
  graph.focus.focus(focus)

  #expect(graph.dispatch(.key(Key(code: .enter, source: .kitty))) == .handled)
  #expect(model.isZero)
  #expect(
    graph.dispatch(.key(Key(code: .enter, kind: .repeat, source: .kitty))) == .handled)
  #expect(model.isZero)
  #expect(
    graph.dispatch(.key(Key(code: .enter, kind: .release, source: .kitty))) == .handled)
  #expect(model.actionCount == 1)
}

@Test
func `focus loss cancels a held phased Button key`() {
  let model = PointerModel()
  let focus = FocusID("blur-button")
  let graph = ViewGraph(
    root: {
      Button("Go") { model.actionCount += 1 }
        .focusable(focus)
        .automationID("go", role: .button)
    }, size: TerminalSize(columns: 4, rows: 1))
  graph.focus.focus(focus)

  #expect(graph.dispatch(.key(Key(code: .character(" "), source: .kitty))) == .handled)
  #expect(graph.automationSnapshot.elements.first?.isPressed == true)
  #expect(graph.dispatch(.focusLost) == .handled)
  #expect(model.isZero)
  #expect(graph.automationSnapshot.elements.first?.isPressed == false)
  #expect(
    graph.dispatch(.key(Key(code: .character(" "), kind: .release, source: .kitty)))
      == .ignored)
}
@Test
func `disabled topmost child bubbles to pointer ancestor without underlay fallthrough`() {
  let model = PointerModel()
  let graph = ViewGraph(
    root: {
      ZStack {
        Button("Under") { model.actionCount += 1 }
        Button("Disabled") { model.actionCount += 10 }.disabled()
      }
      .onPointer { event, _ in
        model.ancestorPhases.append(event.phase)
        return .handled
      }
    }, size: TerminalSize(columns: 10, rows: 1))

  #expect(
    graph.dispatch(
      .mouse(
        MouseEvent(
          kind: .press(.left), position: TerminalPosition(column: 0, row: 0)
        ))) == .handled)
  #expect(
    graph.dispatch(
      .mouse(
        MouseEvent(
          kind: .release(.left), position: TerminalPosition(column: 0, row: 0)
        ))) == .handled)
  #expect(model.ancestorPhases == [.down, .up])
  #expect(model.actionCount == 0)
}

@Test
func `new primary down cancels prior capture before outside hit`() {
  let model = PointerModel()
  let graph = ViewGraph(
    root: {
      Button("Go") { model.actionCount += 1 }
        .automationID("go", role: .button)
    }, size: TerminalSize(columns: 8, rows: 1))

  #expect(
    graph.dispatch(
      .mouse(
        MouseEvent(
          kind: .press(.left), position: TerminalPosition(column: 0, row: 0)
        ))) == .handled)
  #expect((try? graph.automationSnapshot.resolve("go"))?.isPressed == true)
  #expect(
    graph.dispatch(
      .mouse(
        MouseEvent(
          kind: .press(.left), position: TerminalPosition(column: 7, row: 0)
        ))) == .ignored)
  #expect((try? graph.automationSnapshot.resolve("go"))?.isPressed == false)

  #expect(
    graph.dispatch(
      .mouse(
        MouseEvent(
          kind: .press(.left), position: TerminalPosition(column: 0, row: 0)
        ))) == .handled)
  #expect(
    graph.dispatch(
      .mouse(
        MouseEvent(
          kind: .release(.left), position: TerminalPosition(column: 0, row: 0)
        ))) == .handled)
  #expect(model.actionCount == 1)
}

@Test
func `disabling a captured button cancels state before release`() {
  let model = PointerModel()
  var enabled = true
  let graph = ViewGraph(
    root: {
      Button("Go") { model.actionCount += 1 }
        .disabled(!enabled)
        .automationID("go", role: .button)
    }, size: TerminalSize(columns: 4, rows: 1))

  #expect(
    graph.dispatch(
      .mouse(
        MouseEvent(
          kind: .press(.left), position: TerminalPosition(column: 0, row: 0)
        ))) == .handled)
  enabled = false
  graph.update()
  #expect((try? graph.automationSnapshot.resolve("go"))?.isPressed == false)
  #expect(
    graph.dispatch(
      .mouse(
        MouseEvent(
          kind: .release(.left), position: TerminalPosition(column: 0, row: 0)
        ))) == .ignored)
  #expect(model.actionCount == 0)
}
@Test
func `replacement at captured slot cannot inherit pointer ownership`() {
  let model = PointerModel()
  var showOriginal = true
  let graph = ViewGraph(
    root: { ReplacementRoot(showOriginal: showOriginal, model: model) },
    size: TerminalSize(columns: 4, rows: 1))

  #expect(
    graph.dispatch(
      .mouse(
        MouseEvent(
          kind: .press(.left), position: TerminalPosition(column: 0, row: 0)
        ))) == .handled)
  showOriginal = false
  graph.update()
  #expect(
    graph.dispatch(
      .mouse(
        MouseEvent(
          kind: .release(.left), position: TerminalPosition(column: 0, row: 0)
        ))) == .ignored)
  #expect(model.actionCount == 0)
  #expect(
    graph.dispatch(
      .mouse(
        MouseEvent(
          kind: .press(.left), position: TerminalPosition(column: 0, row: 0)
        ))) == .handled)
  #expect(
    graph.dispatch(
      .mouse(
        MouseEvent(
          kind: .release(.left), position: TerminalPosition(column: 0, row: 0)
        ))) == .handled)
  #expect(model.actionCount == 10)
}

@Test
func `wrong-button release cancels capture without activating`() {
  let model = PointerModel()
  let graph = ViewGraph(
    root: {
      Button("Go") { model.actionCount += 1 }
    }, size: TerminalSize(columns: 4, rows: 1))

  #expect(
    graph.dispatch(
      .mouse(
        MouseEvent(
          kind: .press(.left), position: TerminalPosition(column: 0, row: 0)
        ))) == .handled)
  #expect(
    graph.dispatch(
      .mouse(
        MouseEvent(
          kind: .release(.right), position: TerminalPosition(column: 0, row: 0)
        ))) == .ignored)
  #expect(model.actionCount == 0)
}

@Test
func `legacy activation clears before a genuine phased press`() {
  let model = PointerModel()
  let focus = FocusID("mixed-button")
  let graph = ViewGraph(
    root: {
      Button("Go") { model.actionCount += 1 }
        .focusable(focus)
        .automationID("go", role: .button)
    }, size: TerminalSize(columns: 4, rows: 1))
  graph.focus.focus(focus)

  #expect(graph.dispatch(.key(Key(code: .enter, source: .kittyPressOnly))) == .handled)
  #expect(model.actionCount == 1)
  #expect(graph.dispatch(.key(Key(code: .enter, source: .kitty))) == .handled)
  #expect((try? graph.automationSnapshot.resolve("go"))?.isPressed == true)
  #expect(
    graph.dispatch(
      .key(Key(code: .enter, modifiers: .shift, kind: .release, source: .kitty)))
      == .handled)
  #expect(model.actionCount == 1)
  #expect((try? graph.automationSnapshot.resolve("go"))?.isPressed == false)
  #expect(graph.dispatch(.key(Key(code: .enter, source: .kitty))) == .handled)
  #expect(
    graph.dispatch(.key(Key(code: .enter, kind: .release, source: .kitty))) == .handled)
  #expect(model.actionCount == 2)
}
@Test
func `erased same-slot responder replacement cancels old capture`() {
  let model = PointerModel()
  var showOriginal = true
  let graph = ViewGraph(
    root: {
      AnyView(
        showOriginal
          ? AnyView(Button("Old") { model.actionCount += 1 })
          : AnyView(HStack { Button("New") { model.actionCount += 10 } })
      )
    }, size: TerminalSize(columns: 4, rows: 1))

  #expect(
    graph.dispatch(
      .mouse(
        MouseEvent(
          kind: .press(.left), position: TerminalPosition(column: 0, row: 0)
        ))) == .handled)
  showOriginal = false
  graph.update()
  #expect(
    graph.dispatch(
      .mouse(
        MouseEvent(
          kind: .release(.left), position: TerminalPosition(column: 0, row: 0)
        ))) == .ignored)
  #expect(model.actionCount == 0)
  #expect(
    graph.dispatch(
      .mouse(
        MouseEvent(
          kind: .press(.left), position: TerminalPosition(column: 0, row: 0)
        ))) == .handled)
  #expect(
    graph.dispatch(
      .mouse(
        MouseEvent(
          kind: .release(.left), position: TerminalPosition(column: 0, row: 0)
        ))) == .handled)
  #expect(model.actionCount == 10)
}
@Test
func `border clipping excludes chrome cells from child hit testing`() {
  let model = PointerModel()
  let graph = ViewGraph(
    root: {
      Button("Go") { model.actionCount += 1 }.border()
    }, size: TerminalSize(columns: 6, rows: 3))

  #expect(
    graph.dispatch(
      .mouse(
        MouseEvent(
          kind: .press(.left), position: TerminalPosition(column: 0, row: 0)
        ))) == .ignored)
  #expect(
    graph.dispatch(
      .mouse(
        MouseEvent(
          kind: .press(.left), position: TerminalPosition(column: 1, row: 1)
        ))) == .handled)
  #expect(
    graph.dispatch(
      .mouse(
        MouseEvent(
          kind: .release(.left), position: TerminalPosition(column: 1, row: 1)
        ))) == .handled)
  #expect(model.actionCount == 1)
}

@Test
func `new topmost overlay cancels prior target release`() {
  let model = PointerModel()
  var showOverlay = false
  let graph = ViewGraph(
    root: {
      ZStack {
        Button("Base") { model.actionCount += 1 }
        if showOverlay {
          Button("Overlay") { model.actionCount += 10 }
        }
      }
    }, size: TerminalSize(columns: 8, rows: 1))

  #expect(
    graph.dispatch(
      .mouse(
        MouseEvent(
          kind: .press(.left), position: TerminalPosition(column: 0, row: 0)
        ))) == .handled)
  showOverlay = true
  graph.update()
  #expect(
    graph.dispatch(
      .mouse(
        MouseEvent(
          kind: .release(.left), position: TerminalPosition(column: 0, row: 0)
        ))) == .ignored)
  #expect(model.actionCount == 0)
}
@Test
func `onPointer receives cancellation before capture is replaced`() {
  let model = PointerModel()
  let graph = ViewGraph(
    root: {
      Text("Tap").onPointer { event, _ in
        model.ancestorPhases.append(event.phase)
        return .handled
      }
    }, size: TerminalSize(columns: 3, rows: 1))

  #expect(
    graph.dispatch(
      .mouse(
        MouseEvent(
          kind: .press(.left), position: TerminalPosition(column: 0, row: 0)
        ))) == .handled)
  #expect(
    graph.dispatch(
      .mouse(
        MouseEvent(
          kind: .press(.left), position: TerminalPosition(column: 3, row: 0)
        ))) == .ignored)
  #expect(model.ancestorPhases == [.down, .cancel])
}
@Test
func `standalone onTap requests focus reporting for blur cancellation`() {
  let graph = ViewGraph(
    root: {
      Text("Tap").onTap { _ in }
    }, size: TerminalSize(columns: 3, rows: 1))

  #expect(graph.terminalRequirements.wantsMouse)
  #expect(graph.terminalRequirements.wantsFocusReporting)
}
