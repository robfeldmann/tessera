---
type: spec
description: "Slice 2: ANSI Encoder"
---

# Slice 2: ANSI Encoder

Slice 2 is where you start building the only piece of the codebase that's allowed to know what an ANSI escape sequence looks like. Get the encoder's _shape_ right and the rest of `TesseraTerminal` falls into place; get it wrong and you'll be plumbing escape codes through five layers forever.

## What the encoder is, in one sentence

> [!note] Ratatui References
>
> - The `Backend` trait (`ratatui-core/src/backend.rs`, line 157) defines the contract for drawing, cursor movement, and clearing — the encoder is what fulfills this contract by producing the bytes that each backend method emits.
> - `CrosstermBackend` (`ratatui-crossterm/src/lib.rs`, line 160) wraps a `Write` and delegates to crossterm's `queue!`/`execute!` macros (line 85) to emit sequences. The Tessera encoder replaces this delegation: instead of calling into crossterm, we produce the bytes ourselves.
> - The `Backend::draw` method (`ratatui-crossterm/src/lib.rs`, line 232) iterates cells and emits `MoveTo`, `SetColors`, and `Print` — exactly the kind of "semantic operation → bytes" mapping the encoder encapsulates.

A pure, synchronous, zero-I/O module that turns semantic terminal operations (`cursorPosition(TerminalPosition(column: 10, row: 5))`, `setForeground(.red)`, `enterAltScreen`) into the exact bytes that produce them. **It does not write anywhere. It does not allocate file handles. It does not know what a `PlatformIO` is.** Bytes in, bytes out — that's the whole interface to the rest of the system.

This isolation is what makes the encoder testable against golden fixtures and what lets the snapshot harness exist: every normal byte your program emits flows through this module, so testing this module covers everything downstream. The one deliberate exception is `RawTerminalPayload`, which still flows through the renderer/session but carries bytes Tessera does not semantically understand yet.

## The shape question: enum vs. free functions vs. builder

> [!note] Ratatui References
>
> - Ratatui delegates to crossterm's `Command` trait, whose load-bearing API is `write_ansi(&self, ...)` plus a Windows-only `execute_winapi` fallback (`crossterm` `src/command.rs`, lines 12–27). Concrete command types like `MoveTo`, `Hide`, `Show`, `SetColors`, `Clear`, and `Print` are the closest analogue to Option A (enum with associated values): each is semantic data that knows how to encode itself.
> - The `CrosstermBackend::draw` method (`ratatui-crossterm/src/lib.rs`, lines 232–292) builds a sequence of commands per cell — `MoveTo`, modifier diffs, color changes, `Print` — and queues them into a single buffer. This is exactly the "compose sequences as data" pattern Option A enables.
> - `ModifierDiff` (`ratatui-crossterm/src/lib.rs`, line 535) computes the minimal set of attribute changes between two `Modifier` states and queues only the deltas. The Tessera renderer (slice 4) will need equivalent diffing logic, which is natural when sequences are data (Option A) rather than side effects.

There are three reasonable Swift idioms here, and the choice matters because every other layer of the stack will be calling into this one.

**Option A: enum with associated values + a single `encode` function.**

```swift
public enum EraseMode: Sendable, Equatable {
    case toEnd
    case toBeginning
    case all
    case allAndScrollback
}

public enum ControlSequence: Sendable, Equatable {
    case cursorPosition(TerminalPosition)
    case cursorVisible(Bool)
    case eraseInDisplay(EraseMode)
    case setForeground(Color)
    case enterAltScreen
    // ... ~30 cases total for Phase 2
}

public enum ANSIEncoder {
    public static func encode(_ sequence: ControlSequence, into buffer: inout [UInt8])
}
```

**Option B: free functions returning bytes.**

```swift
public enum ControlSequence {
    public static func cursorPosition(_ position: TerminalPosition, into: inout [UInt8])
    public static func enterAltScreen(into: inout [UInt8])
    // ...
}
```

**Option C: a builder/writer type.**

```swift
public struct SequenceWriter {
    public mutating func cursorPosition(_ position: TerminalPosition)
    public mutating func enterAltScreen()
    public func finish() -> [UInt8]
}
```

**My recommendation: Option A.** Reasons:

1. **The renderer wants to compose sequences as data, not effects.** A damage-tracking renderer in slice 4 will build up a `[ControlSequence]` representing "what changed this frame" before emitting bytes. That's natural with an enum, awkward with free functions, and a category error with a builder.
2. **Equatable enum cases make tests legible.**

   ```swift
   #expect(sequences == [
       .cursorPosition(TerminalPosition(column: 0, row: 0)),
       .setForeground(.red),
       .text("hi"),
   ])
   ```

   That reads beautifully. Comparing byte arrays in tests is much worse.

