import TesseraCore
import TesseraRuntime
import TesseraTerminalCore
import TesseraTerminalInput
import TesseraTerminalSnapshotSupport

/// Hosts one application on an actor of its own, so suites that step applications run in
/// parallel instead of queueing on the main actor.
///
/// The actor passes itself as the isolation of the same ``Step`` the main-actor ``Driver``
/// uses. A nonisolated application runs here unchanged; an application with a main-actor
/// isolated conformance is rejected at the call site that names it, because only a
/// main-actor host can use that conformance.
///
/// This host draws nothing through a terminal session. It renders the graph into a fresh
/// virtual terminal when asked for the screen.
actor ActorHost<App: Application> {
  private let app: App
  private let graph: ViewGraph
  private var size: TerminalSize

  /// Builds the application on this actor and tells it its starting size.
  init(size: TerminalSize, make: sending () -> App) async {
    let app = make()
    self.app = app
    self.size = size
    graph = ViewGraph(root: { app.body }, size: size)
    Step.run(app, graph: graph, event: .resize(size), isolation: self)
  }

  /// Delivers one event and returns how the graph disposed of it.
  @discardableResult
  func step(_ event: InputEvent) -> EventDisposition {
    if case .resize(let newSize) = event {
      size = newSize
    }
    return Step.run(app, graph: graph, event: event, isolation: self)
  }

  /// The visible screen, one string per row, with trailing blanks trimmed.
  func screenRows() -> [String] {
    let graph = graph
    return VirtualTerminal.snapshot(size: size) { frame in
      graph.render(into: frame)
    }.trimmedRows
  }

  /// Reads the application's state on this actor.
  func read<Result: Sendable>(_ body: sending (App) -> Result) -> Result {
    body(app)
  }
}
