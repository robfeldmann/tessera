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

/// The parse error `source` raises.
private func parseError(of source: String) -> ScenarioParseError? {
  do {
    _ = try parse(source)
    Issue.record("`\(source)` parsed without an error")
  } catch let error as ScenarioParseError {
    return error
  } catch {
    Issue.record(error, "`\(source)` raised a different error")
  }
  return nil
}

/// The text of the parse error `source` raises, in the `FILE:LINE: error: message` form.
private func parseFailure(of source: String) -> String {
  parseError(of: source)?.description ?? ""
}

/// The failure text of each source, one per line, for tests that check a family of inputs.
private func parseFailures(of sources: [String]) -> String {
  sources.map(parseFailure(of:)).joined(separator: "\n")
}

struct ScenarioParserTests {
  @Test
  func `header statements bind before the first body statement`() throws {
    let scenario = try parse(
      """
      # comment
      app stack
      size mobile
      term colors=16 theme=light
      type "hi there"  # trailing comment
      """
    )

    assertInlineSnapshot(of: scenario, as: .customDump) {
      """
      Scenario(
        app: "stack",
        appLine: SourceLine(
          number: 2,
          text: "app stack"
        ),
        viewport: .mobile,
        sizeLine: SourceLine(
          number: 3,
          text: "size mobile"
        ),
        terminal: TerminalProfile(
          colors: .ansi16,
          theme: .light
        ),
        lines: [
          [0]: ScenarioLine(
            number: 5,
            source: #"type "hi there"  # trailing comment"#,
            statement: .type("hi there")
          )
        ]
      )
      """
    }
  }

  @Test
  func `a scenario without a term header runs on plain cells with unknown colours`()
    throws
  {
    let scenario = try parse("app stack")

    assertInlineSnapshot(of: scenario, as: .customDump) {
      """
      Scenario(
        app: "stack",
        appLine: SourceLine(
          number: 1,
          text: "app stack"
        ),
        viewport: .desktop,
        sizeLine: nil,
        terminal: TerminalProfile(
          colors: .none,
          theme: nil
        ),
        lines: []
      )
      """
    }
  }

  @Test
  func `a scenario without an app header is a parse error naming the accepted apps`() {
    assertInlineSnapshot(of: parseFailure(of: "size desktop\nkey Tab"), as: .lines) {
      """
      t.scn:1: error: a scenario names its app with an `app NAME` header; accepted: stack, workspace, greedy, event-log, counter
      """
    }
  }

  @Test
  func `an app the registry does not hold is a parse error`() {
    assertInlineSnapshot(of: parseFailure(of: "app missing"), as: .lines) {
      """
      t.scn:1: error: unknown app `missing`; accepted: stack, workspace, greedy, event-log, counter
      """
    }
  }

  @Test
  func `size after a body statement names the resize verb`() {
    assertInlineSnapshot(of: parseError(of: "key Tab\nsize 10x10"), as: .customDump) {
      """
      ScenarioParseError(
        file: "t.scn",
        line: 2,
        source: "size 10x10",
        message: "`size` is a header statement; use `resize WxH` after the first body statement"
      )
      """
    }
  }

  @Test
  func `app and term after a body statement are header errors`() {
    let failures = parseFailures(
      of: ["app stack", "term colors=16"].map { "app stack\nkey Tab\n\($0)" })

    assertInlineSnapshot(of: failures, as: .lines) {
      """
      t.scn:3: error: `app` is a header statement and must precede the first body statement
      t.scn:3: error: `term` is a header statement and must precede the first body statement
      """
    }
  }

  @Test
  func `unknown statements list the accepted vocabulary`() {
    assertInlineSnapshot(of: parseFailure(of: "app stack\njump 3"), as: .lines) {
      """
      t.scn:2: error: unknown statement `jump`; accepted: app, size, term, resize, key, type, paste, bytes, shot, tree, dump, check, expect text, expect screen, expect node, expect cost
      """
    }
  }

  @Test
  func `unknown expectations list the accepted kinds`() {
    assertInlineSnapshot(of: parseFailure(of: "app stack\nexpect colour red"), as: .lines)
    {
      """
      t.scn:2: error: unknown expectation `colour`; accepted: text, screen, node, cost
      """
    }

  }

