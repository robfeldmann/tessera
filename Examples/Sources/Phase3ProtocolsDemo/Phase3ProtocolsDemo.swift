import ExampleSupport
import Foundation
import TesseraTerminal

@main
enum Phase3ProtocolsDemo {
  static func main() async throws {
    guard TerminalExampleSupport.isRunningInInteractiveTerminal() else {
      TerminalExampleSupport.printTerminalRequiredMessage(
        applicationName: "Phase3ProtocolsDemo",
        features: [
          "bracketed paste mode",
          "semantic paste events",
          "terminal focus events",
          "raw keyboard input",
          "alternate screen rendering",
        ],
        runCommand: "swift run --package-path Examples Phase3ProtocolsDemo",
        attachSchemeName: "Phase3ProtocolsDemo (Attach)"
      )
      return
    }

    try await TerminalSession.withApplicationTerminal(
      configuration: .default
    ) { terminal in
      var state = DemoState()
      try await draw(terminal: terminal, state: state)

      for await event in terminal.events {
        if handle(event, state: &state, terminal: terminal) {
          return
        }
        try await draw(terminal: terminal, state: state)
      }
    }
  }

  private static func handle(
    _ event: InputEvent,
    state: inout DemoState,
    terminal: isolated TerminalSession
  ) -> Bool {
    switch event {
    case .key(let key) where key == Key(code: .character("q")):
      return true

    case .key(let key):
      state.append(event)
      state.lastKeyDescription = describe(key)
      if key == Key(code: .character("1")) {
        state.selectedPanel = .paste
      } else if key == Key(code: .character("2")) {
        state.selectedPanel = .focus
      }
    case .paste(let text):
      state.append(event)
      state.lastPaste = text

    case .focusGained:
      state.append(event)
      state.focusState = .focused
      state.lastFocusTransition = "focus gained at event \(state.formattedSequenceNumber)"

    case .focusLost:
      state.append(event)
      state.focusState = .unfocused
      state.lastFocusTransition = "focus lost at event \(state.formattedSequenceNumber)"

    case .resize:
      state.append(event)
      terminal.invalidateRenderer()

    case .unknown:
      state.append(event)
    }

    return false
  }

  private static func draw(
    terminal: isolated TerminalSession,
    state: DemoState
  ) async throws {
    try await terminal.draw { frame in
      drawHeader(frame: frame, state: state)
      guard frame.size.columns >= 12, frame.size.rows >= 20 else {
        drawSmallTerminalMessage(frame: frame)
        return
      }

      switch state.selectedPanel {
      case .paste:
        drawLastEvent(frame: frame, state: state)
        drawPastePreview(frame: frame, state: state)
        drawKeySummary(frame: frame, state: state)
        drawRecentEvents(frame: frame, state: state, top: 19)

      case .focus:
        drawFocusPanel(frame: frame, state: state)
      }
    }
  }

  private static func drawHeader(frame: borrowing Frame, state: DemoState) {
    frame.write(
      "Phase3ProtocolsDemo — \(state.selectedPanel.title)",
      at: position(0, 0),
      style: Style(foreground: .ansi(.brightCyan), attributes: [.bold])
    )
    frame.write(
      "q quit · 1 paste · 2 focus",
      at: position(0, 1),
      style: Style(attributes: [.dim])
    )
    frame.write(
      "Terminal: \(frame.size.columns)x\(frame.size.rows)",
      at: position(0, 2),
      style: Style(attributes: [.dim])
    )
  }

  private static func drawSmallTerminalMessage(frame: borrowing Frame) {
    guard frame.size.rows > 4, frame.size.columns > 0 else {
      return
    }

    let lines = wrappedLines(
      "Resize to at least 12x20 for the protocol demo.",
      width: frame.size.columns
    )
    let availableRows = frame.size.rows - 4

    for (offset, line) in lines.prefix(availableRows).enumerated() {
      frame.write(
        line,
        at: position(0, 4 + offset),
        style: Style(foreground: .ansi(.yellow), attributes: [.bold])
      )
    }
  }

  private static func wrappedLines(_ message: String, width: Int) -> [String] {
    guard width > 0 else {
      return []
    }

    var lines: [String] = []
    var currentLine = ""

    for word in message.split(separator: " ") {
      let word = String(word)
      if currentLine.isEmpty {
        currentLine = String(word.prefix(width))
      } else if currentLine.count + 1 + word.count <= width {
        currentLine += " \(word)"
      } else {
        lines.append(currentLine)
        currentLine = String(word.prefix(width))
      }
    }

    if !currentLine.isEmpty {
      lines.append(currentLine)
    }

    return lines
  }

  private static func drawLastEvent(frame: borrowing Frame, state: DemoState) {
    frame.write("Last event", at: position(0, 4), style: Style(attributes: [.bold]))
    frame.write(state.lastEventDescription, at: position(2, 5))
  }

