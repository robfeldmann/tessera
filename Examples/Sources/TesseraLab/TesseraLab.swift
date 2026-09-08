import ArgumentParser
import ExampleSupport
import Foundation
import SpecimenSupport
import Tessera

/// Direct specimen entry point; selection and validation precede terminal mode changes.
@main
struct TesseraLab: AsyncParsableCommand {
  struct List: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "List registered specimens.")
    func run() throws {
      let output = SpecimenRegistry.all
        .map { "\($0.rawValue)\t\($0.summary)" }
        .joined(separator: "\n")
        .appending("\n")
      FileHandle.standardOutput.write(Data(output.utf8))
    }
  }

  struct Run: AsyncParsableCommand {
    @Argument(help: "The registered specimen name.")
    var specimen: String

    mutating func validate() throws {
      guard SpecimenRegistry.id(specimen) != nil else {
        throw ValidationError(
          "Choose one of: \(SpecimenRegistry.all.map(\.rawValue).joined(separator: ", "))."
        )
      }
    }

    func run() async throws {
      guard TerminalExampleSupport.isRunningInInteractiveTerminal() else {
        throw ValidationError("Live specimens require an interactive terminal.")
      }
      guard let id = SpecimenRegistry.id(specimen) else {
        throw ValidationError("Unknown specimen \(specimen).")
      }
      try await TerminalSession.withApplicationTerminal(
        configuration: .default
      ) { terminal in
        // The first real resize event updates this initial proposal before its next frame.
        let session = SpecimenRegistry.make(
          id, size: TerminalSize(columns: 80, rows: 24))
        try await session.driver.present(to: terminal)
        while session.driver.step(try await terminal.nextEvent()) {
          try await session.driver.present(to: terminal)
        }
      }
    }
  }

  static let configuration = CommandConfiguration(
    commandName: "TesseraLab",
    abstract: "Run a registered Tessera specimen directly.",
    subcommands: [List.self, Run.self]
  )
}
