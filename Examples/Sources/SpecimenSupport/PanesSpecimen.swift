import Tessera

/// A two-pane specimen using negotiated pane constraints, hover, and persistent selection.
package final class PanesSpecimen {
  package var selected = 0
  package var panes = [
    SplitViewPane(
      id: "list",
      sizing: SplitViewPaneSizing(minimum: 18, requestedIdeal: 26, maximum: 40)
    ),
    SplitViewPane(
      id: "detail",
      sizing: SplitViewPaneSizing(minimum: 20, requestedIdeal: 42, maximum: nil)
    ),
  ]
  package var axis: Axis = .horizontal
  package var resizingEnabled = true
  package var isHovered = false

  package var content: some View {
    SplitView(
      axis: Binding(get: { self.axis }, set: { self.axis = $0 }),
      panes: Binding(get: { self.panes }, set: { self.panes = $0 }),
      keyboardResizingEnabled: Binding(
        get: { self.resizingEnabled }, set: { self.resizingEnabled = $0 }
      )
    ) {
      VStack(alignment: .leading, spacing: 1) {
        Text("Records").bold()
        Button("First") { self.selected = 0 }
          .automationID("pane-first", role: .button)
        Button("Second") { self.selected = 1 }
          .automationID("pane-second", role: .button)
        Button("Third") { self.selected = 2 }
          .automationID("pane-third", role: .button)
      }
      .padding(1)
      VStack(alignment: .leading, spacing: 1) {
        Text("Detail").bold()
        Text("Selected record: \(selected)").wrapped(.word)
        Text("Drag the divider or use the adjacent-pair keys.").style(Style().dim())
        Text(isHovered ? "Pointer: inside" : "Pointer: outside")
          .automationID("pane-hover-region", role: .text)
          .onHover { isHovered, _ in self.isHovered = isHovered }
      }
      .padding(1)
    }
  }

  package var state: [String: String] {
    [
      "selected": String(selected),
      "axis": String(describing: axis),
      "resizingEnabled": String(resizingEnabled),
      "hovered": String(isHovered),
      "collapsed": panes.map { String($0.isCollapsed) }.joined(separator: ","),
    ]
  }

  package init() {}

  package static func input(_ size: TerminalSize) -> [SpecimenInputStep] {
    [
      SpecimenInputStep("focus-second", bytes: [0x09]),
      SpecimenInputStep("select-second", bytes: [0x0d]),
      SpecimenInputStep("resize-right", bytes: [0x1b, 0x5b, 0x43]),
      SpecimenInputStep("resize-left", bytes: [0x1b, 0x5b, 0x44]),
    ]
  }
}
