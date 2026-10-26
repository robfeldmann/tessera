import ArgumentParser
import Foundation
import TesseraTerminal

/// A command ArgumentParser parses and the harness then runs.
///
/// The conforming type declares what the command accepts; ``execute(in:)`` is what it does.
/// It stays apart from ArgumentParser's `run()` so that a command returns what it printed
/// instead of printing it, which lets a test run one without a process.
protocol HarnessCommand: ParsableCommand {
  /// The options of the command that take one value and may be given at most once, spelled
  /// with their dashes, such as `--repeat`. `HarnessCLI` rejects a second one before
  /// ArgumentParser, which would keep the last, parses; a test fails when the command declares
  /// an option that this does not list.
  static var singleValueOptions: [String] { get }

  /// Runs the command and returns what it printed and how it ended.
  @MainActor
  func execute(in context: HarnessCLI.Context) async -> CommandOutput
}

extension HarnessCommand {
  static var singleValueOptions: [String] { [] }
}

extension HarnessCLI {
  /// What a parsed command runs against.
  struct Context {
    var asJSON: Bool
    var configuration: TerminalApplicationConfiguration
    var environment: [String: String]
    var registry: ApplicationRegistry
    var terminals: (input: Bool, output: Bool)
  }

  /// The command line before any command: it has no behavior of its own, so a command line
  /// that parses to it named no command.
  struct Root: ParsableCommand {
    static var configuration: CommandConfiguration {
      CommandConfiguration(
        commandName: Invocation.current.executableName,
        abstract: "List, launch, run, picture, and check the registered applications.",
        discussion: """
          Every command exits 0 on success, 1 when an expectation failed, 2 on a usage or \
          parse error, and 3 on a harness error. When standard output is not a terminal each \
          command writes one JSON object to it; --json forces that form and --pretty forces \
          the text form.

          `--generate-completion-script SHELL` prints a completion script for fish, zsh, or \
          bash. It completes the commands, their flags, and the registered application names.
          """,
        subcommands: HarnessCLI.commands.map { $0 as any ParsableCommand.Type })
    }

    @OptionGroup var output: OutputOptions
  }

  /// Completes an argument that names a registered application, by asking the executable at
  /// completion time, so no list can fall out of date.
  static let appNameCompletion = CompletionKind.custom { _, _, _ in
    Invocation.current.appNames
  }
}

/// The flags that choose between a command's JSON object and its text form.
///
/// ArgumentParser accepts, documents, and completes them, and rejects the two together. The
/// form itself is read from the raw arguments by ``prefersJSON(_:outputIsTerminal:)``: a parse
/// that fails must still be reported in the form the caller asked for.
struct OutputOptions: ParsableArguments {
  @Flag var form: OutputForm?
}

enum OutputForm: String, EnumerableFlag {
  case json, pretty

  /// The flag spellings, as typed.
  static let spellings = allCases.map { "--\($0.rawValue)" }

  static func help(for value: Self) -> ArgumentHelp? {
    switch value {
    case .json: "Print one JSON object, even on a terminal."
    case .pretty: "Print the text form, even when output is not a terminal."
    }
  }

  /// Whether `arguments` ask for the JSON object: `--json` does, `--pretty` does not, and
  /// with neither it is the case exactly when standard output is not a terminal. Both flags
  /// contradict each other and ask for text, so the error that says so can be read.
  static func prefersJSON(_ arguments: [String], outputIsTerminal: Bool) -> Bool {
    switch (arguments.contains("--json"), arguments.contains("--pretty")) {
    case (true, false): true
    case (false, true), (true, true): false
    case (false, false): !outputIsTerminal
    }
  }
}

struct AppsCommand: HarnessCommand {
  /// `apps`' JSON object.
  private struct Listing: Encodable {
    /// One application. `minimum` is written as `null` when the app declares none, so every
    /// entry has the same three keys.
    struct App: Encodable {
      enum CodingKeys: String, CodingKey {
        case minimum, name, viewports
      }

      var minimum: String?
      var name: String
      var viewports: [String]

      func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(minimum, forKey: .minimum)
        try container.encode(name, forKey: .name)
        try container.encode(viewports, forKey: .viewports)
      }
    }

