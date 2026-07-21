import Tessera

enum ShowcaseCatalogSelection: String, Sendable {
  case text = "Text"
}

enum ShowcaseViewportRole: String, Sendable {
  case compact = "one role"
  case guardSize = "resize guard"
  case regular = "three roles"
  case standard = "two roles"
}

/// App-owned Showcase state. Runtime nodes retain only ephemeral UI state.
final class ShowcaseModel {
  private(set) var eventCount = 0
  private(set) var lastPaste = ""
  private(set) var size: TerminalSize
  var catalogSelection: ShowcaseCatalogSelection = .text
  var controlValue = false
  var isSpecimenVisible = true
  var splitAxis: Axis = .horizontal
  var widePanes = [
    SplitViewPane(
      id: "catalog",
      sizing: SplitViewPaneSizing(minimum: 23, requestedIdeal: 24, maximum: 24)
    ),
    SplitViewPane(
      id: "playground",
      sizing: SplitViewPaneSizing(minimum: 23, requestedIdeal: 70)
    ),
    SplitViewPane(
      id: "inspector",
      sizing: SplitViewPaneSizing(minimum: 23, requestedIdeal: 24, maximum: 24)
    ),
  ]
  var standardPanes = [
    SplitViewPane(
      id: "catalog",
      sizing: SplitViewPaneSizing(minimum: 23, requestedIdeal: 24, maximum: 24)
    ),
    SplitViewPane(
      id: "playground",
      sizing: SplitViewPaneSizing(minimum: 23, requestedIdeal: 70)
    ),
  ]
  var catalogOffset = TerminalPosition(column: 0, row: 0)
  var playgroundOffset = TerminalPosition(column: 0, row: 0)
  var inspectorOffset = TerminalPosition(column: 0, row: 0)
  var compactOffset = TerminalPosition(column: 0, row: 0)

  var viewportRole: ShowcaseViewportRole {
    if size.columns < 23 || size.rows < 10 {
      return .guardSize
    }
    if size.columns < 48 {
      return .compact
    }
    return size.columns < 73 ? .standard : .regular
  }

  init(size: TerminalSize) {
    self.size = size
  }

  func dispatch(_ script: ShowcaseScript) {
    for event in script.events {
      dispatch(event)
    }
  }

  func dispatch(_ event: InputEvent) {
    eventCount += 1
    switch event {
    case .paste(let text):
      lastPaste = text
    case .resize(let size):
      resize(to: size)
    case .focusGained, .focusLost, .key, .kittyGraphicsResponse,
      .kittyKeyboardEnhancementFlags, .mouse, .primaryDeviceAttributes,
      .privateModeStatus, .unknown:
      break
    }
  }

  func resize(to size: TerminalSize) {
    self.size = size
  }

  func binding<Value>(
    _ keyPath: ReferenceWritableKeyPath<ShowcaseModel, Value>
  ) -> Binding<Value> {
    Binding(
      get: { self[keyPath: keyPath] },
      set: { self[keyPath: keyPath] = $0 }
    )
  }
}
