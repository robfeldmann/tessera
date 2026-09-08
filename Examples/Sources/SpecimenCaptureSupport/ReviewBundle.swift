import Foundation
import Tessera
import TesseraTerminalSnapshotSupport

/// Explicit local export for built-in synthetic specimens only. No ambient app capture.
/// Artifacts are written atomically one at a time; manifest.json is the final completion record.
package enum ReviewBundle {
  package enum Error: Swift.Error, CustomStringConvertible {
    case artifactExportFailed([ArtifactFailure])
    case captureAndArtifactFailure(capture: CaptureFailure, artifact: any Swift.Error)
    case destinationAlreadyPopulated(URL)
    case destinationNotDirectory(URL)
    case invalidInput(String)
    case manifestPublicationFailed(path: String, reason: String)

    package var description: String {
      switch self {
      case .destinationAlreadyPopulated(let url):
        "capture destination is not fresh: \(url.path) already contains files"
      case .destinationNotDirectory(let url):
        "capture destination is not a directory: \(url.path)"
      case .invalidInput(let reason): "invalid capture input: \(reason)"
      case .artifactExportFailed(let failures):
        "artifact export failed: " + failures.map(\.description).joined(separator: "; ")
      case .manifestPublicationFailed(let path, let reason):
        "final manifest could not be published at \(path): \(reason)"
      case .captureAndArtifactFailure(let capture, let artifact):
        "\(capture); artifact recording also failed: \(artifact)"
      }
    }
  }

  package struct ArtifactFailure: Swift.Error, CustomStringConvertible {
    package let kind: String
    package let path: String
    package let reason: String
    package var description: String { "\(kind) (\(path)): \(reason)" }
  }

  /// Rendering choices are recorded in each manifest. Cursor diagnostics are opt-in.
  package struct Options {
    package var diagnosticCursor: Bool
    package init(diagnosticCursor: Bool = false) {
      self.diagnosticCursor = diagnosticCursor
    }
  }

  /// Focused tests use this seam for deterministic write and publication failures.
  package struct FileOperations: @unchecked Sendable {
    package static let live = Self(
      exists: { FileManager.default.fileExists(atPath: $0.path) },
      isDirectory: {
        var value = ObjCBool(false)
        return FileManager.default.fileExists(atPath: $0.path, isDirectory: &value)
          && value.boolValue
      },
      entries: {
        try FileManager.default.contentsOfDirectory(
          at: $0, includingPropertiesForKeys: nil, options: [])
      },
      createDirectory: {
        try FileManager.default.createDirectory(at: $0, withIntermediateDirectories: true)
      },
      write: { try $0.write(to: $1, options: .atomic) }
    )
    package var exists: (URL) -> Bool
    package var isDirectory: (URL) -> Bool
    package var entries: (URL) throws -> [URL]
    package var createDirectory: (URL) throws -> Void
    package var write: (Data, URL) throws -> Void

    package init(
      exists: @escaping (URL) -> Bool,
      isDirectory: @escaping (URL) -> Bool,
      entries: @escaping (URL) throws -> [URL],
      createDirectory: @escaping (URL) throws -> Void,
      write: @escaping (Data, URL) throws -> Void
    ) {
      self.exists = exists
      self.isDirectory = isDirectory
      self.entries = entries
      self.createDirectory = createDirectory
      self.write = write
    }

  }

  private struct CheckpointResult {
    let manifest: [String: Any]
    let failures: [ArtifactFailure]
  }
  private struct CheckpointReport {
    let checkpoints: [[String: Any]]
    let failures: [ArtifactFailure]
    let failureArtifact: [String: Any]
  }

  private static let maxCheckpoints = 1_024
  private static let maxRows = 4_096
  private static let maxColumns = 4_096
  private static let maxCells = 1_000_000
  private static let maxTextBytes = 4 * 1_024 * 1_024
  private static let maxInputItems = 4_096
  private static let maxOutputEstimate = 64 * 1_024 * 1_024

  /// Existing files are never removed or overwritten as part of run allocation.
  package static func ensureFreshRunDirectory(
    _ directory: URL, operations: FileOperations = .live
  ) throws {
    if operations.exists(directory) {
      guard operations.isDirectory(directory) else {
        throw Error.destinationNotDirectory(directory)
      }
      guard try operations.entries(directory).isEmpty else {
        throw Error.destinationAlreadyPopulated(directory)
      }
    } else {
      try operations.createDirectory(directory)
    }
  }

  package static func write(
    _ checkpoints: [CapturedCheckpoint],
    to directory: URL,
    revision: String,
    dirty: Bool,
    specimen: String,
    options: Options = Options(),
    operations: FileOperations = .live
  ) throws {
    try validateMetadata(checkpoints: checkpoints, revision: revision, specimen: specimen)
    try ensureFreshRunDirectory(directory, operations: operations)
    let report = writeCheckpoints(
      checkpoints, to: directory, options: options, operations: operations)
    try publishManifest(
      report: report, captureFailure: nil, to: directory, revision: revision, dirty: dirty,
      specimen: specimen, options: options, operations: operations)
    guard report.failures.isEmpty else {
      throw Error.artifactExportFailed(report.failures)
    }
  }

  /// Writes completed observations and the original failure summary. Artifact failures are
  /// reported after the final manifest so partial results remain useful and unambiguous.
  package static func writeFailure(
    _ failure: CaptureFailure,
    to directory: URL,
    revision: String,
    dirty: Bool,
    specimen: String,
    options: Options = Options(),
    operations: FileOperations = .live
  ) throws {
    do {
      try validateMetadata(
        checkpoints: failure.completed, revision: revision, specimen: specimen)
      try ensureFreshRunDirectory(directory, operations: operations)
    } catch {
      throw Error.captureAndArtifactFailure(capture: failure, artifact: error)
    }
    let captureCause = String(describing: failure.cause)
    guard failure.step.utf8.count <= maxTextBytes, captureCause.utf8.count <= maxTextBytes
    else {
      throw Error.captureAndArtifactFailure(
        capture: failure,
        artifact: Error.invalidInput("capture failure metadata is too large"))
    }
    var failures: [ArtifactFailure] = []
    let failureFile = "failure.json"
    let failureArtifact: [String: Any]
    do {
      let summary: [String: Any] = [
        "schemaVersion": 3, "status": "capture-failure", "failedStep": failure.step,
        "completedCheckpoints": failure.completed.count,
        "error": captureCause,
      ]
      try operations.write(
        try json(summary), directory.appendingPathComponent(failureFile))
      failureArtifact = [
        "kind": "capture-failure", "path": failureFile,
        "status": "written", "produced": true,
      ]
    } catch {
      let result = ArtifactFailure(
        kind: "capture-failure", path: failureFile, reason: errorDescription(error))
      failures.append(result)
      failureArtifact = [
        "kind": result.kind, "path": result.path, "status": "failed",
        "produced": false, "error": result.reason,
      ]
    }
    let checkpoints = writeCheckpoints(
      failure.completed, to: directory, options: options, operations: operations)
    failures.append(contentsOf: checkpoints.failures)
    let report = CheckpointReport(
      checkpoints: checkpoints.checkpoints, failures: failures,
      failureArtifact: failureArtifact)
    do {
      try publishManifest(
        report: report, captureFailure: failure, to: directory, revision: revision,
        dirty: dirty,
        specimen: specimen, options: options, operations: operations)
    } catch {
      throw Error.captureAndArtifactFailure(capture: failure, artifact: error)
    }
    guard failures.isEmpty else {
      throw Error.captureAndArtifactFailure(
        capture: failure, artifact: Error.artifactExportFailed(failures))
    }
  }

  private static func writeCheckpoints(
    _ checkpoints: [CapturedCheckpoint],
    to directory: URL,
    options: Options,
    operations: FileOperations
  ) -> CheckpointReport {
    var manifests: [[String: Any]] = []
    var failures: [ArtifactFailure] = []
    for (index, checkpoint) in checkpoints.enumerated() {
      let result = writeCheckpoint(
        checkpoint, index: index, to: directory, options: options, operations: operations)
      manifests.append(result.manifest)
      failures.append(contentsOf: result.failures)
    }
    return CheckpointReport(
      checkpoints: manifests, failures: failures, failureArtifact: [:])
  }

  private static func writeCheckpoint(
    _ checkpoint: CapturedCheckpoint,
    index: Int,
    to directory: URL,
    options: Options,
    operations: FileOperations
  ) -> CheckpointResult {
    let stem = "checkpoint-\(index)"
    let files = [
      ("cells", "\(stem).json"), ("structure", "\(stem).graph.txt"),
      ("input-trace", "\(stem).input.txt"), ("text", "\(stem).txt"),
      ("image", "\(stem).svg"),
    ]
    var artifacts: [[String: Any]] = []
    var failures: [ArtifactFailure] = []
    if let reason = validateCheckpoint(checkpoint) {
      for (kind, file) in files {
        let result = ArtifactFailure(kind: kind, path: file, reason: reason)
        failures.append(result)
        artifacts.append([
          "kind": kind, "path": file, "status": "failed",
          "produced": false, "error": reason,
        ])
      }
      return CheckpointResult(
        manifest: checkpointManifest(checkpoint, artifacts: artifacts, failures: failures),
        failures: failures)
    }

    let screen = checkpoint.screen
    let projection: [String: Any] = [
      "schemaVersion": 3,
      "automation": checkpoint.automation.elements.map(automationProjection),
      "sequence": checkpoint.sequence, "label": checkpoint.label,
      "state": checkpoint.state,
      "inputTrace": checkpoint.inputTrace,
      "cursor": ["column": screen.cursor.column, "row": screen.cursor.row],
      "cells": screen.cells.map { $0.map(cellProjection) },
    ]
    attempt(
      kind: files[0].0, file: files[0].1, to: directory, operations: operations,
      makeData: { try json(projection) }, artifacts: &artifacts, failures: &failures)
    attempt(
      kind: files[1].0, file: files[1].1, to: directory, operations: operations,
      makeData: { Data(checkpoint.structure.utf8) }, artifacts: &artifacts,
      failures: &failures)
    attempt(
      kind: files[2].0, file: files[2].1, to: directory, operations: operations,
      makeData: {
        Data(checkpoint.inputTrace.joined(separator: "\n").appending("\n").utf8)
      },
      artifacts: &artifacts, failures: &failures)
    attempt(
      kind: files[3].0, file: files[3].1, to: directory, operations: operations,
      makeData: {
        Data(
          screen.cells.map { String($0.map(\.character)) }.joined(separator: "\n")
            .appending("\n").utf8)
      }, artifacts: &artifacts, failures: &failures)
    attempt(
      kind: files[4].0, file: files[4].1, to: directory, operations: operations,
      makeData: {
        Data(
          try CellImageExporter.svg(
            screen,
            options: CellImageExporter.Options(diagnosticCursor: options.diagnosticCursor)
          ).utf8)
      },
      artifacts: &artifacts, failures: &failures)
    return CheckpointResult(
      manifest: checkpointManifest(checkpoint, artifacts: artifacts, failures: failures),
      failures: failures)
  }

  private static func attempt(
    kind: String,
    file: String,
    to directory: URL,
    operations: FileOperations,
    makeData: () throws -> Data,
    artifacts: inout [[String: Any]],
    failures: inout [ArtifactFailure]
  ) {
    do {
      try operations.write(makeData(), directory.appendingPathComponent(file))
      artifacts.append(["kind": kind, "path": file, "status": "written", "produced": true])
    } catch {
      let result = ArtifactFailure(kind: kind, path: file, reason: errorDescription(error))
      failures.append(result)
      artifacts.append([
        "kind": kind, "path": file, "status": "failed", "produced": false,
        "error": result.reason,
      ])
    }
  }

  private static func checkpointManifest(
    _ checkpoint: CapturedCheckpoint,
    artifacts: [[String: Any]],
    failures: [ArtifactFailure]
  ) -> [String: Any] {
    [
      "sequence": checkpoint.sequence, "label": checkpoint.label,
      "status": failures.isEmpty ? "complete" : "artifact-failure", "artifacts": artifacts,
    ]
  }

  private static func publishManifest(
    report: CheckpointReport,
    captureFailure: CaptureFailure?,
    to directory: URL,
    revision: String,
    dirty: Bool,
    specimen: String,
    options: Options,
    operations: FileOperations
  ) throws {
    let status: String
    if captureFailure != nil {
      status = report.failures.isEmpty ? "capture-failure" : "capture-and-artifact-failure"
    } else {
      status = report.failures.isEmpty ? "complete" : "artifact-failure"
    }
    let manifest: [String: Any] = [
      "schemaVersion": 3, "status": status, "complete": status == "complete",
      "specimen": specimen, "sourceRevision": revision, "sourceDirty": dirty,
      "capturePolicy": "explicit-built-in-synthetic-only",
      "privacy":
        "Only explicitly selected synthetic specimen checkpoints are exported; cells, state, traces, identifiers, errors, and hyperlinks are content and are not generally sanitized.",
      "exporter": exporterMetadata(options: options), "checkpoints": report.checkpoints,
      "captureFailure": captureFailure.map {
        [
          "failedStep": $0.step,
          "completedCheckpoints": $0.completed.count,
          "error": captureCauseDescription($0),
        ]
      } ?? NSNull(),
      "failureArtifact": report.failureArtifact.isEmpty
        ? NSNull() : report.failureArtifact,
      "artifactFailures": report.failures.map {
        ["kind": $0.kind, "path": $0.path, "error": $0.reason]
      },
      "publication": [
        "manifest": "manifest.json", "writtenLast": true,
        "transaction": "not atomic across the directory; require complete=true",
      ],
      "visualApproval": "provisional-not-human-approved",
    ]
    let path = directory.appendingPathComponent("manifest.json")
    do { try operations.write(try json(manifest), path) } catch {
      throw Error.manifestPublicationFailed(
        path: path.path, reason: errorDescription(error))
    }
  }

  private static func exporterMetadata(options: Options) -> [String: Any] {
    [
      "version": CellImageExporter.Constants.version,
      "cellWidth": CellImageExporter.Constants.cellWidth,
      "cellHeight": CellImageExporter.Constants.cellHeight,
      "fontFamily": CellImageExporter.Constants.fontFamily,
      "fontSize": CellImageExporter.Constants.fontSize,
      "baselineOffset": CellImageExporter.Constants.baselineOffset,
      "defaultForeground": CellImageExporter.Constants.defaultForeground,
      "defaultBackground": CellImageExporter.Constants.defaultBackground,
      "defaultPalette": CellImageExporter.Constants.defaultPalette,
      "rasterizer": "SVG; viewer-dependent, not a canonical pixel baseline",
      "glyphs":
        "Unicode graphemes use canonical terminal cell widths; unsupported attributes fail",
      "options": ["diagnosticCursor": options.diagnosticCursor],
      "overlays": options.diagnosticCursor ? ["cursor-coordinate-only"] : [],
      "cursor": "coordinate marker only; visibility, shape, and blinking are not observed",
    ]
  }

  private static func validateMetadata(
    checkpoints: [CapturedCheckpoint], revision: String, specimen: String
  ) throws {
    guard checkpoints.count <= maxCheckpoints else {
      throw Error.invalidInput("checkpoint count exceeds \(maxCheckpoints)")
    }
    guard revision.utf8.count <= 256 else {
      throw Error.invalidInput("source revision is too large")
    }
    guard specimen.utf8.count <= maxTextBytes else {
      throw Error.invalidInput("specimen label is too large")
    }
    var estimate = 0
    func addEstimate(_ bytes: Int) throws {
      let (next, overflow) = estimate.addingReportingOverflow(bytes)
      guard !overflow, next <= maxOutputEstimate else {
        throw Error.invalidInput(
          "estimated bundle output exceeds \(maxOutputEstimate) bytes")
      }
      estimate = next
    }
    try addEstimate(revision.utf8.count)
    try addEstimate(specimen.utf8.count)
    for checkpoint in checkpoints {
      let rows = checkpoint.screen.cells.count
      guard rows <= maxRows else {
        throw Error.invalidInput("row count exceeds \(maxRows)")
      }
      let columns = checkpoint.screen.cells.first?.count ?? 0
      guard columns <= maxColumns else {
        throw Error.invalidInput("column count exceeds \(maxColumns)")
      }
      var boundedCellCount = 0
      for row in checkpoint.screen.cells {
        let (next, overflow) = boundedCellCount.addingReportingOverflow(row.count)
        guard !overflow, next <= maxCells else {
          throw Error.invalidInput("cell count exceeds \(maxCells)")
        }
        boundedCellCount = next
      }
      let (cellEstimate, cellOverflow) = boundedCellCount.multipliedReportingOverflow(
        by: 512)
      guard !cellOverflow else {
        throw Error.invalidInput("estimated bundle output overflows")
      }
      try addEstimate(cellEstimate)
      for row in checkpoint.screen.cells {
        for cell in row {
          try addEstimate(String(cell.character).utf8.count)
          if let hyperlink = cell.hyperlinkURI {
            guard hyperlink.utf8.count <= maxTextBytes else {
              throw Error.invalidInput("hyperlink is too large")
            }
            try addEstimate(hyperlink.utf8.count)
          }
        }
      }
      guard checkpoint.automation.elements.count <= maxInputItems else {
        throw Error.invalidInput("automation element count exceeds \(maxInputItems)")
      }
      for element in checkpoint.automation.elements {
        let identifierBytes = element.identifier.utf8.count
        guard identifierBytes <= maxTextBytes else {
          throw Error.invalidInput("automation identifier is too large")
        }
        try addEstimate(identifierBytes)
        let nodeIdentityBytes = element.nodeIdentity.description.utf8.count
        guard nodeIdentityBytes <= maxTextBytes else {
          throw Error.invalidInput("automation node identity is too large")
        }
        try addEstimate(nodeIdentityBytes)
        guard element.activationKeys.count <= maxInputItems else {
          throw Error.invalidInput("activation key count exceeds \(maxInputItems)")
        }
        for key in element.activationKeys {
          guard key.utf8.count <= maxTextBytes else {
            throw Error.invalidInput("activation key is too large")
          }
          try addEstimate(key.utf8.count)
        }
      }
      guard checkpoint.label.utf8.count <= maxTextBytes else {
        throw Error.invalidInput("checkpoint label is too large")
      }
      try addEstimate(checkpoint.label.utf8.count)
      guard checkpoint.state.count <= maxInputItems else {
        throw Error.invalidInput("checkpoint state has too many entries")
      }
      for (key, value) in checkpoint.state {
        guard key.utf8.count <= maxTextBytes, value.utf8.count <= maxTextBytes else {
          throw Error.invalidInput("checkpoint state value is too large")
        }
        try addEstimate(key.utf8.count)
        try addEstimate(value.utf8.count)
      }
      guard checkpoint.inputTrace.count <= maxInputItems else {
        throw Error.invalidInput("input trace has too many entries")
      }
      for item in checkpoint.inputTrace {
        guard item.utf8.count <= maxTextBytes else {
          throw Error.invalidInput("input trace item is too large")
        }
        try addEstimate(item.utf8.count)
      }
      guard checkpoint.structure.utf8.count <= maxTextBytes else {
        throw Error.invalidInput("graph diagnostics are too large")
      }
      try addEstimate(checkpoint.structure.utf8.count)
    }
  }

  private static func validateCheckpoint(_ checkpoint: CapturedCheckpoint) -> String? {
    let rows = checkpoint.screen.cells.count
    guard rows <= maxRows else {
      return "row count exceeds \(maxRows)"
    }
    let columns = checkpoint.screen.cells.first?.count ?? 0
    guard columns <= maxColumns else {
      return "column count exceeds \(maxColumns)"
    }
    var count = 0
    for (row, cells) in checkpoint.screen.cells.enumerated() {
      guard cells.count == columns else {
        return "row \(row) has \(cells.count) cells; expected \(columns)"
      }
      let (next, overflow) = count.addingReportingOverflow(cells.count)
      guard !overflow, next <= maxCells else {
        return "cell count exceeds \(maxCells)"
      }
      count = next
      for cell in cells {
        guard String(cell.character).utf8.count <= maxTextBytes else {
          return "cell grapheme is too large"
        }
        if let hyperlink = cell.hyperlinkURI, hyperlink.utf8.count > maxTextBytes {
          return "hyperlink is too large"
        }
      }
    }
    return nil
  }

  private static func automationProjection(_ element: AutomationElement) -> [String: Any] {
    [
      "identifier": element.identifier, "role": element.role.rawValue,
      "nodeIdentity": element.nodeIdentity.description,
      "frame": [
        element.frame.origin.column, element.frame.origin.row, element.frame.size.columns,
        element.frame.size.rows,
      ],
      "clip": [
        element.clip.origin.column, element.clip.origin.row, element.clip.size.columns,
        element.clip.size.rows,
      ],
      "enabled": element.isEnabled, "focused": element.isFocused,
      "activationKeys": element.activationKeys,
    ]
  }

  private static func cellProjection(_ cell: RenderedCell) -> [String: Any] {
    [
      "character": String(cell.character), "foreground": color(cell.foreground),
      "background": color(cell.background), "bold": cell.bold, "dim": cell.dim,
      "italic": cell.italic, "reverse": cell.reverse, "strikethrough": cell.strikethrough,
      "underlineStyle": underlineStyle(cell.underlineStyle),
      "underlineColor": color(cell.underlineColor),
      "hyperlink": cell.hyperlinkURI as Any? ?? NSNull(),
    ]
  }

  private static func underlineStyle(_ style: UnderlineStyle) -> String {
    switch style {
    case .none: "none"
    case .single: "single"
    case .double: "double"
    case .curly: "curly"
    case .dashed: "dashed"
    case .dotted: "dotted"
    }
  }

  private static func color(_ color: RenderedColor) -> String {
    switch color {
    case .default: "default"
    case .indexed(let index): "indexed:\(index)"
    case .rgb(let red, let green, let blue): "rgb:\(red),\(green),\(blue)"
    }
  }

  private static func json(_ object: Any) throws -> Data {
    try JSONSerialization.data(
      withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
  }

  private static func captureCauseDescription(_ failure: CaptureFailure) -> String {
    let description = String(describing: failure.cause)
    guard description.utf8.count > maxTextBytes else {
      return description
    }
    return String(bytes: description.utf8.prefix(maxTextBytes), encoding: .utf8) ?? ""
  }

  private static func errorDescription(_ error: any Swift.Error) -> String {
    String(describing: error)
  }
}
