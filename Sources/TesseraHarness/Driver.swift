import TesseraCore
import TesseraRuntime
import TesseraTerminal
import TesseraTerminalBuffer
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
/// After every step the driver records one ``TraceRecord``: the event, why the frame was drawn,
/// which nodes and rows changed, and what the step cost. It hands the record to `onRecord` and
/// keeps the latest, so a host decides whether to keep every record (a scenario run), write
/// each to a file (a live session), or drop them.
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

  /// The record of the latest step, or `nil` before ``start()`` has drawn the first frame.
  private(set) var lastRecord: TraceRecord?

  private let session: TerminalSession
  private let onRecord: (@MainActor (TraceRecord) -> Void)?
  private var steps = 0
  private var nodesBefore: [NodeDiagnostics] = []
  private var rowsBefore: [String] = []
  private var bytesBefore = 0

  /// Whether the application has asked its host to stop.
  var isFinished: Bool {
    app.isFinished
  }

  /// Creates a driver whose graph starts at `size` and draws through `session`.
  ///
  /// - Parameter onRecord: Called with each step's record, on the main actor, before the step
  ///   returns.
  init(
    app: App,
    size: TerminalSize,
    session: TerminalSession,
    environment: EnvironmentValues = EnvironmentValues(),
    onRecord: (@MainActor (TraceRecord) -> Void)? = nil
  ) {
    self.app = app
    self.size = size
    self.session = session
    self.onRecord = onRecord
    graph = ViewGraph(root: { app.body }, size: size, environment: environment)
  }

  /// Tells the application its starting size and draws the first frame.
  ///
  /// The size reaches the application as a resize event, through the same step as every
  /// later event, because an application has no other way to learn the size it starts at.
  func start() async throws {
    let event = InputEvent.resize(size)
    Step.run(app, graph: graph, event: event, isolation: MainActor.shared)
    try await present()
    await record(event, drew: true)
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
    let drew = graph.needsRender
    if drew {
      try await present()
    }
    await record(event, drew: drew)
    return disposition
  }

  private func present() async throws {
    let graph = graph
    try await session.draw { frame in
      graph.render(into: frame)
    }
  }

  /// Records the step that has just finished: its statistics are the pass's, since the graph
  /// resets them at every update.
  private func record(_ event: InputEvent, drew: Bool) async {
    let nodes = graph.diagnostics.nodes
    var rows = rowsBefore
    if drew, let frame = await session.lastDrawn {
      rows = frame.buffer.textRows
    }
    let bytesDrawn = await session.bytesDrawn
    let record = TraceRecord(
      seq: steps,
      event: event,
      drew: drew,
      statistics: graph.statistics,
      bytes: bytesDrawn - bytesBefore,
      nodes: TraceRecord.NodeChanges(from: nodesBefore, to: nodes),
      rowsBefore: rowsBefore,
      rowsAfter: rows)
    nodesBefore = nodes
    rowsBefore = rows
    bytesBefore = bytesDrawn
    steps += 1
    lastRecord = record
    onRecord?(record)
  }
}

extension Buffer {
  /// The text of every row, as the cells hold it: a continuation cell adds nothing, a cell
  /// with no text adds a space, and a row loses its trailing spaces.
  fileprivate var textRows: [String] {
    (0..<size.rows).map { row in
      var text = ""
      for column in 0..<size.columns {
        switch self[row, column].content {
        case .blank, .raw: text.append(" ")
        case .continuation: continue
        case .grapheme(let grapheme): text += grapheme
        }
      }
      while text.last == " " {
        text.removeLast()
      }
      return text
    }
  }
}
