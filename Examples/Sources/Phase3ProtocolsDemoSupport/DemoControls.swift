import TesseraTerminal

/// Panels available in the protocol demonstration.
public enum DemoPanel: CaseIterable, Equatable, Hashable, Sendable {
  /// Terminal capability evidence and runtime rendering policy.
  case capabilities

  /// OSC 52 clipboard writing.
  case clip

  /// Cursor shape, color, and placement.
  case cursor

  /// Terminal focus-event reporting.
  case focus

  /// Kitty graphics transmission and placement.
  case graphics

  /// Legacy and Kitty keyboard input.
  case keyboard

  /// OSC 8 hyperlink rendering.
  case links

  /// SGR mouse tracking and event volume.
  case mouse

  /// Bracketed paste input.
  case paste

  /// Extended underline style and color rendering.
  case underline

  /// Human-readable panel title.
  public var title: String {
    switch self {
    case .capabilities:
      "Capabilities"
    case .clip:
      "Clipboard"
    case .cursor:
      "Cursor"
    case .focus:
      "Focus"
    case .graphics:
      "Graphics"
    case .keyboard:
      "Keyboard"
    case .links:
      "Links"
    case .mouse:
      "Mouse"
    case .paste:
      "Paste"
    case .underline:
      "Underline"
    }
  }
}

/// One numeric tab in the protocol demonstration.
public struct DemoTab: Equatable, Sendable {
  /// Unmodified numeric key selecting this tab.
  public let key: Character

  /// Compact tab label.
  public let label: String

  /// Panel selected by the key.
  public let panel: DemoPanel

  /// Creates a tab declaration.
  public init(key: Character, label: String, panel: DemoPanel) {
    self.key = key
    self.label = label
    self.panel = panel
  }
}

/// Cursor-marker movement requested by a routed key.
public enum DemoCursorMove: Equatable, Sendable {
  /// Move one row down.
  case down

  /// Move one column left.
  case left

  /// Move one column right.
  case right

  /// Move one row up.
  case up
}

/// Side effect requested by a routed demo key.
public enum DemoKeyAction: Equatable, Sendable {
  /// Copy the fixed sample text through OSC 52.
  case copyClipboard

  /// Cycle the runtime color override.
  case cycleColorCapability

  /// Cycle cursor color.
  case cycleCursorColor

  /// Cycle cursor shape.
  case cycleCursorShape

  /// Cycle the runtime keyboard policy.
  case cycleKeyboardProtocol

  /// Cycle runtime mouse-event volume.
  case cycleMouseTracking
  /// Move the cursor playground marker.
  case moveCursor(DemoCursorMove)

  /// Exit the demonstration.
  case quit

  /// Invalidate renderer cache assumptions and repaint every cell.
  case repaintAllCells

  /// Select a numeric panel.
  case selectPanel(DemoPanel)

  /// Toggle live focus-event reporting.
  case toggleFocusEvents

  /// Toggle opt-in Kitty graphics output.
  case toggleGraphicsOutput

  /// Toggle OSC 8 hyperlink rendering.
  case toggleHyperlinks

  /// Toggle mouse-motion logging outside the mouse panel.
  case toggleMouseLogging

  /// Toggle DEC synchronized output.
  case toggleSynchronizedOutput

  /// Toggle underline color emission.
  case toggleUnderlineColor

  /// Toggle preservation of underline style variants.
  case toggleUnderlineStyle
}

/// Pure key routing and policy-cycle helpers for the protocol demonstration.
public enum DemoControls {
  /// Panel selected when the demonstration launches.
  public static let defaultPanel = DemoPanel.capabilities

  /// Full Kitty keyboard enhancement mask requested by the protocol demonstration.
  public static let kittyKeyboardFlags: KittyKeyboardFlags = [
    .disambiguateEscapeCodes,
    .reportEventTypes,
    .reportAlternateKeys,
    .reportAllKeysAsEscapeCodes,
    .reportAssociatedText,
  ]

  /// Numeric panel declarations in display order.
  public static let tabs: [DemoTab] = [
    DemoTab(key: "0", label: "Caps", panel: .capabilities),
    DemoTab(key: "1", label: "Underline", panel: .underline),
    DemoTab(key: "2", label: "Links", panel: .links),
    DemoTab(key: "3", label: "Cursor", panel: .cursor),
    DemoTab(key: "4", label: "Clip", panel: .clip),
    DemoTab(key: "5", label: "Paste", panel: .paste),
    DemoTab(key: "6", label: "Focus", panel: .focus),
    DemoTab(key: "7", label: "Keys", panel: .keyboard),
    DemoTab(key: "8", label: "Mouse", panel: .mouse),
    DemoTab(key: "9", label: "Graphics", panel: .graphics),
  ]