  private static func drawPastePreview(frame: borrowing Frame, state: DemoState) {
    let top = 7
    frame.write(
      "Paste payload preview",
      at: position(0, top),
      style: Style(attributes: [.bold])
    )

    let width = min(frame.size.columns - 2, 72)
    let horizontal = String(repeating: "─", count: width)
    frame.write("┌\(horizontal)┐", at: position(0, top + 1))

    let previewLines = state.pastePreviewLines(limit: 5, width: width)
    for row in 0..<5 {
      let line = row < previewLines.count ? previewLines[row] : ""
      let paddedLine = line.padding(toLength: width, withPad: " ", startingAt: 0)
      frame.write("│\(paddedLine)│", at: position(0, top + 2 + row))
    }

    frame.write("└\(horizontal)┘", at: position(0, top + 7))
  }

  private static func drawKeySummary(frame: borrowing Frame, state: DemoState) {
    frame.write("Typed keys", at: position(0, 16), style: Style(attributes: [.bold]))
    frame.write(state.lastKeyDescription, at: position(2, 17))
  }

  private static func drawRecentEvents(
    frame: borrowing Frame,
    state: DemoState,
    top: Int
  ) {
    frame.write("Recent events", at: position(0, top), style: Style(attributes: [.bold]))

    if state.recentEvents.isEmpty {
      frame.write(
        "no events yet",
        at: position(2, top + 1),
        style: Style(attributes: [.dim])
      )
      return
    }

    let availableRows = max(frame.size.rows - top - 1, 0)
    for (offset, event) in state.recentEvents.suffix(availableRows).enumerated() {
      frame.write(event, at: position(2, top + 1 + offset))
    }
  }

  private static func drawFocusPanel(frame: borrowing Frame, state: DemoState) {
    drawLastEvent(frame: frame, state: state)

    frame.write("Terminal focus", at: position(0, 7), style: Style(attributes: [.bold]))
    frame.write("state: \(state.focusState.description)", at: position(2, 8))
    frame.write("last transition: \(state.lastFocusTransition)", at: position(2, 9))

    frame.write("Try it", at: position(0, 12), style: Style(attributes: [.bold]))
    frame.write(
      "Switch to another terminal tab/window, then return here.",
      at: position(2, 13)
    )
    frame.write(
      "Some terminals only report focus while the alternate screen is active.",
      at: position(2, 14),
      style: Style(attributes: [.dim])
    )

    drawRecentEvents(frame: frame, state: state, top: 17)
  }

  private static func position(_ column: Int, _ row: Int) -> TerminalPosition {
    TerminalPosition(column: column, row: row)
  }
}

private enum DemoPanel {
  case focus
  case paste

  var title: String {
    switch self {
    case .focus:
      return "Focus"
    case .paste:
      return "Paste"
    }
  }
}

private enum DemoFocusState {
  case focused
  case unfocused
  case unknown

  var description: String {
    switch self {
    case .focused:
      return "focused"
    case .unfocused:
      return "unfocused"
    case .unknown:
      return "unknown"
    }
  }
}

private struct DemoState {
  private(set) var recentEvents: [String] = []
  var selectedPanel = DemoPanel.paste
  var focusState = DemoFocusState.unknown
  var lastFocusTransition = "none"
  var lastKeyDescription = "none"
  var lastPaste = ""
  var sequenceNumber = 0

  var lastEventDescription: String {
    recentEvents.last ?? "none"
  }

  var formattedSequenceNumber: String {
    String(format: "%04d", sequenceNumber)
  }

  mutating func append(_ event: InputEvent) {
    sequenceNumber += 1
    recentEvents.append("\(formattedSequenceNumber) \(describe(event))")
    if recentEvents.count > 25 {
      recentEvents.removeFirst(recentEvents.count - 25)
    }
  }

  func pastePreviewLines(limit: Int, width: Int) -> [String] {
    guard !lastPaste.isEmpty else {
      return ["paste text to see one semantic event"]
    }

    let lines =
      lastPaste
      .split(separator: "\n", omittingEmptySubsequences: false)
      .prefix(limit)

    return lines.map { line in
      let string = String(line)
      if string.count <= width {
        return string
      }
      return String(string.prefix(max(width - 1, 0))) + "…"
    }
  }
}

private func describe(_ event: InputEvent) -> String {
  switch event {
  case .focusGained:
    return "focus gained"
  case .focusLost:
    return "focus lost"
  case .key(let key):
    return "key \(describe(key))"
  case .paste(let text):
    return "paste chars=\(text.count) lines=\(lineCount(text))"
  case .resize(let size):
    return "resize \(size.columns)x\(size.rows)"
  case .unknown(let bytes):
    return "unknown bytes=\(hex(bytes))"
  }
}

private func describe(_ key: Key) -> String {
  "code=\(key.code) modifiers=\(describe(key.modifiers))"
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
