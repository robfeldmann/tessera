---
type: spec
description: "Slice 1: Bracketed paste mode"
---

# Slice 1: Bracketed paste mode

Slice 1 teaches Tessera the difference between text the user typed and text the terminal
pasted.

Without bracketed paste, a paste arrives as ordinary bytes. Pasting `rm -rf /` looks the
same as the user typing `r`, then `m`, then space, then `-`, and so on. That is acceptable
for a dumb terminal, but not for an application framework. A text editor, shell prompt,
chat input, command palette, or form field needs to know whether input arrived as one
paste operation so it can make policy decisions: preserve newlines, disable auto-submit,
avoid per-character validation, batch undo, sanitize content, or display paste
confirmation.

Bracketed paste mode is small but load-bearing:

- Enable with `ESC [ ? 2004 h`
- Disable with `ESC [ ? 2004 l`
- Pasted content starts with `ESC [ 200 ~`
- Pasted content ends with `ESC [ 201 ~`

> [!note] Ratatui References
>
> - Ratatui itself still delegates input protocols to crossterm, but the shapes line up
>   directly: crossterm's top-level `Event` enum includes `Paste(String)` behind its
>   `bracketed-paste` feature (`crossterm` `src/event.rs`, line 550).
> - crossterm's bracketed paste commands encode the same mode toggles Tessera should
>   encode: `EnableBracketedPaste` writes `CSI ? 2004 h`, and `DisableBracketedPaste`
>   writes `CSI ? 2004 l` (`crossterm` `src/event.rs`, lines 410 and 433).
> - crossterm parses bracketed paste as a parser mode spanning `ESC [ 200 ~` through
>   `ESC [ 201 ~`, returning one `Event::Paste(String)` and using lossy UTF-8 conversion
>   for the payload (`crossterm` `src/event/sys/unix/parse.rs`, line 804).
>
> Tessera should copy the event-level idea, not the exact feature-gating: paste is part of
> `TesseraTerminal`'s modern baseline once Phase 3 starts.

This slice should add a new semantic event to the existing `InputEvent` enum (which keeps
its cases alphabetized and its payload unlabeled):

```swift
public enum InputEvent: Equatable, Sendable {
    case key(Key)
    case paste(String)
    case resize(TerminalSize)
    case unknown([UInt8])
}
```

## Lifecycle behavior

Bracketed paste is a terminal mode, so it belongs in the same lifecycle discipline as raw
mode and alternate screen:

- Enable bracketed paste when Tessera enters application terminal mode.
- Disable bracketed paste during normal teardown.
- Disable bracketed paste from cleanup handlers after abnormal exit.
- Keep the disable sequence idempotent and safe to emit even if enable failed partway
  through startup.

Concretely: remove `.bracketedPaste` from the `unsupportedModes` rejection in
`ModeLifecycle.enable`/`disable`, append it to `acquisitionOrder` and `supportedModes`,
emit the `ControlSequence` bytes through `io.write` + `io.flush`, and add the disable
sequence to the teardown bytes built by `installCleanup()`. Enable at startup by including
`.bracketedPaste` in `TerminalApplicationConfiguration.modes`; grow
`TerminalApplicationConfiguration.default` to include it (slice 6's enablement policy
keeps bracketed paste on by default).

The cleanup rule matters more than the feature itself. Leaving a user's shell in bracketed
paste mode is one of those small terminal footguns that makes a library feel sloppy.

## Parser behavior

The parser needs one additional state: “currently inside bracketed paste.”

When it sees the exact start marker `ESC [ 200 ~`, it should stop emitting ordinary
`key(Key(code: .character(...)))` events and begin accumulating bytes as paste payload.
When it later sees the exact end marker `ESC [ 201 ~`, it should UTF-8 decode the
accumulated payload and emit one `InputEvent.paste(String)`.

The concrete hook: the start marker arrives through the existing `.csi` state as a
tilde-terminated sequence with parameter `200`. `parseCSI` dispatches those through
`keyCode(forTildeParameter:)` today; parameter `200` instead clears a private paste byte
buffer and transitions to `State.bracketedPaste(matchedEndMarkerBytes: 0)`. Parameter
`201` seen outside paste mode is malformed (existing unknown policy). Inside
`.bracketedPaste`, bytes append to the private paste buffer while the parser tracks how
many bytes of the exact end marker have matched. When a byte breaks a partial end-marker
match, the matched marker-prefix bytes are replayed as payload.

