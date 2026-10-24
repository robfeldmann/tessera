import ArgumentParser
import Foundation
import TesseraTerminal

/// The command line over an ``ApplicationRegistry``.
///
/// A development executable registers its applications and calls ``main(registry:)``:
///
/// ```swift
/// var registry = ApplicationRegistry()
/// registry.register("browser", viewports: [.desktop]) { Browser() }
/// await HarnessCLI.main(registry: registry)
/// ```
///
/// The commands are `apps` (list the registry), `launch NAME` (run one application in this
/// terminal), `run PATH...` (run scenario files, with `--record`, `--repeat N`, and
/// `--timing`), `shot NAME [SIZE]` and `tree NAME [SIZE]` (print one application's screen or
/// node tree), and `help [COMMAND]`.
///
/// Exit codes are 0 for success, 1 when an expectation failed, 2 for a usage or parse error,
/// and 3 for a harness error. When standard output is not a terminal, each command writes one
/// JSON object to it; `--json` forces that form and `--pretty` forces the text form.
///
/// The executable also prints a completion script for fish, zsh, and bash, which completes
/// the registered application names: `--generate-completion-script SHELL`.
public enum HarnessCLI {
  /// Runs the command in the process's arguments and exits with its status.
  ///
  /// - Parameter registry: The applications the commands can list and launch.
  @MainActor
  public static func main(registry: ApplicationRegistry) async -> Never {
    let output = await run(
      arguments: Array(CommandLine.arguments.dropFirst()),
      registry: registry,
      inputIsTerminal: StandardStreams.inputIsTerminal,
      outputIsTerminal: StandardStreams.outputIsTerminal,
      configuration: .default,
      executableName: ProcessInfo.processInfo.processName,
      columns: nil
    )
    if !output.stdout.isEmpty {
      FileHandle.standardOutput.write(Data(output.stdout.utf8))
    }
    if !output.stderr.isEmpty {
      FileHandle.standardError.write(Data(output.stderr.utf8))
    }
    exit(output.exitCode)
  }
}

/// What a command printed and how it ended.
struct CommandOutput: Equatable {
  var exitCode: Int32
  var stdout = ""
  var stderr = ""
}

extension HarnessCLI {
  /// What the commands read while ArgumentParser builds them and writes their help.
  ///
  /// ArgumentParser creates a command by calling its initializer, and reads its configuration
  /// and completion closures with no argument of ours, so the executable's name and the
  /// registered names reach them through a task-local value instead.
  struct Invocation: Sendable {
    @TaskLocal static var current = Self()

    var appNames: [String] = []
    var executableName = "tessera"
  }

  /// A failed command. `command` is written as `null` when the failure precedes naming one.
  private struct Failure: Encodable {
    enum CodingKeys: String, CodingKey {
      case command, exitCode, message
    }

    var command: String?
    var exitCode: Int32
    var message: String

    func encode(to encoder: any Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(command, forKey: .command)
      try container.encode(exitCode, forKey: .exitCode)
      try container.encode(message, forKey: .message)
    }
  }

  static let commands: [any HarnessCommand.Type] = [
    AppsCommand.self, LaunchCommand.self, RunCommand.self, ShotCommand.self,
    TreeCommand.self,
  ]

  /// The words that name a command: the commands, then ArgumentParser's `help`.
  static var commandNames: [String] {
    // A key path through an existential metatype crashes the Swift 6.3 compiler in SILGen.
    // swiftlint:disable:next prefer_key_path
    commands.map { $0._commandName } + ["help"]
  }

  /// Runs one command and returns what it printed, without touching the process.
  ///
  /// `launch` needs a terminal on both ends, so it refuses to start unless `inputIsTerminal`
  /// and `outputIsTerminal` are both `true`; this keeps a test or a pipe from ever opening a
  /// live session, and fails before the terminal changes mode rather than after.
  ///
  /// - Parameters:
  ///   - executableName: What usage and completion scripts call the executable.
  ///   - columns: The width help text wraps at, or `nil` for the terminal's width.
  @MainActor
  static func run(
    arguments: [String],
    registry: ApplicationRegistry,
    inputIsTerminal: Bool,
    outputIsTerminal: Bool,
    configuration: TerminalApplicationConfiguration,
    executableName: String = "tessera",
    columns: Int? = 80
  ) async -> CommandOutput {
    let invocation = Invocation(
      appNames: (try? registry.names()) ?? [], executableName: executableName)
    return await Invocation.$current.withValue(invocation) {
      // The form comes from the raw arguments, not the parsed command: a parse that fails
      // must still be reported in the form the caller asked for.
      let asJSON = OutputForm.prefersJSON(arguments, outputIsTerminal: outputIsTerminal)

      // ArgumentParser reports an unknown command word as an unexpected argument, and
      // `help ghost` as the overview. Both are usage errors that list the commands here.
      if let unknown = unknownCommand(in: arguments, json: asJSON) {
        return unknown
      }

      let parsed: any ParsableCommand
      do {
        parsed = try Root.parseAsRoot(arguments)
      } catch {
        return parseFailure(error, arguments: arguments, columns: columns, json: asJSON)
      }
      switch parsed {
      case let command as any HarnessCommand:
        return await command.execute(
          in: Context(
            asJSON: asJSON,
            configuration: configuration,
            registry: registry,
            terminals: (input: inputIsTerminal, output: outputIsTerminal)))
      case is Root:
        return usage(
          "a command is required; accepted: \(commandNames.joined(separator: ", "))",
          command: nil, json: asJSON)
      default:
        // ArgumentParser's own `help`, which throws the help request it was given.
        var help = parsed
        do {
          try help.run()
        } catch {
          return parseFailure(error, arguments: arguments, columns: columns, json: asJSON)
        }
        return CommandOutput(exitCode: 0)
      }
    }
  }

