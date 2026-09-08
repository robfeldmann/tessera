import TesseraCore
import TesseraLayout
import TesseraTerminalCore
import TesseraTerminalInput

/// A controlled, inline selector over a finite, application-supplied option list.
public struct Picker<Selection: Hashable, Value: View>: View {
  private let selection: Binding<Selection>
  private let options: [Selection]
  private let content: (Selection) -> Value

  public var body: some View {
    EnvironmentReader { environment in
      _PickerResponder(
        selection: selection,
        options: options,
        isEnabled: environment.isEnabled,
        style: !environment.isEnabled
          ? environment.semanticStyles.disabled
          : (environment.isFocused
            ? environment.semanticStyles.focus
            : environment.semanticStyles.primary),
        inactiveStyle: environment.semanticStyles.secondary,
        content: content,
      )
      .frame(minWidth: 5)
    }
  }

  /// Creates a picker with an application-owned selection.
  public init(
    selection: Binding<Selection>,
    options: [Selection],
    @ViewBuilder content: @escaping (Selection) -> Value,
  ) {
    self.selection = selection
    self.options = options
    self.content = content
  }
}

private struct _PickerResponder<Selection: Hashable, Value: View>: View,
  _FocusAppearanceResponder, _ResponderView, _PointerResponderView,
  _TerminalRequirementsView
{
  struct ResponderState {
    var pointerPressed = false
  }

  let selection: Binding<Selection>
  let options: [Selection]
  let isEnabled: Bool
  let style: Style
  let inactiveStyle: Style
  let content: (Selection) -> Value
  private var selectedOption: Selection? {
    options.first { $0 == selection.wrappedValue }
  }

  var body: some View {
    EnvironmentReader { environment in
      let rowStyle =
        environment._responderStateProjection.isPressed && isEnabled
        ? style.reverse()
        : style
      HStack(spacing: 0) {
        Text("‹ ").style(
          chevronStyle(active: nextSelection(in: .previous) != nil, rowStyle: rowStyle),
        )
        if let selection = selectedOption {
          content(selection)
        } else {
          Text("—").style(rowStyle)
        }
        Text(" ›").style(
          chevronStyle(active: nextSelection(in: .next) != nil, rowStyle: rowStyle),
        )
      }
      .style(rowStyle)
    }
  }

  var _terminalRequirements: TerminalRequirements {
    TerminalRequirements(wantsKeyboardEnhancement: true, wantsMouse: true)
  }

  func _makeResponderState() -> ResponderState {
    ResponderState(pointerPressed: false)
  }

  func _updateResponderState(_ state: inout ResponderState) {
    if !isEnabled {
      state.pointerPressed = false
    }
  }

  func _updateResponderStateProjection(
    _ projection: inout _ResponderStateProjection,
    state: ResponderState,
  ) {
    projection.isPressed = state.pointerPressed
    projection.isPointerCaptured = state.pointerPressed
  }

  func _cancelResponderState(_ state: inout ResponderState) {
    state.pointerPressed = false
  }

  private func chevronStyle(active: Bool, rowStyle: Style) -> Style {
    guard isEnabled else {
      return style
    }
    return active ? rowStyle : inactiveStyle
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

    let direction: _PickerDirection
    switch key.code {
    case .left, .up:
      direction = .previous
    case .right, .down:
      direction = .next
    default:
      return .ignored
    }

    guard let nextSelection = nextSelection(in: direction) else {
      return .ignored
    }

    selection.wrappedValue = nextSelection
    context.setNeedsLayout()
    return .handled
  }

  func _handlePointer(
    _ event: PointerEvent,
    state: inout ResponderState,
    context: inout ResponderContext,
  ) -> EventDisposition {
    guard isEnabled else {
      state.pointerPressed = false
      return .ignored
    }

    switch event.phase {
    case .down where event.button == .left:
      guard isValueSlot(event.position, in: context.nodeBounds),
        nextSelection(in: .next) != nil
      else {
        return .ignored
      }
      state.pointerPressed = true
      context.setNeedsDisplay()
      return .handled
    case .up where event.button == .left:
      guard state.pointerPressed else {
        return .ignored
      }
      let validRelease = isValueSlot(event.position, in: context.nodeBounds)
      state.pointerPressed = false
      context.setNeedsDisplay()
      guard validRelease, let nextSelection = nextSelection(in: .next) else {
        return .ignored
      }
      selection.wrappedValue = nextSelection
      context.setNeedsLayout()
      return .handled
    case .cancel:
      guard state.pointerPressed else {
        return .ignored
      }
      state.pointerPressed = false
      context.setNeedsDisplay()
      return .handled
    case .move:
      return state.pointerPressed ? .handled : .ignored
    default:
      return .ignored
    }
  }

  private func isValueSlot(_ position: TerminalPosition, in bounds: Rect) -> Bool {
    guard bounds.contains(position) else {
      return false
    }
    let column = position.column - bounds.origin.column
    return bounds.size.columns >= 5 && column >= 2 && column < bounds.size.columns - 2
  }

  private func nextSelection(in direction: _PickerDirection) -> Selection? {
    guard options.isEmpty == false else {
      return nil
    }

    guard let currentIndex = options.firstIndex(of: selection.wrappedValue) else {
      return options[0]
    }

    switch direction {
    case .previous:
      guard currentIndex > 0 else {
        return nil
      }
      return options[currentIndex - 1]
    case .next:
      guard currentIndex < options.index(before: options.endIndex) else {
        return nil
      }
      return options[currentIndex + 1]
    }
  }
}

private enum _PickerDirection {
  case next
  case previous
}
