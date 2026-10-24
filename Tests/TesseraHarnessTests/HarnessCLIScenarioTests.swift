import Foundation
import TesseraTerminal
import TesseraTerminalCore
import Testing

@testable import TesseraHarness

private let passing = "app stack\nsize 40x10\nexpect text 0 \"Stack demo\"\n"
private let failing = "app stack\nsize 40x10\nexpect text 0 \"Stack demos\"\n"

@MainActor
struct HarnessCLIScenarioTests {
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
        + "--repeat, --timing\n")
    #expect(noValue.stderr.contains("`--repeat` needs a value"))
    #expect(
      zero.stderr.contains("`--repeat` needs a whole number of at least 1, got `0`"))
    #expect(word.exitCode == 2)
    #expect(twice.stderr.contains("`--repeat` is given twice"))
  }

  @Test
  func `record, repeat, and timing reach the runner`() async throws {
    let scratch = try ScratchDirectory()
    try scratch.write("a.scn", "app stack\nsize 40x10\nshot s")

    let recorded = await run("run", scratch.path, "--record", "--repeat", "2", "--timing")
    let checked = await run("run", scratch.path)

    #expect(recorded.exitCode == 0)
    let report = try #require(try reports(recorded).first)
    #expect((report["recorded"] as? [[String: Any]])?.count == 1)
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

  // MARK: check and replay

  @Test
  func `check and replay say they are not yet available instead of passing`() async throws
  {
    let check = await run("check", "stack")
    let replay = await run("replay", "run.trace", "--app", "stack")

    for (output, name) in [(check, "check"), (replay, "replay")] {
      #expect(output.exitCode == 2, "\(name)")
      let object = try object(output)
      #expect(object["command"] as? String == name)
      #expect(object["exitCode"] as? Int == 2)
      #expect((object["message"] as? String)?.contains("is not yet available") == true)
    }
  }

  @Test
  func `check and replay still validate their arguments`() async {
    let noApp = await run("check", "--pretty")
    let badSize = await run("check", "stack", "huge", "--pretty")
    let noFile = await run("replay", "--app", "stack", "--pretty")
    let noName = await run("replay", "run.trace", "--pretty")

    #expect(noApp.stderr == "error: usage: check NAME [SIZE]\n")
    #expect(badSize.stderr.contains("bad size `huge`"))
    #expect(noFile.stderr == "error: usage: replay FILE --app NAME\n")
    #expect(noName.stderr == "error: usage: replay FILE --app NAME\n")
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
    for flag in ["--record", "--repeat N", "--timing", "--json", "--pretty"] {
      #expect(runHelp.stdout.contains(flag), "\(flag)")
    }
  }
}
