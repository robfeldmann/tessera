import CustomDump
import Foundation
import InlineSnapshotTesting
import SnapshotTesting
import SnapshotTestingCustomDump
import Testing

@testable import TesseraHarness

private func parse(_ source: String) throws -> Scenario {
  try ScenarioParser.parse(
    source, file: "t.scn",
    knownApps: ProjectionFixtures.names + Fixtures.names)
}

extension ProjectionFixtures {
  static let names = [
    "overlap", "overflow", "layers", "styled", "wide", "steady", "growing", "list-layers",
    "list-overlap", "shadowed-list",
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
    expectNoDifference(
      try [statement("check"), statement("check siblings-disjoint no-dirty-after-pass")],
      [.check(rules: []), .check(rules: [.siblingsDisjoint, .noDirtyAfterPass])]
    )
  }

  @Test
  func `an unknown or repeated check rule is a parse error that names the rules`() {
    assertInlineSnapshot(
      of: [
        message("check no-such-rule"),
        message("check siblings-disjoint siblings-disjoint"),
      ],
      as: .customDump
    ) {
      """
      [
        [0]: "unknown check rule `no-such-rule`; accepted: no-dirty-after-pass, frame-inside-clip, measured-within-proposal, siblings-disjoint, requirements-aggregate",
        [1]: "check rule `siblings-disjoint` is named twice"
      ]
      """
    }
  }

  @Test
  func `dump takes no argument`() throws {
    #expect(try statement("dump") == .dump)
    assertInlineSnapshot(of: message("dump everything"), as: .customDump) {
      """
      "usage: dump (the whole projection; it takes no argument)"
      """
    }
  }

  @Test
  func `expect cost takes a bound for each counter it names`() throws {
    expectNoDifference(
      try [
        statement("expect cost bodies<=5 bytes<=40"), statement("expect cost renders<=0"),
      ],
      [
        .expectCost([
          CostBound(counter: "bodies", limit: 5), CostBound(counter: "bytes", limit: 40),
        ]),
        .expectCost([CostBound(counter: "renders", limit: 0)]),
      ]
    )
  }

