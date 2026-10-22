import Testing
import Tessera

@testable import LiveSocketKit

@Test
func `decode maps each operation name to its request`() {
  #expect(ControlProtocol.decode(#"{"op":"text"}"#) == .success(.text))
  #expect(ControlProtocol.decode(#"{"op":"tree"}"#) == .success(.tree))
  #expect(ControlProtocol.decode(#"{"op":"quit"}"#) == .success(.quit))
  #expect(
    ControlProtocol.decode(#"{"op":"key","key":"Tab"}"#)
      == .success(.key(Key(code: .tab), name: "Tab"))
  )
}

@Test
func `decode names the valid operations when the op is unknown or missing`() {
  let unknown = ControlProtocol.decode(#"{"op":"grid"}"#)
  #expect(unknown == .failure(ControlError(#"unknown op "grid" (ops: key, quit, text, tree)"#)))

  let missing = ControlProtocol.decode(#"{"key":"Tab"}"#)
  #expect(missing == .failure(ControlError(#"missing "op" (ops: key, quit, text, tree)"#)))
}

@Test
func `decode rejects text that is not a JSON object`() {
  #expect(ControlProtocol.decode("text") == .failure(ControlError("request is not valid JSON")))
  #expect(
    ControlProtocol.decode("[1]")
      == .failure(ControlError(#"request must be a JSON object with an "op" member"#))
  )
}

@Test
func `key names accept modifiers named keys function keys and the plus key`() {
  #expect(KeyNames.parse("Shift+Tab") == .success(Key(code: .tab, modifiers: .shift)))
  #expect(
    KeyNames.parse("Ctrl+c") == .success(Key(code: .character("c"), modifiers: .control))
  )
  #expect(KeyNames.parse("meta+k") == .success(Key(code: .character("k"), modifiers: .meta)))
  #expect(KeyNames.parse("ArrowLeft") == .success(Key(code: .left)))
  #expect(KeyNames.parse("F5") == .success(Key(code: .function(5))))
  #expect(KeyNames.parse("+") == .success(Key(code: .character("+"))))
  #expect(
    KeyNames.parse("Ctrl++") == .success(Key(code: .character("+"), modifiers: .control))
  )
}

@Test
func `key names list the accepted vocabulary when a name is unknown`() throws {
  let result = KeyNames.parse("Hyper")
  guard case .failure(let error) = result else {
    Issue.record("expected a failure")
    return
  }
  #expect(error.message.hasPrefix(#"unknown key "Hyper" (names: ArrowDown"#))
  #expect(error.message.contains("Shift+"))
}

@Test
func `describe returns the canonical name for a key`() {
  #expect(KeyNames.describe(Key(code: .tab, modifiers: .shift)) == "Shift+Tab")
  #expect(KeyNames.describe(Key(code: .character(" "))) == "Space")
  #expect(KeyNames.describe(Key(code: .function(2))) == "F2")
  #expect(KeyNames.describe(Key(code: .right)) == "ArrowRight")
}

@Test
func `reply envelopes carry ok and sort their keys`() {
  #expect(ControlProtocol.success(["n": .int(1)]) == #"{"n":1,"ok":true}"#)
  #expect(ControlProtocol.failure("boom") == #"{"error":"boom","ok":false}"#)
}

@Test
func `replies stay on one line when the payload contains newlines`() {
  let line = ControlProtocol.success(["text": .string("a\nb")])
  #expect(!line.contains("\n"))
  #expect(line == #"{"ok":true,"text":"a\nb"}"#)
}
