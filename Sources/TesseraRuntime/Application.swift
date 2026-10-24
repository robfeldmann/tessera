import TesseraCore
import TesseraTerminalInput

/// An application that a Tessera host can drive: a reference type that owns its model and
/// describes its interface as a view.
///
/// A host constructs the application, renders ``body`` through a view graph, and offers each
/// input event to the graph first. The host then calls ``apply(_:)`` for every event the
/// graph left unhandled, and for every resize, and stops after the step in which
/// ``isFinished`` becomes `true`. The application reads and writes its own model; there is no
/// separate state container to adopt.
///
/// ## Isolation
///
/// `Application` refines nothing but `AnyObject`. It is not `@MainActor`, and it does not
/// refine `SendableMetatype`, because either would rule out one of the shapes below. A
/// nonisolated application runs on any host. An application whose model is main-actor
/// isolated declares a main-actor isolated conformance, which only a main-actor host can use;
/// a host on any other actor rejects it at compile time, so no path needs a runtime check of
/// isolation. One application instance belongs to one host.
///
/// ## Adopting Application
///
/// Declare the conformance where the type is declared, so the type's isolation and its
/// conformance agree. There are four shapes.
///
/// A plain class runs on any host:
///
/// ```swift
/// final class Counter: Application {
///   private(set) var count = 0
///   var body: some View { Text("Count: \(count)") }
///   func apply(_ event: InputEvent) {
///     if case .key(let key) = event, key.code == .character("+") { count += 1 }
///   }
/// }
/// ```
///
/// An `@Observable` model is the same: observation lives on the model, not on the host.
///
/// ```swift
/// @Observable final class Counter: Application { /* as above */ }
/// ```
///
/// A module that sets `.defaultIsolation(MainActor.self)` (the Xcode 26 app templates) needs
/// nothing more. Its types are main-actor isolated by inference, and so are their
/// conformances, so they run on a main-actor host and may use any other main-actor type in the
/// module. To let one type also run on other actors, mark it `nonisolated`.
///
/// ```swift
/// final class Notes: Application {
///   let store = NotesStore()  // another main-actor class in the module
///   var body: some View { Text("\(store.saved) saved") }
///   func apply(_ event: InputEvent) { store.save() }
/// }
///
/// nonisolated final class Tool: Application { /* nonisolated members */ }
/// ```
///
/// A type with a main-actor model, such as a store that is itself `@MainActor`, declares the
/// conformance isolated:
///
/// ```swift
/// @MainActor final class Browser: @MainActor Application {
///   let store: StoreOf<BrowserFeature>
///   var body: some View { Text("\(store.items.count) items") }
///   func apply(_ event: InputEvent) { store.send(.input(event)) }
/// }
/// ```
///
/// When production code must stay free of the contract, a test or development target adopts it
/// with the isolation the type already has: `extension Counter: Application {}` for a
/// nonisolated type, and `extension Notes: @MainActor Application {}` for a main-actor one.
/// Writing `@MainActor` on the conformance is accepted in every mode. Leaving it off depends
/// on the compiler mode of the module that writes the extension: in plain Swift 6 mode it is a
/// compile error, not a runtime trap, and with the `InferIsolatedConformances` upcoming feature
/// or default main-actor isolation the compiler infers the isolated conformance instead.
/// Swift 6.3 infers it under `InferIsolatedConformances` alone only for a type declared
/// `@MainActor`, not for one that is main-actor isolated through its own module's default
/// isolation; Swift 6.4 infers both.
public protocol Application: AnyObject {
  /// The type of the root view.
  associatedtype Body: View

  /// The root view of the application.
  ///
  /// `body` reads the model and hands out `Binding`s, so controlled controls can write
  /// back to it. Reading it must not change the model.
  @ViewBuilder var body: Body { get }

  /// Whether the application has asked its host to stop.
  ///
  /// A host checks this after each step and stops once it is `true`. The default is
  /// `false`. There is no host-owned quit key: an application that wants one matches the
  /// key in ``apply(_:)`` and sets the state this property reads.
  var isFinished: Bool { get }

  /// Applies an input event the view graph left unhandled to the application's model.
  ///
  /// A host calls this for each event whose disposition is `.ignored`, and for every
  /// resize: a resize is never routed to views, so it always reaches the application.
  func apply(_ event: InputEvent)
}

extension Application {
  /// An application runs until it says otherwise.
  public var isFinished: Bool { false }
}
