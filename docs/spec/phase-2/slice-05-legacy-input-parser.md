---
type: spec
description: "Slice 5: Legacy input parser (escape sequences, arrow keys, function keys, modifiers)"
---

# Slice 5: Legacy input parser (escape sequences, arrow keys, function keys, modifiers)

Slice 5 is where Tessera learns to listen. Slice 2 turned semantic operations into bytes flowing out; slice 5 turns bytes flowing in back into semantic events. It's the mirror image, but the asymmetry we discussed earlier (different vocabularies, no real parser-printer duality) means the design lands in a different place — a state machine, not a reversed encoder.

This slice is also where you start hitting the historical sediment of the terminal world. Input encoding is a mess of overlapping, contradictory, and ambiguous protocols accumulated over five decades. The discipline here is to handle the _legacy_ layer correctly and completely, knowing that Phase 3's Kitty keyboard protocol will eventually augment it — but only on terminals that support it.

## The four problems this slice solves

> [!note] Ratatui References
>
> - Ratatui itself has no input layer — it delegates entirely to crossterm. The `Event` enum (`crossterm` `src/event.rs`, line 550) is the top-level type: `Key(KeyEvent)`, `Mouse(MouseEvent)`, `Resize(u16, u16)`, `Paste(String)`, `FocusGained`/`FocusLost`.
> - The four problems map directly to crossterm's design: (1) byte-by-byte buffering is handled by the `Parser` struct (`src/event/source/unix/mio.rs`, line 168) which accumulates bytes in a `Vec<u8>` buffer until `parse_event` succeeds; (2) ESC ambiguity is resolved by the `input_available` parameter to `parse_event` (`src/event/sys/unix/parse.rs`, line 26) — when no more bytes are pending, bare ESC emits `KeyCode::Esc`; (3) irregular modifier encoding is handled by `parse_modifiers` (`src/event/sys/unix/parse.rs`, line 313) which decodes the semicolon-separated modifier mask; (4) UTF-8 assembly is in `parse_utf8_char` (`src/event/sys/unix/parse.rs`, line 825) which validates continuation bytes against the expected sequence length.

1. **Multi-byte sequences arrive byte-by-byte.** A press of the up arrow generates the three bytes `\e [ A`. They may arrive in one `read(2)` call or three separate ones depending on buffering, network conditions (ssh), and terminal implementation. The parser must buffer partial sequences and complete them across reads.

2. **The ESC ambiguity.** A bare ESC byte is both "the user pressed Escape" and "the beginning of an escape sequence." You can't know which until you wait for more bytes — or wait long enough that you're confident none are coming. This is the single most annoying design problem in terminal input handling, and there's no clean solution, only better and worse tradeoffs.

3. **Legacy modifier encoding is irregular.** Shift+Tab is `\e[Z`. Ctrl+A is `\x01` (a single byte, no escape at all). Alt+a is `\e a` (escape followed by literal 'a'). Ctrl+Shift+arrow is `\e[1;6A` (semicolon-separated modifier parameter). Each of these is its own format. The parser needs a table-driven approach because there's no underlying grammar to exploit.

4. **Unicode input from paste or IME.** A user typing or pasting "你好" sends UTF-8 multi-byte sequences that are _not_ escape sequences and need to be assembled into graphemes. The parser needs to distinguish "byte is part of a UTF-8 character" from "byte is part of an escape sequence" — usually trivial (escape sequences are ASCII-only) but worth being explicit about.

## The shape: a streaming state machine

> [!note] Ratatui References
>
> - crossterm's parser is not exposed as a public type — it's a private `Parser` struct (`src/event/source/unix/mio.rs`, line 168) with a `buffer: Vec<u8>` and `internal_events: VecDeque<InternalEvent>`. It implements `Iterator`, yielding `InternalEvent` items. This is the Rust equivalent of Tessera's `InputParser`.
> - The `advance` method (`src/event/source/unix/mio.rs`, line 198) feeds bytes one at a time into `parse_event`, clearing the buffer on success or keeping it on `Ok(None)` (partial sequence). This is the same byte-by-byte streaming pattern Tessera uses with `feed(_:)`.
> - Unlike Tessera's pull-model `feed` returning `[InputEvent]`, crossterm's parser pushes completed events into a `VecDeque` and yields them via `Iterator::next()`. Tessera's design is cleaner for async — the caller drives the stream, the parser doesn't own time.

