import Tessera

/// A semantic input script used by live and headless hosts.
///
/// The bytes are intentionally kept at the terminal boundary: captures parse them with the
/// same `InputParser` used by the real terminal session rather than calling view handlers.
package struct SpecimenInputStep: Sendable {
  package let label: String
  package let bytes: [UInt8]

  package init(_ label: String, bytes: [UInt8]) {
    self.label = label
    self.bytes = bytes
  }
}

/// The application-owned state and driver for one specimen run.
package final class SpecimenSession {
  package let driver: ApplicationDriver
  package let state: () -> [String: String]
  package let input: (TerminalSize) -> [SpecimenInputStep]

  package init(
    driver: ApplicationDriver,
    state: @escaping () -> [String: String] = { [:] },
    input: @escaping (TerminalSize) -> [SpecimenInputStep] = { _ in [] }
  ) {
    self.driver = driver
    self.state = state
    self.input = input
  }
}

/// The complete set of examples accepted by the direct lab and capture CLI.
///
/// Keep this registry as the only selection point so a specimen cannot accidentally diverge
/// between live launch, replay, and artifact capture.
package enum SpecimenID: String, CaseIterable, Sendable {
  // This order is the stable live-host and capture-matrix contract, not alphabetical order.
  // swiftlint:disable sorted_enum_cases
  case layout
  case button
  case viewport
  case settings
  case collections
  case panes
  case navigation
  case records
  // swiftlint:enable sorted_enum_cases

  package var summary: String {
    switch self {
    case .layout: "Text and layout"
    case .button: "Controlled button"
    case .viewport: "Nested scrolling viewport"
    case .settings: "Small controlled settings editor"
    case .collections: "Keyed collection rows"
    case .panes: "Negotiated two-pane split"
    case .navigation: "Regular and compact navigation roles"
    case .records: "Record and detail browser"
    }
  }

  package var usesFocusTraversal: Bool {
    switch self {
    case .layout: false
    default: true
    }
  }
}

/// Creates application-owned specimen sessions for every host.
package enum SpecimenRegistry {
  package static var all: [SpecimenID] { Array(SpecimenID.allCases) }

  package static func id(_ rawValue: String) -> SpecimenID? {
    SpecimenID(rawValue: rawValue)
  }

  package static func make(_ id: SpecimenID, size: TerminalSize) -> SpecimenSession {
    switch id {
    case .layout:
      let model = LayoutSpecimen()
      return SpecimenSession(
        driver: ApplicationDriver(size: size) { model.content }
      ) { [model] in ["message": model.message] }
    case .button:
      let model = ButtonSpecimen()
      return SpecimenSession(
        driver: ApplicationDriver(size: size, focusTraversal: true) { model.content },
        state: { [model] in model.state },
        input: ButtonSpecimen.input
      )
    case .viewport:
      let model = ViewportSpecimen()
      return SpecimenSession(
        driver: ApplicationDriver(size: size, focusTraversal: true) { model.content },
        state: { [model] in model.state },
        input: ViewportSpecimen.input
      )
    case .settings:
      let model = SettingsSpecimen()
      return SpecimenSession(
        driver: ApplicationDriver(size: size, focusTraversal: true) { model.content },
        state: { [model] in model.state },
        input: SettingsSpecimen.input
      )
    case .collections:
      let model = CollectionsSpecimen()
      return SpecimenSession(
        driver: ApplicationDriver(size: size, focusTraversal: true) { model.content },
        state: { [model] in model.state },
        input: CollectionsSpecimen.input
      )
    case .panes:
      let model = PanesSpecimen()
      return SpecimenSession(
        driver: ApplicationDriver(size: size, focusTraversal: true) { model.content },
        state: { [model] in model.state },
        input: PanesSpecimen.input
      )
    case .navigation:
      let model = NavigationSpecimen()
      return SpecimenSession(
        driver: ApplicationDriver(size: size, focusTraversal: true) { model.content },
        state: { [model] in model.state },
        input: NavigationSpecimen.input
      )
    case .records:
      let model = RecordBrowserSpecimen()
      return SpecimenSession(
        driver: ApplicationDriver(size: size, focusTraversal: true) { model.content },
        state: { [model] in model.state },
        input: RecordBrowserSpecimen.input
      )
    }
  }
}
