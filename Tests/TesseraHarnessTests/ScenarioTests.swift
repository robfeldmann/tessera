import Foundation
import TesseraCore
import TesseraTerminalInput
import Testing

@testable import TesseraHarness

private func parse(_ source: String, file: String = "t.scn") throws -> Scenario {
  try ScenarioParser.parse(source, file: file, knownApps: Fixtures.names)
}

struct ScenarioParserTests {
  @Test
  func `header statements bind before the first body statement`() throws {
    let scenario = try parse(
      """
      # comment
      app stack
      size mobile
      type "hi there"  # trailing comment
      """
    )

    #expect(scenario.app == "stack")
    #expect(scenario.viewport == .mobile)
    #expect(scenario.lines.map(\.statement) == [.type("hi there")])
    #expect(scenario.lines.first?.number == 4)
  }

  @Test
  func `a scenario without an app header is a parse error naming the accepted apps`() {
    let error = #expect(throws: ScenarioParseError.self) {
      try parse("size desktop\nkey Tab")
    }

    #expect(error?.message.contains("`app NAME` header") == true)
    #expect(error?.message.contains("accepted: stack, workspace, greedy") == true)
  }

  @Test
  func `an app the registry does not hold is a parse error`() {
    let error = #expect(throws: ScenarioParseError.self) {
      try parse("app missing")
    }

    #expect(error?.message.contains("unknown app `missing`") == true)
  }

  @Test
  func `size after a body statement names the resize verb`() {
    let error = #expect(throws: ScenarioParseError.self) {
      try parse("key Tab\nsize 10x10")
    }

    #expect(error?.line == 2)
    #expect(error?.description.hasPrefix("t.scn:2: error: ") == true)
    #expect(error?.message.contains("resize") == true)
  }

  @Test
  func `unknown statements list the accepted vocabulary`() {
    let error = #expect(throws: ScenarioParseError.self) {
      try parse("jump 3")
    }

    #expect(error?.message.contains("accepted: app, size, resize, key") == true)
  }

  @Test
  func `reserved verbs are reported as not yet expressible`() {
    let error = #expect(throws: ScenarioParseError.self) {
      try parse("mouse click 3,4")
    }

    #expect(error?.message.contains("not yet expressible") == true)
  }

  @Test
  func `unknown key names list the accepted set`() {
    let error = #expect(throws: ScenarioParseError.self) {
      try parse("key Hyperspace")
    }

    #expect(error?.message.contains("ArrowLeft") == true)
  }

  @Test
  func `chords and function keys parse into key events`() throws {
    let scenario = try parse("app stack\nkey Shift+Tab\nkey Ctrl+C\nkey F5\nkey Ctrl++")
    let keys = scenario.lines.compactMap { line -> Key? in
      if case .key(let key) = line.statement { key } else { nil }
    }

    #expect(keys[0] == Key(code: .tab, modifiers: .shift))
    #expect(keys[1] == Key(code: .character("c"), modifiers: .control))
    #expect(keys[2] == Key(code: .function(5)))
    #expect(keys[3] == Key(code: .character("+"), modifiers: .control))
  }

  @Test
  func `frame expectations accept one token or the plan's two-token form`() throws {
    let scenario = try parse(
      "app stack\nexpect node id=root frame 1,2,3x4\nexpect node id=root frame 1,2 3x4"
    )

    #expect(scenario.lines[0].statement == scenario.lines[1].statement)
  }

  @Test
  func `unterminated quotes fail with the line number`() {
    let error = #expect(throws: ScenarioParseError.self) {
      try parse("\ntype \"oops")
    }

    #expect(error?.line == 2)
  }

  @Test
  func `duplicate shot names are rejected`() {
    #expect(throws: ScenarioParseError.self) {
      try parse("shot a\nshot a")
    }
  }
}

@MainActor
struct ScenarioRunnerTests {
  private func run(_ source: String) async throws -> ScenarioReport {
    let scenario = try parse(source)
    return await ScenarioRunner.run(
      scenario, name: "t.scn", registry: Fixtures.registry())
  }

  @Test
  func `a wrong row expectation reports expected actual and the screen`() async throws {
    let report = try await run("app stack\nsize 40x10\nexpect text 0 \"Stack demos\"")

    #expect(report.passed == false)
    let failure = try #require(report.failures.first)
    #expect(failure.expected == "Stack demos")
    #expect(failure.actual == "Stack demo")
    #expect(failure.screen?.first == "Stack demo")
  }

