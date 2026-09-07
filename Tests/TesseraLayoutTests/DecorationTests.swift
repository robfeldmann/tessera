import InlineSnapshotTesting
import TesseraCore
import TesseraLayout
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
