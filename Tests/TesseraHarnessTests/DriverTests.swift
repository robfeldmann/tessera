import TesseraCore
import TesseraRuntime
import TesseraTerminal
import TesseraTerminalCore
import TesseraTerminalInput
import TesseraTerminalTestSupport
import Testing

@testable import TesseraHarness

@MainActor
struct DriverTests {
  private static let configuration = TerminalApplicationConfiguration(
    modes: [.rawMode, .altScreen],
    synchronizedOutput: .disabled,
    colorCapability: .force(.noColor)
  )

  private func makeDevice(_ size: TerminalSize) -> InMemoryTerminalDevice {
    InMemoryTerminalDevice(
      size: size, cellPixelSize: nil, inputBytes: [], keepsInputOpen: true)
  }

  /// Opens a session over `device`, runs `scope` on the main actor, and closes the session.
  ///
  /// The device stays readable after the session's scope closes.
  private func inSession(
    over device: InMemoryTerminalDevice,
    _ scope: @escaping @MainActor (TerminalSession) async throws -> Void
  ) async throws {
    try await InMemoryTerminalSession(device: device).withApplicationTerminal(
      configuration: Self.configuration
    ) { session in
      do {
        try await scope(session)
      } catch {
        await device.closeInput()
        throw error
      }
      await device.closeInput()
    }
  }

  @Test
  func `a view graph renders through draw into an in-memory device and the bytes arrive`()
    async throws
  {
    let size = TerminalSize(columns: 12, rows: 2)
    let device = makeDevice(size)

    try await inSession(over: device) { session in
      let driver = Driver(app: CounterApp(), size: size, session: session)
      try await driver.start()
      try await driver.step(.key(Key(code: .character("+"))))
    }

    let output = try #require(String(bytes: await device.bytes, encoding: .utf8))
    #expect(
      output.debugDescription
        == #""\u{1B}[?1049h\u{1B}[2J\u{1B}[1;1H\u{1B}[0mCount: 0    \u{1B}[2;1H            "#
        + #"\u{1B}[0m\u{1B}[?25l\u{1B}[1;8H1\u{1B}[0m\u{1B}[?25l\u{1B}[?25h"#
        + #"\u{1B}_Ga=d,d=A\u{1B}\\\u{1B}[?1049l""#
    )
    #expect(Array(await device.events.suffix(2)) == [.exitAltScreen, .exitRawMode])
  }

  @Test
  func `the first frame is drawn at start and carries the starting size to the app`()
    async throws
  {
    let size = TerminalSize(columns: 50, rows: 12)
    let device = makeDevice(size)

    try await inSession(over: device) { session in
      try await Driver(app: WorkspaceApp(), size: size, session: session).start()
    }

    let output = try #require(String(bytes: await device.bytes, encoding: .utf8))
    #expect(output.contains("Workspace 50x12"))
  }

  @Test
  func `a step that leaves the graph clean writes no frame`() async throws {
    let size = TerminalSize(columns: 12, rows: 2)
    let device = makeDevice(size)
    var counts: [Int] = []

    try await inSession(over: device) { session in
      let driver = Driver(app: StillApp(), size: size, session: session)
      try await driver.start()
      counts.append(await device.bytes.count)
      try await driver.step(.key(Key(code: .character("x"))))
      #expect(driver.graph.needsRender == false)
      counts.append(await device.bytes.count)
    }

    #expect(counts.count == 2)
    #expect(counts.first ?? 0 > 0)
    #expect(counts.first == counts.last)
  }

  @Test
  func `the host stops after the step that sets isFinished`() async throws {
    let size = TerminalSize(columns: 12, rows: 2)
    let app = CounterApp()

    try await inSession(over: makeDevice(size)) { session in
      let driver = Driver(app: app, size: size, session: session)
      try await driver.start()
      #expect(driver.isFinished == false)
      try await driver.step(.key(Key(code: .character("q"))))
      #expect(driver.isFinished)
    }

    #expect(app.finished)
  }

  @Test
  func `a resize event resizes the graph and reaches the app`() async throws {
    var rows: [String] = []
    var size = TerminalSize(columns: 1, rows: 1)
    let make: @MainActor () -> WorkspaceApp = { WorkspaceApp() }

    try await HeadlessHost<WorkspaceApp>.run(
      name: "workspace", viewport: .desktop, make: make
    ) { host in
      try await host.send(.resize(TerminalSize(columns: 50, rows: 12)))
      rows = host.screenRows
      size = host.size
    }

    #expect(size == TerminalSize(columns: 50, rows: 12))
    #expect(rows.first == "Workspace 50x12")
    #expect(rows.count == 12)
  }

  @Test
  func `the headless screen is what the live draw path wrote`() async throws {
    var rows: [String] = []
    let make: @MainActor () -> CounterApp = { CounterApp() }

    try await HeadlessHost<CounterApp>.run(
      name: "counter", viewport: .custom(TerminalSize(columns: 20, rows: 3)), make: make
    ) { host in
      try await host.send(.key(Key(code: .character("+"))))
      try await host.send(.key(Key(code: .character("+"))))
      rows = host.screenRows
    }

    #expect(rows == ["Count: 2", "", ""])
  }
}

@MainActor
struct StepHostingTests {
  @Test
  func
    `a nonisolated app steps on a per-test actor and on the main actor through one step`()
    async throws
  {
    let size = TerminalSize(columns: 20, rows: 2)
    let plus = InputEvent.key(Key(code: .character("+")))

    let host = await ActorHost<CounterApp>(size: size) { CounterApp() }
    await host.step(plus)
    await host.step(plus)
    let actorCount = await host.read { $0.count }
    let actorRows = await host.screenRows()

    let app = CounterApp()
    let graph = ViewGraph(root: { app.body }, size: size)
    Step.run(app, graph: graph, event: plus, isolation: MainActor.shared)
    Step.run(app, graph: graph, event: plus, isolation: MainActor.shared)

    #expect(actorCount == 2)
    #expect(app.count == 2)
    #expect(actorRows.first == "Count: 2")
  }

  @Test
  func `an app with a main-actor model steps through the same step on the main actor`() {
    let app = MainActorCounterApp()
    let graph = ViewGraph(root: { app.body }, size: TerminalSize(columns: 30, rows: 2))

    Step.run(
      app, graph: graph, event: .key(Key(code: .character("+"))),
      isolation: MainActor.shared)

    #expect(app.count == 1)
  }

  @Test
  func `an observable app steps like any other`() async {
    let host = await ActorHost<ObservedCounterApp>(
      size: TerminalSize(columns: 30, rows: 2)
    ) {
      ObservedCounterApp()
    }

    await host.step(.key(Key(code: .character("+"))))

    #expect(await host.screenRows().first == "Observed count: 1")
  }
}
