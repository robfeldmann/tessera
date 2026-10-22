---
type: spec
description: "Slice 5: OSC 8 hyperlinks"
---

# Slice 5: OSC 8 hyperlinks

Slice 5 teaches Tessera to render clickable hyperlinks in terminals that support them.

Everything in Phase 3 so far has been input-side protocol work. OSC 8 is output-side: it
lets an application associate a URI with a span of terminal text. Modern terminals render
that span as clickable or hoverable, often without changing the visible characters. This
is useful for logs, build output, documentation browsers, issue lists, package managers,
trace viewers, chat clients, and any TUI that wants to expose a URL without forcing users
to copy raw text.

OSC 8 hyperlinks use Operating System Command escape sequences. The common shape is:

```text
OSC 8 ; params ; URI ST
visible linked text
OSC 8 ; ; ST
```

where `OSC` is `ESC ]` and `ST` is usually either `ESC \` or BEL depending on terminal
convention. Tessera should choose one terminator for output and test it consistently. The
OSC 8 spec recommends ST (`ESC \`); the existing `setWindowTitle` case terminates its OSC
with BEL. Ghostty's VT accepts both, so pick one, justify it in a comment, and pin it in
byte tests. OSC 8 adoption notes and terminal documentation describe this general
`OSC 8 ; params ; URI` form.

> [!note] Ratatui References
>
> - Ratatui has a hyperlink example, but it is intentionally a workaround rather than a
>   first-class style feature: `examples/apps/hyperlink/src/main.rs` builds raw OSC 8
>   strings into buffer symbols (`examples/apps/hyperlink/src/main.rs`, lines 22, 37-48,
>   and 51-68). Tessera should avoid this by making hyperlinks real cell/span metadata.
> - Ratatui's hyperlink example also documents the current pitfall: ANSI/OSC bytes confuse
>   width calculation, so the example chunks visible text and uses forced-width behavior
>   (`examples/apps/hyperlink/src/main.rs`, lines 53-68). Tessera's design should keep OSC
>   bytes out of symbols so width remains a property of graphemes, not escape strings.
> - Ratatui's buffer tests include `merge_diff_link` and `merge_diff_split_link`, which
>   squeeze raw OSC 8 sequences into cells with `CellDiffOption::ForcedWidth` so diffing
>   stays stable (`ratatui-core/src/buffer/buffer.rs`, lines 1214-1249). This is a useful
>   warning sign: raw escape sequences in cells are workable but leaky.
> - Ratatui's crossterm backend tracks terminal output state for modifiers/colors while
>   drawing only changed cells, then resets styles at the end of `draw`
>   (`ratatui-crossterm/src/lib.rs`, lines 236-291). Tessera's renderer should include
>   hyperlink state in the same kind of state machine instead of treating OSC 8 as
>   printable content.

This slice belongs after the input protocol work because it touches the renderer rather
than the input parser. The terminal substrate should already have a stable model for
modern protocol lifecycle by the time hyperlink state is added to cells, spans, or render
operations.

## Public API shape

Hyperlinks are style-like metadata. They affect how a cell or text span behaves in the
terminal, but they do not consume layout space and they should not change the visible
characters in the buffer.

The cleanest Phase 3 shape is to add hyperlink metadata to the existing
`TesseraTerminalBuffer.Style` — the type the buffer/renderer already uses. Its current
fields are non-optional with `.default` color values; the slice appends one optional
field:

```swift
public struct Style: Equatable, Sendable {
    public var foreground: Color
    public var background: Color
    public var attributes: TextAttributes
    public var hyperlink: Hyperlink?

    public init(
        foreground: Color = .default,
        background: Color = .default,
        attributes: TextAttributes = [],
        hyperlink: Hyperlink? = nil
    )
}

public struct Hyperlink: Equatable, Hashable, Sendable {
    public let uri: String
    public let id: String?

