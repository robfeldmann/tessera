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
/// terminal), and `help [COMMAND]`. Exit codes are 0 for success, 2 for a usage error, and 3
/// for a harness error. When standard output is not a terminal, each command writes one JSON
/// object to it; `--json` forces that form and `--pretty` forces the text form.
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

  static let commands: [any HarnessCommand.Type] = [AppsCommand.self, LaunchCommand.self]

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
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    let data = (try? encoder.encode(value)) ?? Data()
    // swiftlint:disable:next optional_data_string_conversion
    return String(decoding: data, as: UTF8.self)
  }

  static func usage(_ message: String, command: String?, json: Bool) -> CommandOutput {
    failure(message, exitCode: 2, command: command, json: json)
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

  /// The usage error for a word that names no command, when the arguments hold one: the
  /// first word, or the one after `help`. Arguments that start with an option hold none.
  private static func unknownCommand(in arguments: [String], json: Bool) -> CommandOutput?
  {
    let words = withoutOutputFlags(arguments)
    let afterHelp = words.first == "help"
    guard let word = words.dropFirst(afterHelp ? 1 : 0).first, !word.hasPrefix("-"),
      !commandNames.contains(word)
    else {
      return nil
    }
    return usage(
      "unknown command `\(word)`; accepted: \(commandNames.joined(separator: ", "))",
      command: afterHelp ? "help" : nil, json: json)
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
