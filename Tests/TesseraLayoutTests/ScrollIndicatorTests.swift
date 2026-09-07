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
  root: @escaping () -> Root
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

private func rowText(_ buffer: Buffer, row: Int = 0) -> String {
  (0..<buffer.size.columns).map { column in
    switch buffer[row, column].content {
    case .blank:
      " "
    case .grapheme(let grapheme):
      grapheme
    case .continuation, .raw:
      "?"
    }
  }.joined()
}

private func columnText(_ buffer: Buffer, column: Int = 0) -> String {
  (0..<buffer.size.rows).map { row in
    switch buffer[row, column].content {
    case .blank:
      " "
    case .grapheme(let grapheme):
      grapheme
    case .continuation, .raw:
      "?"
    }
  }.joined()
}

@Test
func `scroll indicator places proportional thumbs at the start middle and end`() {
  let expected = [
    (offset: 0, glyphs: "━━━─────────"),
    (offset: 18, glyphs: "────━━━─────"),
    (offset: 36, glyphs: "─────────━━━"),
  ]

  for fixture in expected {
    let buffer = render(size: TerminalSize(columns: 12, rows: 1)) {
      ScrollIndicator(
        axis: .horizontal,
        contentExtent: 48,
        viewportExtent: 12,
        effectiveOffset: fixture.offset
      )
    }
    #expect(rowText(buffer) == fixture.glyphs)
  }

  let vertical = render(size: TerminalSize(columns: 1, rows: 10)) {
    ScrollIndicator(
      axis: .vertical,
      contentExtent: 40,
      viewportExtent: 10,
      effectiveOffset: 15
    )
  }
  #expect(columnText(vertical) == "││││┃┃││││")
}

@Test
func `scroll indicator preserves one cell and zero geometry`() {
  let oneCell = render(size: TerminalSize(columns: 1, rows: 1)) {
    ScrollIndicator(
      axis: .vertical,
      contentExtent: 100,
      viewportExtent: 10,
      effectiveOffset: 90
    )
  }
  #expect(columnText(oneCell) == "┃")

  var state: Void = ()
  let indicator = ScrollIndicator(
    axis: .horizontal,
    contentExtent: 100,
    viewportExtent: 10,
    effectiveOffset: 90
  )
  #expect(
    indicator.sizeThatFits(
      ProposedSize(width: 0, height: 1),
      state: &state,
      environment: EnvironmentValues()
    ) == TerminalSize(columns: 0, rows: 1)
  )
  #expect(
    indicator.sizeThatFits(
      ProposedSize(width: 10, height: 0),
      state: &state,
      environment: EnvironmentValues()
    ) == TerminalSize(columns: 10, rows: 0)
  )
}

@Test
func `scroll indicator normalizes malformed metrics before drawing`() {
  let negativeMetrics = render(size: TerminalSize(columns: 1, rows: 4)) {
    ScrollIndicator(
      axis: .vertical,
      contentExtent: -10,
      viewportExtent: -4,
      effectiveOffset: -9
    )
  }
  #expect(columnText(negativeMetrics) == "┃│││")

  let oversizedViewport = render(size: TerminalSize(columns: 6, rows: 1)) {
    ScrollIndicator(
      axis: .horizontal,
      contentExtent: 6,
      viewportExtent: 99,
      effectiveOffset: Int.max
    )
  }
  #expect(rowText(oversizedViewport) == "━━━━━━")

  let oversizedOffset = render(size: TerminalSize(columns: 10, rows: 1)) {
    ScrollIndicator(
      axis: .horizontal,
      contentExtent: 100,
      viewportExtent: 10,
      effectiveOffset: 999
    )
  }
  #expect(rowText(oversizedOffset) == "─────────━")
}

@Test
func `scroll indicator uses overflow safe arithmetic for extreme metrics`() {
  let nearCompleteViewport = render(size: TerminalSize(columns: 10, rows: 1)) {
    ScrollIndicator(
      axis: .horizontal,
      contentExtent: Int.max,
      viewportExtent: Int.max - 1,
      effectiveOffset: Int.max
    )
  }
  #expect(rowText(nearCompleteViewport) == "─━━━━━━━━━")

  let tinyViewportAtEnd = render(size: TerminalSize(columns: 10, rows: 1)) {
    ScrollIndicator(
      axis: .horizontal,
      contentExtent: Int.max,
      viewportExtent: 1,
      effectiveOffset: Int.max
    )
  }
  #expect(rowText(tinyViewportAtEnd) == "─────────━")
}

@Test
func `scroll indicator renders every weight and track glyph variant`() {
  for (weight, verticalGlyph, horizontalGlyph) in [
    (ScrollIndicatorWeight.line, "┃", "━"),
    (ScrollIndicatorWeight.mid, "▐", "▄"),
    (ScrollIndicatorWeight.block, "█", "■"),
  ] {
    var environment = EnvironmentValues()
    environment.scrollIndicatorWeight = weight

    let vertical = render(
      size: TerminalSize(columns: 1, rows: 1), environment: environment
    ) {
      ScrollIndicator(
        axis: .vertical, contentExtent: 10, viewportExtent: 1, effectiveOffset: 0)
    }
    let horizontal = render(
      size: TerminalSize(columns: 1, rows: 1), environment: environment
    ) {
      ScrollIndicator(
        axis: .horizontal, contentExtent: 10, viewportExtent: 1, effectiveOffset: 0)
    }
    #expect(columnText(vertical) == verticalGlyph)
    #expect(rowText(horizontal) == horizontalGlyph)
  }

  for (track, verticalGlyph, horizontalGlyph) in [
    (ScrollIndicatorTrack.solid, "│", "─"),
    (ScrollIndicatorTrack.dashed, "╎", "╌"),
    (ScrollIndicatorTrack.none, " ", " "),
  ] {
    var environment = EnvironmentValues()
    environment.scrollIndicatorTrack = track

    let vertical = render(
      size: TerminalSize(columns: 1, rows: 3), environment: environment
    ) {
      ScrollIndicator(
        axis: .vertical, contentExtent: 2, viewportExtent: 1, effectiveOffset: 0)
    }
    let horizontal = render(
      size: TerminalSize(columns: 3, rows: 1), environment: environment
    ) {
      ScrollIndicator(
        axis: .horizontal, contentExtent: 2, viewportExtent: 1, effectiveOffset: 0)
    }
    #expect(columnText(vertical) == "┃\(verticalGlyph)\(verticalGlyph)")
    #expect(rowText(horizontal) == "━\(horizontalGlyph)\(horizontalGlyph)")
  }
}

@Test
func `scroll indicator applies complete secondary and accent semantic styles`() {
  var environment = EnvironmentValues()
  let secondary = Style(foreground: .indexed(3)).italic()
  let accent = Style(foreground: .indexed(6)).bold()
  environment.semanticStyles = SemanticStyles(
    primary: Style(),
    secondary: secondary,
    accent: accent,
    disabled: Style(),
    destructive: Style()
  )

  let buffer = render(size: TerminalSize(columns: 3, rows: 1), environment: environment) {
    ScrollIndicator(
      axis: .horizontal, contentExtent: 2, viewportExtent: 1, effectiveOffset: 0)
  }

  assertInlineSnapshot(of: buffer, as: .bufferState) {
    """
    ━{fg=indexed(6),bold} ─{fg=indexed(3),italic} ─{fg=indexed(3),italic}
    """
  }
}
