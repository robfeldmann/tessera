import ExampleSupport
import Foundation
import TesseraTerminal

@main
enum RendererDemo {
  static func main() async throws {
    guard TerminalExampleSupport.isRunningInInteractiveTerminal() else {
      TerminalExampleSupport.printTerminalRequiredMessage(
        applicationName: "RendererDemo",
        features: [
          "raw mode",
          "alternate screen",
          "damage-tracked rendering",
          "Unicode-width-aware buffers",
        ],
        runCommand: "swift run --package-path Examples RendererDemo",
        attachSchemeName: "RendererDemo (Attach)"
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

    case .key(let key) where key == Key(code: .character(" ")):
      if state.scene.isAnimated {
        state.advanceFrame()
      } else {
        state.message = "this scene is static; press n/p or i"
      }

    case .key(let key) where key == Key(code: .character("i")):
      state.message = "renderer invalidated; next draw forced a full repaint"
      terminal.invalidateRenderer()

    case .key(let key) where key == Key(code: .character("n")):
      state.nextScene()

    case .key(let key) where key == Key(code: .character("p")):
      state.previousScene()

    case .key:
      state.message = "press n/p to change scenes, space to animate, i to invalidate"

    case .paste(let text):
      state.message = "paste ignored by renderer demo: \(text.count) characters"

    case .focusGained, .focusLost, .kittyGraphicsResponse, .kittyKeyboardEnhancementFlags,
      .mouse, .primaryDeviceAttributes, .privateModeStatus:
      state.message = "protocol event ignored by renderer demo"

    case .resize(let size):
      state.message = resizeMessage(size)
      terminal.invalidateRenderer()

    case .unknown(let bytes):
      state.message =
        "unknown input: \(bytes.map { String(format: "%02X", $0) }.joined(separator: " "))"
    }

    return false
  }

  private static func draw(
    terminal: isolated TerminalSession,
    state: DemoState
  ) async throws {
    try await terminal.draw { frame in
      drawChrome(frame: frame, state: state)

      switch state.scene {
      case .incrementalText:
        drawIncrementalText(frame: frame, state: state)
      case .invalidateAndResize:
        drawInvalidateAndResize(frame: frame, state: state)
      case .rawPayload:
        drawRawPayload(frame: frame, state: state)
      case .styleDeltas:
        drawStyleDeltas(frame: frame, state: state)
      case .wideOverwrite:
        drawWideOverwrite(frame: frame, state: state)
      case .widthCorrectness:
        drawWidthCorrectness(frame: frame)
      }
    }
  }

  private static func drawChrome(frame: borrowing Frame, state: DemoState) {
    frame.write(
      "RendererDemo — \(state.progressText): \(state.scene.title)",
      at: position(0, 0),
      style: Style(foreground: .ansi(.brightCyan), attributes: [.bold])
    )
    frame.write(
      "n next · p previous · space animate · i invalidate · q quit",
      at: position(0, 1),
      style: Style(attributes: [.dim])
    )
    frame.write(
      state.message,
      at: position(0, max(frame.size.rows - 1, 0)),
      style: Style(foreground: .ansi(.yellow))
    )
  }

  private static func drawIncrementalText(frame: borrowing Frame, state: DemoState) {
    let row = 4
    let dotCount = min(max(frame.size.columns - 2, 1), 60)
    let markerColumn = state.frameIndex % dotCount

    frame.write(
      "Only one marker cell changes as you press space:",
      at: position(0, row)
    )
    frame.write(
      String(repeating: "·", count: dotCount),
      at: position(0, row + 2)
    )
    frame.write(
      "●",
      at: position(markerColumn, row + 2),
      style: Style(foreground: .ansi(.brightGreen), attributes: [.bold])
    )
  }

  private static func drawWidthCorrectness(frame: borrowing Frame) {
    let samples = [
      ("ASCII", "hello"),
      ("CJK", "你好 "),
      ("emoji", "🙂   "),
      ("mixed", "A你🙂"),
      ("accent", "é    "),
      ("combining", "e\u{0301}    "),
    ]

    frame.write("Columns:   |12345|", at: position(0, 4))
    frame.write("------------------", at: position(0, 5))
    for (offset, sample) in samples.enumerated() {
      let row = 6 + offset
      frame.write(
        sample.0,
        at: position(0, row),
        style: Style(attributes: [.bold])
      )
      frame.write(
        "|",
        at: position(11, row),
        style: Style(foreground: .ansi(.brightBlack))
      )
      frame.write(sample.1, at: position(12, row))
      frame.write(
        "|",
        at: position(17, row),
        style: Style(foreground: .ansi(.brightBlack))
      )
    }
    frame.write(
      "ZWJ emoji and flags vary by terminal/font, so this ruler avoids them.",
      at: position(0, 13),
      style: Style(attributes: [.dim])
    )
  }

  private static func drawWideOverwrite(frame: borrowing Frame, state: DemoState) {
    let phase = state.frameIndex % 3
    let demoColumn = 10
    frame.write(
      "Wide graphemes occupy two cells; overwrites clear the other half.",
      at: position(0, 4)
    )
    frame.write("columns:", at: position(0, 6), style: Style(attributes: [.dim]))
    frame.write("012345", at: position(demoColumn, 6), style: Style(attributes: [.dim]))
    frame.write("cells:", at: position(0, 8), style: Style(attributes: [.dim]))

    switch phase {
    case 0:
      frame.write(
        "你",
        at: position(demoColumn, 8),
        style: Style(foreground: .ansi(.green))
      )
      frame.write(
        "你",
        at: position(demoColumn + 4, 8),
        style: Style(foreground: .ansi(.green))
      )
      frame.write("wide graphemes at columns 0-1 and 4-5", at: position(0, 10))
    case 1:
      frame.write(
        "x",
        at: position(demoColumn, 8),
        style: Style(foreground: .ansi(.red))
      )
      frame.write(
        "你",
        at: position(demoColumn + 4, 8),
        style: Style(foreground: .ansi(.green))
      )
      frame.write("overwrite leading cell 0; cell 1 is cleared", at: position(0, 10))
    default:
      frame.write(
        "你",
        at: position(demoColumn, 8),
        style: Style(foreground: .ansi(.green))
      )
      frame.write(
        "x",
        at: position(demoColumn + 5, 8),
        style: Style(foreground: .ansi(.red))
      )
      frame.write("overwrite trailing cell 5; cell 4 is cleared", at: position(0, 10))
    }
  }

  private static func drawStyleDeltas(frame: borrowing Frame, state: DemoState) {
    let selectedStyle = Style(
      foreground: .ansi(.black),
      background: .ansi(.brightYellow),
      attributes: [.bold]
    )
    let normalStyle = Style(foreground: .ansi(.brightWhite), background: .ansi(.blue))
    let badgeStyle = state.frameIndex.isMultiple(of: 2) ? selectedStyle : normalStyle

    frame.write(
      "Semantic underline styles and colors repaint independently.",
      at: position(0, 4)
    )
    frame.write(
      "Unsupported terminals may show plain or straight underlines.",
      at: position(0, 5),
      style: Style(attributes: [.dim])
    )
    frame.write(
      "single",
      at: position(0, 6),
      style: Style(underlineStyle: .single)
    )
    frame.write(
      "double",
      at: position(10, 6),
      style: Style(underlineStyle: .double)
    )
    frame.write(
      "curly",
      at: position(20, 6),
      style: Style(underlineStyle: .curly)
    )
    frame.write(
      "dotted",
      at: position(30, 6),
      style: Style(underlineStyle: .dotted)
    )
    frame.write(
      "dashed",
      at: position(40, 6),
      style: Style(underlineStyle: .dashed)
    )
    frame.write(
      "indexed 196",
      at: position(0, 7),
      style: Style(underlineStyle: .single, underlineColor: .indexed(196))
    )
    frame.write(
      "RGB 1,2,3",
      at: position(16, 7),
      style: Style(underlineStyle: .curly, underlineColor: .rgb(1, 2, 3))
    )
    let animatedUnderlineColor: Color =
      state.frameIndex.isMultiple(of: 2) ? .indexed(196) : .rgb(95, 175, 255)
    frame.write(
      "animated",
      at: position(30, 7),
      style: Style(underlineStyle: .curly, underlineColor: animatedUnderlineColor)
    )
    frame.write(
      " ERROR ",
      at: position(0, 8),
      style: Style(foreground: .ansi(.brightWhite), background: .ansi(.red))
    )
    frame.write(" ACTIVE ", at: position(9, 8), style: badgeStyle)
    frame.write(
      " OK ",
      at: position(19, 8),
      style: Style(foreground: .ansi(.black), background: .ansi(.brightGreen))
    )
  }

  private static func drawRawPayload(frame: borrowing Frame, state: DemoState) {
    let rawColumn = state.frameIndex.isMultiple(of: 2) ? 10 : 31
    frame.write(
      "Raw bytes are emitted directly, but still reserve declared buffer cells.",
      at: position(0, 4)
    )
    frame.write(
      "Press space: RAW jumps between slots; stale bytes should disappear.",
      at: position(0, 5)
    )
    frame.write("cells:    012                  012", at: position(0, 7))
    frame.write("slot A:  [   ]       slot B:  [   ]", at: position(0, 9))
    frame.writeRaw(
      RawTerminalPayload(bytes: Array("RAW".utf8), declaredWidth: 3),
      at: position(rawColumn, 9),
      occupying: Rect(column: rawColumn, row: 9, columns: 3, rows: 1)
    )
    frame.write("declared width: 3 cells", at: position(0, 11))
  }

  private static func drawInvalidateAndResize(
    frame: borrowing Frame,
    state: DemoState
  ) {
    frame.write(
      "Press i to invalidate the renderer and force erase + repaint.",
      at: position(0, 4)
    )
    frame.write(
      "Resize this terminal to trigger invalidation in the demo loop.",
      at: position(0, 5)
    )
    frame.write(
      "current size: \(frame.size.columns)x\(frame.size.rows)",
      at: position(0, 7),
      style: Style(foreground: .ansi(.brightGreen), attributes: [.bold])
    )
    frame.write("This scene has no spacebar animation.", at: position(0, 8))
  }

  private static func resizeMessage(_ size: TerminalSize?) -> String {
    guard let size else {
      return "resize event received; renderer invalidated"
    }
    return "resize event: \(size.columns)x\(size.rows); renderer invalidated"
  }
}

private struct DemoState {
  var frameIndex = 0
  var message = "space advances the current scene"
  var scene = DemoScene.incrementalText

