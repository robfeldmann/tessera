import SpecimenSupport
import Tessera
import TesseraTerminalSnapshotSupport
import TesseraTerminalTestSupport

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
      var observer = CaptureObserver()
      var checkpoints: [CapturedCheckpoint] = []
      try await driver.present(to: terminal)
      checkpoints.append(
        await observer.observe(
          "initial", driver: driver, memory: memory, vt: vt, terminal: terminal))
      model.message = "Changed."
      driver.update()
      try await driver.present(to: terminal)
      checkpoints.append(
        await observer.observe(
          "changed", driver: driver, memory: memory, vt: vt, terminal: terminal))
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
          await observer.observe(
            label, driver: driver, memory: memory, vt: vt, terminal: terminal))
      }
      return checkpoints
    }
  }
}
