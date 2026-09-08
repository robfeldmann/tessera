import TesseraCore
import TesseraLayout

/// An application-controlled Boolean value with an arbitrary label.
///
/// The value remains owned by the supplied binding. Toggle composes the same Button
/// responder used by other action controls, so keyboard and pointer activation retain the
/// established focus, capture, cancellation, and disabled semantics.
public struct Toggle<Label: View>: View, _FocusAppearanceResponder {
  private let isOn: Binding<Bool>
  private let label: Label

  public var body: some View {
    Button(
      action: { isOn.wrappedValue.toggle() },
      label: {
        _ToggleLabel(isOn: isOn, label: label)
      },
    )
    .buttonStyle(_ToggleButtonStyle())
    .frame(minWidth: 3)
  }

  /// Creates a toggle.
  public init(
    isOn: Binding<Bool>,
    @ViewBuilder label: () -> Label,
  ) {
    self.isOn = isOn
    self.label = label()
  }
}

/// The checkbox presentation used by Toggle's Button composition.
private struct _ToggleButtonStyle: ButtonStyle {
  func makeBody(configuration: ButtonStyleConfiguration) -> some View {
    // `_ToggleLabel` consumes the responder projection so the marker and label can keep
    // their distinct idle roles while still sharing Button's pressed lifecycle.
    configuration.label
  }
}

private struct _ToggleLabel<Label: View>: View {
  let isOn: Binding<Bool>
  let label: Label

  var body: some View {
    EnvironmentReader { environment in
      let isPressed = environment._responderStateProjection.isPressed
      let activeStyle = resolvedStyle(in: environment, pressed: isPressed)
      let markerStyle = resolvedMarkerStyle(
        in: environment, pressed: isPressed, active: activeStyle)
      let labelStyle = resolvedLabelStyle(
        in: environment, pressed: isPressed, active: activeStyle)

      HStack(spacing: 0) {
        Text(isOn.wrappedValue ? "[x]" : "[ ]").style(markerStyle)
        Text(" ").style(labelStyle)
        label.style(labelStyle)
      }
    }
  }

  private func resolvedMarkerStyle(
    in environment: EnvironmentValues, pressed: Bool, active: Style
  ) -> Style {
    guard environment.isEnabled else {
      return environment.semanticStyles.disabled
    }
    return pressed || environment.isFocused ? active : environment.semanticStyles.secondary
  }

  private func resolvedLabelStyle(
    in environment: EnvironmentValues, pressed: Bool, active: Style
  ) -> Style {
    guard environment.isEnabled else {
      return environment.semanticStyles.disabled
    }
    return pressed || environment.isFocused ? active : environment.semanticStyles.primary
  }

  private func resolvedStyle(in environment: EnvironmentValues, pressed: Bool) -> Style {
    let base: Style =
      if !environment.isEnabled {
        environment.semanticStyles.disabled
      } else if environment.isFocused {
        environment.semanticStyles.focus
      } else {
        environment.semanticStyles.primary
      }
    return pressed && environment.isEnabled ? base.reverse() : base
  }
}

extension Toggle where Label == Text {
  /// Creates a toggle with a string label.
  public init(
    _ title: String,
    isOn: Binding<Bool>,
  ) {
    self.isOn = isOn
    label = Text(title)
  }
}