  /// Routes an unmodified key press or repeat for the selected panel.
  ///
  /// Releases never trigger actions. Global controls take precedence over panel-local
  /// controls; numeric tab selection follows panel-local controls.
  public static func action(for key: Key, panel: DemoPanel) -> DemoKeyAction? {
    guard key.kind != .release, key.modifiers.isEmpty else {
      return nil
    }

    switch key.code {
    case .character("q"):
      return .quit
    case .character("g"):
      return .toggleGraphicsOutput
    case .character("r"):
      return .repaintAllCells
    case .character("m"):
      return .toggleMouseLogging
    default:
      break
    }

    if let action = panelAction(for: key.code, panel: panel) {
      return action
    }
    guard case .character(let character) = key.code,
      let tab = tabs.first(where: { $0.key == character })
    else {
      return nil
    }
    return .selectPanel(tab.panel)
  }

  /// Returns the next color override in detect/truecolor/256/16/no-color order.
  public static func nextColorCapability(
    after current: ColorCapabilityOverride
  ) -> ColorCapabilityOverride {
    switch current {
    case .detect:
      .force(.truecolor)
    case .force(.truecolor), .force(.unknown):
      .force(.indexed256)
    case .force(.indexed256):
      .force(.ansi16)
    case .force(.ansi16):
      .force(.noColor)
    case .force(.noColor):
      .detect
    }
  }

  /// Returns the next mouse policy in disabled/button/any-event order.
  public static func nextMouseTracking(
    after current: MouseTrackingMode
  ) -> MouseTrackingMode {
    switch current {
    case .disabled:
      .buttonEvents
    case .buttonEvents:
      .anyEvent
    case .anyEvent:
      .disabled
    }
  }

  /// Returns the next keyboard policy in legacy/conditional/required order.
  public static func nextKeyboardProtocol(
    after current: KeyboardProtocolMode
  ) -> KeyboardProtocolMode {
    switch current {
    case .legacyOnly:
      .kittyIfAvailable
    case .kittyIfAvailable:
      .kittyRequired
    case .kittyRequired:
      .legacyOnly
    }
  }

  /// Returns the opposite live focus-event request.
  public static func nextFocusEventsEnabled(after current: Bool) -> Bool {
    !current
  }

  /// Returns the opposite OSC 8 rendering policy.
  public static func nextHyperlinkRendering(
    after current: HyperlinkRenderingMode
  ) -> HyperlinkRenderingMode {
    current == .enabled ? .disabled : .enabled
  }

  /// Returns the opposite DEC synchronized-output policy.
  public static func nextSynchronizedOutput(
    after current: SynchronizedOutputPolicy
  ) -> SynchronizedOutputPolicy {
    current == .enabled ? .disabled : .enabled
  }

  /// Returns a policy with the underline-color axis toggled.
  public static func togglingUnderlineColor(
    in current: UnderlineRenderingPolicy
  ) -> UnderlineRenderingPolicy {
    var policy = current
    policy.color = policy.color == .emit ? .omit : .emit
    return policy
  }

  /// Updates the persistent mouse-grid selection for one input event.
  ///
  /// A press selects the hit cell or clears selection when it lands outside the grid.
  /// Release, drag, move, and scroll events preserve the last clicked cell.
  public static func mouseGridSelection(
    after current: TerminalPosition?,
    eventKind: MouseEventKind,
    hitCell: TerminalPosition?
  ) -> TerminalPosition? {
    if case .press = eventKind {
      return hitCell
    }
    return current
  }

  /// Returns a policy with the underline-style axis toggled.
  public static func togglingUnderlineStyle(
    in current: UnderlineRenderingPolicy
  ) -> UnderlineRenderingPolicy {
    var policy = current
    policy.style = policy.style == .preserveVariants ? .singleOnly : .preserveVariants
    return policy
  }

  /// Returns the next index in a non-empty cyclic collection, or zero for an empty one.
  public static func nextIndex(after current: Int, count: Int) -> Int {
    guard count > 0 else {
      return 0
    }
    return (current + 1) % count
  }

  private static func panelAction(
    for code: KeyCode,
    panel: DemoPanel
  ) -> DemoKeyAction? {
    switch (panel, code) {
    case (.capabilities, .character("d")):
      .cycleColorCapability
    case (.capabilities, .character("y")):
      .toggleSynchronizedOutput
    case (.clip, .character("c")):
      .copyClipboard
    case (.cursor, .character("s")):
      .cycleCursorShape
    case (.cursor, .character("x")):
      .cycleCursorColor
    case (.cursor, .down):
      .moveCursor(.down)
    case (.cursor, .left):
      .moveCursor(.left)
    case (.cursor, .right):
      .moveCursor(.right)
    case (.cursor, .up):
      .moveCursor(.up)
    case (.focus, .character("f")):
      .toggleFocusEvents
    case (.keyboard, .character("k")):
      .cycleKeyboardProtocol
    case (.links, .character("h")):
      .toggleHyperlinks
    case (.mouse, .character("t")):
      .cycleMouseTracking
    case (.underline, .character("c")):
      .toggleUnderlineColor
    case (.underline, .character("s")):
      .toggleUnderlineStyle
    default:
      nil
    }
  }
}
