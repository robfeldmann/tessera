import Tessera

/// A complete keyboard action/result loop with a second control for enabled state.
/// The app owns the count, enabled value, and explicit focus binding.
package final class ButtonSpecimen {
  package static let addFocus = FocusID("add")
  package static let toggleFocus = FocusID("toggle")

  package var count = 0
  package var focused: FocusID?
  package var isAddEnabled = true

  package var content: some View {
    VStack(alignment: .leading, spacing: 1) {
      Text("Button / result").bold()
      Text("Count: \(count)")
        .automationID("count", role: .text)
      HStack(spacing: 2) {
        Button("Add") { self.count += 1 }
          .focusable(Self.addFocus)
          .focused(focusBinding, equals: Self.addFocus)
          .automationID("add", role: .button)
          .disabled(!isAddEnabled)
        Button(isAddEnabled ? "Disable Add" : "Enable Add") {
          self.isAddEnabled.toggle()
        }
        .focusable(Self.toggleFocus)
        .focused(focusBinding, equals: Self.toggleFocus)
        .automationID("toggle", role: .button)
      }
      Text(isAddEnabled ? "Add is enabled." : "Add is disabled.")
      Text("Tab / Shift-Tab: focus\nEnter / Space: act\nq: quit")
    }
    .padding(1)
  }

  package var state: [String: String] {
    [
      "actionCount": String(count),
      "addEnabled": String(isAddEnabled),
      "focus": focused == Self.addFocus
        ? "add" : focused == Self.toggleFocus ? "toggle" : "none",
    ]
  }

  private var focusBinding: Binding<FocusID?> {
    Binding(get: { self.focused }, set: { self.focused = $0 })
  }

  package init() {}
}
