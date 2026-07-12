import Phase3ProtocolsDemoSupport
import TesseraTerminal
import Testing

@Test
func `demo requests the full Kitty keyboard mask`() {
  #expect(DemoControls.kittyKeyboardFlags.rawValue == 31)
  #expect(DemoControls.kittyKeyboardFlags.contains(.reportAllKeysAsEscapeCodes))
  #expect(DemoControls.kittyKeyboardFlags.contains(.reportAssociatedText))
}

@Test
func `Ghostty all-keys text reports still route demo controls`() throws {
  var parser = InputParser()
  let qEvent = try #require(
    parser.feed(contentsOf: Array("\u{1B}[113;;113u".utf8)).first
  )
  guard case .key(let qKey) = qEvent else {
    Issue.record("Ghostty q report did not parse as a key: \(qEvent)")
    return
  }
  #expect(DemoControls.action(for: qKey, panel: .capabilities) == .quit)

  for (offset, tab) in DemoControls.tabs.enumerated() {
    let scalar = 48 + offset
    let event = try #require(
      parser.feed(
        contentsOf: Array("\u{1B}[\(scalar);;\(scalar)u".utf8)
      ).first
    )
    guard case .key(let key) = event else {
      Issue.record("Ghostty tab report did not parse as a key: \(event)")
      continue
    }
    #expect(DemoControls.action(for: key, panel: .capabilities) == .selectPanel(tab.panel))
  }
}

@Test
func `tabs declare every panel with unique numeric keys`() {
  #expect(DemoControls.tabs.map(\.key) == Array("0123456789"))
  #expect(DemoControls.defaultPanel == .capabilities)
  #expect(DemoControls.tabs.first?.panel == DemoControls.defaultPanel)
  #expect(
    DemoControls.tabs.map(\.panel) == [
      .capabilities,
      .underline,
      .links,
      .cursor,
      .clip,
      .paste,
      .focus,
      .keyboard,
      .mouse,
      .graphics,
    ]
  )
  #expect(Set(DemoControls.tabs.map(\.key)).count == DemoControls.tabs.count)
  #expect(Set(DemoControls.tabs.map(\.panel)) == Set(DemoPanel.allCases))

  for tab in DemoControls.tabs {
    #expect(
      DemoControls.action(
        for: Key(code: .character(tab.key)),
        panel: .paste
      ) == .selectPanel(tab.panel)
    )
  }
}

@Test(
  arguments: [
    GlobalRoutingCase(character: "q", action: .quit),
    GlobalRoutingCase(character: "g", action: .toggleGraphicsOutput),
    GlobalRoutingCase(character: "r", action: .repaintAllCells),
    GlobalRoutingCase(character: "m", action: .toggleMouseLogging),
  ]
)
private func `global controls accept presses and repeats but not releases`(
  testCase: GlobalRoutingCase
) {
  for kind in [KeyEventKind.press, .repeat] {
    #expect(
      DemoControls.action(
        for: Key(code: .character(testCase.character), kind: kind),
        panel: .underline
      ) == testCase.action
    )
  }
  #expect(
    DemoControls.action(
      for: Key(code: .character(testCase.character), kind: .release),
      panel: .underline
    ) == nil
  )
}

@Test(
  arguments: [
    RoutingCase(
      panel: .capabilities,
      code: .character("d"),
      action: .cycleColorCapability
    ),
    RoutingCase(
      panel: .capabilities,
      code: .character("y"),
      action: .toggleSynchronizedOutput
    ),
    RoutingCase(panel: .clip, code: .character("c"), action: .copyClipboard),
    RoutingCase(panel: .cursor, code: .character("s"), action: .cycleCursorShape),
    RoutingCase(panel: .cursor, code: .character("x"), action: .cycleCursorColor),
    RoutingCase(panel: .cursor, code: .down, action: .moveCursor(.down)),
    RoutingCase(panel: .cursor, code: .left, action: .moveCursor(.left)),
    RoutingCase(panel: .cursor, code: .right, action: .moveCursor(.right)),
    RoutingCase(panel: .cursor, code: .up, action: .moveCursor(.up)),
    RoutingCase(panel: .focus, code: .character("f"), action: .toggleFocusEvents),
    RoutingCase(panel: .keyboard, code: .character("k"), action: .cycleKeyboardProtocol),
    RoutingCase(panel: .links, code: .character("h"), action: .toggleHyperlinks),
    RoutingCase(panel: .mouse, code: .character("t"), action: .cycleMouseTracking),
    RoutingCase(panel: .underline, code: .character("c"), action: .toggleUnderlineColor),
    RoutingCase(panel: .underline, code: .character("s"), action: .toggleUnderlineStyle),
  ]
)
private func `panel controls route presses and repeats without release side effects`(
  testCase: RoutingCase
) {
  #expect(
    DemoControls.action(
      for: Key(code: testCase.code),
      panel: testCase.panel
    ) == testCase.action
  )
  #expect(
    DemoControls.action(
      for: Key(code: testCase.code, kind: .repeat),
      panel: testCase.panel
    ) == testCase.action
  )
  #expect(
    DemoControls.action(
      for: Key(code: testCase.code, kind: .release),
      panel: testCase.panel
    ) == nil
  )
}

