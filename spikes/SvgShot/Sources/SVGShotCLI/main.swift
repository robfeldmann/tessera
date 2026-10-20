import Foundation
import SVGShot
import TesseraTerminalSnapshotSupport

private let usage = """
  usage: svgshot [--theme light|dark] [--cursor] [--out PATH]
                 [--input FILE --columns N --rows N]

  Without --input, renders the built-in 80x24 demo screen.
  Without --out, writes the SVG to stdout.

  """

struct Options {
  var theme = "light"
  var showsCursor = false
  var input: String?
  var output: String?
  var columns = 80
  var rows = 24
}

private func fail(_ message: String) -> Never {
  FileHandle.standardError.write(Data("svgshot: \(message)\n\(usage)".utf8))
  exit(2)
}

private func parse(_ arguments: [String]) -> Options {
  var options = Options()
  var index = 0
  func value(for flag: String) -> String {
    index += 1
    guard index < arguments.count else {
      fail("\(flag) needs a value")
    }
    return arguments[index]
  }
  func number(for flag: String) -> Int {
    let text = value(for: flag)
    guard let parsed = Int(text), parsed > 0 else {
      fail("\(flag) needs a positive integer, got \(text)")
    }
    return parsed
  }
  while index < arguments.count {
    switch arguments[index] {
    case "--theme":
      options.theme = value(for: "--theme")
      guard ["light", "dark"].contains(options.theme) else {
        fail("--theme must be light or dark, got \(options.theme)")
      }
    case "--cursor":
      options.showsCursor = true
    case "--input":
      options.input = value(for: "--input")
    case "--out":
      options.output = value(for: "--out")
    case "--columns":
      options.columns = number(for: "--columns")
    case "--rows":
      options.rows = number(for: "--rows")
    case "--help", "-h":
      print(usage, terminator: "")
      exit(0)
    case let unknown:
      fail("unknown argument \(unknown)")
    }
    index += 1
  }
  return options
}

let options = parse(Array(CommandLine.arguments.dropFirst()))

let snapshot: ScreenSnapshot
if let input = options.input {
  do {
    let bytes = [UInt8](try Data(contentsOf: URL(fileURLWithPath: input)))
    let terminal = VirtualTerminal.ghostty(cols: options.columns, rows: options.rows)
    terminal.feed(bytes)
    snapshot = terminal.snapshot()
  } catch {
    fail("cannot read \(input): \(error)")
  }
} else {
  snapshot = DemoScreen.snapshot()
}

let renderer = SVGRenderer(
  palette: options.theme == "dark" ? .dark : .light,
  showsCursor: options.showsCursor
)
let svg = renderer.render(snapshot)

if let output = options.output {
  do {
    try svg.write(toFile: output, atomically: true, encoding: .utf8)
  } catch {
    fail("cannot write \(output): \(error)")
  }
} else {
  print(svg, terminator: "")
}
