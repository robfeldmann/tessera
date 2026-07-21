/// A bounded, value-free cause for work requested from the graph.
public enum GraphInvalidationReason: String, CaseIterable, Hashable, Sendable {
  /// A changed environment storage requires a new layout.
  case layoutEnvironmentChanged
  /// A changed view value requires a new layout.
  case layoutViewChanged
  /// A viewport size change requires a new layout.
  case layoutViewportChanged
  /// A changed environment storage requires rendering.
  case renderEnvironmentChanged
  /// A render pass was explicitly requested.
  case renderRequested
  /// A changed view value requires rendering.
  case renderViewChanged
  /// A viewport size change requires rendering.
  case renderViewportChanged
  /// The root closure was reconciled during an update pass.
  case updateRequested
}

/// A bounded, value-free record describing why the graph's latest work was requested.
///
/// Each reason can appear at most once. The set therefore cannot grow with user input or
/// with the number of reconciled nodes.
public struct GraphInvalidationReasons: Equatable, Sendable {
  private var reasons: Set<GraphInvalidationReason> = []

  /// The recorded causes in a deterministic order.
  public var values: [GraphInvalidationReason] {
    GraphInvalidationReason.allCases.filter(reasons.contains)
  }

  public init() {}

  package mutating func insert(_ reason: GraphInvalidationReason) {
    reasons.insert(reason)
  }
}

/// Work performed by the graph's most recently completed passes.
public struct GraphStatistics: Equatable, Sendable {
  public package(set) var nodesCreated = 0
  public package(set) var nodesDestroyed = 0
  public package(set) var nodesUpdated = 0
  public package(set) var bodyEvaluations = 0
  public package(set) var equatableSkips = 0
  public package(set) var leafUpdates = 0
  public package(set) var measurements = 0
  public package(set) var placements = 0
  public package(set) var renderedNodes = 0
  public package(set) var focusChanges = 0
  public package(set) var terminalRequirementChanges = 0
  /// Value-free causes for the work reported by this snapshot.
  public private(set) var invalidationReasons = GraphInvalidationReasons()

  public package(set) var updateDuration: Duration = .zero
  public package(set) var layoutDuration: Duration = .zero
  public package(set) var renderDuration: Duration = .zero

  public init() {}

  package mutating func record(_ reason: GraphInvalidationReason) {
    invalidationReasons.insert(reason)
  }

  package mutating func beginLayoutPass() {
    measurements = 0
    placements = 0
    layoutDuration = .zero
  }

  package mutating func beginRenderPass() {
    renderedNodes = 0
    renderDuration = .zero
  }

}
