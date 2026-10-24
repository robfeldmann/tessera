import CustomDump
import Foundation
import InlineSnapshotTesting
import SnapshotTesting
import SnapshotTestingCustomDump
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

    expectNoDifference(report.failures, [])
    assertInlineSnapshot(of: report.observations, as: .customDump) {
      """
      [
        [0]: ScenarioObservation(
          line: 0,
          verb: "replay",
          name: nil,
          lines: [
            [0]: "a",
            [1]: "b"
          ],
          projection: nil
        )
      ]
      """
    }
    expectNoDifference(report.trace.map(\.seq), [0, 1, 2, 3])
  }

  @Test
  func
    `a replay against a different app reports the first field that differs, step by step`()
    async throws
  {
    let records = try await record("growing", [key("+")])
    let other = registryWith("growing") { SteadyApp() }

    let report = await replay(records, app: "growing", in: other)

    assertInlineSnapshot(of: report.failures, as: .customDump) {
      """
      [
        [0]: ScenarioFailure(
          line: 1,
          statement: "step 0: resize 40x12",
          verb: "replay",
          message: "the reasons differ from the recording",
          expected: "layoutEnvironmentChanged, layoutViewChanged, renderEnvironmentChanged, renderRequested, renderViewChanged, updateRequested",
          actual: "renderRequested, updateRequested",
          screen: [
            [0]: "count 0"
          ],
          rule: nil,
          node: nil
        ),
        [1]: ScenarioFailure(
          line: 2,
          statement: "step 1: key +",
          verb: "replay",
          message: "the reasons differ from the recording",
          expected: "layoutEnvironmentChanged, layoutViewChanged, renderEnvironmentChanged, renderRequested, renderViewChanged, updateRequested",
          actual: "layoutViewChanged, renderRequested, renderViewChanged, updateRequested",
          screen: [
            [0]: "count 1"
          ],
          rule: nil,
          node: nil
        )
      ]
      """
    }
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

    expectNoDifference(bytesOnly.failures, [])
    assertInlineSnapshot(of: measured.failures, as: .customDump) {
      """
      [
        [0]: ScenarioFailure(
          line: 2,
          statement: "step 1: key +",
          verb: "replay",
          message: "the costs differ from the recording",
          expected: "bodies=1 bytes=116 measures=5 placements=4 renders=1",
          actual: "bodies=1 bytes=17 measures=4 placements=4 renders=1",
          screen: [
            [0]: "count 1"
          ],
          rule: nil,
          node: nil
        )
      ]
      """
    }
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

    assertInlineSnapshot(
      of: [reasonReport.failures, rowReport.failures, drawReport.failures],
      as: .customDump
    ) {
      """
      [
        [0]: [
          [0]: ScenarioFailure(
            line: 2,
            statement: "step 1: key +",
            verb: "replay",
            message: "the reasons differ from the recording",
            expected: "layoutViewChanged, renderRequested, renderViewChanged, updateRequested, layoutViewportChanged",
            actual: "layoutViewChanged, renderRequested, renderViewChanged, updateRequested",
            screen: [
              [0]: "count 1"
            ],
            rule: nil,
            node: nil
          )
        ],
        [1]: [
          [0]: ScenarioFailure(
            line: 2,
            statement: "step 1: key +",
            verb: "replay",
            message: "the changed rows differ from the recording",
            expected: "[3]",
            actual: "[0]",
            screen: [
              [0]: "count 1"
            ],
            rule: nil,
            node: nil
          )
        ],
        [2]: [
          [0]: ScenarioFailure(
            line: 3,
            statement: "step 2: key x",
            verb: "replay",
            message: "the recording drew a frame and the replay drew none",
            expected: "drew true",
            actual: "drew false",
            screen: [
              [0]: "count 1"
            ],
            rule: nil,
            node: nil
          )
        ]
      ]
      """
    }
  }

  @Test
  func `an app that finishes before the trace does is a failure that says so`()
    async throws
  {
    let records = try await record("growing", [key("+"), key("+")])
    let finished = registryWith("growing") { FinishedApp() }

    let report = await replay(records, app: "growing", in: finished)

    assertInlineSnapshot(of: report.failures.last, as: .customDump) {
      """
      ScenarioFailure(
        line: 2,
        statement: "step 1: key +",
        verb: "replay",
        message: "the application finished before step 1, where the recording kept going",
        expected: nil,
        actual: nil,
        screen: nil,
        rule: nil,
        node: nil
      )
      """
    }
  }

  // MARK: What a replay refuses

  @Test
  func `a trace with an event replay cannot deliver is refused before anything runs`()
    async throws
  {
    var records = try await record("steady", [key("+"), key("+")])
    records[1] = TraceRecord(
      seq: 1, event: TraceEvent(.unknown([0x1b, 0x5b])), drew: false, reasons: [],
      nodes: .init(added: [], changed: [], removed: []), rows: [],
      cost: StepCost(bodies: 0, bytes: 0, measures: 0, placements: 0, renders: 0))

    let report = await replay(records, app: "steady")

    assertInlineSnapshot(of: report, as: .customDump) {
      """
      ScenarioReport(
        scenario: "run.trace.jsonl",
        failures: [
          [0]: ScenarioFailure(
            line: 2,
            statement: "step 1",
            verb: "usage",
            message: "step 1 holds an event replay cannot deliver: unknown (not replayable); replay delivers keys, pastes, resizes, and focus changes",
            expected: nil,
            actual: nil,
            screen: nil,
            rule: nil,
            node: nil
          )
        ],
        observations: [],
        recorded: [],
        seconds: [],
        trace: []
      )
      """
    }
  }

  @Test
  func `a trace with the terminal's focus changes replays like any other`() async throws {
    // A live session records a focus change as it receives it, and that must not make the
    // whole trace unreplayable.
    let records = try await record(
      "growing", [.focusGained, key("+"), .focusLost, key("+"), .focusGained])

    expectNoDifference(
      records.map(\.event.type),
      ["resize", "focusGained", "key", "focusLost", "key", "focusGained"]
    )
    let report = await replay(records, app: "growing")

    expectNoDifference(report.failures, [])
    expectNoDifference(report.trace.map(\.event), records.map(\.event))
    expectNoDifference(report.observations.first?.lines, ["a", "b", "c"])
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

    assertInlineSnapshot(
      of: [withoutStart.failures, skippedStep.failures, empty.failures], as: .customDump
    ) {
      """
      [
        [0]: [
          [0]: ScenarioFailure(
            line: 1,
            statement: "",
            verb: "usage",
            message: "the first record must be step 0, the resize that tells the application its starting size; it is step 1, key +",
            expected: nil,
            actual: nil,
            screen: nil,
            rule: nil,
            node: nil
          )
        ],
        [1]: [
          [0]: ScenarioFailure(
            line: 2,
            statement: "",
            verb: "usage",
            message: "the steps are numbered 0, 1, 2, …; this one is 5",
            expected: nil,
            actual: nil,
            screen: nil,
            rule: nil,
            node: nil
          )
        ],
        [2]: [
          [0]: ScenarioFailure(
            line: 0,
            statement: "",
            verb: "usage",
            message: "the trace holds no steps",
            expected: nil,
            actual: nil,
            screen: nil,
            rule: nil,
            node: nil
          )
        ]
      ]
      """
    }
  }

  @Test
  func `text that is not a trace is a usage failure at the line that is wrong`() async {
    let report = await Replayer.replay(
      text: "{\"seq\": 0}\n", file: "bad.jsonl", app: "steady", registry: registry)

    assertInlineSnapshot(of: report.failures, as: .customDump) {
      """
      [
        [0]: ScenarioFailure(
          line: 1,
          statement: "",
          verb: "usage",
          message: "this line is not a trace record (no `version`)",
          expected: nil,
          actual: nil,
          screen: nil,
          rule: nil,
          node: nil
        )
      ]
      """
    }
    assertInlineSnapshot(of: report.description, as: .lines) {
      """
      FAIL bad.jsonl
      bad.jsonl:1: error: this line is not a trace record (no `version`)
      """
    }
  }

  @Test
  func `an unknown app is a harness failure naming the registered ones`() async throws {
    let records = try await record("steady", [])

    let report = await replay(records, app: "ghost")

    assertInlineSnapshot(of: report.failures, as: .customDump) {
      """
      [
        [0]: ScenarioFailure(
          line: 0,
          statement: "",
          verb: "harness",
          message: "unknown app `ghost`; accepted: growing, layers, list-layers, list-overlap, overflow, overlap, shadowed-list, steady, styled, wide",
          expected: nil,
          actual: nil,
          screen: nil,
          rule: nil,
          node: nil
        )
      ]
      """
    }
  }
}
