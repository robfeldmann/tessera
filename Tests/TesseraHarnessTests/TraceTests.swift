import Foundation
import TesseraTerminalCore
import TesseraTerminalInput
import Testing

@testable import TesseraHarness

@MainActor
struct TraceTests {
  private let registry = ProjectionFixtures.registry()

  /// The records of `name` at 40 columns by 12 rows after delivering `events`.
  private func records(
    of name: String, _ events: [InputEvent] = []
  ) async throws -> [TraceRecord] {
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

  private func key(_ character: Character) -> InputEvent {
    .key(Key(code: .character(character)))
  }

  // MARK: Records

  @Test
  func `the first record is step 0 and its event is the starting size`() async throws {
    let records = try await records(of: "steady")

    let first = try #require(records.first)
    #expect(records.count == 1)
    #expect(first.seq == 0)
    #expect(first.version == TraceRecord.currentVersion)
    #expect(first.event == TraceEvent(.resize(TerminalSize(columns: 40, rows: 12))))
    #expect(first.drew)
    #expect(first.cost.bytes > 0)
    #expect(first.nodes.added.first == "root")
    #expect(first.nodes.changed.isEmpty && first.nodes.removed.isEmpty)
    #expect(first.rows == [0])
  }

  @Test
  func `every step numbers itself and names the reasons its frame was drawn`()
    async throws
  {
    let records = try await records(of: "layers", [key("x"), key("y")])

    #expect(records.map(\.seq) == [0, 1, 2])
    for record in records {
      #expect(record.drew)
      #expect(record.reasons.contains("updateRequested"), "step \(record.seq)")
      #expect(record.reasons.contains("renderRequested"), "step \(record.seq)")
      #expect(record.reasons == record.reasons.sorted(), "the library's fixed order")
    }
  }

  @Test
  func `a resize names the viewport as a cause of the redraw`() async throws {
    let records = try await records(
      of: "layers", [.resize(TerminalSize(columns: 30, rows: 10)), key("x")])

    #expect(records[1].event == TraceEvent(.resize(TerminalSize(columns: 30, rows: 10))))
    #expect(records[1].reasons.contains("layoutViewportChanged"))
    #expect(records[1].reasons.contains("renderViewportChanged"))
    #expect(!records[2].reasons.contains("layoutViewportChanged"))
    #expect(!records[0].reasons.contains("layoutViewportChanged"))
  }

  @Test
  func `a step that leaves the graph clean draws nothing and writes no bytes`()
    async throws
  {
    let records = try await records(of: "steady", [key("x"), key("+"), key("x")])

    let ignored = records[1]
    #expect(!ignored.drew)
    #expect(
      ignored.cost
        == StepCost(bodies: 0, bytes: 0, measures: 0, placements: 0, renders: 0))
    #expect(ignored.rows.isEmpty)
    #expect(ignored.nodes == TraceRecord.NodeChanges(added: [], changed: [], removed: []))
    #expect(ignored.reasons == ["updateRequested"])
    #expect(records[2].drew)
    #expect(records[2].rows == [0])
    #expect(records[2].cost.bytes > 0)
    #expect(!records[3].drew)
  }

  @Test
  func `a step lists the nodes it added and removed by identity`() async throws {
    let records = try await records(of: "growing", [key("+"), key("+"), key("-")])

    #expect(records[1].nodes.added.contains { $0.hasSuffix("id(b)") })
    #expect(records[2].nodes.added.contains { $0.hasSuffix("id(c)") })
    #expect(records[3].nodes.removed.contains { $0.hasSuffix("id(c)") })
    #expect(records[3].nodes.added.isEmpty)
  }

  @Test
  func `a node whose frame moved is changed and a node that did not is not`() async throws
  {
    let records = try await records(
      of: "layers", [.resize(TerminalSize(columns: 20, rows: 12))])

    #expect(records[1].nodes.added.isEmpty)
    #expect(records[1].nodes.removed.isEmpty)
    #expect(!records[1].nodes.changed.contains("root/index(0)/index(2)/id(a)"))
    #expect(records[1].nodes.changed.contains("root"))
  }

  // MARK: Events

