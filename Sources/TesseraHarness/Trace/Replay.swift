import Foundation
import TesseraTerminalCore

/// Reruns a recorded trace as a scenario.
///
/// The trace names the events, so replaying it is delivering them again, in order, to a fresh
/// application at the size the recording started at. After every step the replay compares its
/// own record with the recorded one on what the recording promises to hold on any terminal: why
/// the frame was drawn, which nodes and rows changed, and what the step cost. The bytes a frame
/// wrote are left out, because they depend on the terminal the recording ran on. A step that
/// differs is a `replay` failure, and the run goes on to report the rest.
///
/// A trace that holds an event the grammar cannot say (a mouse event before pointer input
/// exists) cannot be replayed: it is refused before anything runs, naming the step.
@MainActor
enum Replayer {
  /// What a replay collected.
  private final class Outcome {
    var failures: [ScenarioFailure] = []
    var observations: [ScenarioObservation] = []
    var steps: [TraceRecord] = []
  }

  /// Replays the trace in `text`, read from `file`, against the application `name`.
  static func replay(
    text: String, file: String, app name: String, registry: ApplicationRegistry
  ) async -> ScenarioReport {
    let recorded: [TraceRecord]
    do {
      recorded = try TraceFile.records(in: text)
    } catch let error as TraceFile.ReadError {
      return ScenarioReport(
        scenario: file,
        failures: [
          ScenarioFailure(
            line: error.line, statement: "", verb: "usage", message: error.message)
        ])
    } catch {
      return .failure(scenario: file, verb: "usage", message: "\(error)")
    }
    if let refusal = refusal(recorded) {
      return ScenarioReport(scenario: file, failures: [refusal])
    }

    let entry: ApplicationRegistry.Entry
    do {
      entry = try registry.entry(named: name)
    } catch {
      return .failure(scenario: file, verb: "harness", message: error.description)
    }
    guard let start = recorded.first?.event.inputEvent, case .resize(let size) = start
    else {
      return .failure(scenario: file, verb: "usage", message: "the trace holds no steps")
    }

    let outcome = Outcome()
    do {
      try await entry.headless(.custom(size), TerminalProfile()) { host in
        await play(recorded, on: host, into: outcome)
      }
    } catch let error as HostError {
      return .failure(scenario: file, verb: error.verb, message: error.message)
    } catch {
      return .failure(scenario: file, verb: "harness", message: "\(error)")
    }
    return ScenarioReport(
      scenario: file, failures: outcome.failures, observations: outcome.observations,
      trace: outcome.steps)
  }

  /// Delivers each recorded event to `host` and compares the step it took with the recording.
  private static func play(
    _ recorded: [TraceRecord], on host: any ScenarioHost, into outcome: Outcome
  ) async {
    defer {
      outcome.steps = host.records
    }
    func compare(_ replayed: TraceRecord?, with expected: TraceRecord) {
      guard let replayed,
        let difference = difference(expected: expected, replayed: replayed)
      else {
        return
      }
      outcome.failures.append(
        ScenarioFailure(
          line: expected.seq + 1,
          statement: "step \(expected.seq): \(expected.event.summary)",
          verb: "replay",
          message: difference.message,
          expected: difference.expected, actual: difference.actual,
          screen: host.screenRows.dropTrailingEmptyRows()))
    }

    compare(host.lastRecord, with: recorded[0])
    for expected in recorded.dropFirst() {
      if host.isFinished {
        outcome.failures.append(
          ScenarioFailure(
            line: expected.seq + 1,
            statement: "step \(expected.seq): \(expected.event.summary)",
            verb: "replay",
            message:
              "the application finished before step \(expected.seq), where the recording "
              + "kept going"))
        return
      }
      guard let event = expected.event.inputEvent else {
        return
      }
      do {
        try await host.send(event)
      } catch {
        outcome.failures.append(
          ScenarioFailure(
            line: expected.seq + 1, statement: "step \(expected.seq)", verb: "harness",
            message: "the host could not deliver the event: \(error)"))
        return
      }
      compare(host.lastRecord, with: expected)
    }
    outcome.observations.append(
      ScenarioObservation(
        line: 0, verb: "replay", name: nil,
        lines: host.screenRows.dropTrailingEmptyRows()))
  }

  /// The failure for a trace that cannot be replayed, or `nil` when every step can.
  private static func refusal(_ records: [TraceRecord]) -> ScenarioFailure? {
    guard let first = records.first else {
      return ScenarioFailure(
        line: 0, statement: "", verb: "usage", message: "the trace holds no steps")
    }
    guard first.seq == 0, case .resize? = first.event.inputEvent else {
      return ScenarioFailure(
        line: 1, statement: "", verb: "usage",
        message:
          "the first record must be step 0, the resize that tells the application its "
          + "starting size; it is step \(first.seq), \(first.event.summary)")
    }
    for (offset, record) in records.enumerated() {
      if record.seq != offset {
        return ScenarioFailure(
          line: offset + 1, statement: "", verb: "usage",
          message: "the steps are numbered 0, 1, 2, …; this one is \(record.seq)")
      }
      if record.event.inputEvent == nil {
        return ScenarioFailure(
          line: offset + 1, statement: "step \(record.seq)", verb: "usage",
          message:
            "step \(record.seq) holds an event replay cannot deliver: "
            + "\(record.event.summary); replay delivers keys, pastes, resizes, and focus changes"
        )
      }
    }
    return nil
  }

  /// The first way a replayed step differs from the recorded one, with both values.
  private static func difference(expected: TraceRecord, replayed: TraceRecord)
    -> (message: String, expected: String, actual: String)?
  {
    if expected.drew != replayed.drew {
      return (
        "the recording \(expected.drew ? "drew a frame" : "drew none") and the replay "
          + "\(replayed.drew ? "drew a frame" : "drew none")",
        "drew \(expected.drew)", "drew \(replayed.drew)"
      )
    }
    if expected.reasons != replayed.reasons {
      return (
        "the reasons differ from the recording", expected.reasons.joined(separator: ", "),
        replayed.reasons.joined(separator: ", ")
      )
    }
    if expected.nodes != replayed.nodes {
      return (
        "the changed nodes differ from the recording",
        JSONText.string(for: expected.nodes),
        JSONText.string(for: replayed.nodes)
      )
    }
    if expected.rows != replayed.rows {
      return (
        "the changed rows differ from the recording", "\(expected.rows)",
        "\(replayed.rows)"
      )
    }
    var recordedCost = expected.cost
    var replayedCost = replayed.cost
    recordedCost.bytes = 0
    replayedCost.bytes = 0
    if recordedCost != replayedCost {
      return (
        "the costs differ from the recording", expected.cost.text, replayed.cost.text
      )
    }
    return nil
  }
}
