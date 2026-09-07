import InlineSnapshotTesting
import TesseraCore
import TesseraLayout
import TesseraTerminalBuffer
import TesseraTerminalCore
import TesseraTestSupport
import Testing

private func render<Root: View>(
  size: TerminalSize,
  environment: EnvironmentValues = EnvironmentValues(),
  @ViewBuilder root: @escaping () -> Root
) -> Buffer {
  let graph = ViewGraph(root: root, size: size, environment: environment)
  var buffer = Buffer(size: size)
  var cursorPosition: TerminalPosition?
  withUnsafeMutablePointer(to: &buffer) { bufferStorage in
    withUnsafeMutablePointer(to: &cursorPosition) { cursorStorage in
      graph.render(into: Frame(buffer: bufferStorage, cursorPosition: cursorStorage))
    }
  }
  return buffer
}

@Test
func `nested style modifiers merge explicit attributes from their ancestors`() {
  let buffer = render(size: TerminalSize(columns: 2, rows: 1)) {
    Text("AB")
      .foreground(.indexed(14))
      .bold()
  }

  assertInlineSnapshot(of: buffer, as: .bufferState) {
    """
    A{fg=indexed(14),bold} B{fg=indexed(14),bold}
    """
  }
}

@Test
func `a child can explicitly disable an inherited bold attribute`() {
  let buffer = render(size: TerminalSize(columns: 2, rows: 1)) {
    Text("NO")
      .bold(false)
      .bold()
  }

  assertInlineSnapshot(of: buffer, as: .bufferState) {
    """
    N O
    """
  }
}

@Test
func `a style modifier affects only its own sibling subtree`() {
  let buffer = render(size: TerminalSize(columns: 2, rows: 1)) {
    HStack {
      Text("L").foreground(.indexed(14))
      Text("R")
    }
  }

  assertInlineSnapshot(of: buffer, as: .bufferState) {
    """
    L{fg=indexed(14)} R
    """
  }
}

@Test
func `a whole style merges every explicit attribute it supplies`() {
  let ancestor = Style(foreground: .indexed(1), background: .indexed(2)).bold()
  let descendant = Style(foreground: .indexed(3)).italic()
  let buffer = render(size: TerminalSize(columns: 1, rows: 1)) {
    Text("M")
      .style(descendant)
      .style(ancestor)
  }

  assertInlineSnapshot(of: buffer, as: .bufferState) {
    """
    M{fg=indexed(3),bg=indexed(2),bold,italic}
    """
  }
}

@Test
func `semantic styles provide complete token defaults and replace every custom role`() {
  let terminalDefault = EnvironmentValues().defaultStyle
  let semantic = SemanticStyles()

  #expect(semantic.primary == terminalDefault)
  #expect(semantic.secondary == terminalDefault.dim())
  #expect(semantic.accent == terminalDefault.foreground(.indexed(14)).bold())
  #expect(
    semantic.focus
      == terminalDefault
      .foreground(.indexed(0))
      .background(.indexed(3))
      .bold()
  )
  #expect(semantic.disabled == terminalDefault.dim())
  #expect(
    semantic.destructive == terminalDefault.foreground(.indexed(9)).bold().underline())

  let custom = SemanticStyles(
    primary: Style(foreground: .indexed(1)),
    secondary: Style(foreground: .indexed(2)),
    accent: Style(foreground: .indexed(3)),
    disabled: Style(foreground: .indexed(4)),
    destructive: Style(foreground: .indexed(5)),
    focus: Style(foreground: .indexed(6))
  )
  var environment = EnvironmentValues()
  environment.semanticStyles = custom

  #expect(environment.semanticStyles == custom)
  #expect(custom.primary == terminalDefault.foreground(.indexed(1)))
  #expect(custom.secondary == terminalDefault.foreground(.indexed(2)))
  #expect(custom.accent == terminalDefault.foreground(.indexed(3)))
  #expect(custom.disabled == terminalDefault.foreground(.indexed(4)))
  #expect(custom.destructive == terminalDefault.foreground(.indexed(5)))
  #expect(custom.focus == terminalDefault.foreground(.indexed(6)))
}

@Test
func `a color background fills the allocated region before descendant text`() {
  let buffer = render(size: TerminalSize(columns: 4, rows: 1)) {
    Text("INK")
      .foreground(.indexed(14))
      .frame(width: 4)
      .background(.indexed(4))
  }

  assertInlineSnapshot(of: buffer, as: .bufferState) {
    """
    I{fg=indexed(14),bg=indexed(4)} N{fg=indexed(14),bg=indexed(4)} K{fg=indexed(14),bg=indexed(4)} ·{bg=indexed(4)}
    """
  }
}

@Test
func `style modifiers preserve their child's measured size and placement`() throws {
  let size = TerminalSize(columns: 8, rows: 1)
  let plain = ViewGraph(root: { Text("Text") }, size: size)
  let styled = ViewGraph(
    root: { Text("Text").italic().foreground(.indexed(14)) }, size: size)

  plain.layoutIfNeeded()
  styled.layoutIfNeeded()

  let plainNode = plain.diagnostics.nodes[0]
  let styledNodes = styled.diagnostics.nodes
  let styledText = try #require(styledNodes.last)

  #expect(styledNodes[0].measuredSize == plainNode.measuredSize)
  #expect(styledText.measuredSize == plainNode.measuredSize)
  #expect(styledNodes[0].frame == plainNode.frame)
}

@Test
func `style modifiers record inherited environment overrides in diagnostics`() throws {
  let graph = ViewGraph(
    root: {
      Text("X")
        .bold()
        .foreground(.indexed(14))
    },
    size: TerminalSize(columns: 1, rows: 1)
  )

  graph.layoutIfNeeded()

  let text = try #require(graph.diagnostics.nodes.last)
  #expect(text.environmentOverrides.count == 2)
  #expect(
    text.environmentOverrides.allSatisfy {
      $0.contains("defaultStyle")
    })
}

@Test
func `a color background safely skips an empty allocated region`() {
  let buffer = render(size: TerminalSize(columns: 0, rows: 0)) {
    Text("X")
      .frame(width: 0, height: 0)
      .background(.indexed(4))
  }

  #expect(buffer.size == TerminalSize(columns: 0, rows: 0))
}