@Test
func `panel-local collisions resolve only in their selected panel`() {
  #expect(
    DemoControls.action(
      for: Key(code: .character("c")),
      panel: .clip
    ) == .copyClipboard
  )
  #expect(
    DemoControls.action(
      for: Key(code: .character("c")),
      panel: .underline
    ) == .toggleUnderlineColor
  )
  #expect(
    DemoControls.action(
      for: Key(code: .character("s")),
      panel: .cursor
    ) == .cycleCursorShape
  )
  #expect(
    DemoControls.action(
      for: Key(code: .character("s")),
      panel: .underline
    ) == .toggleUnderlineStyle
  )
  #expect(DemoControls.action(for: Key(code: .character("c")), panel: .paste) == nil)
  #expect(DemoControls.action(for: Key(code: .character("s")), panel: .paste) == nil)
}

@Test
func `modified and unrelated keys do not trigger controls`() {
  #expect(
    DemoControls.action(
      for: Key(code: .character("q"), modifiers: .control),
      panel: .paste
    ) == nil
  )
  #expect(
    DemoControls.action(
      for: Key(code: .character("f"), modifiers: .shift),
      panel: .focus
    ) == nil
  )
  #expect(DemoControls.action(for: Key(code: .escape), panel: .keyboard) == nil)
  for kind in [KeyEventKind.press, .repeat, .release] {
    #expect(
      DemoControls.action(
        for: Key(code: .modifier(.leftShift), kind: kind),
        panel: .keyboard
      ) == nil
    )
  }
}

@Test
func `color capability cycle covers detect and every concrete depth`() {
  let values: [ColorCapabilityOverride] = [
    .detect,
    .force(.truecolor),
    .force(.indexed256),
    .force(.ansi16),
    .force(.noColor),
  ]
  for (current, expected) in zip(values, values.dropFirst() + [values[0]]) {
    #expect(DemoControls.nextColorCapability(after: current) == expected)
  }
  #expect(DemoControls.nextColorCapability(after: .force(.unknown)) == .force(.indexed256))
}

@Test
func `mouse and keyboard cycles wrap through every runtime policy`() {
  #expect(DemoControls.nextMouseTracking(after: .disabled) == .buttonEvents)
  #expect(DemoControls.nextMouseTracking(after: .buttonEvents) == .anyEvent)
  #expect(DemoControls.nextMouseTracking(after: .anyEvent) == .disabled)

  #expect(DemoControls.nextKeyboardProtocol(after: .legacyOnly) == .kittyIfAvailable)
  #expect(DemoControls.nextKeyboardProtocol(after: .kittyIfAvailable) == .kittyRequired)
  #expect(DemoControls.nextKeyboardProtocol(after: .kittyRequired) == .legacyOnly)
}

@Test
func `binary rendering and focus controls toggle both directions`() {
  #expect(DemoControls.nextFocusEventsEnabled(after: false))
  #expect(DemoControls.nextFocusEventsEnabled(after: true) == false)
  #expect(DemoControls.nextHyperlinkRendering(after: .disabled) == .enabled)
  #expect(DemoControls.nextHyperlinkRendering(after: .enabled) == .disabled)
  #expect(DemoControls.nextSynchronizedOutput(after: .disabled) == .enabled)
  #expect(DemoControls.nextSynchronizedOutput(after: .enabled) == .disabled)
}

@Test
func `underline axis controls preserve the unrelated axis`() {
  let colorToggled = DemoControls.togglingUnderlineColor(in: .extended)
  #expect(colorToggled.style == .preserveVariants)
  #expect(colorToggled.color == .omit)
  #expect(DemoControls.togglingUnderlineColor(in: colorToggled) == .extended)

  let styleToggled = DemoControls.togglingUnderlineStyle(in: .extended)
  #expect(styleToggled.style == .singleOnly)
  #expect(styleToggled.color == .emit)
  #expect(DemoControls.togglingUnderlineStyle(in: styleToggled) == .extended)
}

@Test
func `mouse grid selection persists through release and clears on outside press`() {
  let cell = TerminalPosition(column: 10, row: 12)
  let selected = DemoControls.mouseGridSelection(
    after: nil,
    eventKind: .press(.left),
    hitCell: cell
  )
  #expect(selected == cell)
  #expect(
    DemoControls.mouseGridSelection(
      after: selected,
      eventKind: .release(.left),
      hitCell: cell
    ) == cell
  )
  #expect(
    DemoControls.mouseGridSelection(
      after: selected,
      eventKind: .move,
      hitCell: nil
    ) == cell
  )
  #expect(
    DemoControls.mouseGridSelection(
      after: selected,
      eventKind: .press(.left),
      hitCell: nil
    ) == nil
  )
}

@Test
func `cyclic index wraps and handles an empty collection`() {
  #expect(DemoControls.nextIndex(after: 0, count: 3) == 1)
  #expect(DemoControls.nextIndex(after: 2, count: 3) == 0)
  #expect(DemoControls.nextIndex(after: 4, count: 0) == 0)
}

private struct GlobalRoutingCase: CustomTestStringConvertible, Sendable {
  let character: Character
  let action: DemoKeyAction

  var testDescription: String {
    "\(character) → \(action)"
  }
}

private struct RoutingCase: CustomTestStringConvertible, Sendable {
  let panel: DemoPanel
  let code: KeyCode
  let action: DemoKeyAction

  var testDescription: String {
    "\(panel.title): \(code) → \(action)"
  }
}
