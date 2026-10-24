import Tessera
import TesseraHarness

/// `HStack`, `VStack`, and `Spacer`: every alignment, spacing, and way a `Spacer` shares the
/// space left over.
///
/// The first row is an `HStack` whose spacing `s` cycles from 0 to 3. Below it, three `VStack`s
/// show `.leading`, `.center`, and `.trailing` over the same three lines, three `HStack`s show
/// `.top`, `.center`, and `.bottom` beside a three-line neighbour, and `v` switches the
/// `VStack`s between no spacing and one blank row. The last block is the `Spacer` family: one
/// `Spacer` takes everything, two share it and the earlier takes the odd cell, and a
/// `layoutPriority` hands all of it to the higher priority. `q` quits.
final class StacksDemo: Demo {
  static let name = "stacks"
  static let minimum = TerminalSize(columns: 40, rows: 20)
  static let viewports: [Viewport] = [.desktop, .mobile]
  static let fixtures: [DemoFixture<StacksDemo>] = []

  private static let maximumSpacing = 3

  private var spacing = 1
  private var rowsApart = false
  private var quitRequested = false

  var isFinished: Bool {
    quitRequested
  }

  var body: some View {
    VStack(spacing: 0) {
      Text("Stacks")
      Divider()
      HStack(spacing: spacing) {
        Text("A")
        Text("B")
        Text("C")
        Text("spacing \(spacing)")
      }
      HStack(spacing: 3) {
        columns(.leading, "leading")
        columns(.center, "center")
        columns(.trailing, "trailing")
      }
      HStack(spacing: 3) {
        beside(.top, "top")
        beside(.center, "center")
        beside(.bottom, "bottom")
      }
      Divider()
      Text("one Spacer")
      HStack(spacing: 0) {
        Text("L")
        Spacer()
        Text("R")
      }
      Text("two Spacers: earlier gets the odd cell")
      HStack(spacing: 0) {
        Text("L")
        Spacer()
        Text("M")
        Spacer()
        Text("R")
      }
      Text("priority 1: first Spacer and neighbours")
      HStack(spacing: 0) {
        Text("L").layoutPriority(1)
        Spacer().layoutPriority(1)
        Text("M").layoutPriority(1)
        Spacer()
        Text("R").layoutPriority(1)
      }
      Divider()
      Text("s spacing   v rows apart   q quit")
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
    case .character("s"): spacing = (spacing + 1) % (Self.maximumSpacing + 1)
    case .character("v"): rowsApart.toggle()
    default: break
    }
  }

  /// Three lines of different widths stacked with one horizontal alignment, under its name.
  private func columns(_ alignment: HorizontalAlignment, _ name: String) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      Text(name)
      VStack(alignment: alignment, spacing: rowsApart ? 1 : 0) {
        Text("a")
        Text("bbbbbbb")
        Text("cc")
      }
    }
  }

  /// A one-character marker beside a three-line neighbour, placed with one vertical alignment.
  private func beside(_ alignment: VerticalAlignment, _ name: String) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      Text(name)
      HStack(alignment: alignment, spacing: 1) {
        Text("M")
        Text("x\ny\nz")
      }
    }
  }
}
