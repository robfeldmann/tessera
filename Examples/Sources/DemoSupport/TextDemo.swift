import Tessera
import TesseraHarness

/// `Text`: what it measures and draws today, with the archived Unicode demo's transcript.
///
/// The sheet shows every kind of content `Text` takes: ASCII, wide CJK, emoji clusters,
/// combining marks, source lines, and empty content. Each is measured in terminal cells at
/// grapheme boundaries, so `東京` is four columns and a combining mark never gains one. Below
/// them is the Unicode demo's chat transcript, a ruler that counts the 40 columns of the
/// `mobile` viewport, and a probe that `n` and `p` step through one sample at a time with the
/// size it should measure.
///
/// Wrapping, truncation, and styled runs are not here: they arrive with the styling slice, and
/// the archived demo's wrap and truncation keys come back with them. `q` quits.
final class TextDemo: Demo {
  /// One probe sample and the size it measures.
  private struct Sample {
    var name: String
    var text: String
    var measures: String
  }

  static let name = "text"
  static let minimum = TerminalSize(columns: 40, rows: 20)
  static let viewports: [Viewport] = [.desktop, .mobile]
  static let fixtures: [DemoFixture<TextDemo>] = []

  private static let samples = [
    Sample(name: "ascii", text: "Hello", measures: "5x1"),
    Sample(name: "wide", text: "東京", measures: "4x1"),
    Sample(name: "emoji", text: "👩🏽‍💻", measures: "2x1"),
    Sample(name: "combining", text: "e\u{0301}", measures: "1x1"),
    Sample(name: "halfwidth", text: "ｱｲｳ", measures: "3x1"),
    Sample(name: "lines", text: "release\nnotes", measures: "7x2"),
  ]

  private static let ruler = String(
    repeating: "0123456789", count: 4)

  private var sampleIndex = 0
  private var quitRequested = false

  var isFinished: Bool {
    quitRequested
  }

  private var sample: Sample {
    Self.samples[sampleIndex]
  }

  var body: some View {
    VStack(spacing: 0) {
      Text("Text")
      Divider()
      row("ascii", "Hello, Tessera")
      row("wide", "東京 中文 한글")
      row("emoji", "👩🏽‍💻 🧑🏿‍🚀 🇯🇵")
      row("marks", "Ti\u{0065}\u{0302}\u{0301}ng Vi\u{0065}\u{0302}\u{0323}t")
      row("lines", "first source line\nsecond source line")
      row("empty", "")
      Divider()
      Text("Ari 👩🏽‍💻: I’m building a diff tool")
      Text("Chen 陈: 我在做终端布局探针")
      Text("Minh: Ti\u{0065}\u{0302}\u{0301}ng Vi\u{0065}\u{0302}\u{0323}t — cảm ơn!")
      Text("Bo 🧑🏿‍🚀: https://tessera.dev/labs")
      Divider()
      Text(sample.text).frame(height: 2)
      Text("\(sample.name): measures \(sample.measures)")
      Text(Self.ruler)
      Text("n next   p previous   q quit")
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
    case .character("n"): sampleIndex = (sampleIndex + 1) % Self.samples.count
    case .character("p"):
      sampleIndex = (sampleIndex + Self.samples.count - 1) % Self.samples.count
    default: break
    }
  }

  /// A label in an eight-column gutter and the content beside it, top-aligned.
  private func row(_ label: String, _ content: String) -> some View {
    HStack(spacing: 1) {
      Text(label).frame(width: 8)
      Text(content)
    }
  }
}
