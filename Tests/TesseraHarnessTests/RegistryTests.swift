import CustomDump
import InlineSnapshotTesting
import SnapshotTesting
import SnapshotTestingCustomDump
import TesseraTerminalCore
import Testing

@testable import TesseraHarness

@MainActor
struct ApplicationRegistryTests {
  private func duplicated() -> ApplicationRegistry {
    var registry = Fixtures.registry()
    registry.register("counter", viewports: [.mobile]) { CounterApp() }
    registry.register("stack", viewports: [.mobile]) { StackApp() }
    return registry
  }

  @Test
  func `lookup returns the registration's name, minimum, and viewports`() throws {
    let entry = try Fixtures.registry().entry(named: "counter")

    assertInlineSnapshot(of: entry, as: .customDump) {
      """
      ApplicationRegistry.Entry(
        name: "counter",
        minimum: TerminalSize(
          columns: 20,
          rows: 1
        ),
        viewports: [
          [0]: .desktop
        ],
        headless: (Function),
        live: (Function)
      )
      """
    }
  }

  @Test
  func `entries and names come back sorted by name`() throws {
    let names = try Fixtures.registry().names()

    assertInlineSnapshot(of: names, as: .customDump) {
      """
      [
        [0]: "counter",
        [1]: "greedy",
        [2]: "main-actor-counter",
        [3]: "observed-counter",
        [4]: "stack",
        [5]: "workspace"
      ]
      """
    }
  }

  @Test
  func `a name that is not registered fails and lists the registered names`() {
    let error = #expect(throws: RegistryError.self) {
      try Fixtures.registry().entry(named: "ghost")
    }

    assertInlineSnapshot(of: error, as: .customDump) {
      """
      RegistryError.unknown(
        "ghost",
        accepted: [
          [0]: "counter",
          [1]: "greedy",
          [2]: "main-actor-counter",
          [3]: "observed-counter",
          [4]: "stack",
          [5]: "workspace"
        ]
      )
      """
    }
    assertInlineSnapshot(of: error?.description, as: .lines) {
      """
      unknown app `ghost`; accepted: counter, greedy, main-actor-counter, observed-counter, stack, workspace
      """
    }
  }

  @Test
  func `registering a name twice does not fail at the registration site`() {
    let registry = duplicated()

    #expect(registry.entries.count == Fixtures.registry().entries.count + 2)
  }

  @Test
  func `a duplicate name fails every read of the registry, never last-wins`() {
    let registry = duplicated()
    let expected = RegistryError.duplicate(["counter", "stack"])

    #expect(throws: expected) { try registry.checkedEntries() }
    #expect(throws: expected) { try registry.names() }
    #expect(throws: expected) { try registry.entry(named: "counter") }
    #expect(throws: expected) { try registry.entry(named: "workspace") }
    #expect(
      expected.description == "applications registered more than once: `counter`, `stack`"
    )
  }

  @Test
  func `a duplicate name fails the scenario runner with the app verb`() async throws {
    let scenario = Scenario(app: "workspace", viewport: .desktop, lines: [])

    let report = await ScenarioRunner.run(scenario, name: "t.scn", registry: duplicated())

    assertInlineSnapshot(of: report, as: .customDump) {
      """
      ScenarioReport(
        scenario: "t.scn",
        passed: false,
        failures: [
          [0]: ScenarioFailure(
            line: 0,
            statement: "app workspace",
            verb: "app",
            message: "applications registered more than once: `counter`, `stack`",
            expected: nil,
            actual: nil,
            screen: nil
          )
        ],
        observations: []
      )
      """
    }
  }

  @Test
  func `a registry with no applications lists nothing and finds nothing`() throws {
    let registry = ApplicationRegistry()

    #expect(try registry.names().isEmpty)
    #expect(throws: RegistryError.self) { try registry.entry(named: "any") }
  }
}

struct ViewportTests {
  @Test
  func `fixed viewports name their sizes and mobile has to be measured`() {
    let viewports: [Viewport] = [
      .desktop, .mobileScreen, .custom(TerminalSize(columns: 30, rows: 9)), .mobile,
    ]

    expectNoDifference(
      viewports.map(\.fixedSize),
      [
        TerminalSize(columns: 80, rows: 24),
        TerminalSize(columns: 40, rows: 16),
        TerminalSize(columns: 30, rows: 9),
        nil,
      ]
    )
  }

  @Test
  func `viewports are hashable and spell themselves the way a scenario header does`() {
    let viewports: Set<Viewport> = [
      .desktop, .mobile, .mobileScreen, .custom(TerminalSize(columns: 30, rows: 9)),
    ]

    expectNoDifference(
      viewports.map(\.name).sorted(), ["30x9", "desktop", "mobile", "mobileScreen"])
  }
}
