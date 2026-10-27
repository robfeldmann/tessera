import Foundation
import TesseraCore
import TesseraTerminalCore
import TesseraTerminalInput

/// What one step cost: the work the library did to take one event to one frame.
///
/// The counts are deterministic, so a scenario can bound them with `expect cost`. They are the
/// library's work and not a promise: a change that makes the library do less work lowers
/// them, so bound them with `<=` and never assert an exact number.
package struct StepCost: Codable, Equatable, Sendable {
  /// The counters `expect cost` accepts, in the order the grammar lists them.
  package static let names = ["bodies", "bytes", "measures", "placements", "renders"]

  /// View bodies evaluated while updating the graph.
  package var bodies: Int

  /// Bytes the frame wrote to the terminal; 0 when nothing was drawn.
  package var bytes: Int

  /// Measurements the layout pass took.
  package var measures: Int

  /// Placements the layout pass made.
  package var placements: Int

  /// Leaf nodes the render pass painted.
  package var renders: Int

  /// `bodies=3 bytes=10 …`, every counter, for the message that shows what a bound met.
  package var text: String {
    Self.names.map { "\($0)=\(count(named: $0) ?? 0)" }.joined(separator: " ")
  }

  /// The value of the counter `name`, or `nil` when no counter has that name.
  package func count(named name: String) -> Int? {
    switch name {
    case "bodies": bodies
    case "bytes": bytes
    case "measures": measures
    case "placements": placements
    case "renders": renders
    default: nil
    }
  }
}

/// The event a step delivered, in the words the scenario grammar uses.
///
/// A key, a paste, and a resize are the grammar's own words. A focus change of the terminal
/// window has no scenario statement, but a live session receives it, so it is recorded as
/// `focusGained` or `focusLost` and replays like the others. An event neither the grammar nor
/// replay can deliver (a mouse event, a terminal reply) is
/// recorded as `other`, so the trace stays complete and `replay` can refuse it by name.
package struct TraceEvent: Codable, Equatable, Sendable {
  /// `key`, `paste`, `resize`, `focusGained`, `focusLost`, or `other`.
  package var type: String

  /// For a key, its name as a `key` statement spells it.
  package var key: String?

  /// For a key that was not a plain press, `repeat` or `release`.
  package var kind: String?

  /// For a paste, the pasted text.
  package var text: String?

  /// For a resize, the new size as `WxH`.
  package var size: String?

  /// For `other`, what the event was.
  package var detail: String?

  /// The event to deliver again, or `nil` for `other` and for a record that does not parse.
  package var inputEvent: InputEvent? {
    switch type {
    case "key":
      guard let key, let parsed = try? KeyName.parse(key) else {
        return nil
      }
      var event = parsed
      switch kind {
      case "repeat": event.kind = .repeat
      case "release": event.kind = .release
      default: break
      }
      return .key(event)
    case "paste":
      return text.map(InputEvent.paste)
    case "resize":
      return size.flatMap { ScenarioParser.parseDimensions($0) }.map {
        .resize(TerminalSize(columns: $0.0, rows: $0.1))
      }
    case "focusGained":
      return .focusGained
    case "focusLost":
      return .focusLost
    default:
      return nil
    }
  }

  /// The event as a statement reads, for a failure that names the step.
  package var summary: String {
    switch type {
    case "key": "key \(key ?? "?")\(kind.map { " (\($0))" } ?? "")"
    case "paste": "paste \(text.map { "\"\($0)\"" } ?? "")"
    case "resize": "resize \(size ?? "?")"
    case "focusGained": "focus gained"
    case "focusLost": "focus lost"
    default: "\(detail ?? "other") (not replayable)"
    }
  }

  package init(_ event: InputEvent) {
    type = "other"
    switch event {
    case .key(let key):
      if let name = KeyName.name(of: key) {
        type = "key"
        self.key = name
        switch key.kind {
        case .press: break
        case .repeat: kind = "repeat"
        case .release: kind = "release"
        }
      } else {
        detail = "key \(KeyName.describe(key))"
      }
    case .paste(let text):
      type = "paste"
      self.text = text
    case .resize(let size):
      type = "resize"
      self.size = "\(size.columns)x\(size.rows)"
    case .focusGained:
      type = "focusGained"
    case .focusLost:
      type = "focusLost"
    case .mouse:
      detail = "mouse"
    case .colorReport, .colorSchemeChanged, .kittyGraphicsResponse,
      .kittyKeyboardEnhancementFlags, .primaryDeviceAttributes, .privateModeStatus:
      detail = "terminalReply"
    case .unknown:
      detail = "unknown"
    }
  }
}

