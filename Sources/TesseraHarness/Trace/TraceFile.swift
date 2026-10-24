import Foundation

/// Reads and writes the trace as a file: one ``TraceRecord`` per line, as compact sorted-key
/// JSON, first frame first.
///
/// `tessera run --trace DIR` writes one file for each scenario, a live session writes the file
/// `TESSERA_TRACE` names, and `tessera replay` reads either.
enum TraceFile {
  /// The one field every schema version of a record keeps, read before the rest.
  private struct VersionOnly: Decodable {
    var version: Int
  }

  /// A line of a trace file that cannot be read back.
  struct ReadError: Error, Equatable, CustomStringConvertible {
    /// The line's number, counted from 1.
    var line: Int
    var message: String

    var description: String {
      "line \(line): \(message)"
    }
  }

  /// The file's text for `records`: one line each, and a final newline.
  static func text(of records: [TraceRecord]) -> String {
    records.map { $0.line + "\n" }.joined()
  }

  /// The file `run --trace` writes a scenario's trace to: the scenario's path without its
  /// extension, mirrored under `directory`, with `.trace.jsonl` added. Parent and current
  /// directory components and a drive's colon are dropped, so the file always lands inside
  /// `directory`.
  static func path(forScenario path: String, in directory: String) -> String {
    var name = path
    if name.hasSuffix(ScenarioFiles.fileExtension) {
      name.removeLast(ScenarioFiles.fileExtension.count)
    }
    let components = name.split { $0 == "/" || $0 == "\\" }
      .map { $0.replacingOccurrences(of: ":", with: "_") }
      .filter { $0 != "." && $0 != ".." && !$0.isEmpty }
    return ([directory] + components).joined(separator: "/") + ".trace.jsonl"
  }

  /// Writes `records` to the trace file of the scenario at `path`, creating the directories.
  static func write(
    _ records: [TraceRecord], forScenario path: String, into directory: String
  ) throws {
    let file = Self.path(forScenario: path, in: directory)
    let url = URL(fileURLWithPath: file)
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data(text(of: records).utf8).write(to: url, options: .atomic)
  }

  /// The records in `text`, in order. A blank line is skipped; a line that is not a record, or
  /// that has another schema version, throws.
  static func records(in text: String) throws -> [TraceRecord] {
    let decoder = JSONDecoder()
    var records: [TraceRecord] = []
    for (offset, line) in ScenarioParser.sourceLines(of: text).enumerated() {
      let number = offset + 1
      let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
      if trimmed.isEmpty {
        continue
      }
      // The version first: a later schema may rename or drop a key, and that line should say
      // which version it is, not that a key is missing.
      let version: Int
      do {
        version = try decoder.decode(VersionOnly.self, from: Data(trimmed.utf8)).version
      } catch {
        throw ReadError(
          line: number, message: "this line is not a trace record (\(describe(error)))")
      }
      guard version == TraceRecord.currentVersion else {
        throw ReadError(
          line: number,
          message:
            "the record has version \(version); this harness reads version "
            + "\(TraceRecord.currentVersion)")
      }
      let record: TraceRecord
      do {
        record = try decoder.decode(TraceRecord.self, from: Data(trimmed.utf8))
      } catch {
        throw ReadError(
          line: number, message: "this line is not a trace record (\(describe(error)))")
      }
      records.append(record)
    }
    return records
  }

  private static func describe(_ error: any Error) -> String {
    guard let error = error as? DecodingError else {
      return "\(error)"
    }
    switch error {
    case .dataCorrupted: return "not valid JSON"
    case .keyNotFound(let key, _): return "no `\(key.stringValue)`"
    case .typeMismatch(_, let context), .valueNotFound(_, let context):
      let path = context.codingPath.map(\.stringValue).joined(separator: ".")
      return "wrong value at `\(path)`"
    @unknown default: return "\(error)"
    }
  }
}
