import TesseraRuntime
import TesseraTerminal

/// Runs an application in the terminal this process is attached to.
///
/// The live host opens a session over the real terminal device and steps the application
/// through the same ``Driver`` as the headless host. It has no quit key: it returns when the
/// application reports `isFinished` or the terminal's input ends.
@MainActor
enum LiveHost {
  /// Builds the application, opens the terminal, and runs until the application finishes.
  ///
  /// The factory runs once, on the main actor, before the terminal changes mode.
  static func run<App: Application>(
    make: @MainActor () -> App,
    configuration: TerminalApplicationConfiguration
  ) async throws {
    let app = make()

    // The session's scope hands this function value, not the generic driver, to the main
    // actor, so the application's conformance never crosses out of it.
    let loop: @MainActor (TerminalSession) async throws -> Void = { session in
      let driver = Driver(app: app, size: try await session.size, session: session)
      try await driver.start()
      guard !driver.isFinished else {
        return
      }
      for await event in session.events {
        try await driver.step(event)
        if driver.isFinished {
          return
        }
      }
    }
    try await TerminalSession.withApplicationTerminal(configuration: configuration) {
      try await loop($0)
    }
  }
}
