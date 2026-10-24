import TesseraCore
import TesseraTerminalInput

/// The one loop body that every host runs once per input event.
///
/// A host owns an application and a ``ViewGraph`` in its own isolation and calls
/// ``run(_:graph:event:isolation:)`` for each event it receives. The function is nonisolated
/// and takes that isolation as a parameter, so the compiler proves that the application is
/// only ever touched from the host that owns it: a main-actor host passes `MainActor.shared`,
/// which accepts an application with a main-actor isolated conformance, and a host on any
/// other actor passes `self`, which rejects it at the call site. There is no default for the
/// parameter, so a nonisolated caller cannot compile the call.
package enum Step {
  /// Delivers one input event to the graph and the application, then updates the graph.
  ///
  /// The order is fixed:
  ///
  /// 1. A `.resize` event resizes the graph first, so every later stage sees the new size.
  /// 2. The graph dispatches the event to its views.
  /// 3. The application applies the event when the graph left it `.ignored`, and always when it
  ///    is a resize.
  /// 4. The graph updates, so the next render reflects whatever the application changed.
  ///
  /// A resize always reaches the application, whatever the graph answered. It describes the
  /// terminal rather than the user, so it is never routed to a view, and a view that handled it
  /// would otherwise hide the new size from the application's model. Events other than resizes
  /// reach the application only when no view handled them.
  ///
  /// - Parameters:
  ///   - app: The application, owned by the host.
  ///   - graph: The view graph that lowers `app.body`, owned by the host.
  ///   - event: The input event to deliver.
  ///   - isolation: The host's isolation; the host passes its own.
  /// - Returns: How the graph disposed of the event.
  @discardableResult
  package static func run<App: Application>(
    _ app: App,
    graph: ViewGraph,
    event: InputEvent,
    isolation: isolated any Actor
  ) -> EventDisposition {
    var isResize = false
    if case .resize(let size) = event {
      isResize = true
      graph.resize(to: size)
    }
    let disposition = graph.dispatch(event)
    if disposition == .ignored || isResize {
      app.apply(event)
    }
    graph.update()
    return disposition
  }
}
