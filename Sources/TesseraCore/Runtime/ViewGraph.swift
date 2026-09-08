import TesseraTerminalBuffer
import TesseraTerminalCore
import TesseraTerminalInput

private struct _LayoutMeasurementKey: Hashable {
  let node: ObjectIdentifier
  let proposal: ProposedSize
}

private struct _LayoutPlacement {
  let origin: TerminalPosition
  let proposal: ProposedSize
  let clip: Rect?
}

private final class _LayoutPlacementCollector {
  var placements: [ObjectIdentifier: _LayoutPlacement] = [:]
}

/// An explicit, synchronous runtime tree reconciled from declarative view values.
public final class ViewGraph {
  private let makeRoot: () -> any View
  private let baseEnvironment: EnvironmentValues
  private lazy var rootNode = buildNode(
    view: makeRoot(),
    identity: .root,
    slot: nil,
    parent: nil,
    environment: rootEnvironment(),
    environmentOverrides: []
  )
  private var size: TerminalSize
  private var layoutMeasurements: [_LayoutMeasurementKey: TerminalSize] = [:]
  private var focusBindings: [_FocusBindingRegistration] = []
  private var focusRestorationGroups: [NodeIdentity: _FocusRestorationGroupState] = [:]
  private var focusReturnCandidates: [NodeIdentity: [AnyHashable: FocusID]] = [:]
  private var focusAppearanceHost: RuntimeNode?
  private var focusAppearanceUsesFallback = false
  private var focusAppearanceNeedsResolution = true
  private var publishedFocusedID: FocusID?
  private weak var publishedFocusedNode: RuntimeNode?
  /// Focus state and live document-order identities owned by this graph.
  public let focus = FocusManager()
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

  /// Reads explicitly annotated semantics without updating, laying out, or rendering.
  /// Bounds describe the last completed layout and may be stale while needsLayout is true.
  /// No application values, closures, or unannotated labels are reflected.
  public var automationSnapshot: AutomationSnapshot {
    let focusedNode = focus.focused.flatMap { firstNode(withFocusID: $0, in: rootNode) }
    var elements: [AutomationElement] = []
    appendAutomation(rootNode, focusedNode: focusedNode, to: &elements)
    return AutomationSnapshot(elements: elements)
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
    focus.onChange = { [weak self] _ in
      self?.focusDidChange()
    }
    _ = rootNode
    refreshInteractionState()
  }
}

extension ViewGraph {

  /// Re-evaluates the root and reconciles it with the persistent runtime tree.
  public func update() {
    let previousRequirements = terminalRequirements
    statistics = GraphStatistics()
    statistics.record(.updateRequested)
    let clock = ContinuousClock()
    let start = clock.now
    rootNode = reconcile(
      node: rootNode,
      view: makeRoot(),
      environment: rootEnvironment(),
      environmentOverrides: []
    )
    refreshInteractionState()
    if terminalRequirements != previousRequirements {
      statistics.terminalRequirementChanges += 1
    }
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
    layoutMeasurements = prunedMeasurements(root: rootNode)
    let proposal = ProposedSize(width: size.columns, height: size.rows)
    _ = measure(rootNode, proposal: proposal)
    let rootFrame = Rect(column: 0, row: 0, columns: size.columns, rows: size.rows)
    place(rootNode, in: rootFrame, clip: rootFrame)
    clearLayoutFlags(rootNode)
    refreshLayoutDependentFocusIDs()
    resolveFocusAppearanceIfNeeded()
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
    resolveFocusAppearanceIfNeeded()

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
    focusAppearanceNeedsResolution = true
    markSubtreeNeedsLayout(rootNode)
  }