Large pastes are expected. Do not store the growing payload in the enum associated value,
do not allocate a candidate array per byte, and do not implement bulk input with
`bytes.flatMap { feed($0) }`. `feed(contentsOf:)` should preserve the public parser
surface while avoiding per-byte event-array churn; a 337 KB paste should parse in low-tens
of milliseconds on a modern machine, not hundreds of milliseconds.

Important edge cases:

- Pasted content may contain newlines, tabs, escape bytes, ANSI-looking sequences, and
  arbitrary UTF-8.
- Bytes inside paste mode are payload unless they are the exact paste-end marker.
- A paste may be split across many reads.
- The start marker itself may be split across reads.
- The end marker itself may be split across reads.
- Invalid UTF-8 should not crash the parser. Completed paste payloads use Swift's lossy
  UTF-8 decoding and emit replacement characters for invalid byte sequences.
- Input-idle notifications must not disturb paste accumulation. `PlatformIO`'s event
  pipeline calls `flushPendingEscape()` whenever an empty idle chunk arrives — which is
  constantly, on every poll timeout. That method acts only on the bare-`.escape` state
  today; keep it that way. A paste may stall between reads indefinitely.
- `flush()` (end of the input stream) with an unterminated paste follows the existing
  incomplete-sequence policy: emit `.unknown` carrying the start marker plus the
  accumulated payload bytes, mirroring the current `.csi`/`.ss3` flush behavior.
- Empty paste payloads emit `.paste("")`.
- A start marker seen while already inside paste mode is payload, not a nested paste.
- Consecutive bracketed pastes must clear paste buffer state between emitted events.

The key design point is that bracketed paste is a _parser mode_, not just another escape
sequence. Once inside paste mode, the normal key parser is suspended until the closing
marker arrives.

## Encoder behavior

Add a semantic control sequence for toggling bracketed paste, rather than sprinkling raw
escape strings through lifecycle code. Follow the existing convention for DEC private
modes with symmetric set/reset — one `Bool`-parameterized case, like
`enableLineWrap(Bool)` and `cursorVisible(Bool)`:

```swift
public enum ControlSequence: Equatable, Sendable {
    // Existing cases, kept alphabetized...
    case enableBracketedPaste(Bool)
}
```

Encode it in `encodeMode` alongside the other DEC private modes, and add the case to every
exhaustive `encode*` switch in the enum.

The important part is that tests assert the exact bytes:

- enable: `\u{1B}[?2004h`
- disable: `\u{1B}[?2004l`

## Tests

Add parser tests for:

- complete paste in one feed
- paste split byte-by-byte
- start marker split across feeds
- end marker split across feeds
- pasted multiline text
- pasted UTF-8 text
- ANSI-looking bytes inside paste payload
- empty paste payload
- start marker inside active paste payload
- consecutive bracketed pastes
- invalid UTF-8 paste uses replacement characters
- ordinary key parsing still works before and after paste
- incomplete paste does not emit partial key events
- paste state survives an input-idle flush (`flushPendingEscape()` mid-paste)
- `flush()` on an unterminated paste follows the unknown policy

Add lifecycle/encoder tests (assert recorded bytes via `InMemoryTerminalDevice`) for:

- startup emits bracketed paste enable
- teardown emits bracketed paste disable
- emergency teardown bytes installed via the cleanup registry include the disable
- disable ordering is compatible with the existing alternate-screen/raw-mode teardown

## Non-goals

Do not add paste handling to the view layer yet. There is no `TextInput`, no command
palette, no form component, and no application runtime in this phase. The only job is to
surface pasted text as a distinct terminal event.

Do not try to auto-detect support yet. Bracketed paste is widely supported by modern
terminals, harmless when unsupported, and easy to disable. Capability detection can wait
until the later Phase 3 slice if it still feels necessary.

## End of Slice 1

`TesseraTerminal` can enable bracketed paste mode, reliably restore the terminal on exit,
and emit a single `.paste(String)` event for pasted content instead of pretending the user
typed every character by hand.
