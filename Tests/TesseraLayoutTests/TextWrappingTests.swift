import InlineSnapshotTesting
import TesseraCore
import TesseraTerminalBuffer
import TesseraTerminalCore
import TesseraTestSupport
import Testing

@Suite("TextWrappingTests")
struct TextWrappingTests {
  @Test(arguments: [
    WrapFixture(
      wrapping: .none,
      expectedSize: TerminalSize(columns: 14, rows: 1),
      expectedRows: ["Ship one thing"]
    ),
    WrapFixture(
      wrapping: .word,
      expectedSize: TerminalSize(columns: 8, rows: 2),
      expectedRows: ["Ship one", "thing"]
    ),
    WrapFixture(
      wrapping: .character,
      expectedSize: TerminalSize(columns: 8, rows: 2),
      expectedRows: ["Ship one", " thing"]
    ),
  ])
  func `finite proposals select the requested wrapping policy`(_ fixture: WrapFixture) {
    let text = Text("Ship one thing").wrapped(fixture.wrapping)
    let size = measured(text, width: 8)

    #expect(size == fixture.expectedSize)
    #expect(visibleRows(in: render(text, in: size)) == fixture.expectedRows)
  }

  @Test
  func `display width uses CJK emoji ZWJ and combining grapheme boundaries`() {
    let natural = Text("東京 👩🏽‍💻 e\u{301}")
    #expect(measured(natural) == TerminalSize(columns: 9, rows: 1))
    let naturalBuffer = render(natural, in: TerminalSize(columns: 9, rows: 1))
    assertInlineSnapshot(of: naturalBuffer, as: .bufferState) {
      """
      東 ◌ 京 ◌   👩🏽‍💻 ◌   é
      """
    }

    let source = "界👩🏽‍💻e\u{301}"
    let character = Text(source).wrapped(.character)
    let word = Text(source).wrapped(.word)

    #expect(measured(character, width: 2) == TerminalSize(columns: 2, rows: 3))
    #expect(measured(word, width: 2) == TerminalSize(columns: 2, rows: 3))
    let characterBuffer = render(character, in: TerminalSize(columns: 2, rows: 3))
    assertInlineSnapshot(of: characterBuffer, as: .bufferState) {
      """
      界 ◌
      👩🏽‍💻 ◌
      é ·
      """
    }
    let wordBuffer = render(word, in: TerminalSize(columns: 2, rows: 3))
    assertInlineSnapshot(of: wordBuffer, as: .bufferState) {
      """
      界 ◌
      👩🏽‍💻 ◌
      é ·
      """
    }
  }

  @Test
  func `word wrapping falls back to character boundaries for long words`() {
    let text = Text("abcdefgh ij").wrapped(.word)
    let size = measured(text, width: 5)

    #expect(size == TerminalSize(columns: 5, rows: 3))
    let buffer = render(text, in: size)
    assertInlineSnapshot(of: buffer, as: .bufferState) {
      """
      a b c d e
      f g h · ·
      i j · · ·
      """
    }
  }

  @Test
  func `source newlines preserve empty rows and normalize CRLF`() {
    let text = Text("a\r\nb\n")

    #expect(text.content == "a\nb\n")
    #expect(measured(text) == TerminalSize(columns: 1, rows: 3))
    let buffer = render(text, in: TerminalSize(columns: 1, rows: 3))
    assertInlineSnapshot(of: buffer, as: .bufferState) {
      """
      a
      b
      ·
      """
    }
  }

  @Test
  func `truncation modes keep whole grapheme clusters`() {
    let source = Text("abcdef")
    let expected: [(TextTruncation, String)] = [
      (.clip, "abcd"),
      (.tail, "abc…"),
      (.head, "…def"),
      (.middle, "ab…f"),
    ]

    for (mode, row) in expected {
      let text = source.truncation(mode)
      #expect(
        visibleRows(in: render(text, in: TerminalSize(columns: 4, rows: 1))) == [row])
    }

