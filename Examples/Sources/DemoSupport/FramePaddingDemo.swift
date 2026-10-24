import Tessera
import TesseraHarness

/// `frame` and `padding`: fixed and bounded frames, every alignment, uniform and per-edge
/// padding, and the order the two compose in.
///
/// Neither modifier draws anything, so each sample sits over a backdrop of dots that is the
/// size the modified view should report: the dots a `Text("Go")` does not cover are the cells
/// the modifier reserved. The first sample is a fixed 8x3 frame whose alignment `a` cycles
/// through the nine placements; `+` and `-` change the uniform padding of the `pad` sample
/// from 0 to 3 cells; the last two samples put the same `padding(1)` and `frame(width:)` in
/// both orders, which differ by two columns. `q` quits.
final class FramePaddingDemo: Demo {
  static let name = "frame-padding"
  static let minimum = TerminalSize(columns: 40, rows: 13)
  static let viewports: [Viewport] = [.desktop, .mobile]
  static let fixtures: [DemoFixture<FramePaddingDemo>] = []

  private static let alignments: [(name: String, value: Alignment)] = [
    ("topLeading", .topLeading), ("top", .top), ("topTrailing", .topTrailing),
    ("leading", .leading), ("center", .center), ("trailing", .trailing),
    ("bottomLeading", .bottomLeading), ("bottom", .bottom),
    ("bottomTrailing", .bottomTrailing),
  ]

  private static let maximumPadding = 3

  private var alignmentIndex = 0
  private var padding = 1
  private var quitRequested = false

  var isFinished: Bool {
    quitRequested
  }

  private var alignment: (name: String, value: Alignment) {
    Self.alignments[alignmentIndex]
  }

  var body: some View {
    VStack(spacing: 0) {
      Text("Frame and padding")
      Divider()
      HStack(spacing: 2) {
        sample("fixed 8x3", columns: 8, rows: 3) {
          Text("Go").frame(width: 8, height: 3, alignment: alignment.value)
        }
        sample("min 6", columns: 6, rows: 1) {
          Text("Go").frame(minWidth: 6)
        }
        sample("max 4", columns: 4, rows: 1) {
          Divider().frame(width: 12).frame(maxWidth: 4)
        }
      }
      HStack(spacing: 2) {
        sample("pad \(padding)", columns: 2 + 2 * padding, rows: 1 + 2 * padding) {
          Text("Go").padding(padding)
        }
        sample("insets", columns: 5, rows: 2) {
          Text("Go").padding(EdgeInsets(top: 0, leading: 3, bottom: 1, trailing: 0))
        }
        sample("pad+frame", columns: 8, rows: 3) {
          Text("Go").padding(1).frame(width: 8)
        }
        sample("frame+pad", columns: 10, rows: 3) {
          Text("Go").frame(width: 8).padding(1)
        }
      }
      Divider()
      Text("alignment \(alignment.name)")
      Text("a alignment   + - padding   q quit")
    }
  }

  init() {}

  private static func backdrop(columns: Int, rows: Int) -> String {
    Array(repeating: String(repeating: "·", count: columns), count: rows)
      .joined(separator: "\n")
  }

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
    case .character("+"): padding = min(padding + 1, Self.maximumPadding)
    case .character("-"): padding = max(padding - 1, 0)
    default: break
    }
  }

  /// A name over a modified view that sits on a backdrop of the size it should report.
  private func sample<Content: View>(
    _ name: String, columns: Int, rows: Int, @ViewBuilder content: () -> Content
  ) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      Text(name)
      ZStack(alignment: .topLeading) {
        Text(Self.backdrop(columns: columns, rows: rows))
        content()
      }
    }
  }
}
