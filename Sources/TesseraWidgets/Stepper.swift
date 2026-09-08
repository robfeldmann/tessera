import Foundation
import TesseraCore
import TesseraLayout
import TesseraTerminalCore
import TesseraTerminalInput

/// A controlled numeric stepper with explicit bounds.
public struct Stepper<Value: Comparable & Strideable>: View
where Value.Stride: Comparable & SignedNumeric {
  private let value: Binding<Value>
  private let minimum: Value
  private let maximum: Value
  private let step: Value.Stride
  private let format: (Value) -> String
  private let clampedStepping: (Value, _StepperDirection) -> Value

  public var body: some View {
    EnvironmentReader { environment in
      _StepperResponder(
        value: value,
        minimum: minimum,
        maximum: maximum,
        format: format,
        clampedStepping: clampedStepping,
        isEnabled: environment.isEnabled,
        style: !environment.isEnabled
          ? environment.semanticStyles.disabled
          : (environment.isFocused
            ? environment.semanticStyles.focus
            : environment.semanticStyles.primary),
        disabledStyle: environment.semanticStyles.disabled,
      )
      .frame(minWidth: 9)
    }
  }

  /// Creates a stepper with an application-owned value binding.
  public init(
    value: Binding<Value>,
    in range: ClosedRange<Value>,
    step: Value.Stride = 1,
  ) {
    self.init(
      value: value,
      in: range,
      step: step,
      format: { String(describing: $0) },
      clampedStepping: { value, direction in
        Self.genericClampedStepping(
          from: value,
          minimum: range.lowerBound,
          maximum: range.upperBound,
          step: step,
          in: direction,
        )
      },
    )
  }

  /// Creates a stepper with an application-owned value binding and display format.
  public init<Format>(
    value: Binding<Value>,
    in range: ClosedRange<Value>,
    step: Value.Stride = 1,
    format: Format,
  ) where Format: FormatStyle, Format.FormatInput == Value, Format.FormatOutput == String {
    self.init(
      value: value,
      in: range,
      step: step,
      format: format.format,
    ) { value, direction in
      Self.genericClampedStepping(
        from: value,
        minimum: range.lowerBound,
        maximum: range.upperBound,
        step: step,
        in: direction,
      )
    }
  }

  private init(
    value: Binding<Value>,
    in range: ClosedRange<Value>,
    step: Value.Stride,
    format: @escaping (Value) -> String,
    clampedStepping: @escaping (Value, _StepperDirection) -> Value,
  ) {
    precondition(step > .zero, "Stepper step must be positive.")

    self.value = value
    minimum = range.lowerBound
    maximum = range.upperBound
    self.step = step
    self.format = format
    self.clampedStepping = clampedStepping
  }

  private static func genericClampedStepping(
    from value: Value,
    minimum: Value,
    maximum: Value,
    step: Value.Stride,
    in direction: _StepperDirection,
  ) -> Value {
    guard value >= minimum, value <= maximum else {
      return min(max(value, minimum), maximum)
    }

    switch direction {
    case .decrement:
      let remaining = minimum.distance(to: value)
      return step >= remaining ? minimum : value.advanced(by: -step)
    case .increment:
      let remaining = value.distance(to: maximum)
      return step >= remaining ? maximum : value.advanced(by: step)
    }
  }
}

extension Stepper where Value: FixedWidthInteger, Value.Stride == Int {
  /// Creates a fixed-width integer stepper that safely clamps at integer overflow boundaries.
  public init(
    value: Binding<Value>,
    in range: ClosedRange<Value>,
    step: Value.Stride = 1,
  ) {
    self.init(
      value: value,
      in: range,
      step: step,
      format: { String(describing: $0) },
      clampedStepping: { value, direction in
        Self.integerClampedStepping(
          from: value,
          minimum: range.lowerBound,
          maximum: range.upperBound,
          step: step,
          in: direction,
        )
      },
    )
  }

  /// Creates a fixed-width integer stepper with an application-owned value binding and display format.
  public init<Format>(
    value: Binding<Value>,
    in range: ClosedRange<Value>,
    step: Value.Stride = 1,
    format: Format,
  ) where Format: FormatStyle, Format.FormatInput == Value, Format.FormatOutput == String {
    self.init(
      value: value,
      in: range,
      step: step,
      format: format.format,
    ) { value, direction in
      Self.integerClampedStepping(
        from: value,
        minimum: range.lowerBound,
        maximum: range.upperBound,
        step: step,
        in: direction,
      )
    }
  }

  private static func integerClampedStepping(
    from value: Value,
    minimum: Value,
    maximum: Value,
    step: Int,
    in direction: _StepperDirection,
  ) -> Value {
    guard value >= minimum, value <= maximum else {
      return min(max(value, minimum), maximum)
    }

    guard let integerStep = Value(exactly: step) else {
      switch direction {
      case .decrement:
        return minimum
      case .increment:
        return maximum
      }
    }

    switch direction {
    case .decrement:
      let candidate = value.subtractingReportingOverflow(integerStep)
      return min(
        max(candidate.overflow ? Value.min : candidate.partialValue, minimum),
        maximum,
      )
    case .increment:
      let candidate = value.addingReportingOverflow(integerStep)
      return min(
        max(candidate.overflow ? Value.max : candidate.partialValue, minimum),
        maximum,
      )
    }
  }
}

