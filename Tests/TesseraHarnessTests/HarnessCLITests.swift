import Foundation
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
  func `apps prints one JSON object when stdout is not a terminal`() async throws {
    let output = await run("apps")

    #expect(output.exitCode == 0)
    #expect(output.stderr.isEmpty)
    #expect(output.stdout.hasSuffix("}\n"))
    let object = try #require(
      JSONSerialization.jsonObject(with: Data(output.stdout.utf8)) as? [String: Any])
    #expect(object["command"] as? String == "apps")
    let apps = try #require(object["apps"] as? [[String: Any]])
    let counter = try #require(apps.first { $0["name"] as? String == "counter" })
    #expect(counter["minimum"] as? String == "20x1")
    #expect(counter["viewports"] as? [String] == ["desktop"])
    #expect(Set(counter.keys) == ["minimum", "name", "viewports"])
    #expect(
      apps.compactMap { $0["name"] as? String }
        == apps.compactMap { $0["name"] as? String }.sorted())
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
    #expect(Set(stack.keys) == ["minimum", "name", "viewports"])
    #expect(stack["minimum"] is NSNull)
    #expect(output.stdout.contains(#"{"minimum":null,"name":"greedy""#))
  }

  @Test
  func `apps prints a table on a terminal and --json forces the object`() async {
    let table = await run("apps", terminal: true)
    let forced = await run("apps", "--json", terminal: true)

    #expect(table.stdout.hasPrefix("NAME"))
    #expect(table.stdout.contains("counter"))
    #expect(table.stdout.contains("20x1"))
    #expect(table.stdout.contains("desktop, mobileScreen"))
    #expect(forced.stdout.hasPrefix("{"))
  }

  @Test
  func `--pretty forces the table when stdout is not a terminal`() async {
    let output = await run("apps", "--pretty")

    #expect(output.stdout.hasPrefix("NAME"))
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

    #expect(output.exitCode == 0)
    #expect(output.stdout == "no applications are registered\n")
  }

  @Test
  func `a duplicate name fails apps and launch with exit 3`() async {
    let registry = duplicated()

    let apps = await run("apps", "--pretty", registry: registry)
    let launch = await run(
      "launch", "stack", "--pretty", registry: registry, terminal: true)

    #expect(apps.exitCode == 3)
    #expect(apps.stderr.contains("registered more than once: `counter`"))
    #expect(launch.exitCode == 3)
    #expect(launch.stderr.contains("registered more than once: `counter`"))
  }

  @Test
  func `launch with an unknown name is a usage error that lists the accepted names`()
    async
  {
    let output = await run("launch", "ghost", "--pretty", terminal: true)

    #expect(output.exitCode == 2)
    #expect(output.stderr.contains("unknown app `ghost`; accepted: "))
    #expect(output.stderr.contains("counter"))
  }

  @Test
  func `launch without a name is a usage error`() async {
    let output = await run("launch", "--pretty", terminal: true)

    #expect(output.exitCode == 2)
    #expect(output.stderr.contains("usage: launch NAME"))
  }

  @Test
  func `launch refuses to start unless stdout is a terminal`() async throws {
    let output = await run("launch", "counter", input: true)

    #expect(output.exitCode == 3)
    let object = try #require(
      JSONSerialization.jsonObject(with: Data(output.stdout.utf8)) as? [String: Any])
    #expect(object["command"] as? String == "launch")
    #expect(object["exitCode"] as? Int == 3)
    #expect(
      (object["message"] as? String)?.hasSuffix("standard output is not one") == true)
  }

  @Test
  func
    `launch refuses to start unless stdin is a terminal and says so before any session`()
    async
  {
    let output = await run("launch", "counter", "--pretty", terminal: true, input: false)

    #expect(output.exitCode == 3)
    #expect(output.stdout.isEmpty)
    #expect(
      output.stderr
        == "error: `launch` runs an application in this terminal, and standard input is not one\n"
    )
  }

  @Test
  func `launch names both streams when neither is a terminal`() async {
    let output = await run("launch", "counter", "--pretty")

    #expect(output.exitCode == 3)
    #expect(output.stderr.contains("standard input and output are not terminals"))
  }

  @Test
  func `an unknown command has a null command in its JSON failure`() async throws {
    let output = await run("jump")

    let object = try #require(
      JSONSerialization.jsonObject(with: Data(output.stdout.utf8)) as? [String: Any])
    #expect(object["command"] is NSNull)
    #expect(object["exitCode"] as? Int == 2)
  }

  @Test
  func `an unknown command lists the accepted commands`() async {
    let output = await run("jump", "--pretty")

    #expect(output.exitCode == 2)
    #expect(
      output.stderr == "error: unknown command `jump`; accepted: apps, launch, help\n")
  }

  @Test
  func `no command is a usage error`() async {
    let output = await run("--pretty")

    #expect(output.exitCode == 2)
    #expect(output.stderr.contains("a command is required"))
  }

  @Test
  func `help prints real text for each command whatever stdout is`() async {
    for command in ["apps", "launch", "help"] {
      let output = await run("help", command)

      #expect(output.exitCode == 0)
      #expect(output.stdout.hasPrefix("usage: \(command)"))
    }
    let overview = await run("help")
    #expect(overview.stdout.contains("launch NAME"))
    #expect(await run("help", "ghost").exitCode == 2)
  }

  @Test
  func `--json and --pretty together are a usage error`() async {
    let output = await run("apps", "--json", "--pretty")

    #expect(output.exitCode == 2)
  }
}
