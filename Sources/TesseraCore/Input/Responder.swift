import TesseraTerminalCore
import TesseraTerminalInput

/// The normalized key event delivered to view responders.
public typealias KeyEvent = Key

/// A key code and exact modifier set matched on key presses.
public struct KeyPattern: Equatable, Sendable {
  /// A pattern matching an unmodified Tab press.
  public static let tab = Self(.tab)

  public let code: KeyCode
  public let modifiers: Modifiers

  /// Creates a key-press pattern.
  public init(_ code: KeyCode, modifiers: Modifiers = []) {
    self.code = code
    self.modifiers = modifiers
  }

  /// Adds Shift to a pattern's exact modifier set.
  public static func shift(_ pattern: Self) -> Self {
    Self(pattern.code, modifiers: pattern.modifiers.union(.shift))
  }

  package func matches(_ key: Key) -> Bool {
    key.kind == .press && key.code == code && key.modifiers == modifiers
  }
}

package struct _FocusBindingRegistration {
  package let id: FocusID
  package let binding: Binding<FocusID?>

  package init(id: FocusID, binding: Binding<FocusID?>) {
    self.id = id
    self.binding = binding
  }
}

package protocol _FocusableView {
  func _focusID(in environment: EnvironmentValues) -> FocusID?
}

package protocol _FocusBindingView {
  var _focusBindingRegistration: _FocusBindingRegistration { get }
}

package protocol _FocusRestorationGroupView {}

package protocol _FocusRestorationScopeView {
  var _focusRestorationScopeID: AnyHashable { get }
  var _focusRestorationScopeIsCollapsed: Bool { get }
}

package protocol _KeyHandlerView {
  func _handleKey(_ key: Key, context: inout ResponderContext) -> EventDisposition
}

/// State projected by a responder into its rendered descendants.
package struct _ResponderStateProjection {
  package var isPressed = false
  package var isPointerCaptured = false
}

private struct _ResponderStateProjectionKey: EnvironmentKey {
  static let defaultValue = _ResponderStateProjection()
}

extension EnvironmentValues {
  package var _responderStateProjection: _ResponderStateProjection {
    get { self[_ResponderStateProjectionKey.self] }
    set { self[_ResponderStateProjectionKey.self] = newValue }
  }

  package var _allowsHitTesting: Bool {
    get { self[_AllowsHitTestingKey.self] }
    set { self[_AllowsHitTestingKey.self] = newValue }
  }
}

private struct _AllowsHitTestingKey: EnvironmentKey {
  static let defaultValue = true
}

/// Marks a responder as an eligible pointer hit target.
package protocol _PointerResponderView {}

/// Internal event-routing seam for structural views and event-only state.
///
/// A stateful ``LeafView`` handles events through ``LeafView/handleEvent(_:state:context:)``
/// so rendering, layout, and events retain one `NodeState` owner. A leaf may also conform
/// here only when its `NodeState` carries no event or rendering state, normally `Void`;
/// never mirror the same ephemeral value in both `NodeState` and `ResponderState`.
package protocol _ResponderView: View {
  associatedtype ResponderState = Void

  func _makeResponderState() -> ResponderState
  func _updateResponderState(_ state: inout ResponderState)
  func _handleEvent(
    _ event: InputEvent,
    state: inout ResponderState,
    context: inout ResponderContext
  ) -> EventDisposition
  func _handlePointer(
    _ event: PointerEvent,
    state: inout ResponderState,
    context: inout ResponderContext
  ) -> EventDisposition
  func _cancelResponderState(_ state: inout ResponderState)
  func _updateResponderStateProjection(
    _ projection: inout _ResponderStateProjection,
    state: ResponderState
  )
}

extension _ResponderView {
  package func _updateResponderState(_ state: inout ResponderState) {}
  package func _handlePointer(
    _ event: PointerEvent,
    state: inout ResponderState,
    context: inout ResponderContext
  ) -> EventDisposition { .ignored }
  package func _cancelResponderState(_ state: inout ResponderState) {}
  package func _updateResponderStateProjection(
    _ projection: inout _ResponderStateProjection,
    state: ResponderState
  ) {}
}

extension _ResponderView where ResponderState == Void {
  package func _makeResponderState() {}
}

package protocol _TerminalRequirementsView {
  var _terminalRequirements: TerminalRequirements { get }
}

private struct _FocusableModifier<Content: View>: View, _FocusableView, _LayoutView {
  typealias Body = Never

  let content: Content
  let id: FocusID

  func _focusID(in environment: EnvironmentValues) -> FocusID? {
    environment.isEnabled ? id : nil
  }

  func _visitChildren(
    in environment: EnvironmentValues,
    environmentOverrides: [String],
    _ visit: (_ViewChild) -> Void
  ) {
    var childEnvironment = environment
    childEnvironment.isFocused = childEnvironment._focusedID == id
    visit(
      _ViewChild(
        slot: .index(0),
        view: content,
        environment: childEnvironment,
        environmentOverrides: environmentOverrides
      )
    )
  }

  func _sizeThatFits(
    _ proposal: ProposedSize,
    subviews: _LayoutSubviewsProxy
  ) -> TerminalSize {
    guard subviews.count == 1 else {
      return TerminalSize(columns: 0, rows: 0)
    }
    return subviews[0].measure(proposal)
  }

  func _placeSubviews(
    in bounds: Rect,
    proposal: ProposedSize,
    subviews: _LayoutSubviewsProxy
  ) {
    guard subviews.count == 1 else {
      return
    }
    subviews[0].place(
      bounds.origin,
      ProposedSize(width: bounds.size.columns, height: bounds.size.rows)
    )
  }
}

private struct _FocusedModifier<Content: View>: View, _FocusBindingView, _StructuralView {
  typealias Body = Never