  /// Routes focused key and paste events leaf-first through ancestor responders.
  public func dispatch(_ event: InputEvent) -> EventDisposition {
    guard event.isRoutableResponderEvent else {
      return .ignored
    }
    layoutIfNeeded()
    guard
      let focusedID = focus.focused,
      let focusNode = firstNode(withFocusID: focusedID, in: rootNode)
    else {
      return .ignored
    }

    var node: RuntimeNode? = deepestResponder(in: focusNode) ?? focusNode
    while let current = node {
      var context = ResponderContext(
        nodeBounds: current.frame,
        isFocused: isDescendant(current, of: focusNode),
        isFocusWithin: isDescendant(focusNode, of: current),
        requestFocus: { [weak self] id in self?.focus.focus(id) },
        requestFocusAdvance: { [weak self] direction in self?.focus.advance(direction) }
      )

      var disposition: EventDisposition = .ignored
      if let responderStorage = current.responderStorage {
        disposition = responderStorage.handleEvent(event, context: &context)
      } else if let leafStorage = current.leafStorage {
        disposition = leafStorage.handleEvent(event, context: &context)
      }
      if disposition == .ignored,
        case .key(let key) = event,
        let handler = current.view as? any _KeyHandlerView
      {
        disposition = handler._handleKey(key, context: &context)
      }

      apply(context, to: current)
      if disposition == .handled {
        return .handled
      }
      node = current.parent
    }
    return .ignored
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
    let sameEnvironment =
      node.environment._hasSameStorage(as: environment)
      || node.environment._hasEqualValues(as: environment)
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
    node.updateInteractionMetadata(from: view)
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
    let key = _LayoutMeasurementKey(node: ObjectIdentifier(node), proposal: proposal)
    if let cached = layoutMeasurements[key] {
      node.proposal = proposal
      node.measuredSize = cached
      return cached
    }

    node.proposal = proposal
    statistics.measurements += 1

    let measured: TerminalSize
    if let leafStorage = node.leafStorage {
      measured = Self.sanitized(
        leafStorage.sizeThatFits(proposal, environment: node.environment)
      )
    } else if let layout = node.view as? any _LayoutView {
      measured = Self.sanitized(
        layout._sizeThatFits(
          proposal,
          subviews: makeLayoutSubviews(for: node, collector: nil)
        )
      )
    } else {
      var width = 0
      var height = 0
      for child in node.children {
        let childProposal =
          forwardsCompleteProposal(to: child)
          ? proposal
          : ProposedSize(width: proposal.width, height: nil)
        let childSize = measure(child, proposal: childProposal)
        width = max(width, childSize.columns)
        height = max(height, childSize.rows)
      }
      measured = TerminalSize(columns: width, rows: height)
    }

    layoutMeasurements[key] = measured
    node.measuredSize = measured
    return measured
  }

  /// Keeps cached measurements only for live nodes that are not pending re-layout.
  ///
  /// Dirty nodes (and their ancestors) drop their entries so they re-measure, while
  /// clean subtrees — such as the many rows inside a scrolling viewport — reuse theirs.
  private func prunedMeasurements(
    root: RuntimeNode
  ) -> [_LayoutMeasurementKey: TerminalSize] {
    var reusable: Set<ObjectIdentifier> = []
    collectReusableMeasurementNodes(root, into: &reusable)
    return layoutMeasurements.filter { reusable.contains($0.key.node) }
  }

  private func collectReusableMeasurementNodes(
    _ node: RuntimeNode,
    into set: inout Set<ObjectIdentifier>
  ) {
    if !node.needsLayout {
      set.insert(ObjectIdentifier(node))
    }
    for child in node.children {
      collectReusableMeasurementNodes(child, into: &set)
    }
  }

  private func forwardsCompleteProposal(to node: RuntimeNode) -> Bool {
    if node.view is any _LayoutView {
      return true
    }
    guard node.children.count == 1, let child = node.children.first else {
      return false
    }
    return forwardsCompleteProposal(to: child)
  }

  private func place(_ node: RuntimeNode, in frame: Rect, clip: Rect) {
    node.frame = frame
    node.clip =
      frame.intersection(clip)
      ?? Rect(column: frame.origin.column, row: frame.origin.row, columns: 0, rows: 0)
    statistics.placements += 1

    guard let layout = node.view as? any _LayoutView else {
      for child in node.children {
        let childFrame =
          child.view is any _LayoutView
          ? frame
          : Rect(
            origin: frame.origin,
            size: child.measuredSize ?? TerminalSize(columns: 0, rows: 0)
          )
        place(child, in: childFrame, clip: node.clip)
      }
      return
    }

    let collector = _LayoutPlacementCollector()
    let proposal =
      node.proposal
      ?? ProposedSize(width: frame.size.columns, height: frame.size.rows)
    layout._placeSubviews(
      in: frame,
      proposal: proposal,
      subviews: makeLayoutSubviews(for: node, collector: collector)
    )

    for child in node.children {
      guard let placement = collector.placements[ObjectIdentifier(child)] else {
        let hidden = Rect(
          origin: frame.origin,
          size: TerminalSize(columns: 0, rows: 0)
        )
        place(child, in: hidden, clip: node.clip)
        continue
      }

      let childSize = measure(child, proposal: placement.proposal)
      let childFrame = Rect(origin: placement.origin, size: childSize)
      let childClip: Rect
      if let requestedClip = placement.clip {
        childClip =
          requestedClip.intersection(node.clip)
          ?? Rect(
            origin: placement.origin,
            size: TerminalSize(columns: 0, rows: 0)
          )
      } else {
        childClip = node.clip
      }
      place(child, in: childFrame, clip: childClip)
    }
  }

