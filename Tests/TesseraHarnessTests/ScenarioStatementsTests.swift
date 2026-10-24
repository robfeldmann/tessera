import Foundation
import Testing

@testable import TesseraHarness

private func parse(_ source: String) throws -> Scenario {
  try ScenarioParser.parse(
    source, file: "t.scn",
    knownApps: ProjectionFixtures.names + Fixtures.names)
}

extension ProjectionFixtures {
  static let names = [
    "overlap", "overflow", "layers", "styled", "wide", "steady", "growing",
  ]
}

// MARK: Parsing

struct NewStatementParserTests {
  private func statement(_ line: String) throws -> Statement {
    try #require(try parse("app layers\n" + line).lines.first?.statement)
  }

  private func message(_ line: String) -> String? {
    let error = #expect(throws: ScenarioParseError.self) {
      try parse("app layers\n" + line)
    }
    return error?.message
  }

  @Test
  func `check with no word runs every rule and with words runs those`() throws {
    #expect(try statement("check") == .check(rules: []))
    #expect(
      try statement("check siblings-disjoint no-dirty-after-pass")
        == .check(rules: [.siblingsDisjoint, .noDirtyAfterPass]))
  }

  @Test
  func `an unknown or repeated check rule is a parse error that names the rules`() {
    #expect(
      message("check no-such-rule")
        == "unknown check rule `no-such-rule`; accepted: \(CheckRule.accepted)")
    #expect(
      message("check siblings-disjoint siblings-disjoint")
        == "check rule `siblings-disjoint` is named twice")
  }

  @Test
  func `dump takes no argument`() throws {
    #expect(try statement("dump") == .dump)
    #expect(message("dump everything")?.hasPrefix("usage: dump") == true)
  }

  @Test
  func `expect cost takes a bound for each counter it names`() throws {
    #expect(
      try statement("expect cost bodies<=5 bytes<=40")
        == .expectCost([
          CostBound(counter: "bodies", limit: 5), CostBound(counter: "bytes", limit: 40),
        ]))
    #expect(
      try statement("expect cost renders<=0")
        == .expectCost([CostBound(counter: "renders", limit: 0)]))
  }

  @Test
  func
    `expect cost refuses everything but a counter, then less than or equal, then a number`()
    throws
  {
    #expect(message("expect cost")?.hasPrefix("usage: expect cost NAME<=N") == true)
    #expect(message("expect cost bodies<5")?.contains("only `<=` is accepted") == true)
    #expect(
      message("expect cost bodies <= 5")?.contains("written without spaces") == true)
    #expect(
      message("expect cost frames<=5")
        == "unknown cost counter `frames`; accepted: bodies, bytes, measures, placements, renders"
    )
    #expect(
      message("expect cost bodies<=many")
        == "cost bound `bodies<=many` needs a non-negative whole number after `<=`")
    #expect(
      message("expect cost bodies<=-1")
        == "cost bound `bodies<=-1` needs a non-negative whole number after `<=`")
    #expect(
      message("expect cost bodies<=1 bodies<=2")
        == "cost counter `bodies` is bounded twice")
  }

  @Test
  func `the unknown statement error lists the new statements`() {
    #expect(
      message("blink")?.hasSuffix(
        "accepted: app, size, term, resize, key, type, paste, bytes, shot, tree, dump, check, "
          + "expect text, expect screen, expect node, expect cost") == true)
  }

  @Test
  func `a locator takes a layout, and the accepted keys name it`() throws {
    #expect(
      try statement("expect node layout=_FrameLayout nth=1 frame 0,0,2x1")
        == .expectNode(
          Locator(layout: "_FrameLayout", nth: 1),
          FrameExpectation(column: 0, row: 0, columns: 2, rows: 1)))
    #expect(
      message("expect node colour=red frame 0,0,1x1")
        == "unknown locator key `colour`; accepted: type, layout, id, text, nth")
  }
}

// MARK: Playing

