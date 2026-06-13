import TesseraTerminalANSI
import Testing

@testable import TesseraTerminalBuffer

@Test
func `cell width classifies displayable content`() {
  #expect(Cell(character: "A").width == 1)
  #expect(Cell(content: .grapheme("你")).width == 2)
  #expect(Cell(content: .grapheme("🙂")).width == 2)
  #expect(Cell(content: .grapheme("👨‍👩‍👧")).width == 2)
  #expect(Cell(content: .grapheme("🇺🇸")).width == 2)
  #expect(Cell(content: .grapheme("👍🏽")).width == 2)
  #expect(Cell(content: .grapheme("e\u{0301}")).width == 1)
  #expect(Cell(content: .grapheme("é")).width == 1)
}

@Test
func `cell width handles non text content`() {
  #expect(Cell.blank.width == 1)
  #expect(Cell(content: .continuation).width == 0)
  #expect(Cell(content: .raw(RawTerminalPayload(bytes: [0x1B]))).width == 0)
  let rawCell = Cell(content: .raw(RawTerminalPayload(bytes: [0x1B], declaredWidth: 2)))
  #expect(rawCell.width == 2)
}

@Test
func `terminal width helper preserves halfwidth katakana sound marks`() {
  #expect(terminalCellWidth(of: "\u{FF9E}") == 1)
  #expect(terminalCellWidth(of: "\u{FF9F}") == 1)
}

@Test
func `terminal width helper rejects isolated zero width and controls`() {
  #expect(terminalCellWidth(of: "\u{0301}") == 0)
  #expect(terminalCellWidth(of: "\u{200D}") == 0)
  #expect(isPrintableStoredGrapheme("\u{0301}") == false)
  #expect(isPrintableStoredGrapheme("\u{200D}") == false)

  #expect(isControlGrapheme("\u{0000}"))
  #expect(isControlGrapheme("\t"))
  #expect(isControlGrapheme("\u{0085}"))
  #expect(isPrintableStoredGrapheme("\t") == false)
}
