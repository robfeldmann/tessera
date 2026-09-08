import Tessera

/// A nested viewport specimen with bounded inner content, focus reveal, and app-owned offsets.
package final class ViewportSpecimen {
  package static let outerFocus = FocusID("outer-scroll")
  package static let innerFocus = FocusID("inner-scroll")
  package static let actionFocus = FocusID("inner-action")

  package var outerOffset = TerminalPosition(column: 0, row: 0)
  package var innerOffset = TerminalPosition(column: 0, row: 0)
  package var focused: FocusID?
  package var actionCount = 0

  private var focusBinding: Binding<FocusID?> {
    Binding(get: { self.focused }, set: { self.focused = $0 })
  }

  package var content: some View {
    ScrollView(
      .vertical,
      offset: Binding(
        get: { self.outerOffset },
        set: { self.outerOffset = $0 }
      )
    ) {
      VStack(alignment: .leading, spacing: 1) {
        Text("Viewport boundary").bold()
        Text("Outer content stays logical while the inner viewport scrolls.")
          .wrapped(.word)
        ScrollView(
          .vertical,
          offset: Binding(
            get: { self.innerOffset },
            set: { self.innerOffset = $0 }
          )
        ) {
          VStack(alignment: .leading, spacing: 0) {
            Text("Inner 01")
            Text("Inner 02")
            Text("Inner 03")
            Text("Inner 04")
            Text("Inner 05")
            Text("Inner 06")
            Text("Inner 07")
            Text("Inner 08")
            Text("Inner 09")
            Text("Inner 10")
            Button("Inner action") { self.actionCount += 1 }
              .focusable(Self.actionFocus)
              .focused(focusBinding, equals: Self.actionFocus)
              .automationID("inner-action", role: .button)
          }
        }
        .frame(height: 5)
        .focusable(Self.innerFocus)
        .focused(focusBinding, equals: Self.innerFocus)
        Text("Outer 01")
        Text("Outer 02")
        Text("Outer 03")
        Text("Outer 04")
        Text("Outer 05")
        Text("Outer 06")
        Text("Outer 07")
        Text("Outer 08")
        Text("Outer 09")
        Text("Outer 10")
        Text("Outer 11")
        Text("Outer 12")
        Text("Outer 13")
        Text("Outer 14")
        Text("Outer 15")
        Text("Outer 16")
      }
      .padding(1)
    }
    .focusable(Self.outerFocus)
    .focused(focusBinding, equals: Self.outerFocus)
  }

  package var state: [String: String] {
    [
      "outerOffset": "\(outerOffset.column),\(outerOffset.row)",
      "innerOffset": "\(innerOffset.column),\(innerOffset.row)",
      "focus": focused.map(String.init(describing:)) ?? "none",
      "actionCount": String(actionCount),
    ]
  }

  package init() {}

  package static func input(_ size: TerminalSize) -> [SpecimenInputStep] {
    [
      SpecimenInputStep("focus-outer", bytes: [0x09]),
      SpecimenInputStep("focus-inner", bytes: [0x09]),
      SpecimenInputStep("inner-down-1", bytes: [0x1b, 0x5b, 0x42]),
      SpecimenInputStep("inner-down-2", bytes: [0x1b, 0x5b, 0x42]),
      SpecimenInputStep("inner-down-3", bytes: [0x1b, 0x5b, 0x42]),
      SpecimenInputStep("inner-down-4", bytes: [0x1b, 0x5b, 0x42]),
      SpecimenInputStep("inner-down-5", bytes: [0x1b, 0x5b, 0x42]),
      SpecimenInputStep("inner-down-6", bytes: [0x1b, 0x5b, 0x42]),
      SpecimenInputStep("boundary-bubble", bytes: [0x1b, 0x5b, 0x42]),
      SpecimenInputStep("focus-inner-action", bytes: [0x09]),
      SpecimenInputStep("inner-home", bytes: [0x1b, 0x5b, 0x48]),
    ]
  }
}
