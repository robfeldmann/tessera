import TesseraTerminalBuffer
import TesseraTerminalCore
import TesseraTerminalInput

/// An explicit, synchronous runtime tree reconciled from declarative view values.
public final class ViewGraph {
  private let makeRoot: () -> any View
  private let baseEnvironment: EnvironmentValues
  private lazy var rootNode = buildNode(
    view: makeRoot(),
    identity: .root,
    slot: nil,
    parent: nil,
    environment: baseEnvironment,
    environmentOverrides: []
  )
  private var size: TerminalSize

  /// Work recorded by the most recently completed graph passes.
  public private(set) var statistics = GraphStatistics()

  /// Terminal features declaratively requested by the current graph.
  public var terminalRequirements: TerminalRequirements {
    aggregateRequirements(rootNode)
  }

  /// Whether the graph has changes that require another render pass.
  public var needsRender: Bool {
    rootNode.needsRender
  }

  /// Whether the graph must be measured and placed before rendering.
  public var needsLayout: Bool {
    rootNode.needsLayout
  }

  /// An immutable local projection of the latest graph state.
  public var diagnostics: GraphDiagnostics {
    GraphDiagnostics(
      nodes: diagnosticNodes(rootNode),
      statistics: statistics,
      requestedTerminalRequirements: terminalRequirements,
      effectiveTerminalRequirements: nil
    )
  }

  /// Creates and lowers the initial root value immediately.
  public init<Root: View>(
    root: @escaping () -> Root,
    size: TerminalSize,
    environment: EnvironmentValues = EnvironmentValues()
  ) {
    makeRoot = root
    self.size = Self.sanitized(size)
    baseEnvironment = environment
    _ = rootNode
  }
}

extension ViewGraph {

  /// Re-evaluates the root and reconciles it with the persistent runtime tree.
  public func update() {
    statistics = GraphStatistics()
    statistics.record(.updateRequested)
    let clock = ContinuousClock()
    let start = clock.now
    rootNode = reconcile(
      node: rootNode,
      view: makeRoot(),
      environment: baseEnvironment,
      environmentOverrides: []
    )
    statistics.updateDuration = start.duration(to: clock.now)
  }

  /// Measures and places dirty nodes using the graph's vertical composition rule.
  public func layoutIfNeeded() {
    guard rootNode.needsLayout else {
      return
    }

    statistics.beginLayoutPass()
    let clock = ContinuousClock()
    let start = clock.now
    let proposal = ProposedSize(width: size.columns, height: size.rows)
    _ = measure(rootNode, proposal: proposal)
    let rootFrame = Rect(column: 0, row: 0, columns: size.columns, rows: size.rows)
    place(rootNode, in: rootFrame, clip: rootFrame)
    clearLayoutFlags(rootNode)
    statistics.layoutDuration = start.duration(to: clock.now)
  }

  /// Renders through the borrowed frame capability, laying out first when required.
  public func render(into frame: borrowing Frame) {
    statistics.beginRenderPass()
    statistics.record(.renderRequested)
    if frame.size != size {
      resize(to: frame.size)
    }
    layoutIfNeeded()

    let clock = ContinuousClock()
    let start = clock.now
    render(rootNode, into: frame)
    clearRenderFlags(rootNode)
    statistics.renderDuration = start.duration(to: clock.now)
  }

  /// Changes the graph viewport and invalidates layout only when the size changed.
  public func resize(to size: TerminalSize) {
    let size = Self.sanitized(size)
    guard size != self.size else {
      return
    }
    self.size = size
    statistics.record(.layoutViewportChanged)
    statistics.record(.renderViewportChanged)
    markSubtreeNeedsLayout(rootNode)
  }

  /// Does not route input events and returns `.ignored`.
  public func dispatch(_ event: InputEvent) -> EventDisposition {
    .ignored
  }

