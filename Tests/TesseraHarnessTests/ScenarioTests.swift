import CustomDump
import Foundation
import InlineSnapshotTesting
import SnapshotTesting
import SnapshotTestingCustomDump
import TesseraCore
import TesseraTerminalInput
import Testing

@testable import TesseraHarness

private func parse(_ source: String, file: String = "t.scn") throws -> Scenario {
  try ScenarioParser.parse(source, file: file, knownApps: Fixtures.names)
}

/// The text of the parse error `source` raises, in the `FILE:LINE: error: message` form.
private func parseFailure(of source: String) -> String {
  do {
    _ = try parse(source)
    Issue.record("`\(source)` parsed without an error")
  } catch let error as ScenarioParseError {
    return error.description
  } catch {
    Issue.record(error, "`\(source)` raised a different error")
  }
  return ""
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

    assertInlineSnapshot(of: scenario, as: .customDump) {
      """
      Scenario(
        app: "stack",
        viewport: .mobile,
        lines: [
          [0]: ScenarioLine(
            number: 4,
            source: #"type "hi there"  # trailing comment"#,
            statement: .type("hi there")
          )
        ]
      )
      """
    }
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
    assertInlineSnapshot(of: parseFailure(of: "key Tab\nsize 10x10"), as: .lines) {
      """
      t.scn:2: error: `size` is a header statement; use `resize WxH` after the first body statement
      """
    }
  }

  @Test
  func `unknown statements list the accepted vocabulary`() {
    assertInlineSnapshot(of: parseFailure(of: "jump 3"), as: .lines) {
      """
      t.scn:1: error: unknown statement `jump`; accepted: app, size, resize, key, type, shot, tree, expect text, expect node
      """
    }
  }

  @Test
  func `reserved verbs are reported as not yet expressible`() {
    assertInlineSnapshot(of: parseFailure(of: "mouse click 3,4"), as: .lines) {
      """
      t.scn:1: error: `mouse` is not yet expressible in v0; accepted: app, size, resize, key, type, shot, tree, expect text, expect node
      """
    }
  }

  @Test
  func `unknown key names list the accepted set`() {
    assertInlineSnapshot(of: parseFailure(of: "key Hyperspace"), as: .lines) {
      """
      t.scn:1: error: unknown key `Hyperspace`; accepted: ArrowDown, ArrowLeft, ArrowRight, ArrowUp, Backspace, Delete, End, Enter, Escape, Home, PageDown, PageUp, Space, Tab, F1, F2, F3, F4, F5, F6, F7, F8, F9, F10, F11, F12, a single character; modifiers: Alt, Control, Ctrl, Meta, Shift, Super joined with `+`
      """
    }
  }

  @Test
  func `chords and function keys parse into key events`() throws {
    let scenario = try parse("app stack\nkey Shift+Tab\nkey Ctrl+C\nkey F5\nkey Ctrl++")

    expectNoDifference(
      scenario.lines.map(\.statement),
      [
        .key(Key(code: .tab, modifiers: .shift)),
        .key(Key(code: .character("c"), modifiers: .control)),
        .key(Key(code: .function(5))),
        .key(Key(code: .character("+"), modifiers: .control)),
      ]
    )
  }

  @Test
  func `frame expectations accept one token or a two-token form`() throws {
    let scenario = try parse(
      "app stack\nexpect node id=root frame 1,2,3x4\nexpect node id=root frame 1,2 3x4"
    )

    let expected = Statement.expectNode(
      Locator(id: "root"),
      FrameExpectation(column: 1, row: 2, columns: 3, rows: 4)
    )

    expectNoDifference(scenario.lines.map(\.statement), [expected, expected])
  }

  @Test
  func `unterminated quotes fail with the line number`() {
    assertInlineSnapshot(of: parseFailure(of: "\ntype \"oops"), as: .lines) {
      """
      t.scn:2: error: unterminated double quote
      """
    }
  }

  @Test
  func `duplicate shot names are rejected`() {
    assertInlineSnapshot(of: parseFailure(of: "shot a\nshot a"), as: .lines) {
      """
      t.scn:2: error: duplicate shot name `a`
      """
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

    assertInlineSnapshot(of: report, as: .customDump) {
      """
      ScenarioReport(
        scenario: "t.scn",
        passed: false,
        failures: [
          [0]: ScenarioFailure(
            line: 3,
            statement: #"expect text 0 "Stack demos""#,
            verb: "expect text",
            message: "row 0 text differs",
            expected: "Stack demos",
            actual: "Stack demo",
            screen: [
              [0]: "Stack demo",
              [1]: "────────────────────────────────────────",
              [2]: "Name: -",
              [3]: "left                               right",
              [4]: "────────────────────────────────────────",
              [5]: "40 columns"
            ]
          )
        ],
        observations: []
      )
      """
    }
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

    assertInlineSnapshot(of: report.human(), as: .lines) {
      """
      FAIL t.scn
        line 3: expect text 0 "wrong"
          row 0 text differs
          expected: wrong
          actual:   Stack demo
          screen:
            0| Stack demo
            1| ────────────────────────────────────────
            2| Name: -
            3| left                               right
            4| ────────────────────────────────────────
            5| 40 columns
        line 6: expect text 5 "wrong again"
          row 5 text differs
          expected: wrong again
          actual:   40 columns
          screen:
            0| Stack demo
            1| ────────────────────────────────────────
            2| Name: x
            3| left                               right
            4| ────────────────────────────────────────
            5| 40 columns
      """
    }
  }

  @Test
  func `a locator that matches nothing is a failure that names the node types`()
    async throws
  {
    let report = try await run(
      "app stack\nsize 40x10\nexpect node type=Missing frame 0,0,1x1")

    assertInlineSnapshot(of: report.human(), as: .lines) {
      """
      FAIL t.scn
        line 3: expect node type=Missing frame 0,0,1x1
          locator `type=Missing` matches no node
          expected: 0,0,1x1
          actual:   (no node; types: TupleView, VStack, Text, Divider, HStack, Spacer)
          screen:
            0| Stack demo
            1| ────────────────────────────────────────
            2| Name: -
            3| left                               right
            4| ────────────────────────────────────────
            5| 40 columns
      """
    }
  }

  @Test
  func `an ambiguous locator asks for nth`() async throws {
    let report = try await run(
      "app stack\nsize 40x10\nexpect node type=Text frame 0,0,1x1")

    assertInlineSnapshot(of: report.human(), as: .lines) {
      """
      FAIL t.scn
        line 3: expect node type=Text frame 0,0,1x1
          locator `type=Text` matches 6 nodes; add nth=
          expected: 0,0,1x1
          actual:   root/index(0)/index(0), root/index(0)/index(2)/index(0), root/index(0)/index(2)/index(1), root/index(0)/index(3)/index(0), root/index(0)/index(3)/index(2), root/index(0)/index(5)
          screen:
            0| Stack demo
            1| ────────────────────────────────────────
            2| Name: -
            3| left                               right
            4| ────────────────────────────────────────
            5| 40 columns
      """
    }
  }

  @Test
  func `type feeds one key event per character into app state`() async throws {
    let report = try await run(
      "app stack\nsize 40x10\ntype \"Rob\"\nkey Backspace\nexpect text 2 \"Name: Ro\"")

    expectNoDifference(report.failures, [])
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

    assertInlineSnapshot(of: report, as: .customDump) {
      """
      ScenarioReport(
        scenario: "t.scn",
        passed: false,
        failures: [
          [0]: ScenarioFailure(
            line: 0,
            statement: "app workspace",
            verb: "size",
            message: "`workspace` has no natural height: it measured 500 rows when offered 500 and 1000 when offered 1000. Use `size mobileScreen` (40x16) or an explicit WxH",
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

    expectNoDifference(first.failures, [])
    #expect(first.passed)
    #expect(first.json() == second.json())
  }

  @Test
  func `the failing scenario fails four expectations`() async throws {
    let report = try await report(for: "failing/mismatch.scn")

    assertInlineSnapshot(of: report.human(), as: .lines) {
      """
      FAIL failing/mismatch.scn
        line 6: expect text 0 "Stack demos"
          row 0 text differs
          expected: Stack demos
          actual:   Stack demo
          screen:
            0| Stack demo
            1| ────────────────────────────────────────
            2| Name: -
            3| left                               right
            4| ────────────────────────────────────────
            5| 40 columns
        line 7: expect text "no such text"
          no screen row contains the text
          expected: no such text
          actual:   (not found in 10 rows)
          screen:
            0| Stack demo
            1| ────────────────────────────────────────
            2| Name: -
            3| left                               right
            4| ────────────────────────────────────────
            5| 40 columns
        line 8: expect node id=root frame 0,0,40x6
          frame of `id=root` differs
          expected: 0,0,40x6
          actual:   0,0,40x10
          screen:
            0| Stack demo
            1| ────────────────────────────────────────
            2| Name: -
            3| left                               right
            4| ────────────────────────────────────────
            5| 40 columns
        line 10: expect node type=Missing frame 0,0,1x1
          locator `type=Missing` matches no node
          expected: 0,0,1x1
          actual:   (no node; types: TupleView, VStack, Text, Divider, HStack, Spacer)
          screen:
            0| Stack demo
            1| ────────────────────────────────────────
            2| Name: -
            3| left                               right
            4| ────────────────────────────────────────
            5| 40 columns
      """
    }
  }
}
