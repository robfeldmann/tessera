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

    let configuration = TerminalApplicationConfiguration(
      capabilityDetection: .active,
      mouseTracking: .anyEvent,
      keyboardProtocol: .kittyIfAvailable
    )

    try await TerminalSession.withApplicationTerminal(
      configuration: configuration
    ) { terminal in
      var state = DemoState()
      try await draw(terminal: terminal, state: &state)

      for await event in terminal.events {
        if handle(event, state: &state, terminal: terminal) {
          return
        }
        try await draw(terminal: terminal, state: &state)
      }
    }
  }

  private static let tabs: [DemoTab] = [
    DemoTab(key: "1", label: "Paste", panel: .paste),
    DemoTab(key: "2", label: "Focus", panel: .focus),
    DemoTab(key: "3", label: "Mouse", panel: .mouse),
    DemoTab(key: "4", label: "Keys", panel: .keyboard),
    DemoTab(key: "5", label: "Links", panel: .links),
    DemoTab(key: "6", label: "Caps", panel: .capabilities),
    DemoTab(key: "7", label: "Graphics", panel: .graphics),
  ]

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
      // Tabs past key "9" are reachable by mouse click.
      if let tab = tabs.first(where: { key == Key(code: .character($0.key)) }) {
        state.selectedPanel = tab.panel
      } else if key == Key(code: .character("g")) {
        state.forceKittyGraphicsOutput.toggle()
      } else if key == Key(code: .character("m")) {
        state.logsMouseMotionOutsideMousePanel.toggle()
      }
    case .paste(let text):
      state.append(event)
      state.lastPaste = text
      state.observedPrivateModeSupport.insert(2_004)

    case .focusGained:
      state.observedPrivateModeSupport.insert(1_004)
      state.append(event)
      state.focusState = .focused
      state.lastFocusTransition = "focus gained at event \(state.formattedSequenceNumber)"

    case .focusLost:
      state.observedPrivateModeSupport.insert(1_004)
      state.append(event)
      state.focusState = .unfocused
      state.lastFocusTransition = "focus lost at event \(state.formattedSequenceNumber)"

    case .kittyGraphicsResponse(let response):
      if state.graphicsProbe == .pending, response.id == GraphicsDemo.probeID {
        state.graphicsProbe = response.success ? .supported : .unsupported
      }
      state.append(event)

    case .kittyKeyboardEnhancementFlags:
      state.keyboardProbe = .supported
      state.append(event)
    case .primaryDeviceAttributes:
      if state.graphicsProbe == .pending {
        state.graphicsProbe = .unsupported
      }
      if state.keyboardProbe == .probing {
        state.keyboardProbe = .unsupported
      }
      state.append(event)
    case .privateModeStatus(let status):
      state.privateModeStatuses[status.mode] = status.state
      state.append(event)
    case .mouse(let event):
      state.observedPrivateModeSupport.formUnion([1_002, 1_003, 1_006])
      if case .press = event.kind,
        let hit = state.tabHitRegions.first(where: { hit in
          event.position.row == hit.region.origin.row
            && event.position.column >= hit.region.origin.column
            && event.position.column < hit.region.origin.column + hit.region.size.columns
        })
      {
        state.selectedPanel = hit.panel
      }
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
    state: inout DemoState
  ) async throws {
    let graphicsCapability = state.kittyGraphicsCapability(
      from: terminal.capabilities.kittyGraphics
    )
    let shouldStartGraphicsProbe =
      state.selectedPanel == .graphics && state.graphicsProbe == .notStarted
      && !state.forceKittyGraphicsOutput
    if shouldStartGraphicsProbe {
      try await terminal.queryKittyGraphicsSupport(id: GraphicsDemo.probeID)
      state.graphicsProbe = .pending
    }
    let graphicsOutputEnabled =
      state.graphicsProbe == .supported || state.forceKittyGraphicsOutput
    if state.selectedPanel == .graphics && graphicsOutputEnabled {
      if !state.hasTransmittedGraphics {
        try await terminal.transmitImage(GraphicsDemo.transmission)
        state.hasTransmittedGraphics = true
      }
      state.hasVisibleGraphics = true
    } else if state.hasVisibleGraphics {
      try await terminal.deleteImages(
        .placement(GraphicsDemo.imageID, GraphicsDemo.placementID)
      )
      state.hasVisibleGraphics = false
    }
    let cellPixelSize = await terminal.cellPixelSize
    try await terminal.draw { frame in
      let layout = drawHeader(frame: frame, state: state, cellPixelSize: cellPixelSize)
      state.tabHitRegions = layout.tabHitRegions
      state.contentRowOffset = layout.contentRowOffset
      let contentTop = layout.contentTop
      let minimumSize = minimumTerminalSize(for: state.selectedPanel)
      guard
        frame.size.columns >= minimumSize.columns,
        frame.size.rows >= minimumSize.rows
      else {
        drawSmallTerminalMessage(
          frame: frame,
          minimumSize: minimumSize,
          top: contentTop
        )
        return
      }

      switch state.selectedPanel {
      case .capabilities:
        drawCapabilitiesPanel(
          frame: frame,
          capabilities: terminal.capabilities,
          enabledModes: terminal.enabledProtocolModes,
          hyperlinkRendering: terminal.hyperlinkRendering,
          synchronizedOutput: terminal.synchronizedOutput,
          state: state,
          top: contentTop
        )

      case .paste:
        drawLastEvent(frame: frame, state: state, top: contentTop)
        drawPastePreview(frame: frame, state: state, top: contentTop)
        drawKeySummary(frame: frame, state: state, top: contentTop)
        drawRecentEvents(frame: frame, state: state, top: contentTop + 15)

      case .focus:
        drawFocusPanel(frame: frame, state: state, top: contentTop)

      case .graphics:
        drawGraphicsPanel(
          frame: frame,
          state: state,
          cellPixelSize: cellPixelSize,
          graphicsCapability: graphicsCapability,
          graphicsOutputEnabled: graphicsOutputEnabled,
          top: contentTop
        )

      case .mouse:
        drawMousePanel(frame: frame, state: state, top: contentTop)

      case .keyboard:
        drawKeyboardPanel(frame: frame, state: state, top: contentTop)

      case .links:
        drawLinksPanel(frame: frame, state: state, top: contentTop)
      }
    }
  }

  private static func drawHeader(
    frame: borrowing Frame,
    state: DemoState,
    cellPixelSize: CellPixelSize?
  ) -> DemoLayout {
    let title = "Phase3ProtocolsDemo — \(state.selectedPanel.title)"
    frame.write(
      title,
      at: position(0, 0),
      style: Style(foreground: .ansi(.brightCyan), attributes: [.bold])
    )
    frame.write(
      "   \(frame.size.columns)x\(frame.size.rows) · cell \(describe(cellPixelSize))",
      at: position(title.count, 0),
      style: Style(attributes: [.dim])
    )

    let availableColumns = max(frame.size.columns, 1)
    var column = 0
    var row = 1
    var tabHitRegions: [(region: Rect, panel: DemoPanel)] = []
    for tab in tabs {
      let segment = " \(tab.key) \(tab.label) "
      let segmentWidth = segment.count
      if column > 0, column + segmentWidth > availableColumns {
        row += 1
        column = 0
      }

      let style =
        tab.panel == state.selectedPanel
        ? Style(attributes: [.reverse, .bold])
        : Style(attributes: [.dim])
      frame.write(segment, at: position(column, row), style: style)
      tabHitRegions.append(
        (
          region: Rect(column: column, row: row, columns: segmentWidth, rows: 1),
          panel: tab.panel
        )
      )
      column += segmentWidth + 1
    }

    let tabBarRows = max(row, 1)
    let hintsRow = 1 + tabBarRows
    frame.write(
      "q quit · g opt-in graphics · m motion (\(state.motionLogDescription))"
        + " · click a tab or press its number to switch",
      at: position(0, hintsRow),
      style: Style(attributes: [.dim])
    )

    let contentTop = tabBarRows + 3
    return DemoLayout(contentTop: contentTop, tabHitRegions: tabHitRegions)
  }

  private static func drawSmallTerminalMessage(
    frame: borrowing Frame,
    minimumSize: TerminalSize,
    top: Int
  ) {
    guard frame.size.rows > top, frame.size.columns > 0 else {
      return
    }

    let lines = wrappedLines(
      "Resize to at least \(minimumSize.columns)x\(minimumSize.rows) for this panel.",
      width: frame.size.columns
    )
    let availableRows = frame.size.rows - top

    for (offset, line) in lines.prefix(availableRows).enumerated() {
      frame.write(
        line,
        at: position(0, top + offset),
        style: Style(foreground: .ansi(.yellow), attributes: [.bold])
      )
    }
  }

  private static func minimumTerminalSize(for panel: DemoPanel) -> TerminalSize {
    switch panel {
    case .capabilities, .focus, .keyboard, .links, .paste:
      return TerminalSize(columns: 12, rows: 20)
    case .graphics:
      return TerminalSize(columns: 48, rows: 20)
    case .mouse:
      return TerminalSize(columns: 32, rows: 22)
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

  private static func drawLastEvent(
    frame: borrowing Frame,
    state: DemoState,
    top: Int
  ) {
    frame.write("Last event", at: position(0, top), style: Style(attributes: [.bold]))
    frame.write(state.lastEventDescription, at: position(2, top + 1))
  }

  private static func drawPastePreview(
    frame: borrowing Frame,
    state: DemoState,
    top contentTop: Int
  ) {
    let top = contentTop + 3
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

  private static func drawKeySummary(frame: borrowing Frame, state: DemoState, top: Int) {
    frame.write("Typed keys", at: position(0, top + 12), style: Style(attributes: [.bold]))
    frame.write(state.lastKeyDescription, at: position(2, top + 13))
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

  private static func drawFocusPanel(frame: borrowing Frame, state: DemoState, top: Int) {
    drawLastEvent(frame: frame, state: state, top: top)

    frame.write("Terminal focus", at: position(0, top + 3), style: Style(attributes: [.bold]))
    frame.write("state: \(state.focusState.description)", at: position(2, top + 4))
    frame.write("last transition: \(state.lastFocusTransition)", at: position(2, top + 5))

    frame.write("Try it", at: position(0, top + 8), style: Style(attributes: [.bold]))
    frame.write(
      "Switch to another terminal tab/window, then return here.",
      at: position(2, top + 9)
    )
    frame.write(
      "Some terminals only report focus while the alternate screen is active.",
      at: position(2, top + 12),
      style: Style(attributes: [.dim])
    )

    drawRecentEvents(frame: frame, state: state, top: top + 13)
  }

  private static func drawMousePanel(frame: borrowing Frame, state: DemoState, top: Int) {
    drawLastEvent(frame: frame, state: state, top: top)

    frame.write(
      "Latest mouse event",
      at: position(0, top + 3),
      style: Style(attributes: [.bold])
    )
    frame.write("kind: \(state.lastMouseDescription)", at: position(2, top + 4))
    if let mouse = state.lastMouseEvent {
      frame.write(
        "position: column \(mouse.position.column), row \(mouse.position.row)",
        at: position(2, top + 5)
      )
      frame.write("modifiers: \(describe(mouse.modifiers))", at: position(2, top + 6))
    } else {
      frame.write("move, click, drag, or scroll inside the terminal", at: position(2, top + 5))
    }

    drawMouseGrid(frame: frame, state: state, offset: top - 4)
    drawRecentEvents(frame: frame, state: state, top: top + 16)
  }

  private static func drawKeyboardPanel(frame: borrowing Frame, state: DemoState, top: Int) {
    drawLastEvent(frame: frame, state: state, top: top)

    frame.write("Latest key", at: position(0, top + 3), style: Style(attributes: [.bold]))
    if let key = state.lastKey {
      frame.write("code: \(key.code)", at: position(2, top + 4))
      frame.write("kind: \(key.kind)", at: position(2, top + 5))
      frame.write("modifiers: \(describe(key.modifiers))", at: position(2, top + 6))
      frame.write("shifted: \(describeOptional(key.shiftedCode))", at: position(2, top + 7))
      frame.write("base: \(describeOptional(key.baseLayoutCode))", at: position(2, top + 8))
      frame.write(
        "text: \(key.associatedText.map(String.init(reflecting:)) ?? "none")",
        at: position(2, top + 9)
      )
    } else {
      frame.write("press keys now", at: position(2, top + 4), style: Style(attributes: [.dim]))
    }

    frame.write(
      "Kitty protocol notes",
      at: position(0, top + 11),
      style: Style(attributes: [.bold])
    )
    frame.write(
      "Press Escape, Tab, arrows, modified letters, and hold a key for repeat.",
      at: position(2, top + 12)
    )
    frame.write(
      "Unsupported terminals should still show legacy key events below.",
      at: position(2, top + 13)
    )

    drawRecentEvents(frame: frame, state: state, top: top + 16)
  }

  private static func drawLinksPanel(frame: borrowing Frame, state: DemoState, top: Int) {
    drawLastEvent(frame: frame, state: state, top: top)

    frame.write(
      "OSC 8 hyperlink samples",
      at: position(0, top + 3),
      style: Style(attributes: [.bold])
    )
    writeLink(
      frame: frame,
      label: "Docs:",
      text: "Tessera Spec",
      uri: "https://github.com/robfeldmann/tessera/blob/main/docs/Spec.md",
      id: "docs",
      row: top + 5
    )
    writeLink(
      frame: frame,
      label: "Issue:",
      text: "GH-123 terminal protocols",
      uri: "https://github.com/robfeldmann/tessera/issues/123",
      id: "issue-123",
      row: top + 6
    )
    writeLink(
      frame: frame,
      label: "File:",
      text: "Sources/TesseraTerminalANSI/ControlSequence.swift",
      uri: "file://Sources/TesseraTerminalANSI/ControlSequence.swift",
      id: "control-sequence",
      row: top + 7
    )

    frame.write("Plain fallback", at: position(0, top + 10), style: Style(attributes: [.bold]))
    frame.write(
      "The visible text above remains readable even when OSC 8 is unsupported.",
      at: position(2, top + 11),
      style: Style(attributes: [.dim])
    )

    drawRecentEvents(frame: frame, state: state, top: top + 14)
  }

  private static func drawCapabilitiesPanel(
    frame: borrowing Frame,
    capabilities: TerminalCapabilities,
    enabledModes: Set<ModeLifecycle.Mode>,
    hyperlinkRendering: HyperlinkRenderingMode,
    synchronizedOutput: SynchronizedOutputPolicy,
    state: DemoState,
    top: Int
  ) {
    frame.write(
      "Detected terminal",
      at: position(0, top),
      style: Style(attributes: [.bold])
    )
    frame.write("identity: \(describe(capabilities.identity))", at: position(2, top + 1))
    frame.write(
      "nested:   \(capabilities.isNested ? "yes" : "no")",
      at: position(2, top + 2)
    )
    frame.write("color:    \(describe(capabilities.color))", at: position(2, top + 3))

    frame.write(
      "Protocol support",
      at: position(0, top + 6),
      style: Style(attributes: [.bold])
    )
    frame.write(
      "bracketed paste: \(state.privateModeDescription(2_004))",
      at: position(2, top + 7)
    )
    frame.write(
      "focus events:    \(state.privateModeDescription(1_004))",
      at: position(2, top + 8)
    )
    frame.write(
      "SGR mouse:       \(state.mouseCapabilityDescription)"
        + " (1002/1003/1006)",
      at: position(2, top + 9)
    )
    frame.write(
      "Kitty keyboard:  \(describe(state.keyboardProbe))",
      at: position(2, top + 10)
    )
    frame.write(
      "Kitty graphics:  \(describe(state.kittyGraphicsCapability(from: capabilities.kittyGraphics)))",
      at: position(2, top + 11)
    )
    frame.write(
      "OSC 8 links:     \(describe(capabilities.osc8Hyperlinks))"
        + ", rendering \(describe(hyperlinkRendering))",
      at: position(2, top + 12)
    )
    frame.write(
      "sync output:     \(state.privateModeDescription(2_026))"
        + ", policy \(describe(synchronizedOutput))",
      at: position(2, top + 13)
    )

    frame.write(
      "Enabled in this session",
      at: position(0, top + 15),
      style: Style(attributes: [.bold])
    )
    let lines = wrappedLines(
      describeEnabledModes(enabledModes),
      width: max(frame.size.columns - 2, 1)
    )
    for (offset, line) in lines.prefix(max(frame.size.rows - (top + 16), 0)).enumerated() {
      frame.write(line, at: position(2, top + 16 + offset))
    }
  }

  private static func drawGraphicsPanel(
    frame: borrowing Frame,
    state: DemoState,
    cellPixelSize: CellPixelSize?,
    graphicsCapability: CapabilityStatus,
    graphicsOutputEnabled: Bool,
    top: Int
  ) {
    let contentRowOffset = top - 4
    let placementRegion = Rect(
      column: GraphicsDemo.placementRegion.origin.column,
      row: GraphicsDemo.placementRegion.origin.row + contentRowOffset,
      columns: GraphicsDemo.placementRegion.size.columns,
      rows: GraphicsDemo.placementRegion.size.rows
    )

    frame.write(
      "Kitty Graphics Protocol",
      at: position(0, top),
      style: Style(attributes: [.bold])
    )
    frame.write(
      "cell pixels: \(describe(cellPixelSize))",
      at: position(2, top + 1),
      style: Style(attributes: [.dim])
    )
    frame.write(
      "demo image id \(GraphicsDemo.imageID.rawValue)"
        + " (\(GraphicsDemo.width)x\(GraphicsDemo.height) RGBA gradient)",
      at: position(2, top + 3)
    )
    frame.write(
      "placement occupies \(placementRegion.size.columns)x"
        + "\(placementRegion.size.rows) cells"
        + " at column \(placementRegion.origin.column),"
        + " row \(placementRegion.origin.row)",
      at: position(2, top + 4)
    )
    frame.write(
      "Kitty Graphics: \(describe(graphicsCapability))"
        + " · probe \(state.graphicsProbe.description)"
        + " · output \(state.forceKittyGraphicsOutput ? "forced on" : "auto")",
      at: position(2, top + 5),
      style: Style(attributes: [.dim])
    )

    guard graphicsOutputEnabled else {
      frame.write(
        state.graphicsProbe == .pending
          ? "Probing KGP support; waiting for DA1 sentinel."
          : "No KGP response arrived before DA1; image output is disabled.",
        at: placementRegion.origin,
        style: Style(attributes: [.dim])
      )
      drawRecentEvents(frame: frame, state: state, top: top + 13)
      return
    }

    frame.placeImage(
      GraphicsDemo.placement,
      at: placementRegion.origin,
      occupying: placementRegion
    )
    frame.write(
      "[ image placement renders above on supporting terminals ]",
      at: position(2, placementRegion.maxRow + 1),
      style: Style(attributes: [.dim])
    )

    drawRecentEvents(frame: frame, state: state, top: top + 13)
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

  private static func drawMouseGrid(
    frame: borrowing Frame,
    state: DemoState,
    offset: Int
  ) {
    let pointer = state.lastMouseEvent?.position
    let normalStyle = Style(foreground: .ansi(.brightBlack))
    let hoverStyle = Style(foreground: .ansi(.brightWhite), attributes: [.bold])
    let pressedStyle = Style(
      foreground: .ansi(.brightWhite),
      background: .ansi(.cyan),
      attributes: [.bold]
    )
    let headerRow = MouseGrid.headerRow(offset: offset)
    let cellOrigin = MouseGrid.cellOrigin(offset: offset)

    frame.write(
      "Mouse grid",
      at: position(0, MouseGrid.top + offset),
      style: Style(attributes: [.bold])
    )
    frame.write(
      "columns →",
      at: position(2, headerRow),
      style: Style(attributes: [.dim])
    )
    for column in 0..<MouseGrid.columnCount {
      let cellPosition = MouseGrid.cellPosition(row: 0, column: column, offset: offset)
      frame.write("\(column)", at: position(cellPosition.column, headerRow))
    }

    for row in 0..<MouseGrid.rowCount {
      frame.write(
        "row \(row) →",
        at: position(2, cellOrigin.row + row),
        style: Style(attributes: [.dim])
      )
      for column in 0..<MouseGrid.columnCount {
        let cellPosition = MouseGrid.cellPosition(row: row, column: column, offset: offset)
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

private enum GraphicsDemo {
  static let probeID = KittyImageID(rawValue: .max)

  static let height = 32
  static let imageID = KittyImageID(rawValue: 1)
  static let placementID = KittyPlacementID(rawValue: 1)
  static let placementRegion = Rect(column: 2, row: 11, columns: 8, rows: 4)
  static let width = 32

  static let placement = KittyGraphicsPlacement(
    id: imageID,
    placement: placementID,
    columns: placementRegion.size.columns,
    rows: placementRegion.size.rows
  )
  static let transmission = KittyGraphicsTransmission(
    id: imageID,
    format: .rgba(width: width, height: height),
    data: rgbaData
  )

  private static let rgbaData: [UInt8] = {
    var data: [UInt8] = []
    data.reserveCapacity(width * height * 4)
    for y in 0..<height {
      for x in 0..<width {
        data.append(UInt8(x * 255 / max(width - 1, 1)))
        data.append(UInt8(y * 255 / max(height - 1, 1)))
        data.append(180)
        data.append(255)
      }
    }
    return data
  }()
}

private enum MouseGrid {
  static let top = 13
  static let columnCount = 10
  static let rowCount = 3
  static let columnStride = 2

  static func cell(at position: TerminalPosition, offset: Int) -> TerminalPosition? {
    for row in 0..<rowCount {
      for column in 0..<columnCount {
        let cell = cellPosition(row: row, column: column, offset: offset)
        if cell == position {
          return cell
        }
      }
    }
    return nil
  }

  static func cellOrigin(offset: Int) -> TerminalPosition {
    TerminalPosition(column: 13, row: top + offset + 2)
  }

  static func cellPosition(row: Int, column: Int, offset: Int) -> TerminalPosition {
    let origin = cellOrigin(offset: offset)
    return TerminalPosition(
      column: origin.column + column * columnStride,
      row: origin.row + row
    )
  }

  static func headerRow(offset: Int) -> Int {
    top + offset + 1
  }
}

private struct DemoLayout {
  let contentTop: Int
  let tabHitRegions: [(region: Rect, panel: DemoPanel)]

  var contentRowOffset: Int {
    contentTop - 4
  }
}

private struct DemoTab {
  let key: Character
  let label: String
  let panel: DemoPanel
}

private enum DemoPanel {
  case capabilities
  case focus
  case graphics
  case keyboard
  case links
  case mouse
  case paste

  var title: String {
    switch self {
    case .capabilities:
      return "Capabilities"
    case .focus:
      return "Focus"
    case .graphics:
      return "Graphics"
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

private enum GraphicsProbeState {
  case notStarted
  case pending
  case supported
  case unsupported

  var description: String {
    switch self {
    case .notStarted:
      return "not started"
    case .pending:
      return "pending"
    case .supported:
      return "supported"
    case .unsupported:
      return "unsupported"
    }
  }
}

private struct DemoState {
  private(set) var recentEvents: [String] = []
  var selectedPanel = DemoPanel.paste
  var tabHitRegions: [(region: Rect, panel: DemoPanel)] = []
  var contentRowOffset = 0
  var keyboardProbe = CapabilityStatus.probing
  var privateModeStatuses: [Int: PrivateModeState] = [:]
  var focusState = DemoFocusState.focused
  var lastFocusTransition = "focused at startup"
  var lastKey: Key?
  var lastKeyDescription = "none"
  var lastMouseDescription = "none"
  var lastMouseEvent: MouseEvent?
  var pressedMouseGridCell: TerminalPosition?
  var logsMouseMotionOutsideMousePanel = false
  var hasTransmittedGraphics = false
  var hasVisibleGraphics = false
  var forceKittyGraphicsOutput = false
  var graphicsProbe = GraphicsProbeState.notStarted
  var observedPrivateModeSupport: Set<Int> = []
  var lastPaste = ""
  var sequenceNumber = 0

  var mouseCapability: CapabilityStatus {
    combinedCapability(for: [1_002, 1_003, 1_006])
  }

  var mouseCapabilityDescription: String {
    privateModesDescription([1_002, 1_003, 1_006], status: mouseCapability)
  }

  var lastEventDescription: String {
    recentEvents.last ?? "none"
  }

  var formattedSequenceNumber: String {
    String(format: "%04d", sequenceNumber)
  }

  var motionLogDescription: String {
    logsMouseMotionOutsideMousePanel ? "on" : "off"
  }

  func privateModeCapability(_ mode: Int) -> CapabilityStatus {
    if observedPrivateModeSupport.contains(mode) {
      return .supported
    }
    guard let state = privateModeStatuses[mode] else {
      return .probing
    }
    switch state {
    case .notRecognized:
      return .unknown
    case .permanentlyReset, .permanentlySet, .reset, .set:
      return .supported
    }
  }

  func privateModeDescription(_ mode: Int) -> String {
    privateModesDescription([mode], status: privateModeCapability(mode))
  }

  private func privateModesDescription(
    _ modes: [Int],
    status: CapabilityStatus
  ) -> String {
    let base = describe(status)
    let hasUnansweredProbe = modes.contains { privateModeStatuses[$0] == nil }
    return hasUnansweredProbe ? "\(base) (probe unanswered)" : base
  }

  private func combinedCapability(for modes: [Int]) -> CapabilityStatus {
    let statuses = modes.map(privateModeCapability)
    if statuses.allSatisfy({ $0 == .supported }) {
      return .supported
    }
    if statuses.contains(.probing) {
      return .probing
    }
    return .unknown
  }

  func kittyGraphicsCapability(from passive: CapabilityStatus) -> CapabilityStatus {
    switch graphicsProbe {
    case .supported:
      return .supported
    case .unsupported:
      return .unsupported
    case .pending:
      return .probing
    case .notStarted:
      return passive
    }
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
      pressedMouseGridCell = MouseGrid.cell(at: event.position, offset: contentRowOffset)
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

private func describe(_ status: CapabilityStatus) -> String {
  switch status {
  case .notDetectable:
    return "not detectable"
  case .probing:
    return "probing"
  case .supported:
    return "supported"
  case .unknown:
    return "unknown"
  case .unsupported:
    return "unsupported"
  }
}

private func describe(_ state: PrivateModeState) -> String {
  switch state {
  case .notRecognized:
    return "not recognized"
  case .permanentlyReset:
    return "permanently reset"
  case .permanentlySet:
    return "permanently set"
  case .reset:
    return "reset"
  case .set:
    return "set"
  }
}

private func describe(_ color: ColorCapability) -> String {
  switch color {
  case .ansi16:
    return "ANSI 16"
  case .indexed256:
    return "256-color"
  case .noColor:
    return "no color"
  case .truecolor:
    return "truecolor"
  case .unknown:
    return "unknown"
  }
}

private func describe(_ mode: HyperlinkRenderingMode) -> String {
  switch mode {
  case .disabled:
    return "disabled"
  case .enabled:
    return "enabled"
  }
}

private func describe(_ policy: SynchronizedOutputPolicy) -> String {
  switch policy {
  case .disabled:
    return "disabled"
  case .enabled:
    return "enabled"
  }
}

private func describe(_ cellPixelSize: CellPixelSize?) -> String {
  guard let cellPixelSize else {
    return "unknown"
  }
  return "\(cellPixelSize.width)x\(cellPixelSize.height) px/cell"
}

private func describe(_ identity: TerminalIdentity) -> String {
  let name = describe(identity.kind)
  let version = identity.version.map { " \($0)" } ?? ""
  let source = describe(identity.source)
  guard source != "unknown" else {
    return name + version
  }
  return "\(name)\(version) from \(source)"
}

private func describe(_ kind: TerminalIdentityKind) -> String {
  switch kind {
  case .appleTerminal:
    return "Apple Terminal"
  case .dumb:
    return "dumb"
  case .foot:
    return "foot"
  case .ghostty:
    return "Ghostty"
  case .iTerm2:
    return "iTerm2"
  case .kitty:
    return "Kitty"
  case .other(let name):
    return name
  case .screen:
    return "screen"
  case .tmux:
    return "tmux"
  case .unknown:
    return "unknown"
  case .wezTerm:
    return "WezTerm"
  case .windowsTerminal:
    return "Windows Terminal"
  case .xterm:
    return "xterm"
  }
}

private func describe(_ source: TerminalIdentitySource) -> String {
  switch source {
  case .environmentVariable(let name, _):
    return name
  case .none:
    return "unknown"
  case .term:
    return "TERM"
  case .termProgram:
    return "TERM_PROGRAM"
  case .windowsTerminalSession:
    return "WT_SESSION"
  }
}

private func describeEnabledModes(_ modes: Set<ModeLifecycle.Mode>) -> String {
  var parts: [String] = []
  if modes.contains(.rawMode) {
    parts.append("raw mode")
  }
  if modes.contains(.altScreen) {
    parts.append("alt screen")
  }
  if modes.contains(.bracketedPaste) {
    parts.append("bracketed paste")
  }
  if modes.contains(.focusEvents) {
    parts.append("focus events")
  }
  if modes.contains(where: isMouseTrackingMode) {
    parts.append("mouse")
  }
  if modes.contains(.kittyKeyboard) {
    parts.append("kitty keyboard")
  }
  return parts.isEmpty ? "none" : parts.joined(separator: " · ")
}

private func isMouseTrackingMode(_ mode: ModeLifecycle.Mode) -> Bool {
  if case .mouseTracking = mode {
    return true
  }
  return false
}

private func describe(_ event: InputEvent) -> String {
  switch event {
  case .focusGained:
    return "focus gained"
  case .focusLost:
    return "focus lost"
  case .key(let key):
    return "key \(describe(key))"
  case .kittyGraphicsResponse(let response):
    return "kitty graphics \(describe(response))"
  case .kittyKeyboardEnhancementFlags(let flags):
    return "kitty keyboard flags=\(flags)"
  case .primaryDeviceAttributes(let attributes):
    return "DA1 ?\(attributes.map(String.init).joined(separator: ";"))"
  case .privateModeStatus(let status):
    return "DECRQM ?\(status.mode) \(describe(status.state))"
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

private func describe(_ response: KittyGraphicsResponse) -> String {
  let status = response.success ? "OK" : "ERR"
  let id = response.id.map { String($0.rawValue) } ?? "none"
  let placement = response.placement.map { String($0.rawValue) } ?? "none"
  return "\(status) id=\(id) placement=\(placement) message=\(response.message)"
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