  /// Returns a deterministic, value-free textual projection of the runtime tree.
  public func dump() -> String {
    var lines: [String] = []
    appendDump(rootNode, depth: 0, to: &lines)
    let requirements = terminalRequirements
    lines.append(
      "statistics created=\(statistics.nodesCreated) destroyed=\(statistics.nodesDestroyed) "
        + "updated=\(statistics.nodesUpdated) bodies=\(statistics.bodyEvaluations) "
        + "equatableSkips=\(statistics.equatableSkips) leaves=\(statistics.leafUpdates) "
        + "measurements=\(statistics.measurements) placements=\(statistics.placements) "
        + "renders=\(statistics.renderedNodes)"
    )
    lines.append("requirements requested=\(requirements) effective=unavailable")
    return lines.joined(separator: "\n")
  }
}

extension ViewGraph {

  private func buildNode<Content: View>(
    view: Content,
    identity: NodeIdentity,
    slot: _ViewSlot?,
    parent: RuntimeNode?,
    environment: EnvironmentValues,
    environmentOverrides: [String]
  ) -> RuntimeNode {
    let node = RuntimeNode(
      identity: identity,
      slot: slot,
      parent: parent,
      view: view,
      environment: environment,
      environmentOverrides: environmentOverrides
    )
    statistics.nodesCreated += 1

    if node.leafStorage != nil {
      return node
    }

    if let structural = view as? any _StructuralView {
      var children: [_ViewChild] = []
      structural._visitChildren(
        in: environment,
        environmentOverrides: environmentOverrides
      ) { children.append($0) }
      node.children = children.map { child in
        buildNode(
          view: child.view,
          identity: identity.appending(child.slot.description),
          slot: child.slot,
          parent: node,
          environment: child.environment,
          environmentOverrides: child.environmentOverrides
        )
      }
      return node
    }

    statistics.bodyEvaluations += 1
    let body = view.body
    node.children = [
      buildNode(
        view: body,
        identity: identity.appending(_ViewSlot.body.description),
        slot: .body,
        parent: node,
        environment: environment,
        environmentOverrides: environmentOverrides
      )
    ]
    return node
  }

  private func reconcile<Content: View>(
    node: RuntimeNode,
    view: Content,
    environment: EnvironmentValues,
    environmentOverrides: [String]
  ) -> RuntimeNode {
    let sameType = node.viewType == ObjectIdentifier(Content.self)
    let sameEnvironment = node.environment._hasSameStorage(as: environment)
    let erasedContentTypeChanged = hasChangedErasedContentType(
      old: node.view,
      new: view
    )
    let reusedChildEnvironment = reusableChildEnvironment(
      for: node,
      view: view,
      parentEnvironment: environment,
      parentEnvironmentOverrides: environmentOverrides
    )

    if sameType, sameEnvironment, viewsAreEqual(node.view, view) {
      statistics.equatableSkips += 1
      return node
    }

    guard sameType else {
      let parent = node.parent
      let identity = node.identity
      let slot = node.slot
      recordViewInvalidation()
      destroy(node)
      return buildNode(
        view: view,
        identity: identity,
        slot: slot,
        parent: parent,
        environment: environment,
        environmentOverrides: environmentOverrides
      )
    }

    node.view = view
    node.environment = environment
    node.environmentOverrides = environmentOverrides
    statistics.nodesUpdated += 1

    if let leafStorage = node.leafStorage {
      leafStorage.update(from: view)
      statistics.leafUpdates += 1
      recordInvalidation(environmentChanged: !sameEnvironment)
      node.markNeedsLayout()
      return node
    }

    guard let structural = view as? any _StructuralView else {
      statistics.bodyEvaluations += 1
      let child = _ViewChild(
        slot: .body,
        view: view.body,
        environment: environment,
        environmentOverrides: environmentOverrides
      )
      reconcileChildren(of: node, with: [child], discardExisting: false)
      recordInvalidation(environmentChanged: !sameEnvironment)
      node.markNeedsLayout()
      return node
    }

    var children: [_ViewChild] = []
    if let modifier = view as? any _EquatableEnvironmentModifier {
      modifier._visitChildren(
        in: environment,
        environmentOverrides: environmentOverrides,
        reusing: reusedChildEnvironment
      ) { children.append($0) }
    } else {
      structural._visitChildren(
        in: environment,
        environmentOverrides: environmentOverrides
      ) { children.append($0) }
    }
    reconcileChildren(
      of: node,
      with: children,
      discardExisting: erasedContentTypeChanged
    )
    recordInvalidation(environmentChanged: !sameEnvironment)
    node.markNeedsLayout()
    return node
  }

