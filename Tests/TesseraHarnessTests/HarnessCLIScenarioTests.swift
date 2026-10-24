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
          {"command":"run","exitCode":2,"scenarios":[{"failures":[{"line":2,"message":"unknown statement `blink`; accepted: app, size, term, resize, key, type, paste, bytes, shot, tree, expect text, expect screen, expect node","statement":"blink","verb":"parse"}],"observations":[],"passed":false,"scenario":"<scratch>/bad.scn"}]}
          
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
          {"command":"run","exitCode":2,"message":"Missing expected argument '<path> ...'; usage: tessera run [--json] [--pretty] [--record] [--repeat <n>] [--timing] <path> ..."}
          
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

    assertInlineSnapshot(of: [unknown, noValue, zero, word], as: .customDump) {
      #"""
      [
        [0]: CommandOutput(
          exitCode: 2,
          stdout: "",
          stderr: """
            error: Unknown option '--frobnicate'; usage: tessera run [--json] [--pretty] [--record] [--repeat <n>] [--timing] <path> ...
            
            """
        ),
        [1]: CommandOutput(
          exitCode: 2,
          stdout: "",
          stderr: """
            error: Missing value for '--repeat <n>'; usage: tessera run [--json] [--pretty] [--record] [--repeat <n>] [--timing] <path> ...
            
            """
        ),
        [2]: CommandOutput(
          exitCode: 2,
          stdout: "",
          stderr: """
            error: `--repeat` needs a whole number of at least 1, got `0`; usage: tessera run [--json] [--pretty] [--record] [--repeat <n>] [--timing] <path> ...
            
            """
        ),
        [3]: CommandOutput(
          exitCode: 2,
          stdout: "",
          stderr: """
            error: The value 'many' is invalid for '--repeat <n>'; usage: tessera run [--json] [--pretty] [--record] [--repeat <n>] [--timing] <path> ...
            
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
          error: The value 'x.scn' is invalid for '--repeat <n>'; usage: tessera run [--json] [--pretty] [--record] [--repeat <n>] [--timing] <path> ...
          
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
            error: bad size `huge`; expected WxH, desktop, mobile, or mobileScreen; usage: tessera tree [--json] [--pretty] <name> [<size>]
            
            """
        ),
        [2]: CommandOutput(
          exitCode: 2,
          stdout: "",
          stderr: """
            error: Missing expected argument '<name>'; usage: tessera shot [--json] [--pretty] <name> [<size>]
            
            """
        ),
        [3]: CommandOutput(
          exitCode: 2,
          stdout: "",
          stderr: """
            error: Unexpected argument 'more'; usage: tessera shot [--json] [--pretty] <name> [<size>]
            
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

  // MARK: help

  @Test
  func `help describes every command, and the overview names each one`() async {
    let overview = await run("help")

    for command in HarnessCLI.commandNames {
      #expect(overview.stdout.contains(command), "\(command)")
      let help = await run("help", command)
      #expect(help.stdout.contains("USAGE: tessera \(command)"), "\(command)")
      #expect(help.stdout.count > 60, "\(command)")
    }
    let runHelp = await run("help", "run")
    for flag in ["--record", "--repeat <n>", "--timing", "--json", "--pretty"] {
      #expect(runHelp.stdout.contains(flag), "\(flag)")
    }
    for field in [#""change": "created" or "updated""#, #""line" 0"#, #""--repeat N""#] {
      #expect(runHelp.stdout.contains(field), "\(field)")
    }
  }
}
