import Tessera
import TesseraTerminalSnapshotSupport

/// JSON projections of the two read-only views the socket serves.
enum Projection {
  /// One string per terminal row with trailing blank cells trimmed.
  ///
  /// A wide glyph is followed by a spacer cell that is indistinguishable from a blank in
  /// `RenderedCell`, so the spacer is skipped by width. The width test below is a stopgap for
  /// the package-level `terminalCellWidth`, which a public-API consumer cannot call.
  static func rows(of snapshot: ScreenSnapshot) -> [String] {
    snapshot.cells.map { row in
      let end = (row.lastIndex { $0 != .blank }).map { $0 + 1 } ?? 0
      var text = ""
      var spacers = 0
      for cell in row[..<end] {
        if spacers > 0 {
          spacers -= 1
          continue
        }
        text.append(cell.character)
        spacers = occupiesTwoCells(cell.character) ? 1 : 0
      }
      return text
    }
  }

  private static func occupiesTwoCells(_ character: Character) -> Bool {
    guard let value = character.unicodeScalars.first?.value else {
      return false
    }
    switch value {
    case 0x1100...0x115F, 0x2E80...0xA4CF, 0xAC00...0xD7A3, 0xF900...0xFAFF, 0xFE30...0xFE6F,
      0xFF00...0xFF60, 0xFFE0...0xFFE6, 0x1F300...0x1F64F, 0x1F900...0x1F9FF, 0x20000...0x3FFFD:
      return true
    default:
      return false
    }
  }

  static func screen(_ snapshot: ScreenSnapshot, frame: Int, size: TerminalSize) -> JSONValue {
    let rows = rows(of: snapshot)
    return .object([
      "frame": .int(frame),
      "rows": .array(rows.map(JSONValue.string)),
      "size": .object(["columns": .int(size.columns), "rows": .int(size.rows)]),
      "text": .string(rows.joined(separator: "\n")),
    ])
  }

  /// `GraphDiagnostics` without durations, so repeated reads of an idle app are identical.
  static func tree(_ diagnostics: GraphDiagnostics) -> JSONValue {
    let statistics = diagnostics.statistics
    return .object([
      "nodes": .array(diagnostics.nodes.map(node)),
      "requirements": requirements(diagnostics.requestedTerminalRequirements),
      "statistics": .object([
        "bodyEvaluations": .int(statistics.bodyEvaluations),
        "equatableSkips": .int(statistics.equatableSkips),
        "leafUpdates": .int(statistics.leafUpdates),
        "measurements": .int(statistics.measurements),
        "nodesCreated": .int(statistics.nodesCreated),
        "nodesDestroyed": .int(statistics.nodesDestroyed),
        "nodesUpdated": .int(statistics.nodesUpdated),
        "placements": .int(statistics.placements),
        "renderedNodes": .int(statistics.renderedNodes),
      ]),
    ])
  }

  private static func node(_ node: NodeDiagnostics) -> JSONValue {
    .object([
      "children": .array(node.childIdentities.map { .string($0.description) }),
      "clip": rect(node.clip),
      "frame": rect(node.frame),
      "handlers": .array(node.handlerKinds.map(JSONValue.string)),
      "id": .string(node.identity.description),
      "measured": node.measuredSize.map(size) ?? .null,
      "needsLayout": .bool(node.needsLayout),
      "needsRender": .bool(node.needsRender),
      "parent": node.parentIdentity.map { .string($0.description) } ?? .null,
      "proposal": node.proposal.map(proposal) ?? .null,
      "type": .string(node.viewType),
    ])
  }

  private static func requirements(_ requirements: TerminalRequirements) -> JSONValue {
    .object([
      "bracketedPaste": .bool(requirements.wantsBracketedPaste),
      "focusReporting": .bool(requirements.wantsFocusReporting),
      "keyboardEnhancement": .bool(requirements.wantsKeyboardEnhancement),
      "mouse": .bool(requirements.wantsMouse),
    ])
  }

  private static func rect(_ rect: Rect) -> JSONValue {
    .object([
      "columns": .int(rect.size.columns),
      "column": .int(rect.origin.column),
      "row": .int(rect.origin.row),
      "rows": .int(rect.size.rows),
    ])
  }

  private static func size(_ size: TerminalSize) -> JSONValue {
    .object(["columns": .int(size.columns), "rows": .int(size.rows)])
  }

  private static func proposal(_ proposal: ProposedSize) -> JSONValue {
    .object([
      "height": proposal.height.map(JSONValue.int) ?? .null,
      "width": proposal.width.map(JSONValue.int) ?? .null,
    ])
  }
}
