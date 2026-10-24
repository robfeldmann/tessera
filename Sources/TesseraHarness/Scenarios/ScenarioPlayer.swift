import TesseraCore
import TesseraTerminalCore
import TesseraTerminalInput

/// Plays one parsed scenario against an application in an ``ApplicationRegistry``.
///
/// A failing `expect`, `check`, or `shot` is recorded with the screen at that moment and the
/// run continues, so one run reports every failure. The run stops early only when the host
/// itself fails, because later statements would run against a broken session.
@MainActor
enum ScenarioPlayer {
  /// What a played scenario collected.
  private final class Outcome {
    var failures: [ScenarioFailure] = []
    var observations: [ScenarioObservation] = []
    var recorded: [GoldenChange] = []
    var trace: [TraceRecord] = []
  }

  /// What a one-off command reads from an application: its screen, its node tree, and the
  /// projection both come from.
  struct Picture {
    var size: TerminalSize
    var rows: [String]
    var tree: [String]
    var projection: Projection
  }

  /// Plays `scenario` and reports it under `name`.
  ///
  /// With a `goldens` store, each `shot` is checked against its golden files or recorded;
  /// without one, a `shot` only observes.
  static func run(
    _ scenario: Scenario,
    name: String,
    registry: ApplicationRegistry,
    goldens: GoldenStore? = nil
  ) async -> ScenarioReport {
    func setupFailure(
      _ line: SourceLine, verb: String, message: String
    ) -> ScenarioReport {
      ScenarioReport(
        scenario: name,
        failures: [
          ScenarioFailure(
            line: line.number, statement: line.text, verb: verb, message: message)
        ]
      )
    }

    let entry: ApplicationRegistry.Entry
    do {
      entry = try registry.entry(named: scenario.app)
    } catch {
      return setupFailure(scenario.appLine, verb: "harness", message: error.description)
    }

    let outcome = Outcome()
    do {
      try await entry.headless(scenario.viewport, scenario.terminal) { host in
        await play(scenario, on: host, goldens: goldens, into: outcome)
      }
    } catch let error as HostError {
      return setupFailure(
        scenario.sizeLine ?? scenario.appLine, verb: error.verb, message: error.message)
    } catch {
      return setupFailure(scenario.appLine, verb: "harness", message: "\(error)")
    }
    return ScenarioReport(
      scenario: name,
      failures: outcome.failures,
      observations: outcome.observations,
      recorded: outcome.recorded,
      trace: outcome.trace
    )
  }

  /// The screen and node tree of the app registered as `name`, at `viewport`, with no input.
  static func picture(
    of name: String,
    at viewport: Viewport,
    registry: ApplicationRegistry
  ) async throws -> Picture {
    final class Box {
      var picture: Picture?
    }
    let box = Box()
    try await registry.entry(named: name).headless(viewport, TerminalProfile()) { host in
      let projection = host.projection
      box.picture = Picture(
        size: host.size,
        rows: host.screenRows.dropTrailingEmptyRows(),
        tree: treeLines(projection.nodes),
        projection: projection)
    }
    guard let picture = box.picture else {
      throw HostError(verb: "harness", message: "the application never started")
    }
    return picture
  }

