import TesseraCore
import TesseraTerminalCore
import TesseraTerminalInput

/// Executes a parsed scenario against an application in an ``ApplicationRegistry``.
///
/// A failing `expect` is recorded with the screen at that moment and the run continues.
@MainActor
package enum ScenarioRunner {
  /// What a played scenario collected.
  private final class Outcome {
    var artifacts: [ShotArtifact] = []
    var failures: [ScenarioFailure] = []
    var observations: [ScenarioObservation] = []
  }

  package static func run(
    _ scenario: Scenario,
    name: String,
    registry: ApplicationRegistry
  ) async -> ScenarioReport {
    await execute(scenario, name: name, registry: registry).report
  }

  static func execute(
    _ scenario: Scenario,
    name: String,
    registry: ApplicationRegistry
  ) async -> (report: ScenarioReport, artifacts: [ShotArtifact]) {
    func setupFailure(
      verb: String, message: String
    ) -> (report: ScenarioReport, artifacts: [ShotArtifact]) {
      let report = ScenarioReport(
        scenario: name,
        passed: false,
        failures: [
          ScenarioFailure(
            line: 0, statement: "app \(scenario.app)", verb: verb, message: message)
        ],
        observations: []
      )
      return (report, [])
    }

    let entry: ApplicationRegistry.Entry
    do {
      entry = try registry.entry(named: scenario.app)
    } catch {
      return setupFailure(verb: "app", message: error.description)
    }

    let outcome = Outcome()
    do {
      try await entry.headless(scenario.viewport) { host in
        await play(scenario, on: host, into: outcome)
      }
    } catch let error as HostError {
      return setupFailure(verb: error.verb, message: error.message)
    } catch {
      return setupFailure(verb: "harness", message: "\(error)")
    }

    let report = ScenarioReport(
      scenario: name,
      passed: outcome.failures.isEmpty,
      failures: outcome.failures,
      observations: outcome.observations
    )
    return (report, outcome.artifacts)
  }

  /// Plays every statement against `host`, stopping early only when the host fails.
  private static func play(
    _ scenario: Scenario,
    on host: any ScenarioHost,
    into outcome: Outcome
  ) async {
    var artifacts: [ShotArtifact] = []
    var failures: [ScenarioFailure] = []
    var observations: [ScenarioObservation] = []
    defer {
      outcome.artifacts = artifacts
      outcome.failures = failures
      outcome.observations = observations
    }

    for line in scenario.lines {
      func failure(
        _ message: String, expected: String? = nil, actual: String? = nil
      ) -> ScenarioFailure {
        ScenarioFailure(
          line: line.number,
          statement: line.source,
          verb: line.statement.verb,
          message: message,
          expected: expected,
          actual: actual,
          screen: screenForReport(host.screenRows)
        )
      }

      func deliver(_ event: InputEvent) async -> Bool {
        do {
          try await host.send(event)
          return true
        } catch {
          failures.append(failure("the host could not deliver the event: \(error)"))
          return false
        }
      }

      switch line.statement {
      case .resize(let columns, let rows):
        guard await deliver(.resize(TerminalSize(columns: columns, rows: rows))) else {
          return
        }

      case .key(let key):
        guard await deliver(.key(key)) else {
          return
        }

      case .type(let text):
        for character in text {
          guard await deliver(.key(Key(code: .character(character)))) else {
            return
          }
        }

      case .shot(let shotName):
        let rows = host.screenRows
        observations.append(
          ScenarioObservation(
            line: line.number, verb: "shot", name: shotName,
            lines: screenForReport(rows)))
        artifacts.append(
          ShotArtifact(
            name: shotName,
            text: rows.joined(separator: "\n") + "\n",
            tree: treeLines(host.diagnostics.nodes).joined(separator: "\n") + "\n"))

      case .tree:
        observations.append(
          ScenarioObservation(
            line: line.number, verb: "tree", name: nil,
            lines: treeLines(host.diagnostics.nodes)))

      case .expectText(let row, let text):
        let rows = host.screenRows
        if let row {
          guard rows.indices.contains(row) else {
            failures.append(
              failure(
                "row \(row) is outside the \(rows.count)-row screen",
                expected: text, actual: nil))
            continue
          }
          if rows[row] != text {
            failures.append(
              failure(
                "row \(row) text differs", expected: text, actual: rows[row]))
          }
        } else if !rows.contains(where: { $0.contains(text) }) {
          failures.append(
            failure(
              "no screen row contains the text", expected: text,
              actual: "(not found in \(rows.count) rows)"))
        }

      case .expectNode(let locator, let frame):
        let nodes = host.diagnostics.nodes
        switch locator.resolve(in: nodes, screenRows: host.screenRows) {
        case .node(let node):
          let actual = FrameExpectation(
            column: node.frame.origin.column, row: node.frame.origin.row,
            columns: node.frame.size.columns, rows: node.frame.size.rows)
          if actual != frame {
            failures.append(
              failure(
                "frame of `\(locator.description)` differs",
                expected: frame.description, actual: actual.description))
          }
        case .none:
          failures.append(
            failure(
              "locator `\(locator.description)` matches no node",
              expected: frame.description,
              actual: "(no node; types: \(distinctTypes(nodes)))"))
        case .ambiguous(let matches):
          failures.append(
            failure(
              "locator `\(locator.description)` matches \(matches.count) nodes; add nth=",
              expected: frame.description,
              actual: matches.map(\.identity.description).joined(separator: ", ")))
        }
      }
    }
  }

  /// Rows with trailing empty rows dropped, so a 500-row probe stays readable.
  static func screenForReport(_ rows: [String]) -> [String] {
    var rows = rows
    while rows.last?.isEmpty == true {
      rows.removeLast()
    }
    return rows
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
