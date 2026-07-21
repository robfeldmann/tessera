import TesseraTerminalCore
import TesseraTerminalInput

/// A primitive view whose measurement and rendering are implemented directly.
///
/// Leaves are values, not runtime nodes. The graph owns their state and lends the scoped
/// capabilities supplied to their methods synchronously.
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
