import Tessera
import TesseraHarness

/// Stacks of natural-height content: the demo whose root has a height of its own, so
/// `size mobile` has one to use.
///
/// Typed characters appear after `Name:`, `Backspace` removes one, and the last line shows the
/// width the demo was last told it has.
final class Stack: Demo {
  static let name = "stack"
  static let minimum = TerminalSize(columns: 20, rows: 6)
  static let viewports: [Viewport] = [.desktop, .mobile]
  static let fixtures: [DemoFixture<Stack>] = []

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

  init() {}

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
