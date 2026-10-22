---
type: spec
description: "Slice 7: Kitty graphics protocol"
---

# Slice 7: Kitty graphics protocol

Slice 7 teaches Tessera to render images: transmitting pixel or PNG data to the terminal and placing it at specific cells, using the Kitty Graphics Protocol (KGP).

Every prior Phase 3 slice either decoded input the terminal already sent (paste, focus, mouse, keyboard) or rendered text-shaped output (hyperlinks). Graphics is the first slice whose whole job is emitting a large, binary, chunked payload the terminal must reassemble before anything appears on screen — closer in spirit to a file transfer than a control sequence. It graduates Kitty graphics out of the `RawTerminalPayload` escape hatch this spec opened early on, per that section's own graduation rule: once Tessera intentionally supports a protocol, it gets a semantic `ControlSequence` case instead of staying raw forever.

KGP, not Sixel or iTerm2's OSC 1337 inline images, is the protocol that graduates here. It has the widest current terminal support among the three (Kitty, Ghostty, iTerm2, WezTerm, Konsole — see Platform notes, below), the cleanest wire format, and — uniquely among them — a documented, portable transmission mode: `t=d` (direct, inline base64) works everywhere a KGP terminal exists, while file/temp/shm transmission modes require a shared filesystem or shared-memory namespace the terminal and the Tessera process may not agree on. Tessera emits `t=d` exclusively. Sixel and iTerm2 inline images remain `RawTerminalPayload` territory; promoting them is future work, gated on demonstrated demand from users of terminals that lack KGP (Windows Terminal, foot).

The protocol's envelope is an APC (Application Program Command) escape sequence:

```text
ESC _ G <k=v,...> ; <base64 payload> ESC \
```

Well-behaved terminals ignore APC codes they do not recognize, but Tessera still probes before emitting large image transmit/place payloads in examples. The KGP `a=q` query is the small, side-effect-free support probe; `a=t`/`a=p` are real output and should be gated by a successful probe or an explicit application/user opt-in.

Core keys, all documented at the URL in the reference callout below: `a` action (`t` transmit, `p` place, `q` query, `d` delete), `f` format (`24` RGB / `32` RGBA default / `100` PNG), `t` medium (`d` direct — the only one Tessera emits), `i` image id, `p` placement id, `m` more-chunks flag, `q` quiet level (`1` suppresses OK responses, `2` additionally suppresses failures — two named levels, not cumulative), `s`/`v` pixel width/height, `c`/`r` display columns/rows, `z` z-index, `C=1` do-not-move-cursor, and `d=` delete-scope letters.

Transmission is chunked: the base64 payload is split into pieces of at most 4096 bytes, every non-final chunk length a multiple of 4, with the full control-key set on the first chunk only and every following chunk carrying just `m=` and the payload slice. `m=1` marks every chunk but the last; `m=0` marks the last. A placement's cursor position is whatever the cursor was at when the final chunk arrived, which is why Tessera keeps transmit (`a=t`) and place (`a=p`) as separate commands rather than the combined `a=T` form: transmission is session-scoped and chunked over time, placement is frame-scoped and instantaneous.

