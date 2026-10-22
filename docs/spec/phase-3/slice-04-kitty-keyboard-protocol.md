---
type: spec
description: "Slice 4: Kitty keyboard protocol"
---

# Slice 4: Kitty keyboard protocol

Slice 4 teaches Tessera to read modern keyboard input without the historical ambiguities of legacy terminal sequences.

The legacy parser from Phase 2 is necessary, but it cannot represent the keyboard reliably. Some keys collapse into the same bytes. Some modifiers are invisible. Some combinations are impossible to distinguish from control characters. `Escape` conflicts with Alt-prefixed input. Shift only appears for some non-character keys. Super/Meta/Hyper are generally not available at all. This is fine for traditional terminal programs, but it is not enough for a modern application framework that wants predictable shortcuts and editor-quality input.

The Kitty keyboard protocol is the most practical modern answer to that problem. It is an opt-in protocol that reports keys using unambiguous CSI `u` sequences and can progressively enable richer features such as disambiguated escape codes, alternate keys, event types, and all-modifier reporting. The protocol is documented by Kitty and implemented, in whole or in useful part, by multiple modern terminals and terminal libraries.

> [!note] Ratatui References
>
> - crossterm exposes Kitty keyboard as `PushKeyboardEnhancementFlags` / `PopKeyboardEnhancementFlags`, explicitly pairing push with pop for cleanup (`crossterm` `src/event.rs`, lines 445-528). Tessera should follow the same stack-shaped lifecycle rather than using a blind reset if the protocol level supports it.
> - crossterm's enhancement flags map to the same decisions Tessera needs to make: `DISAMBIGUATE_ESCAPE_CODES`, `REPORT_EVENT_TYPES`, `REPORT_ALTERNATE_KEYS`, and `REPORT_ALL_KEYS_AS_ESCAPE_CODES` (`crossterm` `src/event.rs`, lines 300-304).
> - crossterm's key model already contains the richer pieces Tessera is adding here: `KeyModifiers` includes Shift/Control/Alt/Super/Hyper/Meta, `KeyEventKind` includes Press/Repeat/Release, and `KeyEvent` stores `code`, `modifiers`, `kind`, and `state` (`crossterm` `src/event.rs`, lines 840-949).
> - crossterm's `KeyCode` enum shows which extra key categories become representable once keyboard enhancement is enabled: CapsLock, ScrollLock, NumLock, PrintScreen, Pause, Menu, KeypadBegin, media keys, and modifier-only keys (`crossterm` `src/event.rs`, lines 1221-1318). Tessera should add these deliberately, not all at once.
> - crossterm parses keyboard-enhancement query responses and primary device attributes as internal events, not public input events (`crossterm` `src/event/sys/unix/parse.rs`, lines 258-292). That separation is relevant again in slice 6.

This is deliberately slice 4, not slice 1. Kitty keyboard changes the shape of keyboard semantics more than bracketed paste, focus, or mouse. By this point, Phase 3 has already established the pattern for optional protocol modes, parser-mode interactions, lifecycle cleanup, and cross-platform byte transport. Now Tessera can apply that pattern to the largest input upgrade.

## Public API shape

The existing Phase 2 `Key` model should evolve rather than be replaced. Applications should still receive `InputEvent.key(Key)`, but `Key` needs enough room to represent information that legacy protocols could not report.

Suggested direction — `Key` already has `var code: KeyCode` and `var modifiers: Modifiers` with the memberwise initializer shown; this slice adds `kind`:

```swift
public struct Key: Equatable, Sendable {
    public var code: KeyCode
    public var kind: KeyEventKind
    public var modifiers: Modifiers

    public init(code: KeyCode, modifiers: Modifiers = [], kind: KeyEventKind = .press)
}

public enum KeyEventKind: Equatable, Sendable {
    case press
    case release
    case `repeat`   // backticks: `repeat` is a Swift keyword
}
```

`kind` defaults to `.press`, and it is the last initializer parameter with a default, so every existing construction site keeps compiling and all legacy input stays behavior-compatible.

`Modifiers` keeps its `UInt8` raw value and existing bits and gains the rest of the Kitty modifier set:

```swift
extension Modifiers {
    // Existing: .shift = 1 << 0, .alt = 1 << 1, .control = 1 << 2
    public static let `super` = Self(rawValue: 1 << 3)  // keyword, needs backticks
    public static let hyper = Self(rawValue: 1 << 4)
    public static let meta = Self(rawValue: 1 << 5)
    // Add only if the implementation surfaces them:
    public static let capsLock = Self(rawValue: 1 << 6)
    public static let numLock = Self(rawValue: 1 << 7)
}
```

