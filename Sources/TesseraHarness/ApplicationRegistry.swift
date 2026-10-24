import TesseraRuntime
import TesseraTerminal
import TesseraTerminalCore

/// The one place applications are selected by name.
///
/// A registry maps a name to a factory. The harness opens a factory on the main actor, once
/// per run, so every run starts from a fresh application, and a fixture is one more
/// registration of the same type:
///
/// ```swift
/// var registry = ApplicationRegistry()
/// registry.register("browser", viewports: [.desktop, .mobileScreen]) { Browser() }
/// registry.register("browser-empty", viewports: [.desktop]) { Browser(files: .empty) }
/// ```
///
/// Registering a name twice is not an error at the registration site. It makes every entry
/// point that reads the registry fail instead, so a later registration never silently
/// replaces an earlier one.
public struct ApplicationRegistry {
  /// One registered application, with its factory erased behind the two ways to run it.
  package struct Entry {
    package let name: String
    package let minimum: TerminalSize?
    package let viewports: [Viewport]

    let headless:
      @MainActor (
        Viewport, @escaping @MainActor (any ScenarioHost) async throws -> Void
      ) async throws -> Void
    let live: @MainActor (TerminalApplicationConfiguration) async throws -> Void
  }

  package private(set) var entries: [Entry] = []

  /// Creates a registry with no applications.
  public init() {}

  /// Registers an application under `name`.
  ///
  /// - Parameters:
  ///   - name: The name scenarios and commands select the application by.
  ///   - minimum: The smallest size the application is designed for, if it declares one.
  ///   - viewports: The viewports the application is checked at. There is no default.
  ///   - make: Builds a fresh application. It runs on the main actor, so an application whose
  ///     model is main-actor isolated can be built here, and a `@Sendable` closure for such
  ///     an application does not compile.
  public mutating func register<App: Application>(
    _ name: String,
    minimum: TerminalSize? = nil,
    viewports: [Viewport],
    make: @escaping @MainActor () -> App
  ) {
    entries.append(
      Entry(
        name: name,
        minimum: minimum,
        viewports: viewports,
        headless: { viewport, body in
          try await HeadlessHost<App>.run(
            name: name, viewport: viewport, make: make, body: body)
        },
        live: { configuration in
          try await LiveHost.run(make: make, configuration: configuration)
        }
      )
    )
  }
}

/// Why the registry could not answer a question.
package enum RegistryError: CustomStringConvertible, Equatable, Error, Sendable {
  /// Names registered more than once, each listed once, in sorted order.
  case duplicate([String])

  /// A name nothing is registered under, with the names that are.
  case unknown(String, accepted: [String])

  package var description: String {
    switch self {
    case .duplicate(let names):
      let quoted = names.map { "`\($0)`" }.joined(separator: ", ")
      return "applications registered more than once: \(quoted)"
    case .unknown(let name, let accepted):
      let list = accepted.isEmpty ? "none registered" : accepted.joined(separator: ", ")
      return "unknown app `\(name)`; accepted: \(list)"
    }
  }
}

extension ApplicationRegistry {
  /// Every entry, sorted by name.
  ///
  /// Every read of the registry goes through here, so a duplicate name fails all of them,
  /// including a lookup of a name that is itself unique.
  package func checkedEntries() throws(RegistryError) -> [Entry] {
    var seen: Set<String> = []
    var duplicates: Set<String> = []
    for entry in entries where !seen.insert(entry.name).inserted {
      duplicates.insert(entry.name)
    }
    guard duplicates.isEmpty else {
      throw .duplicate(duplicates.sorted())
    }
    return entries.sorted { $0.name < $1.name }
  }

  /// The registered names, sorted.
  package func names() throws(RegistryError) -> [String] {
    try checkedEntries().map(\.name)
  }

  /// The entry registered under `name`.
  package func entry(named name: String) throws(RegistryError) -> Entry {
    let entries = try checkedEntries()
    guard let entry = entries.first(where: { $0.name == name }) else {
      throw .unknown(name, accepted: entries.map(\.name))
    }
    return entry
  }
}

extension ApplicationRegistry {
  /// Runs `body` against the application registered as `name`, headless at `viewport`.
  ///
  /// The factory runs once, on the main actor, and the session closes when `body` returns or
  /// throws. A snapshot test is a call to this, a few sends, and an assertion on the screen.
  @MainActor
  package func withHeadlessHost(
    _ name: String,
    at viewport: Viewport,
    _ body: @escaping @MainActor (any ScenarioHost) async throws -> Void
  ) async throws {
    try await entry(named: name).headless(viewport, body)
  }
}
