import CustomDump
import Foundation
import InlineSnapshotTesting
import SnapshotTesting
import SnapshotTestingCustomDump
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

    expectNoDifference(
      reports.map(\.scenario),
      [
        scratch.appending("a.scn"), scratch.appending("b.scn"),
        scratch.appending("nested/a.scn"), scratch.appending("nested/deep/c.scn"),
      ]
    )
  }

  @Test
  func `a trailing separator does not double the one between directory and file`()
    async throws
  {
    let scratch = try ScratchDirectory()
    try scratch.write("a.scn", "app stack\nsize 40x10")

    let reports = await runner().run(scratch.path + "/")

    expectNoDifference(reports.map(\.scenario), [scratch.appending("a.scn")])
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

    assertInlineSnapshot(of: scratch.dump(reports), as: .lines) {
      """
      [
        [0]: ScenarioReport(
          scenario: "<scratch>/missing.scn",
          failures: [
            [0]: ScenarioFailure(
              line: 0,
              statement: "",
              verb: "usage",
              message: "no such file or directory",
              expected: nil,
              actual: nil,
              screen: nil
            )
          ],
          observations: [],
          recorded: [],
          seconds: []
        ),
        [1]: ScenarioReport(
          scenario: "<scratch>/plain.txt",
          failures: [
            [0]: ScenarioFailure(
              line: 0,
              statement: "",
              verb: "usage",
              message: "scenario files end in `.scn`",
              expected: nil,
              actual: nil,
              screen: nil
            )
          ],
          observations: [],
          recorded: [],
          seconds: []
        ),
        [2]: ScenarioReport(
          scenario: "<scratch>/empty",
          failures: [
            [0]: ScenarioFailure(
              line: 0,
              statement: "",
              verb: "usage",
              message: "no scenario files (*.scn) under this directory",
              expected: nil,
              actual: nil,
              screen: nil
            )
          ],
          observations: [],
          recorded: [],
          seconds: []
        ),
        [3]: ScenarioReport(
          scenario: "<scratch>/ok.scn",
          failures: [],
          observations: [],
          recorded: [],
          seconds: []
        )
      ]
      """
    }
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
    assertInlineSnapshot(of: reports[0].failures, as: .customDump) {
      """
      [
        [0]: ScenarioFailure(
          line: 6,
          statement: #"expect text 0 "Stack demos""#,
          verb: "expect text",
          message: "row 0 text differs",
          expected: "Stack demos",
          actual: "Stack demo",
          screen: [
            [0]: "Stack demo",
            [1]: "────────────────────────────────────────",
            [2]: "Name: -",
            [3]: "left                               right",
            [4]: "────────────────────────────────────────",
            [5]: "40 columns"
          ]
        ),
        [1]: ScenarioFailure(
          line: 7,
          statement: #"expect text "no such text""#,
          verb: "expect text",
          message: "no screen row contains the text",
          expected: "no such text",
          actual: "(not found in 10 rows)",
          screen: [
            [0]: "Stack demo",
            [1]: "────────────────────────────────────────",
            [2]: "Name: -",
            [3]: "left                               right",
            [4]: "────────────────────────────────────────",
            [5]: "40 columns"
          ]
        ),
        [2]: ScenarioFailure(
          line: 8,
          statement: "expect node id=root frame 0,0,40x6",
          verb: "expect node",
          message: "frame of `id=root` differs",
          expected: "0,0,40x6",
          actual: "0,0,40x10",
          screen: [
            [0]: "Stack demo",
            [1]: "────────────────────────────────────────",
            [2]: "Name: -",
            [3]: "left                               right",
            [4]: "────────────────────────────────────────",
            [5]: "40 columns"
          ]
        ),
        [3]: ScenarioFailure(
          line: 10,
          statement: "expect node type=Missing frame 0,0,1x1",
          verb: "expect node",
          message: "locator `type=Missing` matches no node",
          expected: "0,0,1x1",
          actual: "(no node; types: TupleView, VStack, Text, Divider, HStack, Spacer)",
          screen: [
            [0]: "Stack demo",
            [1]: "────────────────────────────────────────",
            [2]: "Name: -",
            [3]: "left                               right",
            [4]: "────────────────────────────────────────",
            [5]: "40 columns"
          ]
        )
      ]
      """
    }
  }

  // MARK: Parse errors

  @Test
  func `a scenario that does not parse reports a parse failure and others still run`()
    async throws
  {
    let scratch = try ScratchDirectory()
    try scratch.write("a-bad.scn", "app stack\nsize 40x10\nblink 3\n")
    try scratch.write("b-good.scn", "app stack\nsize 40x10\nexpect text 0 \"Stack demo\"")

    let reports = await runner().run(scratch.path)

    assertInlineSnapshot(of: scratch.dump(reports), as: .lines) {
      """
      [
        [0]: ScenarioReport(
          scenario: "<scratch>/a-bad.scn",
          failures: [
            [0]: ScenarioFailure(
              line: 3,
              statement: "blink 3",
              verb: "parse",
              message: "unknown statement `blink`; accepted: app, size, term, resize, key, type, paste, bytes, shot, tree, expect text, expect screen, expect node",
              expected: nil,
              actual: nil,
              screen: nil
            )
          ],
          observations: [],
          recorded: [],
          seconds: []
        ),
        [1]: ScenarioReport(
          scenario: "<scratch>/b-good.scn",
          failures: [],
          observations: [],
          recorded: [],
          seconds: []
        )
      ]
      """
    }
    assertInlineSnapshot(of: scratch.redacted(reports[0].description), as: .lines) {
      """
      FAIL <scratch>/a-bad.scn
      <scratch>/a-bad.scn:3: error: unknown statement `blink`; accepted: app, size, term, resize, key, type, paste, bytes, shot, tree, expect text, expect screen, expect node
      """
    }
    assertInlineSnapshot(of: scratch.redacted(reports[0].json), as: .lines) {
      """
      {"failures":[{"line":3,"message":"unknown statement `blink`; accepted: app, size, term, resize, key, type, paste, bytes, shot, tree, expect text, expect screen, expect node","statement":"blink 3","verb":"parse"}],"observations":[],"passed":false,"scenario":"<scratch>/a-bad.scn"}
      """
    }
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

    assertInlineSnapshot(of: scratch.dump(reports), as: .lines) {
      """
      [
        [0]: ScenarioReport(
          scenario: "<scratch>/a.scn",
          failures: [
            [0]: ScenarioFailure(
              line: 0,
              statement: "",
              verb: "harness",
              message: "applications registered more than once: `stack`",
              expected: nil,
              actual: nil,
              screen: nil
            )
          ],
          observations: [],
          recorded: [],
          seconds: []
        )
      ]
      """
    }
  }

  // MARK: Goldens

  @Test
  func `a shot with no golden fails without record and says how to create it`()
    async throws
  {
    let scratch = try ScratchDirectory()
    try scratch.write("stack.scn", stackScenario)

    let reports = await runner().run(scratch.path)

    assertInlineSnapshot(of: scratch.dump(reports), as: .lines) {
      """
      [
        [0]: ScenarioReport(
          scenario: "<scratch>/stack.scn",
          failures: [
            [0]: ScenarioFailure(
              line: 5,
              statement: "shot after-typing",
              verb: "shot",
              message: "shot `after-typing` has no golden at `<scratch>/stack/after-typing.txt`; run with --record to create it, and review the file",
              expected: nil,
              actual: nil,
              screen: nil
            )
          ],
          observations: [
            [0]: ScenarioObservation(
              line: 5,
              verb: "shot",
              name: "after-typing",
              lines: [
                [0]: "Stack demo",
                [1]: "────────────────────────────────────────",
                [2]: "Name: Rob",
                [3]: "left                               right",
                [4]: "────────────────────────────────────────",
                [5]: "40 columns"
              ]
            )
          ],
          recorded: [],
          seconds: []
        )
      ]
      """
    }
    #expect(scratch.read("stack/after-typing.txt") == nil)
  }

  @Test
  func `record writes the goldens, and the next run without record passes`() async throws
  {
    let scratch = try ScratchDirectory()
    try scratch.write("stack.scn", stackScenario)

    let recorded = await runner(record: true).run(scratch.path)
    let checked = await runner().run(scratch.path)

    assertInlineSnapshot(of: scratch.dump(recorded), as: .lines) {
      """
      [
        [0]: ScenarioReport(
          scenario: "<scratch>/stack.scn",
          failures: [],
          observations: [
            [0]: ScenarioObservation(
              line: 5,
              verb: "shot",
              name: "after-typing",
              lines: [
                [0]: "Stack demo",
                [1]: "────────────────────────────────────────",
                [2]: "Name: Rob",
                [3]: "left                               right",
                [4]: "────────────────────────────────────────",
                [5]: "40 columns"
              ]
            )
          ],
          recorded: [
            [0]: GoldenChange(
              path: "<scratch>/stack/after-typing.txt",
              change: .created
            )
          ],
          seconds: []
        )
      ]
      """
    }
    assertInlineSnapshot(of: scratch.dump(checked), as: .lines) {
      """
      [
        [0]: ScenarioReport(
          scenario: "<scratch>/stack.scn",
          failures: [],
          observations: [
            [0]: ScenarioObservation(
              line: 5,
              verb: "shot",
              name: "after-typing",
              lines: [
                [0]: "Stack demo",
                [1]: "────────────────────────────────────────",
                [2]: "Name: Rob",
                [3]: "left                               right",
                [4]: "────────────────────────────────────────",
                [5]: "40 columns"
              ]
            )
          ],
          recorded: [],
          seconds: []
        )
      ]
      """
    }
    assertInlineSnapshot(of: scratch.read("stack/after-typing.txt"), as: .lines) {
      """
      Stack demo
      ────────────────────────────────────────
      Name: Rob
      left                               right
      ────────────────────────────────────────
      40 columns

      """
    }
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

    assertInlineSnapshot(of: scratch.dump(reports), as: .lines) {
      #"""
      [
        [0]: ScenarioReport(
          scenario: "<scratch>/stack.scn",
          failures: [
            [0]: ScenarioFailure(
              line: 5,
              statement: "shot after-typing",
              verb: "shot",
              message: "shot `after-typing` differs from `<scratch>/stack/after-typing.txt` at row 2: the golden has 6 rows and the screen has 6. If the new rendering is intended, rerun with --record and review the golden\'s diff",
              expected: "Name: Bob",
              actual: "Name: Rob",
              screen: [
                [0]: "Stack demo",
                [1]: "────────────────────────────────────────",
                [2]: "Name: Rob",
                [3]: "left                               right",
                [4]: "────────────────────────────────────────",
                [5]: "40 columns"
              ]
            )
          ],
          observations: [
            [0]: ScenarioObservation(
              line: 5,
              verb: "shot",
              name: "after-typing",
              lines: [
                [0]: "Stack demo",
                [1]: "────────────────────────────────────────",
                [2]: "Name: Rob",
                [3]: "left                               right",
                [4]: "────────────────────────────────────────",
                [5]: "40 columns"
              ]
            )
          ],
          recorded: [],
          seconds: []
        )
      ]
      """#
    }
    #expect(scratch.read("stack/after-typing.txt")?.contains("Name: Bob") == true)
  }

  @Test
  func `record rewrites a drifted golden and lists what changed`() async throws {
    let scratch = try ScratchDirectory()
    try scratch.write("stack.scn", stackScenario)
    try scratch.write("stack/after-typing.txt", "old\n")

    let reports = await runner(record: true).run(scratch.path)

    assertInlineSnapshot(of: scratch.dump(reports), as: .lines) {
      """
      [
        [0]: ScenarioReport(
          scenario: "<scratch>/stack.scn",
          failures: [],
          observations: [
            [0]: ScenarioObservation(
              line: 5,
              verb: "shot",
              name: "after-typing",
              lines: [
                [0]: "Stack demo",
                [1]: "────────────────────────────────────────",
                [2]: "Name: Rob",
                [3]: "left                               right",
                [4]: "────────────────────────────────────────",
                [5]: "40 columns"
              ]
            )
          ],
          recorded: [
            [0]: GoldenChange(
              path: "<scratch>/stack/after-typing.txt",
              change: .updated
            )
          ],
          seconds: []
        )
      ]
      """
    }
    assertInlineSnapshot(of: scratch.redacted(reports[0].description), as: .lines) {
      """
      PASS <scratch>/stack.scn
        recorded <scratch>/stack/after-typing.txt (updated)
      """
    }
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

    assertInlineSnapshot(of: scratch.dump(reports), as: .lines) {
      """
      [
        [0]: ScenarioReport(
          scenario: "<scratch>/stack.scn",
          failures: [
            [0]: ScenarioFailure(
              line: 5,
              statement: "shot after-typing",
              verb: "shot",
              message: "golden `<scratch>/stack/after-typing.txt` has CRLF line endings; goldens are LF files, so check them out with LF (`*.txt text eol=lf` in .gitattributes)",
              expected: nil,
              actual: nil,
              screen: nil
            )
          ],
          observations: [
            [0]: ScenarioObservation(
              line: 5,
              verb: "shot",
              name: "after-typing",
              lines: [
                [0]: "Stack demo",
                [1]: "────────────────────────────────────────",
                [2]: "Name: Rob",
                [3]: "left                               right",
                [4]: "────────────────────────────────────────",
                [5]: "40 columns"
              ]
            )
          ],
          recorded: [],
          seconds: []
        )
      ]
      """
    }
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

    assertInlineSnapshot(of: scratch.dump(reports), as: .lines) {
      """
      [
        [0]: ScenarioReport(
          scenario: "<scratch>/stack.scn",
          failures: [
            [0]: ScenarioFailure(
              line: 5,
              statement: "shot after-typing",
              verb: "shot",
              message: "golden `<scratch>/stack/after-typing.txt` has CRLF line endings; goldens are LF files, so check them out with LF (`*.txt text eol=lf` in .gitattributes)",
              expected: nil,
              actual: nil,
              screen: nil
            )
          ],
          observations: [
            [0]: ScenarioObservation(
              line: 5,
              verb: "shot",
              name: "after-typing",
              lines: [
                [0]: "Stack demo",
                [1]: "────────────────────────────────────────",
                [2]: "Name: Rob",
                [3]: "left                               right",
                [4]: "────────────────────────────────────────",
                [5]: "40 columns"
              ]
            )
          ],
          recorded: [],
          seconds: []
        )
      ]
      """
    }
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

    expectNoDifference(first, second)
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
    assertInlineSnapshot(of: reports.first?.failures, as: .customDump) {
      """
      [
        [0]: ScenarioFailure(
          line: 0,
          statement: "--repeat 3",
          verb: "repeat",
          message: "run 2 of 3 differs from run 1: it has 1 failures where run 1 has 0",
          expected: nil,
          actual: nil,
          screen: nil
        ),
        [1]: ScenarioFailure(
          line: 0,
          statement: "--repeat 3",
          verb: "repeat",
          message: "run 3 of 3 differs from run 1: it has 1 failures where run 1 has 0",
          expected: nil,
          actual: nil,
          screen: nil
        )
      ]
      """
    }
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
    assertInlineSnapshot(of: json, as: .lines) {
      #"""
      {"failures":[{"actual":"y","expected":"x","line":4,"message":"row 0 text differs","screen":["y"],"statement":"expect text 0 \"x\"","verb":"expect text"},{"line":6,"message":"m","statement":"key Tab","verb":"harness"}],"observations":[{"line":2,"lines":["y"],"name":"s","verb":"shot"}],"passed":false,"scenario":"a.scn"}
      """#
    }
  }

  @Test
  func `a passing report is passed true with empty arrays`() {
    let report = ScenarioReport(scenario: "ok.scn", failures: [])

    assertInlineSnapshot(of: report.json, as: .lines) {
      """
      {"failures":[],"observations":[],"passed":true,"scenario":"ok.scn"}
      """
    }
    assertInlineSnapshot(of: report.description, as: .lines) {
      """
      PASS ok.scn
      """
    }
  }

  @Test
  func `the human form shows the statement, expected, actual, and the screen`() {
    assertInlineSnapshot(of: failing.description, as: .lines) {
      """
      FAIL a.scn
        line 4: expect text 0 "x"
          row 0 text differs
          expected: x
          actual:   y
          screen:
            0| y
        line 6: key Tab
          m
      """
    }
  }

  @Test
  func `a parse failure prints as FILE LINE error and a usage failure as FILE error`() {
    let parse = ScenarioReport.parseFailure(
      ScenarioParseError(file: "p.scn", line: 3, source: "blink", message: "unknown"))
    let usage = ScenarioReport.failure(
      scenario: "dir", verb: "usage", message: "no such file")

    assertInlineSnapshot(of: parse.description, as: .lines) {
      """
      FAIL p.scn
      p.scn:3: error: unknown
      """
    }
    assertInlineSnapshot(of: usage.description, as: .lines) {
      """
      FAIL dir
      dir: error: no such file
      """
    }
    assertInlineSnapshot(of: parse.failures, as: .customDump) {
      """
      [
        [0]: ScenarioFailure(
          line: 3,
          statement: "blink",
          verb: "parse",
          message: "unknown",
          expected: nil,
          actual: nil,
          screen: nil
        )
      ]
      """
    }
  }
}
