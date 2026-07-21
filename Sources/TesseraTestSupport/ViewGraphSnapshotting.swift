import SnapshotTesting
import TesseraCore

extension Snapshotting where Value == ViewGraph, Format == String {
  /// Snapshots a concise, deterministic projection of the graph's runtime tree.
  public static var viewGraph: Snapshotting {
    Snapshotting<String, String>.lines.pullback(viewGraphSnapshot)
  }
}

private func viewGraphSnapshot(_ graph: ViewGraph) -> String {
  let diagnostics = graph.diagnostics
  var lines = diagnostics.nodes.map(viewGraphNodeSnapshot)
  lines.append(graphStatisticsSnapshot(diagnostics.statistics))
  lines.append(
    "requirements: requested=\(terminalRequirementsSnapshot(diagnostics.requestedTerminalRequirements))"
      + " effective=\(diagnostics.effectiveTerminalRequirements.map(terminalRequirementsSnapshot) ?? "unavailable")"
  )
  return lines.joined(separator: "\n")
}

private func viewGraphNodeSnapshot(_ node: NodeDiagnostics) -> String {
  let components = node.identity.description.split(separator: "/")
  let indentation = String(repeating: "  ", count: max(components.count - 1, 0))
  let slot = components.last.map(String.init) ?? "root"
  var details: [String] = []

  if let proposal = node.proposal, let measuredSize = node.measuredSize {
    details.append(
      "proposal=(\(proposal.width.map(String.init) ?? "nil"),\(proposal.height.map(String.init) ?? "nil"))"
    )
    details.append("measured=(\(measuredSize.columns)x\(measuredSize.rows))")
    details.append(
      "frame=(\(node.frame.origin.column),\(node.frame.origin.row),\(node.frame.size.columns)x\(node.frame.size.rows))"
    )
    details.append(
      "clip=(\(node.clip.origin.column),\(node.clip.origin.row),\(node.clip.size.columns)x\(node.clip.size.rows))"
    )
  }
  if node.needsLayout {
    details.append("needsLayout")
  }
  if node.needsRender {
    details.append("needsRender")
  }
  if !node.environmentOverrides.isEmpty {
    details.append("environmentOverrides=\(node.environmentOverrides.count)")
  }
  if !node.handlerKinds.isEmpty {
    details.append("handlers=\(node.handlerKinds)")
  }
  if node.requestedTerminalRequirements != TerminalRequirements() {
    details.append(
      "requirements=\(terminalRequirementsSnapshot(node.requestedTerminalRequirements))"
    )
  }

  let suffix = details.isEmpty ? "" : " [\(details.joined(separator: ", "))]"
  return "\(indentation)\(slot) \(conciseViewType(node.viewType))\(suffix)"
}

private func conciseViewType(_ reflectedType: String) -> String {
  let base = reflectedType.prefix { $0 != "<" }
  return base.split(separator: ".").last.map(String.init) ?? String(base)
}

private func graphStatisticsSnapshot(_ statistics: GraphStatistics) -> String {
  let reasons = statistics.invalidationReasons.values.map(\.rawValue)
  return
    "statistics: created=\(statistics.nodesCreated) destroyed=\(statistics.nodesDestroyed)"
    + " updated=\(statistics.nodesUpdated) bodies=\(statistics.bodyEvaluations)"
    + " equatableSkips=\(statistics.equatableSkips) leaves=\(statistics.leafUpdates)"
    + " measurements=\(statistics.measurements) placements=\(statistics.placements)"
    + " renders=\(statistics.renderedNodes) reasons=\(reasons)"
}

private func terminalRequirementsSnapshot(_ requirements: TerminalRequirements) -> String {
  var names: [String] = []
  if requirements.wantsKeyboardEnhancement {
    names.append("keyboard")
  }
  if requirements.wantsMouse {
    names.append("mouse")
  }
  if requirements.wantsBracketedPaste {
    names.append("bracketedPaste")
  }
  if requirements.wantsFocusReporting {
    names.append("focus")
  }
  return "\(names)"
}
