import SpecimenSupport
import Tessera
import TesseraTerminalSnapshotSupport
import TesseraTerminalTestSupport

/// Drives the button specimen through parser-backed keyboard and pointer scenarios.
///
/// Each checkpoint is observed only after the same application terminal has flushed its
/// render transaction. The VT and observer therefore retain the real terminal history
/// across every state transition.
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

        // Resolve every declared selector before sending input. Exact lookup is fail
        // closed for duplicates, and pointer targets additionally require visible geometry.
        for identifier in ["add", "toggle", "count"] {
          _ = try checkpoints[0].automation.resolve(identifier)
        }
        _ = try primaryTarget(in: checkpoints[0].automation, identifier: "add")
        _ = try primaryTarget(in: checkpoints[0].automation, identifier: "toggle")

        // These are terminal bytes, not hand-built Key values. CR and Space are legacy
        // press-only activations; bare CSI-u is Kitty press-only and must activate now.
        let keyScript: [(String, [UInt8])] = [
          ("focus-add", [0x09]),
          ("legacy-enter", [0x0D]),
          ("legacy-space", [0x20]),
          ("kitty-press-only", Array("\u{1B}[13u".utf8)),
          ("focus-toggle", [0x09]),
          ("phased-press", Array("\u{1B}[13;1:1u".utf8)),
          ("phased-repeat", Array("\u{1B}[13;1:2u".utf8)),
          ("phased-release", Array("\u{1B}[13;1:3u".utf8)),
        ]
        for (label, bytes) in keyScript {
          step = label
          driver.step(try parsedEvent(label, bytes: bytes))
          try await driver.present(to: terminal)
          checkpoints.append(
            await observer.observe(
              label, driver: driver, memory: memory, vt: vt, terminal: terminal,
              state: model.state
            ))
        }

        // The phased toggle disables Add. Restore it through app-owned specimen state;
        // no capture helper assigns focus or invokes actions.
        model.setAddEnabled(true)
        driver.update()
        step = "restore-enabled"
        try await driver.present(to: terminal)
        checkpoints.append(
          await observer.observe(
            "restore-enabled", driver: driver, memory: memory, vt: vt, terminal: terminal,
            state: model.state
          ))

        // Every pointer coordinate comes from the latest automation metadata. We use the
        // effective clip origin so a stale initial frame cannot target a moved node.
        let pointerTarget = try primaryTarget(
          in: driver.graph.automationSnapshot, identifier: "add")
        step = "pointer-down"
        driver.step(.mouse(MouseEvent(kind: .press(.left), position: pointerTarget.point)))
        try await driver.present(to: terminal)
        checkpoints.append(
          await observer.observe(
            "pointer-down", driver: driver, memory: memory, vt: vt, terminal: terminal,
            state: model.state
          ))

        let currentPointerTarget = try primaryTarget(
          in: driver.graph.automationSnapshot, identifier: "add")
        step = "pointer-up"
        driver.step(
          .mouse(MouseEvent(kind: .release(.left), position: currentPointerTarget.point)))
        try await driver.present(to: terminal)
        checkpoints.append(
          await observer.observe(
            "pointer-up", driver: driver, memory: memory, vt: vt, terminal: terminal,
            state: model.state
          ))
        // Switch only the app-owned built-in style, then capture its pressed projection.
        model.setAddPlainStyle(true)
        driver.update()
        step = "plain-style"
        try await driver.present(to: terminal)
        checkpoints.append(
          await observer.observe(
            "plain-style", driver: driver, memory: memory, vt: vt, terminal: terminal,
            state: model.state
          ))
        let plainTarget = try primaryTarget(
          in: driver.graph.automationSnapshot, identifier: "add")
        step = "plain-pointer-down"
        driver.step(.mouse(MouseEvent(kind: .press(.left), position: plainTarget.point)))
        try await driver.present(to: terminal)
        checkpoints.append(
          await observer.observe(
            "plain-pointer-down", driver: driver, memory: memory, vt: vt,
            terminal: terminal,
            state: model.state
          ))
        let currentPlainTarget = try primaryTarget(
          in: driver.graph.automationSnapshot, identifier: "add")
        step = "plain-pointer-up"
        driver.step(
          .mouse(MouseEvent(kind: .release(.left), position: currentPlainTarget.point)))
        try await driver.present(to: terminal)
        checkpoints.append(
          await observer.observe(
            "plain-pointer-up", driver: driver, memory: memory, vt: vt, terminal: terminal,
            state: model.state
          ))
        model.setAddPlainStyle(false)
        driver.update()
        step = "restore-compact"
        try await driver.present(to: terminal)
        checkpoints.append(
          await observer.observe(
            "restore-compact", driver: driver, memory: memory, vt: vt, terminal: terminal,
            state: model.state
          ))

        // A same-button release outside the captured node cancels without invoking Add.
        let outsideTarget = try primaryTarget(
          in: driver.graph.automationSnapshot, identifier: "add")
        step = "outside-down"
        driver.step(.mouse(MouseEvent(kind: .press(.left), position: outsideTarget.point)))
        try await driver.present(to: terminal)
        checkpoints.append(
          await observer.observe(
            "outside-down", driver: driver, memory: memory, vt: vt, terminal: terminal,
            state: model.state
          ))
        step = "outside-up"
        driver.step(
          .mouse(MouseEvent(kind: .release(.left), position: outsideTarget.outsidePoint)))
        try await driver.present(to: terminal)
        checkpoints.append(
          await observer.observe(
            "outside-up", driver: driver, memory: memory, vt: vt, terminal: terminal,
            state: model.state
          ))

        // Focus loss cancels the held pointer before any matching release arrives.
        let focusLossTarget = try primaryTarget(
          in: driver.graph.automationSnapshot, identifier: "add")
        step = "focus-loss-down"
        driver.step(
          .mouse(MouseEvent(kind: .press(.left), position: focusLossTarget.point)))
        try await driver.present(to: terminal)
        checkpoints.append(
          await observer.observe(
            "focus-loss-down", driver: driver, memory: memory, vt: vt, terminal: terminal,
            state: model.state
          ))
        step = "focus-loss"
        driver.step(.focusLost)
        try await driver.present(to: terminal)
        checkpoints.append(
          await observer.observe(
            "focus-loss", driver: driver, memory: memory, vt: vt, terminal: terminal,
            state: model.state
          ))

        // Disable the app-owned target while it owns pointer capture; reconciliation must
        // clear the ephemeral press without invoking the action.
        let disableTarget = try primaryTarget(
          in: driver.graph.automationSnapshot, identifier: "add")
        step = "disable-down"
        driver.step(.mouse(MouseEvent(kind: .press(.left), position: disableTarget.point)))
        try await driver.present(to: terminal)
        checkpoints.append(
          await observer.observe(
            "disable-down", driver: driver, memory: memory, vt: vt, terminal: terminal,
            state: model.state
          ))
        model.setAddEnabled(false)
        driver.update()
        step = "disable-during-press"
        try await driver.present(to: terminal)
        checkpoints.append(
          await observer.observe(
            "disable-during-press", driver: driver, memory: memory, vt: vt,
            terminal: terminal,
            state: model.state
          ))
        model.setAddEnabled(true)
        driver.update()
        step = "restore-after-disable"
        try await driver.present(to: terminal)
        checkpoints.append(
          await observer.observe(
            "restore-after-disable", driver: driver, memory: memory, vt: vt,
            terminal: terminal,
            state: model.state
          ))

        // Removing the node while it owns pointer capture must also cancel it.
        let removalTarget = try primaryTarget(
          in: driver.graph.automationSnapshot, identifier: "add")
        step = "removal-down"
        driver.step(.mouse(MouseEvent(kind: .press(.left), position: removalTarget.point)))
        try await driver.present(to: terminal)
        checkpoints.append(
          await observer.observe(
            "removal-down", driver: driver, memory: memory, vt: vt, terminal: terminal,
            state: model.state
          ))
        model.setAddPresent(false)
        driver.update()
        step = "removal-during-press"
        try await driver.present(to: terminal)
        checkpoints.append(
          await observer.observe(
            "removal-during-press", driver: driver, memory: memory, vt: vt,
            terminal: terminal,
            state: model.state
          ))
        model.setAddPresent(true)
        model.setAddEnabled(true)
        driver.update()
        step = "restore-after-removal"
        try await driver.present(to: terminal)
        checkpoints.append(
          await observer.observe(
            "restore-after-removal", driver: driver, memory: memory, vt: vt,
            terminal: terminal,
            state: model.state
          ))

        return checkpoints
      } catch {
        throw CaptureFailure(step: step, completed: checkpoints, cause: error)
      }
    }
  }
}