/// One step of a run, as the trace records it: the event, why the frame was drawn, what it
/// changed, and what it cost.
///
/// A record is one line of the trace file, a sorted-key JSON object. "Why did this redraw?" is
/// read from `reasons`: the library's invalidation reasons for the pass, which are value-free
/// and bounded. The record carries a `version` and is not part of the 1.0 promise.
package struct TraceRecord: Codable, Equatable, Sendable {
  /// The nodes a step changed, by identity path.
  package struct NodeChanges: Codable, Equatable, Sendable {
    /// Nodes that did not exist before the step.
    package var added: [String]

    /// Nodes that existed and whose type, geometry, or requirements differ.
    package var changed: [String]

    /// Nodes the step removed.
    package var removed: [String]
  }

  /// The schema version the record carries.
  package static let currentVersion = 1

  package var version: Int

  /// The step's number: 0 is the first frame, and every event adds one.
  package var seq: Int

  /// The event the step delivered.
  package var event: TraceEvent

  /// Whether the step drew a frame; a step that leaves the graph clean draws none.
  package var drew: Bool

  /// The invalidation reasons of the pass, in the library's fixed order.
  package var reasons: [String]

  /// The nodes the step changed.
  package var nodes: NodeChanges

  /// The rows of the screen whose text changed, counted from 0.
  package var rows: [Int]

  /// The work the step took.
  package var cost: StepCost

  /// The line of a trace file: compact sorted-key JSON with no trailing newline.
  package var line: String {
    JSONText.string(for: self)
  }

  package init(
    seq: Int, event: TraceEvent, drew: Bool, reasons: [String], nodes: NodeChanges,
    rows: [Int], cost: StepCost
  ) {
    version = Self.currentVersion
    self.seq = seq
    self.event = event
    self.drew = drew
    self.reasons = reasons
    self.nodes = nodes
    self.rows = rows
    self.cost = cost
  }
}

extension TraceRecord.NodeChanges {
  /// The difference between two node lists, by identity: what appeared, what disappeared, and
  /// what kept its identity and changed what it is or where it sits.
  init(from before: [NodeDiagnostics], to after: [NodeDiagnostics]) {
    let old = Dictionary(
      before.map { ($0.identity.description, $0) }
    ) { first, _ in first }
    var seen: Set<String> = []
    var added: [String] = []
    var changed: [String] = []
    for node in after {
      let path = node.identity.description
      seen.insert(path)
      guard let previous = old[path] else {
        added.append(path)
        continue
      }
      if previous.viewType != node.viewType || previous.frame != node.frame
        || previous.clip != node.clip || previous.measuredSize != node.measuredSize
        || previous.proposal != node.proposal
        || previous.environmentOverrides != node.environmentOverrides
        || previous.handlerKinds != node.handlerKinds
        || previous.requestedTerminalRequirements != node.requestedTerminalRequirements
      {
        changed.append(path)
      }
    }
    self.init(
      added: added, changed: changed,
      removed: before.map(\.identity.description).filter { !seen.contains($0) })
  }
}

extension TraceRecord {
  /// The record for one step, from what the driver saw before and after it.
  init(
    seq: Int,
    event: InputEvent,
    drew: Bool,
    statistics: GraphStatistics,
    bytes: Int,
    nodes: TraceRecord.NodeChanges,
    rowsBefore: [String],
    rowsAfter: [String]
  ) {
    let count = max(rowsBefore.count, rowsAfter.count)
    // A row that does not exist reads as an empty one, so the rows a first frame leaves blank
    // are not changes.
    let changed = (0..<count).filter { row in
      (row < rowsBefore.count ? rowsBefore[row] : "")
        != (row < rowsAfter.count ? rowsAfter[row] : "")
    }
    self.init(
      seq: seq,
      event: TraceEvent(event),
      drew: drew,
      reasons: statistics.invalidationReasons.values.map(\.rawValue),
      nodes: nodes,
      rows: changed,
      cost: StepCost(
        bodies: statistics.bodyEvaluations, bytes: bytes,
        measures: statistics.measurements,
        placements: statistics.placements, renders: statistics.renderedNodes))
  }
}