The parser is a struct with mutable state that consumes bytes one at a time and yields events when sequences complete. Concretely:

```swift
public struct InputParser: Sendable {
    public init()

    /// Feeds a byte. Returns events that completed with this byte.
    /// One byte may complete zero events (mid-sequence) or one event.
    public mutating func feed(_ byte: UInt8) -> [InputEvent]

    /// Forces any pending sequence to resolve.
    /// Used when input pauses (timeout) — bare ESC resolves as Escape key.
    public mutating func flush() -> [InputEvent]
}
```

A few load-bearing properties:

- **The parser is a `struct`, not an actor.** Single-threaded by construction (called from one place: the input task in `PlatformIO`). No need for concurrency primitives.
- **`feed` returns events, doesn't yield them.** Pull model, not push. The caller is the input task, which already drives an `AsyncStream<InputEvent>`; pushing into a stream from inside the parser would conflate concerns.
- **`flush` is the ESC-ambiguity escape valve.** When input pauses (no bytes for ~25-50ms after an ESC), `flush` resolves the dangling ESC as a literal Escape keypress.
- **No `reset`.** The parser is always in a valid state; partial sequences are pending data, not errors.

## The `InputEvent` type

> [!note] Ratatui References
>
> - crossterm's `KeyEvent` struct (`src/event.rs`, line 937) is the direct analog of Tessera's `Key`: it carries `code: KeyCode`, `modifiers: KeyModifiers`, `kind: KeyEventKind` (Press/Repeat/Release), and `state: KeyEventState` (keypad, caps-lock, num-lock). Tessera's Phase 2 drops `kind` and `state` — those are Phase 3 (Kitty protocol).
> - `KeyCode` enum (`src/event.rs`, line 1226) covers: `Char(char)`, `Backspace`, `Enter`, `Left`/`Right`/`Up`/`Down`, `Home`, `End`, `PageUp`, `PageDown`, `Tab`, `BackTab`, `Delete`, `Insert`, `F(u8)`, `Esc`, `Null`, plus Kitty-only keys (`CapsLock`, `Media`, `Modifier`). Tessera's Phase 2 `KeyCode` is a subset of this.
> - `KeyModifiers` (`src/event.rs`, line 840) is a `bitflags` OptionSet with `SHIFT`, `CONTROL`, `ALT`, `SUPER`, `HYPER`, `META`. Tessera's Phase 2 uses only `shift`, `alt`, `control` — matching what legacy protocols can report.
> - `KeyEvent::normalize_case()` (`src/event.rs`, line 973) encodes the same "shift only for non-character keys" convention Tessera documents: uppercase chars get SHIFT added, lowercase with SHIFT get uppercased.

This is the slice's other load-bearing public API. For Phase 2 (legacy only):

```swift
public enum InputEvent: Sendable, Equatable {
    case key(Key)
    case resize(TerminalSize)            // yielded by PlatformIO, not the parser
    case unknown(bytes: [UInt8])         // unrecognized sequence; surface for debugging
}

public struct Key: Sendable, Equatable {
    public let code: KeyCode
    public let modifiers: Modifiers

    public init(code: KeyCode, modifiers: Modifiers = [])
}

public enum KeyCode: Sendable, Equatable {
    case char(Character)                  // printable character (post-UTF-8-assembly)
    case enter
    case tab
    case backspace
    case escape
    case left, right, up, down
    case home, end
    case pageUp, pageDown
    case insert, delete
    case f(Int)                            // F1-F12
}

public struct Modifiers: OptionSet, Sendable {
    public let rawValue: UInt8

    public init(rawValue: UInt8)

    public static let shift   = Modifiers(rawValue: 1 << 0)
    public static let alt     = Modifiers(rawValue: 1 << 1)
    public static let control = Modifiers(rawValue: 1 << 2)
}
```

Design notes:

- **`KeyCode.char` carries a `Character`, not a byte.** UTF-8 assembly happens _inside_ the parser; consumers see graphemes. Same logic as the buffer: terminals deal in graphemes, so we do too.
- **No `super`/`meta`/`hyper` modifiers.** Legacy protocols can't represent them; Phase 3's Kitty support will add them.
- **No `KeyCode.unknown` — there's `InputEvent.unknown` instead.** A recognized key with unrecognized modifiers is still a recognized key. Unknown is reserved for "bytes that don't fit any known sequence shape."
- **Shift is included as a modifier but is often redundant.** `Key(.char("A"), [.shift])` and `Key(.char("A"), [])` represent the same thing visually. Convention: shift modifier is set _only_ for non-character keys (Shift+Tab, Shift+Arrow). For letters, the case carries the shift information. This is what legacy protocols actually report, and trying to normalize is a losing battle.

## Input backpressure policy

The input layer must not treat every source as one unbounded FIFO. Classify events by pressure policy:

1. **Ordered semantic input is preserved.** Key events, focus gained/lost, explicit app events, and bracketed paste represent user intent. Tessera must not silently drop them. If an ordered semantic queue reaches its bound, surface overflow explicitly rather than losing input.
2. **Latest-value events are coalesced.** Resize and capability updates are state-like: if several arrive before the app processes them, only the latest meaningful value needs to be delivered.
3. **Noisy streams are bounded and usually opt-in.** Mouse movement and high-frequency drag streams can overwhelm an app. Preserve button events, coalesce movement by default, and make any-event/high-fidelity mouse tracking opt-in.

Bracketed paste is parsed as a semantic paste event or bounded paste chunks in Phase 3, never as a flood of fake keypresses. Phase 2 only documents the policy because bracketed paste and mouse protocols land in Phase 3.

## The state machine

> [!note] Ratatui References
>
> - crossterm doesn't use an explicit enum for parser states — the state machine is implemented as a series of match branches in `parse_event` (`src/event/sys/unix/parse.rs`, line 26). The `.ground` state is the top-level `match buffer[0]`; `.escape` is the `b'\x1B'` branch (line 31); `.csi` is the `parse_csi` function (line 137); `.ss3` is the `b'O'` sub-branch inside escape (line 48). The implicit state is carried by which function is called and the remaining buffer slice.
> - The `.utf8` state is handled by `parse_utf8_char` (`src/event/sys/unix/parse.rs`, line 825) which validates continuation bytes against expected sequence lengths (2, 3, or 4 bytes based on leading byte). Returns `Ok(None)` when more bytes needed — the caller's buffer retains the partial sequence.
> - Tessera's explicit state enum (`.ground`, `.utf8`, `.escape`, `.csi`, `.ss3`) is a cleaner design than crossterm's implicit state-in-the-call-stack, making it easier to reason about and test.

Conceptually, the parser is in one of these states:

- **`.ground`** — waiting for a fresh byte. ASCII control char → emit. Printable ASCII → emit. UTF-8 leading byte → enter `.utf8`. ESC → enter `.escape`.
- **`.utf8(expectedBytes: Int, accumulated: [UInt8])`** — assembling a multi-byte UTF-8 character. Each continuation byte advances; once complete, decode and emit as `.char(...)`.
- **`.escape`** — saw an ESC, waiting to disambiguate. `[` → enter `.csi`. `O` → enter `.ss3` (function keys F1-F4 on some terminals). Letter → Alt+letter, emit and return to `.ground`. Anything else weird → emit Escape + the byte separately.
- **`.csi(params: String, intermediates: String)`** — inside a CSI sequence (`\e[...`). Accumulate parameter bytes (digits + `;`), then a final byte (`A`-`Z`, `~`) triggers lookup-and-emit.
- **`.ss3`** — saw `\eO`, expecting one letter. The letter selects a function key (`P`=F1, `Q`=F2, `R`=F3, `S`=F4).

Per-state transition tables make this implementation tedious but straightforward. The trick is to keep the state machine _small_ — handle only what real terminals actually send, fall through to `.unknown` for everything else, and refine over time.

## The legacy sequence catalog