Do not widen to `UInt16`. The existing bit layout already matches the Kitty wire encoding exactly — Kitty transmits `modifier field = 1 + bits` with shift 1, alt 2, ctrl 4, super 8, hyper 16, meta 32, caps-lock 64, num-lock 128 — so `UInt8` holds the entire protocol and decoding is `Modifiers(rawValue: UInt8(field - 1))` masked to supported bits. The legacy CSI `1 + bits` modifier encoding handled by `modifiers(encodedAs:)` uses the same first three bits, which is why the existing values must not be renumbered.

The `KeyCode` enum may also need to grow (its cases stay alphabetized). Kitty can report keys that legacy terminal input cannot represent cleanly: keypad keys, caps lock, media keys, modifier-only keys, and more. A follow-up full-coverage pass superseded the day-one guidance below: `KeyCode` now represents Kitty's complete functional-key table (nested `Keypad`, `Media`, and `Modifier` enums plus flat singleton cases), and a well-formed Kitty key code with no named mapping surfaces as `KeyCode.unidentified(Int)` rather than `InputEvent.unknown([UInt8])`. `InputEvent.unknown([UInt8])` stays reserved for malformed or non-keyboard sequences Tessera cannot parse at all.

## Protocol level

Kitty keyboard mode is enabled with CSI `> ... u` progressive-enhancement flags and reset with CSI `< u` / protocol-pop behavior. `KittyKeyboardFlags.tesseraDefault` requests disambiguated escape codes, event types, and alternate keys (mask 7). Applications can set `TerminalApplicationConfiguration.kittyKeyboardFlags` to an exact startup mask; the value defaults to `.tesseraDefault`, is exposed by `TerminalSession.kittyKeyboardFlags`, and is used whenever the runtime keyboard policy activates Kitty mode. The Phase 3 protocol demo deliberately requests all five defined flags (mask 31) so modifier-only and text-key release events plus associated text are observable. This startup flag selection is independent of the live legacy/conditional/required keyboard policy.

Keep the enable operation explicit and semantic, mirroring the protocol's push/pop stack shape (`CSI > flags u` pushes, `CSI < u` pops):

```swift
public enum ControlSequence: Equatable, Sendable {
    // Existing cases, kept alphabetized...
    case popKittyKeyboard
    case pushKittyKeyboard(KittyKeyboardFlags)
}
```

where `KittyKeyboardFlags` is a small option set in `TesseraTerminalANSI` mirroring the protocol's progressive-enhancement bits (disambiguate escape codes 1, report event types 2, report alternate keys 4, report all keys as escape codes 8, report associated text 16). These are CSI sequences, not DEC private modes — encode them in a suitable `encode*` helper and remember every exhaustive switch in the enum must list the new cases.

Do not scatter raw `CSI > ... u` strings through lifecycle code. The protocol is subtle enough that all flag choices and reset behavior should live in one encoder implementation with byte-level tests.

The important lifecycle invariant: if Tessera enables Kitty keyboard mode, it must restore the prior keyboard protocol state on every exit path. Prefer the protocol's stack/push-pop mechanism if available, because it composes better with nested terminal applications than a blind global reset. If the chosen implementation uses a reset sequence instead, document why that is acceptable.

## Parser behavior

The parser should recognize Kitty keyboard reports in normal input mode while preserving the legacy parser as fallback.

Parsing requirements:

- Decode basic `CSI number ; modifiers u` key reports.
- Decode richer progressive reports according to the enabled feature flags.
- Accept an omitted default modifier field in CSI-u only when the third associated-text parameter is present, as in Ghostty's valid `CSI 113;;113u` encoding for an unmodified q press under mask 31; keep omitted modifiers invalid in legacy modified-CSI forms.
- Map modifier fields into Tessera's `Modifiers` option set.
- Map event-type fields into `KeyEventKind`.
- Preserve legacy decoding for terminals that ignore Kitty keyboard enablement.
- Preserve ordinary text input as `.key(Key(code: .character(...)))`.
- Continue to handle bytes split across reads.
- Continue to resolve bare ESC / Alt-prefix ambiguity for legacy input.
- Do not interpret Kitty-looking sequences while inside bracketed paste mode.

