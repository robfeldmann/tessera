import Foundation
import TesseraTerminalInput
import Testing

@testable import TesseraHarness

struct ScenarioParserTests {
  @Test
  func `header statements bind before the first body statement`() throws {
    let scenario = try ScenarioParser.parse(
      """
      # comment
      app stack
      size mobile
      type "hi there"  # trailing comment
      """,
      file: "t.scn"
    )

    #expect(scenario.app == "stack")
    #expect(scenario.viewport == .mobile)
    #expect(scenario.lines.map(\.statement) == [.type("hi there")])
    #expect(scenario.lines.first?.number == 4)
  }

  @Test
  func `size after a body statement names the resize verb`() {
    let error = #expect(throws: ScenarioParseError.self) {
      try ScenarioParser.parse("key Tab\nsize 10x10", file: "t.scn")
    }

    #expect(error?.line == 2)
    #expect(error?.description.hasPrefix("t.scn:2: error: ") == true)
    #expect(error?.message.contains("resize") == true)
  }

  @Test
  func `unknown statements list the accepted vocabulary`() {
    let error = #expect(throws: ScenarioParseError.self) {
      try ScenarioParser.parse("jump 3", file: "t.scn")
    }

    #expect(error?.message.contains("accepted: app, size, resize, key") == true)
  }

  @Test
  func `reserved verbs are reported as not yet expressible`() {
    let error = #expect(throws: ScenarioParseError.self) {
      try ScenarioParser.parse("mouse click 3,4", file: "t.scn")
    }

    #expect(error?.message.contains("not yet expressible") == true)
  }

  @Test
  func `unknown key names list the accepted set`() {
    let error = #expect(throws: ScenarioParseError.self) {
      try ScenarioParser.parse("key Hyperspace", file: "t.scn")
    }

    #expect(error?.message.contains("ArrowLeft") == true)
  }

  @Test
  func `chords and function keys parse into key events`() throws {
    let scenario = try ScenarioParser.parse(
      "key Shift+Tab\nkey Ctrl+C\nkey F5\nkey Ctrl++",
      file: "t.scn"
    )
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
    let scenario = try ScenarioParser.parse(
      "expect node id=root frame 1,2,3x4\nexpect node id=root frame 1,2 3x4",
      file: "t.scn"
    )

    #expect(scenario.lines[0].statement == scenario.lines[1].statement)
  }

  @Test
  func `unterminated quotes fail with the line number`() {
    let error = #expect(throws: ScenarioParseError.self) {
      try ScenarioParser.parse("\ntype \"oops", file: "t.scn")
    }

    #expect(error?.line == 2)
  }

  @Test
  func `duplicate shot names are rejected`() {
    #expect(throws: ScenarioParseError.self) {
      try ScenarioParser.parse("shot a\nshot a", file: "t.scn")
    }
  }
}

struct ScenarioRunnerTests {
  @Test
  func `a wrong row expectation reports expected actual and the screen`() throws {
    let scenario = try ScenarioParser.parse(
      "app stack\nsize 40x10\nexpect text 0 \"Stack demos\"",
      file: "t.scn"
    )

    let report = ScenarioRunner.run(scenario, name: "t.scn")

    #expect(report.passed == false)
    let failure = try #require(report.failures.first)
    #expect(failure.expected == "Stack demos")
    #expect(failure.actual == "Stack demo")
    #expect(failure.screen?.first == "Stack demo")
  }

  @Test
  func `the run continues after a failed expectation`() throws {
    let scenario = try ScenarioParser.parse(
      """
      app stack
      size 40x10
      expect text 0 "wrong"
      type "x"
      expect text 2 "Name: x"
      expect text 5 "wrong again"
      """,
      file: "t.scn"
    )

    let report = ScenarioRunner.run(scenario, name: "t.scn")

    #expect(report.failures.map(\.line) == [3, 6])
  }

  @Test
  func `a locator that matches nothing is a failure that names the node types`() throws {
    let scenario = try ScenarioParser.parse(
      "app stack\nsize 40x10\nexpect node type=Missing frame 0,0,1x1",
      file: "t.scn"
    )

    let report = ScenarioRunner.run(scenario, name: "t.scn")

    #expect(report.failures.first?.actual?.contains("VStack") == true)
  }

  @Test
  func `an ambiguous locator asks for nth`() throws {
    let scenario = try ScenarioParser.parse(
      "app stack\nsize 40x10\nexpect node type=Text frame 0,0,1x1",
      file: "t.scn"
    )

    let report = ScenarioRunner.run(scenario, name: "t.scn")

    #expect(report.failures.first?.message.contains("add nth=") == true)
  }

  @Test
  func `type feeds one key event per character into demo state`() throws {
    let scenario = try ScenarioParser.parse(
      "app stack\nsize 40x10\ntype \"Rob\"\nkey Backspace\nexpect text 2 \"Name: Ro\"",
      file: "t.scn"
    )

    #expect(ScenarioRunner.run(scenario, name: "t.scn").passed)
  }

  @Test
  func `mobile fails for a demo that fills its proposal`() throws {
    let scenario = try ScenarioParser.parse(
      "app workspace\nsize mobile\nshot a",
      file: "t.scn"
    )

    let report = ScenarioRunner.run(scenario, name: "t.scn")

    #expect(report.failures.first?.verb == "size")
  }

  @Test
  func `mobile natural height is the root's measured rows under a tall proposal`() {
    let stack = DemoRegistry.naturalHeight(app: "stack", width: 40)
    let workspace = DemoRegistry.naturalHeight(app: "workspace", width: 40)

    #expect(stack?.rows == 6)
    #expect(stack?.fillsProposal == false)
    #expect(workspace?.fillsProposal == true)
  }
}

struct ScenarioCorpusTests {
  private static let scenarios = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .appendingPathComponent("Scenarios")

  private func report(for relativePath: String) throws -> ScenarioReport {
    let url = Self.scenarios.appendingPathComponent(relativePath)
    let source = try String(contentsOf: url, encoding: .utf8)
    let scenario = try ScenarioParser.parse(source, file: relativePath)
    return ScenarioRunner.run(scenario, name: relativePath)
  }

  @Test(arguments: [
    "workspace-desktop.scn", "workspace-input.scn", "workspace-compact.scn",
    "stack-mobile.scn",
  ])
  func `corpus scenarios pass and render identical bytes twice`(file: String) throws {
    let first = try report(for: file)
    let second = try report(for: file)

    #expect(first.passed)
    #expect(first.json() == second.json())
  }

  @Test
  func `the failing scenario fails four expectations`() throws {
    let report = try report(for: "failing/mismatch.scn")

    #expect(report.failures.map(\.line) == [6, 7, 8, 10])
  }
}
