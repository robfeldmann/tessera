import InlineSnapshotTesting
import TesseraCore
import TesseraLayout
import TesseraTerminalBuffer
import TesseraTerminalCore
import TesseraTerminalSnapshotSupport
import TesseraTestSupport
import Testing

private struct DecorationPaintLeaf: LeafView {
  let size: TerminalSize
  let output: String

  func sizeThatFits(
    _ proposal: ProposedSize,
    state: inout Void,
    environment: EnvironmentValues
  ) -> TerminalSize {
    size
  }

  func render(
    in region: inout RenderRegion,
    state: inout Void,
    environment: EnvironmentValues
  ) {
    region.write(output, at: TerminalPosition(column: 0, row: 0))
  }
}

private func decorationSnapshot<Root: View>(
  size: TerminalSize,
  @ViewBuilder root: @escaping () -> Root
) -> ScreenSnapshot {
  let graph = ViewGraph(root: root, size: size)
  return VirtualTerminal.snapshot(size: size) { frame in
    graph.render(into: frame)
  }
}

private func decorationGraph<Root: View>(
  size: TerminalSize,
  @ViewBuilder root: @escaping () -> Root
) -> ViewGraph {
  let graph = ViewGraph(root: root, size: size)
  graph.layoutIfNeeded()
  return graph
}

private func renderDecoration(_ graph: ViewGraph, size: TerminalSize) -> Buffer {
  var buffer = Buffer(size: size)
  var cursorPosition: TerminalPosition?
  withUnsafeMutablePointer(to: &buffer) { bufferStorage in
    withUnsafeMutablePointer(to: &cursorPosition) { cursorStorage in
      graph.render(into: Frame(buffer: bufferStorage, cursorPosition: cursorStorage))
    }
  }
  return buffer
}

private final class DecorationFocusModel {
  var focused: FocusID?

  var binding: Binding<FocusID?> {
    Binding(get: { self.focused }, set: { self.focused = $0 })
  }
}

@Test
func `border glyph families paint their rings after clipped child content`() {
  let single = decorationSnapshot(size: TerminalSize(columns: 6, rows: 3)) {
    DecorationPaintLeaf(size: TerminalSize(columns: 1, rows: 1), output: "ABCDE")
      .border(.single)
  }
  assertInlineSnapshot(of: single, as: .terminalText(trim: .none)) {
    """
    ┌────┐
    │A   │
    └────┘
    """
  }

  let rounded = decorationSnapshot(size: TerminalSize(columns: 6, rows: 3)) {
    Text("AB").border(.rounded)
  }
  assertInlineSnapshot(of: rounded, as: .terminalText(trim: .none)) {
    """
    ╭────╮
    │AB  │
    ╰────╯
    """
  }

  let double = decorationSnapshot(size: TerminalSize(columns: 6, rows: 3)) {
    Text("AB").border(.double)
  }
  assertInlineSnapshot(of: double, as: .terminalText(trim: .none)) {
    """
    ╔════╗
    ║AB  ║
    ╚════╝
    """
  }

  let heavy = decorationSnapshot(size: TerminalSize(columns: 6, rows: 3)) {
    Text("AB").border(.heavy)
  }
  assertInlineSnapshot(of: heavy, as: .terminalText(trim: .none)) {
    """
    ┏━━━━┓
    ┃AB  ┃
    ┗━━━━┛
    """
  }

  let ascii = decorationSnapshot(size: TerminalSize(columns: 6, rows: 3)) {
    Text("AB").border(.ascii)
  }
  assertInlineSnapshot(of: ascii, as: .terminalText(trim: .none)) {
    """
    +----+
    |AB  |
    +----+
    """
  }
}

@Test
func `custom border glyphs retain validated single cell values`() {
  let glyphs = BorderGlyphs(
    topLeft: "*", topRight: "*", bottomLeft: "*", bottomRight: "*", horizontal: "=",
    vertical: ":"
  )
  #expect(glyphs.horizontal == "=")
  #expect(glyphs.vertical == ":")

  let snapshot = decorationSnapshot(size: TerminalSize(columns: 6, rows: 3)) {
    Text("AB").border(.custom(glyphs))
  }
  assertInlineSnapshot(of: snapshot, as: .terminalText(trim: .none)) {
    """
    *====*
    :AB  :
    *====*
    """
  }
}