private struct _StepperResponder<Value: Comparable & Strideable>: View,
  _FocusAppearanceResponder, _ResponderView,
  _PointerResponderView, _TerminalRequirementsView
where Value.Stride: Comparable & SignedNumeric {
  struct ResponderState {
    var pressedDirection: _StepperDirection?
  }

  let value: Binding<Value>
  let minimum: Value
  let maximum: Value
  let format: (Value) -> String
  let clampedStepping: (Value, _StepperDirection) -> Value
  let isEnabled: Bool
  let style: Style
  let disabledStyle: Style

  var body: some View {
    EnvironmentReader { environment in
      let current = value.wrappedValue
      let decrementAvailable = canStep(current, in: .decrement)
      let incrementAvailable = canStep(current, in: .increment)
      let pressed = environment._responderStateProjection.isPressed
      let rowStyle = pressed && isEnabled ? style.reverse() : style
      HStack(spacing: 0) {
        Text("[-]").style(decrementAvailable ? rowStyle : disabledStyle)
        Text(" ").style(rowStyle)
        Text(format(current)).style(rowStyle)
        Text(" ").style(rowStyle)
        Text("[+]").style(incrementAvailable ? rowStyle : disabledStyle)
      }
    }
  }

  var _terminalRequirements: TerminalRequirements {
    TerminalRequirements(wantsKeyboardEnhancement: true, wantsMouse: true)
  }

  func _makeResponderState() -> ResponderState {
    ResponderState(pressedDirection: nil)
  }

  func _updateResponderState(_ state: inout ResponderState) {
    if !isEnabled {
      state.pressedDirection = nil
    }
  }

  func _updateResponderStateProjection(
    _ projection: inout _ResponderStateProjection,
    state: ResponderState,
  ) {
    projection.isPressed = state.pressedDirection != nil
    projection.isPointerCaptured = state.pressedDirection != nil
  }

  func _cancelResponderState(_ state: inout ResponderState) {
    state.pressedDirection = nil
  }

  func _handleEvent(
    _ event: InputEvent,
    state _: inout ResponderState,
    context: inout ResponderContext,
  ) -> EventDisposition {
    guard context.isFocused, isEnabled, case .key(let key) = event,
      key.kind == .press, key.modifiers.isEmpty
    else {
      return .ignored
    }

    let direction: _StepperDirection
    switch key.code {
    case .left, .down:
      direction = .decrement
    case .right, .up:
      direction = .increment
    default:
      return .ignored
    }

    let current = value.wrappedValue
    guard canStep(current, in: direction) else {
      return .ignored
    }

    value.wrappedValue = clampedStepping(current, direction)
    context.setNeedsLayout()
    return .handled
  }

  func _handlePointer(
    _ event: PointerEvent,
    state: inout ResponderState,
    context: inout ResponderContext,
  ) -> EventDisposition {
    guard isEnabled else {
      state.pressedDirection = nil
      return .ignored
    }

    switch event.phase {
    case .down where event.button == .left:
      guard let direction = direction(at: event.position, in: context.nodeBounds),
        canStep(value.wrappedValue, in: direction)
      else {
        return .ignored
      }
      state.pressedDirection = direction
      context.setNeedsDisplay()
      return .handled
    case .up where event.button == .left:
      guard let pressedDirection = state.pressedDirection else {
        return .ignored
      }
      let releasedDirection = direction(at: event.position, in: context.nodeBounds)
      state.pressedDirection = nil
      context.setNeedsDisplay()
      guard releasedDirection == pressedDirection,
        canStep(value.wrappedValue, in: pressedDirection)
      else {
        return .ignored
      }
      value.wrappedValue = clampedStepping(value.wrappedValue, pressedDirection)
      context.setNeedsLayout()
      return .handled
    case .cancel:
      guard state.pressedDirection != nil else {
        return .ignored
      }
      state.pressedDirection = nil
      context.setNeedsDisplay()
      return .handled
    case .move:
      return state.pressedDirection == nil ? .ignored : .handled
    default:
      return .ignored
    }
  }

  private func canStep(_ value: Value, in direction: _StepperDirection) -> Bool {
    switch direction {
    case .decrement:
      value != minimum
    case .increment:
      value != maximum
    }
  }

  private func direction(at position: TerminalPosition, in bounds: Rect)
    -> _StepperDirection?
  {
    guard bounds.contains(position) else {
      return nil
    }
    let column = position.column - bounds.origin.column
    guard bounds.size.columns >= 6 else {
      return nil
    }
    if column < 3 {
      return .decrement
    }
    if column >= bounds.size.columns - 3 {
      return .increment
    }
    return nil
  }
}

private enum _StepperDirection: Equatable {
  case decrement
  case increment
}
