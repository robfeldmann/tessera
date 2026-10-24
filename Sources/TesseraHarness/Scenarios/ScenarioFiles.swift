import Foundation

/// Finds the scenario files a `run` was given.
///
/// A path is a scenario file, which ends in `.scn`, or a directory, which contributes every
/// `.scn` file under it. Directories are walked in sorted order and entries that start with a
/// `.` are skipped, so the order of a run, and so its output, is the same on every machine.
enum ScenarioFiles {
  /// What a path turned into.
  enum Item {
    /// A path that cannot be run, already reported.
    case report(ScenarioReport)

    /// A scenario file to run.
    case scenario(path: String)
  }

  /// The extension every scenario file has.
  static let fileExtension = ".scn"

  static func discover(_ paths: [String]) -> [Item] {
    paths.flatMap { discover($0) }
  }

  private static func discover(_ given: String) -> [Item] {
    let path = trimmed(given)
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) else {
      return [
        .report(
          .failure(scenario: given, verb: "usage", message: "no such file or directory"))
      ]
    }
    if isDirectory.boolValue {
      let files = scenarioFiles(under: path)
      guard !files.isEmpty else {
        return [
          .report(
            .failure(
              scenario: given, verb: "usage",
              message: "no scenario files (*\(fileExtension)) under this directory"))
        ]
      }
      return files.map { .scenario(path: $0) }
    }
    guard path.hasSuffix(fileExtension) else {
      return [
        .report(
          .failure(
            scenario: given, verb: "usage",
            message: "scenario files end in `\(fileExtension)`"))
      ]
    }
    return [.scenario(path: path)]
  }

  /// Every `.scn` file under `directory`, depth first, entries sorted by name.
  private static func scenarioFiles(under directory: String) -> [String] {
    let names = (try? FileManager.default.contentsOfDirectory(atPath: directory)) ?? []
    var files: [String] = []
    for name in names.sorted() where !name.hasPrefix(".") {
      let path = "\(directory)/\(name)"
      var isDirectory: ObjCBool = false
      guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) else {
        continue
      }
      if isDirectory.boolValue {
        files += scenarioFiles(under: path)
      } else if name.hasSuffix(fileExtension) {
        files.append(path)
      }
    }
    return files
  }

  /// `path` without a trailing separator, so joined paths have exactly one.
  private static func trimmed(_ path: String) -> String {
    var path = path
    while path.count > 1, path.hasSuffix("/") {
      path.removeLast()
    }
    return path
  }
}
