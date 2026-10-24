import Tessera
import TesseraHarness

/// `Flex`: explicit integer constraints on one axis, each shown as bars whose width is the
/// allocation the constraint resolved to.
///
/// Most bars are runs of one letter far wider than their allocation, so what shows is exactly
/// the cells `Flex` gave them: `A` runs for the first child, `B` for the second. The rows are
/// the constraint vocabulary (`length`, `fill`, `max`, `percentage`, and `ratio`). Two rows use
/// short letters instead, because an allocation can only be seen through where the next child
/// starts: the fill weights (`w` cycles 1:1, 1:2, 1:3, and 2:1 and moves where `B` starts),
/// and a `min` row whose first child grows into the space left. `s` cycles the spacing of
/// every row between 0, 1, and 2, and the last sample is a vertical `Flex` in a seven-row
/// frame. `q` quits.
final class FlexDemo: Demo {
  static let name = "flex"
  static let minimum = TerminalSize(columns: 40, rows: 22)
  static let viewports: [Viewport] = [.desktop, .mobile]
  static let fixtures: [DemoFixture<FlexDemo>] = []

  private static let weights: [(first: Int, second: Int)] = [
    (1, 1), (1, 2), (1, 3), (2, 1),
  ]

  private var weightIndex = 0
  private var spacing = 1
  private var quitRequested = false

  var isFinished: Bool {
    quitRequested
  }

  private var weight: (first: Int, second: Int) {
    Self.weights[weightIndex]
  }

  var body: some View {
    VStack(spacing: 0) {
      Text("Flex")
      Divider()
      row("length(4) fill(1) max(4)") {
        bar("A").flex(.length(4))
        bar("B").flex(.fill(1))
        bar("C").flex(.max(4))
      }
      row("percentage(25) percentage(75)") {
        bar("A").flex(.percentage(25))
        bar("B").flex(.percentage(75))
      }
      row("ratio(1, 3) fill(1)") {
        bar("A").flex(.ratio(1, 3))
        bar("B").flex(.fill(1))
      }
      row("fill(\(weight.first)) fill(\(weight.second))") {
        Text("A").flex(.fill(weight.first))
        Text("B").flex(.fill(weight.second))
      }
      row("min(10) length(1)") {
        Text("A").flex(.min(10))
        Text("B").flex(.length(1))
      }
      HStack(spacing: 2) {
        Flex(.vertical, spacing: spacing) {
          column("A").flex(.length(1))
          column("B").flex(.fill(1))
          column("C").flex(.length(1))
        }
        .frame(width: 1, height: 7)
        Text("vertical: length(1) fill(1) length(1)")
      }
      Divider()
      Text("spacing \(spacing)")
      Text("w weights   s spacing   q quit")
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
    case .character("w"): weightIndex = (weightIndex + 1) % Self.weights.count
    case .character("s"): spacing = (spacing + 1) % 3
    default: break
    }
  }

  /// A caption over one horizontal `Flex`.
  private func row<Content: View>(
    _ caption: String, @ViewBuilder content: () -> Content
  ) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      Text(caption)
      Flex(.horizontal, spacing: spacing, content: content)
    }
  }

  /// A run of `letter` wider than any allocation the demo's rows can give it.
  private func bar(_ letter: String) -> Text {
    Text(String(repeating: letter, count: 80))
  }

  /// A column of `letter` taller than the vertical sample's frame.
  private func column(_ letter: String) -> Text {
    Text(Array(repeating: letter, count: 12).joined(separator: "\n"))
  }
}
