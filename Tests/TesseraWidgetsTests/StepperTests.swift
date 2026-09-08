import Foundation
import InlineSnapshotTesting
import TesseraCore
import TesseraTerminalBuffer
import TesseraTerminalCore
import TesseraTerminalInput
import Testing

@testable import TesseraWidgets

private final class StepperModel<Value> {
  var value: Value
  var focus: FocusID?

  init(value: Value, focus: FocusID? = nil) {
    self.value = value
    self.focus = focus
  }
}

private func stepperBinding<Value>(_ model: StepperModel<Value>) -> Binding<Value> {
  Binding(get: { model.value }, set: { model.value = $0 })
}

private final class DecimalStepperModel {
  var value: Double
  var focus: FocusID?

  init(value: Double, focus: FocusID? = nil) {
    self.value = value
    self.focus = focus
  }
}

private func decimalStepperBinding(_ model: DecimalStepperModel) -> Binding<Double> {
  Binding(get: { model.value }, set: { model.value = $0 })
}

private struct RatioFormat: FormatStyle {
  func format(_ value: Double) -> String {
    "ratio=\(value)"
  }
}

private func stepperFocusBinding(_ model: StepperModel<some Any>) -> Binding<FocusID?> {
  Binding(get: { model.focus }, set: { model.focus = $0 })
}

private func renderStepper(
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
func `stepper writes clamped directional values through its binding`() {
  let model = StepperModel(value: 4)
  let id = FocusID("stepper")
  let graph = ViewGraph(
    root: {
      Stepper(
        value: stepperBinding(model),
        in: 0...10,
        step: 3,
      )
      .focusable(id)
      .focused(stepperFocusBinding(model), equals: id)
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
  #expect(model.value == 7)
  #expect(graph.dispatch(.key(Key(code: .up))) == .handled)
  #expect(model.value == 10)
  #expect(graph.dispatch(.key(Key(code: .left))) == .handled)
  #expect(model.value == 7)
}

@Test
func `stepper repairs out of range values on enabled arrows`() {
  let model = StepperModel(value: 101)
  let id = FocusID("stepper")
  let graph = ViewGraph(
    root: {
      Stepper(
        value: stepperBinding(model),
        in: 0...99,
        step: 1,
      )
      .focusable(id)
      .focused(stepperFocusBinding(model), equals: id)
    },
    size: TerminalSize(columns: 20, rows: 1),
  )

  graph.focus.focus(id)
  #expect(graph.dispatch(.key(Key(code: .down))) == .handled)
  #expect(model.value == 99)

  model.value = -4
  #expect(graph.dispatch(.key(Key(code: .up))) == .handled)
  #expect(model.value == 0)
}

@Test
func `stepper bubbles at configured endpoints`() {
  let model = StepperModel(value: 0)
  let id = FocusID("stepper")
  let graph = ViewGraph(
    root: {
      Stepper(
        value: stepperBinding(model),
        in: 0...2,
      )
      .focusable(id)
      .focused(stepperFocusBinding(model), equals: id)
    },
    size: TerminalSize(columns: 20, rows: 1),
  )

  graph.focus.focus(id)
  #expect(graph.dispatch(.key(Key(code: .left))) == .ignored)
  #expect(model.value == 0)

  model.value = 2
  #expect(graph.dispatch(.key(Key(code: .right))) == .ignored)
  #expect(model.value == 2)
}

@Test
func `disabled stepper is not focusable and leaves its binding unchanged`() {
  let model = StepperModel(value: 4)
  let id = FocusID("stepper")
  let graph = ViewGraph(
    root: {
      Stepper(
        value: stepperBinding(model),
        in: 0...10,
      )
      .focusable(id)
      .focused(stepperFocusBinding(model), equals: id)
      .disabled()
    },
    size: TerminalSize(columns: 20, rows: 1),
  )

  #expect(graph.focus.focusableIDs.isEmpty)
  graph.focus.focus(id)
  #expect(graph.dispatch(.key(Key(code: .up))) == .ignored)
  #expect(model.value == 4)
  #expect(model.focus == nil)
}

@Test
func `stepper steps and formats decimal values`() {
  let model = DecimalStepperModel(value: 0.25)
  let id = FocusID("decimal-stepper")
  let graph = ViewGraph(
    root: {
      Stepper(
        value: decimalStepperBinding(model),
        in: 0...1,
        step: 0.25,
        format: RatioFormat(),
      )
      .focusable(id)
      .focused(
        Binding(get: { model.focus }, set: { model.focus = $0 }),
        equals: id,
      )
    },
    size: TerminalSize(columns: 24, rows: 1),
  )

  graph.focus.focus(id)
  #expect(graph.dispatch(.key(Key(code: .right))) == .handled)
  #expect(model.value == 0.5)
  #expect(graph.dispatch(.key(Key(code: .right))) == .handled)
  #expect(model.value == 0.75)
  #expect(graph.dispatch(.key(Key(code: .right))) == .handled)
  #expect(model.value == 1)
  #expect(graph.dispatch(.key(Key(code: .right))) == .ignored)

  graph.focus.focus(nil)
  let buffer = renderStepper(size: TerminalSize(columns: 24, rows: 1)) {
    graph.render(into: $0)
  }
  assertInlineSnapshot(of: buffer, as: .bufferState) {
    """
    [ - ]   r a t i o = 1 . 0   [{dim} +{dim} ]{dim} · · · · · · ·
    """
  }
}

@Test
func `integer stepper safely clamps at overflow boundaries`() {
  let model = StepperModel(value: Int.max - 1)
  let id = FocusID("integer-stepper")
  let graph = ViewGraph(
    root: {
      Stepper(value: stepperBinding(model), in: Int.min...Int.max, step: 2)
        .focusable(id)
        .focused(stepperFocusBinding(model), equals: id)
    },
    size: TerminalSize(columns: 24, rows: 1),
  )

  graph.focus.focus(id)
  #expect(graph.dispatch(.key(Key(code: .right))) == .handled)
  #expect(model.value == Int.max)
}

@Test
func `Int64 stepper safely steps a full-span range`() {
  let model = StepperModel(value: Int64.min)
  let id = FocusID("int64-stepper")
  let graph = ViewGraph(
    root: {
      Stepper(
        value: stepperBinding(model),
        in: Int64.min...Int64.max,
        step: 1,
      )
      .focusable(id)
      .focused(stepperFocusBinding(model), equals: id)
    },
    size: TerminalSize(columns: 24, rows: 1),
  )

  graph.focus.focus(id)
  #expect(graph.dispatch(.key(Key(code: .right))) == .handled)
  #expect(model.value == Int64.min + 1)

  model.value = Int64.max
  #expect(graph.dispatch(.key(Key(code: .left))) == .handled)
  #expect(model.value == Int64.max - 1)
}

@Test
func `fixed-width integer stepper reaches endpoints for unrepresentable strides`() {
  let model = StepperModel(value: Int8.max)
  let id = FocusID("int8-stepper")
  let graph = ViewGraph(
    root: {
      Stepper(
        value: stepperBinding(model),
        in: Int8.min...Int8.max,
        step: 128,
      )
      .focusable(id)
      .focused(stepperFocusBinding(model), equals: id)
    },
    size: TerminalSize(columns: 24, rows: 1),
  )

  graph.focus.focus(id)
  #expect(graph.dispatch(.key(Key(code: .left))) == .handled)
  #expect(model.value == Int8.min)

  model.value = Int8.min
  #expect(graph.dispatch(.key(Key(code: .right))) == .handled)
  #expect(model.value == Int8.max)
}

@Test
func `stepper rejects invalid steps`() async {
  await #expect(processExitsWith: .failure) {
    _ = Stepper(
      value: .constant(0),
      in: 0...1,
      step: 0,
    )
  }
}

@Test
func `stepper renders one deterministic row`() {
  let model = StepperModel(value: 42)
  let graph = ViewGraph(
    root: {
      Stepper(
        value: stepperBinding(model),
        in: 0...99,
      )
      .focusable(FocusID("stepper"))
      .focused(stepperFocusBinding(model), equals: FocusID("stepper"))
    },
    size: TerminalSize(columns: 10, rows: 1),
  )

  let buffer = renderStepper(size: TerminalSize(columns: 10, rows: 1)) {
    graph.render(into: $0)
  }
  assertInlineSnapshot(of: buffer, as: .bufferState) {
    """
    [ - ]   4 2   [ + ]
    """
  }
}

@Test
func `stepper pointer activates only the pressed affordance`() {
  let model = StepperModel(value: 5)
  let id = FocusID("pointer-stepper")
  let graph = ViewGraph(
    root: {
      Stepper(value: stepperBinding(model), in: 0...10)
        .focusable(id)
        .focused(stepperFocusBinding(model), equals: id)
    },
    size: TerminalSize(columns: 9, rows: 1),
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
  #expect(model.value == 5)
  #expect(
    graph.dispatch(
      .mouse(
        MouseEvent(
          kind: .release(.left), position: TerminalPosition(column: 0, row: 0),
        ),
      ),
    ) == .handled,
  )
  #expect(model.value == 4)

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
          kind: .release(.left), position: TerminalPosition(column: 4, row: 0),
        ),
      ),
    ) == .ignored,
  )
  #expect(model.value == 4)

  #expect(
    graph.dispatch(
      .mouse(
        MouseEvent(
          kind: .press(.left), position: TerminalPosition(column: 8, row: 0),
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
    ) == .handled,
  )
  #expect(model.value == 5)
}

