import Observation
import TesseraCore
import TesseraLayout
import TesseraRuntime
import TesseraTerminalCore
import TesseraTerminalInput
import TesseraWidgets

@testable import TesseraHarness

final class WorkspaceApp: Application {
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

  func apply(_ event: InputEvent) {
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
/// the root.
final class StackApp: Application {
  private var size = TerminalSize(columns: 80, rows: 24)
  private var typed = ""

  var body: some View {
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

  func apply(_ event: InputEvent) {
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

/// A root that grows to any height it is offered: a vertical spacer takes what the content
/// leaves, so `size mobile` has no natural height to use.
final class GreedyApp: Application {
  var body: some View {
    VStack(spacing: 0) {
      Text("Greedy")
      Spacer()
      Text("footer")
    }
  }

  func apply(_ event: InputEvent) {}
}

/// A view whose equal replacement lets reconciliation skip the whole subtree.
private struct StillLabel: View, Equatable {
  var body: some View {
    Text("Still")
  }
}

/// An app whose body never changes, so no step leaves the graph needing a render.
///
/// The body returns its root explicitly: a view builder would wrap it in a tuple view, which
/// is not equatable and so is dirty after every update.
final class StillApp: Application {
  var body: some View {
    let label = StillLabel()
    return label.equatable()
  }

  func apply(_ event: InputEvent) {}
}

/// A nonisolated counter: it runs on the main actor and on a per-test actor alike.
final class CounterApp: Application {
  private(set) var count = 0
  private(set) var finished = false

  var isFinished: Bool {
    finished
  }

  var body: some View {
    Text("Count: \(count)")
  }

  func apply(_ event: InputEvent) {
    guard case .key(let key) = event, key.modifiers.isEmpty else {
      return
    }
    switch key.code {
    case .character("+"): count += 1
    case .character("q"): finished = true
    default: break
    }
  }
}

/// A counter whose model is main-actor isolated: it declares an isolated conformance, so
/// only a main-actor host can use it.
@MainActor
final class MainActorCounterApp: @MainActor Application {
  private(set) var count = 0

  var body: some View {
    Text("Main-actor count: \(count)")
  }

  func apply(_ event: InputEvent) {
    if case .key(let key) = event, key.code == .character("+") {
      count += 1
    }
  }
}

/// An `@Observable` model with the contract declared where the type is declared.
@Observable
final class ObservedCounterApp: Application {
  private(set) var count = 0

  var body: some View {
    Text("Observed count: \(count)")
  }

  func apply(_ event: InputEvent) {
    if case .key(let key) = event, key.code == .character("+") {
      count += 1
    }
  }
}

enum Fixtures {
  static let names = ["stack", "workspace", "greedy"]

  /// Every fixture app, registered once under the name the scenario corpus uses.
  @MainActor
  static func registry() -> ApplicationRegistry {
    var registry = ApplicationRegistry()
    registry.register("stack", viewports: [.desktop, .mobile]) { StackApp() }
    registry.register("workspace", viewports: [.desktop, .mobileScreen]) {
      WorkspaceApp()
    }
    registry.register("greedy", viewports: [.desktop, .mobileScreen]) { GreedyApp() }
    registry.register(
      "counter", minimum: TerminalSize(columns: 20, rows: 1), viewports: [.desktop]
    ) {
      CounterApp()
    }
    registry.register("main-actor-counter", viewports: [.desktop]) {
      MainActorCounterApp()
    }
    registry.register("observed-counter", viewports: [.desktop]) { ObservedCounterApp() }
    return registry
  }
}
