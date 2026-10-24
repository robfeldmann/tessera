import Tessera
import Testing

/// A nonisolated application that reports what the graph looked like when it applied an event.
private final class RecordingApp: Application {
  private(set) var count = 9
  private(set) var applied: [InputEvent] = []
  var onApply: ((InputEvent) -> Void)?

  var body: some View {
    Text("Counter value is \(count)")
  }

  func apply(_ event: InputEvent) {
    applied.append(event)
    onApply?(event)
    if case .key(let key) = event, key.code == .character("+") {
      count += 1
    }
  }
}

/// A main-actor application with an isolated conformance.
@MainActor
private final class MainActorApp: @MainActor Application {
  private(set) var count = 9

  var body: some View {
    Text("Counter value is \(count)")
  }

  func apply(_ event: InputEvent) {
    if case .key(let key) = event, key.code == .character("+") {
      count += 1
    }
  }
}

/// A host on an actor of its own, passing `self` as the isolation of the step.
private actor ActorHost {
  func stepPlus() -> Int {
    let app = RecordingApp()
    let graph = ViewGraph(root: { app.body }, size: TerminalSize(columns: 40, rows: 4))
    Step.run(app, graph: graph, event: plus, isolation: self)
    return app.count
  }
}

private let plus = InputEvent.key(Key(code: .character("+")))

private func makeGraph<App: Application>(for app: App) -> ViewGraph {
  ViewGraph(root: { app.body }, size: TerminalSize(columns: 40, rows: 4))
}

private func rootColumns(of graph: ViewGraph) -> Int? {
  graph.layoutIfNeeded()
  return graph.diagnostics.nodes.first { $0.parentIdentity == nil }?.measuredSize?.columns
}

@Test @MainActor
func `the step applies the event to the app and then updates the graph`() {
  let app = RecordingApp()
  let graph = makeGraph(for: app)
  #expect(rootColumns(of: graph) == 18)

  let disposition = Step.run(app, graph: graph, event: plus, isolation: MainActor.shared)

  #expect(app.applied == [plus])
  #expect(app.count == 10)
  #expect(rootColumns(of: graph) == 19)
  #expect(disposition == .ignored)
}

@Test @MainActor
func `a resize resizes the graph before the app applies it`() {
  let app = RecordingApp()
  let graph = makeGraph(for: app)
  _ = rootColumns(of: graph)
  #expect(graph.needsLayout == false)
  var layoutPendingWhenApplied: [Bool] = []
  app.onApply = { _ in layoutPendingWhenApplied.append(graph.needsLayout) }

  Step.run(
    app, graph: graph, event: .resize(TerminalSize(columns: 20, rows: 3)),
    isolation: MainActor.shared)

  #expect(layoutPendingWhenApplied == [true])
  #expect(app.applied == [.resize(TerminalSize(columns: 20, rows: 3))])
}

@Test @MainActor
func `a resize that changes nothing still reaches the app`() {
  let app = RecordingApp()
  let graph = makeGraph(for: app)
  let unchanged = InputEvent.resize(TerminalSize(columns: 40, rows: 4))

  Step.run(app, graph: graph, event: unchanged, isolation: MainActor.shared)

  #expect(app.applied == [unchanged])
}

@Test @MainActor
func `a main-actor app steps through the same step on the main actor`() {
  let app = MainActorApp()
  let graph = makeGraph(for: app)

  Step.run(app, graph: graph, event: plus, isolation: MainActor.shared)

  #expect(app.count == 10)
  #expect(rootColumns(of: graph) == 19)
}

@Test
func `a nonisolated app steps on an actor through the same step`() async {
  let host = ActorHost()

  let count = await host.stepPlus()

  #expect(count == 10)
}