> [!note] Ratatui References
>
> - ASCII control range: `parse_event` handles `b'\x01'..=b'\x1A'` as Ctrl+letter (line 97), `b'\x1C'..=b'\x1F'` as Ctrl+4..Ctrl+/ (line 101), `b'\r'`/`b'\n'` as Enter (lines 82–88), `b'\t'` as Tab (line 90), `b'\x7F'` as Backspace (line 92), and `b'\0'` as Ctrl+Space (line 105). Matches Tessera's catalog exactly.
> - CSI arrows: `parse_csi` handles `\e[A`/`B`/`C`/`D` as Up/Down/Right/Left (line 146), `\e[H`/`\e[F` as Home/End (line 150), `\e[Z` as Shift+Tab/BackTab (line 155).
> - CSI tilde keys: `parse_csi_special_key_code` (line 619) maps `1~`/`7~`→Home, `2~`→Insert, `3~`→Delete, `4~`/`8~`→End, `5~`→PageUp, `6~`→PageDown, and ranges `11~`–`26~` to F1–F12. Matches Tessera's vt220-style catalog.
> - SS3 function keys: the `b'O'` branch in `parse_event` (line 48) handles `\eOP`–`\eOS` as F1–F4 and `\eOA`–`\eOD` as arrows in application mode (lines 51–68).
> - CSI modifier keys: `parse_csi_modifier_key_code` (line 348) parses `\e[1;<mods>A` etc. with `parse_modifiers` (line 313) decoding the mask. Matches Tessera's modifier scheme.

The concrete set of sequences the parser needs to recognize for Phase 2:

### ASCII control range (single bytes)

- `0x00..0x1F` (except 0x09 Tab, 0x0A/0x0D Enter, 0x1B ESC, 0x7F Backspace): Ctrl+letter. `Ctrl+A` = `0x01`, `Ctrl+B` = `0x02`, ..., `Ctrl+Z` = `0x1A`. Compute as `byte + 0x40` to get the letter.
- `0x09`: Tab.
- `0x0A` (LF) and `0x0D` (CR): both Enter. Terminals differ on which they send; treat both as Enter.
- `0x7F` (DEL): Backspace. (Counterintuitively. The "Backspace" key on most keyboards sends DEL; the `0x08` BS code is rarely sent.)
- `0x08` (BS): Ctrl+H, which is also sometimes Backspace. Emit Ctrl+H; let the application decide.
- `0x1B` (ESC) alone: handled via the `.escape` state and timer.

### ESC + letter (Alt+letter)

- `\e<letter>`: Alt+letter. `\ea` = Alt+a.
- This is the source of the ESC ambiguity. Distinguishing "Alt+a" from "Escape then a" requires the timer.

### CSI sequences (\e[ ...)

- `\e[A` / `B` / `C` / `D`: Up / Down / Right / Left.
- `\e[H` and `\e[F`: Home and End (xterm style).
- `\e[1~`, `\e[4~`: Home and End (vt220 style — some terminals use this).
- `\e[2~`, `\e[3~`: Insert and Delete.
- `\e[5~`, `\e[6~`: PageUp and PageDown.
- `\e[Z`: Shift+Tab (the one truly weird one).
- `\e[11~`..`\e[15~`, `\e[17~`..`\e[21~`, `\e[23~`, `\e[24~`: F1-F12 (vt220 style).
- `\e[1;<mods><letter>`: arrow/home/end with modifiers. Mods encoded as `2`=Shift, `3`=Alt, `4`=Shift+Alt, `5`=Ctrl, `6`=Shift+Ctrl, `7`=Alt+Ctrl, `8`=Shift+Alt+Ctrl. So `\e[1;5A` is Ctrl+Up.
- `\e[<N>;<mods>~`: same modifier scheme for tilde-style keys. `\e[3;5~` is Ctrl+Delete.

### SS3 sequences (\eO ...)

- `\eOP`, `\eOQ`, `\eOR`, `\eOS`: F1-F4 (xterm application-mode style).
- `\eOA`/`B`/`C`/`D`: arrows in application keypad mode. Rare but worth handling.

### UTF-8 multi-byte

- Leading byte `0xC2..0xF4` → 2-, 3-, or 4-byte sequence. Standard UTF-8 decoding.

That's the Phase 2 catalog. Roughly 40-50 distinct recognized sequences. Phase 3 adds bracketed paste (`\e[200~ ... \e[201~`), SGR mouse (`\e[<...M` / `m`), focus (`\e[I` / `\e[O`), and Kitty keyboard (`\e[<unicode>;<mods>;<text>u` — a whole new world).

## The ESC ambiguity, in detail