  @Test
  func `every statement form the grammar defers is refused by name`() {
    let samples: [String: String] = [
      "wait": "wait",
      "settle": "settle",
      "focus": "focus role=button",
      "mouse": "mouse click 3,4",
      "hit": "hit 1,2",
      "expect cell": "expect cell 1,2 bold",
      "expect focused": "expect focused role=button",
      "expect wireframe": "expect wireframe docs/design/a.md 1",
      "expect node SEL visible": "expect node type=Text visible",
      "expect node SEL clipped": "expect node type=Text clipped",
      "expect node SEL count N": "expect node type=Text count 2",
      "shot NAME SEL": "shot a type=Text",
      "tree SEL": "tree type=Text",
      "term glyphs=": "term glyphs=ascii",
      "term keyboard=": "term keyboard=kitty",
      "term theme=probe": "term theme=probe",
    ]
    expectNoDifference(
      samples.keys.sorted(), ScenarioGrammar.notYetExpressible.map(\.form).sorted())

    let failures = parseFailures(
      of: samples.sorted { $0.key < $1.key }.map { "app stack\n" + $0.value })

    assertInlineSnapshot(of: failures, as: .lines) {
      """
      t.scn:2: error: `expect cell` is not yet expressible: it needs style and role assertions on cells. See the "Not yet expressible" table in Examples/Scenarios/README.md; accepted: app, size, term, resize, key, type, paste, bytes, shot, tree, dump, check, expect text, expect screen, expect node, expect cost
      t.scn:2: error: `expect focused` is not yet expressible: it needs focus tracking. See the "Not yet expressible" table in Examples/Scenarios/README.md; accepted: app, size, term, resize, key, type, paste, bytes, shot, tree, dump, check, expect text, expect screen, expect node, expect cost
      t.scn:2: error: `expect node SEL clipped` is not yet expressible: it needs the visibility rules of focus tooling. See the "Not yet expressible" table in Examples/Scenarios/README.md; accepted: app, size, term, resize, key, type, paste, bytes, shot, tree, dump, check, expect text, expect screen, expect node, expect cost
      t.scn:2: error: `expect node SEL count N` is not yet expressible: it needs a later release of the locator language. See the "Not yet expressible" table in Examples/Scenarios/README.md; accepted: app, size, term, resize, key, type, paste, bytes, shot, tree, dump, check, expect text, expect screen, expect node, expect cost
      t.scn:2: error: `expect node SEL visible` is not yet expressible: it needs the visibility rules of focus tooling. See the "Not yet expressible" table in Examples/Scenarios/README.md; accepted: app, size, term, resize, key, type, paste, bytes, shot, tree, dump, check, expect text, expect screen, expect node, expect cost
      t.scn:2: error: `expect wireframe` is not yet expressible: it needs catalog conformance. See the "Not yet expressible" table in Examples/Scenarios/README.md; accepted: app, size, term, resize, key, type, paste, bytes, shot, tree, dump, check, expect text, expect screen, expect node, expect cost
      t.scn:2: error: `focus` is not yet expressible: it needs focus tracking and role and label locators. See the "Not yet expressible" table in Examples/Scenarios/README.md; accepted: app, size, term, resize, key, type, paste, bytes, shot, tree, dump, check, expect text, expect screen, expect node, expect cost
      t.scn:2: error: `hit` is not yet expressible: it needs pointer input and hit testing. See the "Not yet expressible" table in Examples/Scenarios/README.md; accepted: app, size, term, resize, key, type, paste, bytes, shot, tree, dump, check, expect text, expect screen, expect node, expect cost
      t.scn:2: error: `mouse` is not yet expressible: it needs pointer input and hit testing. See the "Not yet expressible" table in Examples/Scenarios/README.md; accepted: app, size, term, resize, key, type, paste, bytes, shot, tree, dump, check, expect text, expect screen, expect node, expect cost
      t.scn:2: error: `settle` is not yet expressible: it needs the schedulable clock. See the "Not yet expressible" table in Examples/Scenarios/README.md; accepted: app, size, term, resize, key, type, paste, bytes, shot, tree, dump, check, expect text, expect screen, expect node, expect cost
      t.scn:2: error: `shot NAME SEL` is not yet expressible: it needs region shots, with catalog conformance. See the "Not yet expressible" table in Examples/Scenarios/README.md; accepted: app, size, term, resize, key, type, paste, bytes, shot, tree, dump, check, expect text, expect screen, expect node, expect cost
      t.scn:2: error: `term glyphs=` is not yet expressible: it needs ASCII glyph fallbacks in the views. See the "Not yet expressible" table in Examples/Scenarios/README.md; accepted: app, size, term, resize, key, type, paste, bytes, shot, tree, dump, check, expect text, expect screen, expect node, expect cost
      t.scn:2: error: `term keyboard=` is not yet expressible: it needs key routing that depends on the protocol. See the "Not yet expressible" table in Examples/Scenarios/README.md; accepted: app, size, term, resize, key, type, paste, bytes, shot, tree, dump, check, expect text, expect screen, expect node, expect cost
      t.scn:2: error: `term theme=probe` is not yet expressible: it needs semantic roles. See the "Not yet expressible" table in Examples/Scenarios/README.md; accepted: app, size, term, resize, key, type, paste, bytes, shot, tree, dump, check, expect text, expect screen, expect node, expect cost
      t.scn:2: error: `tree SEL` is not yet expressible: it needs a later release of the locator language. See the "Not yet expressible" table in Examples/Scenarios/README.md; accepted: app, size, term, resize, key, type, paste, bytes, shot, tree, dump, check, expect text, expect screen, expect node, expect cost
      t.scn:2: error: `wait` is not yet expressible: it needs the schedulable clock. See the "Not yet expressible" table in Examples/Scenarios/README.md; accepted: app, size, term, resize, key, type, paste, bytes, shot, tree, dump, check, expect text, expect screen, expect node, expect cost
      """
    }
  }