  let content: Content
  let binding: Binding<FocusID?>
  let id: FocusID

  var _focusBindingRegistration: _FocusBindingRegistration {
    _FocusBindingRegistration(id: id, binding: binding)
  }

  func _visitChildren(
    in environment: EnvironmentValues,
    environmentOverrides: [String],
    _ visit: (_ViewChild) -> Void
  ) {
    visit(
      _ViewChild(
        slot: .index(0),
        view: content,
        environment: environment,
        environmentOverrides: environmentOverrides
      )
    )
  }
}

private struct _OnMouseModifier<Content: View>: View, _ResponderView,
  _PointerResponderView,
  _StructuralView, _TerminalRequirementsView
{
  typealias Body = Never

  let content: Content
  let handler: (PointerEvent, inout ResponderContext) -> EventDisposition

  var _terminalRequirements: TerminalRequirements {
    TerminalRequirements(wantsMouse: true, wantsFocusReporting: true)
  }

  func _handleEvent(
    _ event: InputEvent,
    state: inout Void,
    context: inout ResponderContext
  ) -> EventDisposition { .ignored }

  func _handlePointer(
    _ event: PointerEvent,
    state: inout Void,
    context: inout ResponderContext
  ) -> EventDisposition {
    handler(event, &context)
  }

  func _visitChildren(
    in environment: EnvironmentValues,
    environmentOverrides: [String],
    _ visit: (_ViewChild) -> Void
  ) {
    visit(
      _ViewChild(
        slot: .index(0), view: content, environment: environment,
        environmentOverrides: environmentOverrides))
  }
}

private struct _OnTapModifier<Content: View>: View, _ResponderView, _PointerResponderView,
  _StructuralView, _TerminalRequirementsView
{
  typealias Body = Never
  typealias ResponderState = Bool

  let content: Content
  let action: (inout ResponderContext) -> Void

  var _terminalRequirements: TerminalRequirements {
    TerminalRequirements(wantsMouse: true, wantsFocusReporting: true)
  }

  func _makeResponderState() -> Bool { false }

  func _updateResponderState(_ state: inout Bool) {}

  func _updateResponderStateProjection(
    _ projection: inout _ResponderStateProjection,
    state: Bool
  ) {
    projection.isPressed = state
  }

  func _cancelResponderState(_ state: inout Bool) {
    state = false
  }

  func _handleEvent(
    _ event: InputEvent,
    state: inout Bool,
    context: inout ResponderContext
  ) -> EventDisposition { .ignored }

  func _handlePointer(
    _ event: PointerEvent,
    state: inout Bool,
    context: inout ResponderContext
  ) -> EventDisposition {
    switch event.phase {
    case .down where event.button == .left:
      state = true
      return .handled
    case .up where event.button == .left:
      guard state else {
        return .ignored
      }
      state = false
      action(&context)
      return .handled
    case .cancel:
      let wasPressed = state
      state = false
      return wasPressed ? .handled : .ignored
    case .move:
      return state ? .handled : .ignored
    default:
      return .ignored
    }
  }

  func _visitChildren(
    in environment: EnvironmentValues,
    environmentOverrides: [String],
    _ visit: (_ViewChild) -> Void
  ) {
    visit(
      _ViewChild(
        slot: .index(0), view: content, environment: environment,
        environmentOverrides: environmentOverrides))
  }
}

private struct _OnKeyModifier<Content: View>: View, _KeyHandlerView,
  _StructuralView, _TerminalRequirementsView
{
  typealias Body = Never

  let content: Content
  let handler: (Key, inout ResponderContext) -> EventDisposition

  var _terminalRequirements: TerminalRequirements {
    TerminalRequirements(wantsKeyboardEnhancement: true)
  }

  func _handleKey(_ key: Key, context: inout ResponderContext) -> EventDisposition {
    handler(key, &context)
  }

  func _visitChildren(
    in environment: EnvironmentValues,
    environmentOverrides: [String],
    _ visit: (_ViewChild) -> Void
  ) {
    visit(
      _ViewChild(
        slot: .index(0),
        view: content,
        environment: environment,
        environmentOverrides: environmentOverrides
      )
    )
  }
}

extension View {
  /// Registers this view under an explicit focus identity.
  public func focusable(_ id: FocusID) -> some View {
    _FocusableModifier(content: self, id: id)
  }

  /// Synchronizes this focus identity with application-owned focus state.
  public func focused(_ binding: Binding<FocusID?>, equals id: FocusID) -> some View {
    _FocusedModifier(content: self, binding: binding, id: id)
  }

  /// Controls whether this subtree participates in pointer hit testing.
  public func allowsHitTesting(_ enabled: Bool) -> some View {
    environment(\._allowsHitTesting, enabled)
  }

  /// Handles normalized pointer phases.
  public func onPointer(
    _ handler: @escaping (PointerEvent, inout ResponderContext) -> EventDisposition
  ) -> some View {
    _OnMouseModifier(content: self, handler: handler)
  }

  /// Runs an action for a primary-button down/up pair.
  public func onTap(
    perform action: @escaping (inout ResponderContext) -> Void
  ) -> some View {
    _OnTapModifier(content: self, action: action)
  }

  /// Handles focused key events while allowing ignored events to bubble.
  public func onKey(
    _ handler: @escaping (KeyEvent, inout ResponderContext) -> EventDisposition
  ) -> some View {
    _OnKeyModifier(content: self, handler: handler)
  }

  /// Handles one exact key-press pattern.
  public func onKey(
    _ pattern: KeyPattern,
    perform: @escaping (inout ResponderContext) -> Void
  ) -> some View {
    onKey { key, context in
      guard pattern.matches(key) else {
        return .ignored
      }
      perform(&context)
      return .handled
    }
  }
}