  var progressText: String {
    "demo \(scene.index) of \(DemoScene.allCases.count)"
  }

  mutating func advanceFrame() {
    frameIndex += 1
    message = "advanced frame \(frameIndex)"
  }

  mutating func nextScene() {
    scene = scene.next
    frameIndex = 0
    message = scene.title
  }

  mutating func previousScene() {
    scene = scene.previous
    frameIndex = 0
    message = scene.title
  }
}

private enum DemoScene: Int, CaseIterable {
  case incrementalText
  case invalidateAndResize
  case rawPayload
  case styleDeltas
  case wideOverwrite
  case widthCorrectness

  var title: String {
    switch self {
    case .incrementalText:
      "incremental text"
    case .invalidateAndResize:
      "invalidate and resize"
    case .rawPayload:
      "raw payload anchoring"
    case .styleDeltas:
      "style deltas"
    case .wideOverwrite:
      "wide overwrite cleanup"
    case .widthCorrectness:
      "width correctness"
    }
  }

  var index: Int {
    rawValue + 1
  }

  var isAnimated: Bool {
    switch self {
    case .incrementalText, .rawPayload, .styleDeltas, .wideOverwrite:
      true
    case .invalidateAndResize, .widthCorrectness:
      false
    }
  }

  var next: Self {
    Self(rawValue: (rawValue + 1) % Self.allCases.count) ?? .incrementalText
  }

  var previous: Self {
    Self(rawValue: (rawValue + Self.allCases.count - 1) % Self.allCases.count)
      ?? .incrementalText
  }
}

private func position(_ column: Int, _ row: Int) -> TerminalPosition {
  TerminalPosition(column: column, row: row)
}
