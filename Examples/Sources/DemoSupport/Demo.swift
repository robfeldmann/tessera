import Tessera
import TesseraHarness

/// One of Tessera's own per-component example apps.
///
/// A demo is an ``Application`` that also declares how the harness finds and checks it. Every
/// declaration is required: there is no default name, size, viewport list, or fixture list, so
/// a demo states each of them where it is written.
///
/// A demo handles its own quit key in ``Application/apply(_:)``, matching it with
/// ``isQuitKey(_:)``, and reports that through ``Application/isFinished``; the harness has no
/// quit key. A demo shows its component working: it is interactive, it shows every style and
/// variant that can differ, and it uses only what the library provides. When a demo exposes a
/// library defect, the library gets the fix and the demo gets no workaround.
public protocol Demo: Application {
  /// The registry name: kebab-case, unique across every registration.
  static var name: String { get }

  /// The smallest size the demo is designed for.
  static var minimum: TerminalSize { get }

  /// The viewports the demo is checked at.
  static var viewports: [Viewport] { get }

  /// Further registrations of the same demo, each starting from a different state.
  static var fixtures: [DemoFixture<Self>] { get }

  /// Creates the demo in its initial state.
  init()
}

/// A further registration of a demo that starts from a state other than its initial one.
///
/// A fixture takes the demo's minimum size and viewports. Its name is a registry name like
/// any other, so a scenario selects it with `app NAME`.
public struct DemoFixture<D: Demo>: Sendable {
  /// The registry name of the fixture.
  public let name: String

  let make: @MainActor () -> D

  /// Creates a fixture registered as `name`.
  ///
  /// - Parameter make: Builds the demo in the fixture's state. It runs on the main actor,
  ///   once per run.
  public init(_ name: String, make: @escaping @MainActor () -> D) {
    self.name = name
    self.make = make
  }
}
