import ExampleSupport
import SpecimenSupport
import Tessera

/// Direct specimen entry point; case selection happens before entering terminal mode.
@main
enum TesseraLab {
  enum CommandError: Error {
    case terminalRequired
    case usage
  }

  static func main() async throws {
    guard Array(CommandLine.arguments.dropFirst()) == ["run", "layout"] else {
      throw CommandError.usage
    }
    guard TerminalExampleSupport.isRunningInInteractiveTerminal() else {
      throw CommandError.terminalRequired
    }
    try await TerminalSession.withApplicationTerminal(
      configuration: .default
    ) { terminal in
      let model = LayoutSpecimen()
      let driver = ApplicationDriver(size: TerminalSize(columns: 1, rows: 1)) {
        model.content
      }
      try await driver.present(to: terminal)
      while driver.step(try await terminal.nextEvent()) {
        try await driver.present(to: terminal)
      }
    }
  }
}
