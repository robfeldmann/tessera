import TesseraTerminalCore
import TesseraTerminalInput

/// A primitive view whose measurement and rendering are implemented directly.
///
/// Leaves are values, not runtime nodes. The graph owns their state and lends the scoped
/// capabilities supplied to their methods synchronously.
/// A public leaf primitive whose state and rendering are owned by the graph.
public protocol LeafView: View where Body == Never {
  associatedtype NodeState = Void

  func makeState() -> NodeState

  func sizeThatFits(
    _ proposal: ProposedSize,
    state: inout NodeState,
    environment: EnvironmentValues
  ) -> TerminalSize

  func render(
    in region: inout RenderRegion,
    state: inout NodeState,
    environment: EnvironmentValues
  )

  /// Called only for a focused leaf or a leaf on the event bubble path.
  func handleEvent(
    _ event: InputEvent,
    state: inout NodeState,
    context: inout ResponderContext
  ) -> EventDisposition

  /// Called for a pointer phase whose hit-test target is this input leaf.
  ///
  /// Conform to InputLeafView when implementing this handler.
  func handlePointer(
    _ event: PointerEvent,
    state: inout NodeState,
    context: inout ResponderContext
  ) -> EventDisposition
}

/// An input-capable leaf that may receive focused keyboard and pointer events.
///
/// Render-only leaves continue to conform to LeafView alone. Conform to this
/// capability when implementing LeafView.handleEvent or LeafView.handlePointer so
/// the graph can route input to the interactive leaf without treating passive
/// siblings as responders.
public protocol InputLeafView: LeafView {
  /// Terminal modes requested while this input leaf is live.
  var terminalRequirements: TerminalRequirements { get }
}

/// Provides no additional terminal demand by default.
extension InputLeafView {
  /// Supplies the default terminal demand for an input leaf.
  public var terminalRequirements: TerminalRequirements { TerminalRequirements() }
}

extension LeafView where NodeState == Void {
  /// Creates the stateless leaf's empty node state.
  public func makeState() {}
}

extension LeafView {
  /// Ignores events unless a leaf supplies an explicit handler.
  public func handleEvent(
    _ event: InputEvent,
    state: inout NodeState,
    context: inout ResponderContext
  ) -> EventDisposition {
    .ignored
  }
}

extension LeafView {
  /// Ignores pointer phases unless a leaf supplies an explicit handler.
  public func handlePointer(
    _ event: PointerEvent,
    state: inout NodeState,
    context: inout ResponderContext
  ) -> EventDisposition {
    .ignored
  }
}
