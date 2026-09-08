import ArgumentParser
import ExampleSupport
import SpecimenSupport
import Tessera

/// Direct specimen entry point; selection and validation precede terminal mode changes.
@main
struct TesseraLab: AsyncParsableCommand {
  struct Run: AsyncParsableCommand {
    @Argument(help: "The specimen: layout or button.")
    var specimen: String

    mutating func validate() throws {
      guard ["layout", "button"].contains(specimen) else {
        throw ValidationError("Choose layout or button.")
      }
    }

    func run() async throws {
      guard TerminalExampleSupport.isRunningInInteractiveTerminal() else {
        throw ValidationError("Live specimens require an interactive terminal.")
      }
      let specimen = specimen
      try await TerminalSession.withApplicationTerminal(
        configuration: .default
      ) { terminal in
        let driver: ApplicationDriver
        let initialSize = TerminalSize(columns: 1, rows: 1)
        if specimen == "button" {
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

  static let configuration = CommandConfiguration(
    commandName: "TesseraLab",
    abstract: "Run a small Tessera specimen directly.",
    subcommands: [Run.self]
  )
}