  @Test
  func
    `the README's not-yet-expressible table lists exactly the forms the parser refuses`()
    throws
  {
    let readme = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("Examples/Scenarios/README.md")
    let text = try String(contentsOf: readme, encoding: .utf8)
    // Lines split at the `\n` scalar, as the parser's are: a Windows checkout of this file may
    // have CRLF endings, and a "\r\n" is one Character that Foundation's search would not see
    // a "\n" in.
    let lines = ScenarioParser.sourceLines(of: text)
    let start = try #require(lines.firstIndex { $0.hasPrefix("## Not yet expressible") })
    let section = lines[(start + 1)...].prefix { !$0.hasPrefix("## ") }

    // Each row is `| `FORM` | NEEDS |`: the form and what it waits for must both match.
    func deferred(_ line: String) -> ScenarioGrammar.Deferred {
      let cells = line.split(separator: "|", omittingEmptySubsequences: true)
      let form = cells[0].trimmingCharacters(in: .whitespaces).dropFirst().dropLast()
      return ScenarioGrammar.Deferred(
        form: String(form), needs: cells[1].trimmingCharacters(in: .whitespaces))
    }
    let rows = section.filter { $0.hasPrefix("| `") }.map(deferred)

    expectNoDifference(
      rows.sorted { $0.form < $1.form },
      ScenarioGrammar.notYetExpressible.sorted { $0.form < $1.form })
  }

