import CustomDump
import Foundation
import InlineSnapshotTesting
import SnapshotTesting
import SnapshotTestingCustomDump
import TesseraTerminal
import TesseraTerminalCore
import Testing

@testable import TesseraHarness

@MainActor
struct HarnessCLITests {
  /// Runs a command. `terminal` says standard output is a terminal and `input` says standard
  /// input is; neither defaults to `true`, so no test opens a live session by accident.
  private func run(
    _ arguments: String...,
    registry: ApplicationRegistry? = nil,
    terminal: Bool = false,
    input: Bool = false
  ) async -> CommandOutput {
    await HarnessCLI.run(
      arguments: arguments,
      registry: registry ?? Fixtures.registry(),
      inputIsTerminal: input,
      outputIsTerminal: terminal,
      configuration: .default
    )
  }

  private func duplicated() -> ApplicationRegistry {
    var registry = Fixtures.registry()
    registry.register("counter", viewports: [.mobile]) { CounterApp() }
    return registry
  }

  @Test
  func `apps prints one JSON object when stdout is not a terminal`() async {
    let output = await run("apps")

    assertInlineSnapshot(of: output, as: .customDump) {
      #"""
      CommandOutput(
        exitCode: 0,
        stdout: """
          {"apps":[{"minimum":"20x1","name":"counter","viewports":["desktop"]},{"minimum":null,"name":"event-log","viewports":["desktop","mobileScreen"]},{"minimum":null,"name":"greedy","viewports":["desktop","mobileScreen"]},{"minimum":null,"name":"main-actor-counter","viewports":["desktop"]},{"minimum":null,"name":"observed-counter","viewports":["desktop"]},{"minimum":null,"name":"stack","viewports":["desktop","mobile"]},{"minimum":null,"name":"workspace","viewports":["desktop","mobileScreen"]}],"command":"apps"}
          
          """,
        stderr: ""
      )
      """#
    }
  }

  @Test
  func `an app with no declared minimum lists it as null so every entry has three keys`()
    async throws
  {
    let output = await run("apps")

    let object = try #require(
      JSONSerialization.jsonObject(with: Data(output.stdout.utf8)) as? [String: Any])
    let apps = try #require(object["apps"] as? [[String: Any]])
    let stack = try #require(apps.first { $0["name"] as? String == "stack" })
    expectNoDifference(
      Set(apps.map { $0.keys.sorted() }), [["minimum", "name", "viewports"]])
    #expect(stack["minimum"] is NSNull)
  }

  @Test
  func `apps prints a table on a terminal and --json forces the object`() async {
    let table = await run("apps", terminal: true)
    let forced = await run("apps", "--json", terminal: true)
    let piped = await run("apps")

    assertInlineSnapshot(of: table, as: .customDump) {
      #"""
      CommandOutput(
        exitCode: 0,
        stdout: """
          NAME                MINIMUM  VIEWPORTS
          counter             20x1     desktop
          event-log           -        desktop, mobileScreen
          greedy              -        desktop, mobileScreen
          main-actor-counter  -        desktop
          observed-counter    -        desktop
          stack               -        desktop, mobile
          workspace           -        desktop, mobileScreen
          
          """,
        stderr: ""
      )
      """#
    }
    expectNoDifference(forced, piped)
  }

  @Test
  func `--pretty forces the table when stdout is not a terminal`() async {
    let output = await run("apps", "--pretty")
    let table = await run("apps", terminal: true)

    expectNoDifference(output, table)
  }

  @Test
  func `apps output is identical across runs`() async {
    let first = await run("apps")
    let second = await run("apps")

    #expect(first == second)
  }

  @Test
  func `an empty registry lists nothing`() async {
    let output = await run("apps", "--pretty", registry: ApplicationRegistry())

    assertInlineSnapshot(of: output, as: .customDump) {
      #"""
      CommandOutput(
        exitCode: 0,
        stdout: """
          no applications are registered
          
          """,
        stderr: ""
      )
      """#
    }
  }

  @Test
  func `a duplicate name fails apps and launch with exit 3`() async {
    let registry = duplicated()

    let apps = await run("apps", "--pretty", registry: registry)
    let launch = await run(
      "launch", "stack", "--pretty", registry: registry, terminal: true)

    assertInlineSnapshot(of: [apps, launch], as: .customDump) {
      #"""
      [
        [0]: CommandOutput(
          exitCode: 3,
          stdout: "",
          stderr: """
            error: applications registered more than once: `counter`
            
            """
        ),
        [1]: CommandOutput(
          exitCode: 3,
          stdout: "",
          stderr: """
            error: applications registered more than once: `counter`
            
            """
        )
      ]
      """#
    }
  }

  @Test
  func `launch with an unknown name is a usage error that lists the accepted names`()
    async
  {
    let output = await run("launch", "ghost", "--pretty", terminal: true)

    assertInlineSnapshot(of: output, as: .customDump) {
      #"""
      CommandOutput(
        exitCode: 2,
        stdout: "",
        stderr: """
          error: unknown app `ghost`; accepted: counter, event-log, greedy, main-actor-counter, observed-counter, stack, workspace
          
          """
      )
      """#
    }
  }

  @Test
  func `launch without a name is a usage error`() async {
    let output = await run("launch", "--pretty", terminal: true)

    assertInlineSnapshot(of: output, as: .customDump) {
      #"""
      CommandOutput(
        exitCode: 2,
        stdout: "",
        stderr: """
          error: usage: launch NAME
          
          """
      )
      """#
    }
  }

  @Test
  func `launch refuses to start unless stdout is a terminal`() async {
    let output = await run("launch", "counter", input: true)

    assertInlineSnapshot(of: output, as: .customDump) {
      #"""
      CommandOutput(
        exitCode: 3,
        stdout: """
          {"command":"launch","exitCode":3,"message":"`launch` runs an application in this terminal, and standard output is not one"}
          
          """,
        stderr: ""
      )
      """#
    }
  }

  @Test
  func
    `launch refuses to start unless stdin is a terminal and says so before any session`()
    async
  {
    let output = await run("launch", "counter", "--pretty", terminal: true, input: false)

    assertInlineSnapshot(of: output, as: .customDump) {
      #"""
      CommandOutput(
        exitCode: 3,
        stdout: "",
        stderr: """
          error: `launch` runs an application in this terminal, and standard input is not one
          
          """
      )
      """#
    }
  }

  @Test
  func `launch names both streams when neither is a terminal`() async {
    let output = await run("launch", "counter", "--pretty")

    assertInlineSnapshot(of: output, as: .customDump) {
      #"""
      CommandOutput(
        exitCode: 3,
        stdout: "",
        stderr: """
          error: `launch` runs an application in this terminal, and standard input and output are not terminals
          
          """
      )
      """#
    }
  }

  @Test
  func `an unknown command has a null command in its JSON failure`() async {
    let output = await run("jump")

    assertInlineSnapshot(of: output, as: .customDump) {
      #"""
      CommandOutput(
        exitCode: 2,
        stdout: """
          {"command":null,"exitCode":2,"message":"unknown command `jump`; accepted: apps, launch, run, shot, tree, help"}
          
          """,
        stderr: ""
      )
      """#
    }
  }

  @Test
  func `an unknown command lists the accepted commands`() async {
    let output = await run("jump", "--pretty")

    assertInlineSnapshot(of: output, as: .customDump) {
      #"""
      CommandOutput(
        exitCode: 2,
        stdout: "",
        stderr: """
          error: unknown command `jump`; accepted: apps, launch, run, shot, tree, help
          
          """
      )
      """#
    }
  }

  @Test
  func `no command is a usage error`() async {
    let output = await run("--pretty")

    assertInlineSnapshot(of: output, as: .customDump) {
      #"""
      CommandOutput(
        exitCode: 2,
        stdout: "",
        stderr: """
          error: a command is required; accepted: apps, launch, run, shot, tree, help
          
          """
      )
      """#
    }
  }

  @Test
  func `help prints real text for each command whatever stdout is`() async {
    var outputs = [await run("help")]
    for command in HarnessCLI.commands + ["ghost"] {
      outputs.append(await run("help", command))
    }

    assertInlineSnapshot(of: outputs, as: .customDump) {
      #"""
      [
        [0]: CommandOutput(
          exitCode: 0,
          stdout: """
            usage: <executable> COMMAND [ARGUMENT...]
            
            commands:
              apps              list the registered applications
              launch NAME       run one application in this terminal
              run PATH...       run scenario files, or directories of them
              shot NAME [SIZE]  print one application's screen as text
              tree NAME [SIZE]  print one application's node tree
              help [COMMAND]    describe a command
            
            Every command exits 0 on success, 1 when an expectation failed, 2 on a usage or parse
            error, and 3 on a harness error. When standard output is not a terminal each command
            writes one JSON object to it; --json forces that form and --pretty forces the text form.
            
            """,
          stderr: ""
        ),
        [1]: CommandOutput(
          exitCode: 0,
          stdout: """
            usage: apps [--json | --pretty]
            
            Lists every registered application with the smallest size it declares and the
            viewports it is checked at. The JSON form is {"apps": [{"minimum", "name",
            "viewports"}], "command": "apps"}, sorted by name, where "minimum" is null for an
            application that declares none. A name registered twice fails the command with exit 3.
            
            """,
          stderr: ""
        ),
        [2]: CommandOutput(
          exitCode: 0,
          stdout: """
            usage: launch NAME
            
            Runs the named application in this terminal at the terminal's size, until the
            application finishes. The harness has no quit key of its own: the application decides
            which key quits. Exits 2 for an unknown name, and 3 for a duplicate registration or
            when standard input or output is not a terminal.
            
            """,
          stderr: ""
        ),
        [3]: CommandOutput(
          exitCode: 0,
          stdout: """
            usage: run PATH... [--record] [--repeat N] [--timing] [--json | --pretty]
            
            Runs scenario files. A PATH is a .scn file, or a directory whose .scn files, at any
            depth, run in sorted order. A path that is neither, or a directory with no scenarios, is
            a usage error. Each scenario starts a fresh application.
            
            A scenario is a text file with one statement per line. The header statements are
            `app NAME`, `size SIZE`, and `term colors=... theme=...`. The input statements are
            `resize WxH`, `key NAME`, `type "text"`, `paste "text"`, and `bytes "..."`. `shot NAME`
            compares the screen with a golden file and `tree` adds the node tree to the report. The
            assertions are `expect text [ROW] "text"`, `expect screen <<WORD`, and
            `expect node SEL frame X,Y,WxH`. A statement outside this list is a parse error.
            
              --record     write the golden files that `shot` statements compare against, instead
                           of failing when one differs or is missing, and list what changed. Review
                           the files it wrote; never record to make a failing run pass.
              --repeat N   run each scenario N times, and fail a run whose report differs from the
                           first.
              --timing     add the wall-clock seconds of each run to the report. Times differ from
                           run to run, so they are never golden.
            
            Exit codes: 0 every scenario passed, 1 an expectation failed, 2 a scenario did not parse
            or a path is not a scenario, 3 a harness error. When several apply, the highest wins.
            
            The JSON form is {"command": "run", "exitCode", "scenarios": [REPORT...]} with one
            REPORT per scenario: {"failures": [FAILURE...], "observations": [{"line", "verb",
            "lines"} and, for a shot, "name"], "passed", "recorded" (only when --record wrote
            goldens: [{"change": "created" or "updated", "path"}]), "scenario", "seconds" (only with
            --timing)}. A FAILURE is {"line", "statement", "verb", "message"} and, when the
            statement compares values, "expected", "actual", and "screen". A failure that belongs to
            a file or a command, not a line, has "line" 0 and "statement" "" (a repeat failure's
            statement is "--repeat N"). A shot whose golden is missing, is not UTF-8, or has CRLF
            line endings has no "expected", "actual", or "screen": its observation holds the screen.
            A scenario that does not parse is a failure with verb "parse". Fields are added, never
            removed or renamed.
            
            """,
          stderr: ""
        ),
        [4]: CommandOutput(
          exitCode: 0,
          stdout: """
            usage: shot NAME [SIZE] [--json | --pretty]
            
            Prints the screen of the registered application NAME, as text, the way a golden file
            holds it. SIZE is desktop, mobile, mobileScreen, or WxH, and defaults to desktop. The
            JSON form is {"app", "command": "shot", "exitCode", "rows", "size"}, where "size" is the
            terminal size the application was shown at. An unknown NAME is a usage error that lists
            the registered names, and so is a size the application cannot take, such as `mobile` for
            an application whose content fills any height: the error says which size to use.
            
            """,
          stderr: ""
        ),
        [5]: CommandOutput(
          exitCode: 0,
          stdout: """
            usage: tree NAME [SIZE] [--json | --pretty]
            
            Prints the node tree of the registered application NAME, one line per node with its
            identity, type, frame, and clip. SIZE is desktop, mobile, mobileScreen, or WxH, and
            defaults to desktop. The JSON form is {"app", "command": "tree", "exitCode", "lines",
            "size"}. The tree's text is for reading and is not promised to stay as it is. Errors are
            those of `shot`.
            
            """,
          stderr: ""
        ),
        [6]: CommandOutput(
          exitCode: 0,
          stdout: """
            usage: help [COMMAND]
            
            Prints the commands, or one command's usage.
            
            """,
          stderr: ""
        ),
        [7]: CommandOutput(
          exitCode: 2,
          stdout: """
            {"command":"help","exitCode":2,"message":"unknown command `ghost`; accepted: apps, launch, run, shot, tree, help"}
            
            """,
          stderr: ""
        )
      ]
      """#
    }
  }

  @Test
  func `help and its errors name no repository path and promise no later work`() async {
    var texts = [await run("help").stdout]
    for command in HarnessCLI.commands {
      texts.append(await run("help", command).stdout)
    }
    texts.append(await run("help", "ghost").stdout)
    texts.append(await run("jump").stderr)

    let banned = ["Examples/", "docs/", ".agents", "spikes/", "README", "yet", "later"]
    for text in texts {
      #expect(!banned.contains { text.contains($0) }, "\(text)")
    }
  }

  @Test
  func `--json and --pretty together are a usage error`() async {
    let output = await run("apps", "--json", "--pretty")

    assertInlineSnapshot(of: output, as: .customDump) {
      #"""
      CommandOutput(
        exitCode: 2,
        stdout: "",
        stderr: """
          error: `--json` and `--pretty` contradict each other
          
          """
      )
      """#
    }
  }
}
