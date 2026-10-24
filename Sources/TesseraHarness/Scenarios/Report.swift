import Foundation

/// One statement of a scenario that did not hold, or one reason a scenario could not run.
///
/// `verb` says what kind of failure it is, and so which exit code a command ends with: a
/// statement's own verb (`expect text`, `shot`, `key`, …) or `size` or `repeat` is an
/// expectation that failed (exit 1); `parse` and `usage` are mistakes in the scenario file or
/// the command (exit 2); `harness` is a fault in the run itself (exit 3).
public struct ScenarioFailure: Equatable, Sendable {
  /// The failing statement's line in the scenario file, counted from 1, or 0 when the
  /// failure belongs to the file or the command rather than to a line.
  public let line: Int

  /// The statement's text, or empty when the failure has none.
  public let statement: String

  /// The statement's verb, or `parse`, `usage`, `harness`, `size`, or `repeat`.
  public let verb: String

  /// What went wrong, written for the person or agent who has to fix it.
  public let message: String

  /// The value the statement expected, when it compares one.
  package let expected: String?

  /// The value the run produced, when the statement compares one.
  package let actual: String?

  /// The screen at the failure, trailing blanks trimmed and trailing empty rows dropped.
  package let screen: [String]?  // swiftlint:disable:this discouraged_optional_collection

  // swiftlint:disable discouraged_optional_collection
  package init(
    line: Int,
    statement: String,
    verb: String,
    message: String,
    expected: String? = nil,
    actual: String? = nil,
    screen: [String]? = nil
  ) {
    self.line = line
    self.statement = statement
    self.verb = verb
    self.message = message
    self.expected = expected
    self.actual = actual
    self.screen = screen
  }
  // swiftlint:enable discouraged_optional_collection
}

/// Output of an observation statement (`shot`, `tree`).
package struct ScenarioObservation: Encodable, Equatable, Sendable {
  package var line: Int
  package var verb: String
  package var name: String?
  package var lines: [String]
}

/// A golden file `--record` wrote.
package struct GoldenChange: Encodable, Equatable, Sendable {
  /// What `--record` did to a golden.
  package enum Change: String, Encodable, Sendable {
    case created
    case updated
  }

  package var path: String
  package var change: Change
}

/// What one scenario run found, in the human form and the JSON form that share it.
public struct ScenarioReport: CustomStringConvertible, Equatable, Sendable {
  /// The scenario file's path, as the run was given it.
  public let scenario: String

  /// Every statement that failed, in order; the run continues after a failed expectation, so
  /// one run reports them all.
  public let failures: [ScenarioFailure]

  /// What the `shot` and `tree` statements saw, in order.
  package let observations: [ScenarioObservation]

  /// The goldens `--record` wrote.
  package var recorded: [GoldenChange]

  /// Wall-clock seconds, one per run, when `--timing` asked for them, and empty otherwise.
  package var seconds: [Double]

  /// Whether every statement held.
  public var passed: Bool {
    failures.isEmpty
  }

  /// The human form: `PASS` or `FAIL` and the scenario's path, then each failure with the
  /// statement, what was expected, what was seen, and the screen.
  ///
  /// A `parse` failure prints as `FILE:LINE: error: message`, the form editors and CI logs
  /// link.
  public var description: String {
    var lines = ["\(passed ? "PASS" : "FAIL") \(scenario)\(timingText)"]
    for change in recorded {
      lines.append("  recorded \(change.path) (\(change.change.rawValue))")
    }
    for failure in failures {
      lines += humanLines(for: failure)
    }
    return lines.joined(separator: "\n")
  }

  /// The JSON form: one compact, sorted-key object on one line, with no trailing newline.
  public var json: String {
    JSONText.string(for: ReportBody(self))
  }

  /// The report with everything that varies between two runs of the same scenario removed.
  var comparable: Self {
    Self(scenario: scenario, failures: failures, observations: observations)
  }

  private var timingText: String {
    guard !seconds.isEmpty else {
      return ""
    }
    return " (\(seconds.map { String($0) }.joined(separator: ", ")) s)"
  }

  package init(
    scenario: String,
    failures: [ScenarioFailure],
    observations: [ScenarioObservation] = [],
    recorded: [GoldenChange] = [],
    seconds: [Double] = []
  ) {
    self.scenario = scenario
    self.failures = failures
    self.observations = observations
    self.recorded = recorded
    self.seconds = seconds
  }

  /// A report for a scenario that could not be parsed.
  static func parseFailure(_ error: ScenarioParseError) -> Self {
    Self(
      scenario: error.file,
      failures: [
        ScenarioFailure(
          line: error.line, statement: error.source, verb: "parse", message: error.message
        )
      ]
    )
  }

  /// A report for a scenario, path, or command that could not run at all.
  static func failure(scenario: String, verb: String, message: String) -> Self {
    Self(
      scenario: scenario,
      failures: [ScenarioFailure(line: 0, statement: "", verb: verb, message: message)]
    )
  }

  private func humanLines(for failure: ScenarioFailure) -> [String] {
    if failure.verb == "parse" || failure.verb == "usage" {
      let place = failure.line > 0 ? "\(scenario):\(failure.line)" : scenario
      return ["\(place): error: \(failure.message)"]
    }
    var lines = [
      failure.line > 0
        ? "  line \(failure.line): \(failure.statement)" : "  \(failure.verb)"
    ]
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
    return lines
  }
}

/// The JSON form of a report, which the public types do not conform to themselves: the fields
/// are promised, the `Encodable` conformance is not.
struct ReportBody: Encodable {
  /// One failure's fields; `expected`, `actual`, and `screen` are left out when absent.
  struct Failure: Encodable {
    var line: Int
    var statement: String
    var verb: String
    var message: String
    var expected: String?
    var actual: String?
    var screen: [String]?  // swiftlint:disable:this discouraged_optional_collection

    init(_ failure: ScenarioFailure) {
      line = failure.line
      statement = failure.statement
      verb = failure.verb
      message = failure.message
      expected = failure.expected
      actual = failure.actual
      screen = failure.screen
    }
  }

  private enum CodingKeys: String, CodingKey {
    case failures, observations, passed, recorded, scenario, seconds
  }

  var report: ScenarioReport

  init(_ report: ScenarioReport) {
    self.report = report
  }

  func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(report.failures.map(Failure.init), forKey: .failures)
    try container.encode(report.observations, forKey: .observations)
    try container.encode(report.passed, forKey: .passed)
    if !report.recorded.isEmpty {
      try container.encode(report.recorded, forKey: .recorded)
    }
    try container.encode(report.scenario, forKey: .scenario)
    if !report.seconds.isEmpty {
      try container.encode(report.seconds, forKey: .seconds)
    }
  }
}

/// Compact, sorted-key JSON, the one encoding every command's output uses.
enum JSONText {
  static func string(for value: some Encodable) -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    let data = (try? encoder.encode(value)) ?? Data()
    // swiftlint:disable:next optional_data_string_conversion
    return String(decoding: data, as: UTF8.self)
  }
}
