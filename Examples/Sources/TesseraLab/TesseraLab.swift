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
    let arguments = Array(CommandLine.arguments.dropFirst())
    guard arguments.count == 2, arguments[0] == "run",
      ["layout", "button"].contains(arguments[1])
    else {
      throw CommandError.usage
    }
    guard TerminalExampleSupport.isRunningInInteractiveTerminal() else {
      throw CommandError.terminalRequired
    }
    try await TerminalSession.withApplicationTerminal(
      configuration: .default
    ) { terminal in
      let driver: ApplicationDriver
      let initialSize = TerminalSize(columns: 1, rows: 1)
      if arguments[1] == "button" {
        let model = ButtonSpecimen()
        driver = ApplicationDriver(size: initialSize, focusTraversal: true) {
          model.content
        }
      } else {
        let model = LayoutSpecimen()
        driver = ApplicationDriver(size: initialSize) { model.content }
      }
      try await driver.present(to: terminal)
      while driver.step(try await terminal.nextEvent()) {
        try await driver.present(to: terminal)
      }
    }
  }
}