    #expect(
      measured(source.truncation(.clip), width: 4) == TerminalSize(columns: 6, rows: 1))
    #expect(
      measured(source.truncation(.tail), width: 4) == TerminalSize(columns: 4, rows: 1))

    let emoji = Text("A👩🏽‍💻BC").truncation(.tail)
    let buffer = render(emoji, in: TerminalSize(columns: 4, rows: 1))
    assertInlineSnapshot(of: buffer, as: .bufferState) {
      """
      A 👩🏽‍💻 ◌ …
      """
    }
  }

  @Test
  func `ascii truncation mark preserves one cell geometry`() {
    var environment = EnvironmentValues()
    environment.truncationMark = "~"
    let buffer = render(
      Text("abcdef").truncation(.tail),
      in: TerminalSize(columns: 4, rows: 1),
      environment: environment
    )

    assertInlineSnapshot(of: buffer, as: .bufferState) {
      """
      a b c ~
      """
    }

    environment.truncationMark = "wide"
    #expect(environment.truncationMark == "…")
  }

  @Test
  func `fluent configuration is immutable equatable and resolves inherited style`() {
    let explicitStyle = Style().bold()
    let original = Text("Hello", style: explicitStyle)
    let configured = original.wrapped(.word).truncation(.tail)

    #expect(original.wrapping == .none)
    #expect(original.truncationMode == .clip)
    #expect(configured.wrapping == .word)
    #expect(configured.truncationMode == .tail)
    #expect(original == Text("Hello", style: explicitStyle))
    #expect(original != configured)

    var environment = EnvironmentValues()
    environment.defaultStyle = Style().foreground(.indexed(196))
    let buffer = render(
      Text("X", style: explicitStyle), in: TerminalSize(columns: 1, rows: 1),
      environment: environment)
    assertInlineSnapshot(of: buffer, as: .bufferState) {
      """
      X{fg=indexed(196),bold}
      """
    }
  }

  @Test(arguments: [
    FiniteFixture(content: "ASCII words wrap predictably", wrapping: .word, width: 6),
    FiniteFixture(content: "東京の文字列", wrapping: .word, width: 4),
    FiniteFixture(content: "👩🏽‍💻👨🏿‍🚀", wrapping: .character, width: 2),
    FiniteFixture(content: "e\u{301}e\u{301}e\u{301}", wrapping: .character, width: 2),
    FiniteFixture(
      content: "supercalifragilisticexpialidocious", wrapping: .word, width: 7),
  ])
  func `finite wrapping measurement and rendering remain in bounds`(
    _ fixture: FiniteFixture
  ) {
    let text = Text(fixture.content).wrapped(fixture.wrapping)
    let size = measured(text, width: fixture.width)
    let buffer = render(text, in: size)

    #expect(size.columns <= fixture.width)
    #expect(buffer.size == size)

    for row in 0..<size.rows {
      for column in 0..<size.columns {
        guard let cell = buffer.cell(row: row, column: column) else {
          Issue.record("A measured buffer cell must exist.")
          continue
        }

        if case .grapheme = cell.content {
          #expect(cell.width > 0)
          #expect(column + cell.width <= size.columns)
        }
        if case .continuation = cell.content {
          #expect(column > 0)
          #expect(buffer.cell(row: row, column: column - 1)?.width == 2)
        }
      }
    }
  }

  @Test
  func `seeded random wrapping and truncation agree with measured bounds`() {
    var generator = SeededGenerator(seed: 0x5EED_CAFE_F00D_BAAD)

    for iteration in 0..<256 {
      let source = randomText(using: &generator, iteration: iteration)
      let proposedWidth = 2 + Int(generator.next() % 11)

      for wrapping in [TextWrapping.character, .word] {
        let text = Text(source, style: propertyTestStyle).wrapped(wrapping)
        let size = measured(text, width: proposedWidth)
        let rendered = guardedRender(text, in: size)

        #expect(size.columns <= proposedWidth)
        #expect(writtenExtent(in: rendered) == size)
        #expect(
          significantRenderedGraphemes(in: rendered)
            == significantSourceGraphemes(in: source)
        )
        expectGuardUnchanged(rendered)
      }

      let truncationSource = source.filter { !$0.isWhitespace }
      for truncation in [
        TextTruncation.clip, .head, .middle, .tail,
      ] {
        let text = Text(truncationSource, style: propertyTestStyle)
          .truncation(truncation)
        let size = measured(text, width: proposedWidth)
        let rendered = guardedRender(text, in: size)

        if truncation != .clip {
          #expect(size.columns <= proposedWidth)
        }
        #expect(writtenExtent(in: rendered).columns <= size.columns)
        #expect(writtenExtent(in: rendered).rows <= size.rows)
        #expect(
          renderedString(in: rendered)
            == expectedTruncation(
              of: truncationSource,
              mode: truncation,
              width: size.columns
            )
        )
        expectGuardUnchanged(rendered)
      }
    }
  }

}

