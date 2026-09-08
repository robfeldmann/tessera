import Foundation
import SpecimenSupport
import Tessera
import TesseraTerminalSnapshotSupport
import TesseraTerminalTestSupport

/// Runs every registered specimen through the parser-backed terminal boundary.
package enum RegisteredCapture {
  package static func run(id: SpecimenID, size: TerminalSize) async throws
    -> [CapturedCheckpoint]
  {
    let memory = InMemoryTerminalSession(size: size)
    let vt = VirtualTerminal.ghostty(cols: size.columns, rows: size.rows)
    return try await memory.withApplicationTerminal(
      configuration: .init(
        modes: [], synchronizedOutput: .disabled, colorCapability: .force(.truecolor)
      )
    ) { terminal in
      let session = SpecimenRegistry.make(id, size: size)
      var observer = CaptureObserver()
      var checkpoints: [CapturedCheckpoint] = []
      var step = "initial"
      do {
        try await session.driver.present(to: terminal)
        checkpoints.append(
          await observer.observe(
            "initial", driver: session.driver, memory: memory, vt: vt, terminal: terminal,
            state: session.state(), inputTrace: ["event=initial"]
          ))

        for scripted in session.input(size) {
          step = scripted.label
          let event = try parse(scripted)
          guard session.driver.step(event) else { break }
          try await session.driver.present(to: terminal)
          checkpoints.append(
            await observer.observe(
              scripted.label, driver: session.driver, memory: memory, vt: vt,
              terminal: terminal,
              state: session.state(),
              inputTrace: [
                "label=\(scripted.label)",
                "bytes=\(hex(scripted.bytes))",
                "event=\(String(describing: event))",
              ]
            ))
        }

        if let pointer = pointerTarget(in: session.driver.graph.automationSnapshot, id: id)
        {
          for (phase, kind) in [
            ("pointer-down", MouseEventKind.press(.left)),
            ("pointer-up", MouseEventKind.release(.left)),
          ] {
            step = phase
            session.driver.step(.mouse(MouseEvent(kind: kind, position: pointer)))
            try await session.driver.present(to: terminal)
            checkpoints.append(
              await observer.observe(
                phase, driver: session.driver, memory: memory, vt: vt, terminal: terminal,
                state: session.state(),
                inputTrace: [
                  "event=mouse", "phase=\(phase)",
                  "position=\(pointer.column),\(pointer.row)",
                ]
              ))
          }
        }

        if id == .panes,
          let hoverPoint = namedPointerTarget(
            in: session.driver.graph.automationSnapshot, identifier: "pane-hover-region"
          )
        {
          let x = hoverPoint.column + 1
          let y = hoverPoint.row + 1
          let hoverInputs = [
            ("hover-enter", Array("\u{1b}[<35;\(x);\(y)M".utf8)),
            ("hover-blur", Array("\u{1b}[O".utf8)),
            ("hover-focus", Array("\u{1b}[I".utf8)),
            ("hover-reenter", Array("\u{1b}[<35;\(x);\(y)M".utf8)),
            ("hover-leave", Array("\u{1b}[<35;1;1M".utf8)),
          ]
          for (label, bytes) in hoverInputs {
            let event = try parse(SpecimenInputStep(label, bytes: bytes))
            step = label
            session.driver.step(event)
            try await session.driver.present(to: terminal)
            checkpoints.append(
              await observer.observe(
                label, driver: session.driver, memory: memory, vt: vt, terminal: terminal,
                state: session.state(),
                inputTrace: [
                  "label=\(label)", "bytes=\(hex(bytes))",
                  "event=\(String(describing: event))",
                  "target=pane-hover-region",
                  "position=\(x),\(y)",
                ]
              ))
          }
        }

        if id == .settings {
          for (label, bytes) in [
            ("selection-home", Array("\u{1b}[H".utf8)),
            ("selection-shift-end", Array("\u{1b}[1;2F".utf8)),
            ("paste-name", Array("\u{1b}[200~Grace\u{1b}[201~".utf8)),
          ] {
            let event = try parse(SpecimenInputStep(label, bytes: bytes))
            step = label
            session.driver.step(event)
            try await session.driver.present(to: terminal)
            checkpoints.append(
              await observer.observe(
                label, driver: session.driver, memory: memory, vt: vt, terminal: terminal,
                state: session.state(),
                inputTrace: [
                  "label=\(label)", "bytes=\(hex(bytes))",
                  "event=\(String(describing: event))",
                ]
              ))
          }
        }

        if id == .viewport {
          let pointer = TerminalPosition(column: 1, row: 1)
          step = "wheel-down"
          session.driver.step(.mouse(MouseEvent(kind: .scroll(.down), position: pointer)))
          try await session.driver.present(to: terminal)
          checkpoints.append(
            await observer.observe(
              "wheel-down", driver: session.driver, memory: memory, vt: vt,
              terminal: terminal,
              state: session.state(),
              inputTrace: [
                "event=mouse", "phase=scroll", "direction=down",
                "position=\(pointer.column),\(pointer.row)",
              ]
            ))
        }

        if id == .panes {
          let start = TerminalPosition(column: 32, row: 1)
          let end = TerminalPosition(column: 40, row: 1)
          for (label, kind, point) in [
            ("divider-down", MouseEventKind.press(.left), start),
            ("divider-drag", MouseEventKind.drag(.left), end),
            ("divider-up", MouseEventKind.release(.left), end),
          ] {
            step = label
            session.driver.step(.mouse(MouseEvent(kind: kind, position: point)))
            try await session.driver.present(to: terminal)
            checkpoints.append(
              await observer.observe(
                label, driver: session.driver, memory: memory, vt: vt, terminal: terminal,
                state: session.state(),
                inputTrace: [
                  "event=mouse", "phase=\(label)",
                  "position=\(point.column),\(point.row)",
                ]
              ))
          }
        }

        if id == .collections {
          let headerRow = size.rows >= 24 ? 18 : 12
          let row = TerminalPosition(column: 2, row: headerRow)
          for (label, kind) in [
            ("table-header-down", MouseEventKind.press(.left)),
            ("table-header-up", MouseEventKind.release(.left)),
          ] {
            step = label
            session.driver.step(.mouse(MouseEvent(kind: kind, position: row)))
            try await session.driver.present(to: terminal)
            checkpoints.append(
              await observer.observe(
                label, driver: session.driver, memory: memory, vt: vt, terminal: terminal,
                state: session.state(),
                inputTrace: [
                  "event=mouse", "phase=\(label)",
                  "position=\(row.column),\(row.row)",
                ]
              ))
          }
          let tableRow = TerminalPosition(column: 2, row: headerRow + 2)
          for (label, kind) in [
            ("table-row-down", MouseEventKind.press(.left)),
            ("table-row-up", MouseEventKind.release(.left)),
          ] {
            step = label
            session.driver.step(.mouse(MouseEvent(kind: kind, position: tableRow)))
            try await session.driver.present(to: terminal)
            checkpoints.append(
              await observer.observe(
                label, driver: session.driver, memory: memory, vt: vt, terminal: terminal,
                state: session.state(),
                inputTrace: [
                  "event=mouse", "phase=\(label)",
                  "position=\(tableRow.column),\(tableRow.row)",
                ]
              ))
          }
        }

        if id == .navigation,
          let point = namedPointerTarget(
            in: session.driver.graph.automationSnapshot,
            identifier: "navigation-show-detail"
          )
        {
          for (label, kind) in [
            ("show-detail-down", MouseEventKind.press(.left)),
            ("show-detail-up", MouseEventKind.release(.left)),
          ] {
            step = label
            session.driver.step(.mouse(MouseEvent(kind: kind, position: point)))
            try await session.driver.present(to: terminal)
            checkpoints.append(
              await observer.observe(
                label, driver: session.driver, memory: memory, vt: vt, terminal: terminal,
                state: session.state(),
                inputTrace: [
                  "event=mouse", "phase=\(label)",
                  "target=navigation-show-detail",
                  "position=\(point.column),\(point.row)",
                ]
              ))
          }
        }

        if id == .navigation {
          let compact = TerminalSize(columns: 22, rows: 10)
          try vt.resize(to: compact)
          await memory.device.resize(to: compact)
          session.driver.step(.resize(compact))
          try await session.driver.present(to: terminal)
          checkpoints.append(
            await observer.observe(
              "compact-threshold", driver: session.driver, memory: memory, vt: vt,
              terminal: terminal,
              state: session.state(),
              inputTrace: [
                "event=resize", "size=22x10", "mode=compact-threshold",
              ]
            ))
          try vt.resize(to: size)
          await memory.device.resize(to: size)
          session.driver.step(.resize(size))
          try await session.driver.present(to: terminal)
          checkpoints.append(
            await observer.observe(
              "compact-restored", driver: session.driver, memory: memory, vt: vt,
              terminal: terminal,
              state: session.state(),
              inputTrace: [
                "event=resize", "size=\(size.columns)x\(size.rows)", "mode=restored",
              ]
            ))
        }

        let alternate =
          size.columns == 80
          ? TerminalSize(columns: 40, rows: 16)
          : TerminalSize(columns: 80, rows: 24)
        for (label, viewport) in [("resized", alternate), ("restored", size)] {
          step = label
          try vt.resize(to: viewport)
          await memory.device.resize(to: viewport)
          session.driver.step(.resize(viewport))
          try await session.driver.present(to: terminal)
          checkpoints.append(
            await observer.observe(
              label, driver: session.driver, memory: memory, vt: vt, terminal: terminal,
              state: session.state(),
              inputTrace: [
                "event=resize", "size=\(viewport.columns)x\(viewport.rows)",
              ]
            ))
        }
        return checkpoints
      } catch {
        throw CaptureFailure(step: step, completed: checkpoints, cause: error)
      }
    }
  }

  private static func parse(_ scripted: SpecimenInputStep) throws -> InputEvent {
    var parser = InputParser()
    let events = parser.feed(contentsOf: scripted.bytes)
    guard events.count == 1, let event = events.first else {
      throw RegisteredCaptureError.invalidInput(label: scripted.label, count: events.count)
    }
    return event
  }

  private static func hex(_ bytes: [UInt8]) -> String {
    bytes.map { String(format: "%02X", $0) }.joined(separator: " ")
  }

  private static func namedPointerTarget(
    in snapshot: AutomationSnapshot, identifier: String
  ) -> TerminalPosition? {
    guard let element = snapshot.elements.first(where: { $0.identifier == identifier }),
      let visible = element.frame.intersection(element.clip), !visible.isEmpty
    else { return nil }
    return visible.origin
  }

  private static func pointerTarget(
    in snapshot: AutomationSnapshot, id: SpecimenID
  ) -> TerminalPosition? {
    let identifier: String? =
      switch id {
      case .settings: "settings-name"
      case .collections: "collection-row-3"
      case .panes: "pane-second"
      case .navigation: "navigation-settings"
      case .records: "record-2"
      default: nil
      }
    if let identifier,
      let element = snapshot.elements.first(where: { $0.identifier == identifier }),
      let visible = element.frame.intersection(element.clip), !visible.isEmpty
    {
      return TerminalPosition(
        column: visible.origin.column + (id == .settings ? 1 : 0),
        row: visible.origin.row + (id == .settings ? 1 : 0)
      )
    }
    return snapshot.elements.lazy.filter { $0.role == .button }.compactMap { element in
      guard let visible = element.frame.intersection(element.clip), !visible.isEmpty else {
        return nil
      }
      return visible.origin
    }.first
  }
}

private enum RegisteredCaptureError: Error, CustomStringConvertible {
  case invalidInput(label: String, count: Int)

  var description: String {
    switch self {
    case .invalidInput(let label, let count):
      "Input step \(label) produced \(count) events; expected exactly one."
    }
  }
}
