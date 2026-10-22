import Foundation
import GraphQuery
import Tessera

let usage = """
  usage:
    graphquery demos
    graphquery project SOURCE [--pretty]
    graphquery query SOURCE LOCATOR...
    graphquery check SOURCE [RULE...]
    graphquery diff BEFORE.json AFTER.json

  SOURCE is `--demo NAME [--size WxH] [--resize WxH]` or `--projection FILE`.
  LOCATOR is one quoted string or one key=value word per argument; keys: \
  \(Locator.acceptedKeys.joined(separator: ", ")).
  RULE is one of \(Rule.allCases.map(\.rawValue).joined(separator: ", ")); default all.

  exit: 0 ok, 1 no match / violations, 2 malformed request
  """

struct UsageError: CustomStringConvertible, Error {
  let description: String
}

func parseSize(_ text: String) throws -> TerminalSize {
  let parts = text.split(separator: "x")
  guard parts.count == 2, let columns = Int(parts[0]), let rows = Int(parts[1]),
    columns > 0, rows > 0
  else {
    throw UsageError(description: "size must be COLUMNSxROWS, got `\(text)`")
  }
  return TerminalSize(columns: columns, rows: rows)
}

/// Removes `--name VALUE` from `arguments` and returns the value.
func takeOption(_ name: String, from arguments: inout [String]) throws -> String? {
  guard let index = arguments.firstIndex(of: name) else {
    return nil
  }
  guard arguments.indices.contains(index + 1) else {
    throw UsageError(description: "\(name) needs a value")
  }
  let value = arguments[index + 1]
  arguments.removeSubrange(index...(index + 1))
  return value
}

func takeFlag(_ name: String, from arguments: inout [String]) -> Bool {
  guard let index = arguments.firstIndex(of: name) else {
    return false
  }
  arguments.remove(at: index)
  return true
}

func loadProjection(_ path: String) throws -> Projection {
  guard let data = FileManager.default.contents(atPath: path) else {
    throw UsageError(description: "cannot read `\(path)`")
  }
  do {
    return try JSONDecoder().decode(Projection.self, from: data)
  } catch {
    throw UsageError(description: "`\(path)` is not a projection: \(error)")
  }
}

/// Resolves SOURCE options to a projection, consuming them from `arguments`.
func source(from arguments: inout [String]) throws -> Projection {
  if let file = try takeOption("--projection", from: &arguments) {
    return try loadProjection(file)
  }
  guard let name = try takeOption("--demo", from: &arguments) else {
    throw UsageError(description: "need --demo NAME or --projection FILE")
  }
  guard let demo = Demo.named(name) else {
    throw UsageError(
      description: "unknown demo `\(name)`; accepted: \(Demo.all.map(\.name).joined(separator: ", "))"
    )
  }
  let size = try takeOption("--size", from: &arguments).map(parseSize) ?? demo.defaultSize
  let resize = try takeOption("--resize", from: &arguments).map(parseSize)
  let session = demo.makeSession(size)
  var projection = session.capture()
  if let resize {
    projection = session.capture(size: resize)
  }
  return projection
}

func emit(_ value: JSONValue, pretty: Bool = false) {
  print(pretty ? value.prettyString() : value.compactString())
}

func run(_ arguments: [String]) throws -> Int32 {
  guard let command = arguments.first else {
    throw UsageError(description: "missing command")
  }
  var rest = Array(arguments.dropFirst())
  switch command {
  case "demos":
    for demo in Demo.all {
      let size = demo.defaultSize
      print("\(demo.name)\t\(size.columns)x\(size.rows)\t\(demo.summary)")
    }
    return 0

  case "project":
    let pretty = takeFlag("--pretty", from: &rest)
    let projection = try source(from: &rest)
    emit(try JSONValue(encoding: projection), pretty: pretty)
    return 0

  case "query":
    let projection = try source(from: &rest)
    let locator =
      rest.count == 1
      ? try Locator(parsing: rest[0])
      : try Locator(clauseTexts: rest)
    let reply = try Report.query(locator, in: projection)
    emit(reply)
    return reply["ok"] == .bool(true) ? 0 : 1

  case "check":
    let projection = try source(from: &rest)
    let rules = rest.isEmpty ? Rule.allCases : try rest.map(Rule.parse)
    let reply = try Report.check(projection, rules: rules)
    emit(reply)
    return reply["ok"] == .bool(true) ? 0 : 1

  case "diff":
    guard rest.count == 2 else {
      throw UsageError(description: "diff needs BEFORE.json AFTER.json")
    }
    emit(try Report.diff(try loadProjection(rest[0]), try loadProjection(rest[1])))
    return 0

  default:
    throw UsageError(description: "unknown command `\(command)`")
  }
}

do {
  exit(try run(Array(CommandLine.arguments.dropFirst())))
} catch {
  emit(Report.failure("\(error)"))
  FileHandle.standardError.write(Data((usage + "\n").utf8))
  exit(2)
}
