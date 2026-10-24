import Tessera
import TesseraHarness

/// `ForEach` inside stacks: a keyed list beside static children, in both axes.
///
/// A row of tags is a `ForEach` inside an `HStack` after a label, and the items below are a
/// `ForEach` inside a `VStack` between static rows. Both are the shape that once laid every
/// item at the same frame, so the scenario for this demo runs `check siblings-disjoint` after
/// each change. `+` adds an item and `-` removes the last, up to eight, and `r` reverses the
/// order: an item keeps its identity, so `id=` finds it where it moved to. `q` quits.
final class ForEachDemo: Demo {
  private struct Item: Identifiable {
    var id: String
    var title: String
  }

  static let name = "foreach"
  static let minimum = TerminalSize(columns: 40, rows: 10)
  static let viewports: [Viewport] = [.desktop, .mobile]
  static let fixtures: [DemoFixture<ForEachDemo>] = []

  private static let pool = [
    Item(id: "a", title: "alpha"), Item(id: "b", title: "bravo"),
    Item(id: "c", title: "charlie"), Item(id: "d", title: "delta"),
    Item(id: "e", title: "echo"), Item(id: "f", title: "foxtrot"),
    Item(id: "g", title: "golf"), Item(id: "h", title: "hotel"),
  ]

  private static let tags = ["swift", "tui", "views"]

  private var count = 3
  private var reversed = false
  private var quitRequested = false

  var isFinished: Bool {
    quitRequested
  }

  private var items: [Item] {
    let shown = Array(Self.pool.prefix(count))
    return reversed ? shown.reversed() : shown
  }

  var body: some View {
    VStack(spacing: 0) {
      Text("ForEach")
      Divider()
      HStack(spacing: 1) {
        Text("tags")
        ForEach(Self.tags, id: \.self) { tag in
          Text("#\(tag)")
        }
      }
      Divider()
      ForEach(items) { item in
        HStack(spacing: 1) {
          Text(item.id)
          Text(item.title)
        }
      }
      Divider()
      Text("\(count) items\(reversed ? ", reversed" : "")")
      Text("+ add   - remove   r reverse   q quit")
    }
  }

  init() {}

  func apply(_ event: InputEvent) {
    guard case .key(let key) = event, key.kind != .release else {
      return
    }
    if isQuitKey(key) {
      quitRequested = true
      return
    }
    guard key.modifiers.isEmpty else {
      return
    }
    switch key.code {
    case .character("+"): count = min(count + 1, Self.pool.count)
    case .character("-"): count = max(count - 1, 0)
    case .character("r"): reversed.toggle()
    default: break
    }
  }
}
