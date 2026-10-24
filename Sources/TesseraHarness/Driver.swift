import TesseraCore
import TesseraRuntime
import TesseraTerminal
import TesseraTerminalCore
import TesseraTerminalInput

/// Runs one application on the main actor, one input event at a time, and draws every
/// change through a terminal session.
///
/// A driver is a thin host over ``Step``: it owns the application, the ``ViewGraph`` that
/// lowers its body, and the session it presents through. The headless host and the live host
/// both drive an application through this type, so what a scenario renders is what a terminal
/// shows. The session is an actor that receives finished frames; the frame itself is drawn
/// here, in the main actor's isolation, because the graph lives here.
///
/// The driver has no quit key and no focus policy. It stops being useful when the application
/// reports ``isFinished``, and the host decides what to do about that.
@MainActor
final class Driver<App: Application> {
  /// The application under test.
  let app: App

  /// The graph that lowers the application's body.
  let graph: ViewGraph

  /// The size the graph was last laid out at.
  private(set) var size: TerminalSize

  private let session: TerminalSession

  /// Whether the application has asked its host to stop.
  var isFinished: Bool {
    app.isFinished
  }

  /// Creates a driver whose graph starts at `size` and draws through `session`.
  init(
    app: App,
    size: TerminalSize,
    session: TerminalSession,
    environment: EnvironmentValues = EnvironmentValues()
  ) {
    self.app = app
    self.size = size
    self.session = session
    graph = ViewGraph(root: { app.body }, size: size, environment: environment)
  }

  /// Tells the application its starting size and draws the first frame.
  ///
  /// The size reaches the application as a resize event, through the same step as every
  /// later event, because an application has no other way to learn the size it starts at.
  func start() async throws {
    Step.run(app, graph: graph, event: .resize(size), isolation: MainActor.shared)
    try await present()
  }

  /// Delivers one event, then draws a frame if anything changed.
  ///
  /// When this returns, the application has applied the event, the graph is updated, and the
  /// frame is committed to the session.
  @discardableResult
  func step(_ event: InputEvent) async throws -> EventDisposition {
    if case .resize(let newSize) = event {
      size = newSize
    }
    let disposition = Step.run(
      app, graph: graph, event: event, isolation: MainActor.shared)
    if graph.needsRender {
      try await present()
    }
    return disposition
  }

  private func present() async throws {
    let graph = graph
    try await session.draw { frame in
      graph.render(into: frame)
    }
  }
}
