import Foundation
import Testing

@testable import TesseraTerminalInput
@testable import TesseraTerminalSnapshotSupport

private struct KittyNumericKeyCase: Sendable {
  var code: Int
  var keyCode: KeyCode
}

private let kittyNumericKeyCases: [KittyNumericKeyCase] =
  [
    KittyNumericKeyCase(code: 9, keyCode: .tab),
    KittyNumericKeyCase(code: 13, keyCode: .enter),
    KittyNumericKeyCase(code: 27, keyCode: .escape),
    KittyNumericKeyCase(code: 127, keyCode: .backspace),
    KittyNumericKeyCase(code: 57_358, keyCode: .capsLock),
    KittyNumericKeyCase(code: 57_359, keyCode: .scrollLock),
    KittyNumericKeyCase(code: 57_360, keyCode: .numLock),
    KittyNumericKeyCase(code: 57_361, keyCode: .printScreen),
    KittyNumericKeyCase(code: 57_362, keyCode: .pause),
    KittyNumericKeyCase(code: 57_363, keyCode: .menu),
  ]
  + (57_376...57_398).map { code in
    KittyNumericKeyCase(code: code, keyCode: .function(code - 57_363))
  }
  + zip(57_399...57_408, KeyCode.Keypad.digits).map { code, keypad in
    KittyNumericKeyCase(code: code, keyCode: .keypad(keypad))
  }
  + zip(57_409...57_416, KeyCode.Keypad.operations).map { code, keypad in
    KittyNumericKeyCase(code: code, keyCode: .keypad(keypad))
  }
  + zip(57_417...57_427, KeyCode.Keypad.navigation).map { code, keypad in
    KittyNumericKeyCase(code: code, keyCode: .keypad(keypad))
  }
  + zip(57_428...57_437, KeyCode.Media.transport).map { code, media in
    KittyNumericKeyCase(code: code, keyCode: .media(media))
  } + [
    KittyNumericKeyCase(code: 57_438, keyCode: .media(.lowerVolume)),
    KittyNumericKeyCase(code: 57_439, keyCode: .media(.raiseVolume)),
    KittyNumericKeyCase(code: 57_440, keyCode: .media(.muteVolume)),
  ]
  + zip(57_441...57_446, KeyCode.Modifier.leftSide).map { code, modifier in
    KittyNumericKeyCase(code: code, keyCode: .modifier(modifier))
  }
  + zip(57_447...57_452, KeyCode.Modifier.rightSide).map { code, modifier in
    KittyNumericKeyCase(code: code, keyCode: .modifier(modifier))
  } + [
    KittyNumericKeyCase(code: 57_453, keyCode: .modifier(.isoLevel3Shift)),
    KittyNumericKeyCase(code: 57_454, keyCode: .modifier(.isoLevel5Shift)),
  ]

private struct GhosttyOracleCase: CustomTestStringConvertible, Sendable {
  var testDescription: String
  var keyRawValue: UInt32
  var expected: Key
  var action: GhosttyKittyKeyEncoder.Action = .press
  var mods: UInt16 = 0
  var utf8: String?
  var unshiftedCodepoint: UInt32 = 0
}

@Test(arguments: kittyNumericKeyCases)
private func `parser maps documented Kitty numeric key code`(
  _ testCase: KittyNumericKeyCase
) {
  #expect(parseKey("\u{1B}[\(testCase.code)u") == Key(code: testCase.keyCode))
}

@Test
func `parser decodes Kitty alternate keys and associated text`() {
  #expect(
    parseKey("\u{1B}[107:75:113;3:2;97:98u")
      == Key(
        code: .character("k"),
        modifiers: .alt,
        kind: .repeat,
        shiftedCode: .character("K"),
        baseLayoutCode: .character("q"),
        associatedText: "ab"
      )
  )
  #expect(
    parseKey("\u{1B}[107::113u")
      == Key(
        code: .character("k"),
        baseLayoutCode: .character("q")
      )
  )
}

@Test
func `parser decodes explicit empty associated text field as empty string`() {
  #expect(
    parseKey("\u{1B}[107;1;u")
      == Key(
        code: .character("k"),
        associatedText: ""
      )
  )
}

@Test(arguments: Array(1...256))
func `parser decodes every Kitty modifier wire value`(_ wireValue: Int) {
  let expectedModifiers = Modifiers(rawValue: UInt8(wireValue - 1))
  #expect(
    parseKey("\u{1B}[107;\(wireValue)u")
      == Key(
        code: .character("k"),
        modifiers: expectedModifiers
      )
  )
}

@Test
func `parser decodes Kitty event kinds on legacy-shaped reports`() {
  #expect(parseKey("\u{1B}[1;1:3A") == Key(code: .up, kind: .release))
  #expect(parseKey("\u{1B}[13;1:2~") == Key(code: .function(3), kind: .repeat))
}

