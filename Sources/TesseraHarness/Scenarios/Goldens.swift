import Foundation

/// The committed text goldens of one scenario: for each `shot`, `NAME.txt` and `NAME.grid.txt`
/// in a directory named like the scenario file without its extension (`counter.scn` keeps its
/// goldens in `counter/`).
///
/// `NAME.txt` is the screen as text: every row with its trailing spaces removed, trailing empty
/// rows dropped, rows joined by `\n`, and one `\n` at the end. `NAME.grid.txt` is the same
/// screen as the catalog's styled grid (``ScreenGrid/styledGridText``): the characters, one
/// style letter per cell, and the legend. Comparison is byte for byte, so drift in either file
/// fails the `shot` statement; recording rewrites the files and says which changed.
struct GoldenStore: Equatable, Sendable {
  /// What checking one screen against its goldens decided.
  enum Outcome: Equatable {
    /// Both goldens hold this screen.
    case matches

    /// `record` wrote the goldens that were missing or different.
    case recorded([GoldenChange])

    /// The screen differs from a golden.
    case drifted(message: String, expected: String, actual: String)

    /// There is nothing to compare the screen with: a golden is missing or is not an LF file.
    case unusable(message: String)

    /// A golden could not be written.
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

  /// The text of a screen as `NAME.txt` holds it.
  static func text(of rows: [String]) -> String {
    rows.dropTrailingEmptyRows().joined(separator: "\n") + "\n"
  }

  /// The text golden of the shot `name`.
  func path(for name: String) -> String {
    "\(directory)/\(name).txt"
  }

  /// The styled-grid golden of the shot `name`.
  func gridPath(for name: String) -> String {
    "\(directory)/\(name).grid.txt"
  }

  /// Checks `screen`, the screen after statement `name`, against its goldens, or records them.
  ///
  /// The text golden is compared first, and the first golden that differs or is missing is
  /// the one reported.
  func check(shot name: String, screen: ScreenGrid) -> Outcome {
    let files = [
      (path: path(for: name), text: Self.text(of: screen.textRows)),
      (path: gridPath(for: name), text: screen.styledGridText),
    ]
    if record {
      return write(files)
    }
    for file in files {
      let outcome = compare(shot: name, path: file.path, text: file.text)
      if outcome != .matches {
        return outcome
      }
    }
    return .matches
  }

  /// Writes each file that is missing or different, and lists what it changed.
  private func write(_ files: [(path: String, text: String)]) -> Outcome {
    var changes: [GoldenChange] = []
    for file in files {
      let bytes = Data(file.text.utf8)
      let existing = FileManager.default.contents(atPath: file.path)
      if existing == bytes {
        continue
      }
      do {
        try FileManager.default.createDirectory(
          atPath: directory, withIntermediateDirectories: true)
        try bytes.write(to: URL(fileURLWithPath: file.path), options: .atomic)
      } catch {
        return .failed(message: "cannot write the golden `\(file.path)`: \(error)")
      }
      changes.append(
        GoldenChange(path: file.path, change: existing == nil ? .created : .updated))
    }
    return changes.isEmpty ? .matches : .recorded(changes)
  }

  private func compare(shot name: String, path: String, text: String) -> Outcome {
    guard let existing = FileManager.default.contents(atPath: path) else {
      return .unusable(
        message:
          "shot `\(name)` has no golden at `\(path)`; "
          + "run with --record to create it, and review the file")
    }
    if existing == Data(text.utf8) {
      return .matches
    }
    guard let goldenText = String(validating: existing, as: UTF8.self) else {
      return .unusable(message: "golden `\(path)` is not UTF-8 text")
    }
    return drift(shot: name, path: path, goldenText: goldenText, text: text)
  }

  private func drift(shot name: String, path: String, goldenText: String, text: String)
    -> Outcome
  {
    // A screen row never holds a carriage return, so one in a golden means CRLF line endings,
    // whether or not the screen has also changed; say so before the rows are compared, or the
    // difference reported would be a row ending in an invisible `\r`.
    if goldenText.unicodeScalars.contains("\r") {
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
