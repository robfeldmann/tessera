import Tessera

/// The contract the live runner needs from an app: a graph and an app-owned model update.
///
/// This mirrors plan 033's `HeadlessApp`: the runner owns the loop, the app owns state.
public protocol LiveApp: AnyObject {
  var graph: ViewGraph { get }

  /// Applies one input event to the app-owned model; returns `false` when the app should exit.
  func apply(_ event: InputEvent) -> Bool
}

/// A tiny interactive app: a selectable list of counters driven by Tab and the arrow keys.
public final class CounterApp: LiveApp {
  struct Row: Identifiable {
    let id: String
    var count = 0
  }

  private let initialSize: TerminalSize

  private(set) var eventCount = 0
  private(set) var lastKey = "none"
  private(set) var rows = [
    Row(id: "Alpha"), Row(id: "Beta"), Row(id: "Gamma"), Row(id: "你好 wide"),
  ]
  private(set) var selection = 0

  public private(set) lazy var graph = ViewGraph(
    root: { CounterRoot(model: self) },
    size: initialSize
  )

  public init(size: TerminalSize = TerminalSize(columns: 80, rows: 24)) {
    initialSize = size
  }

  var total: Int {
    rows.reduce(0) { $0 + $1.count }
  }

  public func apply(_ event: InputEvent) -> Bool {
    eventCount += 1
    guard case .key(let key) = event, key.kind != .release else {
      return true
    }
    lastKey = KeyNames.describe(key)

    switch (key.code, key.modifiers) {
    case (.character("q"), []), (.character("c"), .control):
      return false
    case (.tab, .shift), (.up, _), (.character("k"), []):
      selection = (selection + rows.count - 1) % rows.count
    case (.tab, _), (.down, _), (.character("j"), []):
      selection = (selection + 1) % rows.count
    case (.character("+"), _), (.character("="), _), (.right, _), (.enter, _), (.character(" "), _):
      rows[selection].count += 1
    case (.character("-"), _), (.left, _):
      rows[selection].count -= 1
    default:
      break
    }
    return true
  }
}

struct CounterRoot: View {
  let model: CounterApp

  var body: some View {
    VStack {
      Text("LiveSocket counter", style: Style(attributes: .bold))
      Text("Tab/Down next  Shift+Tab/Up prev  +/- change  q quit")
      Text(" ")
      // HEAD stacks give every `ForEach` child the same frame (observed through `tree`), so
      // the rows are explicit.
      row(0)
      row(1)
      row(2)
      row(3)
      Text(" ")
      Text(
        "selected \(model.rows[model.selection].id)  total \(model.total)  "
          + "events \(model.eventCount)  last key \(model.lastKey)"
      )
    }
  }

  private func row(_ index: Int) -> Text {
    let row = model.rows[index]
    let selected = index == model.selection
    return Text(
      "\(selected ? ">" : " ") \(row.id)  \(row.count)",
      style: selected ? Style(attributes: .reverse) : Style()
    )
  }
}
