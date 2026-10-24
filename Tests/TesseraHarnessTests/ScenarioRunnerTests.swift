import Foundation
import TesseraCore
import TesseraRuntime
import TesseraTerminalInput
import Testing

@testable import TesseraHarness

/// Counts the apps the factory has built, so a scenario can see that it ran again.
@MainActor
private enum Builds {
  static var count = 0
}

/// Shows how many apps have been built: it differs on every run of a scenario.
private final class TickApp: Application {
  private let run: Int

  var body: some View {
    Text("Run \(run)")
  }

  init(run: Int) {
    self.run = run
  }

  func apply(_ event: InputEvent) {}
}

private let stackScenario = """
  app stack
  size 40x10
  type "Rob"
  expect text 2 "Name: Rob"
  shot after-typing
  """

@MainActor
struct ScenarioRunnerFileTests {
  private func registry() -> ApplicationRegistry {
    var registry = Fixtures.registry()
    registry.register("tick", viewports: [.desktop]) {
      Builds.count += 1
      return TickApp(run: Builds.count)
    }
    return registry
  }

  private func runner(record: Bool = false) -> ScenarioRunner {
    ScenarioRunner(registry: registry(), record: record)
  }

  // MARK: Discovery

  @Test
  func
    `a directory runs its scenarios in sorted order, at any depth, and skips the rest`()
    async throws
  {
    let scratch = try ScratchDirectory()
    try scratch.write("b.scn", "app stack\nsize 40x10\nshot a")
    try scratch.write("a.scn", "app stack\nsize 40x10\nshot a")
    try scratch.write("nested/deep/c.scn", "app stack\nsize 40x10\nshot a")
    try scratch.write("nested/a.scn", "app stack\nsize 40x10\nshot a")
    try scratch.write("notes.txt", "not a scenario")
    try scratch.write(".hidden/z.scn", "not parsed")

    let reports = await runner().run(scratch.path)

    #expect(
      reports.map(\.scenario) == [
        scratch.appending("a.scn"), scratch.appending("b.scn"),
        scratch.appending("nested/a.scn"), scratch.appending("nested/deep/c.scn"),
      ])
  }

  @Test
  func `a trailing separator does not double the one between directory and file`()
    async throws
  {
    let scratch = try ScratchDirectory()
    try scratch.write("a.scn", "app stack\nsize 40x10")

    let reports = await runner().run(scratch.path + "/")

    #expect(reports.map(\.scenario) == [scratch.appending("a.scn")])
  }

  @Test
  func `paths that cannot run report a usage failure and the run goes on`() async throws {
    let scratch = try ScratchDirectory()
    try scratch.write("ok.scn", "app stack\nsize 40x10")
    try scratch.write("plain.txt", "app stack")
    try FileManager.default.createDirectory(
      atPath: scratch.appending("empty"), withIntermediateDirectories: true)

    let reports = await runner().run(
      scratch.appending("missing.scn"), scratch.appending("plain.txt"),
      scratch.appending("empty"), scratch.appending("ok.scn"))

    #expect(reports.map(\.passed) == [false, false, false, true])
    #expect(
      reports.prefix(3).flatMap(\.failures).map(\.verb) == ["usage", "usage", "usage"])
    #expect(reports[0].failures[0].message == "no such file or directory")
    #expect(reports[1].failures[0].message == "scenario files end in `.scn`")
    #expect(reports[2].failures[0].message.hasPrefix("no scenario files (*.scn)"))
  }

  @Test
  func `no paths run nothing`() async {
    let reports = await runner().run(paths: [])

    #expect(reports.isEmpty)
  }

  @Test
  func `a deliberately failing scenario fails four expectations and runs past each`()
    async throws
  {
    let file = pathBesideSource("Scenarios/failing/mismatch.scn")

    let reports = await runner().run(file)

    #expect(reports.map(\.passed) == [false])
    #expect(reports[0].failures.map(\.line) == [6, 7, 8, 10])
    #expect(
      reports[0].failures.map(\.verb) == [
        "expect text", "expect text", "expect node", "expect node",
      ])
  }

  // MARK: Parse errors

  @Test
  func `a scenario that does not parse reports a parse failure and others still run`()
    async throws
  {
    let scratch = try ScratchDirectory()
    let bad = try scratch.write("a-bad.scn", "app stack\nsize 40x10\nblink 3\n")
    try scratch.write("b-good.scn", "app stack\nsize 40x10\nexpect text 0 \"Stack demo\"")

    let reports = await runner().run(scratch.path)

    #expect(reports.map(\.passed) == [false, true])
    let failure = try #require(reports.first?.failures.first)
    #expect(failure.verb == "parse")
    #expect(failure.line == 3)
    #expect(failure.statement == "blink 3")
    #expect(
      failure.message.hasPrefix("unknown statement `blink`; accepted: app, size, term"))
    #expect(
      reports[0].description.hasPrefix(
        "FAIL \(bad)\n\(bad):3: error: unknown statement `blink`"))
    #expect(
      reports[0].json.hasPrefix(
        #"{"failures":[{"line":3,"message":"unknown statement `blink`; accepted:"#))
    #expect(reports[0].json.contains(#""verb":"parse""#))
  }

  @Test
  func `a file with a byte order mark and CRLF line ends runs as written`() async throws {
    let scratch = try ScratchDirectory()
    let body =
      "app stack\r\nsize 40x10\r\ntype \"Rob\"\r\nexpect text 2 \"Name: Rob\"\r\n"
    try scratch.write("crlf.scn", "\u{FEFF}" + body)

    let reports = await runner().run(scratch.path)

    #expect(reports.map(\.passed) == [true], "\(reports)")
  }

  @Test
  func `a duplicate name in the registry fails every scenario with a harness failure`()
    async throws
  {
    let scratch = try ScratchDirectory()
    try scratch.write("a.scn", "app stack")
    var registry = Fixtures.registry()
    registry.register("stack", viewports: [.desktop]) { StackApp() }

    let reports = await ScenarioRunner(registry: registry).run(scratch.path)

    #expect(reports.count == 1)
    #expect(reports[0].failures.first?.verb == "harness")
    #expect(
      reports[0].failures.first?.message.contains("registered more than once") == true)
  }

  // MARK: Goldens

  @Test
  func `a shot with no golden fails without record and says how to create it`()
    async throws
  {
    let scratch = try ScratchDirectory()
    try scratch.write("stack.scn", stackScenario)

    let reports = await runner().run(scratch.path)

    let failure = try #require(reports.first?.failures.first)
    #expect(failure.verb == "shot")
    #expect(failure.line == 5)
    #expect(failure.message.contains("has no golden at"))
    #expect(failure.message.contains("run with --record"))
    #expect(failure.screen == nil)
    #expect(scratch.read("stack/after-typing.txt") == nil)
  }

  @Test
  func `record writes the goldens, and the next run without record passes`() async throws
  {
    let scratch = try ScratchDirectory()
    try scratch.write("stack.scn", stackScenario)

    let recorded = await runner(record: true).run(scratch.path)
    let checked = await runner().run(scratch.path)

    #expect(recorded.map(\.passed) == [true])
    #expect(
      recorded[0].recorded == [
        GoldenChange(path: scratch.appending("stack/after-typing.txt"), change: .created)
      ])
    #expect(checked.map(\.passed) == [true])
    #expect(checked[0].recorded.isEmpty)
    #expect(
      scratch.read("stack/after-typing.txt")
        == """
        Stack demo
        ────────────────────────────────────────
        Name: Rob
        left                               right
        ────────────────────────────────────────
        40 columns

        """)
  }

  @Test
  func `a drifted golden fails without record with the first differing row`() async throws
  {
    let scratch = try ScratchDirectory()
    try scratch.write("stack.scn", stackScenario)
    _ = await runner(record: true).run(scratch.path)
    let golden = scratch.appending("stack/after-typing.txt")
    try Data(
      (scratch.read("stack/after-typing.txt") ?? "")
        .replacingOccurrences(of: "Name: Rob", with: "Name: Bob").utf8
    ).write(to: URL(fileURLWithPath: golden))

    let reports = await runner().run(scratch.path)

    #expect(reports.map(\.passed) == [false])
    let failure = try #require(reports.first?.failures.first)
    #expect(failure.verb == "shot")
    #expect(failure.expected == "Name: Bob")
    #expect(failure.actual == "Name: Rob")
    #expect(failure.message.contains("differs from"))
    #expect(failure.message.contains("at row 2"))
    #expect(failure.message.contains("rerun with --record and review"))
    #expect(failure.screen?.count == 6)
    #expect(scratch.read("stack/after-typing.txt")?.contains("Name: Bob") == true)
  }

  @Test
  func `record rewrites a drifted golden and lists what changed`() async throws {
    let scratch = try ScratchDirectory()
    try scratch.write("stack.scn", stackScenario)
    try scratch.write("stack/after-typing.txt", "old\n")

    let reports = await runner(record: true).run(scratch.path)

    #expect(reports.map(\.passed) == [true])
    #expect(
      reports[0].recorded == [
        GoldenChange(path: scratch.appending("stack/after-typing.txt"), change: .updated)
      ])
    #expect(reports[0].description.contains("recorded"))
    #expect(reports[0].description.contains("(updated)"))
    #expect(scratch.read("stack/after-typing.txt")?.hasPrefix("Stack demo\n") == true)
  }

  @Test
  func `record leaves an unchanged golden alone and lists nothing`() async throws {
    let scratch = try ScratchDirectory()
    try scratch.write("stack.scn", stackScenario)
    _ = await runner(record: true).run(scratch.path)

    let again = await runner(record: true).run(scratch.path)

    #expect(again[0].passed)
    #expect(again[0].recorded.isEmpty)
    #expect(!again[0].json.contains("recorded"))
  }

  @Test
  func `a golden checked out with CRLF line ends fails and says to check it out with LF`()
    async throws
  {
    let scratch = try ScratchDirectory()
    try scratch.write("stack.scn", stackScenario)
    _ = await runner(record: true).run(scratch.path)
    let lf = try #require(scratch.read("stack/after-typing.txt"))
    try scratch.write(
      "stack/after-typing.txt", lf.replacingOccurrences(of: "\n", with: "\r\n"))

    let reports = await runner().run(scratch.path)

    let failure = try #require(reports.first?.failures.first)
    #expect(failure.message.contains("CRLF line endings"))
    #expect(failure.message.contains("eol=lf"))
  }

  @Test
  func `a CRLF golden that has also drifted says CRLF and not a difference at row 0`()
    async throws
  {
    let scratch = try ScratchDirectory()
    try scratch.write("stack.scn", stackScenario)
    _ = await runner(record: true).run(scratch.path)
    let lf = try #require(scratch.read("stack/after-typing.txt"))
    try scratch.write(
      "stack/after-typing.txt",
      lf.replacingOccurrences(of: "Name: Rob", with: "Name: Bob")
        .replacingOccurrences(of: "\n", with: "\r\n"))

    let reports = await runner().run(scratch.path)
    let recorded = await runner(record: true).run(scratch.path)

    let failure = try #require(reports.first?.failures.first)
    #expect(failure.verb == "shot")
    #expect(failure.message.contains("CRLF line endings"))
    #expect(failure.expected == nil)
    #expect(failure.actual == nil)
    #expect(failure.screen == nil)
    #expect(recorded.map(\.passed) == [true])
    #expect(scratch.read("stack/after-typing.txt") == lf)
  }

  @Test
  func `a golden is the trimmed screen with trailing empty rows dropped`() {
    #expect(GoldenStore.text(of: ["a", "", "b", "", ""]) == "a\n\nb\n")
    #expect(GoldenStore.text(of: []) == "\n")
    #expect(GoldenStore.text(of: [""]) == "\n")
  }

  @Test
  func `goldens live in a directory named like the scenario file`() {
    let store = GoldenStore(
      scenarioPath: "Examples/Scenarios/counter-basics.scn", record: false)

    #expect(store.directory == "Examples/Scenarios/counter-basics")
    #expect(store.path(for: "reset") == "Examples/Scenarios/counter-basics/reset.txt")
  }

  // MARK: Determinism, repeat, timing

  @Test
  func `two runs of the same scenarios produce the same bytes`() async throws {
    let scratch = try ScratchDirectory()
    try scratch.write("stack.scn", stackScenario)
    try scratch.write("bad.scn", "app stack\nexpect text 0 \"wrong\"\ntree")
    _ = await runner(record: true).run(scratch.appending("stack.scn"))

    let first = await runner().run(scratch.path).map(\.json)
    let second = await runner().run(scratch.path).map(\.json)

    #expect(first == second)
    #expect(first.count == 2)
  }

  @Test
  func `repeat runs a scenario again and a deterministic one does not diverge`()
    async throws
  {
    let scratch = try ScratchDirectory()
    try scratch.write("stack.scn", stackScenario)
    _ = await runner(record: true).run(scratch.path)
    var repeating = runner()
    repeating.repetitions = 3

    let reports = await repeating.run(scratch.path)

    #expect(reports.map(\.passed) == [true])
  }

  @Test
  func `repeat fails a scenario whose output differs from run to run`() async throws {
    let scratch = try ScratchDirectory()
    try scratch.write("tick.scn", "app tick\nsize 20x2\ntree\nexpect text 0 \"Run 1\"")
    Builds.count = 0
    var repeating = runner()
    repeating.repetitions = 3

    let reports = await repeating.run(scratch.path)

    #expect(Builds.count == 3)
    let failures = try #require(reports.first?.failures)
    #expect(failures.map(\.verb) == ["repeat", "repeat"])
    #expect(failures[0].statement == "--repeat 3")
    #expect(failures[0].message.hasPrefix("run 2 of 3 differs from run 1: "))
    #expect(failures[0].message.contains("it has 1 failures where run 1 has 0"))
  }

  @Test
  func `only the first of several repeated runs records`() async throws {
    let scratch = try ScratchDirectory()
    try scratch.write("stack.scn", stackScenario)
    var repeating = runner(record: true)
    repeating.repetitions = 2

    let reports = await repeating.run(scratch.path)

    #expect(reports.map(\.passed) == [true])
    #expect(reports[0].recorded.count == 1)
  }

  @Test
  func `timing adds the seconds of each run and nothing else changes`() async throws {
    let scratch = try ScratchDirectory()
    try scratch.write("stack.scn", stackScenario)
    _ = await runner(record: true).run(scratch.path)
    var timed = runner()
    timed.measuresTime = true
    timed.repetitions = 2

    let untimed = await runner().run(scratch.path)
    let reports = await timed.run(scratch.path)

    #expect(untimed[0].seconds.isEmpty)
    #expect(!untimed[0].json.contains("seconds"))
    #expect(reports[0].seconds.count == 2)
    #expect(reports[0].json.contains(#""seconds":["#))
    #expect(reports[0].comparable == untimed[0].comparable)
    #expect(reports[0].description.hasPrefix("PASS \(scratch.appending("stack.scn")) ("))
  }
}

