import ArgumentParser
import Foundation

extension HarnessCLI {
  /// What a one-off command found: the application's picture, or the output that says why
  /// there is none.
  enum Loaded {
    case picture(ScenarioPlayer.Picture)
    case refused(CommandOutput)
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

  /// Shows the application `target` names at its size, for `shot` and `tree`.
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

/// Refuses a flag given more than once, as the command line always has.
///
/// ArgumentParser takes the last value of a repeated option, so an option that must be given
/// at most once is declared as an array and checked here.
private func refuseRepeats(of flag: String, given count: Int) throws {
  guard count <= 1 else {
    throw ValidationError("`\(flag)` is given twice")
  }
}

/// `NAME [SIZE]`, the arguments `shot` and `tree` take.
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
    guard ScenarioParser.viewport(spelled: size) != nil else {
      throw ValidationError(
        "bad size `\(size)`; expected WxH, desktop, mobile, or mobileScreen")
    }
  }
}

struct RunCommand: HarnessCommand {
  /// `run`'s JSON object: the command's own status and one report per scenario.
  private struct Result: Encodable {
    var command = "run"
    var exitCode: Int32
    var scenarios: [ReportBody]
  }

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
      `shot NAME` compares the screen with a golden file and `tree` adds the node tree to \
      the report. The assertions are `expect text [ROW] "text"`, `expect screen <<WORD`, \
      and `expect node SEL frame X,Y,WxH`. A statement outside this list is a parse error.

      Exit codes: 0 every scenario passed, 1 an expectation failed, 2 a scenario did not \
      parse or a path is not a scenario, 3 a harness error. When several apply, the \
      highest wins.

      The JSON form is {"command": "run", "exitCode", "scenarios": [REPORT...]} with one \
      REPORT per scenario: {"failures": [FAILURE...], "observations": [{"line", "verb", \
      "lines"} and, for a shot, "name"], "passed", "recorded" (only when --record wrote \
      goldens: [{"change": "created" or "updated", "path"}]), "scenario", "seconds" (only \
      with --timing)}. A FAILURE is {"line", "statement", "verb", "message"} and, when the \
      statement compares values, "expected", "actual", and "screen". A failure that \
      belongs to a file or a command, not a line, has "line" 0 and "statement" "" (a \
      repeat failure's statement is "--repeat N"). A shot whose golden is missing, is not \
      UTF-8, or has CRLF line endings has no "expected", "actual", or "screen": its \
      observation holds the screen. A scenario that does not parse is a failure with verb \
      "parse". Fields are added, never removed or renamed.
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

  @Argument(
    help: ArgumentHelp("A .scn file, or a directory of them.", valueName: "path"),
    completion: .file(extensions: ["scn"]))
  var paths: [String]

  /// The number of times to run each scenario: the one `--repeat` value, or 1.
  private var repetitions: Int {
    repeatValues.first ?? 1
  }

  func validate() throws {
    try refuseRepeats(of: "--repeat", given: repeatValues.count)
    guard repetitions >= 1 else {
      throw ValidationError(
        "`--repeat` needs a whole number of at least 1, got `\(repetitions)`")
    }
  }

  @MainActor
  func execute(in context: HarnessCLI.Context) async -> CommandOutput {
    var runner = ScenarioRunner(registry: context.registry, record: record)
    runner.measuresTime = timing
    runner.repetitions = repetitions

    let reports = await runner.run(paths: paths)
    let code = HarnessCLI.exitCode(for: reports)
    if context.asJSON {
      return CommandOutput(
        exitCode: code,
        stdout: HarnessCLI.encode(
          Result(exitCode: code, scenarios: reports.map(ReportBody.init))) + "\n")
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
      identity, type, frame, and clip. The JSON form is {"app", "command": "tree", \
      "exitCode", "lines", "size"}. The tree's text is for reading and is not promised to \
      stay as it is. Errors are those of `shot`.
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
