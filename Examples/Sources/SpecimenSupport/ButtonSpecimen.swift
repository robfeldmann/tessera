import Tessera

/// A small application-owned action/result loop used by capture and the live lab.
///
/// The specimen deliberately keeps business state outside Button. Its second
/// control uses a generic label and a custom style so capture can show the same
/// press projection through both style paths.
package final class ButtonSpecimen {
  package static let addFocus = FocusID("add")
  package static let toggleFocus = FocusID("toggle")

  package var count = 0
  package var focused: FocusID?
  package var isAddEnabled = true
  package var isAddPresent = true
  package var isAddPlainStyle = false

  package var content: some View {
    VStack(alignment: .leading, spacing: 1) {
      Text("Button / result").bold()
      Text("Count: \(count)")
        .automationID("count", role: .text)
      HStack(spacing: 2) {
        if isAddPresent {
          if isAddPlainStyle {
            addButtonCore.buttonStyle(.plain)
          } else {
            addButtonCore.buttonStyle(.compact)
          }
        }
        Button(
          action: { self.isAddEnabled.toggle() },
          label: {
            HStack(spacing: 0) {
              Text(isAddEnabled ? "Disable " : "Enable ")
              Text("Add").bold()
            }
          }
        )
        .buttonStyle(CaptureButtonStyle())
        .focusable(Self.toggleFocus)
        .focused(focusBinding, equals: Self.toggleFocus)
        .automationID("toggle", role: .button)
      }
      Text(
        isAddPresent
          ? (isAddEnabled ? "Add is enabled." : "Add is disabled.")
          : "Add is removed."
      )
      Text("Tab / Shift-Tab: focus\nEnter / Space: act\nq: quit")
    }
    .padding(1)
  }

  package var state: [String: String] {
    [
      "actionCount": String(count),
      "addEnabled": String(isAddEnabled),
      "addPresent": String(isAddPresent),
      "addStyle": isAddPlainStyle ? "plain" : "compact",
      "focus": focused == Self.addFocus
        ? "add" : focused == Self.toggleFocus ? "toggle" : "none",
    ]
  }

  private var addButtonCore: some View {
    Button("Add") { self.count += 1 }
      .focusable(Self.addFocus)
      .focused(focusBinding, equals: Self.addFocus)
      .automationID("add", role: .button)
      .disabled(!isAddEnabled)
  }

  private var focusBinding: Binding<FocusID?> {
    Binding(get: { self.focused }, set: { self.focused = $0 })
  }

  package init() {}

  /// Mutates the app-owned enabled state without routing through a control.
  package func setAddEnabled(_ enabled: Bool) {
    isAddEnabled = enabled
  }

  /// Switches the built-in visual treatment without changing the app-owned action.
  package func setAddPlainStyle(_ plain: Bool) {
    isAddPlainStyle = plain
  }

  /// Mutates the app-owned presence state without granting a removed node authority.
  package func setAddPresent(_ present: Bool) {
    isAddPresent = present
    if !present, focused == Self.addFocus {
      focused = nil
    }
  }
}

/// A compact custom style whose label is a composed generic view.
///
/// The style intentionally changes only visible treatment; activation and focus remain
/// supplied by the Button responder.
package struct CaptureButtonStyle: ButtonStyle {
  package init() {}

  package func makeBody(configuration: ButtonStyleConfiguration) -> some View {
    let style =
      configuration.isPressed
      ? Style(foreground: .indexed(0), background: .indexed(6)).bold()
      : Style(foreground: .indexed(6)).bold()
    HStack(spacing: 0) {
      Text("<").style(style)
      configuration.label.style(style)
      Text(">").style(style)
    }
  }
}