    public init(uri: String, id: String? = nil) throws
}
```

`Hyperlink` most naturally lives in `TesseraTerminalANSI` next to `Color`, since the
encoder's `openHyperlink` case carries it and `TesseraTerminalBuffer` already imports that
module. The important decision is that hyperlinks live with rendered cell/span attributes,
not inside `String`, not as a separate overlay, and not as a view-layer concept yet.
Because `Style` equality drives `BufferDiff`, adding the field means hyperlink changes
produce damage automatically — no diff changes needed.

`id` should be optional. OSC 8 supports parameters, and the most common useful parameter
is an identifier that lets terminals treat separate spans as the same hyperlink. Tessera
does not need a large parameter bag in the first version. `uri` plus optional `id` is
enough.

## Renderer behavior

The renderer must treat hyperlink state like foreground color, background color, bold, and
other attributes: it is part of the current terminal output state, and transitions must be
encoded when the desired state changes.

Rendering requirements:

- Opening a hyperlink emits an OSC 8 open sequence before the linked text.
- Leaving a hyperlink emits an OSC 8 close sequence.
- Changing from one hyperlink to another closes or replaces the previous hyperlink without
  leaking the old URI.
- Resetting style at end-of-frame or teardown closes any active hyperlink.
- Damage rendering must still work when a changed cell begins or ends inside a hyperlink
  span.
- Hyperlink metadata must not affect cell width, grapheme handling, or layout.

The subtle part is damage tracking, and the implementation site is precise: the renderer
(`TesseraTerminalRendering.Renderer`) tracks `currentStyle: Style?` and encodes
transitions through `sgrDelta(from:to:into:)` in `StyleEncoding.swift`. Hyperlink state
joins that state machine — either inside `sgrDelta` or as a parallel hyperlink-transition
step — with one non-negotiable correction to the "reset closes everything" intuition:
**SGR 0 (`resetAttributes`) does not close an OSC 8 hyperlink.** OSC 8 state is
independent of SGR state. Every place the renderer resets style — the nil-`currentStyle`
path at the start of a damaged run after an erase, and the end-of-frame `resetAttributes`
epilogue in `encodeFrame` — must explicitly emit the OSC 8 close when a hyperlink is open,
and `invalidate()` must forget believed hyperlink state along with believed style state.

At minimum, before drawing a damaged run, the renderer should establish the complete style
state needed for the first cell in that run, including hyperlink. After drawing the run,
it should leave the terminal in a safe neutral state — reset attributes and no open
hyperlink — as the existing epilogue already does for SGR.

## Encoder behavior

Add semantic control sequences for hyperlinks:

```swift
public enum ControlSequence: Equatable, Sendable {
    // Existing cases, kept alphabetized...
    case closeHyperlink
    case openHyperlink(Hyperlink)
}
```

Encode them in `encodeOSC` next to `setWindowTitle`, and add both cases to every
exhaustive `encode*` switch in the enum.

The exact bytes should be centralized and tested. Suggested output form:

```text
ESC ] 8 ; id=<escaped-id> ; <escaped-uri> ESC \
...
ESC ] 8 ; ; ESC \
```

If `id` is nil, emit an empty params field:

```text
ESC ] 8 ; ; <escaped-uri> ESC \
```

The implementation must define escaping/validation rules for `uri` and `id`. At minimum,
reject or sanitize control characters so user-provided strings cannot smuggle arbitrary
OSC or CSI sequences into terminal output. The `setWindowTitle` precedent (`oscSafeTitle`,
which strips BEL and ESC scalars) is the floor; a throwing `Hyperlink` initializer that
rejects all C0 controls is the better ceiling because it refuses instead of silently
rewriting the URI.

## Security and correctness

Hyperlinks are a terminal escape feature that can make visible text point somewhere else.
That is useful, but it has spoofing implications. Tessera's job is not to police every
app, but the terminal layer should avoid making unsafe output easy by accident.

Rules for this slice:

- Do not allow raw OSC terminators inside hyperlink URI or ID fields.
- Do not allow C0 control characters in URI or ID fields unless there is a deliberate,
  tested escaping strategy.
- Prefer a `Hyperlink` initializer that can fail or sanitize over blindly storing
  arbitrary strings.
- Tests should include malicious-looking URI/ID inputs containing BEL, ESC, and newline.

Do not overreach into URL policy. TesseraTerminal does not need to decide whether
`https://`, `file:`, `mailto:`, or custom schemes are acceptable. That is application
policy. The terminal layer only needs to ensure its escape sequences remain syntactically
safe.

## Snapshot behavior

Snapshot tests have a real hyperlink story on all three platforms: the vendored
libghostty-vt exposes per-cell hyperlink inspection (`GHOSTTY_CELL_DATA_HAS_HYPERLINK` and
`ghostty_grid_ref_hyperlink_uri` in the `CGhosttyVT` headers). Extend the harness —
`RenderedCell` gains an optional hyperlink-URI field, populated by the Ghostty-backed
`VirtualTerminal` — so renderer tests can assert that the bytes Tessera emitted produced
linked cells in a real VT. `RenderedCell` is test-support API, so growing it is not a
public-API change.

Suggested split:

- Buffer/style tests compare `Hyperlink` values structurally.
- Renderer byte tests compare exact encoded OSC 8 bytes.
- Renderer screen tests feed frames through `VirtualTerminal` and assert per-cell
  hyperlink URIs (including that damage repaints preserve them).
- Higher-level snapshots, once the view layer exists, may render hyperlinks in a readable
  annotation form if raw escape bytes make tests hard to review.

## Tests

Add encoder tests for:

- open hyperlink without ID
- open hyperlink with ID
- close hyperlink
- URI/ID escaping or rejection
- malicious control-character inputs cannot inject terminal escapes

Add renderer tests for:

- linked text opens and closes OSC 8 around the correct cells
- adjacent cells with the same hyperlink do not repeatedly reopen it
- changing hyperlink closes/replaces the previous one
- changing from linked to unlinked text closes the hyperlink
- damage rendering establishes hyperlink state at the start of a damaged run
- end-of-frame reset closes any active hyperlink even though SGR 0 alone would not
- hyperlink metadata does not affect measured width or cell positions
- `VirtualTerminal` screen assertions: linked cells report the URI, unlinked cells report
  none, and a damage-only repaint keeps both correct

## Non-goals

Do not add Markdown/link parsing. This slice does not turn URLs in text into hyperlinks
automatically.

Do not add view-layer link widgets yet. Phase 4 can expose ergonomic APIs like
`Text("docs").link("https://...")`; Phase 3 only gives the terminal renderer a hyperlink
attribute it can encode.

Do not add hyperlink click handling. OSC 8 lets the terminal handle clicks on links; it
does not report link-click events back to the application.

OSC 8 has no standard capability query, so Tessera records it as `.notDetectable` rather
than pretending that terminal identity, declarations, or a successful write proves
support. Rendering remains an explicit policy: when it is enabled, the visible text still
renders usefully if the terminal ignores OSC 8.

## End of Slice 5

`TesseraTerminal` can attach safe hyperlink metadata to rendered cells/spans and encode
OSC 8 open/close sequences during rendering without affecting layout, corrupting damage
tracking, or leaking hyperlink state into unrelated output.
