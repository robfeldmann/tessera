import Foundation
import TesseraTerminal
import TesseraTerminalCore
import Testing

@testable import TesseraHarness

private let passing = "app stack\nsize 40x10\nexpect text 0 \"Stack demo\"\n"
private let failing = "app stack\nsize 40x10\nexpect text 0 \"Stack demos\"\n"

@MainActor
struct HarnessCLIScenarioTests {
  private let traced = "app stack\nsize 40x10\ntype \"Rob\"\nresize 30x8\nkey Backspace\n"

  private func run(
    _ arguments: String...,
    registry: ApplicationRegistry? = nil,
    terminal: Bool = false
  ) async -> CommandOutput {
    await HarnessCLI.run(
      arguments: arguments,
      registry: registry ?? Fixtures.registry(),
      inputIsTerminal: false,
      outputIsTerminal: terminal,
      configuration: .default
    )
  }

  private func object(_ output: CommandOutput) throws -> [String: Any] {
    try #require(
      JSONSerialization.jsonObject(with: Data(output.stdout.utf8)) as? [String: Any])
  }

  private func reports(_ output: CommandOutput) throws -> [[String: Any]] {
    try #require(try object(output)["scenarios"] as? [[String: Any]])
  }

  // MARK: run

  @Test
  func
    `run prints one JSON object with a report per scenario when stdout is not a terminal`()
    async throws
  {
    let scratch = try ScratchDirectory()
    try scratch.write("a.scn", passing)
    try scratch.write("b.scn", passing)

    let output = await run("run", scratch.path)

    #expect(output.exitCode == 0)
    #expect(output.stderr.isEmpty)
    #expect(output.stdout.hasSuffix("}\n"))
    #expect(output.stdout.filter { $0 == "\n" }.count == 1)
    let object = try object(output)
    #expect(Set(object.keys) == ["command", "exitCode", "scenarios"])
    #expect(object["command"] as? String == "run")
    #expect(object["exitCode"] as? Int == 0)
    let reports = try reports(output)
    #expect(reports.count == 2)
    #expect(reports.allSatisfy { $0["passed"] as? Bool == true })
  }

  @Test
  func `run prints the human form and a summary on a terminal`() async throws {
    let scratch = try ScratchDirectory()
    try scratch.write("a.scn", passing)
    try scratch.write("b.scn", failing)

    let output = await run("run", scratch.path, terminal: true)

    #expect(output.exitCode == 1)
    #expect(output.stdout.contains("PASS \(scratch.appending("a.scn"))"))
    #expect(output.stdout.contains("FAIL \(scratch.appending("b.scn"))"))
    #expect(output.stdout.contains("expected: Stack demos"))
    #expect(output.stdout.hasSuffix("2 scenarios, 1 passed, 1 failed\n"))
    #expect(output.stderr.isEmpty)
  }

  @Test
  func `a summary of one scenario is singular`() async throws {
    let scratch = try ScratchDirectory()
    try scratch.write("a.scn", passing)

    let output = await run("run", scratch.path, "--pretty")

    #expect(output.stdout.hasSuffix("1 scenario, 1 passed, 0 failed\n"))
  }

  @Test
  func `a failed expectation exits 1 and the JSON says which line and statement`()
    async throws
  {
    let scratch = try ScratchDirectory()
    try scratch.write("b.scn", failing)

    let output = await run("run", scratch.path)

    #expect(output.exitCode == 1)
    let object = try object(output)
    #expect(object["exitCode"] as? Int == 1)
    let failures = try #require(
      try reports(output).first?["failures"] as? [[String: Any]])
    #expect(failures.first?["line"] as? Int == 3)
    #expect(failures.first?["verb"] as? String == "expect text")
    #expect(failures.first?["expected"] as? String == "Stack demos")
  }

  @Test
  func `a parse error exits 2 and is a failure with verb parse`() async throws {
    let scratch = try ScratchDirectory()
    try scratch.write("bad.scn", "app stack\nblink\n")

    let output = await run("run", scratch.path)

    #expect(output.exitCode == 2)
    let failures = try #require(
      try reports(output).first?["failures"] as? [[String: Any]])
    #expect(failures.count == 1)
    #expect(failures[0]["verb"] as? String == "parse")
    #expect(failures[0]["line"] as? Int == 2)
    #expect(failures[0]["statement"] as? String == "blink")
  }

  @Test
  func `a path that is not a scenario exits 2`() async throws {
    let scratch = try ScratchDirectory()

    let output = await run("run", scratch.appending("missing.scn"))

    #expect(output.exitCode == 2)
    let failures = try #require(
      try reports(output).first?["failures"] as? [[String: Any]])
    #expect(failures.first?["verb"] as? String == "usage")
  }

  @Test
  func `a harness failure exits 3, and the highest code of the run wins`() async throws {
    let scratch = try ScratchDirectory()
    try scratch.write("a-fails.scn", failing)
    try scratch.write("b-bad.scn", "blink")
    try scratch.write("c-shots.scn", "app stack\nsize 40x10\nshot s")
    // A file where the goldens' directory should be: recording cannot write there.
    try scratch.write("c-shots", "in the way")

    let withoutHarness = await run(
      "run", scratch.appending("a-fails.scn"), scratch.appending("b-bad.scn"))
    let all = await run("run", scratch.path, "--record")

    #expect(withoutHarness.exitCode == 2)
    #expect(all.exitCode == 3)
    let verbs = try reports(all).flatMap { report in
      (report["failures"] as? [[String: Any]] ?? []).compactMap { $0["verb"] as? String }
    }
    #expect(verbs.sorted() == ["expect text", "harness", "parse"])
  }

  @Test
  func `a duplicate name in the registry exits 3`() async throws {
    let scratch = try ScratchDirectory()
    try scratch.write("a.scn", passing)
    var registry = Fixtures.registry()
    registry.register("stack", viewports: [.desktop]) { StackApp() }

    let output = await run("run", scratch.path, registry: registry)

    #expect(output.exitCode == 3)
  }

  @Test
  func `run without a path is a usage error with the failure object`() async throws {
    let output = await run("run")

    #expect(output.exitCode == 2)
    let object = try object(output)
    #expect(object["command"] as? String == "run")
    #expect(object["exitCode"] as? Int == 2)
    #expect((object["message"] as? String)?.hasPrefix("usage: run PATH...") == true)
  }

  @Test
  func `run validates its flags`() async {
    let unknown = await run("run", "x.scn", "--frobnicate", "--pretty")
    let noValue = await run("run", "x.scn", "--repeat", "--pretty")
    let zero = await run("run", "x.scn", "--repeat", "0", "--pretty")
    let word = await run("run", "x.scn", "--repeat", "many", "--pretty")
    let twice = await run("run", "x.scn", "--repeat", "2", "--repeat", "3", "--pretty")

    #expect(unknown.exitCode == 2)
    #expect(
      unknown.stderr
        == "error: unknown flag `--frobnicate`; accepted: --json, --pretty, --record, "
        + "--repeat, --timing, --trace\n")
    #expect(noValue.stderr.contains("`--repeat` needs a value"))
    #expect(
      zero.stderr.contains("`--repeat` needs a whole number of at least 1, got `0`"))
    #expect(word.exitCode == 2)
    #expect(twice.stderr.contains("`--repeat` is given twice"))
  }

  @Test
  func `a path taken as the repeat count reports the repeat value, not a missing path`()
    async
  {
    let output = await run("run", "--repeat", "x.scn", "--pretty")

    #expect(output.exitCode == 2)
    #expect(
      output.stderr
        == "error: `--repeat` needs a whole number of at least 1, got `x.scn`\n")
  }

  @Test
  func `record, repeat, and timing reach the runner`() async throws {
    let scratch = try ScratchDirectory()
    try scratch.write("a.scn", "app stack\nsize 40x10\nshot s")

    let recorded = await run("run", scratch.path, "--record", "--repeat", "2", "--timing")
    let checked = await run("run", scratch.path)

    #expect(recorded.exitCode == 0)
    let report = try #require(try reports(recorded).first)
    #expect((report["recorded"] as? [[String: Any]])?.count == 2)
    #expect((report["seconds"] as? [Double])?.count == 2)
    #expect(checked.exitCode == 0)
    #expect(try reports(checked)[0]["seconds"] == nil)
    #expect(scratch.read("a/s.txt")?.hasPrefix("Stack demo\n") == true)
  }

  @Test
  func `run output is identical across runs`() async throws {
    let scratch = try ScratchDirectory()
    try scratch.write("a.scn", passing)
    try scratch.write("b.scn", failing)

    let first = await run("run", scratch.path)
    let second = await run("run", scratch.path)

    #expect(first == second)
  }

  // MARK: shot and tree

  @Test
  func `shot prints the screen as a golden holds it`() async {
    let output = await run("shot", "stack", "40x8", "--pretty")

    #expect(output.exitCode == 0)
    #expect(
      output.stdout
        == """
        Stack demo
        ────────────────────────────────────────
        Name: -
        left                               right
        ────────────────────────────────────────
        40 columns

        """)
  }

  @Test
  func `shot prints one JSON object with the rows and the size`() async throws {
    let output = await run("shot", "stack", "mobile")

    #expect(output.exitCode == 0)
    let object = try object(output)
    #expect(Set(object.keys) == ["app", "command", "exitCode", "rows", "size"])
    #expect(object["app"] as? String == "stack")
    #expect(object["command"] as? String == "shot")
    #expect(object["size"] as? String == "40x6")
    #expect((object["rows"] as? [String])?.first == "Stack demo")
    #expect((object["rows"] as? [String])?.count == 6)
  }

  @Test
  func `shot defaults to desktop`() async throws {
    let output = await run("shot", "stack")

    #expect(try object(output)["size"] as? String == "80x24")
  }

  @Test
  func `tree prints one line per node and the JSON carries the same lines`() async throws
  {
    let text = await run("tree", "stack", "40x8", "--pretty")
    let json = await run("tree", "stack", "40x8")

    #expect(text.exitCode == 0)
    #expect(
      text.stdout.hasPrefix("root TupleView frame=0,0,40x8\n  root/index(0) VStack"))
    let object = try object(json)
    #expect(Set(object.keys) == ["app", "command", "exitCode", "lines", "size"])
    #expect(
      (object["lines"] as? [String])?.map { $0 + "\n" }.joined() == text.stdout)
  }

  @Test
  func
    `shot and tree fail as usage errors for an unknown app, a bad size, or a greedy app`()
    async throws
  {
    let unknown = await run("shot", "ghost", "--pretty")
    let badSize = await run("tree", "stack", "huge", "--pretty")
    let none = await run("shot", "--pretty")
    let extra = await run("shot", "stack", "mobile", "more", "--pretty")
    let greedy = await run("shot", "greedy", "mobile")
    let duplicate = await run(
      "shot", "stack", "--pretty",
      registry: {
        var registry = Fixtures.registry()
        registry.register("stack", viewports: [.desktop]) { StackApp() }
        return registry
      }())

    #expect(unknown.exitCode == 2)
    #expect(unknown.stderr.contains("unknown app `ghost`; accepted: "))
    #expect(badSize.exitCode == 2)
    #expect(badSize.stderr.contains("bad size `huge`"))
    #expect(none.stderr == "error: usage: shot NAME [SIZE]\n")
    #expect(extra.exitCode == 2)
    #expect(greedy.exitCode == 2)
    #expect((try object(greedy)["message"] as? String)?.contains("mobileScreen") == true)
    #expect(duplicate.exitCode == 3)
  }

  // MARK: check

  private func projectionRun(_ arguments: String...) async -> CommandOutput {
    await HarnessCLI.run(
      arguments: arguments, registry: ProjectionFixtures.registry(),
      inputIsTerminal: false,
      outputIsTerminal: false, configuration: .default)
  }

  @Test
  func `check runs every rule over the app at a size and a clean app passes`()
    async throws
  {
    let output = await projectionRun("check", "layers", "mobile")

    #expect(output.exitCode == 0)
    let object = try object(output)
    #expect(object["command"] as? String == "check")
    #expect(object["app"] as? String == "layers")
    #expect(object["exitCode"] as? Int == 0)
    #expect(object["size"] as? String == "40x6")
    #expect(
      object["rules"] as? [String] == [
        "no-dirty-after-pass", "frame-inside-clip", "measured-within-proposal",
        "siblings-disjoint", "requirements-aggregate",
      ])
    #expect((object["violations"] as? [Any])?.isEmpty == true)
  }

  @Test
  func `check exits 1 when a rule that is an error is violated and lists it`()
    async throws
  {
    let output = await projectionRun("check", "overlap")

    #expect(output.exitCode == 1)
    let violations = try #require(try object(output)["violations"] as? [[String: String]])
    #expect(violations.count == 1)
    #expect(violations[0]["rule"] == "siblings-disjoint")
    #expect(violations[0]["severity"] == "error")
    #expect(violations[0]["detail"]?.hasSuffix("under Overlap") == true)
    #expect(violations[0]["node"]?.hasPrefix("root") == true)
  }

  @Test
  func `check lists a warning with its errors and a text form that says PASS or FAIL`()
    async
  {
    let json = await projectionRun("check", "overflow")
    let text = await projectionRun("check", "overflow", "--pretty")
    let passing = await projectionRun("check", "layers", "--pretty")

    let severities = (try? object(json)["violations"] as? [[String: String]])?.compactMap
    {
      $0["severity"]
    }
    #expect(severities == ["warning", "error"])
    #expect(text.exitCode == 1)
    #expect(text.stdout.contains("  warning frame-inside-clip "))
    #expect(text.stdout.contains("  error measured-within-proposal "))
    #expect(text.stdout.hasSuffix("FAIL overflow: 1 error, 1 warning\n"))
    #expect(passing.stdout.hasPrefix("check layers at 80x24 against 5 rules: no-dirty"))
    #expect(passing.stdout.hasSuffix("PASS layers\n"))
  }

  @Test
  func `check validates its arguments and names an unknown app`() async {
    var duplicated = Fixtures.registry()
    duplicated.register("stack", viewports: [.desktop]) { StackApp() }

    let noApp = await run("check", "--pretty")
    let badSize = await run("check", "stack", "huge", "--pretty")
    let unknown = await run("check", "ghost", "--pretty")
    let duplicate = await run("check", "stack", "--pretty", registry: duplicated)
    let greedy = await run("check", "greedy", "mobile", "--pretty")

    #expect(noApp.exitCode == 2)
    #expect(noApp.stderr == "error: usage: check NAME [SIZE]\n")
    #expect(badSize.stderr.contains("bad size `huge`"))
    #expect(unknown.exitCode == 2)
    #expect(unknown.stderr.hasPrefix("error: unknown app `ghost`; accepted: "))
    #expect(duplicate.exitCode == 3)
    #expect(duplicate.stderr.contains("registered more than once"))
    #expect(greedy.exitCode == 2)
    #expect(greedy.stderr.contains("mobileScreen"))
  }

  @Test
  func `run --pretty shows a bare check's warnings under the scenario's line`()
    async throws
  {
    let scratch = try ScratchDirectory()
    try scratch.write("w.scn", "app overflow\ncheck\n")

    let output = await projectionRun("run", scratch.path, "--pretty")

    #expect(output.exitCode == 1, "the error of the same check fails the run")
    let lines = output.stdout.split(separator: "\n").map(String.init)
    let warning = try #require(lines.firstIndex { $0.hasPrefix("  line 2: warning ") })
    let failure = try #require(lines.firstIndex(of: "  line 2: check"))
    #expect(lines[warning].contains("frame-inside-clip root"))
    #expect(warning < failure, "the warnings come before the failures")
    #expect(lines[failure + 1].hasPrefix("    measured-within-proposal at root"))
  }

  @Test
  func `a scenario that passes with warnings prints them under its PASS line`() {
    let report = ScenarioReport(
      scenario: "flex.scn", failures: [],
      observations: [
        ScenarioObservation(
          line: 7, verb: "check", name: nil,
          lines: [
            "ran no-dirty-after-pass, frame-inside-clip",
            "warning frame-inside-clip root/a: shows 0,0,9x1",
          ]),
        ScenarioObservation(
          line: 9, verb: "check", name: nil, lines: ["ran no-dirty-after-pass"]),
        ScenarioObservation(
          line: 3, verb: "shot", name: "a", lines: ["warning: not a check"]),
      ])

    #expect(
      report.description
        == "PASS flex.scn\n  line 7: warning frame-inside-clip root/a: shows 0,0,9x1")
    #expect(report.json.contains("warning frame-inside-clip root/a"))
  }

  @Test
  func `an empty path, name, or flag value is a usage error and nothing runs`()
    async throws
  {
    let scratch = try ScratchDirectory()
    try scratch.write("a.scn", passing)
    let out = scratch.appending("traces")

    let trace = await run("run", scratch.path, "--trace", "", "--pretty")
    let path = await run("run", "", "--pretty")
    let inside = await run("run", scratch.path, "", "--pretty")
    let shot = await run("shot", "", "--pretty")
    let tree = await run("tree", "", "--pretty")
    let check = await run("check", "", "--pretty")
    let file = await run("replay", "", "--app", "stack", "--pretty")
    let app = await run("replay", "t.jsonl", "--app", "", "--pretty")
    let json = await run("run", scratch.path, "--trace", "")

    for output in [trace, path, inside, shot, tree, check, file, app, json] {
      #expect(output.exitCode == 2, "\(output.stderr)\(output.stdout)")
    }
    #expect(trace.stderr == "error: `--trace` needs a value that is not empty\n")
    #expect(trace.stdout.isEmpty, "no scenario ran")
    #expect(
      path.stderr == "error: an empty argument is not a path or an application name\n")
    #expect(app.stderr == "error: `--app` needs a value that is not empty\n")
    #expect(
      try object(json)["message"] as? String
        == "`--trace` needs a value that is not empty")
    #expect(!FileManager.default.fileExists(atPath: out))
  }

  @Test
  func `the help overview spells replay's required flag`() async {
    let overview = await run("help")

    #expect(overview.exitCode == 0)
    #expect(
      overview.stdout.contains(
        "  replay FILE --app NAME  rerun a recorded trace against an application\n"))
    #expect(overview.stdout.contains("  check NAME [SIZE]       check one application"))
  }

  // MARK: trace and replay

  @Test
  func `run --trace writes one trace file per scenario under the directory`() async throws
  {
    let scratch = try ScratchDirectory()
    try scratch.write("a.scn", traced)
    try scratch.write("nested/b.scn", traced)
    let out = scratch.appending("traces")

    let output = await run("run", scratch.path, "--trace", out, "--pretty")

    #expect(output.exitCode == 0)
    let files = [
      TraceFile.path(forScenario: scratch.appending("a.scn"), in: out),
      TraceFile.path(forScenario: scratch.appending("nested/b.scn"), in: out),
    ]
    for file in files {
      let text = try #require(
        FileManager.default.contents(atPath: file).flatMap {
          String(validating: $0, as: UTF8.self)
        }, "no trace at \(file)")
      let records = try TraceFile.records(in: text)
      #expect(records.map(\.seq) == [0, 1, 2, 3, 4, 5])
      #expect(records[4].event == TraceEvent(.resize(TerminalSize(columns: 30, rows: 8))))
    }
  }

  @Test
  func `replay runs a recorded trace again and passes against the app it came from`()
    async throws
  {
    let scratch = try ScratchDirectory()
    let scenario = try scratch.write("a.scn", traced)
    let out = scratch.appending("traces")
    _ = await run("run", scenario, "--trace", out, "--pretty")
    let file = TraceFile.path(forScenario: scenario, in: out)

    let output = await run("replay", file, "--app", "stack")

    #expect(output.exitCode == 0, "\(output.stdout)")
    let object = try object(output)
    #expect(object["command"] as? String == "replay")
    let report = try #require((object["scenarios"] as? [[String: Any]])?.first)
    #expect(report["passed"] as? Bool == true)
    #expect(report["scenario"] as? String == file)
    let final = (report["observations"] as? [[String: Any]])?.last?["lines"] as? [String]
    #expect(final?.first == "Stack demo")
  }

  @Test
  func `replay against a different app exits 1 and names the step that differs`()
    async throws
  {
    let scratch = try ScratchDirectory()
    let scenario = try scratch.write("a.scn", traced)
    let out = scratch.appending("traces")
    _ = await run("run", scenario, "--trace", out, "--pretty")
    let file = TraceFile.path(forScenario: scenario, in: out)
    var other = ApplicationRegistry()
    other.register("stack", viewports: [.desktop]) { GreedyApp() }

    let output = await run("replay", file, "--app", "stack", "--pretty", registry: other)

    #expect(output.exitCode == 1)
    #expect(output.stdout.hasPrefix("FAIL \(file)\n"))
    #expect(output.stdout.contains("line 1: step 0: resize 40x10"))
    #expect(output.stdout.contains("differ from the recording"))
  }

  @Test
  func `replay validates its arguments, its file, and its app`() async throws {
    let scratch = try ScratchDirectory()
    let notTrace = try scratch.write("nope.jsonl", "not json\n")
    let binary = scratch.appending("bin.jsonl")
    try Data([0xff, 0xfe, 0x00]).write(to: URL(fileURLWithPath: binary))

    let noFile = await run("replay", "--app", "stack", "--pretty")
    let noName = await run("replay", "run.trace", "--pretty")
    let missing = await run(
      "replay", scratch.appending("none.jsonl"), "--app", "stack", "--pretty")
    let notUTF8 = await run("replay", binary, "--app", "stack", "--pretty")
    let notRecords = await run("replay", notTrace, "--app", "stack", "--pretty")
    let unknown = await run("replay", "run.trace", "--app", "ghost", "--pretty")

    #expect(noFile.stderr == "error: usage: replay FILE --app NAME\n")
    #expect(noName.stderr == "error: usage: replay FILE --app NAME\n")
    #expect(missing.exitCode == 2)
    #expect(missing.stderr.contains("cannot read the trace"))
    #expect(notUTF8.exitCode == 2)
    #expect(notUTF8.stderr.contains("is not UTF-8 text"))
    #expect(notRecords.exitCode == 2)
    #expect(
      notRecords.stderr.hasPrefix("error: ") || notRecords.stdout.contains("error:"))
    #expect(unknown.exitCode == 2)
    #expect(unknown.stderr.hasPrefix("error: unknown app `ghost`; accepted: "))
  }

  @Test
  func `launch with a trace file it cannot create exits 3 before the terminal changes`()
    async throws
  {
    let scratch = try ScratchDirectory()

    let output = await HarnessCLI.run(
      arguments: ["launch", "stack", "--pretty"], registry: Fixtures.registry(),
      inputIsTerminal: true, outputIsTerminal: true, configuration: .default,
      environment: ["TESSERA_TRACE": scratch.path])

    #expect(output.exitCode == 3)
    #expect(
      output.stderr.hasPrefix("error: cannot create the trace file `\(scratch.path)`"))
  }

  // MARK: help

  @Test
  func `help describes every command, and the overview names each one`() async {
    let overview = await run("help")

    for command in HarnessCLI.commands {
      #expect(overview.stdout.contains(command), "\(command)")
      let help = await run("help", command)
      #expect(help.stdout.hasPrefix("usage: \(command)"), "\(command)")
      #expect(help.stdout.count > 60, "\(command)")
    }
    let runHelp = await run("help", "run")
    for flag in [
      "--record", "--repeat N", "--timing", "--trace DIR", "--json", "--pretty",
    ] {
      #expect(runHelp.stdout.contains(flag), "\(flag)")
    }
    for field in [#""change": "created" or "updated""#, #""line" 0"#, #""--repeat N""#] {
      #expect(runHelp.stdout.contains(field), "\(field)")
    }
  }
}
