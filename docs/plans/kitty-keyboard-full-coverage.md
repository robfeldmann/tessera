---
name: Kitty Keyboard Full Coverage
description:
  Expand Tessera keyboard input to preserve the full Kitty keyboard protocol surface and
  verify it with table-driven parser tests plus Ghostty key-encoder oracle tests.
status: complete
created: 2026-07-05
updated: 2026-07-05
---

## Progress

- [x] **Phase 1 — Public keyboard model**
  - [x] 1.1 Implement the settled key-code taxonomy
  - [x] 1.2 Preserve Kitty alternate keys and associated text on `Key`
  - [x] 1.3 Add caps-lock and num-lock modifier bits
- [x] **Phase 2 — Full Kitty parser support**
  - [x] 2.1 Parse the full Kitty key-report grammar
  - [x] 2.2 Map every Kitty functional key definition and fix misassignments
  - [x] 2.3 Preserve unidentified key codes semantically
- [x] **Phase 3 — Ghostty key-encoder oracle tests**
  - [x] 3.1 Add a test-only Ghostty key encoder wrapper
  - [x] 3.2 Generate parameterized key cases from Ghostty
  - [x] 3.3 Keep independent golden tests for protocol sentinels
- [x] **Phase 4 — Demo and validation**
  - [x] 4.1 Update the Phase 3 keyboard demo panel
  - [x] 4.2 Run parser, session, IO, demo, quality, and markdown checks

## Overview

This plan extends the completed Kitty keyboard slice. The first slice enabled the protocol
and proved representative key reports. It did not claim that Tessera can represent every
key event Kitty can emit. This plan makes that contract explicit: application authors
should be able to route, display, and test any keyboard event Tessera receives from the
Kitty keyboard protocol without falling back to raw byte inspection.

The raw-output escape hatch in `docs/Spec.md` lines 86-90 remains output-only. It lets an
application render terminal bytes for protocols Tessera does not yet model. It is not the
right abstraction for keyboard input. The input-side equivalent is semantic preservation:
when Tessera can parse that a terminal sent a key event, it should surface a `Key` value
with enough typed metadata for application code to handle it.
`InputEvent.unknown([UInt8])` stays reserved for malformed or non-keyboard sequences that
Tessera cannot parse as a known input protocol. This deliberately supersedes the
`docs/Spec.md` Slice 4 guidance to route unknown-but-well-formed reports through
`.unknown` "until the public API has a real use case"; this plan is that use case.

The Ghostty-backed `VirtualTerminal` screen harness is output-oriented: bytes go in,
screen state comes out. For keyboard input verification, use Ghostty's key encoder API
exposed by `Sources/CGhosttyVT/include/ghostty/vt/key/encoder.h` and
`Sources/CGhosttyVT/include/ghostty/vt/key/event.h`: construct a Ghostty key event, encode
it with Kitty flags, feed the resulting bytes into `InputParser`, and assert Tessera's
semantic `Key` equals the expected value. The oracle covers only the intersection of the
two key models (see Step 3.2), so an independent golden corpus carries the remainder and
keeps Tessera from testing itself against a single external implementation.

### Current state and known defects

The executor inherits these facts from the shipped slice
(`Sources/TesseraTerminalInput/InputParser.swift:499-580`):

- `kittyKeyCode(_:)` names only `9`, `13`, `27`, `127`, and `57358...57361`.
- The `57358...57361` entries are wrong: it maps them to arrow keys, but Kitty assigns
  57358 CAPS_LOCK, 57359 SCROLL_LOCK, 57360 NUM_LOCK, and 57361 PRINT_SCREEN. Arrows have
  no CSI-u code points; Kitty reports them only in the legacy-letter shape
  `CSI 1 ; modifiers [ABCD]`. Phase 2.2 removes the misassignment.
- The default branch turns every other valid Unicode scalar into
  `.character(Character(scalar))`, so today F13 (57376) parses as a Private Use Area
  character, not a function key. The guard on that branch contains a vacuous `|| true`
  clause; delete it with the rewrite.
- Alternate-key and associated-text subfields are parsed by `CSIParameters` but dropped.
- Modifier bits 6 and 7 survive in `Modifiers.rawValue` but have no public names.

## Settled API decisions