@Test
func `box applies chrome padding and title truncation in its border`() {
  let snapshot = decorationSnapshot(size: TerminalSize(columns: 16, rows: 5)) {
    Box(title: "Long title which cannot fit") {
      Text("X").frame(width: 12, height: 1)
    }
  }
  assertInlineSnapshot(of: snapshot, as: .terminalText(trim: .none)) {
    """
    ╭─ Long titl… ─╮
    │              │
    │ X            │
    │              │
    ╰──────────────╯
    """
  }
}

@Test
func `overlay and background use primary measurement clipping and source paint order`() {
  let overlay = decorationSnapshot(size: TerminalSize(columns: 5, rows: 1)) {
    Text("ABCDE").overlay(alignment: .topTrailing) {
      Text("XX")
    }
  }
  assertInlineSnapshot(of: overlay, as: .terminalText(trim: .none)) {
    """
    ABCXX
    """
  }

  let background = decorationSnapshot(size: TerminalSize(columns: 5, rows: 1)) {
    Text("A").frame(width: 5, height: 1).background {
      Text("xxxxx")
    }
  }
  assertInlineSnapshot(of: background, as: .terminalText(trim: .none)) {
    """
    Axxxx
    """
  }

  let graph = decorationGraph(size: TerminalSize(columns: 20, rows: 4)) {
    Text("BASE").overlay {
      Text("an oversized decoration")
    }
  }
  #expect(graph.diagnostics.nodes.first?.measuredSize == TerminalSize(columns: 4, rows: 1))
  #expect(
    graph.diagnostics.nodes.first?.frame == Rect(column: 0, row: 0, columns: 20, rows: 4))
}

@Test
func `divider styles render through the inherited stack orientation`() {
  let horizontal = decorationSnapshot(size: TerminalSize(columns: 5, rows: 5)) {
    VStack {
      Divider(style: .light)
      Divider(style: .heavy)
      Divider(style: .double)
      Divider(style: .dashed)
      Divider(style: .ascii)
    }
  }
  assertInlineSnapshot(of: horizontal, as: .terminalText(trim: .none)) {
    """
    ─────
    ━━━━━
    ═════
    ╌╌╌╌╌
    -----
    """
  }

  let vertical = decorationSnapshot(size: TerminalSize(columns: 1, rows: 4)) {
    HStack {
      Divider(style: .dashed)
    }
  }
  assertInlineSnapshot(of: vertical, as: .terminalText(trim: .none)) {
    """
    ╎
    ╎
    ╎
    ╎
    """
  }

  let inherited = decorationSnapshot(size: TerminalSize(columns: 5, rows: 1)) {
    VStack {
      Divider()
    }
    .dividerStyle(.double)
  }
  assertInlineSnapshot(of: inherited, as: .terminalText(trim: .none)) {
    """
    ═════
    """
  }
}

@Test(arguments: [
  TerminalSize(columns: 0, rows: 0),
  TerminalSize(columns: 1, rows: 1),
  TerminalSize(columns: 1, rows: 4),
  TerminalSize(columns: 4, rows: 1),
])
func `border clamps degenerate rectangles`(size: TerminalSize) {
  let graph = decorationGraph(size: size) {
    DecorationPaintLeaf(size: TerminalSize(columns: 20, rows: 20), output: "overflow")
      .border(.rounded)
  }
  #expect(
    graph.diagnostics.nodes.first?.frame
      == Rect(origin: TerminalPosition(column: 0, row: 0), size: size))
  #expect(graph.diagnostics.nodes.first?.measuredSize == size)
}

@Test
func `degenerate border snapshots retain only surviving chrome`() {
  let oneByOne = decorationSnapshot(size: TerminalSize(columns: 1, rows: 1)) {
    Text("overflow").border(.rounded)
  }
  assertInlineSnapshot(of: oneByOne, as: .terminalText(trim: .none)) {
    """
    ╭
    """
  }

  let oneByMany = decorationSnapshot(size: TerminalSize(columns: 1, rows: 4)) {
    Text("overflow").border(.rounded)
  }
  assertInlineSnapshot(of: oneByMany, as: .terminalText(trim: .none)) {
    """
    ╭
    │
    │
    ╰
    """
  }

  let manyByOne = decorationSnapshot(size: TerminalSize(columns: 4, rows: 1)) {
    Text("overflow").border(.rounded)
  }
  assertInlineSnapshot(of: manyByOne, as: .terminalText(trim: .none)) {
    """
    ╭──╮
    """
  }
}

