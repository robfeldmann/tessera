// Compiled by scripts/check-isolation-fixtures.sh as the module `JournalModel`, with
// `-default-isolation MainActor`, the way an app module built from an Xcode 26 template is.
// It declares `Journal` without the `Application` conformance: the second module adopts it.

import TesseraCore
import TesseraTerminalInput

/// A type that is main-actor isolated only through its module's default isolation.
public final class Journal {
  /// The root view.
  public var body: some View {
    Text("Journal")
  }

  /// Creates a journal.
  public init() {}

  /// Ignores every event.
  public func apply(_ event: InputEvent) {}
}
