import Foundation
import SpecimenCaptureSupport
import Tessera

/// Developer-only command; the wrapper supplies toolchain test-framework search paths.
@main
enum TesseraCapture {
  enum CommandError: Error, CustomStringConvertible {
    case usage

    var description: String {
      "Usage: scripts/capture-specimen.sh {layout|button} OUTPUT_DIRECTORY"
    }
  }

  static func main() async throws {
    let arguments = Array(CommandLine.arguments.dropFirst())
    guard arguments.count == 4,
      ["layout", "button"].contains(arguments[0]),
      arguments[2].count == 40,
      arguments[2].allSatisfy(\.isHexDigit),
      ["clean", "dirty"].contains(arguments[3])
    else {
      throw CommandError.usage
    }
    let destination = URL(fileURLWithPath: arguments[1], isDirectory: true)
    for size in [TerminalSize(columns: 80, rows: 24), TerminalSize(columns: 40, rows: 16)]
    {
      let checkpoints =
        arguments[0] == "button"
        ? try await ButtonCapture.run(size: size)
        : try await LayoutCapture.run(size: size)
      try ReviewBundle.write(
        checkpoints,
        to: destination.appendingPathComponent("\(size.columns)x\(size.rows)"),
        revision: arguments[2],
        dirty: arguments[3] == "dirty",
        specimen: arguments[0]
      )
    }
  }
}