  @Test
  func `unknown key names list the accepted set`() {
    assertInlineSnapshot(of: parseFailure(of: "app stack\nkey Hyperspace"), as: .lines) {
      """
      t.scn:2: error: unknown key `Hyperspace`; accepted: ArrowDown, ArrowLeft, ArrowRight, ArrowUp, Backspace, Delete, End, Enter, Escape, Home, PageDown, PageUp, Space, Tab, F1, F2, F3, F4, F5, F6, F7, F8, F9, F10, F11, F12, a single character; modifiers: Alt, Control, Ctrl, Meta, Shift, Super joined with `+`
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
  func `frame expectations accept one token or the two-token form`() throws {
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
    assertInlineSnapshot(of: parseFailure(of: "app stack\n\ntype \"oops"), as: .lines) {
      """
      t.scn:3: error: unterminated double quote
      """
    }
  }

  @Test
  func `duplicate shot names are rejected, naming the first line`() {
    assertInlineSnapshot(of: parseFailure(of: "app stack\nshot a\nshot a"), as: .lines) {
      """
      t.scn:3: error: duplicate shot name `a` (first used on line 2)
      """
    }
  }

  @Test
  func `shot names that differ only by case collide, because goldens are files`() {
    assertInlineSnapshot(
      of: parseError(of: "app stack\nshot a\ntype \"+\"\nshot A"), as: .customDump
    ) {
      """
      ScenarioParseError(
        file: "t.scn",
        line: 4,
        source: "shot A",
        message: "shot name `A` collides with `a` on line 2: goldens are files, and the file systems CI runs on fold case"
      )
      """
    }
  }

  @Test
  func `a CRLF file parses as an LF file does, with the same line numbers`() throws {
    let lf = "# header\napp stack\nsize 40x10\ntype \"hi\"\nexpect text 0 \"x\"\n"
    let crlf = lf.replacingOccurrences(of: "\n", with: "\r\n")

    let fromLF = try parse(lf)
    let fromCRLF = try parse(crlf)

    expectNoDifference(fromCRLF, fromLF)
    assertInlineSnapshot(of: fromCRLF.lines, as: .customDump) {
      """
      [
        [0]: ScenarioLine(
          number: 4,
          source: #"type "hi""#,
          statement: .type("hi")
        ),
        [1]: ScenarioLine(
          number: 5,
          source: #"expect text 0 "x""#,
          statement: .expectText(
            row: 0,
            text: "x"
          )
        )
      ]
      """
    }
  }

  @Test
  func `a parse error in a CRLF file reports the right line`() {
    assertInlineSnapshot(
      of: parseError(of: "app stack\r\nsize 40x10\r\nblink\r\n"), as: .customDump
    ) {
      """
      ScenarioParseError(
        file: "t.scn",
        line: 3,
        source: "blink",
        message: "unknown statement `blink`; accepted: app, size, term, resize, key, type, paste, bytes, shot, tree, dump, check, expect text, expect screen, expect node, expect cost"
      )
      """
    }
  }

  @Test
  func `bytes, hex escapes, and paste carry their text`() throws {
    let scenario = try parse(
      #"""
      app stack
      bytes "\x1b[A"
      paste "a b\nc"
      type "A\x42"
      """#
    )

    expectNoDifference(
      scenario.lines.map(\.statement),
      [.bytes([0x1B, 0x5B, 0x41]), .paste("a b\nc"), .type("AB")]
    )
  }

  @Test
  func `bad escapes name what is accepted`() {
    let lines = [#"type "\x1""#, #"type "\xZZ""#, #"type "\x80""#, #"type "\q""#]

    assertInlineSnapshot(
      of: parseFailures(of: lines.map { "app stack\n" + $0 }), as: .lines
    ) {
      #"""
      t.scn:2: error: `\x` needs two hex digits, as in `\x1b`
      t.scn:2: error: `\x` needs two hex digits, as in `\x1b`
      t.scn:2: error: `\x` escapes are ASCII (00 to 7f); write a non-ASCII character itself
      t.scn:2: error: unknown escape `\q`; accepted: \n \t \" \\ \xHH
      """#
    }
  }

  @Test
  func `expect screen reads its rows up to the delimiter line`() throws {
    let scenario = try parse(
      """
      app stack
      expect screen <<END
      Stack demo
        # not a comment

      last   \u{20}
      END
      key Tab
      """
    )

    assertInlineSnapshot(of: scenario.lines, as: .customDump) {
      """
      [
        [0]: ScenarioLine(
          number: 2,
          source: "expect screen <<END",
          statement: .expectScreen(
            rows: [
              [0]: "Stack demo",
              [1]: "  # not a comment",
              [2]: "",
              [3]: "last    "
            ]
          )
        ),
        [1]: ScenarioLine(
          number: 8,
          source: "key Tab",
          statement: .key(
            Key(
              code: .tab,
              modifiers: Modifiers(rawValue: 0),
              kind: .press,
              shiftedCode: nil,
              baseLayoutCode: nil,
              associatedText: nil
            )
          )
        )
      ]
      """
    }
  }

  @Test
  func `expect screen strips the carriage returns of a CRLF file`() throws {
    let scenario = try parse("app stack\r\nexpect screen <<EOF\r\na\r\nb\r\nEOF\r\n")

    expectNoDifference(
      scenario.lines.map(\.statement), [.expectScreen(rows: ["a", "b"])])
  }

  @Test
  func `expect screen without its closing line fails at the statement`() {
    assertInlineSnapshot(
      of: parseFailure(of: "app stack\nexpect screen <<EOF\nrow\n"), as: .lines
    ) {
      """
      t.scn:2: error: `expect screen` is missing its closing `EOF` line
      """
    }
  }

  @Test
  func `the closing line of expect screen may carry trailing spaces or tabs`() throws {
    let closers = ["EOF ", "EOF\t", "EOF \t ", "EOF\r"]

    let parsed = try closers.map {
      try parse("app stack\nexpect screen <<EOF\nrow\n\($0)\nkey Tab").lines
    }

    let expected = try #require(parsed.first)
    expectNoDifference(parsed, Array(repeating: expected, count: closers.count))
    assertInlineSnapshot(of: expected, as: .customDump) {
      """
      [
        [0]: ScenarioLine(
          number: 2,
          source: "expect screen <<EOF",
          statement: .expectScreen(
            rows: [
              [0]: "row"
            ]
          )
        ),
        [1]: ScenarioLine(
          number: 5,
          source: "key Tab",
          statement: .key(
            Key(
              code: .tab,
              modifiers: Modifiers(rawValue: 0),
              kind: .press,
              shiftedCode: nil,
              baseLayoutCode: nil,
              associatedText: nil
            )
          )
        )
      ]
      """
    }
  }

  @Test
  func `a closing line with leading blanks or other text is still a row`() {
    let failures = parseFailures(
      of: [" EOF", "EOF.", "EOFX"].map { "app stack\nexpect screen <<EOF\nrow\n\($0)\n" })

    assertInlineSnapshot(of: failures, as: .lines) {
      """
      t.scn:2: error: `expect screen` is missing its closing `EOF` line
      t.scn:2: error: `expect screen` is missing its closing `EOF` line
      t.scn:2: error: `expect screen` is missing its closing `EOF` line
      """
    }
  }

  @Test
  func `expect screen needs a heredoc delimiter`() {
    let lines = [
      "expect screen", "expect screen EOF", "expect screen <<", "expect screen <<a-b",
    ]

    assertInlineSnapshot(
      of: parseFailures(of: lines.map { "app stack\n" + $0 }), as: .lines
    ) {
      """
      t.scn:2: error: usage: expect screen <<EOF, then the rows, then a line holding only EOF
      t.scn:2: error: usage: expect screen <<EOF, then the rows, then a line holding only EOF
      t.scn:2: error: usage: expect screen <<EOF, then the rows, then a line holding only EOF
      t.scn:2: error: the delimiter after `<<` is letters, digits, and `_`, got `a-b`
      """
    }
  }

  @Test
  func `term options validate their values and name the accepted ones`() {
    let lines = [
      "term colors=blue", "term theme=sepia", "term colors", "term colors=16 colors=256",
      "term width=3",
    ]

    assertInlineSnapshot(
      of: parseFailures(of: lines.map { "app stack\n" + $0 }), as: .lines
    ) {
      """
      t.scn:2: error: bad colors `blue`; expected none, 16, 256, true
      t.scn:2: error: bad theme `sepia`; expected light, dark
      t.scn:2: error: term option `colors` is not key=value; accepted keys: colors, theme
      t.scn:2: error: duplicate `term` option `colors`
      t.scn:2: error: unknown term option `width`; accepted keys: colors, theme
      """
    }
  }

  @Test
  func `a second term or size or app header is an error`() {
    let failures = parseFailures(
      of: ["term colors=16", "size desktop", "app stack"].map {
        "app stack\n\($0)\n\($0)"
      })

    assertInlineSnapshot(of: failures, as: .lines) {
      """
      t.scn:3: error: duplicate `term` header
      t.scn:3: error: duplicate `size` header
      t.scn:2: error: duplicate `app` header
      """
    }
  }
}

@MainActor
struct ScenarioPlayerTests {
  private func run(
    _ source: String, registry: ApplicationRegistry = Fixtures.registry()
  ) async throws -> ScenarioReport {
    let scenario = try parse(source)
    return await ScenarioPlayer.run(scenario, name: "t.scn", registry: registry)
  }

  @Test
  func `a wrong row expectation reports expected actual and the screen`() async throws {
    let report = try await run("app stack\nsize 40x10\nexpect text 0 \"Stack demos\"")

    assertInlineSnapshot(of: report, as: .customDump) {
      """
      ScenarioReport(
        scenario: "t.scn",
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
            ],
            rule: nil,
            node: nil
          )
        ],
        observations: [],
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
              size: "40x10",
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
                [3]: "root/index(0)/index(1)",
                [4]: "root/index(0)/index(2)",
                [5]: "root/index(0)/index(2)/index(0)",
                [6]: "root/index(0)/index(2)/index(1)",
                [7]: "root/index(0)/index(3)",
                [8]: "root/index(0)/index(3)/index(0)",
                [9]: "root/index(0)/index(3)/index(1)",
                [10]: "root/index(0)/index(3)/index(2)",
                [11]: "root/index(0)/index(4)",
                [12]: "root/index(0)/index(5)"
              ],
              changed: [],
              removed: []
            ),
            rows: [
              [0]: 0,
              [1]: 1,
              [2]: 2,
              [3]: 3,
              [4]: 4,
              [5]: 5
            ],
            cost: StepCost(
              bodies: 0,
              bytes: 639,
              measures: 65,
              placements: 13,
              renders: 8
            )
          )
        ]
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

    assertInlineSnapshot(of: report.description, as: .lines) {
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

    assertInlineSnapshot(of: report.description, as: .lines) {
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

    assertInlineSnapshot(of: report.description, as: .lines) {
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

    expectNoDifference(report.failures, [])
  }

  @Test
  func `mobile fails for an app that fills its proposal and names mobileScreen`()
    async throws
  {
    let report = try await run("app greedy\nsize mobile\nshot a")

    assertInlineSnapshot(of: report, as: .customDump) {
      """
      ScenarioReport(
        scenario: "t.scn",
        failures: [
          [0]: ScenarioFailure(
            line: 2,
            statement: "size mobile",
            verb: "size",
            message: "`greedy` has no natural height: it measured 500 rows when offered 500 and 1000 when offered 1000. Use `size mobileScreen` (40x16) or an explicit WxH",
            expected: nil,
            actual: nil,
            screen: nil,
            rule: nil,
            node: nil
          )
        ],
        observations: [],
        recorded: [],
        seconds: [],
        trace: []
      )
      """
    }
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
        failures: [
          [0]: ScenarioFailure(
            line: 2,
            statement: "size mobile",
            verb: "size",
            message: "`workspace` has no natural height: it measured 500 rows when offered 500 and 1000 when offered 1000. Use `size mobileScreen` (40x16) or an explicit WxH",
            expected: nil,
            actual: nil,
            screen: nil,
            rule: nil,
            node: nil
          )
        ],
        observations: [],
        recorded: [],
        seconds: [],
        trace: []
      )
      """
    }
  }

  @Test
  func `mobileScreen runs a greedy app at 40x16`() async throws {
    let report = try await run(
      "app greedy\nsize mobileScreen\nexpect node id=root frame 0,0,40x16")

    expectNoDifference(report.failures, [])
  }

  @Test
  func `bytes parse into keys, a bare escape, and a bracketed paste`() async throws {
    let report = try await run(
      #"""
      app event-log
      size 30x8
      bytes "\x1b[B"
      bytes "\x1b[1;5C"
      bytes "\x1b"
      bytes "\x1b[200~x y\x1b[201~"
      expect screen <<EOF
      resize 30x8
      key ArrowDown
      key Ctrl+ArrowRight
      key Escape
      paste x y
      EOF
      """#
    )

    expectNoDifference(report.failures, [])
  }

  @Test
  func `key, type, and paste reach the app as the events they name`() async throws {
    let report = try await run(
      """
      app event-log
      size 30x8
      key Shift+Tab
      type "ab"
      paste "a b"
      expect screen <<EOF
      resize 30x8
      key Shift+Tab
      key a
      key b
      paste a b
      EOF
      """
    )

    expectNoDifference(report.failures, [])
  }

  @Test
  func `expect screen compares trimmed rows and ignores trailing empty rows`()
    async throws
  {
    let report = try await run(
      """
      app stack
      size 40x10
      expect screen <<EOF
      Stack demo
      ────────────────────────────────────────
      Name: -
      left                               right
      ────────────────────────────────────────
      40 columns
      EOF
      """
    )

    expectNoDifference(report.failures, [])
  }

  @Test
  func `a wrong expect screen names the first differing row`() async throws {
    let report = try await run(
      """
      app stack
      size 40x10
      expect screen <<EOF
      Stack demo
      ────────────────────────────────────────
      Name: nobody
      EOF
      """
    )

    assertInlineSnapshot(of: report.description, as: .lines) {
      """
      FAIL t.scn
        line 3: expect screen <<EOF
          screen differs at row 2: expected 3 rows, the screen has 6
          expected: Name: nobody
          actual:   Name: -
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
  func `a shot only observes when no goldens are attached`() async throws {
    let report = try await run("app stack\nsize 40x10\nshot first")

    assertInlineSnapshot(of: report, as: .customDump) {
      """
      ScenarioReport(
        scenario: "t.scn",
        failures: [],
        observations: [
          [0]: ScenarioObservation(
            line: 3,
            verb: "shot",
            name: "first",
            lines: [
              [0]: "Stack demo",
              [1]: "────────────────────────────────────────",
              [2]: "Name: -",
              [3]: "left                               right",
              [4]: "────────────────────────────────────────",
              [5]: "40 columns"
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
              size: "40x10",
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
                [3]: "root/index(0)/index(1)",
                [4]: "root/index(0)/index(2)",
                [5]: "root/index(0)/index(2)/index(0)",
                [6]: "root/index(0)/index(2)/index(1)",
                [7]: "root/index(0)/index(3)",
                [8]: "root/index(0)/index(3)/index(0)",
                [9]: "root/index(0)/index(3)/index(1)",
                [10]: "root/index(0)/index(3)/index(2)",
                [11]: "root/index(0)/index(4)",
                [12]: "root/index(0)/index(5)"
              ],
              changed: [],
              removed: []
            ),
            rows: [
              [0]: 0,
              [1]: 1,
              [2]: 2,
              [3]: 3,
              [4]: 4,
              [5]: 5
            ],
            cost: StepCost(
              bodies: 0,
              bytes: 639,
              measures: 65,
              placements: 13,
              renders: 8
            )
          )
        ]
      )
      """
    }
  }

  @Test
  func `a duplicate-name registry fails the player with the harness verb`() async throws {
    var registry = Fixtures.registry()
    registry.register("stack", viewports: [.desktop]) { StackApp() }

    let report = try await run("app stack", registry: registry)

    assertInlineSnapshot(of: report, as: .customDump) {
      """
      ScenarioReport(
        scenario: "t.scn",
        failures: [
          [0]: ScenarioFailure(
            line: 1,
            statement: "app stack",
            verb: "harness",
            message: "applications registered more than once: `stack`",
            expected: nil,
            actual: nil,
            screen: nil,
            rule: nil,
            node: nil
          )
        ],
        observations: [],
        recorded: [],
        seconds: [],
        trace: []
      )
      """
    }
  }

  @Test
  func `a statement after the app finishes fails and names the line that finished it`()
    async throws
  {
    let report = try await run(
      """
      app counter
      key q
      expect text 0 "Count: 0"
      shot after
      """
    )

    assertInlineSnapshot(of: report, as: .customDump) {
      """
      ScenarioReport(
        scenario: "t.scn",
        failures: [
          [0]: ScenarioFailure(
            line: 3,
            statement: #"expect text 0 "Count: 0""#,
            verb: "expect text",
            message: "the application finished at line 2 (`key q`), and in a terminal nothing after it runs",
            expected: nil,
            actual: nil,
            screen: nil,
            rule: nil,
            node: nil
          )
        ],
        observations: [],
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
              [0]: "layoutViewChanged",
              [1]: "renderRequested",
              [2]: "renderViewChanged",
              [3]: "updateRequested"
            ],
            nodes: TraceRecord.NodeChanges(
              added: [
                [0]: "root",
                [1]: "root/index(0)"
              ],
              changed: [],
              removed: []
            ),
            rows: [
              [0]: 0
            ],
            cost: StepCost(
              bodies: 0,
              bytes: 2097,
              measures: 2,
              placements: 2,
              renders: 1
            )
          ),
          [1]: TraceRecord(
            version: 1,
            seq: 1,
            event: TraceEvent(
              type: "key",
              key: "q",
              kind: nil,
              text: nil,
              size: nil,
              detail: nil
            ),
            drew: true,
            reasons: [
              [0]: "layoutViewChanged",
              [1]: "renderRequested",
              [2]: "renderViewChanged",
              [3]: "updateRequested"
            ],
            nodes: TraceRecord.NodeChanges(
              added: [],
              changed: [],
              removed: []
            ),
            rows: [],
            cost: StepCost(
              bodies: 0,
              bytes: 10,
              measures: 2,
              placements: 2,
              renders: 1
            )
          )
        ]
      )
      """
    }
  }

  @Test
  func `the statement that finishes the app is the last that runs, and passes`()
    async throws
  {
    let report = try await run(
      "app counter\ntype \"+\"\nexpect text 0 \"Count: 1\"\nkey q")

    expectNoDifference(report.failures, [])
  }

  @Test
  func `a finished app gets no more input from the statement that finished it`()
    async throws
  {
    var registry = Fixtures.registry()
    registry.register("quitter", viewports: [.desktop]) { QuitterApp() }
    Delivered.characters = []

    let scenario = try ScenarioParser.parse(
      "app quitter\ntype \"abqcd\"\ntype \"e\"", file: "t.scn", knownApps: ["quitter"])
    let report = await ScenarioPlayer.run(scenario, name: "t.scn", registry: registry)

    expectNoDifference(Delivered.characters, ["a", "b", "q"])
    assertInlineSnapshot(of: report, as: .customDump) {
      """
      ScenarioReport(
        scenario: "t.scn",
        failures: [
          [0]: ScenarioFailure(
            line: 3,
            statement: #"type "e""#,
            verb: "type",
            message: #"the application finished at line 2 (`type "abqcd"`), and in a terminal nothing after it runs"#,
            expected: nil,
            actual: nil,
            screen: nil,
            rule: nil,
            node: nil
          )
        ],
        observations: [],
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
              [0]: "layoutViewChanged",
              [1]: "renderRequested",
              [2]: "renderViewChanged",
              [3]: "updateRequested"
            ],
            nodes: TraceRecord.NodeChanges(
              added: [
                [0]: "root",
                [1]: "root/index(0)"
              ],
              changed: [],
              removed: []
            ),
            rows: [
              [0]: 0
            ],
            cost: StepCost(
              bodies: 0,
              bytes: 2097,
              measures: 2,
              placements: 2,
              renders: 1
            )
          ),
          [1]: TraceRecord(
            version: 1,
            seq: 1,
            event: TraceEvent(
              type: "key",
              key: "a",
              kind: nil,
              text: nil,
              size: nil,
              detail: nil
            ),
            drew: true,
            reasons: [
              [0]: "layoutViewChanged",
              [1]: "renderRequested",
              [2]: "renderViewChanged",
              [3]: "updateRequested"
            ],
            nodes: TraceRecord.NodeChanges(
              added: [],
              changed: [],
              removed: []
            ),
            rows: [],
            cost: StepCost(
              bodies: 0,
              bytes: 10,
              measures: 2,
              placements: 2,
              renders: 1
            )
          ),
          [2]: TraceRecord(
            version: 1,
            seq: 2,
            event: TraceEvent(
              type: "key",
              key: "b",
              kind: nil,
              text: nil,
              size: nil,
              detail: nil
            ),
            drew: true,
            reasons: [
              [0]: "layoutViewChanged",
              [1]: "renderRequested",
              [2]: "renderViewChanged",
              [3]: "updateRequested"
            ],
            nodes: TraceRecord.NodeChanges(
              added: [],
              changed: [],
              removed: []
            ),
            rows: [],
            cost: StepCost(
              bodies: 0,
              bytes: 10,
              measures: 2,
              placements: 2,
              renders: 1
            )
          ),
          [3]: TraceRecord(
            version: 1,
            seq: 3,
            event: TraceEvent(
              type: "key",
              key: "q",
              kind: nil,
              text: nil,
              size: nil,
              detail: nil
            ),
            drew: true,
            reasons: [
              [0]: "layoutViewChanged",
              [1]: "renderRequested",
              [2]: "renderViewChanged",
              [3]: "updateRequested"
            ],
            nodes: TraceRecord.NodeChanges(
              added: [],
              changed: [],
              removed: []
            ),
            rows: [],
            cost: StepCost(
              bodies: 0,
              bytes: 10,
              measures: 2,
              placements: 2,
              renders: 1
            )
          )
        ]
      )
      """
    }
  }

  @Test
  func `an app that is finished before the scenario starts fails its first statement`()
    async throws
  {
    var registry = Fixtures.registry()
    registry.register("done", viewports: [.desktop]) { FinishedApp() }

    let scenario = try ScenarioParser.parse(
      "app done\nexpect text 0 \"Finished\"\nkey Tab", file: "t.scn", knownApps: ["done"])
    let report = await ScenarioPlayer.run(scenario, name: "t.scn", registry: registry)

    assertInlineSnapshot(of: report, as: .customDump) {
      """
      ScenarioReport(
        scenario: "t.scn",
        failures: [
          [0]: ScenarioFailure(
            line: 2,
            statement: #"expect text 0 "Finished""#,
            verb: "expect text",
            message: "the application had already finished when the scenario started, and in a terminal nothing after it runs",
            expected: nil,
            actual: nil,
            screen: nil,
            rule: nil,
            node: nil
          )
        ],
        observations: [],
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
              [0]: "layoutViewChanged",
              [1]: "renderRequested",
              [2]: "renderViewChanged",
              [3]: "updateRequested"
            ],
            nodes: TraceRecord.NodeChanges(
              added: [
                [0]: "root",
                [1]: "root/index(0)"
              ],
              changed: [],
              removed: []
            ),
            rows: [
              [0]: 0
            ],
            cost: StepCost(
              bodies: 0,
              bytes: 2097,
              measures: 2,
              placements: 2,
              renders: 1
            )
          )
        ]
      )
      """
    }
  }

  @Test
  func `natural height is the root's measured rows when no height is proposed`() {
    let stack = NaturalHeight.measure(StackApp(), columns: 40)
    let workspace = NaturalHeight.measure(WorkspaceApp(), columns: 40)
    let greedy = NaturalHeight.measure(GreedyApp(), columns: 40)

    assertInlineSnapshot(of: [stack, workspace, greedy], as: .customDump) {
      """
      [
        [0]: NaturalHeight(
          rows: 6,
          shortRows: 6,
          tallRows: 6
        ),
        [1]: NaturalHeight(
          rows: 34,
          shortRows: 500,
          tallRows: 1000
        ),
        [2]: NaturalHeight(
          rows: 2,
          shortRows: 500,
          tallRows: 1000
        )
      ]
      """
    }
  }
}
