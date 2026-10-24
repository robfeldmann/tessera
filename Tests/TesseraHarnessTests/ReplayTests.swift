import Foundation
import TesseraRuntime
import TesseraTerminalCore
import TesseraTerminalInput
import Testing

@testable import TesseraHarness

@MainActor
struct ReplayTests {
  private let registry = ProjectionFixtures.registry()

  private func key(_ character: Character) -> InputEvent {
    .key(Key(code: .character(character)))
  }

  /// The records of `name` at 40 columns by 12 rows after `events`.
  private func record(_ name: String, _ events: [InputEvent]) async throws
    -> [TraceRecord]
  {
    final class Box {
      var records: [TraceRecord] = []
    }
    let box = Box()
    try await registry.withHeadlessHost(
      name, at: .custom(TerminalSize(columns: 40, rows: 12))
    ) { host in
      for event in events {
        try await host.send(event)
      }
      box.records = host.records
    }
    return box.records
  }

  private func replay(
    _ records: [TraceRecord], app: String, in registry: ApplicationRegistry? = nil
  ) async -> ScenarioReport {
    await Replayer.replay(
      text: TraceFile.text(of: records), file: "run.trace.jsonl", app: app,
      registry: registry ?? self.registry)
  }

  /// A registry whose only app is `make`'s, registered under `name`.
  private func registryWith<App: Application>(
    _ name: String, _ make: @escaping @MainActor () -> App
  ) -> ApplicationRegistry {
    var registry = ApplicationRegistry()
    registry.register(name, viewports: [.desktop], make: make)
    return registry
  }

  // MARK: What a replay compares

  @Test
  func
    `a trace replays against the app it came from and the final screen is the report's`()
    async throws
  {
    let records = try await record("growing", [key("+"), key("+"), key("-")])

    let report = await replay(records, app: "growing")

    #expect(report.passed, "\(report)")
    #expect(report.observations.map(\.verb) == ["replay"])
    #expect(report.observations.first?.lines == ["a", "b"])
    #expect(report.trace.map(\.seq) == [0, 1, 2, 3])
  }

  @Test
  func
    `a replay against a different app reports the first field that differs, step by step`()
    async throws
  {
    let records = try await record("growing", [key("+")])
    let other = registryWith("growing") { SteadyApp() }

    let report = await replay(records, app: "growing", in: other)

    #expect(!report.passed)
    let first = try #require(report.failures.first)
    #expect(first.verb == "replay")
    #expect(first.statement.hasPrefix("step 0: resize 40x12"))
    #expect(first.line == 1)
    #expect(first.message.hasSuffix("differ from the recording"))
    #expect(first.expected != first.actual)
    #expect(report.failures.count == 2, "the replay goes on and reports step 1 too")
  }

  @Test
  func `the bytes a frame wrote are not compared and the other costs are`() async throws {
    var records = try await record("steady", [key("+")])
    for index in records.indices {
      records[index].cost.bytes += 99
    }

    let bytesOnly = await replay(records, app: "steady")
    records[1].cost.measures += 1
    let measured = await replay(records, app: "steady")

    #expect(bytesOnly.passed, "\(bytesOnly)")
    #expect(measured.failures.map(\.message) == ["the costs differ from the recording"])
    #expect(measured.failures.first?.statement == "step 1: key +")
  }

  @Test
  func `a changed reason, row list, or draw decision is a difference`() async throws {
    let recorded = try await record("steady", [key("+"), key("x")])

    var reasons = recorded
    reasons[1].reasons.append("layoutViewportChanged")
    var rows = recorded
    rows[1].rows = [3]
    var drawing = recorded
    drawing[2].drew = true

    let reasonReport = await replay(reasons, app: "steady")
    let rowReport = await replay(rows, app: "steady")
    let drawReport = await replay(drawing, app: "steady")

    #expect(
      reasonReport.failures.map(\.message) == ["the reasons differ from the recording"])
    #expect(
      rowReport.failures.map(\.message) == ["the changed rows differ from the recording"])
    #expect(
      drawReport.failures.map(\.message) == [
        "the recording drew a frame and the replay drew none"
      ])
  }

  @Test
  func `an app that finishes before the trace does is a failure that says so`()
    async throws
  {
    let records = try await record("growing", [key("+"), key("+")])
    let finished = registryWith("growing") { FinishedApp() }

    let report = await replay(records, app: "growing", in: finished)

    let last = try #require(report.failures.last)
    #expect(last.verb == "replay")
    #expect(last.message.hasPrefix("the application finished before step 1"))
  }

  // MARK: What a replay refuses

  @Test
  func `a trace with an event replay cannot deliver is refused before anything runs`()
    async throws
  {
    var records = try await record("steady", [key("+"), key("+")])
    records[1] = TraceRecord(
      seq: 1, event: TraceEvent(.focusGained), drew: false, reasons: [],
      nodes: .init(added: [], changed: [], removed: []), rows: [],
      cost: StepCost(bodies: 0, bytes: 0, measures: 0, placements: 0, renders: 0))

    let report = await replay(records, app: "steady")

    #expect(report.failures.count == 1)
    let failure = try #require(report.failures.first)
    #expect(failure.verb == "usage")
    #expect(failure.line == 2)
    #expect(failure.message.contains("focusGained"))
    #expect(report.observations.isEmpty, "nothing ran")
  }

  @Test
  func `a trace must start with step 0, the resize that gives the starting size`()
    async throws
  {
    let records = try await record("steady", [key("+")])

    let withoutStart = await replay(Array(records.dropFirst()), app: "steady")
    var skipped = records
    skipped[1].seq = 5
    let skippedStep = await replay(skipped, app: "steady")
    let empty = await Replayer.replay(
      text: "\n", file: "empty.jsonl", app: "steady", registry: registry)

    #expect(withoutStart.failures.map(\.verb) == ["usage"])
    #expect(withoutStart.failures.first?.message.contains("must be step 0") == true)
    #expect(skippedStep.failures.map(\.verb) == ["usage"])
    #expect(skippedStep.failures.first?.line == 2)
    #expect(empty.failures.first?.message == "the trace holds no steps")
  }

  @Test
  func `text that is not a trace is a usage failure at the line that is wrong`() async {
    let report = await Replayer.replay(
      text: "{\"seq\": 0}\n", file: "bad.jsonl", app: "steady", registry: registry)

    #expect(report.failures.map(\.verb) == ["usage"])
    #expect(report.failures.first?.line == 1)
    #expect(report.description.hasPrefix("FAIL bad.jsonl"))
  }

  @Test
  func `an unknown app is a harness failure naming the registered ones`() async throws {
    let records = try await record("steady", [])

    let report = await replay(records, app: "ghost")

    #expect(report.failures.map(\.verb) == ["harness"])
    #expect(report.failures.first?.message.contains("unknown app `ghost`") == true)
  }
}