> [!note] Ratatui References
>
> - The protocol Tessera targets is specified at <https://sw.kovidgoyal.net/kitty/graphics-protocol/> — the APC envelope, action/format/medium keys, chunking rule, and the alt-screen/erase interaction this slice cites throughout come from that document.
> - Ratatui core ships zero graphics-protocol code, but grew `CellDiffOption::{Skip, AlwaysUpdate, ForcedWidth}` (`ratatui-core/src/buffer/cell.rs`, lines 12-32; honored in `diff.rs`, lines 110 and 130-131) specifically because of pain reported against `ratatui-image` retrofitting protocol output onto a diffing buffer that never expected it (issue #1116; PRs #1605, #2437, #2480). Tessera's `CellDiffPolicy` and `Frame.writeRaw(occupying:)` were designed for exactly this case from day one — see the raw payload escape hatch section above.
> - `ratatui-image` (github.com/benjajaja/ratatui-image) implements sixel, Kitty, iTerm2, and halfblocks entirely outside Ratatui core, and its architecture shows the cost of that: hand-rolled `clear_area` calls per protocol, a whole `sliced` module that exists purely to handle scroll/viewport clipping (Kitty itself needs none of that — the terminal owns clipping), an `allow_clipping` API wart because Sixel and iTerm2 never clip while Kitty does, tmux passthrough fragility, and a hardcoded terminal blacklist. Its Kitty backend is transmit-once-then-place and simply trusts the terminal for cleanup. This is the case for building KGP into Tessera's core instead of leaving it to a downstream crate the way Ratatui does.
> - The vendored `libghostty-vt` already exposes a complete Kitty graphics inspection C API — `Sources/CGhosttyVT/include/ghostty/vt/kitty_graphics.h` (776 lines, included from `vt.h:135`) — with image and placement handles and per-placement geometry. Ratatui has no equivalent: verifying `ratatui-image` output means screen-scraping bytes, not asserting decoded placement state. Slice 7's snapshot harness (see Snapshot harness support, below) is a structural advantage Tessera gets for free from Slice 1's Ghostty-backed test harness.

Tessera models the command set as a closed value type in new files beside `ControlSequence`. The image and placement identifiers, and the response type input parsing needs, live in `TesseraTerminalCore` instead of `TesseraTerminalANSI` — `TesseraTerminalInput` depends on Core but not on ANSI, and it needs to see these IDs to decode `InputEvent.kittyGraphicsResponse` (below) without adding a new cross-module dependency. Everything ANSI-only stays in `TesseraTerminalANSI`, alongside `ControlSequence`, the same home slice 5 gives `Hyperlink` next to `Color`:

```swift
// TesseraTerminalCore — shared with TesseraTerminalInput, which does not import ANSI.
public struct KittyImageID: Equatable, Hashable, RawRepresentable, Sendable {
    public var rawValue: UInt32
    public init(rawValue: UInt32)
}

public struct KittyPlacementID: Equatable, Hashable, RawRepresentable, Sendable {
    public var rawValue: UInt32
    public init(rawValue: UInt32)
}

// TesseraTerminalANSI — alongside ControlSequence.
public enum KittyImageFormat: Equatable, Sendable {
    case png                            // f=100; dimensions come from the PNG itself
    case rgb(width: Int, height: Int)   // f=24, s=/v= required
    case rgba(width: Int, height: Int)  // f=32, s=/v= required
}

public enum KittyGraphicsQuiet: Equatable, Sendable {
    case suppressFailures  // q=2
    case suppressOK        // q=1
    case verbose           // q=0
}

public struct KittyGraphicsTransmission: Equatable, Sendable {
    public var data: [UInt8]              // raw pixel or PNG bytes; NOT pre-base64ed
    public var format: KittyImageFormat
    public var id: KittyImageID
    public var quiet: KittyGraphicsQuiet  // default .suppressOK: errors still surface

    public init(id: KittyImageID, format: KittyImageFormat, data: [UInt8],
                quiet: KittyGraphicsQuiet = .suppressOK)
}

public struct KittyGraphicsPlacement: Equatable, Sendable {
    public var columns: Int?              // c= cell scaling
    public var id: KittyImageID
    public var placement: KittyPlacementID?
    public var quiet: KittyGraphicsQuiet  // default .suppressOK
    public var rows: Int?                 // r= cell scaling
    public var zIndex: Int32              // z=, default 0

    public init(id: KittyImageID, placement: KittyPlacementID? = nil,
                columns: Int? = nil, rows: Int? = nil, zIndex: Int32 = 0,
                quiet: KittyGraphicsQuiet = .suppressOK)
}

public enum KittyGraphicsDelete: Equatable, Sendable {
    case all                                        // a=d,d=A (placements + data)
    case image(KittyImageID)                        // a=d,d=I,i= (image + data)
    case placement(KittyImageID, KittyPlacementID)  // a=d,d=i,i=,p= (data retained)
}

public enum KittyGraphicsCommand: Equatable, Sendable {
    case delete(KittyGraphicsDelete)
    case place(KittyGraphicsPlacement)
    case query(id: KittyImageID)   // i=<id>,s=1,v=1,a=q,t=d,f=24;AAAA
    case transmit(KittyGraphicsTransmission)
}
```

`query` encodes the KGP half of the detection probe from the protocol spec: a 1×1 RGB pixel sent as a query action. `TerminalSession.queryKittyGraphicsSupport(id:)` appends a DA1 request (`CSI c`) to those query bytes in the same flushed write. If a `KittyGraphicsResponse` arrives before the DA1 response, the terminal supports graphics; if DA1 arrives first, it did not answer the KGP query.

On the input side, `InputEvent` gains cases for both halves of that active probe, and the KGP response payload lives in `TesseraTerminalCore` next to the ID types:

```swift
public enum InputEvent: Equatable, Sendable {
    case focusGained
    case focusLost
    case key(Key)
    case kittyGraphicsResponse(KittyGraphicsResponse)
    case mouse(MouseEvent)
    case paste(String)
    case primaryDeviceAttributes([Int])
    case resize(TerminalSize)
    case unknown([UInt8])
}

public struct KittyGraphicsResponse: Equatable, Sendable {
    public var id: KittyImageID?
    public var message: String        // "OK" or "<CODE>:<detail>"
    public var placement: KittyPlacementID?
    public var success: Bool          // message == "OK"
}
```

This follows the same alphabetized-case discipline Slice 3 established for `.mouse`: the graphics response slots between `.key` and `.mouse`, and the DA1 sentinel slots between `.paste` and `.resize`.

## Encoder behavior

`ANSIByteEncoding` (today 34 lines, with `appendCSI`/`appendOSC`/`appendSGR`/`appendInteger` only) gains `appendAPC(_:into:)` — the introducer is `ESC _` (0x1B 0x5F) — and an `ST` terminator helper (`ESC \`, 0x1B 0x5C), reused by both APC and the OSC 8 hyperlink encoding Slice 5 already ships. OSC 8 itself keeps its existing BEL terminator; only the new APC path adopts `ST`.

`ControlSequence` gains one alphabetized case:

```swift
public enum ControlSequence: Equatable, Sendable {
    // Existing cases, kept alphabetized...
    case kittyGraphics(KittyGraphicsCommand)
}
```

`ControlSequence.encode` dispatches through grouped exhaustive switches (`encodeCursor`/`encodeErase`/`encodeSGR`/`encodeMode`/`encodeOSC`/`encodePayload`) — the new case must be added to every one of them, via a new `encodeKittyGraphics` helper, or the target does not compile.

Byte assembly rules, pinned by exact golden-byte tests (see Tests, below):

- Transmit (`a=t`): `a=t,i=<id>,f=<format>[,s=<w>,v=<h>],t=d,q=<quiet>` followed by `;` and base64(data), chunked at 4096 bytes per the rule above. Base64 goes through Foundation's `Data.base64EncodedString()` — Foundation is already imported by `PlatformIOError.swift` and `Renderer.swift`, so this adds no new dependency.
- Place (`a=p`): `a=p,i=<id>[,p=<placement>][,c=<columns>][,r=<rows>],z=<zIndex>,C=1,q=<quiet>`. `C=1` — do not move the cursor — is always emitted; it is not configurable, because the renderer, not the caller, owns cursor position.
- Delete (`a=d`): `.all` encodes `a=d,d=A`; `.image(id)` encodes `a=d,d=I,i=<id>`; `.placement(id, placement)` encodes `a=d,d=i,i=<id>,p=<placement>`.
- Query (`a=q`): the fixed detection probe, `i=<id>,s=1,v=1,a=q,t=d,f=24;AAAA` — a 1×1 RGB pixel; the key order matches the protocol documentation's own probe bytes.

## Parser behavior

Today, `InputParser`'s private `State` enum has no APC handling at all: `ESC _` falls through the `.escape` state's default case, emits a bogus Alt+`_` key event, and every following byte of the APC payload shreds into further garbage key events (`InputParser.swift:339-344, 353-398`). Any inbound KGP response — an `OK` or an error code arriving on stdin — corrupts the event stream today. This slice fixes that as a correctness requirement, not just a feature addition.

Add a new state, `.apc(accumulated:)`, entered from `.escape` on `_` (0x5F), alongside the existing `.csi(accumulated:)`, `.escape`, `.ground`, `.ss3(accumulated:)`, and `.utf8(expectedCount:accumulated:)` cases:

- Accumulate bytes until the 7-bit string terminator (`ESC \`).
- `CAN`/`SUB` abort the sequence back to `.unknown`, matching the parser's existing cancel handling elsewhere.
- A byte cap (suggested 4096, matching the protocol's own chunk size) bounds accumulation: overflow flushes what's been collected as `.unknown` and resynchronizes to `.ground` rather than growing without limit.
- `flush()` gains an `.apc` recovery path, mirroring its existing `.csi`/`.ss3`/`.utf8` recovery, so a truncated APC sequence at end-of-stream still surfaces as `.unknown` instead of being silently dropped.

Once the terminator arrives, an APC payload starting with `G` decodes into `InputEvent.kittyGraphicsResponse`; a response is either `i=<id>[,p=<placement>];OK` or `i=<id>[,p=<placement>];<CODE>:<message>` (codes like `ENOENT`, `EINVAL`). Every other APC payload — regardless of its first byte — becomes a single `InputEvent.unknown(bytes)` for the WHOLE sequence. It is never shredded into key events; this is the regression test against today's Alt+`_` behavior, and it applies uniformly, not just to graphics: an app that emits its own experimental APC sequences also gets one clean `.unknown`, not garbage keys.

As with focus and mouse sequences, APC bytes inside bracketed paste remain paste payload: a pasted `ESC _ G ... ESC \` is pasted text, not a graphics response.

## Placement, damage tracking, and the renderer

Transmission and placement have different scopes, and the session/`Frame` API reflects that split directly:

```swift
extension TerminalSession {
    /// Transmits image data over the tty (t=d, chunked). Session-scoped, outside draw.
    public func transmitImage(_ transmission: KittyGraphicsTransmission) async throws

    /// Deletes images/placements immediately (also used by teardown).
    public func deleteImages(_ delete: KittyGraphicsDelete) async throws
}

extension Frame {
    /// Encodes an a=p placement anchored at `position` and reserves `region`: the
    /// anchor cell carries the placement bytes with the default `.alwaysRepaint`
    /// policy; the remaining covered cells become .continuation/.opaque.
    public borrowing func placeImage(
        _ placement: KittyGraphicsPlacement,
        at position: TerminalPosition,
        occupying region: Rect
    )
}
```

`transmitImage`/`deleteImages` are session-scoped, not frame-scoped: image data must reach the terminal exactly once, independent of how many frames later a placement references it, so these methods write and flush outside `TerminalSession.draw`'s render transaction — the same ad hoc write-and-flush shape `restoreCursorVisibility` already uses (`TerminalSession.swift:147-150`). `draw`/`Frame` itself never touches `io` directly (`TerminalSession.swift:85-125`); this is the one place graphics deliberately steps outside that rule, because transmission has no natural frame to belong to.

`Frame.placeImage` is a thin semantic layer over the existing `Buffer.writeRaw(_:at:occupying:repaintPolicy:)`/`markOpaque` machinery (`Buffer.swift:100-137, 139-156`; `Frame.swift:46-63`): it encodes the `a=p` command bytes, anchors them at `position` with `Buffer`'s existing `.raw(...)` cell kind, and reserves `region` the same way any other raw payload does. The renderer already emits an anchor's raw bytes after positioning the cursor at the anchor cell (`Renderer.swift:69-104`) — exactly the shape `a=p` needs, since KGP places relative to the current cursor position.

The default `repaintPolicy` for `placeImage` is `.alwaysRepaint`, and that default is deliberate, not incidental: equal frame buffers still re-emit placement anchors so ordinary damage redraws preserve placement intent. A full renderer invalidation is different. `Renderer.encodeFrame` emits `eraseInDisplay(.all)` whenever `previous == nil` or the terminal size changed, and terminals may discard both placements and stored image data after `ESC [ 2 J`. Ghostty does so: a later `a=p` for the old image id returns `ENOENT: image not found`.

An app that invalidates before showing an image must therefore consume the erase/repaint first, then call `transmitImage`, then draw a placement frame. Transmitting before the invalidated draw lets `ED 2` delete the freshly transmitted data. Re-emitting a failed `.alwaysRepaint` placement from each graphics response creates a response/redraw feedback loop, so apps must match asynchronous failures to their image and placement ids, stop placement, retain the complete error, and require an explicit retry. Terminals may also evict image data under memory pressure; the same `ENOENT` recovery rule applies.

The caller keeps `occupying` and `columns`/`rows` consistent with each other; Tessera does not compute one from the other in this slice. Phase 4's future `Image` view will, once `cellPixelSize` (below) is available to convert between pixel and cell units.

## Pixel geometry

Today Tessera has no pixel plumbing at all: POSIX `readTerminalSize` reads only `ws_col`/`ws_row` (`TerminalDevice+Live.swift:146-158`), `TerminalSize` has no pixel fields, and the Windows path reads only the cell rectangle (`WindowsConsole.swift:127-144`). This slice adds a value type beside `TerminalSize` in `TesseraTerminalCore`:

```swift
public struct CellPixelSize: Equatable, Hashable, Sendable {
    public var height: Int
    public var width: Int
}
```

`TerminalDevice` gains a `cellPixelSize` endpoint returning `CellPixelSize?`. The POSIX live implementation reads `ws_xpixel`/`ws_ypixel` from the same `TIOCGWINSZ` call `readTerminalSize` already makes and divides by columns/rows; any zero field (columns, rows, `ws_xpixel`, or `ws_ypixel`) yields `nil` rather than a division by zero or a nonsense size. The Windows live implementation returns `nil` unconditionally — Windows Terminal has no KGP support (see Platform notes, below), so there is nothing to speculatively query `GetCurrentConsoleFontEx` for. `TerminalSize` itself is NOT modified; it stays the resize-event payload it already is, and pixel size travels on its own accessor instead.

The value is exposed as `TerminalSession.cellPixelSize` (`async`, `nil` when unknown). An active `CSI 16 t` query — the terminal asking for cell size directly instead of deriving it from `TIOCGWINSZ` — is explicitly deferred to Slice 6's active-query machinery; TIOCGWINSZ-derived pixel size is this slice's whole deliverable. `ratatui-image`'s cell-size discovery order is the reference for that future work: `CSI 16 t` query first, `TIOCGWINSZ` fallback second, a hardcoded default last. Tessera ships the fallback tier now and the query tier later, in the same priority order.

## Lifecycle and cleanup

Graphics is not a `ModeLifecycle.Mode` — there is no enable sequence, so there is nothing for `enter`/`exit`/`acquisitionOrder` to track. But cleanup discipline still applies: both normal teardown and emergency cleanup gain the delete-all sequence — `ESC _ G a=d,d=A ESC \` — unconditionally: about a dozen bytes, harmless APC on a non-supporting terminal, consistent with the project's existing over-clean stance. It is emitted BEFORE leaving the alternate screen.

A compliant terminal already clears alt-screen images on exit per the protocol spec, so this is defense-in-depth, not a required fix — but it is cheap defense-in-depth against documented non-conformance (WezTerm and Konsole gaps), and it costs nothing on terminals that never saw a KGP sequence in the first place. Wire-wise it lives with the existing teardown-byte assembly — `ModeLifecycle.installCleanup()`/`exit()`, which already encode `ControlSequence` teardown bytes through the async-signal-safe C shim and `CleanupRegistry` — even though graphics is not itself a `Mode`.

Because `deleteImages(_:)` is a plain `TerminalSession` method (D6, above), apps may also call it directly at any point in the session's lifetime, not only during teardown — e.g. to free a large image an app no longer needs.

## Capability detection

Slice 6's `TerminalCapabilities` includes `kittyGraphics: CapabilityStatus`, and passive detection must not infer this value from terminal names. Slice 7 ships the active KGP probe path it owns: `query(id:)` encodes the side-effect-free `a=q` command, `TerminalSession.queryKittyGraphicsSupport(id:)` writes that query followed by DA1, `InputParser` decodes both `KittyGraphicsResponse` and DA1, and the app can decide support based on response ordering.

Current behavior: `kittyGraphics` remains `.unknown` until an active probe or observed KGP response provides evidence. Examples may run the probe when the graphics panel is selected and must not transmit/place image data until support is observed, unless the user explicitly opts in to blind output.

## Snapshot harness support

The vendored libghostty-vt headers already expose a complete Kitty graphics inspection C API — `Sources/CGhosttyVT/include/ghostty/vt/kitty_graphics.h` (776 lines; included from `vt.h:135`) — with `GhosttyKittyGraphics`/`GhosttyKittyGraphicsImage` handles, per-placement data (image id, placement id, x/y offset, columns/rows, z-index), and format enumeration (RGB/RGBA/PNG/...). `VirtualTerminal+Ghostty.swift` calls none of it today, so KGP is end-to-end snapshot-testable in the existing harness the moment this slice wires it up — the same pattern Slice 5 used to grow `RenderedCell` with hyperlink inspection.

Extend `VirtualTerminal` with two new endpoints, `unimplemented` by default like the harness's existing endpoints:

```swift
kittyImages: @Sendable () -> [RenderedKittyImage]
kittyPlacements: @Sendable () -> [RenderedKittyPlacement]
```

`RenderedKittyImage`/`RenderedKittyPlacement` are test-support types (id, placement id, position, columns/rows, z-index, format/dimensions), so growing them is not a public-API change. They make the slice's acceptance tests real instead of byte-comparison-only: feed encoder bytes into `VirtualTerminal`, then assert Ghostty actually decoded the image and placement; re-place the same `(i, p)` pair and assert it moved rather than duplicated; delete and assert it's gone; write an unrelated frame and assert the `.opaque` region is untouched. If the pinned libghostty-vt revision's C surface is missing an accessor a test needs, bump the pin per `docs/guides/updating-ghostty-vt.md` rather than shelling out to a different revision ad hoc.

## Platform notes

Terminal support for KGP, as of mid-2026, is real but partial, and Tessera's design must be honest about that rather than pretend graduation to first-class support means universal support:

- **Support it today:** Kitty and Ghostty implement the core protocol (Ghostty has no animation support, which does not matter here — animation is a non-goal, see below). iTerm2 has supported it since 2024, minus animation. WezTerm supports it behind an opt-in setting, `enable_kitty_graphics = true`. Konsole supports direct transmission only — exactly the mode Tessera emits, so Konsole is fully covered despite the narrower support.
- **Do not support it:** Windows Terminal (Sixel only; its maintainers have stated they will not add KGP), Alacritty (neither protocol), foot (Sixel only), and xterm (neither).
- **tmux:** opaque passthrough only, and `allow-passthrough` is off by default, so a typical tmux session drops graphics bytes even when the outer terminal supports them, unless the user has explicitly configured passthrough. Tessera does not detect or work around this; it is out of scope for this slice (see Non-goals, below).

Given that matrix, graceful degradation is mandatory, not a nice-to-have: many terminals a Tessera app runs in today will ignore or mishandle graphics bytes, and the app must have a real fallback (text, a placeholder glyph, or simply no image) rather than treating graphics as guaranteed. The side-effect-free KGP query plus DA1 sentinel is the preferred way to avoid sending large image payloads to unsupported terminals. Apps may still opt in to blind `transmitImage`/`placeImage` calls when the user or application policy knows the terminal path supports KGP, but examples must default to probing first.

On Windows, `cellPixelSize` is `nil` unconditionally (see Pixel geometry, above) because no currently-supported Windows terminal implements KGP; this is a consequence of today's platform support matrix, not a gap this slice needs to close.

## Tests

Add encoder golden-byte tests for:

- a single-chunk transmit (payload under 4096 bytes)
- a multi-chunk transmit that crosses the 4096-byte boundary exactly, asserting chunk count, the `m=1`/`m=0` flag on each chunk, and that non-final chunk length is a multiple of 4
- place with an explicit `c=`/`r=` cell scaling
- place with a non-default `z=` z-index
- place with `p=` omitted vs. an explicit placement id
- `C=1` is present on every place encoding, unconditionally
- all three delete variants (`.all`, `.image`, `.placement`)
- the fixed query probe bytes

Add parser tests for:

- a successful `OK` response, with and without a placement id
- an error response (e.g. `ENOENT:...`) decodes `success == false`
- an APC response split across reads, byte-by-byte
- a non-`G` APC payload decodes to a single `.unknown(bytes)` for the whole sequence, never shredded into key events
- an APC payload exceeding the byte cap flushes as `.unknown` and resynchronizes cleanly to `.ground`
- an APC-looking byte sequence inside bracketed paste stays paste payload, not a `.kittyGraphicsResponse`
- regression: `ESC _` followed by arbitrary bytes no longer produces the historical bogus Alt+`_` key event plus shredded garbage keys — compare directly against today's behavior to prove the fix

Add harness (Ghostty-backed `VirtualTerminal`) tests for:

- encoder bytes for a transmit + place round-trip decode into a real image and placement via `kittyImages`/`kittyPlacements`
- re-placing the same `(image id, placement id)` moves the existing placement instead of creating a duplicate
- a delete command clears the placement/image from harness state
- an `.opaque` region a placement reserved is untouched by an unrelated later frame's damage pass

Add lifecycle byte tests (`InMemoryTerminalDevice`) for:

- normal teardown bytes include the delete-all sequence, before the alt-screen exit sequence
- emergency cleanup bytes include the same delete-all sequence
- delete-all is present even when no image was ever transmitted during the session (over-cleaning is intentional)

Add pixel-size tests for:

- `CellPixelSize` divides `ws_xpixel`/`ws_ypixel` by columns/rows correctly on POSIX
- a zero `ws_xpixel`, `ws_ypixel`, column, or row count yields `nil`, not a division-by-zero crash or a nonsense size
- the Windows live implementation returns `nil` unconditionally
- `TerminalSession.cellPixelSize` surfaces the device value asynchronously and matches `InMemoryTerminalDevice`'s configured test value

## Non-goals

Do not implement animation (`a=f`/`a=a`/`a=c` and related keys). Do not implement Unicode placeholders (U+10EEEE, not U+10FFFF), relative placements, or tmux passthrough wrapping — even mature KGP implementations treat placeholders as separable follow-up work, and this slice agrees.

Do not implement file, temp-file, or shared-memory transmission (`t=f`/`t`/`s`) — direct (`t=d`) only, per the portability reasoning above. Do not implement zlib compression (`o=z`).

Do not promote Sixel or iTerm2's OSC 1337 inline images to first-class support. Both remain `RawTerminalPayload` territory; re-evaluate only on demonstrated demand from users of terminals that lack KGP (Windows Terminal, foot).

Do not decode, scale, dither, or otherwise process image data. Tessera transports bytes; producing PNG or pixel data is the app's job, or Phase 4's.

Do not build the Phase 4 `Image` view, its layout, or its hit-testing. That is Phase 4 work that requires this slice as its substrate — see the Phase 4 prerequisites update above — not part of it.

## End of Slice 7

`TesseraTerminal` can transmit image data and place it at specific cells using the Kitty graphics protocol, decode graphics responses without corrupting the input event stream, self-heal placements across resize and first-draw erases, clean up unconditionally on every exit path, and degrade silently on the many terminals that do not implement the protocol — all end-to-end verifiable through the existing Ghostty-backed snapshot harness.
