import Foundation

/// One failed statement. `parse` failures carry only `message`.
package struct ScenarioFailure: Codable, Equatable, Sendable {
  package var line: Int
  package var statement: String
  package var verb: String
  package var message: String
  package var expected: String?
  package var actual: String?

  /// Screen rows (trailing blanks trimmed, trailing empty rows dropped) at the failure.
  package var screen: [String]?  // swiftlint:disable:this discouraged_optional_collection
}

/// Output of an observation statement (`shot`, `tree`).
package struct ScenarioObservation: Codable, Equatable, Sendable {
  package var line: Int
  package var verb: String
  package var name: String?
  package var lines: [String]
}

/// A file a `shot` statement produces when the CLI runs with `--out`.
struct ShotArtifact: Equatable, Sendable {
  var name: String
  var text: String
  var tree: String
}

/// The single source of the human and JSON forms.
package struct ScenarioReport: Codable, Equatable, Sendable {
  package var scenario: String
  package var passed: Bool
  package var failures: [ScenarioFailure]
  package var observations: [ScenarioObservation]

  static func parseFailure(_ error: ScenarioParseError) -> Self {
    Self(
      scenario: error.file,
      passed: false,
      failures: [
        ScenarioFailure(
          line: error.line,
          statement: "",
          verb: "parse",
          message: error.description
        )
      ],
      observations: []
    )
  }

  /// Compact, sorted-key JSON on one line.
  package func json() -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    let data = (try? encoder.encode(self)) ?? Data()
    // swiftlint:disable:next optional_data_string_conversion
    return String(decoding: data, as: UTF8.self)
  }

  package func human() -> String {
    var lines = ["\(passed ? "PASS" : "FAIL") \(scenario)"]
    for failure in failures {
      if failure.verb == "parse" || failure.verb == "usage" {
        lines.append("  \(failure.message)")
        continue
      }
      lines.append("  line \(failure.line): \(failure.statement)")
      lines.append("    \(failure.message)")
      if let expected = failure.expected {
        lines.append("    expected: \(expected)")
      }
      if let actual = failure.actual {
        lines.append("    actual:   \(actual)")
      }
      if let screen = failure.screen {
        lines.append("    screen:")
        for (row, text) in screen.enumerated() {
          lines.append("      \(row)| \(text)")
        }
      }
    }
    return lines.joined(separator: "\n")
  }
}
