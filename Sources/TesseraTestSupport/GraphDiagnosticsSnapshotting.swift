import SnapshotTesting
import SnapshotTestingCustomDump
import TesseraCore

extension Snapshotting where Value == GraphDiagnostics, Format == String {
  /// Snapshots stable graph diagnostic state while excluding platform-specific pass timing.
  public static var diagnostics: Self {
    Snapshotting<StableGraphDiagnostics, String>.customDump.pullback(
      StableGraphDiagnostics.init
    )
  }
}

private struct StableGraphDiagnostics {
  struct Node {
    struct Proposal {
      let width: Int?
      let height: Int?
    }

    struct Size {
      let columns: Int
      let rows: Int
    }

    struct Rectangle {
      let column: Int
      let row: Int
      let columns: Int
      let rows: Int
    }

    let identity: String
    let viewType: String
    let parentIdentity: String?
    let childIdentities: [String]
    let proposal: Proposal?
    let measuredSize: Size?
    let frame: Rectangle
    let clip: Rectangle
    let environmentOverrideCount: Int
    let handlerKinds: [String]
    let requestedTerminalRequirements: [String]
    let needsLayout: Bool
    let needsRender: Bool

    init(_ node: NodeDiagnostics) {
      identity = node.identity.description
      viewType = conciseViewType(node.viewType)
      parentIdentity = node.parentIdentity?.description
      childIdentities = node.childIdentities.map(\.description)
      proposal = node.proposal.map { Proposal(width: $0.width, height: $0.height) }
      measuredSize = node.measuredSize.map {
        Size(columns: $0.columns, rows: $0.rows)
      }
      frame = Rectangle(
        column: node.frame.origin.column,
        row: node.frame.origin.row,
        columns: node.frame.size.columns,
        rows: node.frame.size.rows
      )
      clip = Rectangle(
        column: node.clip.origin.column,
        row: node.clip.origin.row,
        columns: node.clip.size.columns,
        rows: node.clip.size.rows
      )
      environmentOverrideCount = node.environmentOverrides.count
      handlerKinds = node.handlerKinds
      requestedTerminalRequirements = terminalRequirementsSnapshot(
        node.requestedTerminalRequirements
      )
      needsLayout = node.needsLayout
      needsRender = node.needsRender
    }
  }

  struct Statistics {
    let nodesCreated: Int
    let nodesDestroyed: Int
    let nodesUpdated: Int
    let bodyEvaluations: Int
    let equatableSkips: Int
    let leafUpdates: Int
    let measurements: Int
    let placements: Int
    let renderedNodes: Int
    let focusChanges: Int
    let terminalRequirementChanges: Int
    let invalidationReasons: [String]

    init(_ statistics: GraphStatistics) {
      nodesCreated = statistics.nodesCreated
      nodesDestroyed = statistics.nodesDestroyed
      nodesUpdated = statistics.nodesUpdated
      bodyEvaluations = statistics.bodyEvaluations
      equatableSkips = statistics.equatableSkips
      leafUpdates = statistics.leafUpdates
      measurements = statistics.measurements
      placements = statistics.placements
      renderedNodes = statistics.renderedNodes
      focusChanges = statistics.focusChanges
      terminalRequirementChanges = statistics.terminalRequirementChanges
      invalidationReasons = statistics.invalidationReasons.values.map(\.rawValue)
    }
  }

  enum EffectiveTerminalRequirements {
    case unavailable
    case values([String])
  }

  let nodes: [Node]
  let statistics: Statistics
  let requestedTerminalRequirements: [String]
  let effectiveTerminalRequirements: EffectiveTerminalRequirements

  init(_ diagnostics: GraphDiagnostics) {
    nodes = diagnostics.nodes.map(Node.init)
    statistics = Statistics(diagnostics.statistics)
    requestedTerminalRequirements = terminalRequirementsSnapshot(
      diagnostics.requestedTerminalRequirements
    )
    effectiveTerminalRequirements =
      diagnostics.effectiveTerminalRequirements.map {
        .values(terminalRequirementsSnapshot($0))
      } ?? .unavailable
  }
}

private func conciseViewType(_ reflectedType: String) -> String {
  let base = reflectedType.prefix { $0 != "<" }
  return base.split(separator: ".").last.map(String.init) ?? String(base)
}

private func terminalRequirementsSnapshot(_ requirements: TerminalRequirements) -> [String]
{
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
  return names
}
