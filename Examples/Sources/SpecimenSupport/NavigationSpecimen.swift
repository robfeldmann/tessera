import Tessera

/// A three-role navigation specimen with app-owned column visibility and compact preference.
package final class NavigationSpecimen {
  package var visibility: NavigationSplitViewVisibility = .all
  package var preferred = NavigationSplitViewColumn.content
  package var selection = "Overview"

  package var content: some View {
    NavigationSplitView(
      columnVisibility: Binding(
        get: { self.visibility }, set: { self.visibility = $0 }
      ),
      preferredCompactColumn: Binding(
        get: { self.preferred }, set: { self.preferred = $0 }
      ),
      sidebar: {
        VStack(alignment: .leading, spacing: 1) {
          Text("Catalog").bold()
          Button("Overview") { self.selection = "Overview" }
            .automationID("navigation-overview", role: .button)
          Button("Settings") { self.selection = "Settings" }
            .automationID("navigation-settings", role: .button)
          Button("Archive") { self.selection = "Archive" }
            .automationID("navigation-archive", role: .button)
        }
        .padding(1)
      },
      content: {
        VStack(alignment: .leading, spacing: 1) {
          Text("Selection").bold()
          Text(selection)
          Button("Show detail") {
            self.visibility = .all
            self.preferred = .detail
          }
          .automationID("navigation-show-detail", role: .button)
        }
        .padding(1)
      },
      detail: {
        VStack(alignment: .leading, spacing: 1) {
          Text("Detail").bold()
          Text("Details for \(selection)").wrapped(.word)
          Button("Compact content") {
            self.visibility = .doubleColumn
            self.preferred = .content
          }
          .automationID("navigation-compact-content", role: .button)
        }
        .padding(1)
      }
    )
  }

  package var state: [String: String] {
    [
      "visibility": String(visibility.rawValue),
      "preferred": String(describing: preferred),
      "selection": selection,
    ]
  }

  package init() {}

  package static func input(_ size: TerminalSize) -> [SpecimenInputStep] {
    [
      SpecimenInputStep("focus-settings", bytes: [0x09]),
      SpecimenInputStep("select-settings", bytes: [0x0d]),
      SpecimenInputStep("next-navigation", bytes: [0x09]),
      SpecimenInputStep("compact-content", bytes: [0x0d]),
      SpecimenInputStep("resize-wide", bytes: [0x1b, 0x5b, 0x36, 0x7e]),
    ]
  }
}