struct WrapFixture: Sendable {
  let wrapping: TextWrapping
  let expectedSize: TerminalSize
  let expectedRows: [String]
}

struct FiniteFixture: Sendable {
  let content: String
  let wrapping: TextWrapping
  let width: Int
}

private let propertyTestStyle = Style().foreground(.indexed(1))

private struct GuardedRender {
  let buffer: Buffer
  let region: Rect
  let sentinel: Cell
}

private struct SeededGenerator: RandomNumberGenerator {
  private var state: UInt64

  init(seed: UInt64) {
    state = seed
  }

  mutating func next() -> UInt64 {
    state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
    return state
  }
}

private func randomText(
  using generator: inout SeededGenerator,
  iteration: Int
) -> String {
  let pool = [
    "a", "Z", "0", " ", "  ", "-", "東京", "界", "👨🏿‍🚀", "e\u{301}", "o\u{308}",
    "\u{301}",
  ]
  var segments = [
    "A",
    "界",
    "👩🏽‍💻",
    "e\u{301}",
    "\u{301}",
    String(repeating: "w", count: 12 + iteration % 17),
  ]
  for _ in 0..<(8 + iteration % 24) {
    segments.append(pool[Int(generator.next() % UInt64(pool.count))])
  }
  segments.shuffle(using: &generator)
  return segments.joined()
}

private func guardedRender(_ text: Text, in size: TerminalSize) -> GuardedRender {
  let inset = 2
  let sentinel = Cell(character: "#", style: Style().foreground(.indexed(2)))
  let fullSize = TerminalSize(
    columns: size.columns + inset * 2,
    rows: size.rows + inset * 2
  )
  let regionRect = Rect(
    origin: TerminalPosition(column: inset, row: inset),
    size: size
  )
  var buffer = Buffer(size: fullSize, fill: sentinel)
  var cursorPosition: TerminalPosition?

  withUnsafeMutablePointer(to: &buffer) { bufferStorage in
    withUnsafeMutablePointer(to: &cursorPosition) { cursorStorage in
      let frame = Frame(buffer: bufferStorage, cursorPosition: cursorStorage)
      frame.withRenderRegion(in: regionRect) { region in
        region.fill(.blank, in: region.bounds)
        var state: Void = ()
        text.render(
          in: &region,
          state: &state,
          environment: EnvironmentValues()
        )
      }
    }
  }

  return GuardedRender(buffer: buffer, region: regionRect, sentinel: sentinel)
}

private func expectGuardUnchanged(_ rendered: GuardedRender) {
  for row in 0..<rendered.buffer.size.rows {
    for column in 0..<rendered.buffer.size.columns {
      let isInside =
        row >= rendered.region.origin.row
        && row < rendered.region.maxRow
        && column >= rendered.region.origin.column
        && column < rendered.region.maxColumn
      if !isInside {
        #expect(rendered.buffer[row, column] == rendered.sentinel)
      }
    }
  }
}

private func writtenExtent(in rendered: GuardedRender) -> TerminalSize {
  var columns = 0
  var rows = 0

  for row in 0..<rendered.region.size.rows {
    for column in 0..<rendered.region.size.columns {
      let cell = rendered.buffer[
        rendered.region.origin.row + row,
        rendered.region.origin.column + column
      ]
      if cell.style.foreground == propertyTestStyle.foreground {
        columns = max(columns, column + 1)
        rows = max(rows, row + 1)
      }
    }
  }

  return TerminalSize(columns: columns, rows: rows)
}

private func significantSourceGraphemes(in source: String) -> [String] {
  source.map(String.init).filter {
    isSupportedStoredGrapheme($0) && !$0.allSatisfy(\.isWhitespace)
  }
}

