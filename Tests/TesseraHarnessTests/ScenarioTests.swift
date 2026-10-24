import CustomDump
import Foundation
import InlineSnapshotTesting
import SnapshotTesting
import SnapshotTestingCustomDump
import TesseraTerminalInput
import Testing

@testable import TesseraHarness

/// The text of the parse error `source` raises, in the `FILE:LINE: error: message` form.
private func parseFailure(of source: String) -> String {
  do {
    _ = try ScenarioParser.parse(source, file: "t.scn")
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
    let scenario = try ScenarioParser.parse(
      """
      # comment
      app stack
      size mobile
      type "hi there"  # trailing comment
      """,
      file: "t.scn"
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
    let scenario = try ScenarioParser.parse(
      "key Shift+Tab\nkey Ctrl+C\nkey F5\nkey Ctrl++",
      file: "t.scn"
    )

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
    let scenario = try ScenarioParser.parse(
      "expect node id=root frame 1,2,3x4\nexpect node id=root frame 1,2 3x4",
      file: "t.scn"
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

struct ScenarioRunnerTests {
  private func run(_ source: String) throws -> ScenarioReport {
    ScenarioRunner.run(try ScenarioParser.parse(source, file: "t.scn"), name: "t.scn")
  }

  @Test
  func `a wrong row expectation reports expected actual and the screen`() throws {
    let report = try run("app stack\nsize 40x10\nexpect text 0 \"Stack demos\"")

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
  func `the run continues after a failed expectation`() throws {
    let report = try run(
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
  func `a locator that matches nothing is a failure that names the node types`() throws {
    let report = try run("app stack\nsize 40x10\nexpect node type=Missing frame 0,0,1x1")

    assertInlineSnapshot(of: report.human(), as: .lines) {
      """
      FAIL t.scn
        line 3: expect node type=Missing frame 0,0,1x1
          locator `type=Missing` matches no node
          expected: 0,0,1x1
          actual:   (no node; types: VStack, Text, Divider, HStack, Spacer)
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
  func `an ambiguous locator asks for nth`() throws {
    let report = try run("app stack\nsize 40x10\nexpect node type=Text frame 0,0,1x1")

    assertInlineSnapshot(of: report.human(), as: .lines) {
      """
      FAIL t.scn
        line 3: expect node type=Text frame 0,0,1x1
          locator `type=Text` matches 6 nodes; add nth=
          expected: 0,0,1x1
          actual:   root/index(0), root/index(2)/index(0), root/index(2)/index(1), root/index(3)/index(0), root/index(3)/index(2), root/index(5)
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
  func `type feeds one key event per character into demo state`() throws {
    let report = try run(
      "app stack\nsize 40x10\ntype \"Rob\"\nkey Backspace\nexpect text 2 \"Name: Ro\"")

    expectNoDifference(report.failures, [])
  }

  @Test
  func `mobile fails for a demo that fills its proposal`() throws {
    let report = try run("app workspace\nsize mobile\nshot a")

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
            message: "`workspace` fills a 500-row proposal, so it has no natural height; use `size mobileScreen` or an explicit WxH",
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

    expectNoDifference(first.failures, [])
    #expect(first.passed)
    #expect(first.json() == second.json())
  }

  @Test
  func `the failing scenario fails four expectations`() throws {
    let report = try report(for: "failing/mismatch.scn")

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
          actual:   (no node; types: VStack, Text, Divider, HStack, Spacer)
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
