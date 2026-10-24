import TesseraCore
import TesseraTerminalCore
import TesseraTerminalInput

/// Plays one parsed scenario against an application in an ``ApplicationRegistry``.
///
/// A failing `expect` or `shot` is recorded with the screen at that moment and the run
/// continues, so one run reports every failure. The run stops early only when the host
/// itself fails, because later statements would run against a broken session.
@MainActor
enum ScenarioPlayer {
  /// What a played scenario collected.
  private final class Outcome {
    var failures: [ScenarioFailure] = []
    var observations: [ScenarioObservation] = []
    var recorded: [GoldenChange] = []
  }

  /// What a one-off command reads from an application: its screen and its node tree.
  struct Picture {
    var size: TerminalSize
    var rows: [String]
    var tree: [String]
  }

  /// Plays `scenario` and reports it under `name`.
  ///
  /// With a `goldens` store, each `shot` is checked against its golden file or recorded;
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
      recorded: outcome.recorded
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
      box.picture = Picture(
        size: host.size,
        rows: host.screenRows.dropTrailingEmptyRows(),
        tree: treeLines(host.diagnostics.nodes))
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
    var finisher: ScenarioLine?
    for line in scenario.lines {
      func failure(
        _ message: String, verb: String? = nil, expected: String? = nil,
        actual: String? = nil, showsScreen: Bool = true
      ) -> ScenarioFailure {
        ScenarioFailure(
          line: line.number,
          statement: line.source,
          verb: verb ?? line.statement.verb,
          message: message,
          expected: expected,
          actual: actual,
          screen: showsScreen ? screenForReport(host.screenRows) : nil
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
        let rows = host.screenRows
        outcome.observations.append(
          ScenarioObservation(
            line: line.number, verb: "shot", name: shotName,
            lines: screenForReport(rows)))
        guard let goldens else {
          continue
        }
        switch goldens.check(shot: shotName, rows: rows) {
        case .matches:
          break
        case .recorded(let change):
          outcome.recorded.append(change)
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
            lines: treeLines(host.diagnostics.nodes)))

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
        if let difference = nodeDifference(
          locator: locator, frame: frame, host: host)
        {
          outcome.failures.append(
            failure(
              difference.message, expected: frame.description, actual: difference.actual))
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
    let nodes = host.diagnostics.nodes
    switch locator.resolve(in: nodes, screenRows: host.screenRows) {
    case .node(let node):
      let actual = FrameExpectation(
        column: node.frame.origin.column, row: node.frame.origin.row,
        columns: node.frame.size.columns, rows: node.frame.size.rows)
      return actual == frame
        ? nil : ("frame of `\(locator.description)` differs", actual.description)
    case .none:
      return (
        "locator `\(locator.description)` matches no node",
        "(no node; types: \(distinctTypes(nodes)))"
      )
    case .ambiguous(let matches):
      return (
        "locator `\(locator.description)` matches \(matches.count) nodes; add nth=",
        matches.map(\.identity.description).joined(separator: ", ")
      )
    }
  }

  // MARK: Output

  /// Rows with trailing empty rows dropped, so a 500-row probe stays readable.
  static func screenForReport(_ rows: [String]) -> [String] {
    rows.dropTrailingEmptyRows()
  }

  static func distinctTypes(_ nodes: [NodeDiagnostics]) -> String {
    var seen: [String] = []
    for node in nodes {
      let type = Locator.baseTypeName(node.viewType)
      if !seen.contains(type) {
        seen.append(type)
      }
    }
    return seen.joined(separator: ", ")
  }

  /// One line per node: indentation by depth, identity, base type, frame (and clip if it differs).
  static func treeLines(_ nodes: [NodeDiagnostics]) -> [String] {
    nodes.map { node in
      let identity = node.identity.description
      let depth = identity.split(separator: "/").count - 1
      var line =
        String(repeating: "  ", count: depth)
        + "\(identity) \(Locator.baseTypeName(node.viewType)) "
        + "frame=\(rectText(node.frame))"
      if node.clip != node.frame {
        line += " clip=\(rectText(node.clip))"
      }
      return line
    }
  }

  private static func rectText(_ rect: Rect) -> String {
    "\(rect.origin.column),\(rect.origin.row),\(rect.size.columns)x\(rect.size.rows)"
  }
}
