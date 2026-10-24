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
  func `help prints real text for each command whatever stdout is`() async {
    let outputs = [
      await run("help"), await run("help", "apps"), await run("help", "launch"),
      await run("help", "help"), await run("help", "ghost"),
    ]

    assertInlineSnapshot(of: outputs, as: .customDump) {
      #"""
      [
        [0]: CommandOutput(
          exitCode: 0,
          stdout: """
            usage: <executable> COMMAND [ARGUMENT]
            
            commands:
              apps           list the registered applications
              launch NAME    run one application in this terminal
              help [COMMAND] describe a command
            
            Every command exits 0 on success, 2 on a usage error, and 3 on a harness error. When
            standard output is not a terminal each command writes one JSON object to it; --json
            forces that form and --pretty forces the text form.
            
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
            usage: help [COMMAND]
            
            Prints the commands, or one command's usage.
            
            """,
          stderr: ""
        ),
        [4]: CommandOutput(
          exitCode: 2,
          stdout: """
            {"command":"help","exitCode":2,"message":"unknown command `ghost`; accepted: apps, launch, help"}
            
            """,
          stderr: ""
        )
      ]
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
          error: `--json` and `--pretty` contradict each other
          
          """
      )
      """#
    }
  }
}