  private func makeLayoutSubviews(
    for node: RuntimeNode,
    collector: _LayoutPlacementCollector?
  ) -> _LayoutSubviewsProxy {
    _LayoutSubviewsProxy(
      node.children.map { child in
        _LayoutSubviewProxy(
          measure: { [weak self, child] proposal in
            guard let self else {
              return TerminalSize(columns: 0, rows: 0)
            }
            return measure(child, proposal: proposal)
          },
          place: { [child, weak collector] origin, proposal, clip in
            collector?.placements[ObjectIdentifier(child)] = _LayoutPlacement(
              origin: origin,
              proposal: proposal,
              clip: clip
            )
          },
          value: { [weak self, child] key in
            guard let self else {
              return nil
            }
            return layoutValue(for: key, in: child)
          }
        )
      }
    )
  }

  private func layoutValue(for key: ObjectIdentifier, in node: RuntimeNode) -> Any? {
    if let provider = node.view as? any _LayoutValueProvider,
      let value = provider._layoutValue(for: key)
    {
      return value
    }

    guard node.children.count == 1 else {
      return nil
    }
    return layoutValue(for: key, in: node.children[0])
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

    guard focusAppearanceHost === node, !node.clip.isEmpty else {
      return
    }
    frame.withRenderRegion(in: node.frame, clip: node.clip) { region in
      if focusAppearanceUsesFallback {
        if let renderer = node.view as? any _FocusAppearanceFallbackRendering {
          renderer._renderFocusAppearanceFallback(
            in: &region,
            environment: node.environment
          )
        } else {
          _renderFocusRing(
            in: &region,
            style: node.environment._focusAppearanceStyle
          )
        }
      } else if let renderer = node.view as? any _FocusAppearanceRendering {
        renderer._renderFocusAppearance(
          in: &region,
          environment: node.environment
        )
      }
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

  private func appendAutomation(
    _ node: RuntimeNode, focusedNode: RuntimeNode?, to elements: inout [AutomationElement]
  ) {
    if let annotation = node.view as? any _AutomationView {
      elements.append(
        AutomationElement(
          identifier: annotation.automationIdentifier,
          role: annotation.automationRole,
          nodeIdentity: node.identity,
          frame: node.frame,
          clip: node.clip,
          isEnabled: node.environment.isEnabled,
          isFocused: focusedNode.map { isDescendant($0, of: node) } ?? false
        )
      )
    }
    for child in node.children {
      appendAutomation(child, focusedNode: focusedNode, to: &elements)
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
        focusID: node.focusID,
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

extension ViewGraph {
  private func rootEnvironment() -> EnvironmentValues {
    var environment = baseEnvironment
    environment._focusManager = focus
    return environment
  }

  private func refreshInteractionState() {
    var ids: [FocusID] = []
    var bindings: [_FocusBindingRegistration] = []
    collectInteractionState(rootNode, ids: &ids, bindings: &bindings)
    var restorationGroups: [NodeIdentity: _FocusRestorationGroupState] = [:]
    collectFocusRestorationState(
      rootNode,
      groupID: nil,
      paneID: nil,
      groups: &restorationGroups
    )

    let previousFocused = focus.focused
    let previousGroups = focusRestorationGroups
    focusRestorationGroups = restorationGroups
    let previousBindings = focusBindings
    focusBindings = previousBindings + bindings
    focus.replaceFocusableIDs(ids)
    applyFocusRestoration(
      previousFocused: previousFocused,
      previousGroups: previousGroups,
      currentGroups: restorationGroups
    )

    if let requested = bindings.first(where: {
      $0.binding.wrappedValue == $0.id && ids.contains($0.id)
    }) {
      focus.focus(requested.id)
    } else if let focused = focus.focused,
      bindings.contains(where: { $0.id == focused && $0.binding.wrappedValue != focused })
    {
      focus.focus(nil)
    } else {
      synchronizeFocusBindings(focusBindings)
    }
    focusBindings = bindings
    updatePublishedFocusedNode()
    focusAppearanceNeedsResolution = true
  }

  /// Recomputes focus eligibility that depends on layout metrics (for example
  /// `ScrollView.focusable(whileScrollable:)`) once a layout pass has settled, so such
  /// views register and withdraw immediately instead of one graph update later.
  /// Withdrawal and restoration flow through the ordinary interaction refresh.
  private func refreshLayoutDependentFocusIDs() {
    var changed = false
    refreshFocusIDs(rootNode, changed: &changed)
    if changed {
      refreshInteractionState()
    }
  }

  private func refreshFocusIDs(_ node: RuntimeNode, changed: inout Bool) {
    if let focusable = node.view as? any _FocusableView,
      focusable._focusID(in: node.environment) != node.focusID
    {
      node.updateInteractionMetadata(from: node.view)
      changed = true
    }
    for child in node.children {
      refreshFocusIDs(child, changed: &changed)
    }
  }

  private func collectInteractionState(
    _ node: RuntimeNode,
    ids: inout [FocusID],
    bindings: inout [_FocusBindingRegistration]
  ) {
    if let focusID = node.focusID {
      ids.append(focusID)
    }
    if let focusBinding = node.focusBinding {
      bindings.append(focusBinding)
    }
    for child in node.children {
      collectInteractionState(child, ids: &ids, bindings: &bindings)
    }
  }

  private func collectFocusRestorationState(
    _ node: RuntimeNode,
    groupID: NodeIdentity?,
    paneID: AnyHashable?,
    groups: inout [NodeIdentity: _FocusRestorationGroupState]
  ) {
    var groupID = groupID
    var paneID = paneID

    if node.view is any _FocusRestorationGroupView {
      let identity = node.identity
      groupID = identity
      paneID = nil
      groups[identity] = _FocusRestorationGroupState()
    }
    if let scope = node.view as? any _FocusRestorationScopeView,
      let groupID
    {
      let scopeID = scope._focusRestorationScopeID
      paneID = scopeID
      var group = groups[groupID] ?? _FocusRestorationGroupState()
      if !group.panes.contains(where: { $0.id == scopeID }) {
        group.panes.append(
          _FocusRestorationPaneState(
            id: scopeID,
            isCollapsed: scope._focusRestorationScopeIsCollapsed
          )
        )
      }
      groups[groupID] = group
    }

    if let groupID, let paneID, var group = groups[groupID],
      let index = group.panes.firstIndex(where: { $0.id == paneID })
    {
      if let declaredID = node.focusID ?? node.focusBinding?.id,
        !group.panes[index].declaredIDs.contains(declaredID)
      {
        group.panes[index].declaredIDs.append(declaredID)
      }
      if let focusID = node.focusID,
        !group.panes[index].activeIDs.contains(focusID)
      {
        group.panes[index].activeIDs.append(focusID)
      }
      groups[groupID] = group
    }

    for child in node.children {
      collectFocusRestorationState(
        child,
        groupID: groupID,
        paneID: paneID,
        groups: &groups
      )
    }
  }

  private func applyFocusRestoration(
    previousFocused: FocusID?,
    previousGroups: [NodeIdentity: _FocusRestorationGroupState],
    currentGroups: [NodeIdentity: _FocusRestorationGroupState]
  ) {
    // Dictionary iteration order is not deterministic; restoration walks groups in
    // stable identity-path order so focus outcomes never depend on hashing.
    if let previousFocused {
      collapseSearch: for (groupID, previousGroup) in previousGroups.sorted(by: {
        $0.key.description < $1.key.description
      }) {
        guard
          let previousIndex = previousGroup.panes.firstIndex(where: {
            $0.declaredIDs.contains(previousFocused)
          }),
          let currentGroup = currentGroups[groupID],
          let currentIndex = currentGroup.panes.firstIndex(where: {
            $0.id == previousGroup.panes[previousIndex].id
          }),
          !previousGroup.panes[previousIndex].isCollapsed,
          currentGroup.panes[currentIndex].isCollapsed
        else {
          continue
        }

        focusReturnCandidates[groupID, default: [:]][
          currentGroup.panes[currentIndex].id
        ] = previousFocused
        let later = currentGroup.panes.dropFirst(currentIndex + 1)
          .first { !$0.isCollapsed && !$0.activeIDs.isEmpty }?
          .activeIDs.first
        let earlier = currentGroup.panes.prefix(currentIndex).reversed()
          .first { !$0.isCollapsed && !$0.activeIDs.isEmpty }?
          .activeIDs.first
        focus.focus(later ?? earlier)
        break collapseSearch
      }
    }

    for (groupID, currentGroup) in currentGroups.sorted(by: {
      $0.key.description < $1.key.description
    }) {
      guard let previousGroup = previousGroups[groupID] else {
        continue
      }
      for currentPane in currentGroup.panes where !currentPane.isCollapsed {
        guard
          let previousPane = previousGroup.panes.first(where: {
            $0.id == currentPane.id
          }),
          previousPane.isCollapsed,
          let candidate = focusReturnCandidates[groupID]?[currentPane.id]
        else {
          continue
        }
        if focus.focused == nil && currentPane.activeIDs.contains(candidate) {
          focus.focus(candidate)
        }
        focusReturnCandidates[groupID]?[currentPane.id] = nil
      }
    }

    for (groupID, candidates) in focusReturnCandidates {
      guard let currentGroup = currentGroups[groupID] else {
        focusReturnCandidates[groupID] = nil
        continue
      }
      for paneID in candidates.keys
      where !currentGroup.panes.contains(where: { $0.id == paneID }) {
        focusReturnCandidates[groupID]?[paneID] = nil
      }
    }
  }
  private func resolveFocusAppearanceIfNeeded() {
    guard focusAppearanceNeedsResolution else {
      return
    }
    focusAppearanceNeedsResolution = false

    guard
      let focusedID = focus.focused,
      let focusedNode = firstNode(withFocusID: focusedID, in: rootNode)
    else {
      selectFocusAppearanceHost(nil, usesFallback: false)
      return
    }

    let appearanceNode = nearestFocusAppearanceResponder(in: focusedNode) ?? focusedNode
    var candidate: RuntimeNode? = appearanceNode
    while let node = candidate {
      defer { candidate = node.parent }
      guard let responder = node.view as? any _FocusAppearanceResponder else {
        continue
      }
      let context = FocusAppearanceContext(
        focusedID: focusedID,
        focusedBounds: appearanceNode.frame,
        hostBounds: node.frame
      )
      switch responder._resolveFocusAppearance(in: context) {
      case .deferred:
        continue
      case .handled:
        selectFocusAppearanceHost(node, usesFallback: false)
        return
      case .suppressed:
        selectFocusAppearanceHost(nil, usesFallback: false)
        return
      }
    }

    selectFocusAppearanceHost(appearanceNode, usesFallback: true)
  }

  private func selectFocusAppearanceHost(
    _ host: RuntimeNode?,
    usesFallback: Bool
  ) {
    guard focusAppearanceHost !== host || focusAppearanceUsesFallback != usesFallback
    else {
      return
    }
    let previousHost = focusAppearanceHost
    focusAppearanceHost = host
    focusAppearanceUsesFallback = usesFallback
    previousHost?.markNeedsRender()
    host?.markNeedsRender()
    rootNode.markNeedsRender()
  }

  private func focusDidChange() {
    let previousFocusedID = publishedFocusedID
    let previousFocusedNode = publishedFocusedNode
    publishedFocusedID = focus.focused
    statistics.focusChanges += 1
    focusAppearanceNeedsResolution = true
    synchronizeFocusBindings(focusBindings)
    refreshFocusedSubtree(
      for: previousFocusedID,
      fallback: previousFocusedNode
    )
    if focus.focused != previousFocusedID {
      refreshFocusedSubtree(for: focus.focused)
    }
    updatePublishedFocusedNode()
    if !rootNode.needsLayout {
      resolveFocusAppearanceIfNeeded()
    }
  }

  private func refreshFocusedSubtree(
    for id: FocusID?,
    fallback: RuntimeNode? = nil
  ) {
    guard
      let id,
      let node =
        (firstNode(withFocusID: id, in: rootNode)
          ?? fallback.flatMap { self.contains($0, in: rootNode) })
    else {
      return
    }

    let environment = node.environment
    let environmentOverrides = node.environmentOverrides
    if node === rootNode {
      rootNode = reconcile(
        node: node,
        view: node.view,
        environment: environment,
        environmentOverrides: environmentOverrides
      )
    } else {
      _ = reconcile(
        node: node,
        view: node.view,
        environment: environment,
        environmentOverrides: environmentOverrides
      )
    }
  }

  private func updatePublishedFocusedNode() {
    publishedFocusedNode = focus.focused.flatMap {
      firstNode(withFocusID: $0, in: rootNode)
    }
  }

  private func synchronizeFocusBindings(_ bindings: [_FocusBindingRegistration]) {
    for registration in bindings
    where registration.binding.wrappedValue == registration.id
      && registration.id != focus.focused
    {
      registration.binding.wrappedValue = nil
    }
    if let focused = focus.focused {
      for registration in bindings where registration.id == focused {
        if registration.binding.wrappedValue != focused {
          registration.binding.wrappedValue = focused
        }
      }
    }
  }

  private func firstNode(withFocusID id: FocusID, in node: RuntimeNode) -> RuntimeNode? {
    if node.focusID == id {
      return node
    }
    for child in node.children {
      if let match = firstNode(withFocusID: id, in: child) {
        return match
      }
    }
    return nil
  }

  private func contains(_ target: RuntimeNode, in node: RuntimeNode) -> RuntimeNode? {
    if node === target {
      return node
    }
    for child in node.children {
      if let match = contains(target, in: child) {
        return match
      }
    }
    return nil
  }

  /// Finds the responder that should receive events on behalf of `node`.
  ///
  /// Descent stops at any descendant that owns its own focus identity: that node is a
  /// separate focus target reached only when it is itself focused, never by routing
  /// through an ancestor that currently owns focus. This keeps a focused container from
  /// silently handing its keys to a nested focusable control.
  private func deepestResponder(in node: RuntimeNode) -> RuntimeNode? {
    for child in node.children {
      if child.focusID != nil {
        continue
      }
      if let responder = deepestResponder(in: child) {
        return responder
      }
    }
    if node.responderStorage != nil
      || node.leafStorage != nil
      || node.view is any _KeyHandlerView
    {
      return node
    }
    return nil
  }

  /// The focused subtree's own appearance responder: the focused node itself when it is
  /// a responder, otherwise the first responder reachable from it without crossing a
  /// nested focus identity or another responder. Stopping at responder boundaries keeps
  /// a focusable viewport from delegating its appearance into unrelated responders
  /// inside the content it scrolls.
  private func nearestFocusAppearanceResponder(in node: RuntimeNode) -> RuntimeNode? {
    if node.view is any _FocusAppearanceResponder {
      return node
    }
    for child in node.children {
      if child.focusID != nil {
        continue
      }
      if child.view is any _FocusAppearanceResponder {
        return child
      }
      if let responder = nearestFocusAppearanceResponder(in: child) {
        return responder
      }
    }
    return nil
  }

  private func isDescendant(_ node: RuntimeNode, of ancestor: RuntimeNode) -> Bool {
    var candidate: RuntimeNode? = node
    while let current = candidate {
      if current === ancestor {
        return true
      }
      candidate = current.parent
    }
    return false
  }

  private func apply(_ context: borrowing ResponderContext, to node: RuntimeNode) {
    if context.needsLayout {
      node.markNeedsLayout()
    } else if context.needsDisplay {
      node.markNeedsRender()
    }
  }
}

extension InputEvent {
  fileprivate var isRoutableResponderEvent: Bool {
    switch self {
    case .key, .paste:
      true
    case .focusGained, .focusLost, .kittyGraphicsResponse,
      .kittyKeyboardEnhancementFlags, .mouse, .primaryDeviceAttributes,
      .privateModeStatus, .resize, .unknown:
      false
    }
  }
}

private struct _FocusRestorationGroupState {
  var panes: [_FocusRestorationPaneState] = []
}

private struct _FocusRestorationPaneState {
  let id: AnyHashable
  let isCollapsed: Bool
  var declaredIDs: [FocusID] = []
  var activeIDs: [FocusID] = []
}
