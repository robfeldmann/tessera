import SpecimenSupport
import Tessera
import TesseraTerminalSnapshotSupport
import TesseraTerminalTestSupport

/// Exercises real graph input; no action closure, focus binding, or model value is forced.
package enum ButtonCapture {
  package static func run(size: TerminalSize) async throws -> [CapturedCheckpoint] {
    let memory = InMemoryTerminalSession(size: size)
    let vt = VirtualTerminal.ghostty(cols: size.columns, rows: size.rows)
    return try await memory.withApplicationTerminal(
      configuration: .init(
        modes: [], synchronizedOutput: .disabled, colorCapability: .force(.truecolor)
      )
    ) { terminal in
      let model = ButtonSpecimen()
      let driver = ApplicationDriver(size: size, focusTraversal: true) { model.content }
      var observer = CaptureObserver()
      var checkpoints: [CapturedCheckpoint] = []
      var step = "initial"
      do {
        try await driver.present(to: terminal)
        checkpoints.append(
          await observer.observe(
            "initial", driver: driver, memory: memory, vt: vt, terminal: terminal,
            state: model.state
          ))
        step = "selectors"
        // Fail closed before input if the specimen's explicit selectors are not unique.
        for identifier in ["add", "toggle", "count"] {
          _ = try checkpoints[0].automation.resolve(identifier)
        }
        let script: [(String, Key)] = [
          ("focus-add", Key(code: .tab)),
          ("enter", Key(code: .enter)),
          ("repeat", Key(code: .enter, kind: .repeat)),
          ("release", Key(code: .enter, kind: .release)),
          ("space", Key(code: .character(" "))),
          ("focus-toggle", Key(code: .tab)),
          ("disable", Key(code: .enter)),
          ("skip-disabled", Key(code: .tab)),
          ("enable", Key(code: .enter)),
          ("back-to-add", Key(code: .tab, modifiers: .shift)),
          ("space-restored", Key(code: .character(" "))),
        ]
        for (label, key) in script {
          step = label
          driver.step(.key(key))
          try await driver.present(to: terminal)
          checkpoints.append(
            await observer.observe(
              label, driver: driver, memory: memory, vt: vt, terminal: terminal,
              state: model.state
            ))
        }
        return checkpoints
      } catch {
        throw CaptureFailure(step: step, completed: checkpoints, cause: error)
      }
    }
  }
}
