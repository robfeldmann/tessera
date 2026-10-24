import ArgumentParser
import Foundation

extension HarnessCLI {
  /// What a one-off command found: the application's picture, or the output that says why
  /// there is none.
  enum Loaded {
    case picture(ScenarioPlayer.Picture)
    case refused(CommandOutput)
  }

  /// The JSON object of a command that runs scenarios, `run` and `replay`: the command's own
  /// status and one report per scenario.
  struct RunResult: Encodable {
    var command = "run"
    var exitCode: Int32
    var scenarios: [ReportBody]
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

  /// Shows the application `target` names at its size, for `shot`, `tree`, and `check`.
  @MainActor
  static func loadPicture(
    _ command: String, _ target: PictureArguments, in context: Context
  ) async -> Loaded {
    do {
      return .picture(
        try await ScenarioPlayer.picture(
          of: target.name, at: target.viewport, registry: context.registry))
    } catch let error as RegistryError {
      return .refused(
        registryFailure(error, command: command, json: context.asJSON))
    } catch let error as HostError {
      // A size the app cannot take is a mistake in the command, not a failed expectation.
      return .refused(
        failure(
          error.message, exitCode: error.verb == "size" ? 2 : 3, command: command,
          json: context.asJSON))
    } catch {
      return .refused(
        failure("\(error)", exitCode: 3, command: command, json: context.asJSON))
    }
  }
}

/// The message for an argument that is the empty string, which names no path or application.
private let emptyArgumentMessage =
  "an empty argument is not a path or an application name"

/// Refuses a flag given more than once, as the command line always has.
///
/// ArgumentParser takes the last value of a repeated option, so an option that must be given
/// at most once is declared as an array and checked here.
private func refuseRepeats(of flag: String, given count: Int) throws {
  guard count <= 1 else {
    throw ValidationError("`\(flag)` is given twice")
  }
}

/// `NAME [SIZE]`, the arguments `shot`, `tree`, and `check` take.
struct PictureArguments: ParsableArguments {
  @Argument(
    help: "The application to show, as `apps` lists it.",
    completion: HarnessCLI.appNameCompletion)
  var name: String

  @Argument(
    help: ArgumentHelp(
      "The terminal size: desktop, mobile, mobileScreen, or WxH.", valueName: "size"),
    completion: .list(["desktop", "mobile", "mobileScreen"]))
  var size = "desktop"

  /// The size as a viewport. ``validate()`` rejects a size that names none, so the fallback
  /// is never used.
  var viewport: Viewport {
    ScenarioParser.viewport(spelled: size) ?? .desktop
  }

  func validate() throws {
    guard !name.isEmpty else {
      throw ValidationError(emptyArgumentMessage)
    }
    guard ScenarioParser.viewport(spelled: size) != nil else {
      throw ValidationError(
        "bad size `\(size)`; expected WxH, desktop, mobile, or mobileScreen")
    }
  }
}

struct RunCommand: HarnessCommand {
  static let configuration = CommandConfiguration(
    commandName: "run",
    abstract: "Run scenario files, or directories of them.",
    discussion: """
      Runs scenario files. A path is a .scn file, or a directory whose .scn files, at any \
      depth, run in sorted order. A path that is neither, or a directory with no scenarios, \
      is a usage error. Each scenario starts a fresh application.

      A scenario is a text file with one statement per line. The header statements are \
      `app NAME`, `size SIZE`, and `term colors=... theme=...`. The input statements are \
      `resize WxH`, `key NAME`, `type "text"`, `paste "text"`, and `bytes "..."`. \
      `shot NAME` compares the screen with golden files, `tree` adds the node tree to the \
      report, and `dump` adds the projection. The assertions are `expect text [ROW] \
      "text"`, `expect screen <<WORD`, `expect node SEL frame X,Y,WxH`, `expect cost \
      NAME<=N...`, and `check [RULE...]`. A statement outside this list is a parse error.

      Exit codes: 0 every scenario passed, 1 an expectation failed, 2 a scenario did not \
      parse or a path is not a scenario, 3 a harness error. When several apply, the \
      highest wins.

      The JSON form is {"command": "run", "exitCode", "scenarios": [REPORT...]} with one \
      REPORT per scenario: {"failures": [FAILURE...], "observations": [{"line", "verb", \
      "lines"} and, for a shot, "name"; for a dump, "projection"], "passed", "recorded" \
      (only when --record wrote goldens: [{"change": "created" or "updated", "path"}]), \
      "scenario", "seconds" (only with --timing)}. A FAILURE is {"line", "statement", \
      "verb", "message"} and, when the statement compares values, "expected", "actual", \
      and "screen"; a failed `check` adds "rule" and "node". A failure that belongs to a \
      file or a command, not a line, has "line" 0 and "statement" "" (a repeat failure's \
      statement is "--repeat N"). A shot whose golden is missing, is not UTF-8, or has \
      CRLF line endings has no "expected", "actual", or "screen": its observation holds \
      the screen. A scenario that does not parse is a failure with verb "parse". Fields \
      are added, never removed or renamed.
      """)

