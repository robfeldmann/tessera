import TesseraCore
import TesseraLayout
import TesseraTerminalCore
import TesseraTerminalInput
import TesseraWidgets

/// A responsive workspace: header, a split of a scrolling catalog and an inspector, a
/// status line. All input state is demo-owned because `ViewGraph.dispatch` is a stub.
package final class WorkspaceApp: DemoApp {
  package static let name = "workspace"

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

  package var root: some View {
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

  package init() {}

  package func apply(_ event: InputEvent) {
    switch event {
    case .resize(let newSize):
      size = newSize
    case .key(let key):
      lastKey = KeyName.describe(key)
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

/// Natural-height content only: no greedy children, so a tall proposal does not stretch
/// the root. This is the shape `mobile` natural-height measurement targets.
package final class StackApp: DemoApp {
  package static let name = "stack"

  private var size = TerminalSize(columns: 80, rows: 24)
  private var typed = ""

  package var root: some View {
    VStack(spacing: 0) {
      Text("Stack demo")
      Divider()
      HStack(spacing: 1) {
        Text("Name:")
        Text(typed.isEmpty ? "-" : typed)
      }
      HStack(spacing: 0) {
        Text("left")
        Spacer()
        Text("right")
      }
      Divider()
      Text("\(size.columns) columns")
    }
  }

  package init() {}

  package func apply(_ event: InputEvent) {
    switch event {
    case .resize(let newSize):
      size = newSize
    case .key(let key):
      switch key.code {
      case .character(let character):
        typed.append(character)
      case .backspace:
        _ = typed.popLast()
      default:
        break
      }
    default:
      break
    }
  }
}
