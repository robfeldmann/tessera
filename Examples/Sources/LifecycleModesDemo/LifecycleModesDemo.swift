import ExampleSupport
import Foundation
import TesseraTerminal

@main
enum LifecycleModesDemo {
  static func main() async throws {
    guard TerminalExampleSupport.isRunningInInteractiveTerminal() else {
      TerminalExampleSupport.printTerminalRequiredMessage(
        applicationName: "LifecycleModesDemo",
        features: [
          "raw mode",
          "alternate screen",
          "terminal size queries",
          "immediate keyboard input",
        ],
        runCommand: "swift run --package-path Examples LifecycleModesDemo",
        attachSchemeName: "LifecycleModesDemo (Attach)"
      )
      return
    }

    writeLine("Before Tessera: cooked mode on the primary screen.")
    writeLine("Tessera will enter raw mode on the primary screen next.")

    let shouldEnterAltScreen = try await runRawPrimaryScreenStage()
    guard shouldEnterAltScreen else {
      writeLine("Back from Tessera: primary screen restored.")
      writeLine("Typing should echo normally again.")
      return
    }

    try await TerminalSession.withApplicationTerminal(
      configuration: .default
    ) { terminal in
      var lastEvent = "none"
      var shouldQuit = false

      try await draw(terminal: terminal, lastEvent: lastEvent)

      for await event in terminal.events {
        switch event {
        case .key(let key) where key == Key(code: .character("q")):
          shouldQuit = true

        case .key(let key):
          if key.modifiers.isEmpty, case .character(let character) = key.code {
            lastEvent = "key: \(character)"
          } else {
            lastEvent = "key: \(key.code) modifiers: \(key.modifiers.rawValue)"
          }
          try await draw(terminal: terminal, lastEvent: lastEvent)

        case .paste(let text):
          lastEvent = "paste: \(text.count) characters"
          try await draw(terminal: terminal, lastEvent: lastEvent)

        case .focusGained, .focusLost, .kittyGraphicsResponse,
          .kittyKeyboardEnhancementFlags, .mouse, .primaryDeviceAttributes,
          .privateModeStatus:
          lastEvent = "protocol event"
          try await draw(terminal: terminal, lastEvent: lastEvent)

        case .resize:
          terminal.invalidateRenderer()
          try await draw(terminal: terminal, lastEvent: lastEvent)

        case .unknown(let bytes):
          lastEvent =
            "unknown: \(bytes.map { String(format: "%02X", $0) }.joined(separator: " "))"
          try await draw(terminal: terminal, lastEvent: lastEvent)
        }

        if shouldQuit {
          break
        }
      }
    }

    writeLine("Back from Tessera: primary screen restored.")
    writeLine("Typing should echo normally again.")
  }

  private static func runRawPrimaryScreenStage() async throws -> Bool {
    writeLine("")
    writeLine("Inside Tessera: raw mode on the primary screen.")
    writeLine("Typed keys are reported immediately; press Enter for alternate screen.")
    writeLine("Press q here to leave without opening alternate screen.")

    var shouldEnterAltScreen = false
    try await TerminalSession.withApplicationTerminal(
      configuration: TerminalApplicationConfiguration(
        modes: [.rawMode],
        synchronizedOutput: .disabled
      )
    ) { terminal in
      for await event in terminal.events {
        switch event {
        case .key(let key) where key == Key(code: .enter):
          shouldEnterAltScreen = true
          return

        case .key(let key) where key == Key(code: .character("q")):
          shouldEnterAltScreen = false
          return

        case .key(let key):
          if key.modifiers.isEmpty, case .character(let character) = key.code {
            writeRawLine("raw key: \(character)")
          } else {
            writeRawLine("raw key: \(key.code) modifiers: \(key.modifiers.rawValue)")
          }

        case .paste(let text):
          writeRawLine("raw paste: \(text)")

        case .focusGained, .focusLost, .kittyGraphicsResponse,
          .kittyKeyboardEnhancementFlags, .mouse, .primaryDeviceAttributes,
          .privateModeStatus:
          writeRawLine("raw protocol event")

        case .resize:
          writeRawLine("raw resize")

        case .unknown(let bytes):
          let hexBytes = bytes.map { String(format: "%02X", $0) }.joined(separator: " ")
          writeRawLine("raw unknown: \(hexBytes)")
        }
      }
    }

    return shouldEnterAltScreen
  }

  private static func draw(
    terminal: isolated TerminalSession,
    lastEvent: String
  ) async throws {
    try await terminal.draw { frame in
      frame.write(
        "Inside Tessera: raw mode + alternate screen.",
        at: TerminalPosition(column: 0, row: 0)
      )
      frame.write(
        "Keystrokes are handled immediately; press q to leave.",
        at: TerminalPosition(column: 0, row: 1)
      )
      frame.write(
        "Resize this pane to update the size below.",
        at: TerminalPosition(column: 0, row: 2)
      )
      frame.write(
        "size: \(frame.size.columns)x\(frame.size.rows)",
        at: TerminalPosition(column: 0, row: 4)
      )
      frame.write(
        "last event: \(lastEvent)",
        at: TerminalPosition(column: 0, row: 5)
      )
    }
  }
}

private func writeLine(_ line: String) {
  TerminalExampleSupport.writeLine(line)
}

private func writeRawLine(_ line: String) {
  FileHandle.standardOutput.write(Data("\(line)\r\n".utf8))
}