private func significantRenderedGraphemes(in rendered: GuardedRender) -> [String] {
  renderedGraphemes(in: rendered).filter {
    !$0.allSatisfy(\.isWhitespace)
  }
}

private func renderedString(in rendered: GuardedRender) -> String {
  renderedGraphemes(in: rendered).joined()
}

private func renderedGraphemes(in rendered: GuardedRender) -> [String] {
  var graphemes: [String] = []
  for row in 0..<rendered.region.size.rows {
    for column in 0..<rendered.region.size.columns {
      let cell = rendered.buffer[
        rendered.region.origin.row + row,
        rendered.region.origin.column + column
      ]
      if case .grapheme(let grapheme) = cell.content {
        graphemes.append(grapheme)
      }
    }
  }
  return graphemes
}

private func expectedTruncation(
  of source: String,
  mode: TextTruncation,
  width: Int
) -> String {
  let graphemes = source.map(String.init).filter(isSupportedStoredGrapheme)
  let sourceWidth = graphemes.reduce(0) { $0 + terminalCellWidth(of: $1) }
  guard sourceWidth > width else {
    return graphemes.joined()
  }
  guard width >= 1 else {
    return ""
  }

  let visibleWidth = width - 1
  switch mode {
  case .clip:
    return graphemes.joined()
  case .head:
    return "…" + suffixFitting(graphemes, within: visibleWidth).joined()
  case .middle:
    let prefixBudget = visibleWidth / 2 + visibleWidth % 2
    let prefix = prefixFitting(graphemes, within: prefixBudget)
    let prefixWidth = prefix.reduce(0) { $0 + terminalCellWidth(of: $1) }
    let suffix = suffixFitting(
      Array(graphemes.dropFirst(prefix.count)),
      within: visibleWidth - prefixWidth
    )
    return prefix.joined() + "…" + suffix.joined()
  case .tail:
    return prefixFitting(graphemes, within: visibleWidth).joined() + "…"
  }
}

private func prefixFitting(_ graphemes: [String], within budget: Int) -> [String] {
  var result: [String] = []
  var width = 0
  for grapheme in graphemes {
    let graphemeWidth = terminalCellWidth(of: grapheme)
    guard graphemeWidth <= budget - width else {
      break
    }
    result.append(grapheme)
    width += graphemeWidth
  }
  return result
}

private func suffixFitting(_ graphemes: [String], within budget: Int) -> [String] {
  var result: [String] = []
  var width = 0
  for grapheme in graphemes.reversed() {
    let graphemeWidth = terminalCellWidth(of: grapheme)
    guard graphemeWidth <= budget - width else {
      break
    }
    result.append(grapheme)
    width += graphemeWidth
  }
  return result.reversed()
}

private func measured(_ text: Text, width: Int? = nil) -> TerminalSize {
  var state: Void = ()
  return text.sizeThatFits(
    ProposedSize(width: width, height: nil),
    state: &state,
    environment: EnvironmentValues()
  )
}

private func render(
  _ text: Text,
  in size: TerminalSize,
  environment: EnvironmentValues = EnvironmentValues()
) -> Buffer {
  withTestFrame(size: size) { frame in
    frame.withRenderRegion(
      in: Rect(origin: TerminalPosition(column: 0, row: 0), size: size)
    ) { region in
      var state: Void = ()
      text.render(in: &region, state: &state, environment: environment)
    }
  }
}

private func visibleRows(in buffer: Buffer) -> [String] {
  (0..<buffer.size.rows).map { row in
    var result = ""
    for column in 0..<buffer.size.columns {
      guard let cell = buffer.cell(row: row, column: column) else {
        continue
      }
      if case .grapheme(let grapheme) = cell.content {
        result.append(contentsOf: grapheme)
      }
    }
    return result
  }
}

private func withTestFrame(
  size: TerminalSize,
  _ body: (borrowing Frame) -> Void
) -> Buffer {
  var buffer = Buffer(size: size)
  var cursorPosition: TerminalPosition?
  withUnsafeMutablePointer(to: &buffer) { bufferStorage in
    withUnsafeMutablePointer(to: &cursorPosition) { cursorStorage in
      body(Frame(buffer: bufferStorage, cursorPosition: cursorStorage))
    }
  }
  return buffer
}
