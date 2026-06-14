import ExampleSupport
import TesseraTerminal

/// A walking-skeleton example that exercises Tessera's scoped terminal session.
@main
enum HelloTessera {
  static func main() async throws {
    guard TerminalExampleSupport.isRunningInInteractiveTerminal() else {
      TerminalExampleSupport.printTerminalRequiredMessage(
        applicationName: "HelloTessera",
        features: [
          "raw mode",
          "terminal size queries",
          "immediate keyboard input",
        ],
        runCommand: "swift run --package-path Examples HelloTessera",
        attachSchemeName: "HelloTessera (Attach)"
      )
      return
    }

    try await TerminalSession.withApplicationTerminal(
      configuration: .default
    ) { terminal in
      var lastKey: Character = " "
      var shouldQuit = false

      try await render(lastKey: lastKey, to: terminal)

      while !shouldQuit {
        switch try await terminal.nextEvent() {
        case .key(let key) where key == Key(code: .character("q")):
          shouldQuit = true

        case .key(let key):
          if key.modifiers.isEmpty, case .character(let character) = key.code {
            lastKey = character
            try await render(lastKey: lastKey, to: terminal)
          }

        case .resize, .unknown:
          break
        }
      }
    }
  }

  private static func render(
    lastKey: Character,
    to terminal: isolated TerminalSession
  ) async throws {
    try await terminal.draw { frame in
      frame.write(
        "Hello, Tessera. Press q to quit.",
        at: TerminalPosition(column: 0, row: 0)
      )
      frame.write(
        "You pressed: \(lastKey)",
        at: TerminalPosition(column: 0, row: 1)
      )
    }
  }
}
