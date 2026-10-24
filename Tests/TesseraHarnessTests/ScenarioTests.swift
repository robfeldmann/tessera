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
      term colors=16 theme=light
      type "hi there"  # trailing comment
      """
    )

    #expect(scenario.app == "stack")
    #expect(scenario.appLine == SourceLine(number: 2, text: "app stack"))
    #expect(scenario.viewport == .mobile)
    #expect(scenario.sizeLine == SourceLine(number: 3, text: "size mobile"))
    #expect(scenario.terminal == TerminalProfile(colors: .ansi16, theme: .light))
    #expect(scenario.lines.map(\.statement) == [.type("hi there")])
    #expect(scenario.lines.first?.number == 5)
  }

  @Test
  func `a scenario without a term header runs on plain cells with unknown colours`()
    throws
  {
    let scenario = try parse("app stack")

    #expect(scenario.terminal == TerminalProfile(colors: .none, theme: nil))
    #expect(scenario.viewport == .desktop)
    #expect(scenario.sizeLine == nil)
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
    #expect(error?.source == "size 10x10")
    #expect(error?.description.hasPrefix("t.scn:2: error: ") == true)
    #expect(error?.message.contains("resize") == true)
  }

  @Test
  func `app and term after a body statement are header errors`() {
    for header in ["app stack", "term colors=16"] {
      let error = #expect(throws: ScenarioParseError.self) {
        try parse("app stack\nkey Tab\n\(header)")
      }

      #expect(error?.line == 3, "\(header)")
      #expect(error?.message.contains("must precede the first body statement") == true)
    }
  }

  @Test
  func `unknown statements list the accepted vocabulary`() {
    let error = #expect(throws: ScenarioParseError.self) {
      try parse("app stack\njump 3")
    }

    #expect(error?.line == 2)
    #expect(error?.message.contains("unknown statement `jump`") == true)
    #expect(
      error?.message.contains("accepted: app, size, term, resize, key, type") == true)
  }

  @Test
  func `unknown expectations list the accepted kinds`() {
    let error = #expect(throws: ScenarioParseError.self) {
      try parse("app stack\nexpect colour red")
    }

    #expect(
      error?.message == "unknown expectation `colour`; accepted: text, screen, node")
  }

  @Test
  func `every statement form the grammar defers is refused by name`() throws {
    let samples: [String: String] = [
      "wait": "wait",
      "settle": "settle",
      "focus": "focus role=button",
      "mouse": "mouse click 3,4",
      "hit": "hit 1,2",
      "dump": "dump",
      "check": "check",
      "expect cell": "expect cell 1,2 bold",
      "expect cost": "expect cost bodies<=1",
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
    #expect(Set(samples.keys) == Set(ScenarioGrammar.notYetExpressible.map(\.form)))

    for (form, sample) in samples {
      let error = #expect(throws: ScenarioParseError.self) {
        try parse("app stack\n" + sample)
      }

      #expect(error?.line == 2, "\(form)")
      #expect(
        error?.message.hasPrefix("`\(form)` is not yet expressible: it needs ") == true,
        "\(form): \(error?.message ?? "no error")")
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

    let forms = section.filter { $0.hasPrefix("| `") }.map { line in
      String(line.dropFirst(3).prefix { $0 != "`" })
    }

    #expect(forms.sorted() == ScenarioGrammar.notYetExpressible.map(\.form).sorted())
  }

  @Test
  func `unknown key names list the accepted set`() {
    let error = #expect(throws: ScenarioParseError.self) {
      try parse("app stack\nkey Hyperspace")
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
  func `frame expectations accept one token or the two-token form`() throws {
    let scenario = try parse(
      "app stack\nexpect node id=root frame 1,2,3x4\nexpect node id=root frame 1,2 3x4"
    )

    #expect(scenario.lines[0].statement == scenario.lines[1].statement)
  }

  @Test
  func `unterminated quotes fail with the line number`() {
    let error = #expect(throws: ScenarioParseError.self) {
      try parse("app stack\n\ntype \"oops")
    }

    #expect(error?.line == 3)
  }

  @Test
  func `duplicate shot names are rejected, naming the first line`() {
    let error = #expect(throws: ScenarioParseError.self) {
      try parse("app stack\nshot a\nshot a")
    }

    #expect(error?.line == 3)
    #expect(error?.message == "duplicate shot name `a` (first used on line 2)")
  }

  @Test
  func `shot names that differ only by case collide, because goldens are files`() {
    let error = #expect(throws: ScenarioParseError.self) {
      try parse("app stack\nshot a\ntype \"+\"\nshot A")
    }

    #expect(error?.line == 4)
    #expect(error?.source == "shot A")
    #expect(
      error?.description.hasPrefix("t.scn:4: error: shot name `A` collides with `a`")
        == true)
    #expect(error?.message.contains("on line 2") == true)
    #expect(error?.message.contains("fold case") == true)
  }

  @Test
  func `a CRLF file parses as an LF file does, with the same line numbers`() throws {
    let lf = "# header\napp stack\nsize 40x10\ntype \"hi\"\nexpect text 0 \"x\"\n"
    let crlf = lf.replacingOccurrences(of: "\n", with: "\r\n")

    let fromLF = try parse(lf)
    let fromCRLF = try parse(crlf)

    #expect(fromCRLF == fromLF)
    #expect(fromCRLF.lines.map(\.number) == [4, 5])
    #expect(fromCRLF.lines.map(\.source) == ["type \"hi\"", "expect text 0 \"x\""])
  }

  @Test
  func `a parse error in a CRLF file reports the right line`() {
    let error = #expect(throws: ScenarioParseError.self) {
      try parse("app stack\r\nsize 40x10\r\nblink\r\n")
    }

    #expect(error?.line == 3)
    #expect(error?.source == "blink")
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

    #expect(
      scenario.lines.map(\.statement) == [
        .bytes([0x1B, 0x5B, 0x41]), .paste("a b\nc"), .type("AB"),
      ])
  }

  @Test
  func `bad escapes name what is accepted`() {
    let cases = [
      (#"type "\x1""#, "needs two hex digits"),
      (#"type "\xZZ""#, "needs two hex digits"),
      (#"type "\x80""#, "ASCII"),
      (#"type "\q""#, #"accepted: \n \t \" \\ \xHH"#),
    ]
    for (line, expected) in cases {
      let error = #expect(throws: ScenarioParseError.self) {
        try parse("app stack\n" + line)
      }

      #expect(
        error?.message.contains(expected) == true, "\(line): \(error?.message ?? "")")
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

    #expect(scenario.lines.count == 2)
    #expect(
      scenario.lines[0].statement
        == .expectScreen(rows: ["Stack demo", "  # not a comment", "", "last    "]))
    #expect(scenario.lines[0].number == 2)
    #expect(scenario.lines[0].source == "expect screen <<END")
    #expect(scenario.lines[1].number == 8)
  }

  @Test
  func `expect screen strips the carriage returns of a CRLF file`() throws {
    let scenario = try parse("app stack\r\nexpect screen <<EOF\r\na\r\nb\r\nEOF\r\n")

    #expect(scenario.lines[0].statement == .expectScreen(rows: ["a", "b"]))
  }

  @Test
  func `expect screen without its closing line fails at the statement`() {
    let error = #expect(throws: ScenarioParseError.self) {
      try parse("app stack\nexpect screen <<EOF\nrow\n")
    }

    #expect(error?.line == 2)
    #expect(error?.message.contains("missing its closing `EOF` line") == true)
  }

  @Test
  func `the closing line of expect screen may carry trailing spaces or tabs`() throws {
    for closer in ["EOF ", "EOF\t", "EOF \t ", "EOF\r"] {
      let scenario = try parse("app stack\nexpect screen <<EOF\nrow\n\(closer)\nkey Tab")

      #expect(scenario.lines.map(\.number) == [2, 5], "\(closer.debugDescription)")
      #expect(scenario.lines[0].statement == .expectScreen(rows: ["row"]))
    }
  }

  @Test
  func `a closing line with leading blanks or other text is still a row`() {
    for closer in [" EOF", "EOF.", "EOFX"] {
      let error = #expect(throws: ScenarioParseError.self) {
        try parse("app stack\nexpect screen <<EOF\nrow\n\(closer)\n")
      }

      #expect(
        error?.message.contains("missing its closing `EOF` line") == true, "\(closer)")
    }
  }

  @Test
  func `expect screen needs a heredoc delimiter`() {
    for line in [
      "expect screen", "expect screen EOF", "expect screen <<", "expect screen <<a-b",
    ] {
      #expect(throws: ScenarioParseError.self, "\(line)") {
        try parse("app stack\n" + line)
      }
    }
  }

  @Test
  func `term options validate their values and name the accepted ones`() {
    let cases = [
      ("term colors=blue", "bad colors `blue`; expected none, 16, 256, true"),
      ("term theme=sepia", "bad theme `sepia`; expected light, dark"),
      ("term colors", "is not key=value"),
      ("term colors=16 colors=256", "duplicate `term` option `colors`"),
      ("term width=3", "unknown term option `width`"),
    ]
    for (line, expected) in cases {
      let error = #expect(throws: ScenarioParseError.self) {
        try parse("app stack\n" + line)
      }

      #expect(
        error?.message.contains(expected) == true, "\(line): \(error?.message ?? "")")
    }
  }

  @Test
  func `a second term or size or app header is an error`() {
    for header in ["term colors=16", "size desktop", "app stack"] {
      let error = #expect(throws: ScenarioParseError.self) {
        try parse("app stack\n\(header)\n\(header)")
      }

      #expect(error?.message.contains("duplicate") == true, "\(header)")
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

    #expect(report.passed == false)
    let failure = try #require(report.failures.first)
    #expect(failure.verb == "expect text")
    #expect(failure.line == 3)
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
    #expect(failure.line == 2)
    #expect(failure.statement == "size mobile")
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

    #expect(report.passed, "\(report)")
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

    #expect(report.passed, "\(report)")
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

    #expect(report.passed, "\(report)")
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

    let failure = try #require(report.failures.first)
    #expect(failure.verb == "expect screen")
    #expect(failure.line == 3)
    #expect(failure.expected == "Name: nobody")
    #expect(failure.actual == "Name: -")
    #expect(failure.message.hasPrefix("screen differs at row 2"))
    #expect(failure.screen?.count == 6)
  }

  @Test
  func `a shot only observes when no goldens are attached`() async throws {
    let report = try await run("app stack\nsize 40x10\nshot first")

    #expect(report.passed)
    #expect(report.observations.map(\.name) == ["first"])
    #expect(report.observations.first?.lines.first == "Stack demo")
  }

  @Test
  func `a duplicate-name registry fails the player with the harness verb`() async throws {
    var registry = Fixtures.registry()
    registry.register("stack", viewports: [.desktop]) { StackApp() }

    let report = try await run("app stack", registry: registry)

    #expect(report.failures.first?.verb == "harness")
    #expect(report.failures.first?.line == 1)
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

    #expect(report.failures.count == 1)
    let failure = try #require(report.failures.first)
    #expect(failure.line == 3)
    #expect(failure.verb == "expect text")
    #expect(failure.message.hasPrefix("the application finished at line 2 (`key q`)"))
    #expect(failure.message.contains("nothing after it runs"))
    #expect(failure.screen == nil)
    #expect(report.observations.isEmpty)
  }

  @Test
  func `the statement that finishes the app is the last that runs, and passes`()
    async throws
  {
    let report = try await run(
      "app counter\ntype \"+\"\nexpect text 0 \"Count: 1\"\nkey q")

    #expect(report.passed, "\(report)")
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

    #expect(Delivered.characters == ["a", "b", "q"])
    #expect(report.failures.map(\.line) == [3])
    #expect(report.failures.first?.verb == "type")
    #expect(
      report.failures.first?.message.hasPrefix("the application finished at line 2")
        == true)
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

    #expect(report.failures.map(\.line) == [2])
    #expect(
      report.failures.first?.message.hasPrefix(
        "the application had already finished when the scenario started") == true)
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
