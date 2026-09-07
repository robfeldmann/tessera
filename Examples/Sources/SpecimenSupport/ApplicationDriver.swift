import Tessera

/// Coordinates synchronous application work in the host's isolation domain.
///
/// The app owns its model and root factory. Every event is followed by one explicit
/// update; observation never performs graph work. Presentation completes only after
/// the session has flushed the borrowed render transaction. No async work is drained.
package final class ApplicationDriver {
  package let graph: ViewGraph
  package private(set) var frameSequence = 0

  package init<Root: View>(size: TerminalSize, root: @escaping () -> Root) {
    graph = ViewGraph(root: root, size: size)
  }

  /// Routes ordinary semantic input before applying the host's unhandled quit policy.
  /// Returns whether the host should continue accepting input.
  @discardableResult
  package func step(_ event: InputEvent) -> Bool {
    let disposition = graph.dispatch(event)
    if case .resize(let size) = event {
      graph.resize(to: size)
    }
    graph.update()
    if disposition == .ignored,
      case .key(let key) = event,
      key.kind == .press, key.code == .character("q"), key.modifiers.isEmpty
    {
      return false
    }
    return true
  }

  /// Explicitly reconciles externally completed model work, without presenting it.
  package func update() {
    graph.update()
  }

  /// Presents at most once, using actual device geometry, and awaits output completion.
  /// The caller must use the same isolation domain that created this driver.
  @discardableResult
  package func present(to terminal: isolated TerminalSession) async throws -> Bool {
    guard graph.needsRender else {
      return false
    }
    try await terminal.draw { frame in
      graph.render(into: frame)
    }
    frameSequence += 1
    return true
  }
}
