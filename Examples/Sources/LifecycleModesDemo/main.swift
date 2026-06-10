import Foundation
import TesseraTerminal

@main
enum LifecycleModesDemo {
  static func main() async throws {
    writeLine("Before Tessera: cooked mode on the primary screen.")
    writeLine("Typing should echo normally here. Press Enter to start.")
    _ = readLine()

    try await TerminalSession.withApplicationTerminal(
      configuration: .default
    ) { terminal in
      var lastEvent = "none"
      var shouldQuit = false

      try await draw(terminal: terminal, lastEvent: lastEvent)

      try await withThrowingDiscardingTaskGroup { group in
        let (events, continuation) = AsyncStream.makeStream(
          of: DemoEvent.self,
          bufferingPolicy: .bufferingNewest(32)
        )

        group.addTask {
          do {
            while Task.isCancelled == false {
              continuation.yield(.input(try await terminal.nextEvent()))
            }
          } catch is CancellationError {
          } catch {
            continuation.finish()
          }
        }

        group.addTask {
          for await size in terminal.sizeChanges {
            continuation.yield(.resize(size))
          }
        }

        for await event in events {
          switch event {
          case .input(.quit):
            shouldQuit = true
            group.cancelAll()
            continuation.finish()

          case .input(.character(let character)):
            lastEvent = "key: \(character)"
            try await draw(terminal: terminal, lastEvent: lastEvent)

          case .resize:
            try await draw(terminal: terminal, lastEvent: lastEvent)
          }

          if shouldQuit {
            break
          }
        }

        group.cancelAll()
      }
    }

    writeLine("Back from Tessera: primary screen restored.")
    writeLine("Typing should echo normally again.")
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

private enum DemoEvent {
  case input(InputEvent)
  case resize(TerminalSize?)
}

private func writeLine(_ line: String) {
  FileHandle.standardOutput.write(Data("\(line)\n".utf8))
}
