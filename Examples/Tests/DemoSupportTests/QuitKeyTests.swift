import Tessera
import Testing

@testable import DemoSupport

struct QuitKeyTests {
  @Test
  func `an unmodified press of q quits`() {
    #expect(isQuitKey(Key(code: .character("q"))))
  }

  @Test
  func `an enriched q still quits because the match ignores alternate codes and text`() {
    let enriched = Key(
      code: .character("q"),
      shiftedCode: .character("Q"),
      baseLayoutCode: .character("q"),
      associatedText: "q"
    )

    #expect(enriched != Key(code: .character("q")))
    #expect(isQuitKey(enriched))
  }

  @Test
  func `a modified, repeated, released, or different key does not quit`() {
    #expect(isQuitKey(Key(code: .character("q"), modifiers: .control)) == false)
    #expect(isQuitKey(Key(code: .character("q"), modifiers: .alt)) == false)
    #expect(isQuitKey(Key(code: .character("q"), kind: .repeat)) == false)
    #expect(isQuitKey(Key(code: .character("q"), kind: .release)) == false)
    #expect(isQuitKey(Key(code: .character("w"))) == false)
    #expect(isQuitKey(Key(code: .escape)) == false)
  }
}
