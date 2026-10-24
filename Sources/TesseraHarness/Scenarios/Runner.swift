import TesseraCore
import TesseraTerminalCore
import TesseraTerminalInput

/// Executes a parsed scenario against a ``DemoRegistry`` app.
///
/// A failing `expect` is recorded with the screen at that moment and the run continues.
package enum ScenarioRunner {
  package static func run(_ scenario: Scenario, name: String) -> ScenarioReport {
    execute(scenario, name: name).report
  }

  static func execute(
    _ scenario: Scenario,
    name: String
  ) -> (report: ScenarioReport, artifacts: [ShotArtifact]) {
    let host: any ScenarioHost
    do {
      host = try DemoRegistry.makeHost(app: scenario.app, viewport: scenario.viewport)
    } catch {
      let report = ScenarioReport(
        scenario: name,
        passed: false,
        failures: [
          ScenarioFailure(
            line: 0, statement: "app \(scenario.app)", verb: error.verb,
            message: error.message)
        ],
        observations: []
      )
      return (report, [])
    }

    var artifacts: [ShotArtifact] = []
    var failures: [ScenarioFailure] = []
    var observations: [ScenarioObservation] = []

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

      switch line.statement {
      case .resize(let columns, let rows):
        host.send(.resize(TerminalSize(columns: columns, rows: rows)))

      case .key(let key):
        host.send(.key(key))

      case .type(let text):
        for character in text {
          host.send(.key(Key(code: .character(character))))
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

    let report = ScenarioReport(
      scenario: name,
      passed: failures.isEmpty,
      failures: failures,
      observations: observations
    )
    return (report, artifacts)
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
