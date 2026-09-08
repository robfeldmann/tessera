import Tessera

/// A small settings editor demonstrating plain application-owned control state.
package final class SettingsSpecimen {
  package static let nameFocus = FocusID("settings-name")
  package static let enabledFocus = FocusID("settings-enabled")
  package static let volumeFocus = FocusID("settings-volume")
  package static let themeFocus = FocusID("settings-theme")

  package var name = "Ada"
  package var enabled = true
  package var volume = 3
  package var theme = "Light"
  package var submissions = 0
  package var focused: FocusID?

  private let themes = ["Light", "Dark", "System"]

  private var focusBinding: Binding<FocusID?> {
    Binding(get: { self.focused }, set: { self.focused = $0 })
  }

  package var content: some View {
    VStack(alignment: .leading, spacing: 1) {
      Text("Settings").bold()
      TextField(
        "Name",
        text: Binding(get: { self.name }, set: { self.name = $0 }),
        prompt: Text("Display name")
      ) { _ in self.submissions += 1 }
      .focusable(Self.nameFocus)
      .focused(focusBinding, equals: Self.nameFocus)
      .automationID("settings-name", role: .button)
      Toggle(
        isOn: Binding(get: { self.enabled }, set: { self.enabled = $0 })
      ) {
        Text("Enabled")
      }
      .focusable(Self.enabledFocus)
      .focused(focusBinding, equals: Self.enabledFocus)
      .automationID("settings-enabled", role: .button)
      Stepper(
        value: Binding(get: { self.volume }, set: { self.volume = $0 }),
        in: 0...10,
        step: 1
      )
      .focusable(Self.volumeFocus)
      .focused(focusBinding, equals: Self.volumeFocus)
      .automationID("settings-volume", role: .button)
      Picker(
        selection: Binding(get: { self.theme }, set: { self.theme = $0 }),
        options: themes
      ) { value in
        Text("Theme: \(value)")
      }
      .focusable(Self.themeFocus)
      .focused(focusBinding, equals: Self.themeFocus)
      .automationID("settings-theme", role: .button)
      Text("Submitted: \(submissions)").style(Style().dim())
    }
    .padding(1)
  }

  package var state: [String: String] {
    [
      "name": name,
      "enabled": String(enabled),
      "volume": String(volume),
      "theme": theme,
      "submissions": String(submissions),
      "focus": focused.map { String(describing: $0) } ?? "none",
    ]
  }

  package init() {}

  package static func input(_ size: TerminalSize) -> [SpecimenInputStep] {
    [
      SpecimenInputStep("focus-name", bytes: [0x09]),
      SpecimenInputStep("insert-name", bytes: Array("!".utf8)),
      SpecimenInputStep("submit-name", bytes: [0x0d]),
      SpecimenInputStep("next-control", bytes: [0x09]),
      SpecimenInputStep("toggle", bytes: [0x20]),
      SpecimenInputStep("next-volume", bytes: [0x09]),
      SpecimenInputStep("increment-volume", bytes: [0x1b, 0x5b, 0x43]),
    ]
  }
}
