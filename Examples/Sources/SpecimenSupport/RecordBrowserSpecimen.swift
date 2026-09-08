import Tessera

/// A realistic synthetic record/detail browser with app-owned selection and detail state.
///
/// The action reducer is deliberately explicit: the graph never observes this model and the
/// host calls `ApplicationDriver.update()` only at its documented update boundary.
package final class RecordBrowserSpecimen {
  package enum Action: Sendable {
    case select(Int)
  }

  package struct Record: Identifiable {
    package let id: Int
    package let title: String
    package let summary: String
  }

  package let records = [
    Record(id: 1, title: "North star", summary: "A compact navigation record."),
    Record(id: 2, title: "Waypoint", summary: "The selected detail remains app-owned."),
    Record(id: 3, title: "Harbor", summary: "Synthetic data keeps captures safe."),
  ]
  package var selectedID: Int? = 1
  package var focused: FocusID?
  package var panes = [
    SplitViewPane(
      id: "records",
      sizing: SplitViewPaneSizing(minimum: 18, requestedIdeal: 28, maximum: 40)
    ),
    SplitViewPane(
      id: "record-detail",
      sizing: SplitViewPaneSizing(minimum: 20, requestedIdeal: 48)
    ),
  ]
  package var resizingEnabled = true

  private var focusBinding: Binding<FocusID?> {
    Binding(get: { self.focused }, set: { self.focused = $0 })
  }

  package var content: some View {
    SplitView(
      panes: Binding(get: { self.panes }, set: { self.panes = $0 }),
      keyboardResizingEnabled: Binding(
        get: { self.resizingEnabled }, set: { self.resizingEnabled = $0 }
      )
    ) {
      VStack(alignment: .leading, spacing: 1) {
        Text("Records").bold()
        ForEach(records) { record in
          Button(record.title) { self.send(.select(record.id)) }
            .focusable(FocusID("record-\(record.id)"))
            .focused(self.focusBinding, equals: FocusID("record-\(record.id)"))
            .automationID("record-\(record.id)", role: .button)
        }
      }
      .padding(1)
      if let record = records.first(where: { $0.id == selectedID }) {
        VStack(alignment: .leading, spacing: 1) {
          Text(record.title).bold()
          Text(record.summary).wrapped(.word)
          Text("ID \(record.id)").style(Style().dim())
        }
        .padding(1)
      } else {
        Text("No record selected").padding(1)
      }
    }
  }

  package var state: [String: String] {
    [
      "selectedID": selectedID.map(String.init) ?? "none",
      "focused": focused.map(String.init(describing:)) ?? "none",
      "paneIdeals": panes.map { String($0.sizing.requestedIdeal) }.joined(separator: ","),
      "resizingEnabled": String(resizingEnabled),
    ]
  }
  package init() {}

  package static func input(_ size: TerminalSize) -> [SpecimenInputStep] {
    let dividerColumn = size.columns >= 80 ? 30 : 18
    let startX = dividerColumn + 1
    let endX = min(startX + 8, size.columns - 1)
    return [
      SpecimenInputStep("focus-record-1", bytes: [0x09]),
      SpecimenInputStep("focus-record-2", bytes: [0x09]),
      SpecimenInputStep("open-record-2", bytes: [0x0d]),
      SpecimenInputStep(
        "divider-down", bytes: Array("\u{1b}[<0;\(startX);2M".utf8)),
      SpecimenInputStep(
        "divider-drag", bytes: Array("\u{1b}[<32;\(endX);2M".utf8)),
      SpecimenInputStep(
        "divider-up", bytes: Array("\u{1b}[<3;\(endX);2m".utf8)),
    ]
  }

  package func send(_ action: Action) {
    switch action {
    case .select(let id):
      selectedID = records.contains { $0.id == id } ? id : nil
    }
  }

}