These four decisions were reviewed before implementation and are binding. The full
spellings live in the Phase 1 steps.

1. **Taxonomy names.** Keep the existing sixteen `KeyCode` cases unchanged. Add flat cases
   for singleton keys (`capsLock`, `scrollLock`, `numLock`, `printScreen`, `pause`,
   `menu`) and three nested enums for dense families: `KeyCode.Keypad`, `KeyCode.Media`,
   and `KeyCode.Modifier`, carried by `case keypad(Keypad)`, `case media(Media)`, and
   `case modifier(Modifier)`. This mirrors crossterm's proven
   `Media(MediaKeyCode)`/`Modifier(ModifierKeyCode)` split while staying Swift-idiomatic.
   Nesting avoids a top-level `ModifierKey`/`Modifiers` near-collision.
2. **`function(Int)` stays open-range.** No clamp, no nested type, matching crossterm's
   `F(u8)`. The doc comment states the parser emits only 1 through 35: F1-F12 from legacy
   encodings, F13-F35 from Kitty codes 57376-57398. A hand-constructed `function(99)` is
   inert, not a trap.
3. **Fallback case.** `case unidentified(Int)` preserves any well-formed Kitty key code
   that has no named mapping: unassigned Private Use Area codes (57344-63743) and the
   reserved key number `0` used for pure-text events. The payload is the raw Kitty key
   code. Well-formed non-PUA scalars keep mapping to `.character`; invalid scalars and
   syntactic errors remain `InputEvent.unknown`. The name follows W3C UIEvents
   ("Unidentified") and `GHOSTTY_KEY_UNIDENTIFIED`; `privateUse` was rejected because the
   case also covers key number 0.
4. **Kitty metadata lives flat on `Key`.** Three optional stored properties —
   `shiftedCode: KeyCode?`, `baseLayoutCode: KeyCode?`, `associatedText: String?` — all
   defaulting to `nil`. The `KeyAlternateCodes` wrapper struct from the first draft was
   rejected: it added a nesting level without enforcing any invariant. `Key` remains the
   protocol-agnostic key event; legacy parse paths simply leave the optionals `nil`.

## Phase 1 — Public keyboard model

**Goal**: `Key` and `KeyCode` represent the complete Kitty keyboard event model, including
all current Kitty functional key definitions, alternate key metadata, associated text,
lock modifiers, and unidentified key codes.

### Step 1.1 — Implement the settled key-code taxonomy

Files:

- `Sources/TesseraTerminalInput/KeyCode.swift`
- `Tests/TesseraTerminalInputTests/InputParserTests.swift`