> [!note] Ratatui References
>
> - crossterm resolves ESC ambiguity in `parse_event` (`src/event/sys/unix/parse.rs`, lines 31–35): when the buffer is exactly `[0x1B]` (length 1), it checks the `input_available` boolean — `false` (no more bytes pending) emits `KeyCode::Esc`, `true` (more bytes may arrive) returns `Ok(None)` to wait. The timeout that determines "are more bytes coming?" is the `poll` timeout in `UnixInternalEventSource::try_read` (`src/event/source/unix/mio.rs`, line 68) which uses `PollTimeout` (`src/event/timeout.rs`, line 5).
> - Unlike Tessera's explicit 25ms configurable timeout in the input task, crossterm's timeout is whatever the caller passes to `poll()` — there's no built-in ESC-specific timeout. The `EventStream` async type (`src/event/stream.rs`, line 33) polls with zero timeout and relies on mio's readiness notification, which means ESC latency depends on when the next byte arrives (no explicit timeout flush).
> - `KeyboardEnhancementFlags::DISAMBIGUATE_ESCAPE_CODES` (`src/event.rs`, line 292) is the Phase 3 escape hatch: when enabled, Escape sends `\e[27u` which is unambiguous. Tessera mirrors this with Kitty protocol support.

The standard solution is a timeout: after receiving a bare ESC, wait some number of milliseconds for more bytes. If something arrives within the window, it's an escape sequence; if not, it's a literal Escape keypress.

The classic value is 25-50ms. Lower than ~25ms and you get false positives on slow connections (ssh over a bad link). Higher than ~50ms and the Escape key feels laggy. **Tessera's choice: 25ms by default, configurable.**

Where the timer lives matters. It can't live in `InputParser` because the parser is synchronous and doesn't own time. It lives in the _input task_ in `PlatformIO`:

```text
inputLoop:
    poll(stdin, timeout: parserHasPendingEscape ? 25ms : 100ms)
    if readable:
        read bytes, feed to parser, yield events
        parserHasPendingEscape = (parser is in .escape state)
    else if timeout:
        if parserHasPendingEscape:
            events = parser.flush()
            yield events
            parserHasPendingEscape = false
```

The parser exposes "am I in a pending-escape state?" via a property; the input task adjusts its poll timeout accordingly. Clean separation: parser knows shapes, task knows time.

There's a sharper alternative — _Kitty keyboard protocol_ in Phase 3 eliminates ESC ambiguity entirely by sending Escape as `\e[27u`. Once enabled, the timer can be set to 0. Worth noting in a comment, but not relevant to slice 5.

## A note on bracketed paste (which is _not_ in slice 5)

Without bracketed paste enabled, when a user pastes a block of text, every character arrives as individual keystrokes. There's no way to distinguish typed from pasted input. This is _fine_ for slice 5 — the parser correctly emits N `KeyCode.char` events for an N-character paste, and the application handles them like any other input.

The bracketed paste mode (`\e[?2004h`) makes the terminal wrap pasted content in `\e[200~ ... \e[201~`, letting the parser emit a single `InputEvent.paste(String)` event. That's Phase 3 territory. Slice 5 just needs to _not preclude_ this — which it doesn't, because the parser's escape-sequence handling already extends cleanly.

## Wiring into `PlatformIO`

> [!note] Ratatui References
>
> - crossterm's `InternalEventReader` (`src/event/read.rs`, line 12) is the singleton that wraps the platform-specific `EventSource` and provides `poll()` and `read()` methods. It's held behind a `parking_lot::Mutex` as a static (`src/event.rs`, line 149) — only one event reader exists per process.
> - `UnixInternalEventSource` (`src/event/source/unix/mio.rs`, line 24) uses mio's `Poll` to multiplex stdin (TTY_TOKEN), SIGWINCH signals (SIGNAL_TOKEN), and an optional waker (WAKE_TOKEN). On SIGWINCH, it calls `crate::terminal::size()` and yields `Event::Resize(columns, rows)` (line 123). This is the same pattern Tessera uses: unify keyboard input and resize events into one stream.
> - The `EventStream` async type (`src/event/stream.rs`, line 33) implements `futures_core::stream::Stream` and spawns a background thread that blocks on `poll_internal` and wakes the async task when events arrive. This is the closest analog to Tessera's `AsyncStream<InputEvent>`.

Slice 3 gave you `PlatformIO.bytes: AsyncStream<[UInt8]>`. Slice 5 layers on top — at package level, with `TerminalSession` as the public surface, consistent with the ownership thesis (raw byte access must not be public API):

