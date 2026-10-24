import Foundation

/// The arguments of one command: positional words, flags, and flags that take a value.
struct CommandArguments {
  struct Failure: Error {
    var message: String
  }

  private(set) var positional: [String] = []
  private(set) var flags: Set<String> = []
  private(set) var values: [String: String] = [:]

  /// Splits `arguments`, accepting only the named flags.
  ///
  /// - Parameters:
  ///   - arguments: The words after the command.
  ///   - flags: The flags that stand alone.
  ///   - valued: The flags followed by their value.
  init(
    _ arguments: [String], flags allowed: Set<String> = [], valued: Set<String> = []
  ) throws(Failure) {
    var iterator = arguments.makeIterator()
    while let argument = iterator.next() {
      if allowed.contains(argument) {
        flags.insert(argument)
      } else if valued.contains(argument) {
        guard let value = iterator.next() else {
          throw Failure(message: "`\(argument)` needs a value")
        }
        guard values.updateValue(value, forKey: argument) == nil else {
          throw Failure(message: "`\(argument)` is given twice")
        }
      } else if argument.hasPrefix("-"), argument.count > 1 {
        let accepted = (allowed.union(valued).union(["--json", "--pretty"])).sorted()
        throw Failure(
          message:
            "unknown flag `\(argument)`; accepted: \(accepted.joined(separator: ", "))")
      } else {
        positional.append(argument)
      }
    }
  }
}

extension HarnessCLI {
  /// `run`'s JSON object: the command's own status and one report per scenario.
  private struct RunResult: Encodable {
    var command = "run"
    var exitCode: Int32
    var scenarios: [ReportBody]
  }

  /// `shot`'s JSON object.
  private struct ShotResult: Encodable {
    var app: String
    var command = "shot"
    var exitCode: Int32 = 0
    var rows: [String]
    var size: String
  }

  /// `tree`'s JSON object.
  private struct TreeResult: Encodable {
    var app: String
    var command = "tree"
    var exitCode: Int32 = 0
    var lines: [String]
    var size: String
  }

  /// The exit code for a set of reports, the highest any failure asks for: 3 for a `harness`
  /// failure, 2 for `parse` and `usage`, and 1 for every other failure, which is an
  /// expectation that did not hold.
  static func exitCode(for reports: [ScenarioReport]) -> Int32 {
    reports.flatMap(\.failures).map { failure -> Int32 in
      switch failure.verb {
      case "harness": 3
      case "parse", "usage": 2
      default: 1
      }
    }.max() ?? 0
  }

  // MARK: run

  @MainActor
  static func runScenarios(
    _ arguments: [String], registry: ApplicationRegistry, json: Bool
  ) async -> CommandOutput {
    let parsed: CommandArguments
    do {
      parsed = try CommandArguments(
        arguments, flags: ["--record", "--timing"], valued: ["--repeat"])
    } catch {
      return usage(error.message, command: "run", json: json)
    }
    var runner = ScenarioRunner(
      registry: registry, record: parsed.flags.contains("--record"))
    runner.measuresTime = parsed.flags.contains("--timing")
    // The value first: `run --repeat x.scn` read `x.scn` as the count, and that is the mistake
    // to report, not the missing path it leaves behind.
    if let value = parsed.values["--repeat"] {
      guard let count = Int(value), count >= 1 else {
        return usage(
          "`--repeat` needs a whole number of at least 1, got `\(value)`", command: "run",
          json: json)
      }
      runner.repetitions = count
    }
    guard !parsed.positional.isEmpty else {
      return usage(
        "usage: run PATH... [--record] [--repeat N] [--timing]", command: "run",
        json: json)
    }

    let reports = await runner.run(paths: parsed.positional)
    let code = exitCode(for: reports)
    if json {
      return CommandOutput(
        exitCode: code,
        stdout: encode(RunResult(exitCode: code, scenarios: reports.map(ReportBody.init)))
          + "\n")
    }
    let failed = reports.filter { !$0.passed }.count
    var lines = reports.map(\.description)
    lines.append(
      "\(reports.count) \(reports.count == 1 ? "scenario" : "scenarios"), "
        + "\(reports.count - failed) passed, \(failed) failed")
    return CommandOutput(exitCode: code, stdout: lines.joined(separator: "\n") + "\n")
  }