3. **Exhaustive `switch` in the encoder.** When you add a new sequence in Phase 3 (Kitty keyboard, say), the compiler tells you exactly where to handle it. Free functions silently let you forget.
4. **It mirrors how every mature terminal library models this** — Ratatui's `Command`, crossterm's `Command`, vty libraries' opcodes. It's the load-bearing abstraction in this domain.

The one downside is allocation: building `[ControlSequence]` per frame is more allocation than streaming directly to a byte buffer. Premature concern. If profiling later shows it matters, you can add a streaming fast-path alongside without breaking the enum API.

## The encoding interface

> [!note] Ratatui References
>
> - The `Backend::draw` signature (`ratatui-core/src/backend.rs`, line 183) takes an iterator of `(u16, u16, &Cell)` — the crossterm backend consumes this and queues commands into the writer's internal buffer via `queue!` (`ratatui-crossterm/src/lib.rs`, line 85). The `encode(into: inout [UInt8])` pattern mirrors this: accumulate into a shared buffer rather than return new allocations per call.
> - `crossterm::queue!` vs `crossterm::execute!` (`ratatui-crossterm/src/lib.rs`, line 85): `queue!` buffers without flushing (used in `draw`), `execute!` flushes immediately (used in `hide_cursor`, `clear`). The Tessera encoder's `inout [UInt8]` is the queue! side — flush is the caller's responsibility.

```swift
public enum ControlSequence: Sendable, Equatable {
    // ... cases ...
}

public extension ControlSequence {
    /// Appends the bytes for this sequence to `buffer`.
    /// Pure function. Does not allocate beyond growing `buffer`.
    public func encode(into buffer: inout [UInt8])

    /// Convenience for tests and ad-hoc use.
    public var bytes: [UInt8] {
        var b: [UInt8] = []
        encode(into: &b)
        return b
    }
}
```

The `inout [UInt8]` is load-bearing — the renderer will build one big byte buffer per frame and `encode(into:)` many sequences into it. Returning fresh `[UInt8]` per call would mean N small allocations per frame. This shape costs nothing and scales.

## The Phase 2 sequence catalog

> [!note] Ratatui References
>
> - Cursor control maps to `Backend::set_cursor_position` (`ratatui-core/src/backend.rs`, line 229) and `hide_cursor`/`show_cursor` (lines 188, 202). The crossterm backend uses `MoveTo(x, y)` (`ratatui-crossterm/src/lib.rs`, line 245), `Hide` (line 295), and `Show` (line 299). The exact coordinate conversion lives in crossterm: `MoveTo` writes `CSI row;col H` and adds 1 to both zero-based fields (`crossterm` `src/cursor.rs`, lines 60–65).
> - Erase maps to `Backend::clear` (`ratatui-core/src/backend.rs`, line 259) and `clear_region` with `ClearType` (`ratatui-core/src/backend.rs`, line 121). The crossterm backend uses `Clear` from crossterm (`ratatui-crossterm/src/lib.rs`, lines 313–322); crossterm's `Clear` command maps clear types to `CSI 2J`, `CSI 3J`, `CSI J`, `CSI 1J`, `CSI 2K`, and `CSI K` (`crossterm` `src/terminal.rs`, lines 341–352).
> - SGR styling maps to the `Color` enum (`ratatui-core/src/style/color.rs`, line 69) and `Modifier` bitflags (`ratatui-core/src/style.rs`, line 104). The crossterm backend emits `SetColors` (line 259), `SetForegroundColor`/`SetBackgroundColor` (lines 280–289), and `SetAttribute` via `ModifierDiff` (line 535). The underlying crossterm commands encode colors and attributes as SGR (`crossterm` `src/style.rs`, lines 206–339).
> - Alt screen is handled by crossterm's `EnterAlternateScreen`/`LeaveAlternateScreen` (`ratatui-crossterm/src/lib.rs`, lines 127, 145) — the backend itself doesn't expose these as `Backend` trait methods; they're applied at the application level. The actual bytes are `CSI ? 1049 h/l` (`crossterm` `src/terminal.rs`, lines 218–262).
> - `Print` (`ratatui-crossterm/src/lib.rs`, line 274) is crossterm's command for literal text output — the analogue of `text(String)` as a `ControlSequence` case. Its command impl writes the display value directly (`crossterm` `src/style.rs`, line 501).

