import Tessera
import TesseraHarness

/// A header, a split view of a scrolling catalog beside an inspector, and a status line: the
/// demo that fills any height it is offered, so it runs at `mobileScreen` and not `mobile`.
///
/// Typed characters, the last key, and `Enter` presses show in the inspector; `Tab` and
/// `Shift+Tab` move a pane marker in the status line, `ArrowDown`, `ArrowUp`, `PageDown`, and
/// `PageUp` scroll the catalog, and `Ctrl+C` marks the status line `quit`. Below 60 columns
/// the catalog pane collapses and the inspector takes the width.
final class Workspace: Demo {
  static let name = "workspace"
  static let minimum = TerminalSize(columns: 40, rows: 10)
  static let viewports: [Viewport] = [.desktop, .mobileScreen]
  static let fixtures: [DemoFixture<Workspace>] = []

  private static let catalogRows = 30
  private static let catalogText = (0..<catalogRows).map { "Item \($0)" }.joined(
    separator: "\n")
  private static let compactColumns = 60

  private var size = TerminalSize(columns: 80, rows: 24)
  private var typed = ""
  private let paneNames = ["catalog", "inspector"]
  private var lastKey = "none"
  private var activations = 0
  private var focusedPane = 0
  private var quitRequested = false
  private var scrollOffset = TerminalPosition(column: 0, row: 0)
  private var panes = [
    SplitViewPane(
      id: "catalog", sizing: SplitViewPaneSizing(minimum: 16, requestedIdeal: 24)),
    SplitViewPane(
      id: "inspector", sizing: SplitViewPaneSizing(minimum: 16, requestedIdeal: 40)),
  ]

  private var visiblePanes: [SplitViewPane] {
    var panes = panes
    panes[0].isCollapsed = size.columns < Self.compactColumns
    return panes
  }

  var body: some View {
    let visiblePanes = visiblePanes
    return VStack(spacing: 0) {
      Text("Workspace \(size.columns)x\(size.rows)")
      Divider()
      SplitView(
        panes: Binding(get: { visiblePanes }, set: { _ in })
      ) {
        ScrollView(
          offset: Binding(
            get: { self.scrollOffset },
            set: { self.scrollOffset = $0 }
          )
        ) {
          Text(Self.catalogText)
        }
        VStack(spacing: 0) {
          Text("Typed: \(typed)")
          Text("Key: \(lastKey)")
          Text("Count: \(activations)")
        }
      }
      Divider()
      Text(
        "focus=\(paneNames[focusedPane]) scroll=\(scrollOffset.row)"
          + (quitRequested ? " quit" : ""))
    }
  }

  init() {}

  /// The inspector's name for a key: modifiers, then the key, as `Ctrl+c` or `ArrowDown`.
  private static func describe(_ key: Key) -> String {
    var parts: [String] = []
    for (name, flag) in [
      ("Ctrl", Modifiers.control), ("Alt", .alt), ("Meta", .meta), ("Shift", .shift),
    ] where key.modifiers.contains(flag) {
      parts.append(name)
    }
    switch key.code {
    case .character(let character):
      parts.append(character == " " ? "Space" : String(character))
    case .tab: parts.append("Tab")
    case .enter: parts.append("Enter")
    case .escape: parts.append("Escape")
    case .backspace: parts.append("Backspace")
    case .delete: parts.append("Delete")
    case .up: parts.append("ArrowUp")
    case .down: parts.append("ArrowDown")
    case .left: parts.append("ArrowLeft")
    case .right: parts.append("ArrowRight")
    case .home: parts.append("Home")
    case .end: parts.append("End")
    case .pageUp: parts.append("PageUp")
    case .pageDown: parts.append("PageDown")
    case .function(let number): parts.append("F\(number)")
    default: parts.append("?")
    }
    return parts.joined(separator: "+")
  }

  func apply(_ event: InputEvent) {
    switch event {
    case .resize(let newSize):
      size = newSize
    case .key(let key):
      lastKey = Self.describe(key)
      applyKey(key)
    default:
      break
    }
  }

  private func applyKey(_ key: Key) {
    if key.modifiers.contains(.control), key.code == .character("c") {
      quitRequested = true
      return
    }
    switch key.code {
    case .character(let character)
    where key.modifiers.isDisjoint(with: [.control, .alt, .meta]):
      typed.append(character)
    case .backspace:
      _ = typed.popLast()
    case .enter:
      activations += 1
    case .tab:
      let step = key.modifiers.contains(.shift) ? paneNames.count - 1 : 1
      focusedPane = (focusedPane + step) % paneNames.count
    case .down:
      scroll(by: 1)
    case .up:
      scroll(by: -1)
    case .pageDown:
      scroll(by: 10)
    case .pageUp:
      scroll(by: -10)
    default:
      break
    }
  }

  private func scroll(by delta: Int) {
    let row = min(max(scrollOffset.row + delta, 0), Self.catalogRows - 1)
    scrollOffset = TerminalPosition(column: 0, row: row)
  }
}