@Test
func `parser preserves unidentified Kitty key codes semantically`() {
  #expect(parseKey("\u{1B}[57500u") == Key(code: .unidentified(57_500)))
  #expect(
    parseKey("\u{1B}[0;1;97:98u")
      == Key(
        code: .unidentified(0),
        associatedText: "ab"
      )
  )
}

@Test
func `parser rejects malformed full Kitty reports as unknown`() {
  assertUnknown("\u{1B}[0u")
  assertUnknown("\u{1B}[107;257u")
  assertUnknown("\u{1B}[107;1:4u")
  assertUnknown("\u{1B}[107;1;31u")
  assertUnknown("\u{1B}[99999999u")
}

@Test
func `parser accepts keypad begin through both Kitty terminators`() {
  #expect(parseKey("\u{1B}[57427u") == Key(code: .keypad(.begin)))
  #expect(parseKey("\u{1B}[57427~") == Key(code: .keypad(.begin)))
  #expect(parseKey("\u{1B}[E") == Key(code: .keypad(.begin)))
}

@Test(
  .disabled(
    if: GhosttyKittyKeyEncoder.isUnavailable,
    "Ghostty key encoder is unavailable in this build."
  ),
  arguments: ghosttyOracleCases
)
private func `parser matches Ghostty Kitty keyboard encoding`(
  _ testCase: GhosttyOracleCase
) throws {
  let bytes = try GhosttyKittyKeyEncoder.encode(
    keyRawValue: testCase.keyRawValue,
    action: testCase.action,
    mods: testCase.mods,
    utf8: testCase.utf8,
    unshiftedCodepoint: testCase.unshiftedCodepoint,
    kittyFlags: GhosttyKittyKeyEncoder.KittyFlag.all
  )

  var parser = InputParser()
  let events = parser.feed(contentsOf: bytes)
  #expect(
    events == [.key(testCase.expected)],
    """
    case "\(testCase.testDescription)": key=\(testCase.keyRawValue) \
    action=\(testCase.action) mods=\(testCase.mods) flags=\(GhosttyKittyKeyEncoder.KittyFlag.all) \
    encoded=\(bytes.map { String(format: "%02X", $0) }.joined(separator: " ")) \
    expected=\(testCase.expected) actual=\(events)
    """
  )
}