Concrete list of cases the encoder needs for Phase 2 (informed by the layer-by-layer Phase 1 work; nothing speculative):

### Cursor control

- `cursorPosition(TerminalPosition)` — CSI `row;colH` (1-indexed in the wire format; convert from 0-indexed at the boundary)
- `cursorUp(Int)`, `cursorDown(Int)`, `cursorForward(Int)`, `cursorBack(Int)`
- `cursorVisible(Bool)` — DEC private modes 25
- `cursorSave`, `cursorRestore` — DECSC/DECRC

### Erase

- `eraseInDisplay(EraseMode)` where `EraseMode` is `.toEnd | .toBeginning | .all | .allAndScrollback`
- `eraseInLine(LineEraseMode)` where `LineEraseMode` is `.toEnd | .toBeginning | .all` — a separate enum, because EL (`CSI Ps K`) has no scrollback variant and sharing `EraseMode` would make `eraseInLine(.allAndScrollback)` representable but meaningless (the unrepresentability thesis applies to the encoder too)

### SGR (styling)

- `resetAttributes` — SGR 0 (worth a dedicated case; emitted constantly)
- `setForeground(Color)`, `setBackground(Color)` — 16-color, 256-color, and truecolor variants behind a single `Color` enum
- `setBold(Bool)`, `setItalic(Bool)`, `setUnderline(Bool)`, `setReverse(Bool)`, `setDim(Bool)`, `setStrikethrough(Bool)` (Phase 3 Slice 11 replaces `setUnderline(Bool)` with `setUnderlineStyle(UnderlineStyle)` plus `setUnderlineColor(Color)`)

### Modes