  /// Plays every statement against `host`, stopping early when the host fails or the app
  /// finishes.
  ///
  /// A live host returns the moment the application reports `isFinished`, so nothing after
  /// that can happen in a terminal. The statement that finishes the application is the last
  /// one that runs, and the rest of its input is not delivered; the next statement, whatever it
  /// is, fails with a message that names the line that finished the application, and the run
  /// ends there.
  private static func play(
    _ scenario: Scenario,
    on host: any ScenarioHost,
    goldens: GoldenStore?,
    into outcome: Outcome
  ) async {
    defer {
      outcome.trace = host.records
    }
    var finisher: ScenarioLine?
    for line in scenario.lines {
      func failure(
        _ message: String, verb: String? = nil, expected: String? = nil,
        actual: String? = nil, showsScreen: Bool = true, rule: String? = nil,
        node: String? = nil
      ) -> ScenarioFailure {
        ScenarioFailure(
          line: line.number,
          statement: line.source,
          verb: verb ?? line.statement.verb,
          message: message,
          expected: expected,
          actual: actual,
          screen: showsScreen ? screenForReport(host.screenRows) : nil,
          rule: rule,
          node: node
        )
      }

      func deliver(_ events: [InputEvent]) async -> Bool {
        for event in events {
          do {
            try await host.send(event)
          } catch {
            outcome.failures.append(
              failure("the host could not deliver the event: \(error)", verb: "harness"))
            return false
          }
          if host.isFinished {
            finisher = line
            break
          }
        }
        return true
      }

      if host.isFinished {
        let cause =
          finisher.map {
            "the application finished at line \($0.number) (`\($0.source)`)"
          }
          ?? "the application had already finished when the scenario started"
        outcome.failures.append(
          failure("\(cause), and in a terminal nothing after it runs", showsScreen: false)
        )
        return
      }

      switch line.statement {
      case .resize(let columns, let rows):
        guard await deliver([.resize(TerminalSize(columns: columns, rows: rows))]) else {
          return
        }

      case .key(let key):
        guard await deliver([.key(key)]) else {
          return
        }

      case .type(let text):
        guard await deliver(text.map { .key(Key(code: .character($0))) }) else {
          return
        }

      case .paste(let text):
        guard await deliver([.paste(text)]) else {
          return
        }

      case .bytes(let bytes):
        var parser = InputParser()
        let events = parser.feed(contentsOf: bytes) + parser.flush()
        guard await deliver(events) else {
          return
        }

      case .shot(let shotName):
        let screen = host.screen
        outcome.observations.append(
          ScenarioObservation(
            line: line.number, verb: "shot", name: shotName,
            lines: screenForReport(screen.textRows)))
        guard let goldens else {
          continue
        }
        switch goldens.check(shot: shotName, screen: screen) {
        case .matches:
          break
        case .recorded(let changes):
          outcome.recorded.append(contentsOf: changes)
        case .drifted(let message, let expected, let actual):
          outcome.failures.append(failure(message, expected: expected, actual: actual))
        case .unusable(let message):
          outcome.failures.append(failure(message, showsScreen: false))
        case .failed(let message):
          outcome.failures.append(failure(message, verb: "harness"))
        }

      case .tree:
        outcome.observations.append(
          ScenarioObservation(
            line: line.number, verb: "tree", name: nil,
            lines: treeLines(host.projection.nodes)))

      case .dump:
        outcome.observations.append(
          ScenarioObservation(
            line: line.number, verb: "dump", name: nil, lines: [],
            projection: host.projection))

      case .check(let rules):
        let ran = rules.isEmpty ? CheckRule.allCases : rules
        let violations = Checker.run(ran, on: host.projection)
        // A named rule is asked to hold, so a warning of it fails; a bare `check` reports
        // warnings and fails only on errors.
        let named = !rules.isEmpty
        var warnings: [String] = []
        for violation in violations {
          if violation.severity == CheckRule.Severity.warning.rawValue, !named {
            warnings.append(violation.text)
            continue
          }
          outcome.failures.append(
            failure(
              "\(violation.rule) at \(violation.node): \(violation.detail)",
              rule: violation.rule, node: violation.node))
        }
        outcome.observations.append(
          ScenarioObservation(
            line: line.number, verb: "check", name: nil,
            lines: ["ran \(ran.map(\.rawValue).joined(separator: ", "))"] + warnings))

      case .expectText(let row, let text):
        if let message = expectText(row: row, text: text, rows: host.screenRows) {
          outcome.failures.append(
            failure(message.text, expected: text, actual: message.actual))
        }

      case .expectScreen(let expectedRows):
        if let difference = screenDifference(
          expected: expectedRows, rows: host.screenRows)
        {
          outcome.failures.append(
            failure(
              difference.message, expected: difference.expected, actual: difference.actual
            ))
        }

      case .expectNode(let locator, let frame):
        if let difference = nodeDifference(locator: locator, frame: frame, host: host) {
          outcome.failures.append(
            failure(
              difference.message, expected: frame.description, actual: difference.actual))
        }

      case .expectCost(let bounds):
        if let difference = costDifference(bounds, record: host.lastRecord) {
          outcome.failures.append(
            failure(
              difference.message,
              expected: bounds.map(\.description).joined(separator: " "),
              actual: difference.actual, showsScreen: false))
        }
      }
    }
  }

  // MARK: Expectations

