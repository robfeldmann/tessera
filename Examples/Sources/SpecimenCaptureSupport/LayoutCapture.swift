import SpecimenSupport
import Tessera
import TesseraTerminalSnapshotSupport
import TesseraTerminalTestSupport
import TesseraTestSupport

/// An immutable observation taken only after session presentation and VT ingestion.
package struct CapturedCheckpoint: Equatable, Sendable {
  package let label: String
  package let screen: ScreenSnapshot
  package let sequence: Int
  package let structure: String
}

/// Synthetic, deterministic scenarios through the same driver used by the live host.
package enum LayoutCapture {
  package static func run(size: TerminalSize) async throws -> [CapturedCheckpoint] {
    let memory = InMemoryTerminalSession(size: size)
    let vt = VirtualTerminal.ghostty(cols: size.columns, rows: size.rows)
    return try await memory.withApplicationTerminal(
      configuration: .init(
        modes: [], synchronizedOutput: .disabled, colorCapability: .force(.truecolor)
      )
    ) { terminal in
      let model = LayoutSpecimen()
      let driver = ApplicationDriver(size: size) { model.content }
      var offset = 0
      var checkpoints: [CapturedCheckpoint] = []
      try await driver.present(to: terminal)
      checkpoints.append(
        await observe("initial", driver: driver, memory: memory, vt: vt, offset: &offset))
      model.message = "Changed."
      driver.update()
      try await driver.present(to: terminal)
      checkpoints.append(
        await observe("changed", driver: driver, memory: memory, vt: vt, offset: &offset))
      let alternate =
        size.columns == 80
        ? TerminalSize(columns: 40, rows: 16)
        : TerminalSize(columns: 80, rows: 24)
      for (label, viewport) in [("resized", alternate), ("restored", size)] {
        try vt.resize(to: viewport)
        await memory.device.resize(to: viewport)
        driver.step(.resize(viewport))
        try await driver.present(to: terminal)
        checkpoints.append(
          await observe(label, driver: driver, memory: memory, vt: vt, offset: &offset))
      }
      return checkpoints
    }
  }

  /// Ingests only newly flushed bytes. It never updates, lays out, or renders the graph.
  private static func observe(
    _ label: String,
    driver: ApplicationDriver,
    memory: InMemoryTerminalSession,
    vt: VirtualTerminal,
    offset: inout Int
  ) async -> CapturedCheckpoint {
    let bytes = await memory.bytes
    vt.feed(Array(bytes.dropFirst(offset)))
    offset = bytes.count
    return CapturedCheckpoint(
      label: label,
      screen: vt.snapshot(),
      sequence: driver.frameSequence,
      structure: graphDiagnosticsText(driver.graph.diagnostics)
    )
  }
}
