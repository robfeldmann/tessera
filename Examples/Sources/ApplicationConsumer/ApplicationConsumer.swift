import Tessera

// This target is compiled from outside the root package and imports only `Tessera`, so the
// Examples build fails if `Tessera` stops re-exporting `TesseraRuntime`: the adoption tests
// in the root package cannot see that.

/// A nonisolated application: it runs on any host.
final class CounterApplication: Application {
  private(set) var count = 0

  var body: some View {
    Text("Count: \(count)")
  }

  func apply(_ event: InputEvent) {
    if case .key(let key) = event, key.code == .character("+") {
      count += 1
    }
  }
}

/// A main-actor application with an isolated conformance: only a main-actor host can use it.
@MainActor
final class MainActorCounterApplication: @MainActor Application {
  private(set) var count = 0

  var body: some View {
    Text("Count: \(count)")
  }

  func apply(_ event: InputEvent) {
    if case .key(let key) = event, key.code == .character("+") {
      count += 1
    }
  }
}
