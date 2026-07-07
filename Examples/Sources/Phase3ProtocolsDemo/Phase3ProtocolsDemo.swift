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
          "SGR mouse tracking",
          "Kitty keyboard protocol",
          "OSC 8 hyperlinks",
          "raw keyboard input",
          "alternate screen rendering",
        ],
        runCommand: "swift run --package-path Examples Phase3ProtocolsDemo",
        attachSchemeName: "Phase3ProtocolsDemo (Attach)"
      )
      return
    }

    var configuration = TerminalApplicationConfiguration.default
    configuration.modes.insert(.mouseTracking(.anyEvent))
    configuration.modes.insert(.kittyKeyboard)

    try await TerminalSession.withApplicationTerminal(
      configuration: configuration
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
      } else if key == Key(code: .character("3")) {
        state.selectedPanel = .mouse
      } else if key == Key(code: .character("4")) {
        state.selectedPanel = .keyboard
      } else if key == Key(code: .character("5")) {
        state.selectedPanel = .links
      } else if key == Key(code: .character("m")) {
        state.logsMouseMotionOutsideMousePanel.toggle()
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

    case .mouse(let event):
      if state.shouldAppendMouseEvent(event) {
        state.append(.mouse(event))
      }
      state.lastMouseEvent = event
      state.lastMouseDescription = describe(event)
      state.updateMouseGridPress(for: event)

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
      let minimumSize = minimumTerminalSize(for: state.selectedPanel)
      guard
        frame.size.columns >= minimumSize.columns,
        frame.size.rows >= minimumSize.rows
      else {
        drawSmallTerminalMessage(frame: frame, minimumSize: minimumSize)
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

      case .mouse:
        drawMousePanel(frame: frame, state: state)

      case .keyboard:
        drawKeyboardPanel(frame: frame, state: state)

      case .links:
        drawLinksPanel(frame: frame, state: state)
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
      "q quit · 1 paste · 2 focus · 3 mouse · 4 keys · 5 links · m motion log",
      at: position(0, 1),
      style: Style(attributes: [.dim])
    )
    frame.write(
      "Terminal: \(frame.size.columns)x\(frame.size.rows) · motion log outside mouse: \(state.motionLogDescription)",
      at: position(0, 2),
      style: Style(attributes: [.dim])
    )
  }

  private static func drawSmallTerminalMessage(
    frame: borrowing Frame,
    minimumSize: TerminalSize
  ) {
    guard frame.size.rows > 4, frame.size.columns > 0 else {
      return
    }

    let lines = wrappedLines(
      "Resize to at least \(minimumSize.columns)x\(minimumSize.rows) for this panel.",
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

  private static func minimumTerminalSize(for panel: DemoPanel) -> TerminalSize {
    switch panel {
    case .mouse:
      return TerminalSize(columns: 32, rows: 22)
    case .focus, .keyboard, .links, .paste:
      return TerminalSize(columns: 12, rows: 20)
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
      at: position(2, 16),
      style: Style(attributes: [.dim])
    )

    drawRecentEvents(frame: frame, state: state, top: 17)
  }

  private static func drawMousePanel(frame: borrowing Frame, state: DemoState) {
    drawLastEvent(frame: frame, state: state)

    frame.write(
      "Latest mouse event",
      at: position(0, 7),
      style: Style(attributes: [.bold])
    )
    frame.write("kind: \(state.lastMouseDescription)", at: position(2, 8))
    if let mouse = state.lastMouseEvent {
      frame.write(
        "position: column \(mouse.position.column), row \(mouse.position.row)",
        at: position(2, 9)
      )
      frame.write("modifiers: \(describe(mouse.modifiers))", at: position(2, 10))
    } else {
      frame.write("move, click, drag, or scroll inside the terminal", at: position(2, 9))
    }

    drawMouseGrid(frame: frame, state: state)
    drawRecentEvents(frame: frame, state: state, top: 20)
  }

  private static func drawKeyboardPanel(frame: borrowing Frame, state: DemoState) {
    drawLastEvent(frame: frame, state: state)

    frame.write("Latest key", at: position(0, 7), style: Style(attributes: [.bold]))
    if let key = state.lastKey {
      frame.write("code: \(key.code)", at: position(2, 8))
      frame.write("kind: \(key.kind)", at: position(2, 9))
      frame.write("modifiers: \(describe(key.modifiers))", at: position(2, 10))
      frame.write("shifted: \(describeOptional(key.shiftedCode))", at: position(2, 11))
      frame.write("base: \(describeOptional(key.baseLayoutCode))", at: position(2, 12))
      frame.write(
        "text: \(key.associatedText.map(String.init(reflecting:)) ?? "none")",
        at: position(2, 13)
      )
    } else {
      frame.write("press keys now", at: position(2, 8), style: Style(attributes: [.dim]))
    }

    frame.write(
      "Kitty protocol notes",
      at: position(0, 15),
      style: Style(attributes: [.bold])
    )
    frame.write(
      "Press Escape, Tab, arrows, modified letters, and hold a key for repeat.",
      at: position(2, 16)
    )
    frame.write(
      "Unsupported terminals should still show legacy key events below.",
      at: position(2, 17)
    )

    drawRecentEvents(frame: frame, state: state, top: 20)
  }

  private static func drawLinksPanel(frame: borrowing Frame, state: DemoState) {
    drawLastEvent(frame: frame, state: state)

    frame.write(
      "OSC 8 hyperlink samples",
      at: position(0, 7),
      style: Style(attributes: [.bold])
    )
    writeLink(
      frame: frame,
      label: "Docs:",
      text: "Tessera Spec",
      uri: "https://github.com/robfeldmann/tessera/blob/main/docs/Spec.md",
      id: "docs",
      row: 9
    )
    writeLink(
      frame: frame,
      label: "Issue:",
      text: "GH-123 terminal protocols",
      uri: "https://github.com/robfeldmann/tessera/issues/123",
      id: "issue-123",
      row: 10
    )
    writeLink(
      frame: frame,
      label: "File:",
      text: "Sources/TesseraTerminalANSI/ControlSequence.swift",
      uri: "file://Sources/TesseraTerminalANSI/ControlSequence.swift",
      id: "control-sequence",
      row: 11
    )

    frame.write("Plain fallback", at: position(0, 14), style: Style(attributes: [.bold]))
    frame.write(
      "The visible text above remains readable even when OSC 8 is unsupported.",
      at: position(2, 15),
      style: Style(attributes: [.dim])
    )

    drawRecentEvents(frame: frame, state: state, top: 18)
  }

  private static func writeLink(
    frame: borrowing Frame,
    label: String,
    text: String,
    uri: String,
    id: String,
    row: Int
  ) {
    frame.write(label, at: position(2, row), style: Style(attributes: [.bold]))
    let style: Style
    do {
      style = try Style(
        foreground: .ansi(.brightBlue),
        attributes: [.underline],
        hyperlink: Hyperlink(uri: uri, id: id)
      )
    } catch {
      style = Style(foreground: .ansi(.brightBlue), attributes: [.underline])
    }
    frame.write(text, at: position(11, row), style: style)
  }

  private static func drawMouseGrid(frame: borrowing Frame, state: DemoState) {
    let pointer = state.lastMouseEvent?.position
    let normalStyle = Style(foreground: .ansi(.brightBlack))
    let hoverStyle = Style(foreground: .ansi(.brightWhite), attributes: [.bold])
    let pressedStyle = Style(
      foreground: .ansi(.brightWhite),
      background: .ansi(.cyan),
      attributes: [.bold]
    )

    frame.write(
      "Mouse grid",
      at: position(0, MouseGrid.top),
      style: Style(attributes: [.bold])
    )
    frame.write(
      "columns →",
      at: position(2, MouseGrid.headerRow),
      style: Style(attributes: [.dim])
    )
    for column in 0..<MouseGrid.columnCount {
      let cellPosition = MouseGrid.cellPosition(row: 0, column: column)
      frame.write("\(column)", at: position(cellPosition.column, MouseGrid.headerRow))
    }

    for row in 0..<MouseGrid.rowCount {
      frame.write(
        "row \(row) →",
        at: position(2, MouseGrid.cellOrigin.row + row),
        style: Style(attributes: [.dim])
      )
      for column in 0..<MouseGrid.columnCount {
        let cellPosition = MouseGrid.cellPosition(row: row, column: column)
        let isPointerOverCell = pointer == cellPosition
        let isPressedCell = state.pressedMouseGridCell == cellPosition
        let symbol: String
        let style: Style
        if isPressedCell {
          symbol = "●"
          style = pressedStyle
        } else if isPointerOverCell {
          symbol = "●"
          style = hoverStyle
        } else {
          symbol = "·"
          style = normalStyle
        }
        frame.write(symbol, at: cellPosition, style: style)
      }
    }
  }

  private static func position(_ column: Int, _ row: Int) -> TerminalPosition {
    TerminalPosition(column: column, row: row)
  }
}

private enum MouseGrid {
  static let top = 13
  static let headerRow = top + 1
  static let cellOrigin = TerminalPosition(column: 13, row: top + 2)
  static let columnCount = 10
  static let rowCount = 3
  static let columnStride = 2

  static func cell(at position: TerminalPosition) -> TerminalPosition? {
    for row in 0..<rowCount {
      for column in 0..<columnCount {
        let cell = cellPosition(row: row, column: column)
        if cell == position {
          return cell
        }
      }
    }
    return nil
  }

  static func cellPosition(row: Int, column: Int) -> TerminalPosition {
    TerminalPosition(
      column: cellOrigin.column + column * columnStride,
      row: cellOrigin.row + row
    )
  }
}

private enum DemoPanel {
  case focus
  case keyboard
  case links
  case mouse
  case paste

  var title: String {
    switch self {
    case .focus:
      return "Focus"
    case .keyboard:
      return "Keyboard"
    case .links:
      return "Links"
    case .mouse:
      return "Mouse"
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
  var lastKey: Key?
  var lastKeyDescription = "none"
  var lastMouseDescription = "none"
  var lastMouseEvent: MouseEvent?
  var pressedMouseGridCell: TerminalPosition?
  var logsMouseMotionOutsideMousePanel = false
  var lastPaste = ""
  var sequenceNumber = 0

  var lastEventDescription: String {
    recentEvents.last ?? "none"
  }

  var formattedSequenceNumber: String {
    String(format: "%04d", sequenceNumber)
  }

  var motionLogDescription: String {
    logsMouseMotionOutsideMousePanel ? "on" : "off"
  }

  mutating func append(_ event: InputEvent) {
    sequenceNumber += 1
    if case .key(let key) = event {
      lastKey = key
    }
    recentEvents.append("\(formattedSequenceNumber) \(describe(event))")
    if recentEvents.count > 25 {
      recentEvents.removeFirst(recentEvents.count - 25)
    }
  }

  func shouldAppendMouseEvent(_ event: MouseEvent) -> Bool {
    selectedPanel == .mouse
      || logsMouseMotionOutsideMousePanel
      || !isMouseMotion(event.kind)
  }

  mutating func updateMouseGridPress(for event: MouseEvent) {
    switch event.kind {
    case .press:
      pressedMouseGridCell = MouseGrid.cell(at: event.position)
    case .release:
      pressedMouseGridCell = nil
    case .drag, .move, .scroll:
      break
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
  case .mouse(let event):
    return "mouse \(describe(event))"
  case .paste(let text):
    return "paste chars=\(text.count) lines=\(lineCount(text))"
  case .resize(let size):
    return "resize \(size.columns)x\(size.rows)"
  case .unknown(let bytes):
    return "unknown bytes=\(hex(bytes))"
  }
}

private func describe(_ key: Key) -> String {
  var parts = [
    "code=\(key.code)",
    "modifiers=\(describe(key.modifiers))",
    "kind=\(key.kind)",
  ]
  if let shiftedCode = key.shiftedCode {
    parts.append("shifted=\(shiftedCode)")
  }
  if let baseLayoutCode = key.baseLayoutCode {
    parts.append("base=\(baseLayoutCode)")
  }
  if let associatedText = key.associatedText {
    parts.append("text=\(String(reflecting: associatedText))")
  }
  return parts.joined(separator: " ")
}

private func describeOptional(_ code: KeyCode?) -> String {
  code.map(String.init(describing:)) ?? "none"
}

private func describe(_ event: MouseEvent) -> String {
  "\(describe(event.kind)) at \(event.position.column),\(event.position.row) "
    + "modifiers=\(describe(event.modifiers))"
}

private func describe(_ kind: MouseEventKind) -> String {
  switch kind {
  case .drag(let button):
    return "drag(\(button))"
  case .move:
    return "move"
  case .press(let button):
    return "press(\(button))"
  case .release(let button):
    if let button {
      return "release(\(button))"
    }
    return "release"
  case .scroll(let direction):
    return "scroll(\(direction))"
  }
}

private func isMouseMotion(_ kind: MouseEventKind) -> Bool {
  switch kind {
  case .drag, .move:
    true
  case .press, .release, .scroll:
    false
  }
}

private func describe(_ modifiers: Modifiers) -> String {
  var parts: [String] = []
  if modifiers.contains(.shift) { parts.append("shift") }
  if modifiers.contains(.alt) { parts.append("alt") }
  if modifiers.contains(.control) { parts.append("ctrl") }
  if modifiers.contains(.super) { parts.append("super") }
  if modifiers.contains(.hyper) { parts.append("hyper") }
  if modifiers.contains(.meta) { parts.append("meta") }
  if modifiers.contains(.capsLock) { parts.append("capsLock") }
  if modifiers.contains(.numLock) { parts.append("numLock") }
  return parts.isEmpty ? "none" : parts.joined(separator: "+")
}

private func lineCount(_ text: String) -> Int {
  text.split(separator: "\n", omittingEmptySubsequences: false).count
}

private func hex(_ bytes: [UInt8]) -> String {
  bytes.map { String(format: "%02X", $0) }.joined(separator: " ")
}
