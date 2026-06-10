import TesseraTerminal

/// A walking-skeleton example that exercises Tessera's scoped terminal session.
@main
enum HelloTessera {
  static func main() async throws {
    try await TerminalSession.withApplicationTerminal(
      configuration: .default
    ) { terminal in
      var lastKey: Character = " "
      var shouldQuit = false

      try await render(lastKey: lastKey, to: terminal)

      while !shouldQuit {
        switch try await terminal.nextEvent() {
        case .quit:
          shouldQuit = true

        case .character(let character):
          lastKey = character
          try await render(lastKey: lastKey, to: terminal)
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