The concrete hooks: Kitty key reports arrive through the existing `.csi` state with final byte `u`, so `csiCode(finalByte:params:)` grows a `u` branch. Kitty also upgrades the tilde and arrow/navigation forms the legacy parser already decodes (`CSI number ; modifiers ~`, `CSI 1 ; modifiers A`), adding event-type and alternate-key sub-parameters. That is the real parsing work: Kitty separates parameters with `;` but sub-parameters with `:` (`unicode-key:shifted:base ; modifiers:event-type u`), and the existing `csiParameterValues` helper splits on `;` and `Int`-parses only — parameter parsing must become colon-aware without breaking the legacy paths that reuse it.

The parser should not require proof that Kitty mode is enabled before decoding a valid Kitty keyboard sequence. The input stream is the source of truth: if a terminal sends a well-formed Kitty report, decode it. Lifecycle state can decide what Tessera asks the terminal to send; parser state should decide what bytes mean.

## Fallback behavior

Kitty keyboard support must be opportunistic. If a terminal ignores the enable sequence, Tessera still has the Phase 2 legacy keyboard parser. That fallback path is not a degraded implementation detail; it is a first-class compatibility story.

This also means the public event model must tolerate mixed input. A terminal might support some Kitty features but not all of them, or a multiplexer might pass through some sequences and rewrite others. Tessera should decode the best semantic event it can from each sequence, not assume an all-or-nothing mode.

## Lifecycle behavior

Kitty keyboard mode joins the optional Phase 3 protocol stack:

- Enable Kitty keyboard mode when Tessera enters application terminal mode.
- Disable or pop Kitty keyboard mode during normal teardown.
- Disable or pop Kitty keyboard mode from cleanup handlers after abnormal exit.
- Keep cleanup safe if startup fails after enabling the protocol but before the terminal fully starts.

Concretely, this is the `.kittyKeyboard` mode case in `ModeLifecycle`, wired like the previous three slices. One asymmetry to respect: enable is a push and disable is a pop, so the emergency-teardown bytes built by `installCleanup()` include one pop for the one push the session performed. Keep `.kittyKeyboard` out of `TerminalApplicationConfiguration.default` until slice 6 settles the enablement policy (`keyboardProtocol: .kittyIfAvailable` is the intended end state).

A reasonable teardown order is:

1. Restore Kitty keyboard protocol state.
2. Disable mouse tracking.
3. Disable focus tracking.
4. Disable bracketed paste.
5. Continue with the existing alternate-screen, cursor/style reset, and raw-mode restore sequence from Phase 2.

Keyboard protocol cleanup comes first because it affects how subsequent typed input would be encoded if teardown stalls or the process drops into a debugger.

## Tests

Add encoder/lifecycle tests for:

- Kitty keyboard enable emits the exact chosen progressive-enhancement sequence
- Kitty keyboard disable/pop emits the exact chosen restoration sequence
- startup emits Kitty keyboard enable in the documented ordering
- teardown emits Kitty keyboard restore in the documented ordering
- cleanup path restores Kitty keyboard state
- partial startup failure still restores Kitty keyboard state

Add parser tests for:

- plain character key report
- modified character key report
- arrow/function/navigation key reports
- shift/alt/control/super/hyper/meta modifiers where representable
- press/repeat/release event kinds where supported by the chosen flags
- mixed legacy and Kitty input in the same parser stream
- Kitty sequences split byte-by-byte
- malformed Kitty sequences follow the existing unknown-sequence policy
- Kitty-looking bytes inside bracketed paste payload do not emit key events

## Non-goals

Do not delete or de-prioritize the legacy parser. Kitty keyboard is opt-in and not universal. The legacy path remains the compatibility baseline.

Do not build application shortcut routing yet. This slice reports better key events; Phase 4 and Phase 5 can decide how shortcuts are matched, propagated, or intercepted.

Do not attempt a full global keyboard taxonomy unless the implementation needs it. Add public key cases deliberately, with tests and motivating sequences.

Do not make startup depend on a successful capability query. Capability detection is slice 6. This slice should work by enabling the protocol, decoding it if it appears, and falling back gracefully if it does not.

## End of Slice 4

`TesseraTerminal` can opt into Kitty keyboard reporting, restore the previous keyboard protocol state on exit, decode modern keyboard reports into richer `Key` values, and keep the legacy parser as a reliable fallback for terminals that do not participate.
