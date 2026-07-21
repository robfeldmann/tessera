/// A read-only, local projection of the graph's latest completed pass.
///
/// It intentionally contains no view values, controlled values, node state, closures,
/// input payloads, raw terminal bytes, or borrowed rendering capabilities.
public struct GraphDiagnostics: Equatable, Sendable {
  public let nodes: [NodeDiagnostics]
  public let statistics: GraphStatistics
  public let requestedTerminalRequirements: TerminalRequirements
  public let effectiveTerminalRequirements: TerminalRequirements?

  public init(
    nodes: [NodeDiagnostics],
    statistics: GraphStatistics,
    requestedTerminalRequirements: TerminalRequirements,
    effectiveTerminalRequirements: TerminalRequirements? = nil
  ) {
    self.nodes = nodes
    self.statistics = statistics
    self.requestedTerminalRequirements = requestedTerminalRequirements
    self.effectiveTerminalRequirements = effectiveTerminalRequirements
  }
}
