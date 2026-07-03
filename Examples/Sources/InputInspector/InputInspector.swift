import ExampleSupport
import Foundation
import TesseraTerminal

@main
enum InputInspector {
  static func main() async throws {
    guard TerminalExampleSupport.isRunningInInteractiveTerminal() else {
      TerminalExampleSupport.printTerminalRequiredMessage(
        applicationName: "InputInspector",
        features: [
          "semantic input events",
          "legacy escape-sequence parsing",
          "resize events",
          "keyboard-scrollable event log",
        ],
        runCommand: "swift run --package-path Examples InputInspector",
        attachSchemeName: "InputInspector (Attach)"
      )
      return
    }

    try await TerminalSession.withApplicationTerminal(
      configuration: .default
    ) { terminal in
      var state = InspectorState()
      try await draw(terminal: terminal, state: &state)

      for await event in terminal.events {
        if handle(event, state: &state, terminal: terminal) {
          return
        }
        try await draw(terminal: terminal, state: &state)
      }
    }
  }

  private static func handle(
    _ event: InputEvent,
    state: inout InspectorState,
    terminal: isolated TerminalSession
  ) -> Bool {
    switch event {
    case .key(let key) where key == Key(code: .character("q")):
      return true

    case .key(let key) where key == Key(code: .up, modifiers: .control):
      state.scrollLines(-1)

    case .key(let key) where key == Key(code: .down, modifiers: .control):
      state.scrollLines(1)

    case .key(let key) where key == Key(code: .pageUp):
      state.scrollPages(-1)

    case .key(let key) where key == Key(code: .pageDown):
      state.scrollPages(1)

    case .key(let key) where key == Key(code: .home):
      state.scrollToOldest()

    case .key(let key) where key == Key(code: .end):
      state.followLatest()

    case .key(let key) where key == Key(code: .up):
      state.append(event)
      state.marker.row = max(0, state.marker.row - 1)
      state.followLatest()

    case .key(let key) where key == Key(code: .down):
      state.append(event)
      state.marker.row = min(state.gridRows - 1, state.marker.row + 1)
      state.followLatest()

    case .key(let key) where key == Key(code: .left):
      state.append(event)
      state.marker.column = max(0, state.marker.column - 1)
      state.followLatest()

    case .key(let key) where key == Key(code: .right):
      state.append(event)
      state.marker.column = min(state.gridColumns - 1, state.marker.column + 1)
      state.followLatest()

    case .resize:
      state.append(event)
      terminal.invalidateRenderer()
      state.followLatest()

    case .key, .paste, .unknown:
      state.append(event)
      state.followLatest()
    }

    return false
  }

  private static func draw(
    terminal: isolated TerminalSession,
    state: inout InspectorState
  ) async throws {
    try await terminal.draw { frame in
      drawHeader(frame: frame, state: state)
      drawLastEvent(frame: frame, state: state)
      drawGrid(frame: frame, state: state)
      drawLog(frame: frame, state: &state)
    }
  }

  private static func drawHeader(frame: borrowing Frame, state: InspectorState) {
    frame.write(
      "InputInspector — press q to quit",
      at: position(0, 0),
      style: Style(foreground: .ansi(.brightCyan), attributes: [.bold])
    )
    frame.write(
      "Terminal: \(frame.size.columns)x\(frame.size.rows) · log: \(state.log.count) events",
      at: position(0, 1),
      style: Style(attributes: [.dim])
    )
    frame.write(
      "Arrows move @ · PageUp/PageDown scroll log",
      at: position(0, 2),
      style: Style(attributes: [.dim])
    )
    frame.write(
      "Ctrl+Up/Down line scroll · Home/End jump",
      at: position(0, 3),
      style: Style(attributes: [.dim])
    )
    frame.write(
      "Bracketed paste logs as one grouped paste event.",
      at: position(0, 4),
      style: Style(attributes: [.dim])
    )
  }

