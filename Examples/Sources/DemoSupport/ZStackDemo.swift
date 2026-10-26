import Tessera
import TesseraHarness

/// `ZStack`: layers that share bounds, paint in source order, and place with one alignment.
///
/// The first sample is the catalog's anatomy, `Text("OK")` over `Text("status")`. The second
/// places a `Text("Go")` in an 8x3 backdrop of dots with the alignment `a` cycles through. The
/// third overlaps two blocks, and `s` swaps their source order: the later layer is the one
/// that shows. The last four show an empty `ZStack`, which reports no size and paints nothing,
/// a `layoutPriority` that a `ZStack` ignores, layers built by a `ForEach`, and a group of
/// layers that `g` adds with an `if`; the layers of a list are still layers, so the later
/// one shows. `q` quits.
final class ZStackDemo: Demo {
  static let name = "zstack"
  static let minimum = TerminalSize(columns: 40, rows: 11)
  static let viewports: [Viewport] = [.desktop, .mobile]
  static let fixtures: [DemoFixture<ZStackDemo>] = []

  private static let alignments: [(name: String, value: Alignment)] = [
    ("topLeading", .topLeading), ("top", .top), ("topTrailing", .topTrailing),
    ("leading", .leading), ("center", .center), ("trailing", .trailing),
    ("bottomLeading", .bottomLeading), ("bottom", .bottom),
    ("bottomTrailing", .bottomTrailing),
  ]

  private static let backdrop = Array(repeating: "········", count: 3).joined(
    separator: "\n")

  private static let layers = ["abcd", "ef"]

  private var alignmentIndex = 0
  private var swapped = false
  private var grouped = false
  private var quitRequested = false

  var isFinished: Bool {
    quitRequested
  }

  private var alignment: (name: String, value: Alignment) {
    Self.alignments[alignmentIndex]
  }

  var body: some View {
    VStack(spacing: 0) {
      Text("ZStack")
      Divider()
      HStack(spacing: 2) {
        sample("anatomy") {
          ZStack {
            Text("status")
            Text("OK").frame(width: 2)
          }
        }
        sample("alignment") {
          ZStack(alignment: alignment.value) {
            Text(Self.backdrop)
            Text("Go")
          }
        }
        sample("order") {
          if swapped {
            ZStack {
              Text("bb")
              Text("AAAA\nAAAA")
            }
          } else {
            ZStack {
              Text("AAAA\nAAAA")
              Text("bb")
            }
          }
        }
      }
      HStack(spacing: 2) {
        sample("empty") {
          HStack(spacing: 0) {
            Text("[")
            ZStack {}
            Text("]")
          }
        }
        sample("priority") {
          ZStack {
            Text("A").layoutPriority(9)
            Text("B")
          }
        }
        sample("layers") {
          ZStack {
            ForEach(Self.layers, id: \.self) { layer in
              Text(layer)
            }
          }
        }
        sample("group") {
          ZStack {
            Text("base")
            if grouped {
              Text("g")
              Text("h")
            }
          }
        }
      }
      Divider()
      Text("alignment \(alignment.name), \(swapped ? "A on top" : "bb on top")")
      Text("a alignment   s swap   g group   q quit")
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
    case .character("a"): alignmentIndex = (alignmentIndex + 1) % Self.alignments.count
    case .character("s"): swapped.toggle()
    case .character("g"): grouped.toggle()
    default: break
    }
  }

  /// A name over a sample.
  private func sample<Content: View>(
    _ name: String, @ViewBuilder content: () -> Content
  ) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      Text(name)
      content()
    }
  }
}