  private func hasChangedErasedContentType(old: any View, new: any View) -> Bool {
    guard
      let old = old as? any _AnyViewIdentityBarrier,
      let new = new as? any _AnyViewIdentityBarrier
    else {
      return false
    }

    return old.erasedContentType != new.erasedContentType
  }

  private func reusableChildEnvironment<Content: View>(
    for node: RuntimeNode,
    view: Content,
    parentEnvironment: EnvironmentValues,
    parentEnvironmentOverrides: [String]
  ) -> EnvironmentValues? {
    guard
      node.environment._hasSameStorage(as: parentEnvironment),
      node.environmentOverrides == parentEnvironmentOverrides,
      let old = node.view as? any _EquatableEnvironmentModifier,
      let new = view as? any _EquatableEnvironmentModifier,
      old._hasSameEnvironmentOverride(as: new),
      node.children.count == 1,
      node.children[0].slot == .index(0)
    else {
      return nil
    }

    return node.children[0].environment
  }

  private func recordViewInvalidation() {
    statistics.record(.layoutViewChanged)
    statistics.record(.renderViewChanged)
  }

  private func recordInvalidation(environmentChanged: Bool) {
    if environmentChanged {
      statistics.record(.layoutEnvironmentChanged)
      statistics.record(.renderEnvironmentChanged)
    } else {
      recordViewInvalidation()
    }
  }

  private func reconcileChildren(
    of node: RuntimeNode,
    with newChildren: [_ViewChild],
    discardExisting: Bool
  ) {
    var remaining = node.children
    var reconciled: [RuntimeNode] = []
    reconciled.reserveCapacity(newChildren.count)

    if discardExisting {
      for child in remaining {
        destroy(child)
      }
      remaining.removeAll(keepingCapacity: true)
    }

    for child in newChildren {
      if let existingIndex = remaining.firstIndex(where: { $0.slot == child.slot }) {
        let existing = remaining.remove(at: existingIndex)
        let updated = reconcile(
          node: existing,
          view: child.view,
          environment: child.environment,
          environmentOverrides: child.environmentOverrides
        )
        updated.parent = node
        reconciled.append(updated)
      } else {
        reconciled.append(
          buildNode(
            view: child.view,
            identity: node.identity.appending(child.slot.description),
            slot: child.slot,
            parent: node,
            environment: child.environment,
            environmentOverrides: child.environmentOverrides
          )
        )
      }
    }

    for removed in remaining {
      destroy(removed)
    }
    node.children = reconciled
  }

  private func destroy(_ node: RuntimeNode) {
    for child in node.children {
      destroy(child)
    }
    statistics.nodesDestroyed += 1
  }

  private func measure(_ node: RuntimeNode, proposal: ProposedSize) -> TerminalSize {
    node.proposal = proposal
    statistics.measurements += 1

    let measured: TerminalSize
    if let leafStorage = node.leafStorage {
      measured = Self.sanitized(
        leafStorage.sizeThatFits(proposal, environment: node.environment)
      )
    } else {
      var width = 0
      var height = 0
      for child in node.children {
        let childSize = measure(
          child,
          proposal: ProposedSize(width: proposal.width, height: nil)
        )
        width = max(width, childSize.columns)
        height += childSize.rows
      }
      measured = TerminalSize(columns: width, rows: height)
    }

    node.measuredSize = measured
    return measured
  }

  private func place(_ node: RuntimeNode, in frame: Rect, clip: Rect) {
    node.frame = frame
    node.clip =
      frame.intersection(clip)
      ?? Rect(column: frame.origin.column, row: frame.origin.row, columns: 0, rows: 0)
    statistics.placements += 1

    var row = frame.origin.row
    for child in node.children {
      let measured = child.measuredSize ?? TerminalSize(columns: 0, rows: 0)
      let childFrame = Rect(
        column: frame.origin.column,
        row: row,
        columns: measured.columns,
        rows: measured.rows
      )
      place(child, in: childFrame, clip: node.clip)
      row += measured.rows
    }
  }

