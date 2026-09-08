import Tessera

/// A keyed collection specimen with grouped rows, a fixed grid, and tabular output.
package final class CollectionsSpecimen {
  package struct Row: Identifiable {
    package let id: Int
    package let title: String
    package let detail: String
  }

  package var rows = [
    Row(id: 1, title: "Inbox", detail: "Three unread records"),
    Row(id: 2, title: "Today", detail: "Two scheduled records"),
    Row(id: 3, title: "Archive", detail: "Long-lived synthetic history"),
    Row(id: 4, title: "Empty", detail: "No child rows"),
  ]
  package var selectedID: Int?

  package var content: some View {
    VStack(alignment: .leading, spacing: 1) {
      Section("Collections", spacing: 1) {
        List(
          rows,
          selection: Binding(get: { self.selectedID }, set: { self.selectedID = $0 }),
          emptyMessage: "No records"
        ) { row in
          Button(
            action: { self.selectedID = row.id },
            label: {
              VStack(alignment: .leading, spacing: 0) {
                Text(row.title)
                Text(row.detail).style(Style().dim())
              }
            }
          )
          .automationID("collection-row-\(row.id)", role: .button)
        }
      }
      Grid(columns: [.fill(1), .fill(1)], spacing: 1) {
        Text("Grid A")
        Text("Grid B")
        Text("Grid C")
        Text("Grid D")
      }
      Table(
        rows,
        selection: Binding(get: { self.selectedID }, set: { self.selectedID = $0 }),
        columns: [
          TableColumn("Title", constraint: .fill(2)) { $0.title },
          TableColumn("Detail", constraint: .fill(3)) { $0.detail },
        ]
      ) { self.selectedID = $0.id }
    }
    .padding(1)
  }

  package var state: [String: String] {
    [
      "rowCount": String(rows.count),
      "selectedID": selectedID.map(String.init) ?? "none",
    ]
  }

  package init() {}

  package static func input(_ size: TerminalSize) -> [SpecimenInputStep] {
    [
      SpecimenInputStep("next-row", bytes: [0x09]),
      SpecimenInputStep("select-row", bytes: [0x0d]),
      SpecimenInputStep("scroll-rows", bytes: [0x1b, 0x5b, 0x42]),
      SpecimenInputStep("resize", bytes: [0x1b, 0x5b, 0x36, 0x7e]),
    ]
  }
}