  private static func drawLastEvent(frame: borrowing Frame, state: InspectorState) {
    let description = state.log.last ?? "none"
    frame.write("Last event:", at: position(0, 5), style: Style(attributes: [.bold]))
    frame.write(description, at: position(2, 6), style: Style(foreground: .ansi(.yellow)))
  }

  private static func drawGrid(frame: borrowing Frame, state: InspectorState) {
    let origin = TerminalPosition(column: 0, row: 8)
    frame.write("Grid:", at: origin, style: Style(attributes: [.bold]))

    for row in 0..<state.gridRows {
      var line = ""
      for column in 0..<state.gridColumns {
        line += state.marker == GridPosition(column: column, row: row) ? "@ " : "· "
      }
      frame.write(line, at: position(2, origin.row + row + 1))
    }
  }

  private static func drawLog(frame: borrowing Frame, state: inout InspectorState) {
    let top = 8
    let left = 18
    let height = max(frame.size.rows - top - 1, 1)
    state.setVisibleLogCount(height)
    let start = state.visibleLogStart(visibleCount: height)
    let end = min(state.log.count, start + height)

    frame.write(
      "Event log:",
      at: position(left, top - 1),
      style: Style(attributes: [.bold])
    )

    if start < end {
      for (offset, line) in state.log[start..<end].enumerated() {
        frame.write(line, at: position(left, top + offset))
      }
    } else {
      frame.write(
        "no events yet",
        at: position(left, top),
        style: Style(attributes: [.dim])
      )
    }
  }

  private static func position(_ column: Int, _ row: Int) -> TerminalPosition {
    TerminalPosition(column: column, row: row)
  }
}

private struct InspectorState {
  var log: [String] = []
  var marker = GridPosition(column: 2, row: 1)
  var scrollOffsetFromLatest = 0
  var visibleLogCount = 1

  let gridColumns = 5
  let gridRows = 3

  private var maximumScrollOffset: Int {
    max(log.count - visibleLogCount, 0)
  }

  mutating func append(_ event: InputEvent) {
    log.append(describe(event))
    if log.count > 1_000 {
      log.removeFirst(log.count - 1_000)
    }
    clampScrollOffset()
  }

  mutating func followLatest() {
    scrollOffsetFromLatest = 0
  }

  mutating func scrollLines(_ delta: Int) {
    scrollOffsetFromLatest -= delta
    clampScrollOffset()
  }

  mutating func scrollPages(_ delta: Int) {
    scrollLines(delta * 10)
  }

  mutating func scrollToOldest() {
    scrollOffsetFromLatest = maximumScrollOffset
  }

  mutating func setVisibleLogCount(_ count: Int) {
    visibleLogCount = max(count, 1)
    clampScrollOffset()
  }

  func visibleLogStart(visibleCount: Int) -> Int {
    max(0, log.count - visibleCount - scrollOffsetFromLatest)
  }

  private mutating func clampScrollOffset() {
    scrollOffsetFromLatest = max(0, min(maximumScrollOffset, scrollOffsetFromLatest))
  }
}

private struct GridPosition: Equatable {
  var column: Int
  var row: Int
}

private func describe(_ event: InputEvent) -> String {
  switch event {
  case .key(let key):
    return "key code=\(key.code) modifiers=\(describe(key.modifiers))"
  case .paste(let text):
    return "paste chars=\(text.count) lines=\(lineCount(text))"
  case .resize(let size):
    return "resize \(size.columns)x\(size.rows)"
  case .unknown(let bytes):
    return "unknown bytes=\(hex(bytes))"
  }
}

private func describe(_ modifiers: Modifiers) -> String {
  var parts: [String] = []
  if modifiers.contains(.shift) { parts.append("shift") }
  if modifiers.contains(.alt) { parts.append("alt") }
  if modifiers.contains(.control) { parts.append("ctrl") }
  return parts.isEmpty ? "none" : parts.joined(separator: "+")
}

private func lineCount(_ text: String) -> Int {
  text.split(separator: "\n", omittingEmptySubsequences: false).count
}

private func hex(_ bytes: [UInt8]) -> String {
  bytes.map { String(format: "%02X", $0) }.joined(separator: " ")
}
