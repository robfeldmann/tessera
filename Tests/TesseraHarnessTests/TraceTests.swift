import CustomDump
import Foundation
import InlineSnapshotTesting
import SnapshotTesting
import SnapshotTestingCustomDump
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

    #expect(records.first?.version == TraceRecord.currentVersion)
    assertInlineSnapshot(of: records, as: .customDump) {
      """
      [
        [0]: TraceRecord(
          version: 1,
          seq: 0,
          event: TraceEvent(
            type: "resize",
            key: nil,
            kind: nil,
            text: nil,
            size: "40x12",
            detail: nil
          ),
          drew: true,
          reasons: [
            [0]: "renderRequested",
            [1]: "updateRequested"
          ],
          nodes: TraceRecord.NodeChanges(
            added: [
              [0]: "root",
              [1]: "root/index(0)",
              [2]: "root/index(0)/body",
              [3]: "root/index(0)/body/index(0)"
            ],
            changed: [],
            removed: []
          ),
          rows: [
            [0]: 0
          ],
          cost: StepCost(
            bodies: 0,
            bytes: 573,
            measures: 4,
            placements: 4,
            renders: 1
          )
        )
      ]
      """
    }
  }

  @Test
  func `every step numbers itself and names the reasons its frame was drawn`()
    async throws
  {
    let records = try await records(of: "layers", [key("x"), key("y")])

    assertInlineSnapshot(
      of: records.map { ($0.seq, $0.drew, $0.reasons) }, as: .customDump
    ) {
      """
      [
        [0]: (
          0,
          true,
          [
            [0]: "layoutEnvironmentChanged",
            [1]: "layoutViewChanged",
            [2]: "renderEnvironmentChanged",
            [3]: "renderRequested",
            [4]: "renderViewChanged",
            [5]: "updateRequested"
          ]
        ),
        [1]: (
          1,
          true,
          [
            [0]: "layoutEnvironmentChanged",
            [1]: "layoutViewChanged",
            [2]: "renderEnvironmentChanged",
            [3]: "renderRequested",
            [4]: "renderViewChanged",
            [5]: "updateRequested"
          ]
        ),
        [2]: (
          2,
          true,
          [
            [0]: "layoutEnvironmentChanged",
            [1]: "layoutViewChanged",
            [2]: "renderEnvironmentChanged",
            [3]: "renderRequested",
            [4]: "renderViewChanged",
            [5]: "updateRequested"
          ]
        )
      ]
      """
    }
    for record in records {
      #expect(record.reasons == record.reasons.sorted(), "the library's fixed order")
    }
  }

  @Test
  func `a resize names the viewport as a cause of the redraw`() async throws {
    let records = try await records(
      of: "layers", [.resize(TerminalSize(columns: 30, rows: 10)), key("x")])

    assertInlineSnapshot(of: records.map { ($0.event, $0.reasons) }, as: .customDump) {
      """
      [
        [0]: (
          TraceEvent(
            type: "resize",
            key: nil,
            kind: nil,
            text: nil,
            size: "40x12",
            detail: nil
          ),
          [
            [0]: "layoutEnvironmentChanged",
            [1]: "layoutViewChanged",
            [2]: "renderEnvironmentChanged",
            [3]: "renderRequested",
            [4]: "renderViewChanged",
            [5]: "updateRequested"
          ]
        ),
        [1]: (
          TraceEvent(
            type: "resize",
            key: nil,
            kind: nil,
            text: nil,
            size: "30x10",
            detail: nil
          ),
          [
            [0]: "layoutEnvironmentChanged",
            [1]: "layoutViewChanged",
            [2]: "layoutViewportChanged",
            [3]: "renderEnvironmentChanged",
            [4]: "renderRequested",
            [5]: "renderViewChanged",
            [6]: "renderViewportChanged",
            [7]: "updateRequested"
          ]
        ),
        [2]: (
          TraceEvent(
            type: "key",
            key: "x",
            kind: nil,
            text: nil,
            size: nil,
            detail: nil
          ),
          [
            [0]: "layoutEnvironmentChanged",
            [1]: "layoutViewChanged",
            [2]: "renderEnvironmentChanged",
            [3]: "renderRequested",
            [4]: "renderViewChanged",
            [5]: "updateRequested"
          ]
        )
      ]
      """
    }
  }

  @Test
  func `a step that leaves the graph clean draws nothing and writes no bytes`()
    async throws
  {
    let records = try await records(of: "steady", [key("x"), key("+"), key("x")])

    assertInlineSnapshot(
      of: records.map { ($0.drew, $0.cost, $0.rows, $0.nodes, $0.reasons) },
      as: .customDump
    ) {
      """
      [
        [0]: (
          true,
          StepCost(
            bodies: 0,
            bytes: 573,
            measures: 4,
            placements: 4,
            renders: 1
          ),
          [
            [0]: 0
          ],
          TraceRecord.NodeChanges(
            added: [
              [0]: "root",
              [1]: "root/index(0)",
              [2]: "root/index(0)/body",
              [3]: "root/index(0)/body/index(0)"
            ],
            changed: [],
            removed: []
          ),
          [
            [0]: "renderRequested",
            [1]: "updateRequested"
          ]
        ),
        [1]: (
          false,
          StepCost(
            bodies: 0,
            bytes: 0,
            measures: 0,
            placements: 0,
            renders: 0
          ),
          [],
          TraceRecord.NodeChanges(
            added: [],
            changed: [],
            removed: []
          ),
          [
            [0]: "updateRequested"
          ]
        ),
        [2]: (
          true,
          StepCost(
            bodies: 1,
            bytes: 17,
            measures: 4,
            placements: 4,
            renders: 1
          ),
          [
            [0]: 0
          ],
          TraceRecord.NodeChanges(
            added: [],
            changed: [],
            removed: []
          ),
          [
            [0]: "layoutViewChanged",
            [1]: "renderRequested",
            [2]: "renderViewChanged",
            [3]: "updateRequested"
          ]
        ),
        [3]: (
          false,
          StepCost(
            bodies: 0,
            bytes: 0,
            measures: 0,
            placements: 0,
            renders: 0
          ),
          [],
          TraceRecord.NodeChanges(
            added: [],
            changed: [],
            removed: []
          ),
          [
            [0]: "updateRequested"
          ]
        )
      ]
      """
    }
  }

  @Test
  func `a step lists the nodes it added and removed by identity`() async throws {
    let records = try await records(of: "growing", [key("+"), key("+"), key("-")])

    assertInlineSnapshot(of: records.map(\.nodes), as: .customDump) {
      """
      [
        [0]: TraceRecord.NodeChanges(
          added: [
            [0]: "root",
            [1]: "root/index(0)",
            [2]: "root/index(0)/index(0)",
            [3]: "root/index(0)/index(0)/id(a)",
            [4]: "root/index(0)/index(0)/id(a)/index(0)"
          ],
          changed: [],
          removed: []
        ),
        [1]: TraceRecord.NodeChanges(
          added: [
            [0]: "root/index(0)/index(0)/id(b)",
            [1]: "root/index(0)/index(0)/id(b)/index(0)"
          ],
          changed: [
            [0]: "root",
            [1]: "root/index(0)",
            [2]: "root/index(0)/index(0)"
          ],
          removed: []
        ),
        [2]: TraceRecord.NodeChanges(
          added: [
            [0]: "root/index(0)/index(0)/id(c)",
            [1]: "root/index(0)/index(0)/id(c)/index(0)"
          ],
          changed: [
            [0]: "root",
            [1]: "root/index(0)",
            [2]: "root/index(0)/index(0)"
          ],
          removed: []
        ),
        [3]: TraceRecord.NodeChanges(
          added: [],
          changed: [
            [0]: "root",
            [1]: "root/index(0)",
            [2]: "root/index(0)/index(0)"
          ],
          removed: [
            [0]: "root/index(0)/index(0)/id(c)",
            [1]: "root/index(0)/index(0)/id(c)/index(0)"
          ]
        )
      ]
      """
    }
  }

  @Test
  func `a node whose frame moved is changed and a node that did not is not`() async throws
  {
    let records = try await records(
      of: "layers", [.resize(TerminalSize(columns: 20, rows: 12))])

    assertInlineSnapshot(of: records[1].nodes, as: .customDump) {
      """
      TraceRecord.NodeChanges(
        added: [],
        changed: [
          [0]: "root",
          [1]: "root/index(0)",
          [2]: "root/index(0)/index(0)",
          [3]: "root/index(0)/index(1)",
          [4]: "root/index(0)/index(2)/id(a)/index(0)",
          [5]: "root/index(0)/index(2)/id(b)/index(0)"
        ],
        removed: []
      )
      """
    }
  }

  // MARK: Events

  @Test
  func `an event is spelled the way a scenario statement spells it`() {
    let keys = [
      Key(code: .down), Key(code: .tab, modifiers: .shift),
      Key(code: .character("c"), modifiers: .control), Key(code: .character(" ")),
    ]
    let kinds = [KeyEventKind.release, .repeat, .press].map {
      TraceEvent(.key(Key(code: .character("a"), kind: $0))).kind
    }

    expectNoDifference(
      keys.map { TraceEvent(.key($0)).key },
      ["ArrowDown", "Shift+Tab", "Ctrl+c", "Space"])
    expectNoDifference(kinds, ["release", "repeat", nil])
    #expect(TraceEvent(.paste("a b")).text == "a b")
    #expect(TraceEvent(.resize(TerminalSize(columns: 9, rows: 4))).size == "9x4")
  }

  @Test
  func `an event neither the grammar nor replay can say is recorded as other`() {
    let recorded = [
      InputEvent.unknown([0x1b, 0x5b]), .primaryDeviceAttributes([1]),
      .key(Key(code: .character("a"), modifiers: .capsLock)),
    ].map(TraceEvent.init)

    assertInlineSnapshot(
      of: recorded.map { ($0.type, $0.inputEvent == nil, $0.summary, $0.detail) },
      as: .customDump
    ) {
      """
      [
        [0]: (
          "other",
          true,
          "unknown (not replayable)",
          "unknown"
        ),
        [1]: (
          "other",
          true,
          "terminalReply (not replayable)",
          "terminalReply"
        ),
        [2]: (
          "other",
          true,
          "key a (not replayable)",
          "key a"
        )
      ]
      """
    }
  }

  @Test
  func `a focus change of the terminal is recorded by name and delivers again`() throws {
    let gained = TraceEvent(.focusGained)
    let lost = TraceEvent(.focusLost)

    assertInlineSnapshot(
      of: [gained, lost].map { ($0.type, $0.inputEvent, $0.summary) }, as: .customDump
    ) {
      """
      [
        [0]: (
          "focusGained",
          .focusGained,
          "focus gained"
        ),
        [1]: (
          "focusLost",
          .focusLost,
          "focus lost"
        )
      ]
      """
    }
    // Nothing else rides along, so a record is just the type.
    #expect(JSONText.string(for: gained) == #"{"type":"focusGained"}"#)
    let decoded = try JSONDecoder().decode(
      TraceEvent.self, from: Data(JSONText.string(for: lost).utf8))
    #expect(decoded == lost)
  }

  @Test
  func `a recorded event delivers again as the event it came from`() {
    let events: [InputEvent] = [
      .key(Key(code: .left)),
      .key(Key(code: .character("c"), modifiers: [.control, .alt])),
      .key(Key(code: .function(5))), .key(Key(code: .character("a"), kind: .release)),
      .paste("x y"), .resize(TerminalSize(columns: 7, rows: 3)), .focusGained, .focusLost,
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
    assertInlineSnapshot(of: line, as: .lines) {
      """
      {"cost":{"bodies":0,"bytes":573,"measures":4,"placements":4,"renders":1},"drew":true,"event":{"size":"40x12","type":"resize"},"nodes":{"added":["root","root/index(0)","root/index(0)/body","root/index(0)/body/index(0)"],"changed":[],"removed":[]},"reasons":["renderRequested","updateRequested"],"rows":[0],"seq":0,"version":1}
      """
    }
  }

  @Test
  func `a trace file reads back the records it was written from`() async throws {
    let records = try await records(of: "growing", [key("+"), key("-")])

    let text = TraceFile.text(of: records)

    #expect(text.hasSuffix("}\n"))
    #expect(text.split(separator: "\n").count == records.count)
    expectNoDifference(try TraceFile.records(in: text), records)
    expectNoDifference(try TraceFile.records(in: "\n" + text + "\n\n"), records)
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

    assertInlineSnapshot(of: [notJSON, missing, later], as: .customDump) {
      """
      [
        [0]: TraceFile.ReadError(
          line: 2,
          message: "this line is not a trace record (not valid JSON)"
        ),
        [1]: TraceFile.ReadError(
          line: 2,
          message: "this line is not a trace record (no `seq`)"
        ),
        [2]: TraceFile.ReadError(
          line: 1,
          message: "the record has version 2; this harness reads version 1"
        )
      ]
      """
    }
  }

  @Test
  func `a record of another version is named by its version even when its keys are gone`()
    throws
  {
    // A later schema may rename or drop any key but `version`, so the version is read first.
    let renamed = #expect(throws: TraceFile.ReadError.self) {
      try TraceFile.records(in: #"{"version":2,"steps":[],"verdict":"new"}"# + "\n")
    }
    let older = #expect(throws: TraceFile.ReadError.self) {
      try TraceFile.records(in: #"{"version":0}"# + "\n")
    }
    let noVersion = #expect(throws: TraceFile.ReadError.self) {
      try TraceFile.records(in: #"{"seq":0}"# + "\n")
    }

    assertInlineSnapshot(of: [renamed, older, noVersion], as: .customDump) {
      """
      [
        [0]: TraceFile.ReadError(
          line: 1,
          message: "the record has version 2; this harness reads version 1"
        ),
        [1]: TraceFile.ReadError(
          line: 1,
          message: "the record has version 0; this harness reads version 1"
        ),
        [2]: TraceFile.ReadError(
          line: 1,
          message: "this line is not a trace record (no `version`)"
        )
      ]
      """
    }
  }

  @Test
  func
    `a scenario's trace file mirrors its path under the directory and stays inside it`()
  {
    let scenarios = [
      "Examples/Scenarios/flex-desktop.scn", "/tmp/../etc/x.scn", "./a/./b.scn",
      #"C:\work\s.scn"#,
    ]

    expectNoDifference(
      scenarios.map { TraceFile.path(forScenario: $0, in: "out") },
      [
        "out/Examples/Scenarios/flex-desktop.trace.jsonl", "out/tmp/etc/x.trace.jsonl",
        "out/a/b.trace.jsonl", "out/C_/work/s.trace.jsonl",
      ]
    )
  }
}
