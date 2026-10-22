import Tessera
import TesseraTerminalSnapshotSupport

/// Drives one `ViewGraph` through whole passes and projects the result.
///
/// Uses only public API: `ViewGraph.update()`, `layoutIfNeeded()` and `render(into:)` (via
/// `VirtualTerminal.snapshot`), and `diagnostics`.
public final class GraphSession {
  public let graph: ViewGraph
  public private(set) var size: TerminalSize

  public init<Root: View>(size: TerminalSize, root: @escaping () -> Root) {
    self.size = size
    graph = ViewGraph(root: root, size: size)
  }

  /// Re-evaluates the root closure, as the run loop does after an app update.
  public func update() {
    graph.update()
  }

  /// Renders a full pass at `size` (or the current size) and projects it. Rendering into
  /// a frame of a new size resizes the graph, so a resize is just a capture at a new size.
  public func capture(size: TerminalSize? = nil) -> Projection {
    if let size {
      self.size = size
    }
    let screen = VirtualTerminal.snapshot(size: self.size) { frame in
      graph.render(into: frame)
    }
    return Projection(diagnostics: graph.diagnostics, screen: screen)
  }
}