  @Test
  func `an event is spelled the way a scenario statement spells it`() {
    #expect(TraceEvent(.key(Key(code: .down))).key == "ArrowDown")
    #expect(TraceEvent(.key(Key(code: .tab, modifiers: .shift))).key == "Shift+Tab")
    #expect(
      TraceEvent(.key(Key(code: .character("c"), modifiers: .control))).key == "Ctrl+c")
    #expect(TraceEvent(.key(Key(code: .character(" ")))).key == "Space")
    #expect(TraceEvent(.paste("a b")).text == "a b")
    #expect(TraceEvent(.resize(TerminalSize(columns: 9, rows: 4))).size == "9x4")
    #expect(
      TraceEvent(.key(Key(code: .character("a"), kind: .release))).kind == "release")
    #expect(TraceEvent(.key(Key(code: .character("a"), kind: .repeat))).kind == "repeat")
    #expect(TraceEvent(.key(Key(code: .character("a")))).kind == nil)
  }

  @Test
  func `an event the grammar cannot say is recorded as other and cannot be replayed`() {
    for event in [
      InputEvent.focusGained, .focusLost, .unknown([0x1b, 0x5b]),
      .primaryDeviceAttributes([1]),
    ] {
      let recorded = TraceEvent(event)
      #expect(recorded.type == "other")
      #expect(recorded.inputEvent == nil)
    }
    let capsLock = TraceEvent(.key(Key(code: .character("a"), modifiers: .capsLock)))
    #expect(capsLock.type == "other")
    #expect(capsLock.detail?.hasPrefix("key") == true)
  }

  @Test
  func `a recorded event delivers again as the event it came from`() {
    let events: [InputEvent] = [
      .key(Key(code: .left)),
      .key(Key(code: .character("c"), modifiers: [.control, .alt])),
      .key(Key(code: .function(5))), .key(Key(code: .character("a"), kind: .release)),
      .paste("x y"), .resize(TerminalSize(columns: 7, rows: 3)),
    ]

    for event in events {
      #expect(TraceEvent(event).inputEvent == event, "\(event)")
    }
  }

  // MARK: Lines and files

  @Test
  func `a record is one line of sorted-key JSON with its version`() async throws {
    let records = try await records(of: "steady")

    let line = try #require(records.first?.line)
    #expect(!line.contains("\n"))
    let keys = ["cost", "drew", "event", "nodes", "reasons", "rows", "seq", "version"]
    let positions = keys.compactMap { line.range(of: "\"\($0)\":")?.lowerBound }
    #expect(positions.count == keys.count)
    #expect(positions == positions.sorted())
    #expect(line.contains(#""version":1"#))
  }

  @Test
  func `a trace file reads back the records it was written from`() async throws {
    let records = try await records(of: "growing", [key("+"), key("-")])

    let text = TraceFile.text(of: records)

    #expect(text.hasSuffix("}\n"))
    #expect(text.split(separator: "\n").count == records.count)
    #expect(try TraceFile.records(in: text) == records)
    #expect(try TraceFile.records(in: "\n" + text + "\n\n") == records)
  }

  @Test
  func `a line that is not a record fails with its line number and what is wrong`() throws
  {
    let valid = TraceRecord(
      seq: 0, event: TraceEvent(.resize(TerminalSize(columns: 4, rows: 1))), drew: true,
      reasons: [], nodes: .init(added: [], changed: [], removed: []), rows: [],
      cost: StepCost(bodies: 0, bytes: 0, measures: 0, placements: 0, renders: 0))

    let notJSON = #expect(throws: TraceFile.ReadError.self) {
      try TraceFile.records(in: valid.line + "\nnot json\n")
    }
    let missing = #expect(throws: TraceFile.ReadError.self) {
      try TraceFile.records(in: valid.line + "\n" + #"{"version":1}"# + "\n")
    }
    let later = #expect(throws: TraceFile.ReadError.self) {
      try TraceFile.records(
        in: valid.line.replacingOccurrences(of: #""version":1"#, with: #""version":2"#))
    }

    #expect(notJSON?.line == 2)
    #expect(notJSON?.message.contains("not a trace record") == true)
    #expect(missing?.line == 2)
    #expect(later?.line == 1)
    #expect(later?.message.contains("version 2") == true)
  }

  @Test
  func
    `a scenario's trace file mirrors its path under the directory and stays inside it`()
  {
    #expect(
      TraceFile.path(forScenario: "Examples/Scenarios/flex-desktop.scn", in: "out")
        == "out/Examples/Scenarios/flex-desktop.trace.jsonl")
    #expect(
      TraceFile.path(forScenario: "/tmp/../etc/x.scn", in: "out")
        == "out/tmp/etc/x.trace.jsonl")
    #expect(
      TraceFile.path(forScenario: "./a/./b.scn", in: "out") == "out/a/b.trace.jsonl")
    #expect(
      TraceFile.path(forScenario: #"C:\work\s.scn"#, in: "out")
        == "out/C_/work/s.trace.jsonl")
  }
}
