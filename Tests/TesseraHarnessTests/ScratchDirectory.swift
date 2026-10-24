import CustomDump
import Foundation

@testable import TesseraHarness

/// The path of `relative` in the directory that holds the source file `file`.
///
/// This splits the compiler's own path string at either separator instead of going through a
/// file URL, whose `path` is not the native spelling on every platform.
func pathBesideSource(_ relative: String, file: String = #filePath) -> String {
  var parts = file.split(omittingEmptySubsequences: false) { $0 == "/" || $0 == "\\" }
  parts.removeLast()
  return (parts + [Substring(relative)]).joined(separator: "/")
}

/// A temporary directory a test fills with scenario files, removed when the test ends.
final class ScratchDirectory: Sendable {
  let path: String

  init() throws {
    path = NSTemporaryDirectory() + "tessera-harness-\(UUID().uuidString)"
    try FileManager.default.createDirectory(
      atPath: path, withIntermediateDirectories: true)
  }

  /// The path of `relative` inside the directory.
  func appending(_ relative: String) -> String {
    "\(path)/\(relative)"
  }

  /// Writes `contents` to `relative`, creating directories, and returns its path.
  @discardableResult
  func write(_ relative: String, _ contents: String) throws -> String {
    let parent = relative.split(separator: "/").dropLast().joined(separator: "/")
    try FileManager.default.createDirectory(
      atPath: appending(parent), withIntermediateDirectories: true)
    let file = appending(relative)
    try Data(contents.utf8).write(to: URL(fileURLWithPath: file))
    return file
  }

  /// The text of `relative`, or `nil` when there is no such file.
  func read(_ relative: String) -> String? {
    FileManager.default.contents(atPath: appending(relative)).flatMap {
      String(validating: $0, as: UTF8.self)
    }
  }

  /// `text` with this directory's path shown as `<scratch>`, so text that names a file in it is
  /// the same in every run.
  ///
  /// A path with backslashes appears in a dump with each one doubled, and in the JSON a dump
  /// holds with each one doubled again, so every spelling of it is replaced, the longest first.
  func redacted(_ text: String) -> String {
    [4, 2, 1].reduce(text) { text, factor in
      let spelled = path.replacingOccurrences(
        of: "\\", with: String(repeating: "\\", count: factor))
      return text.replacingOccurrences(of: spelled, with: "<scratch>")
    }
  }

  /// `value` as a custom dump with the directory's path redacted.
  func dump<Value>(_ value: Value) -> String {
    var text = ""
    customDump(value, to: &text)
    return redacted(text)
  }

  deinit {
    try? FileManager.default.removeItem(atPath: path)
  }
}
