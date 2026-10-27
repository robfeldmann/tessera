import Observation
import Tessera
import Testing

// These tests import only `Tessera`: that one import is enough to declare an `Application`.
// Each type below is one adoption shape from the `Application` documentation, so a shape that
// stops compiling fails here.

/// A plain class declared with the conformance: runs on any host.
private final class PlainCounter: Application {
  private(set) var count = 9

  var body: some View {
    VStack {
      Text("Counter value is \(count)")
      Text("+ to count")
    }
  }

  func apply(_ event: InputEvent) {
    if case .key(let key) = event, key.code == .character("+") {
      count += 1
    }
  }
}

/// An `@Observable` model: the same shape, with observation on the model.
@Observable
private final class ObservedCounter: Application {
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

/// A main-actor model with a main-actor isolated conformance: only a main-actor host can use it.
@MainActor
private final class MainActorCounter: @MainActor Application {
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

/// A nonisolated type declared without the contract, adopted in an extension the way a test or
/// development target adopts a type whose production module stays free of it.
private final class BareCounter {
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

extension BareCounter: Application {}

/// An application that overrides the default `isFinished`.
private final class OneShot: Application {
  private(set) var isFinished = false

  var body: some View {
    Text("one shot")
  }

  func apply(_ event: InputEvent) {
    if case .key = event {
      isFinished = true
    }
  }
}

private let plus = InputEvent.key(Key(code: .character("+")))

/// The columns the root view measures to, which shows `body` reading the current model.
private func measuredColumns<App: Application>(of app: App) -> Int? {
  let graph = ViewGraph(root: { app.body }, size: TerminalSize(columns: 40, rows: 4))
  graph.update()
  graph.layoutIfNeeded()
  return graph.diagnostics.nodes.first { $0.parentIdentity == nil }?.measuredSize?.columns
}

@Test
func `a plain class adopts Application and reads its model in body`() {
  let app = PlainCounter()

  #expect(measuredColumns(of: app) == 18)
  app.apply(plus)

  #expect(measuredColumns(of: app) == 19)
}

@Test
func `an Observable class adopts Application`() {
  let app = ObservedCounter()

  #expect(measuredColumns(of: app) == 18)
  app.apply(plus)

  #expect(measuredColumns(of: app) == 19)
}

@Test @MainActor
func `a main-actor class adopts Application with an isolated conformance`() {
  let app = MainActorCounter()

  #expect(measuredColumns(of: app) == 18)
  app.apply(plus)

  #expect(measuredColumns(of: app) == 19)
}

@Test
func `an extension adopts Application for a type declared without it`() {
  let app = BareCounter()

  #expect(measuredColumns(of: app) == 18)
  app.apply(plus)

  #expect(measuredColumns(of: app) == 19)
}

@Test
func `isFinished defaults to false and a conformer can override it`() {
  let counter = PlainCounter()
  let oneShot = OneShot()

  #expect(counter.isFinished == false)
  counter.apply(plus)
  #expect(counter.isFinished == false)

  #expect(oneShot.isFinished == false)
  oneShot.apply(plus)
  #expect(oneShot.isFinished)
}

@Test @MainActor
func `a main-actor application keeps the default isFinished`() {
  let app = MainActorCounter()

  app.apply(plus)

  #expect(app.isFinished == false)
}