private let ghosttyOracleCases: [GhosttyOracleCase] = [
  // Every Ghostty-representable non-text key, no modifiers.
  GhosttyOracleCase(
    testDescription: "enter press",
    keyRawValue: GhosttyKittyKeyEncoder.KeyRawValue.enter,
    expected: Key(code: .enter)
  ),
  GhosttyOracleCase(
    testDescription: "escape press",
    keyRawValue: GhosttyKittyKeyEncoder.KeyRawValue.escape,
    expected: Key(code: .escape)
  ),
  GhosttyOracleCase(
    testDescription: "tab press",
    keyRawValue: GhosttyKittyKeyEncoder.KeyRawValue.tab,
    expected: Key(code: .tab)
  ),
  GhosttyOracleCase(
    testDescription: "backspace press",
    keyRawValue: GhosttyKittyKeyEncoder.KeyRawValue.backspace,
    expected: Key(code: .backspace)
  ),
  GhosttyOracleCase(
    testDescription: "delete press",
    keyRawValue: GhosttyKittyKeyEncoder.KeyRawValue.delete,
    expected: Key(code: .delete)
  ),
  GhosttyOracleCase(
    testDescription: "home press",
    keyRawValue: GhosttyKittyKeyEncoder.KeyRawValue.home,
    expected: Key(code: .home)
  ),
  GhosttyOracleCase(
    testDescription: "page up press",
    keyRawValue: GhosttyKittyKeyEncoder.KeyRawValue.pageUp,
    expected: Key(code: .pageUp)
  ),
  GhosttyOracleCase(
    testDescription: "page down press",
    keyRawValue: GhosttyKittyKeyEncoder.KeyRawValue.pageDown,
    expected: Key(code: .pageDown)
  ),
  GhosttyOracleCase(
    testDescription: "arrow down press",
    keyRawValue: GhosttyKittyKeyEncoder.KeyRawValue.arrowDown,
    expected: Key(code: .down)
  ),
  GhosttyOracleCase(
    testDescription: "arrow left press",
    keyRawValue: GhosttyKittyKeyEncoder.KeyRawValue.arrowLeft,
    expected: Key(code: .left)
  ),
  GhosttyOracleCase(
    testDescription: "arrow right press",
    keyRawValue: GhosttyKittyKeyEncoder.KeyRawValue.arrowRight,
    expected: Key(code: .right)
  ),
  GhosttyOracleCase(
    testDescription: "arrow up press",
    keyRawValue: GhosttyKittyKeyEncoder.KeyRawValue.arrowUp,
    expected: Key(code: .up)
  ),
  GhosttyOracleCase(
    testDescription: "f1 press",
    keyRawValue: GhosttyKittyKeyEncoder.KeyRawValue.f1,
    expected: Key(code: .function(1))
  ),
  GhosttyOracleCase(
    testDescription: "f2 press",
    keyRawValue: GhosttyKittyKeyEncoder.KeyRawValue.f2,
    expected: Key(code: .function(2))
  ),

  // Representative modifier combinations on non-text keys.
  GhosttyOracleCase(
    testDescription: "home shift",
    keyRawValue: GhosttyKittyKeyEncoder.KeyRawValue.home,
    expected: Key(code: .home, modifiers: .shift),
    mods: GhosttyKittyKeyEncoder.ModRawValue.shift
  ),
  GhosttyOracleCase(
    testDescription: "f5 control",
    keyRawValue: GhosttyKittyKeyEncoder.KeyRawValue.f5,
    expected: Key(code: .function(5), modifiers: .control),
    mods: GhosttyKittyKeyEncoder.ModRawValue.control
  ),
  GhosttyOracleCase(
    testDescription: "delete control shift",
    keyRawValue: GhosttyKittyKeyEncoder.KeyRawValue.delete,
    expected: Key(code: .delete, modifiers: [.control, .shift]),
    mods: GhosttyKittyKeyEncoder.ModRawValue.control
      | GhosttyKittyKeyEncoder.ModRawValue.shift
  ),
  GhosttyOracleCase(
    testDescription: "page down super caps lock",
    keyRawValue: GhosttyKittyKeyEncoder.KeyRawValue.pageDown,
    expected: Key(code: .pageDown, modifiers: [.super, .capsLock]),
    mods: GhosttyKittyKeyEncoder.ModRawValue.super
      | GhosttyKittyKeyEncoder.ModRawValue.capsLock
  ),

  // Press, repeat, and release on a representative non-text key.
  GhosttyOracleCase(
    testDescription: "arrow up repeat",
    keyRawValue: GhosttyKittyKeyEncoder.KeyRawValue.arrowUp,
    expected: Key(code: .up, kind: .repeat),
    action: .repeat
  ),
  GhosttyOracleCase(
    testDescription: "arrow up release",
    keyRawValue: GhosttyKittyKeyEncoder.KeyRawValue.arrowUp,
    expected: Key(code: .up, kind: .release),
    action: .release
  ),

  // Text keys via set_utf8 / set_unshifted_codepoint, including press, repeat, and
  // release, plus a shifted example. Ghostty derives the primary Kitty key code from
  // the unshifted codepoint regardless of the shifted utf8 text supplied; it does not
  // populate Kitty's alternate-key or associated-text subfields through this minimal
  // event API, so that coverage stays in the golden tests above.
  GhosttyOracleCase(
    testDescription: "k text press",
    keyRawValue: GhosttyKittyKeyEncoder.KeyRawValue.k,
    expected: Key(code: .character("k")),
    utf8: "k",
    unshiftedCodepoint: 0x6B
  ),
  GhosttyOracleCase(
    testDescription: "k text repeat",
    keyRawValue: GhosttyKittyKeyEncoder.KeyRawValue.k,
    expected: Key(code: .character("k"), kind: .repeat),
    action: .repeat,
    utf8: "k",
    unshiftedCodepoint: 0x6B
  ),
  GhosttyOracleCase(
    testDescription: "k text release",
    keyRawValue: GhosttyKittyKeyEncoder.KeyRawValue.k,
    expected: Key(code: .character("k"), kind: .release),
    action: .release,
    utf8: "k",
    unshiftedCodepoint: 0x6B
  ),
  GhosttyOracleCase(
    testDescription: "k text shift",
    keyRawValue: GhosttyKittyKeyEncoder.KeyRawValue.k,
    expected: Key(code: .character("k"), modifiers: .shift),
    mods: GhosttyKittyKeyEncoder.ModRawValue.shift,
    utf8: "K",
    unshiftedCodepoint: 0x6B
  ),
]

/// One Kitty modifier bit Ghostty can express, paired with its Tessera equivalent.
private struct GhosttyModifierBit {
  var ghosttyMod: UInt16
  var tesseraModifier: Modifiers
}