```swift
package extension PlatformIO {
    var events: AsyncStream<InputEvent> { get }
}

public extension TerminalSession {
    /// The session's semantic event stream. `nextEvent()` remains as sugar over it.
    var events: AsyncStream<InputEvent> { get }
}
```

The implementation is the input task we sketched: read bytes, feed parser, yield events, manage timeout for ESC ambiguity. The package-level `bytes` stream stays available internally for code that bypasses the parser (rare but legitimate — Phase 3's Kitty support might need this).

One throughput note, normative for this slice: the event pipeline must not pay one `AsyncStream` continuation yield per input byte. Slice 3's per-byte `bytes` stream is fine for a walking skeleton, but a large paste (Phase 3) or fast mouse drag delivers kilobytes per read, and per-byte yields plus a `[InputEvent]` allocation per `feed(_:)` call is the hot spot. The input task should feed the parser whole read buffers (`feed(contentsOf: ArraySlice<UInt8>) -> [InputEvent]` or equivalent) and yield events, not re-consume the per-byte stream. If the per-byte `bytes` stream loses its remaining internal consumers in the process, change it to chunked yields (`AsyncStream<[UInt8]>`) rather than keeping a per-byte API alive for sentiment.

A `SIGWINCH` arriving via the cleanup-registry mechanism also yields an `InputEvent.resize(TerminalSize)` through the same stream. This unifies "user input" and "terminal state changes" into one event channel — exactly what application code wants.

## Testing strategy

> [!note] Ratatui References
>
> - crossterm's parser tests live in the `#[cfg(test)] mod tests` block at the bottom of `src/event/sys/unix/parse.rs` (line 1183). They cover: `test_esc_key` (bare ESC), `test_possible_esc_sequence` (ESC with more bytes pending), `test_alt_key` (Alt+letter), `test_parse_csi` (arrow keys), `test_parse_csi_modifier_key_code` (modified arrows), `test_parse_csi_special_key_code` (tilde keys), `test_parse_csi_focus` (focus events), `test_utf8` (multi-byte UTF-8 validation), `test_parse_char_event_uppercase` (shift convention), and CSI-u encoded key tests (Kitty protocol).
> - The `test_parse_event_subsequent_calls` test (line 1205) feeds complete byte sequences and asserts the parsed event — the golden-test pattern Tessera describes.
> - crossterm lacks explicit multi-byte split tests (feeding `[0x1b]`, then `[0x5b, 0x31]`, then `[0x35, 0x41]` separately). Tessera's spec calls these out explicitly as a test category — a worthwhile addition over crossterm's coverage.

The parser is the most fixture-heavy module in the library. The shape of the tests:

- **Per-sequence golden tests.** For every entry in the catalog, feed the byte sequence and assert the emitted event. ~50 tests, mechanical.
- **Multi-byte split tests.** Feed `\e[1;5A` as three separate `feed` calls: `[0x1b]`, `[0x5b, 0x31, 0x3b]`, `[0x35, 0x41]`. Assert no premature events, final event is Ctrl+Up. Catches "parser assumes whole sequence in one call" bugs.
- **ESC-ambiguity tests.** Feed `\e`, no more bytes, call `flush()`, assert Escape keypress. Feed `\e`, then `a`, assert Alt+a (no flush). Feed `\e`, flush, feed `a`, assert Escape then 'a' (two separate events).
- **UTF-8 tests.** Feed multi-byte UTF-8 characters byte-by-byte; assert single `.char` event with correct grapheme.
- **Unknown-sequence tests.** Feed garbage like `\e[99X`; assert `InputEvent.unknown` with the captured bytes.
- **Integration test via `PlatformIO`.** With a fake stdin source, feed byte streams, assert events flow through correctly with realistic timing.

Roughly 60-80 tests for the parser. Most are tiny. The whole test file becomes the de facto specification of what Tessera accepts as input.

## Definition of done for slice 5

1. `InputEvent`, `Key`, `KeyCode`, `Modifiers` public types.
2. `InputParser` struct with `feed(_:)` and `flush()` methods, state machine implementation, full Phase 2 sequence catalog.
3. `PlatformIO.events: AsyncStream<InputEvent>` derived from `bytes`, with ESC-timeout handling in the input task.
4. `SIGWINCH` yields `InputEvent.resize` through the same stream.
5. ~60-80 tests covering: every catalog sequence, multi-byte splits, ESC ambiguity, UTF-8 assembly, unknown sequences, end-to-end via `PlatformIO`.
6. Phase 1 walking skeleton is updated: evolve the minimal byte parser loop into `for await event in io.events`. Arrow keys now work. Ctrl-C still triggers SIGINT (handled by the signal handler, restoring the terminal). Escape-to-exit works without 200ms lag.

## What's not in this slice

> [!note] Ratatui References
>
> - crossterm's bracketed paste is behind the `bracketed-paste` feature flag. `EnableBracketedPaste` (`src/event.rs`, line 421) emits `\e[?2004h`; `DisableBracketedPaste` emits `\e[?2004l`.
> - The parser function `parse_csi_bracketed_paste` (`src/event/sys/unix/parse.rs`, line 813) looks for `\e[200~` prefix and `\e[201~` suffix, extracting the pasted string between them. Returns `Ok(None)` if the closing marker hasn't arrived yet (partial paste).
> - The `Event::Paste(String)` variant is conditionally compiled with `#[cfg(feature = "bracketed-paste")]` on the `Event` enum (line 550). Tessera's design of deferring this to Phase 3 mirrors crossterm's feature-gated approach.

- **Bracketed paste.** Phase 3.
- **SGR mouse events.** Phase 3.
- **Focus events.** Phase 3.
- **Kitty keyboard protocol.** Phase 3.
- **Mode-aware parsing.** Some sequences are ambiguous between protocols; once Phase 3 adds Kitty support, the parser will need to know which mode is active. Not yet.
- **IME / dead keys / composition input.** Tessera receives whatever the terminal sends; if the terminal does IME natively (as macOS Terminal does for some methods), we get the composed result. If the terminal sends raw scan codes, we don't try to compose. This is a terminal concern.
- **Bidirectional text handling.** Not Tessera's job — the terminal renders, we just feed it bytes.

## Three things to flag

> [!note] Ratatui References
>
> - ESC timeout: crossterm has no configurable ESC timeout — the resolution depends entirely on the caller's `poll` timeout. `EventStream` uses zero-timeout polling with mio readiness, so ESC latency is unbounded (waits for next byte forever). This is a known limitation; crossterm relies on Kitty protocol (`DISAMBIGUATE_ESCAPE_CODES`, line 292) as the proper fix rather than tuning a timeout.
> - Shift modifier convention: `KeyEvent::normalize_case()` (`src/event.rs`, line 973) and `char_code_to_event()` (`src/event/sys/unix/parse.rs`, line 112) both implement the "uppercase char implies SHIFT" convention. crossterm's `PartialEq` for `KeyEvent` (line 1003) normalizes before comparison, so `KeyEvent(Char('A'), SHIFT)` equals `KeyEvent(Char('A'), NONE)` — the equivalence Tessera's spec describes.
> - Unknown events: crossterm does not have an equivalent to `InputEvent.unknown(bytes:)`. Unrecognized sequences cause `parse_event` to return `Err` (line 26), which propagates as an `io::Error` from `read()`. The `Parser::advance` method (line 198) silently clears the buffer on error and moves on. Tessera's choice to surface unknown bytes is a deliberate improvement over this behavior.

1. **The 25ms ESC timeout is the single most user-visible knob in the library**, and the default matters. 25ms is responsive but can cause false positives on slow ssh; 100ms is safe but makes Escape feel sticky. I'd ship 25ms and surface the configuration prominently in docs. The Kitty keyboard escape hatch (Phase 3) eliminates the tradeoff entirely; nudging users toward Kitty-capable terminals is a long-term win.

2. **The "shift modifier is set only for non-character keys" convention is the kind of thing that will confuse exactly one user per year, forever.** It's the correct behavior — matching what legacy terminals actually send — but worth a prominent doc-comment example. Phase 3's Kitty protocol fixes this too (reports shift always), but for the legacy layer, the convention has to hold.

3. **`InputEvent.unknown(bytes:)` as a public case** is a deliberate choice to surface protocol gaps rather than swallow them. The cost is that _any_ unrecognized sequence becomes part of the public API surface and users may pattern-match on it. The win is enormous for debugging — when someone files "my key doesn't work," they can `print(event)` and immediately see the bytes. I think this is the right trade, but worth noting it commits us to keeping that case in the API forever.
