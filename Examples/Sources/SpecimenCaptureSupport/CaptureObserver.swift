import SpecimenSupport
import Tessera
import TesseraTerminalSnapshotSupport
import TesseraTerminalTestSupport
import TesseraTestSupport

/// An immutable observation taken only after presentation and VT ingestion.
package struct CapturedCheckpoint: Equatable, Sendable {
  package let automation: AutomationSnapshot
  package let label: String
  package let screen: ScreenSnapshot
  package let sequence: Int
  package let state: [String: String]
  package let structure: String
  /// Human-readable bytes/events at the input boundary for this completed checkpoint.
  package let inputTrace: [String]
}

/// Tracks ingestion within one session; the VT itself persists across all checkpoints.
package struct CaptureObserver {
  private var byteOffset = 0

  /// Reads a completed presentation without triggering any graph work. Model fields
  /// are explicitly selected synthetic specimen data, never reflected app objects.
  package mutating func observe(
    _ label: String,
    driver: ApplicationDriver,
    memory: InMemoryTerminalSession,
    vt: VirtualTerminal,
    terminal: isolated TerminalSession,
    state: [String: String] = [:],
    inputTrace: [String] = []
  ) async -> CapturedCheckpoint {
    let bytes = await memory.bytes
    vt.feed(Array(bytes.dropFirst(byteOffset)))
    byteOffset = bytes.count
    let modes = terminal.protocolModeReport.effective.map { String(describing: $0) }
      .sorted()
    let trace =
      inputTrace.isEmpty
      ? ["inputTrace=unavailable", "scenario=\(label)"]
      : inputTrace
    let session =
      "session effectiveModes=\(modes) effectiveColor=\(terminal.effectiveColorCapability)"
    return CapturedCheckpoint(
      automation: driver.graph.automationSnapshot,
      label: label,
      screen: vt.snapshot(),
      sequence: driver.frameSequence,
      state: state,
      structure: graphDiagnosticsText(driver.graph.diagnostics) + "\n" + session,
      inputTrace: trace
    )
  }
}
