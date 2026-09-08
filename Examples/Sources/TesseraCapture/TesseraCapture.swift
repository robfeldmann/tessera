import ArgumentParser
import Foundation
import SpecimenCaptureSupport
import Tessera

/// Developer-only command; the wrapper supplies toolchain test-framework search paths.
@main
struct TesseraCapture: AsyncParsableCommand {
  @Argument(help: "The built-in synthetic specimen: layout or button.")
  var specimen: String

  @Argument(help: "The output directory.")
  var output: String

  @Argument(help: "The source Git revision, supplied by the capture wrapper.")
  var revision: String

  @Argument(help: "The source state: clean or dirty, supplied by the capture wrapper.")
  var dirty: String

  mutating func validate() throws {
    guard ["layout", "button"].contains(specimen), revision.count == 40,
      revision.allSatisfy(\.isHexDigit), ["clean", "dirty"].contains(dirty)
    else {
      throw ValidationError(
        "Use scripts/capture-specimen.sh {layout|button} OUTPUT_DIRECTORY.")
    }
  }

  func run() async throws {
    let destination = URL(fileURLWithPath: output, isDirectory: true)
    for size in [TerminalSize(columns: 80, rows: 24), TerminalSize(columns: 40, rows: 16)]
    {
      let viewportDirectory = destination.appendingPathComponent(
        "\(size.columns)x\(size.rows)")
      do {
        let checkpoints =
          specimen == "button"
          ? try await ButtonCapture.run(size: size)
          : try await LayoutCapture.run(size: size)
        try ReviewBundle.write(
          checkpoints, to: viewportDirectory, revision: revision,
          dirty: dirty == "dirty", specimen: specimen
        )
      } catch let failure as CaptureFailure {
        try ReviewBundle.writeFailure(
          failure, to: viewportDirectory, revision: revision,
          dirty: dirty == "dirty", specimen: specimen
        )
        throw failure
      }
    }
  }
}