  @Test
  func
    `expect cost refuses everything but a counter, then less than or equal, then a number`()
    throws
  {
    let lines = [
      "expect cost", "expect cost bodies<5", "expect cost bodies <= 5",
      "expect cost frames<=5", "expect cost bodies<=many", "expect cost bodies<=-1",
      "expect cost bodies<=1 bodies<=2",
    ]

    assertInlineSnapshot(of: lines.map(message), as: .customDump) {
      #"""
      [
        [0]: "usage: expect cost NAME<=N… (counters: bodies, bytes, measures, placements, renders)",
        [1]: "cost bound `bodies<5` is not NAME<=N, written without spaces; only `<=` is accepted, because the counts are the library\'s work and change with it (counters: bodies, bytes, measures, placements, renders)",
        [2]: "cost bound `bodies` is not NAME<=N, written without spaces; only `<=` is accepted, because the counts are the library\'s work and change with it (counters: bodies, bytes, measures, placements, renders)",
        [3]: "unknown cost counter `frames`; accepted: bodies, bytes, measures, placements, renders",
        [4]: "cost bound `bodies<=many` needs a non-negative whole number after `<=`",
        [5]: "cost bound `bodies<=-1` needs a non-negative whole number after `<=`",
        [6]: "cost counter `bodies` is bounded twice"
      ]
      """#
    }
  }

  @Test
  func `the unknown statement error lists the new statements`() {
    assertInlineSnapshot(of: message("blink"), as: .customDump) {
      """
      "unknown statement `blink`; accepted: app, size, term, resize, key, type, paste, bytes, shot, tree, dump, check, expect text, expect screen, expect node, expect cost"
      """
    }
  }

  @Test
  func `a locator takes a layout, and the accepted keys name it`() throws {
    expectNoDifference(
      try statement("expect node layout=_FrameLayout nth=1 frame 0,0,2x1"),
      .expectNode(
        Locator(layout: "_FrameLayout", nth: 1),
        FrameExpectation(column: 0, row: 0, columns: 2, rows: 1))
    )
    assertInlineSnapshot(
      of: message("expect node colour=red frame 0,0,1x1"), as: .customDump
    ) {
      """
      "unknown locator key `colour`; accepted: type, layout, id, text, nth"
      """
    }
  }

  @Test
  func
    `a locator key with an empty value is a parse error and not a query for everything`()
  {
    let lines =
      ["type", "layout", "id", "text"].map { "expect node \($0)= frame 0,0,1x1" }
      + [#"expect node text="" frame 0,0,1x1"#]

    assertInlineSnapshot(of: lines.map(message), as: .customDump) {
      """
      [
        [0]: "locator key `type` needs a value that is not empty",
        [1]: "locator key `layout` needs a value that is not empty",
        [2]: "locator key `id` needs a value that is not empty",
        [3]: "locator key `text` needs a value that is not empty",
        [4]: "locator key `text` needs a value that is not empty"
      ]
      """
    }
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

    expectNoDifference(report.failures, [])
    assertInlineSnapshot(of: report.observations, as: .customDump) {
      """
      [
        [0]: ScenarioObservation(
          line: 2,
          verb: "check",
          name: nil,
          lines: [
            [0]: "ran no-dirty-after-pass, frame-inside-clip, measured-within-proposal, siblings-disjoint, requirements-aggregate"
          ],
          projection: nil
        )
      ]
      """
    }
  }

  @Test
  func `layers a ForEach and an if build under a ZStack pass siblings-disjoint`()
    async throws
  {
    // The items really do share a frame, which is what makes this the case worth checking.
    let report = try await play(
      """
      app list-layers
      expect node id=abcd frame 0,0,4x1
      expect node id=ef frame 0,0,2x1
      expect node type=Text text="h" frame 0,1,1x1
      check siblings-disjoint
      check
      """)

    expectNoDifference(report.failures, [])
    assertInlineSnapshot(of: report.observations, as: .customDump) {
      """
      [
        [0]: ScenarioObservation(
          line: 5,
          verb: "check",
          name: nil,
          lines: [
            [0]: "ran siblings-disjoint"
          ],
          projection: nil
        ),
        [1]: ScenarioObservation(
          line: 6,
          verb: "check",
          name: nil,
          lines: [
            [0]: "ran no-dirty-after-pass, frame-inside-clip, measured-within-proposal, siblings-disjoint, requirements-aggregate"
          ],
          projection: nil
        )
      ]
      """
    }
  }

  @Test
  func `a list on a layout that is not a ZStack still fails siblings-disjoint`()
    async throws
  {
    let report = try await play("app list-overlap\ncheck siblings-disjoint")

    assertInlineSnapshot(of: report.failures, as: .customDump) {
      """
      [
        [0]: ScenarioFailure(
          line: 2,
          statement: "check siblings-disjoint",
          verb: "check",
          message: "siblings-disjoint at root/index(0)/index(0)/id(b): shows 0,0,1x1, which overlaps sibling root/index(0)/index(0)/id(a) showing 0,0,1x1 under ForEach",
          expected: nil,
          actual: nil,
          screen: [
            [0]: "b"
          ],
          rule: "siblings-disjoint",
          node: "root/index(0)/index(0)/id(b)"
        )
      ]
      """
    }
  }

  @Test
  func
    `an app's own view named ForEach is not a list, so its overlapping body is reported`()
    async throws
  {
    let report = try await play(
      """
      app shadowed-list
      expect node type=Text text="second" frame 0,0,6x1
      check siblings-disjoint
      """)

    // The app's `ForEach` is not looked through, so the `ZStack` does not excuse the two texts
    // that its container-less body puts on one frame.
    assertInlineSnapshot(of: report.failures, as: .customDump) {
      """
      [
        [0]: ScenarioFailure(
          line: 3,
          statement: "check siblings-disjoint",
          verb: "check",
          message: "siblings-disjoint at root/index(0)/index(0)/body/index(1): shows 0,0,6x1, which overlaps sibling root/index(0)/index(0)/body/index(0) showing 0,0,5x1 under TupleView",
          expected: nil,
          actual: nil,
          screen: [
            [0]: "second"
          ],
          rule: "siblings-disjoint",
          node: "root/index(0)/index(0)/body/index(1)"
        )
      ]
      """
    }
  }

  @Test
  func `a violated rule fails the statement with its rule and node`() async throws {
    let report = try await play("app overlap\ncheck siblings-disjoint")

    assertInlineSnapshot(of: report.failures, as: .customDump) {
      """
      [
        [0]: ScenarioFailure(
          line: 2,
          statement: "check siblings-disjoint",
          verb: "check",
          message: "siblings-disjoint at root/index(0)/index(1): shows 0,0,6x1, which overlaps sibling root/index(0)/index(0) showing 0,0,5x1 under Overlap",
          expected: nil,
          actual: nil,
          screen: [
            [0]: "second"
          ],
          rule: "siblings-disjoint",
          node: "root/index(0)/index(1)"
        )
      ]
      """
    }
    assertInlineSnapshot(of: report.json, as: .lines) {
      """
      {"failures":[{"line":2,"message":"siblings-disjoint at root/index(0)/index(1): shows 0,0,6x1, which overlaps sibling root/index(0)/index(0) showing 0,0,5x1 under Overlap","node":"root/index(0)/index(1)","rule":"siblings-disjoint","screen":["second"],"statement":"check siblings-disjoint","verb":"check"}],"observations":[{"line":2,"lines":["ran siblings-disjoint"],"verb":"check"}],"passed":false,"scenario":"t.scn"}
      """
    }
  }

  @Test
  func `a bare check reports a warning without failing and a named rule fails on it`()
    async throws
  {
    let bare = try await play("app overflow\ncheck")
    let named = try await play("app overflow\ncheck frame-inside-clip")
    let others = try await play(
      "app overflow\ncheck no-dirty-after-pass siblings-disjoint")

    assertInlineSnapshot(of: bare, as: .customDump) {
      """
      ScenarioReport(
        scenario: "t.scn",
        failures: [
          [0]: ScenarioFailure(
            line: 2,
            statement: "check",
            verb: "check",
            message: "measured-within-proposal at root/index(0)/index(0)/index(0): measured 12 columns where 4 were offered",
            expected: nil,
            actual: nil,
            screen: [
              [0]: "wide",
              [1]: "ok"
            ],
            rule: "measured-within-proposal",
            node: "root/index(0)/index(0)/index(0)"
          )
        ],
        observations: [
          [0]: ScenarioObservation(
            line: 2,
            verb: "check",
            name: nil,
            lines: [
              [0]: "ran no-dirty-after-pass, frame-inside-clip, measured-within-proposal, siblings-disjoint, requirements-aggregate",
              [1]: "warning frame-inside-clip root/index(0)/index(0)/index(0): frame 0,0,12x1 is clipped to 0,0,4x1 (visible text `wide`)"
            ],
            projection: nil
          )
        ],
        recorded: [],
        seconds: [],
        trace: [
          [0]: TraceRecord(
            version: 1,
            seq: 0,
            event: TraceEvent(
              type: "resize",
              key: nil,
              kind: nil,
              text: nil,
              size: "80x24",
              detail: nil
            ),
            drew: true,
            reasons: [
              [0]: "layoutEnvironmentChanged",
              [1]: "layoutViewChanged",
              [2]: "renderEnvironmentChanged",
              [3]: "renderRequested",
              [4]: "renderViewChanged",
              [5]: "updateRequested"
            ],
            nodes: TraceRecord.NodeChanges(
              added: [
                [0]: "root",
                [1]: "root/index(0)",
                [2]: "root/index(0)/index(0)",
                [3]: "root/index(0)/index(0)/index(0)",
                [4]: "root/index(0)/index(1)"
              ],
              changed: [],
              removed: []
            ),
            rows: [
              [0]: 0,
              [1]: 1
            ],
            cost: StepCost(
              bodies: 0,
              bytes: 2097,
              measures: 11,
              placements: 5,
              renders: 2
            )
          )
        ]
      )
      """
    }
    assertInlineSnapshot(of: named, as: .customDump) {
      """
      ScenarioReport(
        scenario: "t.scn",
        failures: [
          [0]: ScenarioFailure(
            line: 2,
            statement: "check frame-inside-clip",
            verb: "check",
            message: "frame-inside-clip at root/index(0)/index(0)/index(0): frame 0,0,12x1 is clipped to 0,0,4x1 (visible text `wide`)",
            expected: nil,
            actual: nil,
            screen: [
              [0]: "wide",
              [1]: "ok"
            ],
            rule: "frame-inside-clip",
            node: "root/index(0)/index(0)/index(0)"
          )
        ],
        observations: [
          [0]: ScenarioObservation(
            line: 2,
            verb: "check",
            name: nil,
            lines: [
              [0]: "ran frame-inside-clip"
            ],
            projection: nil
          )
        ],
        recorded: [],
        seconds: [],
        trace: [
          [0]: TraceRecord(
            version: 1,
            seq: 0,
            event: TraceEvent(
              type: "resize",
              key: nil,
              kind: nil,
              text: nil,
              size: "80x24",
              detail: nil
            ),
            drew: true,
            reasons: [
              [0]: "layoutEnvironmentChanged",
              [1]: "layoutViewChanged",
              [2]: "renderEnvironmentChanged",
              [3]: "renderRequested",
              [4]: "renderViewChanged",
              [5]: "updateRequested"
            ],
            nodes: TraceRecord.NodeChanges(
              added: [
                [0]: "root",
                [1]: "root/index(0)",
                [2]: "root/index(0)/index(0)",
                [3]: "root/index(0)/index(0)/index(0)",
                [4]: "root/index(0)/index(1)"
              ],
              changed: [],
              removed: []
            ),
            rows: [
              [0]: 0,
              [1]: 1
            ],
            cost: StepCost(
              bodies: 0,
              bytes: 2097,
              measures: 11,
              placements: 5,
              renders: 2
            )
          )
        ]
      )
      """
    }
    expectNoDifference(others.failures, [])
  }

  // MARK: dump

  @Test
  func `dump observes the whole projection as a JSON object in the report`() async throws
  {
    let report = try await play("app layers\ndump")

    let observation = try #require(report.observations.first)
    let projection = try #require(observation.projection)
    assertInlineSnapshot(
      of: (observation.verb, observation.lines, projection.pass, projection.nodes.count),
      as: .customDump
    ) {
      """
      (
        "dump",
        [],
        0,
        13
      )
      """
    }
    let json = try #require(
      JSONSerialization.jsonObject(with: Data(report.json.utf8)) as? [String: Any])
    let observations = try #require(json["observations"] as? [[String: Any]])
    let dumped = try #require(observations.first?["projection"] as? [String: Any])
    #expect(dumped["version"] as? Int == 1)
    #expect((dumped["nodes"] as? [Any])?.count == projection.nodes.count)
    expectNoDifference(
      dumped.keys.sorted(),
      ["nodes", "pass", "requirements", "screen", "statistics", "version"])
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

    expectNoDifference(report.failures, [])
  }

  @Test
  func
    `expect cost names the step, the counter, and every count when a bound is exceeded`()
    async throws
  {
    let report = try await play("app steady\nkey +\nexpect cost bytes<=0 measures<=5")

    assertInlineSnapshot(of: report.failures, as: .customDump) {
      """
      [
        [0]: ScenarioFailure(
          line: 3,
          statement: "expect cost bytes<=0 measures<=5",
          verb: "expect cost",
          message: "step 1 (key +) took 17 bytes, above the bound 0",
          expected: "bytes<=0 measures<=5",
          actual: "bodies=1 bytes=17 measures=4 placements=4 renders=1",
          screen: nil,
          rule: nil,
          node: nil
        )
      ]
      """
    }
  }

  @Test
  func `expect cost before any event bounds the first frame`() async throws {
    let report = try await play("app layers\nexpect cost bytes<=1")

    assertInlineSnapshot(of: report.failures, as: .customDump) {
      """
      [
        [0]: ScenarioFailure(
          line: 2,
          statement: "expect cost bytes<=1",
          verb: "expect cost",
          message: "step 0 (resize 80x24) took 2097 bytes, above the bound 1",
          expected: "bytes<=1",
          actual: "bodies=0 bytes=2097 measures=29 placements=13 renders=5",
          screen: nil,
          rule: nil,
          node: nil
        )
      ]
      """
    }
  }

  @Test
  func `the last event of a type statement is the step the cost belongs to`() async throws
  {
    let report = try await play(
      "app steady\ntype \"+x\"\nexpect cost bytes<=0 renders<=0")

    expectNoDifference(report.failures, [])
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

    expectNoDifference(report.failures, [])
  }

  @Test
  func `text is the topmost leaf's, so covered text does not match`() async throws {
    let covered = try await play("app layers\nexpect node text=status frame 0,0,6x1")
    let shown = try await play("app layers\nexpect node text=atus frame 0,0,6x1")
    let top = try await play("app layers\nexpect node text=OK frame 0,0,2x1")

    assertInlineSnapshot(of: covered.failures, as: .customDump) {
      """
      [
        [0]: ScenarioFailure(
          line: 2,
          statement: "expect node text=status frame 0,0,6x1",
          verb: "expect node",
          message: #"locator `text="status"` matches no node"#,
          expected: "0,0,6x1",
          actual: "(no node; types: TupleView, VStack, ZStack, Text, _LayoutContainer, ForEach; layouts: _FrameLayout, _PaddingLayout)",
          screen: [
            [0]: "OKatus",
            [1]: "",
            [2]: " Go",
            [3]: "",
            [4]: "a",
            [5]: "b"
          ],
          rule: nil,
          node: nil
        )
      ]
      """
    }
    expectNoDifference(shown.failures, [])
    expectNoDifference(top.failures, [])
  }

  @Test
  func `a locator that matches nothing names the types and layouts present`() async throws
  {
    let report = try await play(
      "app layers\nexpect node layout=_NoSuchLayout frame 0,0,1x1")

    assertInlineSnapshot(of: report.failures, as: .customDump) {
      """
      [
        [0]: ScenarioFailure(
          line: 2,
          statement: "expect node layout=_NoSuchLayout frame 0,0,1x1",
          verb: "expect node",
          message: "locator `layout=_NoSuchLayout` matches no node",
          expected: "0,0,1x1",
          actual: "(no node; types: TupleView, VStack, ZStack, Text, _LayoutContainer, ForEach; layouts: _FrameLayout, _PaddingLayout)",
          screen: [
            [0]: "OKatus",
            [1]: "",
            [2]: " Go",
            [3]: "",
            [4]: "a",
            [5]: "b"
          ],
          rule: nil,
          node: nil
        )
      ]
      """
    }
  }

  @Test
  func `a locator that matches several without nth says so and lists them`() async throws
  {
    let report = try await play("app layers\nexpect node type=Text frame 0,0,1x1")

    assertInlineSnapshot(of: report.failures, as: .customDump) {
      """
      [
        [0]: ScenarioFailure(
          line: 2,
          statement: "expect node type=Text frame 0,0,1x1",
          verb: "expect node",
          message: "locator `type=Text` matches 5 nodes; add nth=",
          expected: "0,0,1x1",
          actual: "root/index(0)/index(0)/index(0), root/index(0)/index(0)/index(1)/index(0), root/index(0)/index(1)/index(0), root/index(0)/index(2)/id(a)/index(0), root/index(0)/index(2)/id(b)/index(0)",
          screen: [
            [0]: "OKatus",
            [1]: "",
            [2]: " Go",
            [3]: "",
            [4]: "a",
            [5]: "b"
          ],
          rule: nil,
          node: nil
        )
      ]
      """
    }
  }

  // MARK: Trace and shots

  @Test
  func `a played scenario carries one trace record per step`() async throws {
    let report = try await play("app growing\nkey +\ntype \"+-\"\nresize 30x6")

    expectNoDifference(report.trace.map(\.seq), [0, 1, 2, 3, 4])
    expectNoDifference(
      report.trace.map(\.event.type), ["resize", "key", "key", "key", "resize"])
  }

  @Test
  func `a scenario that stops at a quit still keeps the trace it made`() async throws {
    let registry = Fixtures.registry()
    let scenario = try ScenarioParser.parse(
      "app counter\nkey q\nexpect text 0 \"x\"", file: "t.scn",
      knownApps: try registry.names())

    let report = await ScenarioPlayer.run(scenario, name: "t.scn", registry: registry)

    #expect(report.trace.count == 2)
    assertInlineSnapshot(of: report.failures, as: .customDump) {
      """
      [
        [0]: ScenarioFailure(
          line: 3,
          statement: #"expect text 0 "x""#,
          verb: "expect text",
          message: "the application finished at line 2 (`key q`), and in a terminal nothing after it runs",
          expected: nil,
          actual: nil,
          screen: nil,
          rule: nil,
          node: nil
        )
      ]
      """
    }
  }
}
