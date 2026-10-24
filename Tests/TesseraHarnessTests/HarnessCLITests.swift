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
    input: Bool = false,
    executable: String = "tessera"
  ) async -> CommandOutput {
    await HarnessCLI.run(
      arguments: arguments,
      registry: registry ?? Fixtures.registry(),
      inputIsTerminal: input,
      outputIsTerminal: terminal,
      configuration: .default,
      executableName: executable
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
          {"apps":[{"minimum":"20x1","name":"counter","viewports":["desktop"]},{"minimum":null,"name":"greedy","viewports":["desktop","mobileScreen"]},{"minimum":null,"name":"main-actor-counter","viewports":["desktop"]},{"minimum":null,"name":"observed-counter","viewports":["desktop"]},{"minimum":null,"name":"stack","viewports":["desktop","mobile"]},{"minimum":null,"name":"workspace","viewports":["desktop","mobileScreen"]}],"command":"apps"}
          
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
          error: unknown app `ghost`; accepted: counter, greedy, main-actor-counter, observed-counter, stack, workspace
          
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
          error: Missing expected argument '<name>'; usage: tessera launch [--json] [--pretty] <name>
          
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
          {"command":null,"exitCode":2,"message":"unknown command `jump`; accepted: apps, launch, help"}
          
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
          error: unknown command `jump`; accepted: apps, launch, help
          
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
          error: a command is required; accepted: apps, launch, help
          
          """
      )
      """#
    }
  }

  @Test
  func `help prints the overview and each command's help whatever stdout is`() async {
    let outputs = [
      await run("help"), await run("help", "apps"), await run("help", "launch"),
    ]

    assertInlineSnapshot(of: outputs, as: .customDump) {
      #"""
      [
        [0]: CommandOutput(
          exitCode: 0,
          stdout: """
            OVERVIEW: List and launch the registered applications.
            
            Every command exits 0 on success, 2 on a usage error, and 3 on a harness error.
            When standard output is not a terminal each command writes one JSON object to
            it; --json forces that form and --pretty forces the text form.
            
            `--generate-completion-script SHELL` prints a completion script for fish, zsh,
            or bash. It completes the commands, their flags, and the registered application
            names.
            
            USAGE: tessera [--json] [--pretty] <subcommand>
            
            OPTIONS:
              --json                  Print one JSON object, even on a terminal.
              --pretty                Print the text form, even when output is not a
                                      terminal.
              -h, --help              Show help information.
            
            SUBCOMMANDS:
              apps                    List the registered applications.
              launch                  Run one application in this terminal.
            
              See 'tessera help <subcommand>' for detailed help.
            
            """,
          stderr: ""
        ),
        [1]: CommandOutput(
          exitCode: 0,
          stdout: """
            OVERVIEW: List the registered applications.
            
            Lists every registered application with the smallest size it declares and the
            viewports it is checked at. The JSON form is {"apps": [{"minimum", "name",
            "viewports"}], "command": "apps"}, sorted by name, where "minimum" is null for
            an application that declares none. A name registered twice fails the command
            with exit 3.
            
            USAGE: tessera apps [--json] [--pretty]
            
            OPTIONS:
              --json                  Print one JSON object, even on a terminal.
              --pretty                Print the text form, even when output is not a
                                      terminal.
              -h, --help              Show help information.
            
            
            """,
          stderr: ""
        ),
        [2]: CommandOutput(
          exitCode: 0,
          stdout: """
            OVERVIEW: Run one application in this terminal.
            
            Runs the named application at the terminal's size, until the application
            finishes. The harness has no quit key of its own: the application decides which
            key quits.
            
            Exits 2 for an unknown name, and 3 for a duplicate registration or when
            standard input or output is not a terminal.
            
            USAGE: tessera launch [--json] [--pretty] <name>
            
            ARGUMENTS:
              <name>                  The application to run, as `apps` lists it.
            
            OPTIONS:
              --json                  Print one JSON object, even on a terminal.
              --pretty                Print the text form, even when output is not a
                                      terminal.
              -h, --help              Show help information.
            
            
            """,
          stderr: ""
        )
      ]
      """#
    }
  }

  @Test
  func `help COMMAND and COMMAND --help print the same text`() async {
    let spelled = await run("help", "launch")
    let flagged = await run("launch", "--help")
    let overview = await run("help")
    let flaggedOverview = await run("--help", terminal: true)

    expectNoDifference(spelled, flagged)
    expectNoDifference(overview, flaggedOverview)
  }

  @Test
  func `usage names the executable it runs as`() async {
    let output = await run("help", "launch", executable: "mytool")

    #expect(output.stdout.contains("USAGE: mytool launch"))
  }

  @Test
  func `help for an unknown command is a usage error that lists the commands`() async {
    let json = await run("help", "ghost")
    let text = await run("help", "ghost", "--pretty")

    assertInlineSnapshot(of: [json, text], as: .customDump) {
      #"""
      [
        [0]: CommandOutput(
          exitCode: 2,
          stdout: """
            {"command":"help","exitCode":2,"message":"unknown command `ghost`; accepted: apps, launch, help"}
            
            """,
          stderr: ""
        ),
        [1]: CommandOutput(
          exitCode: 2,
          stdout: "",
          stderr: """
            error: unknown command `ghost`; accepted: apps, launch, help
            
            """
        )
      ]
      """#
    }
  }

  @Test
  func `the parser's usage errors exit 2, not its own 64, and say what is accepted`()
    async
  {
    let outputs = [
      await run("apps", "extra", "--pretty"),
      await run("apps", "--nope", "--pretty"),
      await run("launch", "a", "b", "--pretty"),
      await run("--generate-completion-script", "powershell", "--pretty"),
      await run("--nope", "--pretty"),
    ]

    assertInlineSnapshot(of: outputs, as: .customDump) {
      #"""
      [
        [0]: CommandOutput(
          exitCode: 2,
          stdout: "",
          stderr: """
            error: Unexpected argument 'extra'; usage: tessera apps [--json] [--pretty]
            
            """
        ),
        [1]: CommandOutput(
          exitCode: 2,
          stdout: "",
          stderr: """
            error: Unknown option '--nope'; usage: tessera apps [--json] [--pretty]
            
            """
        ),
        [2]: CommandOutput(
          exitCode: 2,
          stdout: "",
          stderr: """
            error: Unexpected argument 'b'; usage: tessera launch [--json] [--pretty] <name>
            
            """
        ),
        [3]: CommandOutput(
          exitCode: 2,
          stdout: "",
          stderr: """
            error: Can't generate completion scripts for 'powershell'. Please use --generate-completion-script=<shell> with one of: zsh bash fish; usage: tessera [--json] [--pretty] <subcommand>
            
            """
        ),
        [4]: CommandOutput(
          exitCode: 2,
          stdout: "",
          stderr: """
            error: Unknown option '--nope'; usage: tessera [--json] [--pretty] <subcommand>
            
            """
        )
      ]
      """#
    }
  }

  @Test
  func `a usage error is a JSON failure when stdout is not a terminal`() async {
    let output = await run("launch")

    assertInlineSnapshot(of: output, as: .customDump) {
      #"""
      CommandOutput(
        exitCode: 2,
        stdout: """
          {"command":"launch","exitCode":2,"message":"Missing expected argument '<name>'; usage: tessera launch [--json] [--pretty] <name>"}
          
          """,
        stderr: ""
      )
      """#
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
          error: Value to be set with flag '--pretty' had already been set with flag '--json'; usage: tessera apps [--json] [--pretty]
          
          """
      )
      """#
    }
  }

  @Test
  func `the output flags are accepted before or after the command`() async {
    let before = await run("--json", "apps", terminal: true)
    let after = await run("apps", "--json", terminal: true)

    expectNoDifference(before, after)
    #expect(before.exitCode == 0)
  }

  @Test
  func `the app-name completion lists the registered names`() async {
    let output = await run("---completion", "launch", "--", "name", "0", "0", "launch")

    assertInlineSnapshot(of: output, as: .customDump) {
      #"""
      CommandOutput(
        exitCode: 0,
        stdout: """
          counter
          greedy
          main-actor-counter
          observed-counter
          stack
          workspace
          
          """,
        stderr: ""
      )
      """#
    }
  }

  @Test
  func `a registry with a duplicate name completes nothing`() async {
    let output = await run(
      "---completion", "launch", "--", "name", "0", "0", "launch", registry: duplicated())

    expectNoDifference(output, CommandOutput(exitCode: 0))
  }

  @Test(arguments: ["bash", "fish", "zsh"])
  func `the completion script for a shell calls the executable by its name`(
    shell: String
  ) async {
    let output = await run(
      "--generate-completion-script", shell, executable: "mytool")

    #expect(output.exitCode == 0)
    #expect(output.stderr.isEmpty)
    #expect(output.stdout.contains("mytool"))
    #expect(output.stdout.contains("---completion"))
  }
}