/// The six Kitty modifier bits reachable through `GhosttyMods` (no hyper or meta).
private let ghosttyRepresentableModifierBits: [GhosttyModifierBit] = [
  GhosttyModifierBit(
    ghosttyMod: GhosttyKittyKeyEncoder.ModRawValue.shift,
    tesseraModifier: .shift
  ),
  GhosttyModifierBit(
    ghosttyMod: GhosttyKittyKeyEncoder.ModRawValue.alt,
    tesseraModifier: .alt
  ),
  GhosttyModifierBit(
    ghosttyMod: GhosttyKittyKeyEncoder.ModRawValue.control,
    tesseraModifier: .control
  ),
  GhosttyModifierBit(
    ghosttyMod: GhosttyKittyKeyEncoder.ModRawValue.super,
    tesseraModifier: .super
  ),
  GhosttyModifierBit(
    ghosttyMod: GhosttyKittyKeyEncoder.ModRawValue.capsLock,
    tesseraModifier: .capsLock
  ),
  GhosttyModifierBit(
    ghosttyMod: GhosttyKittyKeyEncoder.ModRawValue.numLock,
    tesseraModifier: .numLock
  ),
]

private struct GhosttyModifierSweepCase: CustomTestStringConvertible, Sendable {
  var bitmask: Int
  var ghosttyMods: UInt16
  var expectedModifiers: Modifiers

  var testDescription: String {
    "bitmask \(bitmask) (ghostty mods \(ghosttyMods))"
  }
}

/// All 64 combinations of the six Ghostty-representable Kitty modifier bits, on one key.
private let ghosttyModifierSweepCases: [GhosttyModifierSweepCase] = (0..<64)
  .map { bitmask in
    var ghosttyMods: UInt16 = 0
    var expectedModifiers: Modifiers = []
    for (index, bit) in ghosttyRepresentableModifierBits.enumerated()
    where bitmask & (1 << index) != 0 {
      ghosttyMods |= bit.ghosttyMod
      expectedModifiers.insert(bit.tesseraModifier)
    }
    return GhosttyModifierSweepCase(
      bitmask: bitmask,
      ghosttyMods: ghosttyMods,
      expectedModifiers: expectedModifiers
    )
  }

@Test(
  .disabled(
    if: GhosttyKittyKeyEncoder.isUnavailable,
    "Ghostty key encoder is unavailable in this build."
  ),
  arguments: ghosttyModifierSweepCases
)
private func `parser matches Ghostty modifier bit combinations`(
  _ testCase: GhosttyModifierSweepCase
) throws {
  let bytes = try GhosttyKittyKeyEncoder.encode(
    keyRawValue: GhosttyKittyKeyEncoder.KeyRawValue.arrowUp,
    mods: testCase.ghosttyMods,
    kittyFlags: GhosttyKittyKeyEncoder.KittyFlag.all
  )

  var parser = InputParser()
  let events = parser.feed(contentsOf: bytes)
  let expected = Key(code: .up, modifiers: testCase.expectedModifiers)
  #expect(
    events == [.key(expected)],
    """
    bitmask=\(testCase.bitmask) ghosttyMods=\(testCase.ghosttyMods) \
    encoded=\(bytes.map { String(format: "%02X", $0) }.joined(separator: " ")) \
    expected=\(expected) actual=\(events)
    """
  )
}

private func parseKey(_ string: String) -> Key? {
  var parser = InputParser()
  guard case .key(let key) = parser.feed(contentsOf: Array(string.utf8)).first else {
    return nil
  }
  return key
}

private func assertUnknown(
  _ string: String,
  sourceLocation: SourceLocation = #_sourceLocation
) {
  var parser = InputParser()
  #expect(
    parser.feed(contentsOf: Array(string.utf8)) == [.unknown(Array(string.utf8))],
    sourceLocation: sourceLocation
  )
}

extension KeyCode.Keypad {
  fileprivate static let digits: [Self] = [
    .zero, .one, .two, .three, .four, .five, .six, .seven, .eight, .nine,
  ]

  fileprivate static let operations: [Self] = [
    .decimal, .divide, .multiply, .subtract, .add, .enter, .equal, .separator,
  ]

  fileprivate static let navigation: [Self] = [
    .left, .right, .up, .down, .pageUp, .pageDown, .home, .end, .insert,
    .delete, .begin,
  ]
}

extension KeyCode.Media {
  fileprivate static let transport: [Self] = [
    .play, .pause, .playPause, .reverse, .stop, .fastForward, .rewind,
    .trackNext, .trackPrevious, .record,
  ]
}

extension KeyCode.Modifier {
  fileprivate static let leftSide: [Self] = [
    .leftShift, .leftControl, .leftAlt, .leftSuper, .leftHyper, .leftMeta,
  ]

  fileprivate static let rightSide: [Self] = [
    .rightShift, .rightControl, .rightAlt, .rightSuper, .rightHyper, .rightMeta,
  ]
}
