import TesseraCore
import TesseraRuntime
import TesseraTerminal
import TesseraTerminalCore
import TesseraTerminalIO
import TesseraTerminalInput
import TesseraTerminalSnapshotSupport

/// What a scenario runner or a snapshot test needs from a running application, without its
/// type.
@MainActor
package protocol ScenarioHost: AnyObject {
  /// The size the application is laid out at.
  var size: TerminalSize { get }

  /// Whether the application has asked its host to stop.
  var isFinished: Bool { get }

  /// The visible screen, one string per row, with trailing blanks trimmed.
  var screenRows: [String] { get }

  /// The view graph's current diagnostics.
  var diagnostics: GraphDiagnostics { get }

  /// Delivers one event and returns once the resulting frame is committed.
  func send(_ event: InputEvent) async throws
}

extension ScreenSnapshot {
  /// One string per row, with trailing blanks trimmed.
  var trimmedRows: [String] {
    cells.map { row in
      var text = String(row.map(\.character))
      while text.last == " " {
        text.removeLast()
      }
      return text
    }
  }
}

/// Runs an application on a terminal session over a headless device and reads the result from
/// one persistent virtual terminal.
///
/// The session is the live one: frames reach it through the same ``Driver`` and the same
/// `TerminalSession.draw` as in a real terminal, and the bytes it writes are fed to the
/// virtual terminal, so the screen the host reports is what a terminal would show.
@MainActor
final class HeadlessHost<App: Application>: ScenarioHost {
  private let driver: Driver<App>
  private let device: HeadlessTerminalDevice
  private let terminal: VirtualTerminal

  var size: TerminalSize {
    driver.size
  }

  var isFinished: Bool {
    driver.isFinished
  }

  var screenRows: [String] {
    terminal.snapshot().trimmedRows
  }

  var diagnostics: GraphDiagnostics {
    driver.graph.diagnostics
  }

  private init(
    driver: Driver<App>,
    device: HeadlessTerminalDevice,
    terminal: VirtualTerminal
  ) {
    self.driver = driver
    self.device = device
    self.terminal = terminal
  }

  /// Builds the application, opens a headless session at `viewport`, and runs `body` against
  /// it once the first frame is drawn.
  ///
  /// The session renders with the profile's colour level and gets the profile's colours when
  /// it asks for them. The factory runs once, on the main actor, so every run starts from a
  /// fresh application. The session closes when `body` returns or throws.
  static func run(
    name: String,
    viewport: Viewport,
    profile: TerminalProfile = TerminalProfile(),
    make: @MainActor () -> App,
    body: @escaping @MainActor (any ScenarioHost) async throws -> Void
  ) async throws {
    let app = make()
    let size = try viewport.size(for: app, named: name)
    let device = HeadlessTerminalDevice(size: size, theme: profile.theme)
    let terminal = VirtualTerminal.ghosttyOrUnavailable(
      cols: size.columns, rows: size.rows)
    // No terminal modes and no synchronized output: a headless frame is plain cells.
    let configuration = TerminalApplicationConfiguration(
      modes: [],
      synchronizedOutput: .disabled,
      colorCapability: profile.colors.override
    )

    // The session's scope hands this function value, not the generic driver, to the main
    // actor, so the application's conformance never crosses out of it.
    let scope: @MainActor (TerminalSession) async throws -> Void = { session in
      let driver = Driver(app: app, size: size, session: session)
      try await driver.start()
      try await body(HeadlessHost(driver: driver, device: device, terminal: terminal))
    }
    do {
      try await TerminalSession.withApplicationTerminal(
        configuration: configuration,
        io: PlatformIO(terminalDevice: device.seam),
        environment: [:]
      ) { session in
        session.outputTap = { terminal.feed($0) }
        try await scope(session)
      }
    } catch {
      await device.finish()
      throw error
    }
    await device.finish()
  }

  func send(_ event: InputEvent) async throws {
    if case .resize(let newSize) = event {
      await device.resize(to: newSize)
      try terminal.resize(newSize)
    }
    try await driver.step(event)
  }
}
