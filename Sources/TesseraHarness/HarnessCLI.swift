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
/// terminal), `run PATH...` (run scenario files, with `--record`, `--repeat N`, `--timing`,
/// and `--trace DIR`), `shot NAME [SIZE]`, `tree NAME [SIZE]`, and `check NAME [SIZE]` (print
/// one application's screen or node tree, or check it against the invariant rules),
/// `replay FILE --app NAME` (run a recorded trace again), and `help [COMMAND]`.
///
/// Exit codes are 0 for success, 1 when an expectation failed, 2 for a usage or parse error,
/// and 3 for a harness error. When standard output is not a terminal, each command writes one
/// JSON object to it; `--json` forces that form and `--pretty` forces the text form.
public enum HarnessCLI {
  /// Runs the command in the process's arguments and exits with its status.
  ///
  /// - Parameter registry: The applications the commands can list, launch, and run
  ///   scenarios against.
  @MainActor
  public static func main(registry: ApplicationRegistry) async -> Never {
    let output = await run(
      arguments: Array(CommandLine.arguments.dropFirst()),
      registry: registry,
      inputIsTerminal: StandardStreams.inputIsTerminal,
      outputIsTerminal: StandardStreams.outputIsTerminal,
      configuration: .default,
      environment: ProcessInfo.processInfo.environment
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

  static let commands = [
    "apps", "launch", "run", "shot", "tree", "check", "replay", "help",
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
    configuration: TerminalApplicationConfiguration,
    environment: [String: String] = [:]
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
        configuration: configuration, environment: environment)
    case "run":
      return await runScenarios(rest, registry: registry, json: asJSON)
    case "shot", "tree":
      return await picture(command, rest, registry: registry, json: asJSON)
    case "check":
      return await check(rest, registry: registry, json: asJSON)
    case "replay":
      return await replay(rest, registry: registry, json: asJSON)
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

  @MainActor
  private static func launch(
    _ arguments: [String],
    registry: ApplicationRegistry,
    json: Bool,
    terminals: (input: Bool, output: Bool),
    configuration: TerminalApplicationConfiguration,
    environment: [String: String]
  ) async -> CommandOutput {
    guard arguments.count == 1, let name = arguments.first, !name.hasPrefix("-") else {
      return usage("usage: launch NAME", command: "launch", json: json)
    }
    let entry: ApplicationRegistry.Entry
    do {
      entry = try registry.entry(named: name)
    } catch {
      return registryFailure(error, command: "launch", json: json)
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
    var trace: TraceWriter?
    if let path = environment["TESSERA_TRACE"], !path.isEmpty {
      do {
        trace = try TraceWriter(path: path)
      } catch {
        return failure(error.description, exitCode: 3, command: "launch", json: json)
      }
    }
    do {
      try await entry.live(configuration, trace)
    } catch {
      trace?.close()
      return failure(
        "`launch \(name)` could not run in this terminal: \(error)",
        exitCode: 3, command: "launch", json: json)
    }
    trace?.close()
    if let message = trace?.failure {
      return failure(message, exitCode: 3, command: "launch", json: json)
    }
    return CommandOutput(exitCode: 0)
  }

  private static func help(_ arguments: [String], json: Bool) -> CommandOutput {
    guard let topic = arguments.first else {
      return CommandOutput(exitCode: 0, stdout: HelpText.overview + "\n")
    }
    guard arguments.count == 1 else {
      return usage("usage: help [COMMAND]", command: "help", json: json)
    }
    guard let text = HelpText.commands[topic] else {
      return usage(
        "unknown command `\(topic)`; accepted: \(commands.joined(separator: ", "))",
        command: "help", json: json)
    }
    return CommandOutput(exitCode: 0, stdout: text + "\n")
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
}
