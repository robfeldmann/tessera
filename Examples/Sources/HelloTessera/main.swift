import TesseraTerminal

/// A walking-skeleton example that exercises Tessera's terminal stack end to end.
///
/// The example enters raw mode and the alternate screen, renders a greeting into a
/// buffer, updates the screen as printable keys are pressed, and exits cleanly when
/// `q` is pressed. It intentionally stays small so each terminal layer remains easy
/// to inspect while the library API evolves.
@main
enum HelloTessera {
  static func main() async throws {
    let io = PlatformIO()
    var rawModeEntered = false
    var altScreenEntered = false

    do {
      try await io.enterRawMode()
      rawModeEntered = true

      try await io.enterAltScreen()
      altScreenEntered = true

      try await run(io: io)

      try await io.exitAltScreen()
      altScreenEntered = false

      try await io.exitRawMode()
      rawModeEntered = false
    } catch {
      if altScreenEntered {
        try? await io.exitAltScreen()
      }
      if rawModeEntered {
        try? await io.exitRawMode()
      }
      throw error
    }
  }

  private static func run(io: PlatformIO) async throws {
    let terminalSize = try await io.size
    var buffer = Buffer(size: terminalSize)
    var lastKey: Character = " "

    try await render(buffer: &buffer, lastKey: lastKey, to: io)

    for await byte in io.bytes {
      switch InputParser.parse(byte) {
      case .quit:
        return
      case .character(let character):
        lastKey = character
        try await render(buffer: &buffer, lastKey: lastKey, to: io)
      case nil:
        continue
      }
    }
  }

  private static func render(
    buffer: inout Buffer,
    lastKey: Character,
    to io: PlatformIO
  ) async throws {
    buffer.clear()
    buffer.write(
      "Hello, Tessera. Press q to quit.",
      at: TerminalPosition(column: 0, row: 0)
    )
    buffer.write(
      "You pressed: \(lastKey)",
      at: TerminalPosition(column: 0, row: 1)
    )
    try await io.write(Renderer.render(buffer))
  }
}