  private static func expectText(row: Int?, text: String, rows: [String])
    -> (text: String, actual: String?)?
  {
    if let row {
      guard rows.indices.contains(row) else {
        return ("row \(row) is outside the \(rows.count)-row screen", nil)
      }
      return rows[row] == text ? nil : ("row \(row) text differs", rows[row])
    }
    return rows.contains { $0.contains(text) }
      ? nil : ("no screen row contains the text", "(not found in \(rows.count) rows)")
  }

  /// The first row where `rows` is not `expected`, once both lose their trailing spaces and
  /// trailing empty rows.
  private static func screenDifference(expected: [String], rows: [String])
    -> (message: String, expected: String, actual: String)?
  {
    func trimmed(_ rows: [String]) -> [String] {
      rows.map { row in
        var row = row
        while row.last == " " {
          row.removeLast()
        }
        return row
      }.dropTrailingEmptyRows()
    }
    let wanted = trimmed(expected)
    let actual = trimmed(rows)
    guard wanted != actual else {
      return nil
    }
    let row = wanted.firstDifference(from: actual) ?? min(wanted.count, actual.count)
    return (
      "screen differs at row \(row): expected \(wanted.count) rows, the screen has "
        + "\(actual.count)",
      row < wanted.count ? wanted[row] : "(no row \(row))",
      row < actual.count ? actual[row] : "(no row \(row))"
    )
  }

  private static func nodeDifference(
    locator: Locator, frame: FrameExpectation, host: any ScenarioHost
  ) -> (message: String, actual: String)? {
    let projection = host.projection
    switch locator.resolve(in: projection) {
    case .node(let node):
      let actual = FrameExpectation(
        column: node.frame.column, row: node.frame.row,
        columns: node.frame.columns, rows: node.frame.rows)
      return actual == frame
        ? nil : ("frame of `\(locator.description)` differs", actual.description)
    case .none:
      return (
        "locator `\(locator.description)` matches no node",
        "(no node; types: \(distinctTypes(projection.nodes))"
          + "\(layoutsSuffix(projection.nodes)))"
      )
    case .ambiguous(let matches):
      return (
        "locator `\(locator.description)` matches \(matches.count) nodes; add nth=",
        matches.map(\.path).joined(separator: ", ")
      )
    }
  }

  /// The first bound the step's cost exceeds, with every count so the next bound can be
  /// written from what the step took.
  private static func costDifference(_ bounds: [CostBound], record: TraceRecord?)
    -> (message: String, actual: String)?
  {
    guard let record else {
      return ("no step has run to take the cost of", "(no step)")
    }
    for bound in bounds {
      let count = record.cost.count(named: bound.counter) ?? 0
      if count > bound.limit {
        return (
          "step \(record.seq) (\(record.event.summary)) took \(count) \(bound.counter), "
            + "above the bound \(bound.limit)",
          record.cost.text
        )
      }
    }
    return nil
  }

  // MARK: Output

  /// Rows with trailing empty rows dropped, so a 500-row probe stays readable.
  static func screenForReport(_ rows: [String]) -> [String] {
    rows.dropTrailingEmptyRows()
  }

  static func distinctTypes(_ nodes: [Projection.Node]) -> String {
    var seen: [String] = []
    for node in nodes where !seen.contains(node.type) {
      seen.append(node.type)
    }
    return seen.joined(separator: ", ")
  }

  /// `; layouts: …` when some node has a layout algorithm, so a `layout=` locator that
  /// matched nothing shows what it could have named.
  private static func layoutsSuffix(_ nodes: [Projection.Node]) -> String {
    var seen: [String] = []
    for layout in nodes.compactMap(\.layout) where !seen.contains(layout) {
      seen.append(layout)
    }
    return seen.isEmpty ? "" : "; layouts: \(seen.joined(separator: ", "))"
  }

  /// One line per node: indentation by depth, identity, type (with the layout algorithm of a
  /// container that has one), frame, and clip if it differs from the frame.
  static func treeLines(_ nodes: [Projection.Node]) -> [String] {
    nodes.map { node in
      let type = node.layout.map { "\(node.type)(\($0))" } ?? node.type
      var line =
        String(repeating: "  ", count: node.depth)
        + "\(node.path) \(type) frame=\(node.frame.text)"
      if node.clip != node.frame {
        line += " clip=\(node.clip.text)"
      }
      return line
    }
  }
}