Extend `KeyCode` to exactly this shape (cases sorted alphabetically, matching the current
file's convention; conformances stay `Equatable, Sendable`):

```swift
public enum KeyCode: Equatable, Sendable {
  case backspace
  case capsLock
  case character(Character)
  case delete
  case down
  case end
  case enter
  case escape
  case function(Int)
  case home
  case insert
  case keypad(Keypad)
  case left
  case media(Media)
  case menu
  case modifier(Modifier)
  case numLock
  case pageDown
  case pageUp
  case pause
  case printScreen
  case right
  case scrollLock
  case tab
  case unidentified(Int)
  case up
}

extension KeyCode {
  public enum Keypad: Equatable, Sendable {
    case add, begin, decimal, delete, divide, down, eight, end, enter, equal,
      five, four, home, insert, left, multiply, nine, one, pageDown, pageUp,
      right, separator, seven, six, subtract, three, two, up, zero
  }

  public enum Media: Equatable, Sendable {
    case fastForward, lowerVolume, muteVolume, pause, play, playPause,
      raiseVolume, record, reverse, rewind, stop, trackNext, trackPrevious
  }

  public enum Modifier: Equatable, Sendable {
    case isoLevel3Shift, isoLevel5Shift, leftAlt, leftControl, leftHyper,
      leftMeta, leftShift, leftSuper, rightAlt, rightControl, rightHyper,
      rightMeta, rightShift, rightSuper
  }
}
```

`Keypad` has 29 cases, one per Kitty `KP_*` code (57399-57427). `Media` has 13 cases
covering `MEDIA_*` plus the three volume keys (57428-57440). `Modifier` has 14 cases
covering the twelve left/right physical modifiers plus both ISO level shifts
(57441-57454). Digits are spelled out (`zero`...`nine`) so the enum is total with no
invalid values.

Doc comments to write:

- `function`: valid range emitted by the parser is 1-35; F1-F12 arrive via legacy
  SS3/CSI/tilde encodings, F13-F35 via Kitty codes 57376-57398.
- `unidentified`: semantics from decision 3 above, including key number 0.

Acceptance:

- Existing call sites still compile. No external exhaustive `switch` over `KeyCode` exists
  today (demos equality-match `Key` or bind `case .character`), so added cases are
  source-compatible.
- Common keys remain ergonomic: `.enter`, `.function(5)`, `.media(.playPause)`,
  `.modifier(.leftShift)`.
- Every code in Kitty's current functional-key table is representable, and
  `unidentified(Int)` is the stable escape valve for future codes.

### Step 1.2 — Preserve Kitty alternate keys and associated text on `Key`

Files:

- `Sources/TesseraTerminalInput/Key.swift`
- `Sources/TesseraTerminalInput/InputParser.swift`
- `Tests/TesseraTerminalInputTests/InputParserTests.swift`

Extend `Key` with three defaulted optional properties:

```swift
public struct Key: Equatable, Sendable {
  public var code: KeyCode
  public var modifiers: Modifiers
  public var kind: KeyEventKind
  public var shiftedCode: KeyCode?
  public var baseLayoutCode: KeyCode?
  public var associatedText: String?

  public init(
    code: KeyCode,
    modifiers: Modifiers = [],
    kind: KeyEventKind = .press,
    shiftedCode: KeyCode? = nil,
    baseLayoutCode: KeyCode? = nil,
    associatedText: String? = nil
  )
}
```

Semantics, from `CSI key-code:shifted:base-layout ; modifiers:event-type ; text u`:

- `shiftedCode`: the shifted alternate, mapped through the same key-code table as the
  primary. Kitty documents that it is only sent when shift is held; Tessera preserves
  whatever a terminal sends rather than enforcing that invariant (interop over
  strictness), and documents it.
- `baseLayoutCode`: the PC-101 base-layout alternate, same mapping.
- `associatedText`: the decoded text-as-code-points payload. Kitty prohibits control codes
  (code points below U+0020 and U+007F-U+009F) in this field; reports carrying them are
  malformed and preserved as `.unknown`.

Acceptance:

- Parser tests cover: shifted alternate, base-layout alternate, empty-shifted plus
  base-layout (`code::base`), and associated text with multiple code points.
- Associated text containing control codes preserves the whole report as `.unknown`.
- Existing `Key(code:modifiers:kind:)` call sites compile unchanged; equality tests
  against keys without metadata still pass because the new fields default to `nil`.

### Step 1.3 — Add caps-lock and num-lock modifier bits

Files:

- `Sources/TesseraTerminalInput/Modifiers.swift`
- `Tests/TesseraTerminalInputTests/InputParserTests.swift`

Kitty's modifier byte is shift 1, alt 2, ctrl 4, super 8, hyper 16, meta 32, caps_lock 64,
num_lock 128, sent on the wire as `value + 1`. Tessera's existing six flags already match
bit positions 0-5. Add:

- `.capsLock` = `1 << 6`
- `.numLock` = `1 << 7`

Keep `rawValue: UInt8` (`docs/Spec.md` Slice 4: do not widen). With all eight bits named,
the current unmasked pass-through of the decoded byte becomes exact rather than lossy.

Acceptance:

- Tests cover all 8 modifier bits, including wire value 256 (all modifiers).
- Event-log formatting (`eventLogLine` helper and demo `describe`) names `capsLock` and
  `numLock`.

## Phase 2 — Full Kitty parser support

**Goal**: the parser decodes the full current Kitty keyboard protocol grammar and maps
known keys into public semantic values.

### Step 2.1 — Parse the full Kitty key-report grammar

Files:

- `Sources/TesseraTerminalInput/InputParser.swift`
- `Tests/TesseraTerminalInputTests/InputParserTests.swift`

Replace the partial Kitty decoder with the complete grammar:

```text
CSI unicode-key-code:shifted-key:base-layout-key ; modifiers:event-type ; text u
```

Rules:

- Omitted modifiers field means wire value 1, i.e. no modifiers.
- Omitted event type defaults to press; `1` press, `2` repeat, `3` release.
- Empty shifted subfield plus present base-layout subfield (`code::base`) is valid.
- Associated text is zero or more colon-separated Unicode code points and only appears on
  `u`-terminated reports.
- Key code `0` is valid only when associated text is present (pure-text event).
- The `modifiers:event-type` subfield also appears on Kitty's legacy-shaped functional
  forms: `CSI 1 ; modifiers:event-type [ABCDEFHPQS]` and
  `CSI number ; modifiers:event-type ~`. Extend the legacy CSI-letter and tilde paths to
  decode the event-type subfield there too (e.g. `CSI 1;1:3 A` is an up-arrow release).
- Invalid integers, invalid Unicode scalars, invalid event types, zero modifier wire
  values, and control-code associated text become `.unknown(originalBytes)`.

Acceptance:

- Tests cover every optional-field shape in the grammar, including event-type subfields on
  letter- and tilde-terminated reports.
- Tests prove malformed reports preserve the original bytes as `.unknown`.
- Existing legacy CSI, SS3, UTF-8, focus, mouse, and bracketed-paste tests still pass.

### Step 2.2 — Map every Kitty functional key definition and fix misassignments

Files:

- `Sources/TesseraTerminalInput/InputParser.swift`
- `Sources/TesseraTerminalInput/KeyCode.swift`
- `Tests/TesseraTerminalInputTests/InputParserTests.swift`

Implement a single source-of-truth mapping from Kitty numeric codes to `KeyCode`, used for
the primary code and both alternates. This removes the current arrow misassignment of
57358-57361 and the vacuous scalar guard. The complete table (Kitty spec, "Functional key
definitions"; PUA range 57344-63743, highest assigned code 57454):

```text
9  tab · 13 enter · 27 escape · 127 backspace
57358 capsLock · 57359 scrollLock · 57360 numLock · 57361 printScreen
57362 pause · 57363 menu
57376-57398        function(13)...function(35)
57399-57408        keypad(.zero)...keypad(.nine)
57409-57416        keypad: .decimal .divide .multiply .subtract .add .enter .equal .separator
57417-57427        keypad: .left .right .up .down .pageUp .pageDown .home .end .insert .delete .begin
57428-57437        media: .play .pause .playPause .reverse .stop .fastForward .rewind .trackNext .trackPrevious .record
57438-57440        media: .lowerVolume .raiseVolume .muteVolume
57441-57446        modifier: .leftShift .leftControl .leftAlt .leftSuper .leftHyper .leftMeta
57447-57452        modifier: .rightShift .rightControl .rightAlt .rightSuper .rightHyper .rightMeta
57453 modifier(.isoLevel3Shift) · 57454 modifier(.isoLevel5Shift)
```

Keys with legacy encodings keep them under Kitty (arrows, Home `1 H`/`7 ~`, End
`1 F`/`8 ~`, Insert `2 ~`, Delete `3 ~`, PageUp `5 ~`, PageDown `6 ~`, F1-F12 via
SS3/CSI-letter/tilde). Kitty encodes F3 as `CSI 13 ~` only, because `CSI 1;m R` collides
with cursor-position reports. `KP_BEGIN` is reachable as legacy `CSI E`/`CSI 1;m E` and by
number 57427; the spec table marks its numeric form with a `~` terminator, so accept 57427
through both the tilde and `u` dispatch paths.

Acceptance:

- Parameterized tests cover every known Kitty numeric key code in the table above.
- Tests prove `57358 u` now parses as `.capsLock` (and peers), not an arrow key.
- Legacy aliases such as `CSI 1 P`, `CSI P`, `SS3 P`, and `CSI 11 ~` for F1 remain
  covered, plus `CSI E` for `keypad(.begin)`.

### Step 2.3 — Preserve unidentified key codes semantically

Files:

- `Sources/TesseraTerminalInput/KeyCode.swift`
- `Sources/TesseraTerminalInput/InputParser.swift`
- `Tests/TesseraTerminalInputTests/InputParserTests.swift`

If a terminal emits a parseable key code inside Kitty's PUA range that the table does not
name, or key number `0` with associated text, parse it into `.unidentified(code)`. Do not
treat a report as malformed solely because Tessera lacks a case name. Well-formed non-PUA
scalars keep mapping to `.character`.

Acceptance:

- Tests cover an unassigned PUA code (e.g. `57500 u`) asserting `.unidentified(57500)`.
- Tests cover `CSI 0;1;97:98 u`-shaped pure-text events asserting `.unidentified(0)` with
  `associatedText`.
- Tests still reject invalid Unicode scalars and syntactically malformed reports as
  `.unknown`.

## Phase 3 — Ghostty key-encoder oracle tests

**Goal**: verify Tessera's input parser against Ghostty's independent Kitty key encoder
for large cross-products without hand-writing every expected byte sequence.

### Step 3.1 — Add a test-only Ghostty key encoder wrapper

Files:

- `Sources/TesseraTerminalSnapshotSupport/GhosttyKeyEncoder.swift` (new)
- `Tests/TesseraTerminalInputTests/`
- `Package.swift`: add `TesseraTerminalSnapshotSupport` to the existing
  `TesseraTerminalInputTests` target dependencies. No new target is required.

`TesseraTerminalSnapshotSupport` already owns the `canImport(CGhosttyVT)` gate and the
loud-unavailability pattern (`VirtualTerminal+ghosttyUnavailable.swift`); the wrapper
follows the same conventions, including the allocator convention used by
`VirtualTerminal+Ghostty.swift`. Wrap:

- `ghostty_key_encoder_new` / `ghostty_key_encoder_free`
- `ghostty_key_encoder_setopt` (option `GHOSTTY_KEY_ENCODER_OPT_KITTY_FLAGS`; the value
  parameter is a pointer to a `GhosttyKittyKeyFlags` byte)
- `ghostty_key_encoder_encode`
- `ghostty_key_event_new` / `ghostty_key_event_free`
- `ghostty_key_event_set_action`, `_set_key`, `_set_mods`, `_set_utf8`,
  `_set_unshifted_codepoint` (text keys need `utf8` and `unshifted_codepoint` populated
  for faithful encodings)

Configure Kitty flags explicitly per test via `GHOSTTY_KITTY_KEY_*` constants. Do not
route this through `VirtualTerminal.feed`; that harness validates output bytes against
screen state, while keyboard verification needs the key-event-to-byte encoder.

Acceptance:

- The helper is compiled only under `#if canImport(CGhosttyVT)` and lives in the
  test-support product, not the core terminal products.
- The helper frees encoder and event handles deterministically.
- Tests skip loudly on platforms where the Ghostty key encoder is unavailable, matching
  the existing `ghosttyOrUnavailable` convention.

### Step 3.2 — Generate parameterized key cases from Ghostty

Files:

- `Tests/TesseraTerminalInputTests/InputParserTests.swift` or a new focused test file

Use Swift Testing parameterized tests:

```swift
@Test(arguments: kittyKeyboardCases)
func `parser matches Ghostty Kitty keyboard encoding`(_ testCase: KittyKeyboardCase) {
  let bytes = ghosttyEncoder.encode(testCase.ghosttyEvent, flags: testCase.flags)
  #expect(InputParser().feed(contentsOf: bytes) == [.key(testCase.expectedKey)])
}
```

The oracle covers only the intersection of the two key models. `GhosttyKey` stops at F25,
has no ISO level shifts, and lacks Kitty's distinct play/pause/reverse/fast-forward/
rewind/record media keys; `GhosttyMods` has no hyper or meta bits, and its bit layout
(ctrl `1 << 1`, alt `1 << 2`, caps `1 << 4`, num `1 << 5`) differs from Kitty's wire bits,
so the wrapper translates Tessera expectations into `GhosttyMods`, never reuses Kitty bit
values. Golden tests in Step 3.3 carry everything outside the intersection.

The matrix should be broad but intentional:

- every Ghostty-representable non-text key with no modifiers
- the same keys with representative modifier combinations
- all 64 combinations of the six Ghostty-representable Kitty modifier bits (shift, alt,
  ctrl, super, caps-lock, num-lock) on a small key subset
- press, repeat, and release on representative text and non-text keys
- associated-text and alternate-key examples (via `set_utf8` and
  `set_unshifted_codepoint`)

Do not create a test case for every possible Unicode scalar times every modifier times
every event kind. That is unbounded and not useful. Test invariants over generated tables
instead.

Acceptance:

- A failure prints the key name, Ghostty key code, modifiers, action, flags, encoded
  bytes, expected Tessera key, and actual parser event.
- Generated cases run deterministically and do not depend on test order.
- The suite stays fast enough for `swift test --filter TesseraTerminalInputTests`.

### Step 3.3 — Keep independent golden tests for protocol sentinels

Files:

- `Tests/TesseraTerminalInputTests/InputParserTests.swift` or a new focused test file

Golden byte tests carry the protocol grammar independent of Ghostty, plus everything the
oracle cannot represent:

- minimal printable `CSI 107 u`
- the full modifier sweep: all 256 wire values on one key, with expected `Modifiers`
  computed arithmetically in the test, not hand-written
- hyper and meta modifier combinations (absent from `GhosttyMods`)
- each event kind, including event kinds on letter/tilde forms (`CSI 1;1:3 A`)
- alternate-key and associated-text subfields, including `code::base` and pure-text
  key-number-0 reports
- malformed reports
- F26-F35 (57391-57398) and both ISO level shifts (absent from `GhosttyKey`)
- media keys absent from `GhosttyKey`: play, pause, reverse, fastForward, rewind, record
- representative keypad keys, `57427` through both terminators, and legacy aliases for
  F1/F2/F3/F4/F5

Acceptance:

- Golden tests cover the protocol grammar independent of Ghostty.
- Oracle tests cover breadth against a shipping implementation; golden tests cover the
  documented oracle gaps.

## Phase 4 — Demo and validation

**Goal**: the demo exposes all retained key metadata and validation proves the expanded
contract.

### Step 4.1 — Update the Phase 3 keyboard demo panel

Files:

- `Examples/Sources/Phase3ProtocolsDemo/Phase3ProtocolsDemo.swift`

Display the expanded key fields:

- code, including named keypad/media/modifier keys
- modifiers, including caps-lock and num-lock (extend `describe(_ modifiers:)`)
- kind
- `shiftedCode` and `baseLayoutCode` when present
- `associatedText` when present

Acceptance:

- Pressing function/media/keypad keys shows a named key when the terminal reports one.
- Unknown-but-parseable key codes show `unidentified(<code>)` rather than raw unknown
  bytes.

### Step 4.2 — Run parser, session, IO, demo, quality, and markdown checks

Run:

```fish
swift test --filter TesseraTerminalInputTests
swift test --filter TesseraTerminalIOTests
swift test --filter TesseraTerminalTests
swift build --package-path Examples --product Phase3ProtocolsDemo
just quality changed
pnpx markdownlint-cli .agents/plans/023-kitty-keyboard-full-coverage.md
```

`TesseraTerminalIOTests` is included because `PlatformIOTests` asserts parsed key events
end to end.

Acceptance:

- All validation commands pass.
- Any platform skip for Ghostty key encoder tests is explicit and documented in the test
  output.

## Decisions

- The four settled API decisions at the top of this plan are binding: nested
  `Keypad`/`Media`/`Modifier` taxonomy, open-range `function(Int)` documented as 1-35,
  `unidentified(Int)` as the fallback case, and flat optional Kitty metadata on `Key`.
- This plan supersedes the `docs/Spec.md` Slice 4 instruction to keep
  unknown-but-well-formed reports in `.unknown`; semantic preservation is the contract
  now. `Key` still evolves rather than being replaced, and `Modifiers.rawValue` stays
  `UInt8`, as Spec.md requires.
- The parser is permissive about Kitty's "shifted alternate requires shift" invariant: it
  preserves what terminals send and documents the spec rule instead of rejecting.
- Swift Testing parameterized tests are the right mechanism for the table-driven cases.
- Ghostty is a key-encoder oracle, not a screen `VirtualTerminal`, for keyboard input
  verification, and its model gaps (F26-F35, ISO shifts, hyper/meta, split media keys) are
  covered by golden tests.
- The raw-output escape hatch remains output-only. Input preservation belongs in semantic
  `Key` and `KeyCode` values.