private struct ButtonCaptureTarget {
  let point: TerminalPosition
  let outsidePoint: TerminalPosition
}

private enum ButtonCaptureInputError: Error, CustomStringConvertible {
  case multipleEvents(label: String, count: Int)
  case noEvent(label: String)
  case selectorDisabled(identifier: String)
  case selectorNotButton(identifier: String)
  case selectorNotVisible(identifier: String)

  var description: String {
    switch self {
    case .noEvent(let label):
      return "Input parser produced no event for capture step '\(label)'."
    case .multipleEvents(let label, let count):
      return
        "Input parser produced \(count) events for capture step '\(label)'; expected one."
    case .selectorNotButton(let identifier):
      return "Capture selector '\(identifier)' did not resolve to a button."
    case .selectorDisabled(let identifier):
      return "Capture selector '\(identifier)' resolved to a disabled button."
    case .selectorNotVisible(let identifier):
      return "Capture selector '\(identifier)' has no visible intersection."
    }
  }
}

private func parsedEvent(_ label: String, bytes: [UInt8]) throws -> InputEvent {
  var parser = InputParser()
  let events = parser.feed(contentsOf: bytes)
  guard !events.isEmpty else {
    throw ButtonCaptureInputError.noEvent(label: label)
  }
  guard events.count == 1, let event = events.first else {
    throw ButtonCaptureInputError.multipleEvents(label: label, count: events.count)
  }
  return event
}

private func primaryTarget(
  in snapshot: AutomationSnapshot, identifier: String
) throws -> ButtonCaptureTarget {
  let element = try snapshot.resolve(identifier)
  guard element.role == .button else {
    throw ButtonCaptureInputError.selectorNotButton(identifier: identifier)
  }
  guard element.isEnabled else {
    throw ButtonCaptureInputError.selectorDisabled(identifier: identifier)
  }
  guard let visible = element.frame.intersection(element.clip), !visible.isEmpty else {
    throw ButtonCaptureInputError.selectorNotVisible(identifier: identifier)
  }
  let point = visible.origin
  let outsidePoint: TerminalPosition
  if element.frame.origin.column > 0 {
    outsidePoint = TerminalPosition(
      column: element.frame.origin.column - 1, row: element.frame.origin.row)
  } else {
    outsidePoint = TerminalPosition(
      column: element.frame.origin.column, row: max(0, element.frame.origin.row - 1))
  }
  return ButtonCaptureTarget(point: point, outsidePoint: outsidePoint)
}