  private func render(_ node: RuntimeNode, into frame: borrowing Frame) {
    if let leafStorage = node.leafStorage, !node.clip.isEmpty {
      frame.withRenderRegion(in: node.frame, clip: node.clip) { region in
        leafStorage.render(in: &region, environment: node.environment)
      }
      statistics.renderedNodes += 1
    }

    for child in node.children {
      render(child, into: frame)
    }
  }

  private func markSubtreeNeedsLayout(_ node: RuntimeNode) {
    node.needsLayout = true
    node.needsRender = true
    for child in node.children {
      markSubtreeNeedsLayout(child)
    }
  }

  private func clearLayoutFlags(_ node: RuntimeNode) {
    node.needsLayout = false
    for child in node.children {
      clearLayoutFlags(child)
    }
  }

  private func clearRenderFlags(_ node: RuntimeNode) {
    node.needsRender = false
    for child in node.children {
      clearRenderFlags(child)
    }
  }

  private func aggregateRequirements(_ node: RuntimeNode) -> TerminalRequirements {
    node.children.reduce(node.terminalRequirements) { result, child in
      .union(result, aggregateRequirements(child))
    }
  }

  private func diagnosticNodes(_ root: RuntimeNode) -> [NodeDiagnostics] {
    var result: [NodeDiagnostics] = []
    appendDiagnostics(root, to: &result)
    return result
  }

  private func appendDiagnostics(_ node: RuntimeNode, to result: inout [NodeDiagnostics]) {
    result.append(
      NodeDiagnostics(
        identity: node.identity,
        viewType: node.viewTypeName,
        parentIdentity: node.parent?.identity,
        childIdentities: node.children.map(\.identity),
        proposal: node.proposal,
        measuredSize: node.measuredSize,
        frame: node.frame,
        clip: node.clip,
        environmentOverrides: node.environmentOverrides,
        handlerKinds: node.handlerKinds,
        requestedTerminalRequirements: node.terminalRequirements,
        needsLayout: node.needsLayout,
        needsRender: node.needsRender
      )
    )
    for child in node.children {
      appendDiagnostics(child, to: &result)
    }
  }

  private func appendDump(_ node: RuntimeNode, depth: Int, to lines: inout [String]) {
    let indent = String(repeating: "  ", count: depth)
    let proposal = node.proposal.map(Self.describe) ?? "unmeasured"
    let measured = node.measuredSize.map(Self.describe) ?? "unmeasured"
    lines.append(
      "\(indent)\(node.identity) \(node.viewTypeName) proposal=\(proposal) "
        + "measured=\(measured) frame=\(Self.describe(node.frame)) "
        + "clip=\(Self.describe(node.clip)) dirty=[layout:\(node.needsLayout),render:\(node.needsRender)] "
        + "environment=\(node.environmentOverrides) handlers=\(node.handlerKinds) "
        + "requirements=\(node.terminalRequirements)"
    )
    for child in node.children {
      appendDump(child, depth: depth + 1, to: &lines)
    }
  }

  private func viewsAreEqual(_ old: any View, _ new: any View) -> Bool {
    if let equatable = old as? any _EquatableView {
      return equatable._isContentEqual(to: new)
    }
    guard let equatable = old as? any Equatable else {
      return false
    }
    return compareEquatable(equatable, to: new)
  }

  private func compareEquatable<Value: Equatable>(
    _ old: Value,
    to new: any View
  ) -> Bool {
    guard let new = new as? Value else {
      return false
    }
    return old == new
  }

}

extension ViewGraph {
  private static func sanitized(_ size: TerminalSize) -> TerminalSize {
    TerminalSize(columns: max(size.columns, 0), rows: max(size.rows, 0))
  }

  private static func describe(_ proposal: ProposedSize) -> String {
    "(\(proposal.width.map(String.init) ?? "nil"),\(proposal.height.map(String.init) ?? "nil"))"
  }

  private static func describe(_ size: TerminalSize) -> String {
    "(\(size.columns)x\(size.rows))"
  }

  private static func describe(_ rect: Rect) -> String {
    "(\(rect.origin.column),\(rect.origin.row),\(rect.size.columns)x\(rect.size.rows))"
  }
}