@Test
func `stepper pointer leaves endpoint and disabled interactions unconsumed`() {
  let model = StepperModel(value: 0)
  let id = FocusID("endpoint-stepper")
  let graph = ViewGraph(
    root: {
      Stepper(value: stepperBinding(model), in: 0...10)
        .focusable(id)
        .focused(stepperFocusBinding(model), equals: id)
    },
    size: TerminalSize(columns: 9, rows: 1),
  )

  #expect(
    graph.dispatch(
      .mouse(
        MouseEvent(
          kind: .press(.left), position: TerminalPosition(column: 0, row: 0),
        ),
      ),
    ) == .ignored,
  )
  #expect(model.value == 0)

  let disabledGraph = ViewGraph(
    root: { Stepper(value: stepperBinding(model), in: 0...10).disabled() },
    size: TerminalSize(columns: 9, rows: 1),
  )
  #expect(
    disabledGraph.dispatch(
      .mouse(
        MouseEvent(
          kind: .press(.left), position: TerminalPosition(column: 8, row: 0),
        ),
      ),
    ) == .ignored,
  )
  #expect(model.value == 0)

  #expect(
    graph.dispatch(
      .mouse(
        MouseEvent(
          kind: .press(.left), position: TerminalPosition(column: 8, row: 0),
        ),
      ),
    ) == .handled,
  )
  #expect(
    graph.dispatch(
      .mouse(
        MouseEvent(
          kind: .release(.left), position: TerminalPosition(column: 20, row: 0),
        ),
      ),
    ) == .ignored,
  )
  #expect(model.value == 0)
}
