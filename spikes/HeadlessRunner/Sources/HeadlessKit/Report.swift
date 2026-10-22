import Foundation

/// One failed statement. `parse` failures carry only `message`.
public struct ScenarioFailure: Codable, Equatable, Sendable {
  public var line: Int
  public var statement: String
  public var verb: String
  public var message: String
  public var expected: String?
  public var actual: String?

  /// Screen rows (trailing blanks trimmed, trailing empty rows dropped) at the failure.
  public var screen: [String]?
}

/// Output of an observation statement (`shot`, `tree`).
public struct ScenarioObservation: Codable, Equatable, Sendable {
  public var line: Int
  public var verb: String
  public var name: String?
  public var lines: [String]
}

/// A file a `shot` statement produces when the CLI runs with `--out`.
struct ShotArtifact: Equatable, Sendable {
  var name: String
  var text: String
  var tree: String
}

/// The single source of the human and JSON forms.
public struct ScenarioReport: Codable, Equatable, Sendable {
  public var scenario: String
  public var passed: Bool
  public var failures: [ScenarioFailure]
  public var observations: [ScenarioObservation]

  static func parseFailure(_ error: ScenarioParseError) -> ScenarioReport {
    ScenarioReport(
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
  public func json() -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    let data = (try? encoder.encode(self)) ?? Data()
    return String(decoding: data, as: UTF8.self)
  }

  public func human() -> String {
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
