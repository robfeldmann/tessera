import CustomDump
import Foundation
import InlineSnapshotTesting
import SnapshotTesting
import SnapshotTestingCustomDump
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

    assertInlineSnapshot(of: scratch.dump(output), as: .lines) {
      #"""
      CommandOutput(
        exitCode: 0,
        stdout: """
          {"command":"run","exitCode":0,"scenarios":[{"failures":[],"observations":[],"passed":true,"scenario":"<scratch>/a.scn"},{"failures":[],"observations":[],"passed":true,"scenario":"<scratch>/b.scn"}]}
          
          """,
        stderr: ""
      )
      """#
    }
  }

  @Test
  func `run prints the human form and a summary on a terminal`() async throws {
    let scratch = try ScratchDirectory()
    try scratch.write("a.scn", passing)
    try scratch.write("b.scn", failing)

    let output = await run("run", scratch.path, terminal: true)

    assertInlineSnapshot(of: scratch.dump(output), as: .lines) {
      #"""
      CommandOutput(
        exitCode: 1,
        stdout: """
          PASS <scratch>/a.scn
          FAIL <scratch>/b.scn
            line 3: expect text 0 "Stack demos"
              row 0 text differs
              expected: Stack demos
              actual:   Stack demo
              screen:
                0| Stack demo
                1| ────────────────────────────────────────
                2| Name: -
                3| left                               right
                4| ────────────────────────────────────────
                5| 40 columns
          2 scenarios, 1 passed, 1 failed
          
          """,
        stderr: ""
      )
      """#
    }
  }

  @Test
  func `a summary of one scenario is singular`() async throws {
    let scratch = try ScratchDirectory()
    try scratch.write("a.scn", passing)

    let output = await run("run", scratch.path, "--pretty")

    assertInlineSnapshot(of: scratch.dump(output), as: .lines) {
      #"""
      CommandOutput(
        exitCode: 0,
        stdout: """
          PASS <scratch>/a.scn
          1 scenario, 1 passed, 0 failed
          
          """,
        stderr: ""
      )
      """#
    }
  }

  @Test
  func `a failed expectation exits 1 and the JSON says which line and statement`()
    async throws
  {
    let scratch = try ScratchDirectory()
    try scratch.write("b.scn", failing)

    let output = await run("run", scratch.path)

    assertInlineSnapshot(of: scratch.dump(output), as: .lines) {
      #"""
      CommandOutput(
        exitCode: 1,
        stdout: """
          {"command":"run","exitCode":1,"scenarios":[{"failures":[{"actual":"Stack demo","expected":"Stack demos","line":3,"message":"row 0 text differs","screen":["Stack demo","────────────────────────────────────────","Name: -","left                               right","────────────────────────────────────────","40 columns"],"statement":"expect text 0 \"Stack demos\"","verb":"expect text"}],"observations":[],"passed":false,"scenario":"<scratch>/b.scn"}]}
          
          """,
        stderr: ""
      )
      """#
    }
  }

  @Test
  func `a parse error exits 2 and is a failure with verb parse`() async throws {
    let scratch = try ScratchDirectory()
    try scratch.write("bad.scn", "app stack\nblink\n")

    let output = await run("run", scratch.path)

    assertInlineSnapshot(of: scratch.dump(output), as: .lines) {
      #"""
      CommandOutput(
        exitCode: 2,
        stdout: """
          {"command":"run","exitCode":2,"scenarios":[{"failures":[{"line":2,"message":"unknown statement `blink`; accepted: app, size, term, resize, key, type, paste, bytes, shot, tree, dump, check, expect text, expect screen, expect node, expect cost","statement":"blink","verb":"parse"}],"observations":[],"passed":false,"scenario":"<scratch>/bad.scn"}]}
          
          """,
        stderr: ""
      )
      """#
    }
  }

  @Test
  func `a path that is not a scenario exits 2`() async throws {
    let scratch = try ScratchDirectory()

    let output = await run("run", scratch.appending("missing.scn"))

    assertInlineSnapshot(of: scratch.dump(output), as: .lines) {
      #"""
      CommandOutput(
        exitCode: 2,
        stdout: """
          {"command":"run","exitCode":2,"scenarios":[{"failures":[{"line":0,"message":"no such file or directory","statement":"","verb":"usage"}],"observations":[],"passed":false,"scenario":"<scratch>/missing.scn"}]}
          
          """,
        stderr: ""
      )
      """#
    }
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

    assertInlineSnapshot(of: scratch.dump(output), as: .lines) {
      #"""
      CommandOutput(
        exitCode: 3,
        stdout: """
          {"command":"run","exitCode":3,"scenarios":[{"failures":[{"line":0,"message":"applications registered more than once: `stack`","statement":"","verb":"harness"}],"observations":[],"passed":false,"scenario":"<scratch>/a.scn"}]}
          
          """,
        stderr: ""
      )
      """#
    }
  }

  @Test
  func `run without a path is a usage error with the failure object`() async throws {
    let output = await run("run")

    assertInlineSnapshot(of: output, as: .customDump) {
      #"""
      CommandOutput(
        exitCode: 2,
        stdout: """
          {"command":"run","exitCode":2,"message":"usage: run PATH... [--record] [--repeat N] [--timing]"}
          
          """,
        stderr: ""
      )
      """#
    }
  }

  @Test
  func `run validates its flags`() async {
    let unknown = await run("run", "x.scn", "--frobnicate", "--pretty")
    let noValue = await run("run", "x.scn", "--repeat", "--pretty")
    let zero = await run("run", "x.scn", "--repeat", "0", "--pretty")
    let word = await run("run", "x.scn", "--repeat", "many", "--pretty")
    let twice = await run("run", "x.scn", "--repeat", "2", "--repeat", "3", "--pretty")

    assertInlineSnapshot(of: [unknown, noValue, zero, word, twice], as: .customDump) {
      #"""
      [
        [0]: CommandOutput(
          exitCode: 2,
          stdout: "",
          stderr: """
            error: unknown flag `--frobnicate`; accepted: --json, --pretty, --record, --repeat, --timing, --trace
            
            """
        ),
        [1]: CommandOutput(
          exitCode: 2,
          stdout: "",
          stderr: """
            error: `--repeat` needs a value
            
            """
        ),
        [2]: CommandOutput(
          exitCode: 2,
          stdout: "",
          stderr: """
            error: `--repeat` needs a whole number of at least 1, got `0`
            
            """
        ),
        [3]: CommandOutput(
          exitCode: 2,
          stdout: "",
          stderr: """
            error: `--repeat` needs a whole number of at least 1, got `many`
            
            """
        ),
        [4]: CommandOutput(
          exitCode: 2,
          stdout: "",
          stderr: """
            error: `--repeat` is given twice
            
            """
        )
      ]
      """#
    }
  }

  @Test
  func `a path taken as the repeat count reports the repeat value, not a missing path`()
    async
  {
    let output = await run("run", "--repeat", "x.scn", "--pretty")

    assertInlineSnapshot(of: output, as: .customDump) {
      #"""
      CommandOutput(
        exitCode: 2,
        stdout: "",
        stderr: """
          error: `--repeat` needs a whole number of at least 1, got `x.scn`
          
          """
      )
      """#
    }
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

    assertInlineSnapshot(of: output, as: .customDump) {
      #"""
      CommandOutput(
        exitCode: 0,
        stdout: """
          Stack demo
          ────────────────────────────────────────
          Name: -
          left                               right
          ────────────────────────────────────────
          40 columns
          
          """,
        stderr: ""
      )
      """#
    }
  }

  @Test
  func `shot prints one JSON object with the rows and the size`() async throws {
    let output = await run("shot", "stack", "mobile")

    assertInlineSnapshot(of: output, as: .customDump) {
      #"""
      CommandOutput(
        exitCode: 0,
        stdout: """
          {"app":"stack","command":"shot","exitCode":0,"rows":["Stack demo","────────────────────────────────────────","Name: -","left                               right","────────────────────────────────────────","40 columns"],"size":"40x6"}
          
          """,
        stderr: ""
      )
      """#
    }
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

    assertInlineSnapshot(of: text, as: .customDump) {
      #"""
      CommandOutput(
        exitCode: 0,
        stdout: """
          root TupleView frame=0,0,40x8
            root/index(0) VStack frame=0,0,40x8
              root/index(0)/index(0) Text frame=0,0,10x1
              root/index(0)/index(1) Divider frame=0,1,40x1
              root/index(0)/index(2) HStack frame=0,2,7x1
                root/index(0)/index(2)/index(0) Text frame=0,2,5x1
                root/index(0)/index(2)/index(1) Text frame=6,2,1x1
              root/index(0)/index(3) HStack frame=0,3,40x1
                root/index(0)/index(3)/index(0) Text frame=0,3,4x1
                root/index(0)/index(3)/index(1) Spacer frame=4,3,31x0 clip=4,3,0x0
                root/index(0)/index(3)/index(2) Text frame=35,3,5x1
              root/index(0)/index(4) Divider frame=0,4,40x1
              root/index(0)/index(5) Text frame=0,5,10x1
          
          """,
        stderr: ""
      )
      """#
    }
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

    assertInlineSnapshot(
      of: [unknown, badSize, none, extra, greedy, duplicate], as: .customDump
    ) {
      #"""
      [
        [0]: CommandOutput(
          exitCode: 2,
          stdout: "",
          stderr: """
            error: unknown app `ghost`; accepted: counter, event-log, greedy, main-actor-counter, observed-counter, stack, workspace
            
            """
        ),
        [1]: CommandOutput(
          exitCode: 2,
          stdout: "",
          stderr: """
            error: bad size `huge`; expected WxH, desktop, mobile, or mobileScreen
            
            """
        ),
        [2]: CommandOutput(
          exitCode: 2,
          stdout: "",
          stderr: """
            error: usage: shot NAME [SIZE]
            
            """
        ),
        [3]: CommandOutput(
          exitCode: 2,
          stdout: "",
          stderr: """
            error: usage: shot NAME [SIZE]
            
            """
        ),
        [4]: CommandOutput(
          exitCode: 2,
          stdout: """
            {"command":"shot","exitCode":2,"message":"`greedy` has no natural height: it measured 500 rows when offered 500 and 1000 when offered 1000. Use `size mobileScreen` (40x16) or an explicit WxH"}
            
            """,
          stderr: ""
        ),
        [5]: CommandOutput(
          exitCode: 3,
          stdout: "",
          stderr: """
            error: applications registered more than once: `stack`
            
            """
        )
      ]
      """#
    }
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

    assertInlineSnapshot(of: output, as: .customDump) {
      #"""
      CommandOutput(
        exitCode: 0,
        stdout: """
          {"app":"layers","command":"check","exitCode":0,"rules":["no-dirty-after-pass","frame-inside-clip","measured-within-proposal","siblings-disjoint","requirements-aggregate"],"size":"40x6","violations":[]}
          
          """,
        stderr: ""
      )
      """#
    }
  }

  @Test
  func `check exits 1 when a rule that is an error is violated and lists it`()
    async throws
  {
    let output = await projectionRun("check", "overlap")

    assertInlineSnapshot(of: output, as: .customDump) {
      #"""
      CommandOutput(
        exitCode: 1,
        stdout: """
          {"app":"overlap","command":"check","exitCode":1,"rules":["no-dirty-after-pass","frame-inside-clip","measured-within-proposal","siblings-disjoint","requirements-aggregate"],"size":"80x24","violations":[{"detail":"shows 0,0,6x1, which overlaps sibling root/index(0)/index(0) showing 0,0,5x1 under Overlap","node":"root/index(0)/index(1)","rule":"siblings-disjoint","severity":"error"}]}
          
          """,
        stderr: ""
      )
      """#
    }
  }

  @Test
  func `check lists a warning with its errors and a text form that says PASS or FAIL`()
    async
  {
    let json = await projectionRun("check", "overflow")
    let text = await projectionRun("check", "overflow", "--pretty")
    let passing = await projectionRun("check", "layers", "--pretty")

    assertInlineSnapshot(of: [json, text, passing], as: .customDump) {
      #"""
      [
        [0]: CommandOutput(
          exitCode: 1,
          stdout: """
            {"app":"overflow","command":"check","exitCode":1,"rules":["no-dirty-after-pass","frame-inside-clip","measured-within-proposal","siblings-disjoint","requirements-aggregate"],"size":"80x24","violations":[{"detail":"frame 0,0,12x1 is clipped to 0,0,4x1 (visible text `wide`)","node":"root/index(0)/index(0)/index(0)","rule":"frame-inside-clip","severity":"warning"},{"detail":"measured 12 columns where 4 were offered","node":"root/index(0)/index(0)/index(0)","rule":"measured-within-proposal","severity":"error"}]}
            
            """,
          stderr: ""
        ),
        [1]: CommandOutput(
          exitCode: 1,
          stdout: """
            check overflow at 80x24 against 5 rules: no-dirty-after-pass, frame-inside-clip, measured-within-proposal, siblings-disjoint, requirements-aggregate
              warning frame-inside-clip root/index(0)/index(0)/index(0): frame 0,0,12x1 is clipped to 0,0,4x1 (visible text `wide`)
              error measured-within-proposal root/index(0)/index(0)/index(0): measured 12 columns where 4 were offered
            FAIL overflow: 1 error, 1 warning
            
            """,
          stderr: ""
        ),
        [2]: CommandOutput(
          exitCode: 0,
          stdout: """
            check layers at 80x24 against 5 rules: no-dirty-after-pass, frame-inside-clip, measured-within-proposal, siblings-disjoint, requirements-aggregate
            PASS layers
            
            """,
          stderr: ""
        )
      ]
      """#
    }
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

    assertInlineSnapshot(
      of: [noApp, badSize, unknown, duplicate, greedy], as: .customDump
    ) {
      #"""
      [
        [0]: CommandOutput(
          exitCode: 2,
          stdout: "",
          stderr: """
            error: usage: check NAME [SIZE]
            
            """
        ),
        [1]: CommandOutput(
          exitCode: 2,
          stdout: "",
          stderr: """
            error: bad size `huge`; expected WxH, desktop, mobile, or mobileScreen
            
            """
        ),
        [2]: CommandOutput(
          exitCode: 2,
          stdout: "",
          stderr: """
            error: unknown app `ghost`; accepted: counter, event-log, greedy, main-actor-counter, observed-counter, stack, workspace
            
            """
        ),
        [3]: CommandOutput(
          exitCode: 3,
          stdout: "",
          stderr: """
            error: applications registered more than once: `stack`
            
            """
        ),
        [4]: CommandOutput(
          exitCode: 2,
          stdout: "",
          stderr: """
            error: `greedy` has no natural height: it measured 500 rows when offered 500 and 1000 when offered 1000. Use `size mobileScreen` (40x16) or an explicit WxH
            
            """
        )
      ]
      """#
    }
  }

  @Test
  func `run --pretty shows a bare check's warnings under the scenario's line`()
    async throws
  {
    let scratch = try ScratchDirectory()
    try scratch.write("w.scn", "app overflow\ncheck\n")

    let output = await projectionRun("run", scratch.path, "--pretty")

    assertInlineSnapshot(of: scratch.dump(output), as: .lines) {
      #"""
      CommandOutput(
        exitCode: 1,
        stdout: """
          FAIL <scratch>/w.scn
            line 2: warning frame-inside-clip root/index(0)/index(0)/index(0): frame 0,0,12x1 is clipped to 0,0,4x1 (visible text `wide`)
            line 2: check
              measured-within-proposal at root/index(0)/index(0)/index(0): measured 12 columns where 4 were offered
              screen:
                0| wide
                1| ok
          1 scenario, 0 passed, 1 failed
          
          """,
        stderr: ""
      )
      """#
    }
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

    assertInlineSnapshot(of: report.description, as: .lines) {
      """
      PASS flex.scn
        line 7: warning frame-inside-clip root/a: shows 0,0,9x1
      """
    }
    assertInlineSnapshot(of: report.json, as: .lines) {
      """
      {"failures":[],"observations":[{"line":7,"lines":["ran no-dirty-after-pass, frame-inside-clip","warning frame-inside-clip root/a: shows 0,0,9x1"],"verb":"check"},{"line":9,"lines":["ran no-dirty-after-pass"],"verb":"check"},{"line":3,"lines":["warning: not a check"],"name":"a","verb":"shot"}],"passed":true,"scenario":"flex.scn"}
      """
    }
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

    assertInlineSnapshot(
      of: scratch.dump([trace, path, inside, shot, tree, check, file, app, json]),
      as: .lines
    ) {
      #"""
      [
        [0]: CommandOutput(
          exitCode: 2,
          stdout: "",
          stderr: """
            error: `--trace` needs a value that is not empty
            
            """
        ),
        [1]: CommandOutput(
          exitCode: 2,
          stdout: "",
          stderr: """
            error: an empty argument is not a path or an application name
            
            """
        ),
        [2]: CommandOutput(
          exitCode: 2,
          stdout: "",
          stderr: """
            error: an empty argument is not a path or an application name
            
            """
        ),
        [3]: CommandOutput(
          exitCode: 2,
          stdout: "",
          stderr: """
            error: an empty argument is not a path or an application name
            
            """
        ),
        [4]: CommandOutput(
          exitCode: 2,
          stdout: "",
          stderr: """
            error: an empty argument is not a path or an application name
            
            """
        ),
        [5]: CommandOutput(
          exitCode: 2,
          stdout: "",
          stderr: """
            error: an empty argument is not a path or an application name
            
            """
        ),
        [6]: CommandOutput(
          exitCode: 2,
          stdout: "",
          stderr: """
            error: an empty argument is not a path or an application name
            
            """
        ),
        [7]: CommandOutput(
          exitCode: 2,
          stdout: "",
          stderr: """
            error: `--app` needs a value that is not empty
            
            """
        ),
        [8]: CommandOutput(
          exitCode: 2,
          stdout: """
            {"command":"run","exitCode":2,"message":"`--trace` needs a value that is not empty"}
            
            """,
          stderr: ""
        )
      ]
      """#
    }
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

    assertInlineSnapshot(of: scratch.dump(output), as: .lines) {
      #"""
      CommandOutput(
        exitCode: 0,
        stdout: """
          PASS <scratch>/a.scn
          PASS <scratch>/nested/b.scn
          2 scenarios, 2 passed, 0 failed
          
          """,
        stderr: ""
      )
      """#
    }
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
      expectNoDifference(records.map(\.seq), [0, 1, 2, 3, 4, 5])
      expectNoDifference(
        records[4].event, TraceEvent(.resize(TerminalSize(columns: 30, rows: 8))))
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

    assertInlineSnapshot(of: scratch.dump(output), as: .lines) {
      #"""
      CommandOutput(
        exitCode: 0,
        stdout: """
          {"command":"replay","exitCode":0,"scenarios":[{"failures":[],"observations":[{"line":0,"lines":["Stack demo","──────────────────────────────","Name: Ro","left                     right","──────────────────────────────","30 columns"],"verb":"replay"}],"passed":true,"scenario":"<scratch>/traces<scratch>/a.trace.jsonl"}]}
          
          """,
        stderr: ""
      )
      """#
    }
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

    assertInlineSnapshot(of: scratch.dump(output), as: .lines) {
      #"""
      CommandOutput(
        exitCode: 1,
        stdout: """
          FAIL <scratch>/traces<scratch>/a.trace.jsonl
            line 1: step 0: resize 40x10
              the changed nodes differ from the recording
              expected: {"added":["root","root/index(0)","root/index(0)/index(0)","root/index(0)/index(1)","root/index(0)/index(2)","root/index(0)/index(2)/index(0)","root/index(0)/index(2)/index(1)","root/index(0)/index(3)","root/index(0)/index(3)/index(0)","root/index(0)/index(3)/index(1)","root/index(0)/index(3)/index(2)","root/index(0)/index(4)","root/index(0)/index(5)"],"changed":[],"removed":[]}
              actual:   {"added":["root","root/index(0)","root/index(0)/index(0)","root/index(0)/index(1)","root/index(0)/index(2)"],"changed":[],"removed":[]}
              screen:
                0| Greedy
                1| 
                2| 
                3| 
                4| 
                5| 
                6| 
                7| 
                8| 
                9| footer
            line 2: step 1: key R
              the changed rows differ from the recording
              expected: [2]
              actual:   []
              screen:
                0| Greedy
                1| 
                2| 
                3| 
                4| 
                5| 
                6| 
                7| 
                8| 
                9| footer
            line 3: step 2: key o
              the changed nodes differ from the recording
              expected: {"added":[],"changed":["root/index(0)/index(2)","root/index(0)/index(2)/index(1)"],"removed":[]}
              actual:   {"added":[],"changed":[],"removed":[]}
              screen:
                0| Greedy
                1| 
                2| 
                3| 
                4| 
                5| 
                6| 
                7| 
                8| 
                9| footer
            line 4: step 3: key b
              the changed nodes differ from the recording
              expected: {"added":[],"changed":["root/index(0)/index(2)","root/index(0)/index(2)/index(1)"],"removed":[]}
              actual:   {"added":[],"changed":[],"removed":[]}
              screen:
                0| Greedy
                1| 
                2| 
                3| 
                4| 
                5| 
                6| 
                7| 
                8| 
                9| footer
            line 5: step 4: resize 30x8
              the changed nodes differ from the recording
              expected: {"added":[],"changed":["root","root/index(0)","root/index(0)/index(0)","root/index(0)/index(1)","root/index(0)/index(2)","root/index(0)/index(3)","root/index(0)/index(3)/index(1)","root/index(0)/index(3)/index(2)","root/index(0)/index(4)","root/index(0)/index(5)"],"removed":[]}
              actual:   {"added":[],"changed":["root","root/index(0)","root/index(0)/index(0)","root/index(0)/index(1)","root/index(0)/index(2)"],"removed":[]}
              screen:
                0| Greedy
                1| 
                2| 
                3| 
                4| 
                5| 
                6| 
                7| footer
            line 6: step 5: key Backspace
              the changed nodes differ from the recording
              expected: {"added":[],"changed":["root/index(0)/index(2)","root/index(0)/index(2)/index(1)"],"removed":[]}
              actual:   {"added":[],"changed":[],"removed":[]}
              screen:
                0| Greedy
                1| 
                2| 
                3| 
                4| 
                5| 
                6| 
                7| footer
          
          """,
        stderr: ""
      )
      """#
    }
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

    assertInlineSnapshot(
      of: scratch.dump([noFile, noName, missing, notUTF8, notRecords, unknown]),
      as: .lines
    ) {
      #"""
      [
        [0]: CommandOutput(
          exitCode: 2,
          stdout: "",
          stderr: """
            error: usage: replay FILE --app NAME
            
            """
        ),
        [1]: CommandOutput(
          exitCode: 2,
          stdout: "",
          stderr: """
            error: usage: replay FILE --app NAME
            
            """
        ),
        [2]: CommandOutput(
          exitCode: 2,
          stdout: "",
          stderr: """
            error: cannot read the trace `<scratch>/none.jsonl`
            
            """
        ),
        [3]: CommandOutput(
          exitCode: 2,
          stdout: "",
          stderr: """
            error: the trace `<scratch>/bin.jsonl` is not UTF-8 text
            
            """
        ),
        [4]: CommandOutput(
          exitCode: 2,
          stdout: """
            FAIL <scratch>/nope.jsonl
            <scratch>/nope.jsonl:1: error: this line is not a trace record (not valid JSON)
            
            """,
          stderr: ""
        ),
        [5]: CommandOutput(
          exitCode: 2,
          stdout: "",
          stderr: """
            error: unknown app `ghost`; accepted: counter, event-log, greedy, main-actor-counter, observed-counter, stack, workspace
            
            """
        )
      ]
      """#
    }
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

    assertInlineSnapshot(of: scratch.dump(output), as: .lines) {
      #"""
      CommandOutput(
        exitCode: 3,
        stdout: "",
        stderr: """
          error: cannot create the trace file `<scratch>`: the file could not be created
          
          """
      )
      """#
    }
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
