import Foundation

// The command line's stdout is its product, so printing is the point here.
// swiftlint:disable no_print

/// `headless run <files...> [--json] [--out DIR]` and `headless natural APP [--width N]`.
///
/// Exit codes: 0 every scenario passed, 1 an expectation failed, 2 usage or parse error.
package enum CLI {
  static let usage = """
    usage:
      headless run <files...> [--json] [--out DIR]
      headless natural <app> [--width N]
      headless help
    apps: \(DemoRegistry.names.joined(separator: ", "))
    """

  package static func main(arguments: [String]) -> Int32 {
    guard let command = arguments.first else {
      return usageError("missing command")
    }
    switch command {
    case "run":
      return run(Array(arguments.dropFirst()))
    case "natural":
      return natural(Array(arguments.dropFirst()))
    case "help", "--help", "-h":
      print(usage)
      return 0
    default:
      return usageError("unknown command `\(command)`; accepted: run, natural, help")
    }
  }

  private static func run(_ arguments: [String]) -> Int32 {
    var files: [String] = []
    var json = false
    var outDirectory: String?
    var iterator = arguments.makeIterator()
    while let argument = iterator.next() {
      switch argument {
      case "--json":
        json = true
      case "--out":
        guard let directory = iterator.next() else {
          return usageError("--out needs a directory")
        }
        outDirectory = directory
      default:
        if argument.hasPrefix("--") {
          return usageError("unknown flag `\(argument)`; accepted: --json, --out")
        }
        files.append(argument)
      }
    }
    guard !files.isEmpty else {
      return usageError("run needs at least one scenario file")
    }

    var exitCode: Int32 = 0
    for file in files {
      let report: ScenarioReport
      var artifacts: [ShotArtifact] = []
      do {
        guard let data = FileManager.default.contents(atPath: file) else {
          throw ScenarioParseError(file: file, line: 0, message: "cannot read file")
        }
        // swiftlint:disable:next optional_data_string_conversion
        let source = String(decoding: data, as: UTF8.self)
        let scenario = try ScenarioParser.parse(source, file: file)
        (report, artifacts) = ScenarioRunner.execute(scenario, name: file)
        if !report.passed {
          exitCode = max(exitCode, 1)
        }
      } catch let error as ScenarioParseError {
        report = ScenarioReport.parseFailure(error)
        exitCode = 2
      } catch {
        report = ScenarioReport.parseFailure(
          ScenarioParseError(file: file, line: 0, message: "\(error)"))
        exitCode = 2
      }

      print(json ? report.json() : report.human())
      if let outDirectory {
        do {
          try write(artifacts, for: file, into: outDirectory)
        } catch {
          FileHandle.standardError.write(Data("error: \(error)\n".utf8))
          exitCode = 2
        }
      }
    }
    return exitCode
  }

  private static func natural(_ arguments: [String]) -> Int32 {
    var app: String?
    var width = 40
    var iterator = arguments.makeIterator()
    while let argument = iterator.next() {
      if argument == "--width" {
        guard let value = iterator.next(), let parsed = Int(value), parsed >= 1 else {
          return usageError("--width needs a positive integer")
        }
        width = parsed
      } else if app == nil {
        app = argument
      } else {
        return usageError("unexpected argument `\(argument)`")
      }
    }
    guard let app, let measured = DemoRegistry.naturalHeight(app: app, width: width)
    else {
      return usageError(
        "natural needs a registered app; accepted: \(DemoRegistry.names.joined(separator: ", "))"
      )
    }
    print(
      "\(app) width=\(width) probe=\(measured.probe.columns)x\(measured.probe.rows) "
        + "root_rows=\(measured.rows) fills_proposal=\(measured.fillsProposal)")
    return 0
  }

  /// Writes `<dir>/<stem>/<name>.txt` and `.tree.txt`, only when bytes differ.
  private static func write(
    _ artifacts: [ShotArtifact], for file: String, into directory: String
  )
    throws
  {
    let stem = URL(fileURLWithPath: file).deletingPathExtension().lastPathComponent
    let folder = URL(fileURLWithPath: directory).appendingPathComponent(stem)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    for artifact in artifacts {
      for (suffix, text) in [("txt", artifact.text), ("tree.txt", artifact.tree)] {
        let url = folder.appendingPathComponent("\(artifact.name).\(suffix)")
        let data = Data(text.utf8)
        if FileManager.default.contents(atPath: url.path) != data {
          try data.write(to: url)
        }
      }
    }
  }

  private static func usageError(_ message: String) -> Int32 {
    FileHandle.standardError.write(Data("error: \(message)\n\(usage)\n".utf8))
    return 2
  }
}

// swiftlint:enable no_print