@MainActor
struct NewStatementPlayerTests {
  private let registry = ProjectionFixtures.registry()

  private func play(_ source: String) async throws -> ScenarioReport {
    let scenario = try parse(source)
    return await ScenarioPlayer.run(scenario, name: "t.scn", registry: registry)
  }

  // MARK: check

  @Test
  func `check passes on a clean app and records the rules it ran`() async throws {
    let report = try await play("app layers\ncheck")

    #expect(report.passed, "\(report)")
    let observation = try #require(report.observations.first)
    #expect(observation.verb == "check")
    #expect(
      observation.lines == [
        "ran no-dirty-after-pass, frame-inside-clip, measured-within-proposal, "
          + "siblings-disjoint, requirements-aggregate"
      ])
  }

  @Test
  func `a violated rule fails the statement with its rule and node`() async throws {
    let report = try await play("app overlap\ncheck siblings-disjoint")

    let failure = try #require(report.failures.first)
    #expect(report.failures.count == 1)
    #expect(failure.verb == "check")
    #expect(failure.line == 2)
    #expect(failure.statement == "check siblings-disjoint")
    #expect(failure.rule == "siblings-disjoint")
    #expect(failure.node?.hasPrefix("root") == true)
    #expect(failure.message.hasPrefix("siblings-disjoint at root"))
    #expect(failure.message.contains("under Overlap"))
    #expect(failure.screen?.first == "second")
    #expect(report.json.contains(#""rule":"siblings-disjoint""#))
  }

  @Test
  func `a bare check reports a warning without failing and a named rule fails on it`()
    async throws
  {
    let bare = try await play("app overflow\ncheck")
    let named = try await play("app overflow\ncheck frame-inside-clip")
    let others = try await play(
      "app overflow\ncheck no-dirty-after-pass siblings-disjoint")

    #expect(bare.failures.map(\.rule) == ["measured-within-proposal"])
    let lines = try #require(bare.observations.first?.lines)
    #expect(lines.count == 2)
    #expect(lines[1].hasPrefix("warning frame-inside-clip root"))
    #expect(named.failures.map(\.rule) == ["frame-inside-clip"])
    #expect(named.observations.first?.lines.count == 1)
    #expect(others.passed, "\(others)")
  }

  // MARK: dump

  @Test
  func `dump observes the whole projection as a JSON object in the report`() async throws
  {
    let report = try await play("app layers\ndump")

    let observation = try #require(report.observations.first)
    #expect(observation.verb == "dump")
    #expect(observation.lines.isEmpty)
    let projection = try #require(observation.projection)
    #expect(projection.pass == 0)
    #expect(projection.nodes.count > 5)
    let json = try #require(
      JSONSerialization.jsonObject(with: Data(report.json.utf8)) as? [String: Any])
    let observations = try #require(json["observations"] as? [[String: Any]])
    let dumped = try #require(observations.first?["projection"] as? [String: Any])
    #expect(dumped["version"] as? Int == 1)
    #expect((dumped["nodes"] as? [Any])?.count == projection.nodes.count)
    #expect(
      Set(dumped.keys) == [
        "nodes", "pass", "requirements", "screen", "statistics", "version",
      ])
  }

  @Test
  func `two dumps of one scenario are the same bytes`() async throws {
    let first = try await play("app layers\nkey x\ndump")
    let second = try await play("app layers\nkey x\ndump")

    #expect(first.json == second.json)
    #expect(first.observations.first?.projection?.pass == 1)
  }

  // MARK: expect cost

  @Test
  func `expect cost holds while the last step took no more than each bound`() async throws
  {
    let report = try await play(
      """
      app steady
      key x
      expect cost bodies<=0 bytes<=0 measures<=0 placements<=0 renders<=0
      key +
      expect cost bytes<=100 renders<=1
      """)

    #expect(report.passed, "\(report)")
  }

  @Test
  func
    `expect cost names the step, the counter, and every count when a bound is exceeded`()
    async throws
  {
    let report = try await play("app steady\nkey +\nexpect cost bytes<=0 measures<=5")

    let failure = try #require(report.failures.first)
    #expect(failure.verb == "expect cost")
    #expect(failure.line == 3)
    #expect(failure.message.hasPrefix("step 1 (key +) took "))
    #expect(failure.message.contains(" bytes, above the bound 0"))
    #expect(failure.expected == "bytes<=0 measures<=5")
    #expect(failure.actual?.contains(" bytes=") == true)
    #expect(failure.actual?.contains("renders=") == true)
  }

  @Test
  func `expect cost before any event bounds the first frame`() async throws {
    let report = try await play("app layers\nexpect cost bytes<=1")

    let failure = try #require(report.failures.first)
    #expect(failure.message.hasPrefix("step 0 (resize 80x24) took "))
  }

  @Test
  func `the last event of a type statement is the step the cost belongs to`() async throws
  {
    let report = try await play(
      "app steady\ntype \"+x\"\nexpect cost bytes<=0 renders<=0")

    #expect(report.passed, "\(report)")
  }

  // MARK: Locators

  @Test
  func `a locator finds a container by its layout and a ForEach item by its key`()
    async throws
  {
    let report = try await play(
      """
      app layers
      expect node layout=_FrameLayout frame 0,0,2x1
      expect node layout=_PaddingLayout frame 0,1,4x3
      expect node id=a frame 0,4,1x1
      expect node id=b frame 0,5,1x1
      expect node type=ForEach frame 0,4,1x2
      """)

    #expect(report.passed, "\(report)")
  }

  @Test
  func `text is the topmost leaf's, so covered text does not match`() async throws {
    let covered = try await play("app layers\nexpect node text=status frame 0,0,6x1")
    let shown = try await play("app layers\nexpect node text=atus frame 0,0,6x1")
    let top = try await play("app layers\nexpect node text=OK frame 0,0,2x1")

    #expect(
      covered.failures.first?.message == "locator `text=\"status\"` matches no node")
    #expect(shown.passed, "\(shown)")
    #expect(top.passed, "\(top)")
  }

  @Test
  func `a locator that matches nothing names the types and layouts present`() async throws
  {
    let report = try await play(
      "app layers\nexpect node layout=_NoSuchLayout frame 0,0,1x1")

    let actual = try #require(report.failures.first?.actual)
    #expect(actual.hasPrefix("(no node; types: "))
    #expect(actual.contains("_LayoutContainer"))
    #expect(actual.contains("; layouts: _FrameLayout, _PaddingLayout)"))
  }

  @Test
  func `a locator that matches several without nth says so and lists them`() async throws
  {
    let report = try await play("app layers\nexpect node type=Text frame 0,0,1x1")

    let failure = try #require(report.failures.first)
    #expect(failure.message.hasPrefix("locator `type=Text` matches "))
    #expect(failure.message.hasSuffix(" nodes; add nth="))
    #expect(failure.actual?.contains("root/index(0)/index(1)") == true)
  }

  // MARK: Trace and shots

  @Test
  func `a played scenario carries one trace record per step`() async throws {
    let report = try await play("app growing\nkey +\ntype \"+-\"\nresize 30x6")

    #expect(report.trace.map(\.seq) == [0, 1, 2, 3, 4])
    #expect(report.trace.map(\.event.type) == ["resize", "key", "key", "key", "resize"])
  }

  @Test
  func `a scenario that stops at a quit still keeps the trace it made`() async throws {
    let registry = Fixtures.registry()
    let scenario = try ScenarioParser.parse(
      "app counter\nkey q\nexpect text 0 \"x\"", file: "t.scn",
      knownApps: try registry.names())

    let report = await ScenarioPlayer.run(scenario, name: "t.scn", registry: registry)

    #expect(report.trace.count == 2)
    #expect(report.failures.map(\.verb) == ["expect text"])
  }
}
