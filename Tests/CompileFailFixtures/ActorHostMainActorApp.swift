// This file is intentionally ill-typed. scripts/check-isolation-fixtures.sh verifies that an
// actor host cannot step an application whose conformance is main-actor isolated, and that
// the same application steps on a main-actor host (compiled with -D CONTROL).

import TesseraCore
import TesseraRuntime
import TesseraTerminalInput

/// A main-actor model with a main-actor isolated conformance.
@MainActor
final class Browser: @MainActor Application {
  var body: some View {
    Text("Browser")
  }

  func apply(_ event: InputEvent) {}
}

#if CONTROL
  @MainActor
  final class Host {
    func step(_ app: Browser, graph: ViewGraph, event: InputEvent) {
      Step.run(app, graph: graph, event: event, isolation: MainActor.shared)
    }
  }
#else
  actor Host {
    func step(_ app: Browser, graph: ViewGraph, event: InputEvent) {
      Step.run(app, graph: graph, event: event, isolation: self)
    }
  }
#endif