@MainActor
struct ScenarioReportShapeTests {
  private let failing = ScenarioReport(
    scenario: "a.scn",
    failures: [
      ScenarioFailure(
        line: 4, statement: "expect text 0 \"x\"", verb: "expect text",
        message: "row 0 text differs", expected: "x", actual: "y", screen: ["y"]),
      ScenarioFailure(line: 6, statement: "key Tab", verb: "harness", message: "m"),
    ],
    observations: [ScenarioObservation(line: 2, verb: "shot", name: "s", lines: ["y"])]
  )

  @Test
  func `the JSON form is one compact sorted-key line with the promised fields`() throws {
    let json = failing.json

    #expect(!json.contains("\n"))
    #expect(
      json
        == #"{"failures":[{"actual":"y","expected":"x","line":4,"message":"row 0 text differs","#
        + #""screen":["y"],"statement":"expect text 0 \"x\"","verb":"expect text"},"#
        + #"{"line":6,"message":"m","statement":"key Tab","verb":"harness"}],"#
        + #""observations":[{"line":2,"lines":["y"],"name":"s","verb":"shot"}],"#
        + #""passed":false,"scenario":"a.scn"}"#)
  }

  @Test
  func `a passing report is passed true with empty arrays`() {
    let report = ScenarioReport(scenario: "ok.scn", failures: [])

    #expect(
      report.json
        == #"{"failures":[],"observations":[],"passed":true,"scenario":"ok.scn"}"#)
    #expect(report.description == "PASS ok.scn")
  }

  @Test
  func `the human form shows the statement, expected, actual, and the screen`() {
    #expect(
      failing.description
        == """
        FAIL a.scn
          line 4: expect text 0 "x"
            row 0 text differs
            expected: x
            actual:   y
            screen:
              0| y
          line 6: key Tab
            m
        """)
  }

  @Test
  func `a parse failure prints as FILE LINE error and a usage failure as FILE error`() {
    let parse = ScenarioReport.parseFailure(
      ScenarioParseError(file: "p.scn", line: 3, source: "blink", message: "unknown"))
    let usage = ScenarioReport.failure(
      scenario: "dir", verb: "usage", message: "no such file")

    #expect(parse.description == "FAIL p.scn\np.scn:3: error: unknown")
    #expect(usage.description == "FAIL dir\ndir: error: no such file")
    #expect(parse.failures[0].statement == "blink")
    #expect(parse.failures[0].message == "unknown")
  }
}
