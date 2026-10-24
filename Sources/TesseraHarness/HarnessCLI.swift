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
      configuration: .default
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
  private struct AppsListing: Encodable {
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

  static let commands = ["apps", "launch", "help"]

  private static let overview = """
    usage: <executable> COMMAND [ARGUMENT]

    commands:
      apps           list the registered applications
      launch NAME    run one application in this terminal
      help [COMMAND] describe a command

    Every command exits 0 on success, 2 on a usage error, and 3 on a harness error. When
    standard output is not a terminal each command writes one JSON object to it; --json
    forces that form and --pretty forces the text form.
    """

  private static let helpText: [String: String] = [
    "apps": """
    usage: apps [--json | --pretty]

    Lists every registered application with the smallest size it declares and the
    viewports it is checked at. The JSON form is {"apps": [{"minimum", "name",
    "viewports"}], "command": "apps"}, sorted by name, where "minimum" is null for an
    application that declares none. A name registered twice fails the command with exit 3.
    """,
    "launch": """
    usage: launch NAME

    Runs the named application in this terminal at the terminal's size, until the
    application finishes. The harness has no quit key of its own: the application decides
    which key quits. Exits 2 for an unknown name, and 3 for a duplicate registration or
    when standard input or output is not a terminal.
    """,
    "help": """
    usage: help [COMMAND]

    Prints the commands, or one command's usage.
    """,
  ]

  /// Runs one command and returns what it printed, without touching the process.
  ///
  /// `launch` needs a terminal on both ends, so it refuses to start unless `inputIsTerminal`
  /// and `outputIsTerminal` are both `true`; this keeps a test or a pipe from ever opening a
  /// live session, and fails before the terminal changes mode rather than after.
  @MainActor
  static func run(
    arguments: [String],
    registry: ApplicationRegistry,
    inputIsTerminal: Bool,
    outputIsTerminal: Bool,
    configuration: TerminalApplicationConfiguration
  ) async -> CommandOutput {
    var arguments = arguments
    let asJSON: Bool
    switch (arguments.contains("--json"), arguments.contains("--pretty")) {
    case (true, true):
      return usage(
        "`--json` and `--pretty` contradict each other", command: nil, json: false)
    case (true, false):
      asJSON = true
    case (false, true):
      asJSON = false
    case (false, false):
      asJSON = !outputIsTerminal
    }
    arguments.removeAll { $0 == "--json" || $0 == "--pretty" }

    guard let command = arguments.first else {
      return usage(
        "a command is required; accepted: \(commands.joined(separator: ", "))",
        command: nil, json: asJSON)
    }
    let rest = Array(arguments.dropFirst())
    switch command {
    case "apps":
      return apps(rest, registry: registry, json: asJSON)
    case "launch":
      return await launch(
        rest, registry: registry, json: asJSON,
        terminals: (input: inputIsTerminal, output: outputIsTerminal),
        configuration: configuration)
    case "help":
      return help(rest, json: asJSON)
    default:
      return usage(
        "unknown command `\(command)`; accepted: \(commands.joined(separator: ", "))",
        command: nil, json: asJSON)
    }
  }

  // MARK: Commands

  private static func apps(
    _ arguments: [String], registry: ApplicationRegistry, json: Bool
  ) -> CommandOutput {
    if let extra = arguments.first {
      return usage(
        "`apps` takes no argument, got `\(extra)`", command: "apps", json: json)
    }
    let entries: [ApplicationRegistry.Entry]
    do {
      entries = try registry.checkedEntries()
    } catch {
      return failure(error.description, exitCode: 3, command: "apps", json: json)
    }

    if json {
      let listing = AppsListing(
        apps: entries.map { entry in
          AppsListing.App(
            minimum: entry.minimum.map { "\($0.columns)x\($0.rows)" },
            name: entry.name,
            viewports: entry.viewports.map(\.name))
        })
      return CommandOutput(exitCode: 0, stdout: encode(listing) + "\n")
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

  private static func launch(
    _ arguments: [String],
    registry: ApplicationRegistry,
    json: Bool,
    terminals: (input: Bool, output: Bool),
    configuration: TerminalApplicationConfiguration
  ) async -> CommandOutput {
    guard arguments.count == 1, let name = arguments.first, !name.hasPrefix("-") else {
      return usage("usage: launch NAME", command: "launch", json: json)
    }
    let entry: ApplicationRegistry.Entry
    do {
      entry = try registry.entry(named: name)
    } catch {
      let exitCode: Int32 =
        switch error {
        case .duplicate: 3
        case .unknown: 2
        }
      return failure(error.description, exitCode: exitCode, command: "launch", json: json)
    }
    guard terminals.input, terminals.output else {
      let missing =
        switch terminals {
        case (false, false): "standard input and output are not terminals"
        case (false, true): "standard input is not one"
        default: "standard output is not one"
        }
      return failure(
        "`launch` runs an application in this terminal, and \(missing)",
        exitCode: 3, command: "launch", json: json)
    }
    do {
      try await entry.live(configuration)
    } catch {
      return failure(
        "`launch \(name)` could not run in this terminal: \(error)",
        exitCode: 3, command: "launch", json: json)
    }
    return CommandOutput(exitCode: 0)
  }

  private static func help(_ arguments: [String], json: Bool) -> CommandOutput {
    guard let topic = arguments.first else {
      return CommandOutput(exitCode: 0, stdout: overview + "\n")
    }
    guard arguments.count == 1 else {
      return usage("usage: help [COMMAND]", command: "help", json: json)
    }
    guard let text = helpText[topic] else {
      return usage(
        "unknown command `\(topic)`; accepted: \(commands.joined(separator: ", "))",
        command: "help", json: json)
    }
    return CommandOutput(exitCode: 0, stdout: text + "\n")
  }

  // MARK: Output

  private static func encode(_ value: some Encodable) -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    let data = (try? encoder.encode(value)) ?? Data()
    // swiftlint:disable:next optional_data_string_conversion
    return String(decoding: data, as: UTF8.self)
  }

  private static func usage(_ message: String, command: String?, json: Bool)
    -> CommandOutput
  {
    failure(message, exitCode: 2, command: command, json: json)
  }

  private static func failure(
    _ message: String, exitCode: Int32, command: String?, json: Bool
  ) -> CommandOutput {
    if json {
      let body = Failure(command: command, exitCode: exitCode, message: message)
      return CommandOutput(exitCode: exitCode, stdout: encode(body) + "\n")
    }
    return CommandOutput(exitCode: exitCode, stderr: "error: \(message)\n")
  }
}