    var apps: [App]
    var command = "apps"
  }

  static let configuration = CommandConfiguration(
    commandName: "apps",
    abstract: "List the registered applications.",
    discussion: """
      Lists every registered application with the smallest size it declares and the \
      viewports it is checked at. The JSON form is {"apps": [{"minimum", "name", \
      "viewports"}], "command": "apps"}, sorted by name, where "minimum" is null for an \
      application that declares none. A name registered twice fails the command with exit 3.
      """)

  @OptionGroup var output: OutputOptions

  func execute(in context: HarnessCLI.Context) -> CommandOutput {
    let entries: [ApplicationRegistry.Entry]
    do {
      entries = try context.registry.checkedEntries()
    } catch {
      return HarnessCLI.failure(
        error.description, exitCode: 3, command: "apps", json: context.asJSON)
    }

    if context.asJSON {
      let listing = Listing(
        apps: entries.map { entry in
          Listing.App(
            minimum: entry.minimum.map { "\($0.columns)x\($0.rows)" },
            name: entry.name,
            viewports: entry.viewports.map(\.name))
        })
      return CommandOutput(exitCode: 0, stdout: HarnessCLI.encode(listing) + "\n")
    }

    guard !entries.isEmpty else {
      return CommandOutput(exitCode: 0, stdout: "no applications are registered\n")
    }
    let nameWidth = max("NAME".count, entries.map(\.name.count).max() ?? 0)
    let minimums = entries.map { $0.minimum.map { "\($0.columns)x\($0.rows)" } ?? "-" }
    let minimumWidth = max("MINIMUM".count, minimums.map(\.count).max() ?? 0)
    func row(_ name: String, _ minimum: String, _ viewports: String) -> String {
      name.padding(toLength: nameWidth, withPad: " ", startingAt: 0) + "  "
        + minimum.padding(toLength: minimumWidth, withPad: " ", startingAt: 0) + "  "
        + viewports
    }
    var lines = [row("NAME", "MINIMUM", "VIEWPORTS")]
    for (entry, minimum) in zip(entries, minimums) {
      lines.append(
        row(entry.name, minimum, entry.viewports.map(\.name).joined(separator: ", ")))
    }
    return CommandOutput(exitCode: 0, stdout: lines.joined(separator: "\n") + "\n")
  }
}

struct LaunchCommand: HarnessCommand {
  static let configuration = CommandConfiguration(
    commandName: "launch",
    abstract: "Run one application in this terminal.",
    discussion: """
      Runs the named application at the terminal's size, until the application finishes. \
      The harness has no quit key of its own: the application decides which key quits.

      Exits 2 for an unknown name, and 3 for a duplicate registration or when standard \
      input or output is not a terminal.

      When the environment variable TESSERA_TRACE names a file, the session writes its \
      trace there, one JSON record per step, so `replay` can run it again. A file that \
      cannot be created is exit 3, before the terminal changes mode. The trace is not \
      promised to stay as it is.
      """)

  @OptionGroup var output: OutputOptions

  @Argument(
    help: "The application to run, as `apps` lists it.",
    completion: HarnessCLI.appNameCompletion)
  var name: String

  @MainActor
  func execute(in context: HarnessCLI.Context) async -> CommandOutput {
    let entry: ApplicationRegistry.Entry
    do {
      entry = try context.registry.entry(named: name)
    } catch {
      return HarnessCLI.registryFailure(error, command: "launch", json: context.asJSON)
    }
    guard context.terminals.input, context.terminals.output else {
      let missing =
        switch context.terminals {
        case (false, false): "standard input and output are not terminals"
        case (false, true): "standard input is not one"
        default: "standard output is not one"
        }
      return HarnessCLI.failure(
        "`launch` runs an application in this terminal, and \(missing)",
        exitCode: 3, command: "launch", json: context.asJSON)
    }
    var trace: TraceWriter?
    if let path = context.environment["TESSERA_TRACE"], !path.isEmpty {
      do {
        trace = try TraceWriter(path: path)
      } catch {
        return HarnessCLI.failure(
          error.description, exitCode: 3, command: "launch", json: context.asJSON)
      }
    }
    do {
      try await entry.live(context.configuration, trace)
    } catch {
      trace?.close()
      return HarnessCLI.failure(
        "`launch \(name)` could not run in this terminal: \(error)",
        exitCode: 3, command: "launch", json: context.asJSON)
    }
    trace?.close()
    if let message = trace?.failure {
      return HarnessCLI.failure(
        message, exitCode: 3, command: "launch", json: context.asJSON)
    }
    return CommandOutput(exitCode: 0)
  }
}
