import ArgumentParser
import Foundation
import SpecimenCaptureSupport
import SpecimenSupport
import Tessera

/// Developer-only command; the wrapper supplies toolchain test-framework search paths.
@main
struct TesseraCapture: AsyncParsableCommand {
  @Argument(
    help:
      "The registered specimen: layout, button, viewport, settings, collections, panes, navigation, or records."
  )
  var specimen: String

  @Argument(help: "The output directory.")
  var output: String

  @Argument(help: "The source Git revision, supplied by the capture wrapper.")
  var revision: String

  @Argument(help: "The source state: clean or dirty, supplied by the capture wrapper.")
  var dirty: String

  mutating func validate() throws {
    guard SpecimenRegistry.id(specimen) != nil, revision.count == 40,
      revision.allSatisfy(\.isHexDigit), ["clean", "dirty"].contains(dirty)
    else {
      throw ValidationError(
        "Use scripts/capture-specimen.sh {layout|button|viewport|settings|collections|panes|navigation|records} OUTPUT_DIRECTORY."
      )
    }
  }

  func run() async throws {
    guard let id = SpecimenRegistry.id(specimen) else {
      throw ValidationError("Unknown specimen \(specimen).")
    }
    let destination = URL(fileURLWithPath: output, isDirectory: true)
    for size in [TerminalSize(columns: 80, rows: 24), TerminalSize(columns: 40, rows: 16)]
    {
      let viewportDirectory = destination.appendingPathComponent(
        "\(size.columns)x\(size.rows)")
      do {
        let checkpoints: [CapturedCheckpoint]
        switch id {
        case .button:
          checkpoints = try await ButtonCapture.run(size: size)
        case .layout:
          checkpoints = try await LayoutCapture.run(size: size)
        default:
          checkpoints = try await RegisteredCapture.run(id: id, size: size)
        }
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
