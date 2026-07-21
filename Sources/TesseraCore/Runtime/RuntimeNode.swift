import TesseraTerminalCore

package final class RuntimeNode {
  package let identity: NodeIdentity
  package let slot: _ViewSlot?
  package weak var parent: RuntimeNode?
  package var view: any View
  package var viewType: ObjectIdentifier
  package var viewTypeName: String
  package var children: [RuntimeNode] = []
  package var environment: EnvironmentValues
  package var environmentOverrides: [String]
  package var leafStorage: (any _LeafStorage)?
  package var proposal: ProposedSize?
  package var measuredSize: TerminalSize?
  package var frame = Rect(column: 0, row: 0, columns: 0, rows: 0)
  package var clip = Rect(column: 0, row: 0, columns: 0, rows: 0)
  package var needsLayout = true
  package var needsRender = true
  package var handlerKinds: [String] = []
  package var terminalRequirements = TerminalRequirements()

  package init<Content: View>(
    identity: NodeIdentity,
    slot: _ViewSlot?,
    parent: RuntimeNode?,
    view: Content,
    environment: EnvironmentValues,
    environmentOverrides: [String]
  ) {
    self.identity = identity
    self.slot = slot
    self.parent = parent
    self.view = view
    viewType = ObjectIdentifier(Content.self)
    viewTypeName = String(reflecting: Content.self)
    self.environment = environment
    self.environmentOverrides = environmentOverrides
    leafStorage = _makeLeafStorageIfNeeded(view)
  }

  package func markNeedsLayout() {
    needsLayout = true
    needsRender = true
    parent?.markNeedsLayout()
  }

  package func markNeedsRender() {
    needsRender = true
    parent?.markNeedsRender()
  }

  package func clearDirtyFlagsRecursively() {
    needsLayout = false
    needsRender = false
    for child in children {
      child.clearDirtyFlagsRecursively()
    }
  }
}

package protocol _LeafStorage: AnyObject {
  func update(from view: any View)
  func sizeThatFits(_ proposal: ProposedSize, environment: EnvironmentValues)
    -> TerminalSize
  func render(in region: inout RenderRegion, environment: EnvironmentValues)
}

private final class ConcreteLeafStorage<Leaf: LeafView>: _LeafStorage {
  private var leaf: Leaf
  private var state: Leaf.NodeState

  init(_ leaf: Leaf) {
    self.leaf = leaf
    state = leaf.makeState()
  }

  func update(from view: any View) {
    guard let leaf = view as? Leaf else {
      preconditionFailure("A leaf storage can only receive its original leaf type.")
    }
    self.leaf = leaf
  }

  func sizeThatFits(
    _ proposal: ProposedSize,
    environment: EnvironmentValues
  ) -> TerminalSize {
    leaf.sizeThatFits(proposal, state: &state, environment: environment)
  }

  func render(in region: inout RenderRegion, environment: EnvironmentValues) {
    leaf.render(in: &region, state: &state, environment: environment)
  }
}

private func _makeLeafStorageIfNeeded<Content: View>(
  _ view: Content
) -> (any _LeafStorage)? {
  guard let leaf = view as? any LeafView else {
    return nil
  }
  return _openLeafStorage(leaf)
}

private func _openLeafStorage<Leaf: LeafView>(_ leaf: Leaf) -> any _LeafStorage {
  ConcreteLeafStorage(leaf)
}
