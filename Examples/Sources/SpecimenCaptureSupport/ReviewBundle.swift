import Foundation
import TesseraTerminalSnapshotSupport

/// Explicit local export for built-in synthetic specimens only. No ambient app capture.
package enum ReviewBundle {
  /// Writes deterministic styled cells, structural observations, and candidate SVG frames.
  /// Existing files with these generated names are replaced atomically; unrelated files
  /// are untouched. A partial failure leaves earlier completed frames for diagnosis.
  package static func write(
    _ checkpoints: [CapturedCheckpoint],
    to directory: URL,
    revision: String,
    dirty: Bool,
    specimen: String
  ) throws {
    try FileManager.default.createDirectory(
      at: directory, withIntermediateDirectories: true)
    var frames: [[String: Any]] = []
    for checkpoint in checkpoints {
      let name = "\(checkpoint.sequence)-\(checkpoint.label)"
      let screen = checkpoint.screen
      let projection: [String: Any] = [
        "schemaVersion": 1,
        "sequence": checkpoint.sequence,
        "label": checkpoint.label,
        "state": checkpoint.state,
        "cursor": ["column": screen.cursor.column, "row": screen.cursor.row],
        "cells": screen.cells.map { $0.map(cellProjection) },
      ]
      try json(projection).write(
        to: directory.appendingPathComponent("\(name).json"), options: .atomic)
      try Data(checkpoint.structure.utf8).write(
        to: directory.appendingPathComponent("\(name).graph.txt"), options: .atomic
      )
      let text =
        screen.cells.map { String($0.map(\.character)) }.joined(separator: "\n") + "\n"
      try Data(text.utf8).write(
        to: directory.appendingPathComponent("\(name).txt"), options: .atomic)
      try Data(CellImageExporter.svg(screen).utf8).write(
        to: directory.appendingPathComponent("\(name).svg"), options: .atomic
      )
      frames.append([
        "name": name,
        "columns": screen.cells.first?.count ?? 0,
        "rows": screen.cells.count,
      ])
    }
    let manifest: [String: Any] = [
      "schemaVersion": 1,
      "specimen": specimen,
      "sourceRevision": revision,
      "sourceDirty": dirty,
      "capturePolicy": "explicit-built-in-synthetic-only",
      "profile": "truecolor-no-protocol-modes",
      "seed": NSNull(),
      "exporter": [
        "version": CellImageExporter.Constants.version,
        "cellWidth": CellImageExporter.Constants.cellWidth,
        "cellHeight": CellImageExporter.Constants.cellHeight,
        "fontFamily": CellImageExporter.Constants.fontFamily,
        "defaultForeground": CellImageExporter.Constants.defaultForeground,
        "defaultBackground": CellImageExporter.Constants.defaultBackground,
        "rasterizer": "SVG; viewer-dependent, not a canonical pixel baseline",
        "glyphs": "printable ASCII only; unsupported glyphs and attributes fail",
        "cursor": "coordinate marker only; visibility and shape not observed",
      ],
      "checkpoints": frames,
      "visualApproval": "provisional-not-human-approved",
    ]
    try json(manifest).write(
      to: directory.appendingPathComponent("manifest.json"), options: .atomic)
  }

  private static func json(_ object: Any) throws -> Data {
    try JSONSerialization.data(
      withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
  }

  private static func cellProjection(_ cell: RenderedCell) -> [String: Any] {
    [
      "character": String(cell.character),
      "foreground": color(cell.foreground),
      "background": color(cell.background),
      "bold": cell.bold,
      "dim": cell.dim,
      "italic": cell.italic,
      "reverse": cell.reverse,
      "strikethrough": cell.strikethrough,
      "underlineStyle": String(describing: cell.underlineStyle),
      "underlineColor": color(cell.underlineColor),
      "hyperlink": cell.hyperlinkURI as Any? ?? NSNull(),
    ]
  }

  private static func color(_ color: RenderedColor) -> String {
    switch color {
    case .default: "default"
    case .indexed(let index): "indexed:\(index)"
    case .rgb(let red, let green, let blue): "rgb:\(red),\(green),\(blue)"
    }
  }
}
