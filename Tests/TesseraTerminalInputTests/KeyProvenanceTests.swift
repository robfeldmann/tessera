import TesseraTerminalInput
import Testing

private enum TestError: Error { case missingKey }

private func key(from events: [InputEvent]) throws -> Key {
  guard let event = events.first, case .key(let value) = event else {
    throw TestError.missingKey
  }
  return value
}

private func parse(_ text: String) -> [InputEvent] {
  var parser = InputParser()
  return parser.feed(contentsOf: Array(text.utf8))
}

@Test
func `key provenance distinguishes legacy press-only and explicit Kitty events`() throws {
  let legacy = try key(from: [InputParser.parse(0x0D)].compactMap(\.self))
  #expect(legacy.source == .legacy)

  let kittyPressOnly = try key(from: parse("\u{1B}[13u"))
  #expect(kittyPressOnly.source == .kittyPressOnly)

  let kittyPress = try key(from: parse("\u{1B}[13;1:1u"))
  #expect(kittyPress.source == .kitty)
  #expect(kittyPress.kind == .press)

  let kittyRelease = try key(from: parse("\u{1B}[13;1:3u"))
  #expect(kittyRelease.source == .kitty)
  #expect(kittyRelease.kind == .release)
}
@Test
func `associated text colons do not imply phased Kitty events`() throws {
  let value = try key(from: parse("\u{1B}[107;1;97:98u"))
  #expect(
    value
      == Key(
        code: .character("k"),
        associatedText: "ab",
        source: .kittyPressOnly
      )
  )
}
