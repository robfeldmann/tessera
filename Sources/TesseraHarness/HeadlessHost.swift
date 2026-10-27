import TesseraCore
import TesseraRuntime
import TesseraTerminal
import TesseraTerminalCore
import TesseraTerminalInMemory
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

  /// The visible screen as cells, for the goldens and the projection.
  var screen: ScreenGrid { get }

  /// The view graph's current diagnostics.
  var diagnostics: GraphDiagnostics { get }

  /// The graph's diagnostics and the screen, joined as of the last completed step.
  var projection: Projection { get }

  /// The record of the last step, which is the first frame until an event has been sent.
  var lastRecord: TraceRecord? { get }

  /// The record of every step so far, the first frame first.
  var records: [TraceRecord] { get }

  /// Delivers one event and returns once the resulting frame is committed.
  func send(_ event: InputEvent) async throws
}

extension ScreenSnapshot {
  /// One string per row, with trailing blanks trimmed and a wide grapheme's continuation cell
  /// left out.
  var trimmedRows: [String] {
    ScreenGrid(self).textRows
  }
}

/// The records of a run, kept in step order.
@MainActor
private final class RecordLog {
  var records: [TraceRecord] = []
}

/// Runs an application on a terminal session over an in-memory device and reads the result from
/// one persistent virtual terminal.
///
/// The session is the live one: frames reach it through the same ``Driver`` and the same
/// `TerminalSession.draw` as in a real terminal, and the bytes it writes are fed to the
/// virtual terminal, so the screen the host reports is what a terminal would show.
@MainActor
final class HeadlessHost<App: Application>: ScenarioHost {
  private let driver: Driver<App>
  private let device: InMemoryTerminalDevice
  private let terminal: VirtualTerminal
  private let log: RecordLog

  var size: TerminalSize {
    driver.size
  }

  var isFinished: Bool {
    driver.isFinished
  }

  var screenRows: [String] {
    screen.textRows
  }

  var screen: ScreenGrid {
    ScreenGrid(terminal.snapshot())
  }

  var diagnostics: GraphDiagnostics {
    driver.graph.diagnostics
  }

  var projection: Projection {
    Projection(
      diagnostics: driver.graph.diagnostics, screen: screen,
      pass: driver.lastRecord?.seq ?? 0)
  }

  var lastRecord: TraceRecord? {
    driver.lastRecord
  }

  var records: [TraceRecord] {
    log.records
  }

  private init(
    driver: Driver<App>,
    device: InMemoryTerminalDevice,
    terminal: VirtualTerminal,
    log: RecordLog
  ) {
    self.driver = driver
    self.device = device
    self.terminal = terminal
    self.log = log
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
    // The device never finishes its input until the run ends, and answers a session's colour
    // queries from the profile's theme, so the colours a session learns come from the
    // scenario and never from the virtual terminal's own defaults.
    let answerer = TerminalAnswerer(theme: profile.theme)
    let device = InMemoryTerminalDevice(
      size: size,
      cellPixelSize: nil,
      inputBytes: [],
      keepsInputOpen: true
    ) { answerer.replies(to: $0) }
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
      let log = RecordLog()
      let driver = Driver(
        app: app, size: size, session: session
      ) { log.records.append($0) }
      try await driver.start()
      try await body(
        HeadlessHost(driver: driver, device: device, terminal: terminal, log: log))
    }
    do {
      try await InMemoryTerminalSession(device: device).withApplicationTerminal(
        configuration: configuration,
        environment: [:]
      ) { session in
        session.outputTap = { terminal.feed($0) }
        try await scope(session)
      }
    } catch {
      await device.closeInput()
      throw error
    }
    await device.closeInput()
  }

  func send(_ event: InputEvent) async throws {
    if case .resize(let newSize) = event {
      await device.resize(to: newSize)
      try terminal.resize(newSize)
    }
    try await driver.step(event)
  }
}