  @OptionGroup var output: OutputOptions

  @Flag(
    help: """
      Write the golden files that `shot` statements compare against, instead of failing \
      when one differs or is missing, and list what changed. Review the files it wrote; \
      never record to make a failing run pass.
      """)
  var record = false

  @Option(
    name: .customLong("repeat"),
    help: ArgumentHelp(
      "Run each scenario N times, and fail a run whose report differs from the first.",
      valueName: "n"))
  var repeatValues: [Int] = []

  @Flag(
    help: """
      Add the wall-clock seconds of each run to the report. Times differ from run to run, \
      so they are never golden.
      """)
  var timing = false

  @Option(
    name: .customLong("trace"),
    help: ArgumentHelp(
      """
      Write each scenario's trace under DIR, as DIR/PATH.trace.jsonl, one JSON record per \
      step: the event, why the frame was drawn (`reasons`), the nodes and rows that \
      changed, and what the step cost. Read it to learn why a redraw happened. The trace \
      is not promised to stay as it is.
      """,
      valueName: "dir"))
  var traceValues: [String] = []

  @Argument(
    help: ArgumentHelp("A .scn file, or a directory of them.", valueName: "path"),
    completion: .file(extensions: ["scn"]))
  var paths: [String]

  /// The number of times to run each scenario: the one `--repeat` value, or 1.
  private var repetitions: Int {
    repeatValues.first ?? 1
  }

  /// The directory to write traces under: the one `--trace` value, if any.
  private var trace: String? {
    traceValues.first
  }

  func validate() throws {
    try refuseRepeats(of: "--repeat", given: repeatValues.count)
    try refuseRepeats(of: "--trace", given: traceValues.count)
    guard repetitions >= 1 else {
      throw ValidationError(
        "`--repeat` needs a whole number of at least 1, got `\(repetitions)`")
    }
    // An empty path would join to the filesystem root, and an empty name matches nothing.
    guard trace?.isEmpty != true else {
      throw ValidationError("`--trace` needs a value that is not empty")
    }
    guard !paths.contains(where: \.isEmpty) else {
      throw ValidationError(emptyArgumentMessage)
    }
  }

  @MainActor
  func execute(in context: HarnessCLI.Context) async -> CommandOutput {
    var runner = ScenarioRunner(registry: context.registry, record: record)
    runner.measuresTime = timing
    runner.repetitions = repetitions
    runner.traceDirectory = trace

    let reports = await runner.run(paths: paths)
    let code = HarnessCLI.exitCode(for: reports)
    if context.asJSON {
      return CommandOutput(
        exitCode: code,
        stdout: HarnessCLI.encode(
          HarnessCLI.RunResult(exitCode: code, scenarios: reports.map(ReportBody.init)))
          + "\n")
    }
    let failed = reports.filter { !$0.passed }.count
    var lines = reports.map(\.description)
    lines.append(
      "\(reports.count) \(reports.count == 1 ? "scenario" : "scenarios"), "
        + "\(reports.count - failed) passed, \(failed) failed")
    return CommandOutput(exitCode: code, stdout: lines.joined(separator: "\n") + "\n")
  }
}

struct ShotCommand: HarnessCommand {
  /// `shot`'s JSON object.
  private struct Result: Encodable {
    var app: String
    var command = "shot"
    var exitCode: Int32 = 0
    var rows: [String]
    var size: String
  }