  // MARK: Output

  static func encode(_ value: some Encodable) -> String {
    JSONText.string(for: value)
  }

  static func usage(_ message: String, command: String?, json: Bool) -> CommandOutput {
    failure(message, exitCode: 2, command: command, json: json)
  }

  /// The failure for a name the registry cannot answer: an unknown name is a usage error and
  /// a duplicate registration a harness error.
  static func registryFailure(_ error: RegistryError, command: String, json: Bool)
    -> CommandOutput
  {
    let exitCode: Int32 =
      switch error {
      case .duplicate: 3
      case .unknown: 2
      }
    return failure(error.description, exitCode: exitCode, command: command, json: json)
  }

  static func failure(
    _ message: String, exitCode: Int32, command: String?, json: Bool
  ) -> CommandOutput {
    if json {
      let body = Failure(command: command, exitCode: exitCode, message: message)
      return CommandOutput(exitCode: exitCode, stdout: encode(body) + "\n")
    }
    return CommandOutput(exitCode: exitCode, stderr: "error: \(message)\n")
  }

  // MARK: Parsing

  /// The arguments that are not output flags, which may stand anywhere.
  private static func withoutOutputFlags(_ arguments: [String]) -> [String] {
    arguments.filter { !OutputForm.spellings.contains($0) }
  }

  /// The usage error for words that name no command, when the arguments hold some: the first
  /// word, or the words after `help`, which takes one. Arguments that start with an option
  /// hold none.
  private static func unknownCommand(in arguments: [String], json: Bool) -> CommandOutput?
  {
    let words = withoutOutputFlags(arguments)
    let accepted = commandNames.joined(separator: ", ")
    guard words.first == "help" else {
      guard let word = words.first, !word.hasPrefix("-"), !commandNames.contains(word)
      else {
        return nil
      }
      return usage(
        "unknown command `\(word)`; accepted: \(accepted)", command: nil, json: json)
    }
    // ArgumentParser's `help` takes any number of words and describes the first it knows.
    let topics = words.dropFirst().filter { !$0.hasPrefix("-") }
    if topics.count > 1 {
      return usage(
        "`help` takes one command, got `\(topics.joined(separator: " "))`; accepted: \(accepted)",
        command: "help", json: json)
    }
    guard let topic = topics.first, !commandNames.contains(topic) else {
      return nil
    }
    return usage(
      "unknown command `\(topic)`; accepted: \(accepted)", command: "help", json: json)
  }

  /// What ArgumentParser's error means here.
  ///
  /// A help request, a completion script, and the candidates of a custom completion are
  /// errors to ArgumentParser and exit 0 with their text. Every other one is a usage error,
  /// which ArgumentParser would exit 64 for, and exits 2 here.
  private static func parseFailure(
    _ error: any Error, arguments: [String], columns: Int?, json: Bool
  ) -> CommandOutput {
    guard Root.exitCode(for: error) != .success else {
      let text = Root.fullMessage(for: error, columns: columns)
      return CommandOutput(exitCode: 0, stdout: text.isEmpty ? "" : text + "\n")
    }
    // The message says what was wrong, on one line so the JSON form reads; the usage says
    // what is accepted where it was.
    let command = commands.first {
      $0._commandName == withoutOutputFlags(arguments).first
    }
    let message = Root.message(for: error)
      .split(whereSeparator: \.isNewline)
      .map { $0.trimmingCharacters(in: .whitespaces) }
      .joined(separator: " ")
    let synopsis = command.map { Root.usageString(for: $0) } ?? Root.usageString()
    return usage(
      "\(message); usage: \(synopsis)", command: command?._commandName, json: json)
  }
}
