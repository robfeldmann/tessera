import Foundation

/// Appends the records of a live session to a file as the steps happen, so a session that ends
/// badly still leaves the steps before it.
///
/// `tessera launch` opens one when `TESSERA_TRACE` names a file. A write that fails stops the
/// writing and is kept in ``failure``, which the command reports once the session is over: the
/// terminal is in the app's hands until then, so a message could not be shown.
@MainActor
final class TraceWriter {
  /// A trace file that cannot be created.
  struct OpenError: Error, CustomStringConvertible {
    var path: String
    var reason: String

    var description: String {
      "cannot create the trace file `\(path)`: \(reason)"
    }
  }

  /// Why the writing stopped, or `nil` while every record has been written.
  private(set) var failure: String?

  private let path: String
  private let handle: FileHandle

  /// Creates `path`, replacing a file that is there, and opens it for appending records.
  init(path: String) throws(OpenError) {
    guard FileManager.default.createFile(atPath: path, contents: Data()) else {
      throw OpenError(path: path, reason: "the file could not be created")
    }
    do {
      handle = try FileHandle(forWritingTo: URL(fileURLWithPath: path))
    } catch {
      throw OpenError(path: path, reason: "\(error)")
    }
    self.path = path
  }

  /// Writes one record as a line.
  func append(_ record: TraceRecord) {
    guard failure == nil else {
      return
    }
    do {
      try handle.write(contentsOf: Data((record.line + "\n").utf8))
    } catch {
      failure = "cannot write the trace file `\(path)`: \(error)"
    }
  }

  /// Closes the file; no record is written after this.
  func close() {
    do {
      try handle.close()
    } catch {
      failure = failure ?? "cannot close the trace file `\(path)`: \(error)"
    }
  }
}