  static let configuration = CommandConfiguration(
    commandName: "shot",
    abstract: "Print one application's screen as text.",
    discussion: """
      Prints the screen of the registered application, as text, the way a golden file \
      holds it. The JSON form is {"app", "command": "shot", "exitCode", "rows", "size"}, \
      where "size" is the terminal size the application was shown at. An unknown name is a \
      usage error that lists the registered names, and so is a size the application \
      cannot take, such as `mobile` for an application whose content fills any height: \
      the error says which size to use.
      """)

  @OptionGroup var output: OutputOptions
  @OptionGroup var target: PictureArguments

  @MainActor
  func execute(in context: HarnessCLI.Context) async -> CommandOutput {
    switch await HarnessCLI.loadPicture("shot", target, in: context) {
    case .refused(let refusal):
      return refusal
    case .picture(let picture):
      let size = "\(picture.size.columns)x\(picture.size.rows)"
      return CommandOutput(
        exitCode: 0,
        stdout: context.asJSON
          ? HarnessCLI.encode(Result(app: target.name, rows: picture.rows, size: size))
            + "\n"
          : GoldenStore.text(of: picture.rows))
    }
  }
}

struct TreeCommand: HarnessCommand {
  /// `tree`'s JSON object.
  private struct Result: Encodable {
    var app: String
    var command = "tree"
    var exitCode: Int32 = 0
    var lines: [String]
    var size: String
  }

  static let configuration = CommandConfiguration(
    commandName: "tree",
    abstract: "Print one application's node tree.",
    discussion: """
      Prints the node tree of the registered application, one line per node with its \
      identity, type, frame, and clip; a container with a layout algorithm shows it in \
      parentheses, as `_LayoutContainer(_FrameLayout)`. The JSON form is {"app", \
      "command": "tree", "exitCode", "lines", "size"}. The tree's text is for reading and \
      is not promised to stay as it is. Errors are those of `shot`.
      """)

  @OptionGroup var output: OutputOptions
  @OptionGroup var target: PictureArguments

  @MainActor
  func execute(in context: HarnessCLI.Context) async -> CommandOutput {
    switch await HarnessCLI.loadPicture("tree", target, in: context) {
    case .refused(let refusal):
      return refusal
    case .picture(let picture):
      let size = "\(picture.size.columns)x\(picture.size.rows)"
      return CommandOutput(
        exitCode: 0,
        stdout: context.asJSON
          ? HarnessCLI.encode(Result(app: target.name, lines: picture.tree, size: size))
            + "\n"
          : picture.tree.map { $0 + "\n" }.joined())
    }
  }
}

struct CheckCommand: HarnessCommand {
  /// `check`'s JSON object.
  private struct Result: Encodable {
    var app: String
    var command = "check"
    var exitCode: Int32
    var rules: [String]
    var size: String
    var violations: [Violation]
  }

  static let configuration = CommandConfiguration(
    commandName: "check",
    abstract: "Check one application against the invariant rules.",
    discussion: """
      Runs every invariant rule over the registered application at the size, with no \
      input: no-dirty-after-pass, frame-inside-clip, measured-within-proposal, \
      siblings-disjoint, and requirements-aggregate. An error fails the command (exit 1); \
      a warning (frame-inside-clip) is listed and does not. The output names the rules \
      that ran. The JSON form is {"app", "command": "check", "exitCode", "rules", "size", \
      "violations": [{"detail", "node", "rule", "severity"}]}. Errors are those of \
      `shot`. A scenario's `check` statement runs the same rules after its input.
      """)

  @OptionGroup var output: OutputOptions
  @OptionGroup var target: PictureArguments

