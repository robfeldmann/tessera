import Foundation

/// The committed text goldens of one scenario: a `NAME.txt` file per `shot`, in a directory
/// named like the scenario file without its extension (`counter.scn` keeps its goldens in
/// `counter/`).
///
/// A golden is the screen as text: every row with its trailing spaces removed, trailing empty
/// rows dropped, rows joined by `\n`, and one `\n` at the end. Comparison is byte for byte,
/// so drift fails the `shot` statement; recording rewrites the files and says which changed.
struct GoldenStore: Equatable, Sendable {
  /// What checking one screen against its golden decided.
  enum Outcome: Equatable {
    /// The golden holds this screen.
    case matches

    /// `record` wrote the golden, which was missing or different.
    case recorded(GoldenChange)

    /// The screen differs from the golden.
    case drifted(message: String, expected: String, actual: String)

    /// There is nothing to compare the screen with: the golden is missing or is not an LF
    /// file.
    case unusable(message: String)

    /// The golden could not be written.
    case failed(message: String)
  }

  /// The directory holding the scenario's goldens, as the run was given the scenario's path.
  var directory: String

  /// Whether to write goldens instead of failing on drift.
  var record: Bool

  /// The store for the scenario file at `path`, which ends in `.scn`.
  init(scenarioPath path: String, record: Bool) {
    directory = String(path.dropLast(ScenarioFiles.fileExtension.count))
    self.record = record
  }

  /// The text of a screen as a golden holds it.
  static func text(of rows: [String]) -> String {
    rows.dropTrailingEmptyRows().joined(separator: "\n") + "\n"
  }

  func path(for name: String) -> String {
    "\(directory)/\(name).txt"
  }

  /// Checks `rows`, the screen after statement `name`, against its golden, or records it.
  func check(shot name: String, rows: [String]) -> Outcome {
    let path = path(for: name)
    let text = Self.text(of: rows)
    let bytes = Data(text.utf8)
    let existing = FileManager.default.contents(atPath: path)
    if existing == bytes {
      return .matches
    }
    if record {
      do {
        try FileManager.default.createDirectory(
          atPath: directory, withIntermediateDirectories: true)
        try bytes.write(to: URL(fileURLWithPath: path), options: .atomic)
      } catch {
        return .failed(message: "cannot write the golden `\(path)`: \(error)")
      }
      return .recorded(
        GoldenChange(path: path, change: existing == nil ? .created : .updated))
    }
    guard let existing else {
      return .unusable(
        message:
          "shot `\(name)` has no golden at `\(path)`; "
          + "run with --record to create it, and review the file")
    }
    guard let goldenText = String(validating: existing, as: UTF8.self) else {
      return .unusable(message: "golden `\(path)` is not UTF-8 text")
    }
    return drift(shot: name, path: path, goldenText: goldenText, text: text)
  }

  private func drift(shot name: String, path: String, goldenText: String, text: String)
    -> Outcome
  {
    if goldenText.replacingOccurrences(of: "\r\n", with: "\n") == text {
      return .unusable(
        message:
          "golden `\(path)` has CRLF line endings; goldens are LF files, so check them out "
          + "with LF (`*.txt text eol=lf` in .gitattributes)")
    }
    let expected = ScenarioParser.sourceLines(of: goldenText).dropTrailingEmptyRows()
    let actual = ScenarioParser.sourceLines(of: text).dropTrailingEmptyRows()
    let row = expected.firstDifference(from: actual) ?? min(expected.count, actual.count)
    return .drifted(
      message:
        "shot `\(name)` differs from `\(path)` at row \(row): the golden has "
        + "\(expected.count) rows and the screen has \(actual.count). If the new rendering "
        + "is intended, rerun with --record and review the golden's diff",
      expected: row < expected.count ? expected[row] : "(no row \(row))",
      actual: row < actual.count ? actual[row] : "(no row \(row))")
  }
}

extension Array where Element == String {
  /// The rows without the empty ones at the end.
  func dropTrailingEmptyRows() -> [String] {
    var rows = self
    while rows.last?.isEmpty == true {
      rows.removeLast()
    }
    return rows
  }
}

extension Array where Element: Equatable {
  /// The first index at which `self` and `other` differ, or `nil` when one is a prefix of the
  /// other.
  func firstDifference(from other: [Element]) -> Int? {
    zip(self, other).enumerated().first { $0.element.0 != $0.element.1 }?.offset
  }
}