  // MARK: shot and tree

  @MainActor
  static func picture(
    _ command: String, _ arguments: [String], registry: ApplicationRegistry, json: Bool
  ) async -> CommandOutput {
    let target: (name: String, viewport: Viewport)
    do {
      target = try appAndSize(arguments, command: command)
    } catch {
      return usage(error.message, command: command, json: json)
    }

    let picture: ScenarioPlayer.Picture
    do {
      picture = try await ScenarioPlayer.picture(
        of: target.name, at: target.viewport, registry: registry)
    } catch let error as RegistryError {
      return registryFailure(error, command: command, json: json)
    } catch let error as HostError {
      // A size the app cannot take is a mistake in the command, not a failed expectation.
      return failure(
        error.message, exitCode: error.verb == "size" ? 2 : 3, command: command,
        json: json)
    } catch {
      return failure("\(error)", exitCode: 3, command: command, json: json)
    }

    let size = "\(picture.size.columns)x\(picture.size.rows)"
    if command == "shot" {
      return CommandOutput(
        exitCode: 0,
        stdout: json
          ? encode(ShotResult(app: target.name, rows: picture.rows, size: size)) + "\n"
          : GoldenStore.text(of: picture.rows))
    }
    return CommandOutput(
      exitCode: 0,
      stdout: json
        ? encode(TreeResult(app: target.name, lines: picture.tree, size: size)) + "\n"
        : picture.tree.map { $0 + "\n" }.joined())
  }

  /// `NAME [SIZE]`, the words `shot`, `tree`, and `check` take.
  private static func appAndSize(_ arguments: [String], command: String)
    throws(CommandArguments.Failure) -> (name: String, viewport: Viewport)
  {
    let parsed = try CommandArguments(arguments)
    guard (1...2).contains(parsed.positional.count) else {
      throw CommandArguments.Failure(message: "usage: \(command) NAME [SIZE]")
    }
    let size = parsed.positional.dropFirst().first ?? "desktop"
    guard let viewport = ScenarioParser.viewport(spelled: size) else {
      throw CommandArguments.Failure(
        message: "bad size `\(size)`; expected WxH, desktop, mobile, or mobileScreen")
    }
    return (parsed.positional[0], viewport)
  }

  // MARK: check and replay

  static func check(
    _ arguments: [String], registry: ApplicationRegistry, json: Bool
  ) -> CommandOutput {
    let target: (name: String, viewport: Viewport)
    do {
      target = try appAndSize(arguments, command: "check")
    } catch {
      return usage(error.message, command: "check", json: json)
    }
    // The name is checked as `shot` checks it, so the refusal below is the only thing that
    // changes when the rules exist.
    do {
      _ = try registry.entry(named: target.name)
    } catch {
      return registryFailure(error, command: "check", json: json)
    }
    return usage(
      "`check` is not yet available: it runs invariant rules over the projection, and the "
        + "harness builds neither yet, so it would pass without checking anything",
      command: "check", json: json)
  }

  static func replay(
    _ arguments: [String], registry: ApplicationRegistry, json: Bool
  ) -> CommandOutput {
    let parsed: CommandArguments
    do {
      parsed = try CommandArguments(arguments, valued: ["--app"])
    } catch {
      return usage(error.message, command: "replay", json: json)
    }
    guard parsed.positional.count == 1, let name = parsed.values["--app"] else {
      return usage("usage: replay FILE --app NAME", command: "replay", json: json)
    }
    do {
      _ = try registry.entry(named: name)
    } catch {
      return registryFailure(error, command: "replay", json: json)
    }
    return usage(
      "`replay` is not yet available: it reruns a recorded trace, and the harness records "
        + "no traces yet",
      command: "replay", json: json)
  }
}