  /// An error fails the command (exit 1); a warning is listed and does not, as in a bare
  /// `check` statement. The output names the rules that ran, so a pass is never an empty line.
  @MainActor
  func execute(in context: HarnessCLI.Context) async -> CommandOutput {
    let picture: ScenarioPlayer.Picture
    switch await HarnessCLI.loadPicture("check", target, in: context) {
    case .refused(let refusal):
      return refusal
    case .picture(let loaded):
      picture = loaded
    }
    let name = target.name
    let rules = CheckRule.allCases
    let violations = Checker.run(rules, on: picture.projection)
    let errors = violations.filter { $0.severity == CheckRule.Severity.error.rawValue }
    let code: Int32 = errors.isEmpty ? 0 : 1
    let size = "\(picture.size.columns)x\(picture.size.rows)"
    if context.asJSON {
      return CommandOutput(
        exitCode: code,
        stdout: HarnessCLI.encode(
          Result(
            app: name, exitCode: code, rules: rules.map(\.rawValue), size: size,
            violations: violations)) + "\n")
    }
    var lines = [
      "check \(name) at \(size) against \(rules.count) rules: "
        + rules.map(\.rawValue).joined(separator: ", ")
    ]
    lines += violations.map { "  \($0.text)" }
    let warnings = violations.count - errors.count
    let warningText = "\(warnings) \(warnings == 1 ? "warning" : "warnings")"
    if errors.isEmpty {
      lines.append("PASS \(name)" + (warnings > 0 ? ": \(warningText)" : ""))
    } else {
      lines.append(
        "FAIL \(name): \(errors.count) \(errors.count == 1 ? "error" : "errors")"
          + (warnings > 0 ? ", \(warningText)" : ""))
    }
    return CommandOutput(exitCode: code, stdout: lines.joined(separator: "\n") + "\n")
  }
}

struct ReplayCommand: HarnessCommand {
  static let configuration = CommandConfiguration(
    commandName: "replay",
    abstract: "Run a recorded trace again against an application.",
    discussion: """
      Runs the trace FILE, written by `launch` under TESSERA_TRACE or by `run --trace`, \
      again against the registered application: the same events, in order, at the size \
      the recording started at. After every step the replay is compared with the \
      recording on why the frame was drawn, the nodes and rows that changed, and the \
      cost, which are the same on any terminal; the bytes a frame wrote are not \
      compared. A step that differs is a `replay` failure (exit 1) that shows both. Keys, \
      pastes, resizes, and the terminal's focus changes replay; a trace that holds any \
      other event (a mouse event, a terminal reply), or that is not a trace, is a usage \
      error (exit 2). The output is a run report, {"command": "replay", "exitCode", \
      "scenarios": [REPORT]}, whose observation holds the final screen.
      """)

  @OptionGroup var output: OutputOptions

  @Argument(help: ArgumentHelp("The trace to run again.", valueName: "file"))
  var file: String

  @Option(
    name: .customLong("app"),
    help: ArgumentHelp(
      "The application to replay it against, as `apps` lists it.", valueName: "name"),
    completion: HarnessCLI.appNameCompletion)
  var appValues: [String]

  /// The application to replay against: the one `--app` value.
  private var app: String {
    appValues.first ?? ""
  }

  func validate() throws {
    try refuseRepeats(of: "--app", given: appValues.count)
    guard !file.isEmpty else {
      throw ValidationError(emptyArgumentMessage)
    }
    guard !app.isEmpty else {
      throw ValidationError("`--app` needs a value that is not empty")
    }
  }

  /// Reports what differs from the recording, as `run` reports a scenario.
  @MainActor
  func execute(in context: HarnessCLI.Context) async -> CommandOutput {
    do {
      _ = try context.registry.entry(named: app)
    } catch {
      return HarnessCLI.registryFailure(error, command: "replay", json: context.asJSON)
    }
    guard let data = FileManager.default.contents(atPath: file) else {
      return HarnessCLI.usage(
        "cannot read the trace `\(file)`", command: "replay", json: context.asJSON)
    }
    guard let text = String(validating: data, as: UTF8.self) else {
      return HarnessCLI.usage(
        "the trace `\(file)` is not UTF-8 text", command: "replay", json: context.asJSON)
    }

    let report = await Replayer.replay(
      text: text, file: file, app: app, registry: context.registry)
    let code = HarnessCLI.exitCode(for: [report])
    if context.asJSON {
      return CommandOutput(
        exitCode: code,
        stdout: HarnessCLI.encode(
          HarnessCLI.RunResult(
            command: "replay", exitCode: code, scenarios: [ReportBody(report)])) + "\n")
    }
    return CommandOutput(exitCode: code, stdout: report.description + "\n")
  }
}
