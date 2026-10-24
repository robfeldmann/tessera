import Tessera
import TesseraHarness

/// A counter: the smallest demo that takes input, changes state, and quits.
///
/// `+` and `-` step the count, `0` resets it, and `q` quits.
final class Counter: Demo {
  static let name = "counter"
  static let minimum = TerminalSize(columns: 32, rows: 5)
  static let viewports: [Viewport] = [.desktop, .mobile]
  static let fixtures = [
    DemoFixture("counter-high") { Counter(count: 12_345) }
  ]

  private(set) var count: Int
  private var quitRequested = false

  var isFinished: Bool {
    quitRequested
  }

  var body: some View {
    VStack(spacing: 0) {
      Text("Counter")
      Divider()
      HStack(spacing: 0) {
        Text("Count")
        Spacer()
        Text("\(count)")
      }
      Divider()
      Text("+ up   - down   0 reset   q quit")
    }
  }

  convenience init() {
    self.init(count: 0)
  }

  private init(count: Int) {
    self.count = count
  }

  func apply(_ event: InputEvent) {
    guard case .key(let key) = event else {
      return
    }
    if isQuitKey(key) {
      quitRequested = true
      return
    }
    guard key.kind != .release, key.modifiers.isDisjoint(with: [.control, .alt, .meta])
    else {
      return
    }
    switch key.code {
    case .character("+"): count += 1
    case .character("-"): count -= 1
    case .character("0"): count = 0
    default: break
    }
  }
}