- `enterAltScreen`, `exitAltScreen` — DEC private mode 1049
- `enterSynchronizedOutput`, `exitSynchronizedOutput` — DEC private mode 2026 (critical for flicker-free updates; we'll lean on this hard in the renderer)
- `enableLineWrap(Bool)` — DECAWM

### Misc

- `setWindowTitle(String)` — OSC 0/2
- `text(String)` — literal text (just appends UTF-8 bytes; included as a case so a `[ControlSequence]` can fully represent a frame's output)
- `raw(RawTerminalPayload)` — explicit escape hatch for bytes Tessera does not model yet; only emitted from a render transaction and always paired with diff policy in the buffer or frame API
- `bell` — 0x07, occasionally useful

That's roughly 25-30 semantic cases plus the raw escape hatch. Resist adding more "just in case." Phase 3 will add bracketed paste, focus, mouse, Kitty, OSC 8 as their own cases — that's the right time.

## The `Color` type

> [!note] Ratatui References
>
> - Ratatui's `Color` enum (`ratatui-core/src/style/color.rs`, line 69) has cases: `Reset`, 16 named ANSI colors (`Black` through `White`, lines 75–112), `Rgb(u8, u8, u8)` (line 118), and `Indexed(u8)` (line 124). This closely matches the spec's four-case design (`default` → `Reset`, `ansi` → named cases, `rgb`, `indexed`).
> - The `IntoCrossterm<CrosstermColor>` impl (`ratatui-crossterm/src/lib.rs`, line 408) shows the encoding mapping: `Reset` → `CrosstermColor::Reset`, named colors → crossterm's `DarkRed`/`Red` etc., `Indexed(i)` → `AnsiValue(i)`, `Rgb(r,g,b)` → `Rgb { r, g, b }`.
> - The `anstyle` conversion module (`ratatui-core/src/style/anstyle.rs`, line 1) provides bidirectional conversion between Ratatui's `Color` and `anstyle`'s `AnsiColor`/`Ansi256Color`/ `RgbColor`, confirming the three color spaces (16-color, 256-color, truecolor) are a standard split.

This is the one place where modeling decisions get fiddly. ANSI has three color spaces and they're not unified:

```swift
public enum Color: Sendable, Equatable {
    case `default`              // SGR 39 / 49
    case ansi(ANSIColor)        // 16-color: black, red, ..., brightWhite
    case indexed(UInt8)         // 256-color: any 0-255
    case rgb(UInt8, UInt8, UInt8)  // truecolor
}

public enum ANSIColor: Sendable, Equatable, CaseIterable {
    case black, red, green, yellow, blue, magenta, cyan, white
    case brightBlack, brightRed, ..., brightWhite
}

public struct TextAttributes: OptionSet, Sendable {
    public let rawValue: UInt16

    public init(rawValue: UInt16)

    public static let bold = TextAttributes(rawValue: 1 << 0)
    public static let dim = TextAttributes(rawValue: 1 << 1)
    public static let italic = TextAttributes(rawValue: 1 << 2)
    public static let underline = TextAttributes(rawValue: 1 << 3)
    public static let reverse = TextAttributes(rawValue: 1 << 4)
    public static let strikethrough = TextAttributes(rawValue: 1 << 5)
}
```

A few decisions baked in here worth flagging:

- **`default` is a first-class case**, not "fall back to ANSI 0". Resetting to default fg is a different SGR code than setting black, and confusing the two creates subtle rendering bugs.
- **`ansi` and `indexed(0..<16)` are kept distinct** even though they overlap. `ansi(.red)` emits SGR 31; `indexed(1)` emits SGR 38;5;1. Terminals may render these slightly differently (ANSI 16 typically respects user palette; indexed always uses the 256-color cube), and being explicit matters.
- **No 256-color named constants.** If a user wants `indexed(208)`, they pass 208. Naming 256 colors is a job for a _theme_ library, not the encoder.
- **No silent down-conversion inside the encoder.** If the caller asks the encoder for `rgb(...)`, the encoder emits the truecolor sequence. Capability policy belongs above the encoder: the renderer/session can choose an already-downsampled `Color` based on `NO_COLOR`, detected color depth, or user configuration before encoding.

## Raw payload escape hatch

The raw escape hatch is how Tessera avoids becoming a compatibility ceiling. It exists for terminal protocols Tessera has not modeled yet and for application-specific extensions: sixel, iTerm2 OSC 1337 inline images, future OSCs, vendor DCS payloads, or experiments.

```swift
public struct RawTerminalPayload: Sendable, Equatable {
    public let bytes: [UInt8]
    public let declaredWidth: Int?

    public init(bytes: [UInt8], declaredWidth: Int? = nil)
}
```

Rules:

- `RawTerminalPayload` is bytes, not authority. It can be encoded only as part of a render transaction; it does not expose `PlatformIO`, file descriptors, or immediate writes.
- Callers that emit raw bytes must also declare the cells or region whose display is now foreign/opaque to Tessera's normal cell model. Slice 4 defines the corresponding `CellDiffPolicy` and `Frame.writeRaw` behavior.
- Prefer a first-class semantic `ControlSequence` once Tessera intentionally supports a protocol. For example, OSC 8 becomes `openHyperlink`/`closeHyperlink` in Phase 3 rather than staying raw forever. Kitty graphics graduates the same way in Phase 3 Slice 7 — `ControlSequence.kittyGraphics` replaces raw APC transmit/place bytes once Tessera decided to support the protocol directly; sixel and iTerm2 inline images stay on this escape hatch until a future slice does the same.
- Tests should include at least one raw payload that has zero display width (an OSC-like sequence) and one that claims visible width/area, proving the diff policy rather than string width drives repaint behavior.

## What the encoder does _not_ do

> [!note] Ratatui References
>
> - The crossterm backend's `draw` method (`ratatui-crossterm/src/lib.rs`, lines 232–292) tracks state across the loop (`fg`, `bg`, `modifier`, `last_pos`) to minimize redundant SGR emissions. This is the "buffering of state" that the Tessera encoder deliberately pushes to the renderer layer — the encoder itself is stateless, the renderer decides what to emit.
> - `ModifierDiff` (`ratatui-crossterm/src/lib.rs`, line 535) computes minimal attribute deltas between frames. Tessera's renderer will need equivalent logic, not the encoder.
> - `BufferDiff` (`ratatui-core/src/buffer/diff.rs`, line 10) and `Buffer::diff_iter` (`ratatui-core/src/buffer/buffer.rs`, line 506) compute which cells changed between frames. This is the "no batching" / "no clamping" boundary: the diff layer decides what changed, the encoder just produces bytes for what it's told.
> - `TestBackend` (`ratatui-core/src/backend/test.rs`, line 32) is Ratatui's in-memory backend for golden-byte-style testing — it records what was drawn and lets you assert on the resulting `Buffer`. The Tessera `VirtualTerminal` (libghostty) plays a similar role but at a lower level (byte → terminal state, not cell → buffer).

This list matters as much as the catalog:

- **No buffering of state.** The encoder doesn't remember "the current foreground is red, don't re-emit the SGR." That's the renderer's job (and the renderer will need to do it carefully to minimize bytes). The encoder is stateless.
- **No batching.** `encode(into:)` produces exactly the bytes for the one sequence it's called with. Sequencing is the caller's problem.
- **No clamping.** If you ask for an out-of-range cursor position, the encoder emits exactly those bytes. Validation belongs at a higher layer if it belongs anywhere.
- **No querying.** Sequences that request a response from the terminal (DA1, cursor position report) are not Phase 2. They need a response-parsing infrastructure that's better designed later.
- **No assumptions about the I/O sink.** The encoder writes bytes into a `[UInt8]`; whether those bytes go to stdout, a pipe, a `VirtualTerminal` in tests, or `/dev/null` is not its concern.

## Testing strategy for the encoder

> [!note] Ratatui References
>
> - `TestBackend` (`ratatui-core/src/backend/test.rs`, line 32) provides an in-memory implementation of `Backend` that records all draw operations into a `Buffer`. Ratatui's widget tests use it for golden-buffer assertions: draw a widget, compare the resulting buffer to expected output. This is the "golden byte fixture" pattern at the cell level.
> - The buffer diff tests (`ratatui-core/src/buffer/buffer.rs`, lines 1094–1121) test `diff_iter` against known inputs — `diff_empty_empty`, `diff_empty_filled`, etc. This is the structural analogue of Tessera's golden-byte tests: known input → known output, no terminal involved.
> - Ratatui does not have a byte-level encoder test suite because encoding is delegated to crossterm. Tessera's encoder _is_ the encoding layer, so the golden-byte + VirtualTerminal round-trip strategy fills the gap that Ratatui's delegation model sidesteps.

This is the part that pays the harness back. For every `ControlSequence` case, two tests:

1. **Golden byte fixture.**

   ```swift
   #expect(
       ControlSequence.cursorPosition(TerminalPosition(column: 0, row: 0)).bytes ==
           [0x1b, 0x5b, 0x31, 0x3b, 0x31, 0x48]
   )
   ```

   That is `\e[1;1H`: tedious to write the first time, immortal regression coverage forever.

2. **Round-trip through `VirtualTerminal`.** Feed the bytes to libghostty, assert the terminal state changed as expected. This catches "I emitted bytes that _look_ right but the actual escape sequence does something else."

Together these cover both "the bytes are what I think they are" and "the bytes do what I think they do." Either alone is insufficient.

I'd also write **one negative test per ambiguous case** — e.g., assert that `setForeground(.default)` emits SGR 39, not SGR 30. The cases where you might guess wrong are exactly the cases worth pinning down.

## Definition of done for slice 2

1. `ControlSequence` enum with the ~25-30 cases listed above.
2. `Color` and `ANSIColor` types.
3. `encode(into:)` implementation for every case.
4. ~60 tests: one golden-byte test per case (~30) plus one `VirtualTerminal` round-trip per case (~30).
5. Documentation comments on every case linking to the relevant VT100/xterm/DEC reference. (The encoder is the project's institutional memory for "why is this byte 0x1b and not 0x9b" — it deserves comments.)
6. The Phase 1 walking skeleton is rewritten to use `ControlSequence` instead of hardcoded byte strings. This is a small refactor and proves the encoder is usable from the renderer's perspective.

Roughly another couple of evenings of work. Most of it is mechanical; the design decisions are all up front, which is why we're spending so much time on them now.

## Three things to flag

> [!note] Ratatui References
>
> - Ratatui does not currently emit synchronized output (DEC 2026) sequences. The `CrosstermBackend::draw` method (`ratatui-crossterm/src/lib.rs`, line 232) queues commands directly without wrapping in `DEC private mode 2026`. This is a known gap — crossterm itself has `EnableLineWrap`/`DisableLineWrap` but no sync output command in the versions Ratatui supports.

1. **Synchronized Output (DEC 2026) is in the Phase 2 catalog.** This is a relatively new mode — not all terminals support it, but the ones that do (Ghostty, iTerm2, Kitty, modern Alacritty, WezTerm) make a huge difference for flicker. Terminals that don't support it just ignore the sequence, so emitting it is always safe. The damage-tracking renderer in slice 4 will wrap every frame in `enterSynchronizedOutput`/`exitSynchronizedOutput`. Worth knowing now so the encoder API supports it.

2. **`text(String)` as a case feels weird but is correct.** It lets a `[ControlSequence]` be a complete representation of a frame's output (styling + cursor moves + actual text content interleaved). The alternative — text is "outside" the encoder — fragments the model and makes the renderer ugly. Worth pushing back on if it bothers you, but I think it's the right call.

3. **The `Color` type is going to be load-bearing across the whole stack** — `Style` will hold one, themes will produce them, view APIs will accept them. The shape we pin down here is hard to change later. The four-case design above (`default`, `ansi`, `indexed`, `rgb`) is what every serious terminal library converges on, but worth confirming you're happy with it before we move on.

---