  @Test
  func `the run continues after a failed expectation`() async throws {
    let report = try await run(
      """
      app stack
      size 40x10
      expect text 0 "wrong"
      type "x"
      expect text 2 "Name: x"
      expect text 5 "wrong again"
      """
    )

    #expect(report.failures.map(\.line) == [3, 6])
  }

  @Test
  func `a locator that matches nothing is a failure that names the node types`()
    async throws
  {
    let report = try await run(
      "app stack\nsize 40x10\nexpect node type=Missing frame 0,0,1x1")

    #expect(report.failures.first?.actual?.contains("VStack") == true)
  }

  @Test
  func `an ambiguous locator asks for nth`() async throws {
    let report = try await run(
      "app stack\nsize 40x10\nexpect node type=Text frame 0,0,1x1")

    #expect(report.failures.first?.message.contains("add nth=") == true)
  }

  @Test
  func `type feeds one key event per character into app state`() async throws {
    let report = try await run(
      "app stack\nsize 40x10\ntype \"Rob\"\nkey Backspace\nexpect text 2 \"Name: Ro\"")

    #expect(report.passed)
  }

  @Test
  func `mobile is 40 columns at the natural height of an app with one`() async throws {
    let report = try await run(
      "app stack\nsize mobile\nexpect node id=root frame 0,0,40x6")

    #expect(report.passed)
  }

  @Test
  func `mobile fails for an app that fills its proposal and names mobileScreen`()
    async throws
  {
    let report = try await run("app greedy\nsize mobile\nshot a")

    let failure = try #require(report.failures.first)
    #expect(failure.verb == "size")
    #expect(failure.message.contains("mobileScreen"))
    #expect(failure.message.contains("`greedy` has no natural height"))
  }

  @Test
  func `mobile fails for the workspace, whose viewport and split fill any height`()
    async throws
  {
    let report = try await run("app workspace\nsize mobile\nshot a")

    #expect(report.failures.first?.verb == "size")
  }

  @Test
  func `mobileScreen runs a greedy app at 40x16`() async throws {
    let report = try await run(
      "app greedy\nsize mobileScreen\nexpect node id=root frame 0,0,40x16")

    #expect(report.passed)
  }

  @Test
  func `an app the registry lacks fails the run with the app verb`() async throws {
    let scenario = Scenario(app: "ghost", viewport: .desktop, lines: [])

    let report = await ScenarioRunner.run(
      scenario, name: "t.scn", registry: Fixtures.registry())

    #expect(report.failures.first?.verb == "app")
    #expect(report.failures.first?.message.contains("accepted: ") == true)
  }

  @Test
  func `natural height is the root's measured rows when no height is proposed`() {
    let stack = NaturalHeight.measure(StackApp(), columns: 40)
    let workspace = NaturalHeight.measure(WorkspaceApp(), columns: 40)
    let greedy = NaturalHeight.measure(GreedyApp(), columns: 40)

    #expect(stack.rows == 6)
    #expect(stack.fillsProposal == false)
    #expect(workspace.fillsProposal)
    #expect(greedy.fillsProposal)
  }
}

@MainActor
struct ScenarioCorpusTests {
  private static let scenarios = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .appendingPathComponent("Scenarios")

  private func report(for relativePath: String) async throws -> ScenarioReport {
    let url = Self.scenarios.appendingPathComponent(relativePath)
    let source = try String(contentsOf: url, encoding: .utf8)
    let scenario = try parse(source, file: relativePath)
    return await ScenarioRunner.run(
      scenario, name: relativePath, registry: Fixtures.registry())
  }

  @Test(arguments: [
    "workspace-desktop.scn", "workspace-input.scn", "workspace-compact.scn",
    "stack-mobile.scn",
  ])
  func `corpus scenarios pass and render identical bytes twice`(file: String) async throws
  {
    let first = try await report(for: file)
    let second = try await report(for: file)

    #expect(first.passed)
    #expect(first.json() == second.json())
  }

  @Test
  func `the failing scenario fails four expectations`() async throws {
    let report = try await report(for: "failing/mismatch.scn")

    #expect(report.failures.map(\.line) == [6, 7, 8, 10])
  }
}
