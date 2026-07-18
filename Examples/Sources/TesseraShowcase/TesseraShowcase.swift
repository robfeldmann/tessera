import ExampleSupport
import TesseraTerminal

public enum ShowcaseFixture: CaseIterable, Sendable {
  case compact
  case guardSize
  case regular
  case standard
  case standardShort

  public var size: TerminalSize {
    switch self {
    case .regular:
      TerminalSize(columns: 120, rows: 24)
    case .standard:
      TerminalSize(columns: 80, rows: 24)
    case .standardShort:
      TerminalSize(columns: 80, rows: 16)
    case .compact:
      TerminalSize(columns: 40, rows: 16)
    case .guardSize:
      TerminalSize(columns: 39, rows: 11)
    }
  }
}

public struct ShowcaseScript: Equatable, Sendable {
  public var events: [InputEvent]

  public init(events: [InputEvent]) {
    self.events = events
  }
}

public struct ShowcaseModel: Equatable, Sendable {
  public private(set) var eventCount = 0
  public private(set) var lastPaste = ""
  public private(set) var size: TerminalSize

  public init(size: TerminalSize) {
    self.size = size
  }

  public mutating func dispatch(_ script: ShowcaseScript) {
    for event in script.events {
      dispatch(event)
    }
  }

  public mutating func dispatch(_ event: InputEvent) {
    eventCount += 1
    switch event {
    case .paste(let text):
      lastPaste = text
    case .resize(let size):
      self.size = size
    case .focusGained, .focusLost, .key, .kittyGraphicsResponse,
      .kittyKeyboardEnhancementFlags, .mouse, .primaryDeviceAttributes,
      .privateModeStatus, .unknown:
      break
    }
  }

  public borrowing func render(into frame: borrowing Frame) {
    let renderSize = frame.size
    if renderSize.columns < 40 || renderSize.rows < 12 {
      frame.write(
        "Resize to at least 40x12",
        at: TerminalPosition(column: 0, row: 0)
      )
      return
    }

    frame.write("Tessera Showcase", at: TerminalPosition(column: 0, row: 0))
    frame.write(
      "Fixture: \(renderSize.columns)x\(renderSize.rows)",
      at: TerminalPosition(column: 0, row: 1)
    )
    frame.write(
      "Events: \(eventCount)",
      at: TerminalPosition(column: 0, row: 2)
    )
  }
}

@main
enum TesseraShowcase {
  static func main() async throws {
    guard TerminalExampleSupport.isRunningInInteractiveTerminal() else {
      TerminalExampleSupport.printTerminalRequiredMessage(
        applicationName: "TesseraShowcase",
        features: ["raw mode", "terminal resize events", "immediate keyboard input"],
        runCommand: "swift run --package-path Examples TesseraShowcase",
        attachSchemeName: "TesseraShowcase (Attach)"
      )
      return
    }

    let configuration = TerminalApplicationConfiguration.default
    try await TerminalSession.withApplicationTerminal(
      configuration: configuration,
      run
    )
  }

  private static func run(terminal: isolated TerminalSession) async throws -> sending Void
  {
    var model = ShowcaseModel(size: ShowcaseFixture.standard.size)
    try await render(model, to: terminal)

    while true {
      let event = try await terminal.nextEvent()
      if case .key(let key) = event, key == Key(code: .character("q")) {
        return
      }
      model.dispatch(event)
      try await render(model, to: terminal)
    }
  }

  private static func render(
    _ model: borrowing ShowcaseModel,
    to terminal: isolated TerminalSession
  ) async throws {
    try await terminal.draw { frame in
      model.render(into: frame)
    }
  }
}
