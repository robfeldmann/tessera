import TesseraTerminalCore
import TesseraTerminalInput

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
  package var responderStorage: (any _ResponderStorage)?
  package var focusID: FocusID?
  package var focusBinding: _FocusBindingRegistration?
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
    responderStorage = _makeResponderStorageIfNeeded(view)
    updateInteractionMetadata(from: view)
  }

  package func updateInteractionMetadata(from view: any View) {
    if let responderStorage {
      responderStorage.update(from: view)
    } else {
      responderStorage = _makeResponderStorageIfNeeded(view)
    }

    focusID = (view as? any _FocusableView)?._focusID(in: environment)
    focusBinding = (view as? any _FocusBindingView)?._focusBindingRegistration

    handlerKinds.removeAll(keepingCapacity: true)
    if responderStorage != nil || (leafStorage != nil && focusID != nil) {
      handlerKinds.append("event")
    }
    if view is any _KeyHandlerView {
      handlerKinds.append("key")
    }
    if focusID != nil {
      handlerKinds.append("focus")
    }

    terminalRequirements =
      (view as? any _TerminalRequirementsView)?._terminalRequirements
      ?? TerminalRequirements()
    if focusID != nil {
      terminalRequirements = .union(
        terminalRequirements,
        TerminalRequirements(wantsKeyboardEnhancement: true)
      )
    }
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
  func handleEvent(
    _ event: InputEvent,
    context: inout ResponderContext
  ) -> EventDisposition
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

  func handleEvent(
    _ event: InputEvent,
    context: inout ResponderContext
  ) -> EventDisposition {
    leaf.handleEvent(event, state: &state, context: &context)
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

package protocol _ResponderStorage: AnyObject {
  func update(from view: any View)
  func handleEvent(
    _ event: InputEvent,
    context: inout ResponderContext
  ) -> EventDisposition
}

private final class ConcreteResponderStorage<Responder: _ResponderView>:
  _ResponderStorage
{
  private var responder: Responder
  private var state: Responder.ResponderState

  init(_ responder: Responder) {
    self.responder = responder
    state = responder._makeResponderState()
  }

  func update(from view: any View) {
    guard let responder = view as? Responder else {
      preconditionFailure("Responder storage can only receive its original view type.")
    }
    self.responder = responder
    self.responder._updateResponderState(&state)
  }

  func handleEvent(
    _ event: InputEvent,
    context: inout ResponderContext
  ) -> EventDisposition {
    responder._handleEvent(event, state: &state, context: &context)
  }
}

private func _makeResponderStorageIfNeeded<Content: View>(
  _ view: Content
) -> (any _ResponderStorage)? {
  guard let responder = view as? any _ResponderView else {
    return nil
  }
  return _openResponderStorage(responder)
}

private func _openResponderStorage<Responder: _ResponderView>(
  _ responder: Responder
) -> any _ResponderStorage {
  ConcreteResponderStorage(responder)
}
