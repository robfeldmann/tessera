import Foundation
import SpecimenSupport
import TesseraTerminalCore
import TesseraTerminalSnapshotSupport
import Testing

@testable import SpecimenCaptureSupport
@testable import Tessera

private struct EmptyRoot: View {
  var body: some View { EmptyView() }
}

@Suite
struct ReviewBundleTests {
  @Test
  func `exports multiple checkpoints with safe names and manifest references`() throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let screen = ScreenSnapshot(
      cells: [[cell("A")]], cursor: TerminalPosition(column: 0, row: 0))
    let checkpoints = [
      checkpoint(label: "same/../label", screen: screen, sequence: 7),
      checkpoint(label: "same/../label", screen: screen, sequence: 7),
    ]

    try ReviewBundle.write(
      checkpoints, to: directory, revision: Self.revision, dirty: false,
      specimen: "synthetic")

    let manifest = try readJSON(directory.appendingPathComponent("manifest.json"))
    #expect(manifest["schemaVersion"] as? Int == 3)
    #expect(manifest["status"] as? String == "complete")
    #expect(manifest["complete"] as? Bool == true)
    let entries = try #require(manifest["checkpoints"] as? [[String: Any]])
    #expect(entries.count == 2)
    #expect(entries[0]["sequence"] as? Int == 7)
    #expect(entries[1]["sequence"] as? Int == 7)
    let firstArtifacts = try #require(entries[0]["artifacts"] as? [[String: Any]])
    #expect(firstArtifacts.allSatisfy { ($0["status"] as? String) == "written" })
    #expect(
      FileManager.default.fileExists(
        atPath: directory.appendingPathComponent("checkpoint-0.json").path))
    #expect(
      FileManager.default.fileExists(
        atPath: directory.appendingPathComponent("checkpoint-1.svg").path))
    #expect(!firstArtifacts.contains { ($0["path"] as? String)?.contains("same") == true })
  }

  @Test
  func `retains other checkpoints when an image export fails`() throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let unsupported = ScreenSnapshot(
      cells: [[cell("x", hyperlink: "https://synthetic.invalid")]],
      cursor: TerminalPosition(column: 0, row: 0))
    let valid = ScreenSnapshot(
      cells: [[cell("y")]], cursor: TerminalPosition(column: 0, row: 0))
    let checkpoints = [
      checkpoint(label: "unsupported", screen: unsupported),
      checkpoint(label: "valid", screen: valid),
    ]

    do {
      try ReviewBundle.write(
        checkpoints, to: directory, revision: Self.revision, dirty: false,
        specimen: "synthetic")
      Issue.record("unsupported image unexpectedly succeeded")
    } catch let error as ReviewBundle.Error {
      guard case .artifactExportFailed = error else {
        Issue.record("unexpected bundle error: \(error)")
        return
      }
    }
    let manifest = try readJSON(directory.appendingPathComponent("manifest.json"))
    #expect(manifest["status"] as? String == "artifact-failure")
    let entries = try #require(manifest["checkpoints"] as? [[String: Any]])
    let first = try #require(entries[0]["artifacts"] as? [[String: Any]])
    let second = try #require(entries[1]["artifacts"] as? [[String: Any]])
    #expect(
      first.first { ($0["kind"] as? String) == "image" }?["status"] as? String == "failed")
    #expect(
      second.first { ($0["kind"] as? String) == "image" }?["status"] as? String
        == "written")
    #expect(
      FileManager.default.fileExists(
        atPath: directory.appendingPathComponent("checkpoint-1.json").path))
  }

  @Test
  func `preserves the original capture cause when a diagnostic image fails`() throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let screen = ScreenSnapshot(
      cells: [[cell("x", hyperlink: "https://synthetic.invalid")]],
      cursor: TerminalPosition(column: 0, row: 0))
    let failure = CaptureFailure(
      step: "input", completed: [checkpoint(label: "done", screen: screen)],
      cause: SyntheticError())

    do {
      try ReviewBundle.writeFailure(
        failure, to: directory, revision: Self.revision, dirty: true, specimen: "synthetic"
      )
      Issue.record("unsupported image unexpectedly succeeded")
    } catch let error as ReviewBundle.Error {
      guard case .captureAndArtifactFailure = error else {
        Issue.record("unexpected bundle error: \(error)")
        return
      }
      #expect(error.description.contains("synthetic capture failure"))
    }
    let manifest = try readJSON(directory.appendingPathComponent("manifest.json"))
    #expect(manifest["status"] as? String == "capture-and-artifact-failure")
    #expect(
      FileManager.default.fileExists(
        atPath: directory.appendingPathComponent("failure.json").path))
    let failureJSON = try readJSON(directory.appendingPathComponent("failure.json"))
    #expect(
      (failureJSON["error"] as? String)?.contains("synthetic capture failure") == true)
  }

  @Test
  func `publishes an incomplete manifest when capture fails before a checkpoint`() throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let failure = CaptureFailure(step: "initial", completed: [], cause: SyntheticError())

    try ReviewBundle.writeFailure(
      failure, to: directory, revision: Self.revision, dirty: false, specimen: "synthetic")

    let manifest = try readJSON(directory.appendingPathComponent("manifest.json"))
    #expect(manifest["status"] as? String == "capture-failure")
    #expect(manifest["complete"] as? Bool == false)
    #expect(
      FileManager.default.fileExists(
        atPath: directory.appendingPathComponent("failure.json").path))
  }

  @Test
  func `rejects a populated destination without touching stale files`() throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let stale = directory.appendingPathComponent("manifest.json")
    try Data(#"{"stale":true}"#.utf8).write(to: stale)
    let hidden = directory.appendingPathComponent(".stale")
    try Data("hidden".utf8).write(to: hidden)
    let screen = ScreenSnapshot(
      cells: [[cell("A")]], cursor: TerminalPosition(column: 0, row: 0))

    do {
      try ReviewBundle.write(
        [checkpoint(label: "new", screen: screen)], to: directory,
        revision: Self.revision, dirty: false, specimen: "synthetic")
      Issue.record("populated destination unexpectedly accepted")
    } catch let error as ReviewBundle.Error {
      guard case .destinationAlreadyPopulated = error else {
        Issue.record("unexpected bundle error: \(error)")
        return
      }
    }
    #expect(
      String(data: try Data(contentsOf: stale), encoding: .utf8) == #"{"stale":true}"#)
    #expect(
      String(data: try Data(contentsOf: hidden), encoding: .utf8) == "hidden")
  }

  @Test
  func `reports final manifest publication failure without a false manifest`() throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    var operations = ReviewBundle.FileOperations.live
    operations.write = { data, url in
      if url.lastPathComponent == "manifest.json" { throw SyntheticError() }
      try data.write(to: url, options: .atomic)
    }
    let screen = ScreenSnapshot(
      cells: [[cell("A")]], cursor: TerminalPosition(column: 0, row: 0))

    do {
      try ReviewBundle.write(
        [checkpoint(label: "new", screen: screen)], to: directory,
        revision: Self.revision, dirty: false, specimen: "synthetic",
        operations: operations)
      Issue.record("manifest publication unexpectedly succeeded")
    } catch let error as ReviewBundle.Error {
      guard case .manifestPublicationFailed = error else {
        Issue.record("unexpected bundle error: \(error)")
        return
      }
    }
    #expect(
      !FileManager.default.fileExists(
        atPath: directory.appendingPathComponent("manifest.json").path))
    #expect(
      FileManager.default.fileExists(
        atPath: directory.appendingPathComponent("checkpoint-0.json").path))
  }

  @Test
  func `retains other artifacts when one artifact write fails`() throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    var operations = ReviewBundle.FileOperations.live
    operations.write = { data, url in
      if url.lastPathComponent == "checkpoint-0.graph.txt" { throw SyntheticError() }
      try data.write(to: url, options: .atomic)
    }
    let screen = ScreenSnapshot(
      cells: [[cell("A")]], cursor: TerminalPosition(column: 0, row: 0))

    do {
      try ReviewBundle.write(
        [checkpoint(label: "write-failure", screen: screen)], to: directory,
        revision: Self.revision, dirty: false, specimen: "synthetic",
        operations: operations)
      Issue.record("artifact write failure unexpectedly succeeded")
    } catch let error as ReviewBundle.Error {
      guard case .artifactExportFailed = error else {
        Issue.record("unexpected bundle error: \(error)")
        return
      }
    }
    let manifest = try readJSON(directory.appendingPathComponent("manifest.json"))
    #expect(manifest["complete"] as? Bool == false)
    let entries = try #require(manifest["checkpoints"] as? [[String: Any]])
    let artifacts = try #require(entries[0]["artifacts"] as? [[String: Any]])
    #expect(
      artifacts.first { ($0["kind"] as? String) == "structure" }?["status"] as? String
        == "failed")
    #expect(
      FileManager.default.fileExists(
        atPath: directory.appendingPathComponent("checkpoint-0.json").path))
    #expect(
      FileManager.default.fileExists(
        atPath: directory.appendingPathComponent("checkpoint-0.svg").path))
  }

  @Test
  func `retains the original cause when capture and manifest storage fail`() throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    var operations = ReviewBundle.FileOperations.live
    operations.write = { data, url in
      if ["failure.json", "manifest.json"].contains(url.lastPathComponent) {
        throw SyntheticStorageError()
      }
      try data.write(to: url, options: .atomic)
    }
    let failure = CaptureFailure(
      step: "initial", completed: [], cause: SyntheticError())

    do {
      try ReviewBundle.writeFailure(
        failure, to: directory, revision: Self.revision, dirty: false,
        specimen: "synthetic",
        operations: operations)
      Issue.record("storage failure unexpectedly succeeded")
    } catch let error as ReviewBundle.Error {
      guard case .captureAndArtifactFailure(let capture, _) = error else {
        Issue.record("unexpected bundle error: \(error)")
        return
      }
      #expect(capture.cause is SyntheticError)
    }
    #expect(
      !FileManager.default.fileExists(
        atPath: directory.appendingPathComponent("failure.json").path))
    #expect(
      !FileManager.default.fileExists(
        atPath: directory.appendingPathComponent("manifest.json").path))
  }

  @Test
  func `fails only the malformed checkpoint without claiming completion`() throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let malformed = ScreenSnapshot(
      cells: [[cell("a")], [cell("b"), cell("c")]],
      cursor: TerminalPosition(column: 0, row: 0))
    let valid = ScreenSnapshot(
      cells: [[cell("d")]], cursor: TerminalPosition(column: 0, row: 0))

    do {
      try ReviewBundle.write(
        [
          checkpoint(label: "bad", screen: malformed),
          checkpoint(label: "good", screen: valid),
        ],
        to: directory, revision: Self.revision, dirty: false, specimen: "synthetic")
      Issue.record("malformed snapshot unexpectedly succeeded")
    } catch let error as ReviewBundle.Error {
      guard case .artifactExportFailed = error else {
        Issue.record("unexpected bundle error: \(error)")
        return
      }
    }
    let manifest = try readJSON(directory.appendingPathComponent("manifest.json"))
    #expect(manifest["complete"] as? Bool == false)
    let entries = try #require(manifest["checkpoints"] as? [[String: Any]])
    #expect(entries[0]["status"] as? String == "artifact-failure")
    #expect(entries[1]["status"] as? String == "complete")
  }

  @Test
  func `produces equivalent canonical contents on repeat runs`() throws {
    let first = try temporaryDirectory()
    let second = try temporaryDirectory()
    defer {
      try? FileManager.default.removeItem(at: first)
      try? FileManager.default.removeItem(at: second)
    }
    let screen = ScreenSnapshot(
      cells: [[cell("A")]], cursor: TerminalPosition(column: 0, row: 0))
    let checkpoints = [checkpoint(label: "same", screen: screen, sequence: 4)]
    try ReviewBundle.write(
      checkpoints, to: first, revision: Self.revision, dirty: false, specimen: "synthetic")
    try ReviewBundle.write(
      checkpoints, to: second, revision: Self.revision, dirty: false, specimen: "synthetic"
    )
    let firstFiles = try FileManager.default.contentsOfDirectory(atPath: first.path)
      .sorted()
    let secondFiles = try FileManager.default.contentsOfDirectory(atPath: second.path)
      .sorted()
    #expect(firstFiles == secondFiles)
    for file in firstFiles {
      #expect(
        try Data(contentsOf: first.appendingPathComponent(file))
          == Data(contentsOf: second.appendingPathComponent(file)))
    }
  }

  @Test
  func `records a zero-area snapshot as a valid observation`() throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let screen = ScreenSnapshot(cells: [], cursor: TerminalPosition(column: 0, row: 0))

    try ReviewBundle.write(
      [checkpoint(label: "empty", screen: screen)], to: directory,
      revision: Self.revision, dirty: false, specimen: "synthetic")

    let manifest = try readJSON(directory.appendingPathComponent("manifest.json"))
    #expect(manifest["status"] as? String == "complete")
    #expect(
      FileManager.default.fileExists(
        atPath: directory.appendingPathComponent("checkpoint-0.svg").path))
  }

  @Test
  func `rejects excessive rows as typed input`() throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let screen = ScreenSnapshot(
      cells: Array(repeating: [], count: 4_097),
      cursor: TerminalPosition(column: 0, row: 0))

    do {
      try ReviewBundle.write(
        [checkpoint(label: "too-large", screen: screen)], to: directory,
        revision: Self.revision, dirty: false, specimen: "synthetic")
      Issue.record("excessive snapshot unexpectedly succeeded")
    } catch let error as ReviewBundle.Error {
      guard case .invalidInput = error else {
        Issue.record("unexpected bundle error: \(error)")
        return
      }
    }
    #expect(
      (try? FileManager.default.contentsOfDirectory(atPath: directory.path))?.isEmpty
        == true)
  }

  private static let revision = String(repeating: "a", count: 40)

  private func emptyAutomation() -> AutomationSnapshot {
    ApplicationDriver(size: TerminalSize(columns: 1, rows: 1)) { EmptyRoot() }.graph
      .automationSnapshot
  }

  private func checkpoint(
    label: String, screen: ScreenSnapshot, sequence: Int = 1
  ) -> CapturedCheckpoint {
    CapturedCheckpoint(
      automation: emptyAutomation(), label: label, screen: screen,
      sequence: sequence, state: ["fixture": "synthetic"], structure: "graph",
      inputTrace: ["synthetic"])
  }

  private func cell(_ character: Character, hyperlink: String? = nil) -> RenderedCell {
    RenderedCell(
      character: character, foreground: .default, background: .default, bold: false,
      dim: false,
      italic: false, reverse: false, strikethrough: false, hyperlinkURI: hyperlink)
  }

  private func temporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(
      UUID().uuidString)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
  }

  private func readJSON(_ url: URL) throws -> [String: Any] {
    try #require(
      JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
  }

  private struct SyntheticError: Error, CustomStringConvertible {
    var description: String { "synthetic capture failure" }
  }

  private struct SyntheticStorageError: Error, CustomStringConvertible {
    var description: String { "synthetic storage failure" }
  }
}
