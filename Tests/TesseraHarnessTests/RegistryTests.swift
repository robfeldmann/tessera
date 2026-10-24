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

    #expect(entry.name == "counter")
    #expect(entry.minimum == TerminalSize(columns: 20, rows: 1))
    #expect(entry.viewports == [.desktop])
  }

  @Test
  func `entries and names come back sorted by name`() throws {
    let names = try Fixtures.registry().names()

    #expect(names == names.sorted())
    #expect(names.contains("main-actor-counter"))
  }

  @Test
  func `a name that is not registered fails and lists the registered names`() {
    let error = #expect(throws: RegistryError.self) {
      try Fixtures.registry().entry(named: "ghost")
    }

    guard case .unknown(let name, let accepted)? = error else {
      Issue.record("expected an unknown-name error, got \(String(describing: error))")
      return
    }
    #expect(name == "ghost")
    #expect(accepted.contains("counter"))
    #expect(error?.description.hasPrefix("unknown app `ghost`; accepted: ") == true)
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
  func `a duplicate name fails the scenario player with the harness verb`() async throws {
    let scenario = Scenario(app: "workspace")

    let report = await ScenarioPlayer.run(scenario, name: "t.scn", registry: duplicated())

    #expect(report.passed == false)
    #expect(report.failures.first?.verb == "harness")
    #expect(report.failures.first?.message.contains("registered more than once") == true)
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
    #expect(Viewport.desktop.fixedSize == TerminalSize(columns: 80, rows: 24))
    #expect(Viewport.mobileScreen.fixedSize == TerminalSize(columns: 40, rows: 16))
    #expect(
      Viewport.custom(TerminalSize(columns: 30, rows: 9)).fixedSize
        == TerminalSize(columns: 30, rows: 9))
    #expect(Viewport.mobile.fixedSize == nil)
  }

  @Test
  func `viewports are hashable and spell themselves the way a scenario header does`() {
    let viewports: Set<Viewport> = [
      .desktop, .mobile, .mobileScreen, .custom(TerminalSize(columns: 30, rows: 9)),
    ]

    #expect(viewports.count == 4)
    #expect(
      viewports.map(\.name).sorted() == ["30x9", "desktop", "mobile", "mobileScreen"])
  }
}