@Test
func `focused box preserves double chrome and leaves its content style unchanged`() {
  let id = FocusID("box")
  let model = DecorationFocusModel()
  let size = TerminalSize(columns: 12, rows: 5)
  let graph = ViewGraph(
    root: {
      Box(title: "Status", border: .double) {
        DecorationPaintLeaf(size: TerminalSize(columns: 1, rows: 1), output: "X")
          .frame(width: 8, height: 1)
          .focusable(id)
          .focused(model.binding, equals: id)
      }
    },
    size: size
  )

  graph.layoutIfNeeded()
  let framesBeforeFocus = graph.diagnostics.nodes.map(\.frame)
  let measurementsBeforeFocus = graph.diagnostics.nodes.map(\.measuredSize)
  graph.focus.focus(id)
  let snapshot = renderDecoration(graph, size: size)
  let focusStyle = EnvironmentValues().semanticStyles.focus

  #expect(snapshot[0, 0].content == .grapheme("╔"))
  #expect(snapshot[0, 0].style.foreground == focusStyle.background)
  #expect(snapshot[0, 0].style.background == .default)
  #expect(snapshot[0, 3].content == .grapheme("S"))
  #expect(snapshot[0, 3].style.foreground == .default)
  #expect(snapshot[0, 3].style.background == .default)
  #expect(snapshot[1, 0].style.attributes == focusStyle.attributes)
  #expect(snapshot[2, 2].style.background != focusStyle.background)

  #expect(graph.focus.focused == id)
  #expect(graph.diagnostics.nodes.map(\.frame) == framesBeforeFocus)
  #expect(graph.diagnostics.nodes.map(\.measuredSize) == measurementsBeforeFocus)
  assertInlineSnapshot(of: snapshot, as: .bufferState) {
    """
    ╔{fg=indexed(3),bold} ═{fg=indexed(3),bold}   S t a t u s   ═{fg=indexed(3),bold} ╗{fg=indexed(3),bold}
    ║{fg=indexed(3),bold} · · · · · · · · · · ║{fg=indexed(3),bold}
    ║{fg=indexed(3),bold} · X · · · · · · · · ║{fg=indexed(3),bold}
    ║{fg=indexed(3),bold} · · · · · · · · · · ║{fg=indexed(3),bold}
    ╚{fg=indexed(3),bold} ═{fg=indexed(3),bold} ═{fg=indexed(3),bold} ═{fg=indexed(3),bold} ═{fg=indexed(3),bold} ═{fg=indexed(3),bold} ═{fg=indexed(3),bold} ═{fg=indexed(3),bold} ═{fg=indexed(3),bold} ═{fg=indexed(3),bold} ═{fg=indexed(3),bold} ╝{fg=indexed(3),bold}
    """
  }
}

@Test(arguments: [
  TerminalSize(columns: 0, rows: 0),
  TerminalSize(columns: 1, rows: 1),
  TerminalSize(columns: 1, rows: 4),
  TerminalSize(columns: 4, rows: 1),
])
func `focused box clamps delegated chrome to its clipped degenerate bounds`(
  size: TerminalSize
) {
  let id = FocusID("box")
  let model = DecorationFocusModel()
  model.focused = id
  let graph = ViewGraph(
    root: {
      Box(title: "Status", border: .double) {
        DecorationPaintLeaf(size: TerminalSize(columns: 20, rows: 20), output: "overflow")
          .focusable(id)
          .focused(model.binding, equals: id)
      }
    },
    size: size
  )

  graph.layoutIfNeeded()
  #expect(
    graph.diagnostics.nodes.first?.frame
      == Rect(origin: TerminalPosition(column: 0, row: 0), size: size))
  guard size.columns > 0, size.rows > 0 else {
    return
  }
  let snapshot = renderDecoration(graph, size: size)

  #expect(snapshot[0, 0].content == .grapheme("╔"))
  if size.columns == 1 {
    #expect(snapshot[size.rows - 1, 0].content == .grapheme(size.rows == 1 ? "╔" : "╚"))
  }
  if size.rows == 1, size.columns > 1 {
    #expect(snapshot[0, size.columns - 1].content == .grapheme("╗"))
  }
}
