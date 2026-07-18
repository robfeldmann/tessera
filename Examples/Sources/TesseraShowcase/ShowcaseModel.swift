import Tessera

enum ShowcaseCatalogSelection: String, Sendable {
  case text = "Text"
}

enum ShowcaseViewportRole: String, Sendable {
  case compact
  case guardSize = "resize guard"
  case regular
}

/// App-owned Showcase state. Runtime nodes retain only ephemeral UI state.
final class ShowcaseModel {
  private(set) var eventCount = 0
  private(set) var lastPaste = ""
  private(set) var size: TerminalSize
  var catalogSelection: ShowcaseCatalogSelection = .text
  var controlValue = false
  var isSpecimenVisible = true

  var viewportRole: ShowcaseViewportRole {
    if size.columns < 40 || size.rows < 12 {
      return .guardSize
    }
    return size.columns < 80 ? .compact : .regular
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
}
