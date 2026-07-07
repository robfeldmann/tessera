---
name: Phase 3 Slice 7 Kitty Graphics Protocol
description:
  Add first-class Kitty Graphics Protocol (KGP) support: APC encoding and parsing,
  per-cell pixel geometry, session-scoped image transmission, frame-scoped placement,
  unconditional cleanup, a Ghostty snapshot harness, and a procedural-gradient demo panel.
status: complete
created: 2026-07-04
updated: 2026-07-07
---

## Progress

- [x] **Phase 1 — APC encoding and the KGP command model**
  - [x] 1.1 Add APC/ST encoding primitives and the KGP value/command types
  - [x] 1.2 Wire `ControlSequence.kittyGraphics` through the encoder
  - [x] 1.3 Add exact byte tests for every KGP wire format
- [x] **Phase 2 — APC input parsing**
  - [x] 2.1 Add the `.apc` parser state and stop shredding `ESC _`
  - [x] 2.2 Decode `G`-prefixed APC payloads into `KittyGraphicsResponse`
  - [x] 2.3 Add parser tests, including the Alt+`_` regression
- [x] **Phase 3 — Pixel geometry**
  - [x] 3.1 Add `CellPixelSize` and the `TerminalDevice.cellPixelSize` seam
  - [x] 3.2 Implement POSIX/Windows/in-memory pixel geometry and expose the session
        accessor
- [x] **Phase 4 — Session, Frame, cleanup, and snapshot harness**
  - [x] 4.1 Add `TerminalSession.queryKittyGraphicsSupport`/`transmitImage`/
        `deleteImages` and `Frame.placeImage`
  - [x] 4.2 Add the unconditional delete-all cleanup sequence
  - [x] 4.3 Extend the Ghostty snapshot harness with graphics inspection endpoints
- [x] **Phase 5 — Example app and validation**
  - [x] 5.1 Add the graphics panel to `Phase3ProtocolsDemo`
  - [x] 5.2 Run narrow encoder, parser, IO, session, snapshot, and example checks

## Overview

This plan implements `docs/Spec.md` Phase 3 Slice 7. Tessera adopts the Kitty Graphics
Protocol (KGP) as a first-class capability — new value types, an APC encoder, an APC
parser, per-cell pixel geometry, and a `Frame`/`TerminalSession` API — rather than routing
it through the `RawTerminalPayload` escape hatch. Sixel and iTerm2 OSC 1337 stay
escape-hatch citizens; they are not implemented by this slice.

KGP earns first-class treatment because its wire model already matches Tessera's
architecture: an image is transmitted once (`a=t`, session-scoped, outside `draw`) and
then placed by id/placement-id (`a=p`, frame-scoped, anchored in the buffer like any other
raw region); re-sending the same `(image id, placement id)` pair is a flicker-free
in-place move or resize per the protocol's own spec; and a `delete-all` control sequence
(`a=d,d=A`) gives Tessera a single, harmless-everywhere cleanup primitive. Sixel and
iTerm2 OSC 1337 have no equivalent id/placement/z/delete model and no libghostty-vt
inspection surface, so they stay `RawTerminalPayload` territory until there is
demonstrated demand.

Implemented in this slice: `ANSIByteEncoding` now has APC/ST helpers, `InputParser` has a
bounded APC state, `TerminalDevice`/`TerminalSession` expose cell pixel geometry,
`TerminalSession.queryKittyGraphicsSupport(id:)` writes a KGP query followed by DA1 for a
bounded active support probe, and `Frame.placeImage` is backed by first-class KGP command
encoding and Ghostty snapshot inspection.

### Module placement (resolved, matches the spec exactly)

`TesseraTerminalInput` depends only on `TesseraTerminalCore` (not `TesseraTerminalANSI`;
see `Package.swift`'s `TesseraTerminalInput` target). Since the parser (Phase 2) must
construct `KittyImageID`/`KittyPlacementID`/`KittyGraphicsResponse`, those three types
live in `TesseraTerminalCore`, not alongside the rest of the KGP surface. Everything else
from the design contract's type sketch — `KittyImageFormat`, `KittyGraphicsQuiet`,
`KittyGraphicsTransmission`, `KittyGraphicsPlacement`, `KittyGraphicsDelete`,
`KittyGraphicsCommand` — lives in `TesseraTerminalANSI` beside `ControlSequence`, which
already depends on `TesseraTerminalCore`. This split is coordinated with the spec edit and
must not drift from it.

## Non-goals (also stated in the spec)

- Animation (`a=f`/`a=a`/`a=c` and related keys).
- Unicode placeholders (U+10EEEE), relative placements, and tmux passthrough wrapping.
- File/temp-file/shared-memory transmission (`t=f`/`t=t`/`t=s`) — `t=d` (direct) only.
- zlib compression (`o=z`).
- First-class Sixel or iTerm2 OSC 1337 — both remain `RawTerminalPayload` territory;
  re-evaluate only on demonstrated demand (Windows Terminal/foot users).
- Image decoding, scaling, dithering, or any raster processing — Tessera transports bytes;
  PNG/pixel production is the caller's (or Phase 4's) concern.
- The Phase 4 `Image` view, layout, and hit-testing (Phase 4 work; requires this slice).
- Non-KGP active probes, terminal-name inference removal, and the broader Phase 3.4
  capability-detector refactor. This slice owns KGP's `a=q` + DA1 support probe plus APC
  response parsing.

## Phase 1 — APC encoding and the KGP command model

**Goal**: Every `KittyGraphicsCommand` encodes to exact, spec-correct APC bytes, including
chunked, base64 transmission — with zero behavior on terminals that ignore APC.

### Step 1.1 — Add APC/ST encoding primitives and the KGP value/command types

- Files:
  - `Sources/TesseraTerminalANSI/ANSIByteEncoding.swift`
  - new `Sources/TesseraTerminalCore/KittyGraphics.swift`
  - new `Sources/TesseraTerminalANSI/KittyGraphics.swift`
- Add an APC introducer and String Terminator (ST) helper to `ANSIByteEncoding`, beside
  the existing `appendCSI`/`appendOSC`. Unlike `appendOSC` (BEL-terminated), APC bodies
  are always ST-terminated, so the terminator is a separate append call made at the
  encoding call site — mirroring how `encodeOSC` appends `ANSIByteEncoding.bell` itself
  after `appendOSC` rather than baking the terminator into the helper:

  ```swift
  /// Appends a 7-bit Application Program Command introducer: `ESC _` followed by `body`.
  static func appendAPC(_ body: String, into buffer: inout [UInt8]) {
    buffer.append(Self.escape)
    buffer.append(0x5F)
    buffer.append(contentsOf: body.utf8)
  }

  /// Appends a 7-bit String Terminator: `ESC \`, used to end APC sequences.
  static func appendST(into buffer: inout [UInt8]) {
    buffer.append(Self.escape)
    buffer.append(0x5C)
  }
  ```

- Add the two identifier types and the input-side response type to
  `Sources/TesseraTerminalCore/KittyGraphics.swift` (all conformances alphabetized):

  ```swift
  public struct KittyImageID: Equatable, Hashable, RawRepresentable, Sendable {
    public var rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }
  }

  public struct KittyPlacementID: Equatable, Hashable, RawRepresentable, Sendable {
    public var rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }
  }

  public struct KittyGraphicsResponse: Equatable, Sendable {
    public var id: KittyImageID?
    public var message: String        // "OK" or "<CODE>:<detail>"
    public var placement: KittyPlacementID?
    public var success: Bool          // message == "OK"
  }
  ```

  `KittyGraphicsResponse` is added here (Phase 1) even though Phase 2 is its only
  consumer, so the Core file exists before either later phase needs it. The design
  contract's sketch lists `KittyGraphicsResponse`'s fields only, with no public
  initializer (unlike the other D2 types). Since Phase 2's parser must construct one
  across the `TesseraTerminalCore`/`TesseraTerminalInput` module boundary, add an explicit
  public initializer that DERIVES `success` from `message` so the two fields can never
  disagree:

  ```swift
  public init(id: KittyImageID? = nil, placement: KittyPlacementID? = nil, message: String) {
    self.id = id
    self.placement = placement
    self.message = message
    self.success = message == "OK"
  }
  ```

- Add the remaining KGP value/command types to
  `Sources/TesseraTerminalANSI/KittyGraphics.swift` (all conformances and enum cases
  alphabetized):

  ```swift
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
    public var data: [UInt8]            // raw pixel or PNG bytes; NOT pre-base64ed
    public var format: KittyImageFormat
    public var id: KittyImageID
    public var quiet: KittyGraphicsQuiet  // default .suppressOK: errors still surface

    public init(id: KittyImageID, format: KittyImageFormat, data: [UInt8],
                quiet: KittyGraphicsQuiet = .suppressOK) {
      self.id = id
      self.format = format
      self.data = data
      self.quiet = quiet
    }
  }

  public struct KittyGraphicsPlacement: Equatable, Sendable {
    public var columns: Int?            // c= cell scaling
    public var id: KittyImageID
    public var placement: KittyPlacementID?
    public var quiet: KittyGraphicsQuiet  // default .suppressOK
    public var rows: Int?               // r= cell scaling
    public var zIndex: Int32            // z=, default 0

    public init(id: KittyImageID, placement: KittyPlacementID? = nil,
                columns: Int? = nil, rows: Int? = nil, zIndex: Int32 = 0,
                quiet: KittyGraphicsQuiet = .suppressOK) {
      self.id = id
      self.placement = placement
      self.columns = columns
      self.rows = rows
      self.zIndex = zIndex
      self.quiet = quiet
    }
  }

  public enum KittyGraphicsDelete: Equatable, Sendable {
    case all                                              // a=d,d=A (placements + data)
    case image(KittyImageID)                              // a=d,d=I,i= (image + data)
    case placement(KittyImageID, KittyPlacementID)        // a=d,d=i,i=,p= (data retained)
  }

  public enum KittyGraphicsCommand: Equatable, Sendable {
    case delete(KittyGraphicsDelete)
    case place(KittyGraphicsPlacement)
    case query(id: KittyImageID)   // i=<id>,s=1,v=1,a=q,t=d,f=24;AAAA — support probe
    case transmit(KittyGraphicsTransmission)
  }
  ```

Acceptance:

- `KittyImageID`/`KittyPlacementID`/`KittyGraphicsResponse` compile in
  `TesseraTerminalCore` with no dependency on `TesseraTerminalANSI`.
- The remaining KGP types compile in `TesseraTerminalANSI` and reuse the `Core` id types.
- `ANSIByteEncoding.appendAPC`/`appendST` exist and are not yet called by anything (that
  is Step 1.2).

### Step 1.2 — Wire `ControlSequence.kittyGraphics` through the encoder

- Files:
  - `Sources/TesseraTerminalANSI/ControlSequence.swift`
  - `Sources/TesseraTerminalANSI/KittyGraphics.swift`
- Add ONE new case to the `ControlSequence` enum declaration, alphabetized between
  `exitSynchronizedOutput` and `raw`:

  ```swift
  /// Sends a Kitty Graphics Protocol command as an APC-wrapped sequence.
  case kittyGraphics(KittyGraphicsCommand)
  ```

- `ControlSequence.encode(into:)`'s top-level dispatch switch groups cases by shared
  encoding behavior, not alphabetically (payload, cursor, erase, SGR, mode, then OSC, in
  that historical order — verify against the current file before editing). Add a new
  dispatch arm for the new case, following that same append-at-the-end convention:

  ```swift
  case .kittyGraphics:
    self.encodeKittyGraphics(into: &buffer)
  ```

- `kittyGraphics` does not fit `encodeCursor`/`encodeErase`/`encodeSGR`/`encodeMode`/
  `encodeOSC`/`encodePayload`, so it needs its own new private helper,
  `encodeKittyGraphics(into:)`, added beside the other five. Every one of those FIVE
  existing helpers has an exhaustive `case .bell, .cursorBack, ..., .text: break` arm
  listing every OTHER case alphabetically — add `.kittyGraphics,` to each of those five
  break-arm lists at its alphabetized position (between `.exitSynchronizedOutput,` and
  `.raw,` in every list, matching the enum's own declaration order). The compiler's
  exhaustiveness check will point at any list you miss.

  ```swift
  /// Encodes Kitty Graphics Protocol commands as APC-wrapped, base64-chunked bytes.
  private func encodeKittyGraphics(into buffer: inout [UInt8]) {
    switch self {
    case .kittyGraphics(let command):
      command.encode(into: &buffer)

    case .bell, .cursorBack, .cursorDown, .cursorForward, .cursorPosition, .cursorRestore,
      .cursorSave, .cursorUp, .cursorVisible, .enableBracketedPaste, .enableLineWrap,
      .enterAltScreen, .enterSynchronizedOutput, .eraseInDisplay, .eraseInLine,
      .exitAltScreen, .exitSynchronizedOutput, .raw, .resetAttributes, .setBackground,
      .setBold, .setDim, .setForeground, .setItalic, .setReverse, .setStrikethrough,
      .setUnderline, .setWindowTitle, .text:
      break
    }
  }
  ```

- Implement the actual byte assembly as an internal (non-public) extension on
  `KittyGraphicsCommand` in `Sources/TesseraTerminalANSI/KittyGraphics.swift` — this keeps
  `ControlSequence.swift` a thin dispatcher, matching how
  `EraseMode.displayEraseParameter` (an internal computed property beside `EraseMode`, not
  inside `ControlSequence`) backs `encodeErase`. `import Foundation` in this file for
  `Data.base64EncodedString()` — do not hand-roll base64
  (`PlatformIOError.swift:1`/`Renderer.swift:1` already import Foundation in this
  package):

  ```swift
  extension KittyGraphicsCommand {
    func encode(into buffer: inout [UInt8]) {
      switch self {
      case .delete(let delete):
        ANSIByteEncoding.appendAPC("G" + delete.controlString, into: &buffer)
        ANSIByteEncoding.appendST(into: &buffer)

      case .place(let placement):
        ANSIByteEncoding.appendAPC("G" + placement.controlString, into: &buffer)
        ANSIByteEncoding.appendST(into: &buffer)

      case .query(let id):
        // Verified detection probe shape (1x1 RGB pixel, direct transmission): the key
        // ORDER below is load-bearing — it matches the exact bytes real terminals are
        // tested against for KGP support detection.
        ANSIByteEncoding.appendAPC(
          "Gi=\(id.rawValue),s=1,v=1,a=q,t=d,f=24;AAAA",
          into: &buffer
        )
        ANSIByteEncoding.appendST(into: &buffer)

      case .transmit(let transmission):
        transmission.encodeChunks(into: &buffer)
      }
    }
  }

  extension KittyGraphicsDelete {
    fileprivate var controlString: String {
      switch self {
      case .all:
        "a=d,d=A"
      case .image(let id):
        "a=d,d=I,i=\(id.rawValue)"
      case .placement(let id, let placementID):
        "a=d,d=i,i=\(id.rawValue),p=\(placementID.rawValue)"
      }
    }
  }

  extension KittyGraphicsPlacement {
    fileprivate var controlString: String {
      var keys = ["a=p", "i=\(id.rawValue)"]
      if let placement { keys.append("p=\(placement.rawValue)") }
      if let columns { keys.append("c=\(columns)") }
      if let rows { keys.append("r=\(rows)") }
      keys.append("z=\(zIndex)")
      keys.append("C=1")  // Always emitted: the renderer owns the cursor, not the caller.
      keys.append("q=\(quiet.wireValue)")
      return keys.joined(separator: ",")
    }
  }

  extension KittyGraphicsQuiet {
    fileprivate var wireValue: Int {
      switch self {
      case .suppressFailures: 2
      case .suppressOK: 1
      case .verbose: 0
      }
    }
  }

  extension KittyGraphicsTransmission {
    fileprivate func encodeChunks(into buffer: inout [UInt8]) {
      let base64 = Array(Data(data).base64EncodedString().utf8)
      let chunkSize = 4096  // Already a multiple of 4; every non-final slice stays valid.
      var offset = 0
      var isFirstChunk = true

      repeat {
        let end = min(offset + chunkSize, base64.count)
        let isLastChunk = end == base64.count

        var keys: [String] = []
        if isFirstChunk {
          keys.append("a=t")
          keys.append("i=\(id.rawValue)")
          switch format {
          case .png:
            keys.append("f=100")
          case .rgb(let width, let height):
            keys.append("f=24")
            keys.append("s=\(width)")
            keys.append("v=\(height)")
          case .rgba(let width, let height):
            keys.append("f=32")
            keys.append("s=\(width)")
            keys.append("v=\(height)")
          }
          keys.append("t=d")
          keys.append("q=\(quiet.wireValue)")
        }
        keys.append("m=\(isLastChunk ? 0 : 1)")

        ANSIByteEncoding.appendAPC("G" + keys.joined(separator: ",") + ";", into: &buffer)
        buffer.append(contentsOf: base64[offset..<end])
        ANSIByteEncoding.appendST(into: &buffer)

        offset = end
        isFirstChunk = false
      } while offset < base64.count
    }
  }
  ```

  Note the `repeat`/`while` loop runs its body at least once even when `data` is empty
  (`base64.count == 0`), so an empty transmission still emits exactly one chunk (`m=0`,
  empty payload) instead of zero APC sequences — cover this with a test.

Acceptance:

- `ControlSequence.kittyGraphics(...)` is exhaustively wired through every grouped switch;
  the project does not compile with a missing arm.
- Transmit encoding always uses `t=d` (direct); no other medium is ever encoded.
- `place` always emits `C=1`; nothing makes it optional.
- `query` produces byte-for-byte the verified detection-probe sequence.

### Step 1.3 — Add exact byte tests for every KGP wire format

- File: `Tests/TesseraTerminalANSITests/ANSIEncoderTests.swift`.
- Follow the existing `expectBytes`/`esc`/`sgr` helper conventions in this file. Add exact
  byte assertions for:
  - `transmit` with `.rgb`, `.rgba`, and `.png` formats, each quiet level, confirming key
    order `a,i,f,[s,v],t,q,m` on the (only) chunk.
  - `transmit` with a payload just under, at, and over the 4096-byte base64 boundary,
    confirming: exactly one chunk when the base64 length is `<= 4096`; multiple chunks
    when it exceeds 4096; every non-final chunk is exactly 4096 base64 bytes; `m=1` on
    every non-final chunk and `m=0` on the last; only the FIRST chunk carries the
    `a=t,i=,f=,...` control keys, later chunks carry only `m=`.
  - `transmit` with empty `data` still emits exactly one chunk (`m=0`, empty payload).
  - `place` with and without a placement id, with and without `columns`/`rows`, with a
    non-zero `zIndex`, and for each quiet level — confirming `C=1` and the `q=` key are
    always present regardless of the other fields.
  - `delete(.all)`, `delete(.image(_))`, `delete(.placement(_,_)))` byte-for-byte.
  - `query(id:)` byte-for-byte against the verified detection-probe sequence.
  - Every APC sequence starts with `ESC _ G` (`0x1B, 0x5F, 0x47`) and ends with ST
    (`0x1B, 0x5C`).

Acceptance:

- Golden byte tests pin every command variant and both chunking boundary conditions
  (single chunk, multi-chunk split exactly at 4096).
- No test asserts on a hand-decoded base64 string; assert on the RAW bytes Tessera emits,
  matching the exact-byte convention already used for cursor/erase/SGR sequences in this
  file.

## Phase 2 — APC input parsing

**Goal**: `ESC _ ... ESC \` sequences become one semantic `.unknown` or
`.kittyGraphicsResponse` event instead of shredding into a bogus `Alt+_` key event
followed by garbage key/unknown events for the rest of the payload.

### Step 2.1 — Add the `.apc` parser state and stop shredding `ESC _`

- Files:
  - `Sources/TesseraTerminalInput/InputParser.swift`
  - `Sources/TesseraTerminalInput/InputEvent.swift`
- Add `case apc(accumulated: [UInt8])` to the parser's private `State` enum, alphabetized
  FIRST (`apc` sorts before `bracketedPaste`).
- `InputParser.swift` currently has NO imports (it never touches `TesseraTerminalCore`
  types directly). Add `import TesseraTerminalCore` — Phase 2.2 needs it for
  `KittyGraphicsResponse`/`KittyImageID`/`KittyPlacementID`.
- In `parseEscape(_:)`, add a `case 0x5F:` arm ABOVE the existing `case 0x20...0x7E:` arm
  (order matters: Swift tries switch cases top to bottom, and `0x5F` currently falls into
  that generic printable-ASCII range, producing
  `Key(code: .character("_"), modifiers: .alt)` — the exact bug this step fixes). The new
  arm enters `.apc`, seeded with the introducer bytes already consumed:

  ```swift
  case 0x5F:
    state = .apc(accumulated: [ANSIByteEncodingEscapeByte, byte])
    return []
  ```

  (`InputParser` has no `ANSIByteEncoding` dependency; use the literal byte `0x1B` for the
  already-consumed ESC instead of introducing a cross-target import for one constant.)

- Add a byte cap constant, e.g. `private static let apcByteCap = 4096`, and a new
  `parseAPC(_:accumulated:)` handler mirroring the existing `parseCSI`/`parseSS3` shape.
  Detect the two-byte ST terminator (`ESC \`) by checking whether the just-extended byte
  sequence ends in `[0x1B, 0x5C]` after each append — simpler than tracking a "saw-escape"
  flag across calls, and correct because APC payloads from a real terminal never contain a
  literal, unescaped ESC byte:

  ```swift
  private mutating func parseAPC(_ byte: UInt8, accumulated: [UInt8]) -> [InputEvent] {
    if byte == 0x18 || byte == 0x1A {  // CAN / SUB: abort per existing terminal convention.
      state = .ground
      return [.unknown(accumulated)]
    }

    let sequence = accumulated + [byte]

    if sequence.count >= 4, sequence.suffix(2) == [0x1B, 0x5C] {
      state = .ground
      return [decodeAPC(sequence)]
    }

    guard sequence.count < Self.apcByteCap else {
      // Overflow: flush everything captured so far as unknown. The parser is already
      // back in `.ground`, so the NEXT byte resynchronizes normally.
      state = .ground
      return [.unknown(sequence)]
    }

    state = .apc(accumulated: sequence)
    return []
  }
  ```

- Add a matching
  `case .apc(let accumulated): return parseAPC(byte, accumulated: accumulated)` arm to
  `feed(_:)`'s state switch, and a
  `case .apc(let accumulated): state = .ground; return [.unknown(accumulated)]` arm to
  `flush()`, mirroring the existing `.csi`/`.ss3` flush behavior (flush a still-open APC
  as `.unknown` rather than silently dropping it).
- Bracketed paste isolation needs NO code change: `parseBracketedPaste` only watches for
  its own six-byte end marker (`ESC [ 2 0 1 ~`) and otherwise appends every byte —
  including `ESC _` sequences — to the paste buffer as literal payload. Verify this with a
  test in Step 2.3 rather than adding special-case code.

Acceptance:

- `ESC _` no longer produces `Key(code: .character("_"), modifiers: .alt)`.
- A complete, well-formed APC sequence never leaks intermediate key/unknown events — only
  the terminal `.unknown`/`.kittyGraphicsResponse` event is emitted, once, at ST.
- CAN/SUB and the byte cap both return the parser to `.ground` cleanly.

### Step 2.2 — Decode `G`-prefixed APC payloads into `KittyGraphicsResponse`

- Files:
  - `Sources/TesseraTerminalInput/InputParser.swift`
  - `Sources/TesseraTerminalInput/InputEvent.swift`
- Add `case kittyGraphicsResponse(KittyGraphicsResponse)` to `InputEvent`, alphabetized
  between `key` and `paste`.
- Add a private `decodeAPC(_:)` that takes the FULL delimited sequence
  (`ESC _ <payload> ESC \`, matching how `.unknown(accumulated)` elsewhere in this parser
  always wraps the full raw sequence including its introducer) and returns exactly one
  `InputEvent`:

  ```swift
  private func decodeAPC(_ sequence: [UInt8]) -> InputEvent {
    let payload = sequence.dropFirst(2).dropLast(2)
    guard payload.first == 0x47 /* "G" */,
      let response = KittyGraphicsResponse(decoding: payload.dropFirst())
    else {
      return .unknown(sequence)
    }
    return .kittyGraphicsResponse(response)
  }
  ```

- Add a failable `KittyGraphicsResponse` decoder (private to this target, e.g. as a
  fileprivate extension in `InputParser.swift`) parsing the wire shape from the design
  contract's grounding facts: `i=<id>[,p=<placement>];<message>`, where `<message>` is
  either `OK` or `<CODE>:<detail>`:

  ```swift
  extension KittyGraphicsResponse {
    fileprivate init?(decoding payload: ArraySlice<UInt8>) {
      guard let text = String(validating: Array(payload), as: UTF8.self),
        let semicolon = text.firstIndex(of: ";")
      else {
        return nil
      }

      var id: KittyImageID?
      var placement: KittyPlacementID?
      for pair in text[..<semicolon].split(separator: ",") {
        let parts = pair.split(separator: "=", maxSplits: 1)
        guard parts.count == 2, let value = UInt32(parts[1]) else {
          continue
        }
        switch parts[0] {
        case "i": id = KittyImageID(rawValue: value)
        case "p": placement = KittyPlacementID(rawValue: value)
        default: break
        }
      }

      self.init(id: id, placement: placement, message: String(text[text.index(after: semicolon)...]))
    }
  }
  ```

  (`String(validating:as:)` is the same API already used at `InputParser.swift:310` for
  CSI parameter bytes — reuse it, do not hand-roll UTF-8 validation.)

- A non-`G` APC (or a `G` payload that fails to decode) becomes exactly ONE
  `.unknown(sequence)` event for the WHOLE sequence — never shredded into per-character
  events. This is the direct regression target for the pre-existing bug.

Acceptance:

- `ESC _ Gi=31;OK ESC \` decodes to
  `.kittyGraphicsResponse(KittyGraphicsResponse(id: KittyImageID(rawValue: 31), message: "OK"))`
  with `success == true`.
- An error response (`ESC _ Gi=7;ENOENT:no such image ESC \`) decodes with
  `success == false` and the full message preserved.
- A non-`G` APC and a malformed `G` APC both become a single `.unknown` event covering the
  entire `ESC _ ... ESC \` sequence.

### Step 2.3 — Add parser tests, including the Alt+`_` regression

- File: `Tests/TesseraTerminalInputTests/InputParserTests.swift`.
- Follow the existing `ParserCase`/`@Test(arguments:)` conventions in this file. Add tests
  for:
  - a byte-by-byte fed, complete `ESC _ Gi=1;OK ESC \` decodes to one
    `.kittyGraphicsResponse` event, not a `.key`/`.unknown` stream.
  - a REGRESSION test asserting `ESC _` followed by any other byte never produces
    `Key(code: .character("_"), modifiers: .alt)` (the exact bug being fixed).
  - a response WITH a placement id (`p=`) decodes both `id` and `placement`.
  - an error response (non-`OK` message) decodes with `success == false` and the message
    text intact.
  - a non-`G` APC (e.g. `ESC _ Xhello ESC \`) becomes one `.unknown` covering the whole
    sequence.
  - a malformed `G` payload (missing `;`, non-numeric `i=`) becomes one `.unknown`.
  - CAN and SUB abort an in-progress APC to `.unknown` and return to ground cleanly (the
    next fed byte parses normally afterward).
  - an APC sequence that never terminates is flushed as `.unknown` by `flush()`.
  - an APC sequence exceeding the byte cap flushes as `.unknown` and the parser accepts
    the next byte normally (no permanent state corruption).
  - an `ESC _ G... ESC \` sequence embedded inside an open bracketed-paste block remains
    literal paste text — the paste event's payload contains the raw bytes, and no
    `.kittyGraphicsResponse`/`.unknown` event is emitted mid-paste.
  - APC sequences interleaved with ordinary key events in one transcript (mirroring this
    file's inline-snapshot transcript style for multi-event runs).

Acceptance:

- The Alt+`_` regression test explicitly documents, in its name, the bug it prevents from
  reappearing.
- Every existing parser test (keys, paste, focus-adjacent unknowns) stays green — `.apc`
  is additive, not a behavior change to any other state.

## Phase 3 — Pixel geometry

**Goal**: Tessera can report per-cell pixel dimensions when the platform exposes them
(POSIX `TIOCGWINSZ`), and reports `nil` everywhere else, without adding any new query
machinery.

### Step 3.1 — Add `CellPixelSize` and the `TerminalDevice.cellPixelSize` seam

- Files:
  - `Sources/TesseraTerminalCore/TerminalGeometry.swift`
  - `Sources/TesseraTerminalIO/TerminalDevice.swift`
- Add the value type beside `TerminalSize` in the existing geometry file (do not create a
  new file; `TerminalGeometry.swift` already bundles `TerminalSize`/`TerminalPosition`/
  `Rect` as one cohesive concept area):

  ```swift
  /// The terminal's per-cell pixel dimensions, when the platform reports them.
  public struct CellPixelSize: Equatable, Hashable, Sendable {
    public var height: Int
    public var width: Int
  }
  ```

- `TerminalSize` itself is NOT modified — it stays the resize-event payload; pixel
  geometry is a separate, independently-nil-able signal.
- Add a new stored closure to `TerminalDevice`, inserted alphabetically between `bytes`
  and `cleanupState` (matching the struct's existing alphabetized property order), with a
  default of `{ nil }` so every existing `TerminalDevice(...)` call site in tests and
  `InMemoryTerminalDevice` keeps compiling unchanged:

  ```swift
  /// Reads the terminal's current per-cell pixel size, or `nil` when unknown.
  package var cellPixelSize: @Sendable () async -> CellPixelSize?
  ```

  Add the matching initializer parameter
  (`cellPixelSize: @escaping @Sendable () async -> CellPixelSize? = { nil }`) at the same
  alphabetized position, and assign it in `init`.

Acceptance:

- `CellPixelSize` is `Equatable, Hashable, Sendable` with exactly `height`/`width`, field
  order alphabetized.
- Every existing `TerminalDevice(...)` construction (tests, `InMemoryTerminalDevice`,
  `.failing`/`.unsupported`) compiles unchanged because of the `{ nil }` default.

### Step 3.2 — Implement POSIX/Windows/in-memory pixel geometry and expose the session accessor

- Files:
  - `Sources/TesseraTerminalIO/TerminalDevice+Live.swift`
  - `Sources/TesseraTerminalIO/WindowsConsole.swift`
  - `Sources/TesseraTerminalIO/PlatformIO.swift`
  - `Sources/TesseraTerminal/TerminalSession.swift`
  - `Sources/TesseraTerminalTestSupport/InMemoryTerminalDevice.swift`
  - `Tests/TesseraTerminalIOTests/TerminalDeviceLiveTests.swift`
  - `Tests/TesseraTerminalIOTests/PlatformIOSizeTests.swift`
  - `Tests/TesseraTerminalTests/TerminalSessionTests.swift`
- POSIX (`#if os(macOS) || os(Linux)` block in `TerminalDevice+Live.swift`): add a private
  helper reading the SAME `TIOCGWINSZ` ioctl call `readTerminalSize(fileDescriptor:)`
  already uses (do not add a new syscall or a `CSI 16 t` active query — that query is
  explicitly deferred to Slice 6's active-query machinery; ratatui-image's own priority
  order documents `CSI 16 t` first, `TIOCGWINSZ` fallback, hardcoded default last — this
  slice ships the `TIOCGWINSZ` fallback tier):

  ```swift
  private func readCellPixelSize(fileDescriptor: CInt) -> CellPixelSize? {
    var windowSize = winsize()
    guard ioctl(fileDescriptor, UInt(TIOCGWINSZ), &windowSize) != -1,
      windowSize.ws_col > 0, windowSize.ws_row > 0,
      windowSize.ws_xpixel > 0, windowSize.ws_ypixel > 0
    else {
      return nil
    }

    return CellPixelSize(
      height: Int(windowSize.ws_ypixel) / Int(windowSize.ws_row),
      width: Int(windowSize.ws_xpixel) / Int(windowSize.ws_col)
    )
  }
  ```

  Wire it into the POSIX branch of `TerminalDevice.live(handles:)`:
  `cellPixelSize: { readCellPixelSize(fileDescriptor: stdout) }` (non-throwing — any
  failure or zero field simply reports `nil`, matching the "advisory, not truth" posture
  the rest of this device already has for size).

- Windows (`#if os(Windows)` branch of the same function): wire `cellPixelSize: { nil }`
  explicitly. `WindowsConsole.swift`'s `windowsTerminalSize(rawHandle:)` only reads the
  cell rectangle via `GetConsoleScreenBufferInfo`; do NOT add `GetCurrentConsoleFontEx`
  speculation — Windows Terminal has no KGP support (grounding facts), so there is no
  consumer for Windows pixel geometry yet.
- `PlatformIO`: add a passthrough, alphabetized beside `size()`:

  ```swift
  /// Reads the terminal's per-cell pixel size, or `nil` when unknown.
  package func cellPixelSize() async -> CellPixelSize? {
    await terminalDevice.cellPixelSize()
  }
  ```

- `TerminalSession`: expose an async computed property (not a throwing method — this
  signal is advisory and never fails, only reports `nil`):

  ```swift
  /// The terminal's per-cell pixel size, or `nil` when unknown.
  public var cellPixelSize: CellPixelSize? {
    get async { await io.cellPixelSize() }
  }
  ```

- `InMemoryTerminalDevice`: add an optional `storedCellPixelSize: CellPixelSize?` (default
  `nil`) alongside `storedSize`, an `init` parameter for it, and wire
  `cellPixelSize: { await self.storedCellPixelSize }` into the `terminalDevice` computed
  property.
- Extend `TerminalDeviceLiveTests.PTYFixture.setSize` with optional `xPixel`/`yPixel`
  parameters defaulting to `0` (preserving every existing call site's behavior), so a new
  test can configure a PTY with real pixel geometry via `ioctl(TIOCSWINSZ)`.

Add tests for:

- POSIX: a PTY configured with nonzero `ws_xpixel`/`ws_ypixel` reports the correct divided
  `CellPixelSize` (`TerminalDeviceLiveTests.swift`, following the existing PTY-fixture
  pattern used by `` `live terminal reads configured pty size` ``).
- POSIX: a PTY configured with zero pixel fields (the default, matching current
  `setSize`'s always-zero `ws_xpixel`/`ws_ypixel`) reports `nil`.
- `PlatformIO.cellPixelSize()` passes through the underlying `TerminalDevice` value,
  mirroring `` `size returns queried terminal size` `` in `PlatformIOSizeTests.swift`.
- `TerminalSession.cellPixelSize` returns `nil` when the underlying device reports `nil`,
  and the configured value otherwise, using `InMemoryTerminalDevice`.

Acceptance:

- Every zero pixel field (including a zero column/row count) maps to `nil`, never a
  divide-by-zero or a bogus `CellPixelSize(height: 0, width: 0)`.
- Windows always reports `nil`; no `GetCurrentConsoleFontEx` call is added.
- No new active query (`CSI 16 t` or otherwise) is added anywhere in this step.

## Phase 4 — Session, Frame, cleanup, and snapshot harness

**Goal**: Applications can transmit an image once, place it every frame with self-healing,
flicker-free semantics, and Tessera always cleans up images/placements on exit — verified
against a real libghostty-vt-backed virtual terminal.

### Step 4.1 — Add `TerminalSession.queryKittyGraphicsSupport`/`transmitImage`/`deleteImages` and `Frame.placeImage`

- Files:
  - `Sources/TesseraTerminal/TerminalSession.swift`
  - `Sources/TesseraTerminal/Frame.swift`
  - `Tests/TesseraTerminalTests/TerminalSessionTests.swift`
  - `Tests/TesseraTerminalTests/FrameTests.swift`
- Add the session-scoped query, transmission, and deletion API. They follow the exact
  write-then-flush shape `TerminalSession.restoreCursorVisibility()` already uses for
  session-scoped I/O outside `draw`; the query writes the KGP `a=q` command immediately
  followed by DA1 before flushing so APC/no-response terminals can be fenced by DA1.

  ```swift
  extension TerminalSession {
    /// Transmits image data over the tty (t=d, chunked). Session-scoped, outside draw.
    public func transmitImage(_ transmission: KittyGraphicsTransmission) async throws {
      await io.write(ControlSequence.kittyGraphics(.transmit(transmission)).bytes)
      try await io.flush()
    }

    /// Deletes images/placements immediately (also used by teardown).
    public func deleteImages(_ delete: KittyGraphicsDelete) async throws {
      await io.write(ControlSequence.kittyGraphics(.delete(delete)).bytes)
      try await io.flush()
    }
  }
  ```

  "Also used by teardown" describes the SAME encoded bytes, not a shared call site:
  `ModeLifecycle` (Step 4.2) lives below `TerminalSession` in the dependency graph and
  cannot call it, so teardown independently encodes
  `ControlSequence.kittyGraphics(.delete(.all))` itself.

- Add the frame-scoped placement API. `Frame` is `~Copyable, ~Escapable`; every existing
  method (`write`/`writeRaw`/`markOpaque`) is `public borrowing func`, so `placeImage`
  matches that convention exactly (not the `mutating` spelling in the design contract's
  illustrative sketch — the sketch describes behavior, not the literal keyword):

  ```swift
  extension Frame {
    /// Encodes an `a=p` placement anchored at `position` and reserves `region`.
    ///
    /// `position` MUST equal `region.origin` — KGP places images extending right and
    /// down from the cursor, so the anchor is always the placement's top-left cell.
    public borrowing func placeImage(
      _ placement: KittyGraphicsPlacement,
      at position: TerminalPosition,
      occupying region: Rect
    ) {
      let payload = RawTerminalPayload(
        bytes: ControlSequence.kittyGraphics(.place(placement)).bytes
      )
      writeRaw(payload, at: position, occupying: region, repaintPolicy: .alwaysRepaint)

      // Opaque-mark every covered cell OTHER than the anchor so nothing else drawn in
      // this frame overwrites the image's screen region. Decomposed into up to two
      // sub-rects (rest of the anchor's row, plus every row below it) specifically to
      // avoid re-touching the anchor cell: `Buffer.markOpaque` reclaims any existing
      // wide/raw cluster at each cell it covers, which would blank the anchor's own
      // `.raw` content if the anchor were included in this call.
      if region.size.columns > 1 {
        markOpaque(
          Rect(
            column: position.column + 1,
            row: position.row,
            columns: region.size.columns - 1,
            rows: 1
          )
        )
      }
      if region.size.rows > 1 {
        markOpaque(
          Rect(
            column: region.origin.column,
            row: position.row + 1,
            columns: region.size.columns,
            rows: region.size.rows - 1
          )
        )
      }
    }
  }
  ```

  The anchor cell ends up `.raw(payload)` content with `.alwaysRepaint` diff policy — the
  self-healing rationale below depends on this being `.alwaysRepaint`, not `.opaque`. The
  non-anchor covered cells end up `diffPolicy == .opaque` (their content tag after
  `Buffer.markOpaque`'s cluster-reclaim step becomes `.blank`, not `.continuation` — this
  is harmless because `BufferDiff.splitAroundOpaqueCells` excludes `.opaque` cells from
  every future damage run purely by `diffPolicy`, regardless of content tag; assert on
  `diffPolicy`, not content, in tests).

- Self-healing rationale (document this in the doc comment above, concisely): re-sending
  an identical `(image id, placement id)` placement is a flicker-free, in-place
  replace/move per the KGP spec. Marking the anchor `.alwaysRepaint` means
  `BufferDiff.dirtyColumns` (`oldCell != newCell || newCell.diffPolicy == .alwaysRepaint`)
  includes it in EVERY damage computation, so the placement bytes are re-emitted on every
  `draw`. This makes placements self-healing across `Renderer.encodeFrame`'s own
  `eraseInDisplay(.all)` call, which fires whenever `previous == nil` or the terminal size
  changed (`Renderer.swift:41-44`) — and per the KGP spec, `CSI 2 J` clears ALL images.
  Without `.alwaysRepaint` on the anchor, a resize would silently and permanently lose
  every placed image. Document the accompanying caveat too: the underlying image DATA can
  still be evicted by the terminal under storage-quota pressure even though the placement
  keeps re-sending; an `ENOENT`-style `KittyGraphicsResponse` (Phase 2) is the signal an
  app should use to retransmit via `transmitImage`.
- The caller keeps `occupying`/`columns`/`rows` consistent; Tessera does not compute one
  from the other in this slice (Phase 4's `Image` view will, using `cellPixelSize`).

Add tests for:

- `TerminalSession.queryKittyGraphicsSupport` writes the exact KGP `query(id:)` bytes,
  appends primary device attributes (`ESC [ c`) before flushing, and does not wait for a
  response.
- `TerminalSession.transmitImage`/`deleteImages` write the exact
  `ControlSequence.kittyGraphics(...)` bytes and flush, using `InMemoryTerminalDevice`
  (mirroring how `TerminalSessionTests.swift` already exercises other session-scoped
  writes).
- `Frame.placeImage` (using this file's existing `withFrame` helper): the anchor cell has
  `content == .raw(payload)` and `diffPolicy == .alwaysRepaint`; every other cell in
  `region` has `diffPolicy == .opaque`.
- Re-placing the SAME `(id, placement)` at the same position twice across two separate
  `withFrame` calls produces byte-identical anchor content both times (the "flicker-free
  replace" contract, at the buffer level).

Acceptance:

- `Frame.placeImage` never mutates the anchor cell's diff policy away from
  `.alwaysRepaint`.
- No production code anywhere computes `columns`/`rows` from `cellPixelSize`; that stays
  entirely the caller's responsibility this slice.

### Step 4.2 — Add the unconditional delete-all cleanup sequence

- Files:
  - `Sources/TesseraTerminalIO/ModeLifecycle.swift`
  - `Tests/TesseraTerminalIOTests/ModeLifecycleTests.swift`
- `installCleanup()` (the emergency/signal-handler cleanup byte assembly, invoked by
  `enter(_:)` after all requested modes are acquired) currently builds `teardownBytes`
  conditionally per mode, then unconditionally shows the cursor. Add the delete-all APC
  UNCONDITIONALLY (about a dozen bytes; harmless on non-supporting terminals), positioned
  BEFORE the conditional `exitAltScreen` encode — a compliant terminal already clears
  alt-screen images on exit, but this is defense-in-depth against the documented
  WezTerm/Konsole non-conformance gaps:

  ```swift
  private func installCleanup() async {
    var teardownBytes: [UInt8] = []

    // Unconditional Kitty Graphics cleanup: harmless APC noise on terminals that never
    // saw a KGP command, and defense-in-depth against terminals that do not fully clear
    // alt-screen images on their own. Must precede leaving the alternate screen.
    ControlSequence.kittyGraphics(.delete(.all)).encode(into: &teardownBytes)

    // DEC private mode 2004: disable bracketed paste, `CSI ? 2004 l`.
    if modes.contains(.bracketedPaste) || requestedModes.contains(.bracketedPaste) {
      ControlSequence.enableBracketedPaste(false).encode(into: &teardownBytes)
    }

    // DEC private mode 1049: leave alternate screen, `CSI ? 1049 l`.
    if modes.contains(.altScreen) || requestedModes.contains(.altScreen) {
      ControlSequence.exitAltScreen.encode(into: &teardownBytes)
    }

    // DEC private mode 25: show cursor, `CSI ? 25 h`.
    ControlSequence.cursorVisible(true).encode(into: &teardownBytes)

    await io.installCleanup(teardownBytes: teardownBytes)
  }
  ```

- `exit()` (the normal, non-emergency teardown path) iterates `Mode` cases in reverse
  acquisition order and calls `disable(mode)` per mode; graphics is not a `Mode`, so it
  needs its own explicit, unconditional write. Add it at the TOP of `exit()`, before the
  reversed-order disable loop begins — this guarantees it runs before `.altScreen`'s
  disable step (which is reached partway through that loop) whenever alt-screen was
  active, and is a harmless no-op write otherwise:

  ```swift
  public func exit() async throws {
    // Unconditional Kitty Graphics cleanup, before any mode is torn down — see
    // `installCleanup()` for the matching emergency-path sequence and rationale.
    await io.write(ControlSequence.kittyGraphics(.delete(.all)).bytes)
    try? await io.flush()

    let cleanupModes = modes.union(requestedModes)
    var firstError: (any Error)?
    // ... existing reversed-order disable loop unchanged ...
  }
  ```

  Use `try?` for this specific flush (not `try`): a failure to write the graphics
  delete-all must never prevent the REST of `exit()`'s mode teardown from running, since
  losing raw-mode/alt-screen restoration is strictly worse for the user than a stray image
  surviving on a terminal that already failed one write.

Add lifecycle tests for:

- Normal `exit()` always writes `ControlSequence.kittyGraphics(.delete(.all)).bytes`
  before any mode-disable bytes, regardless of which modes (if any) were active.
- Emergency `teardownBytes` (via `installCleanup()`, inspected the same way existing
  `ModeLifecycleTests.swift` tests inspect cleanup byte transcripts) always start with the
  delete-all APC, before the conditional bracketed-paste/alt-screen bytes.
- A session that never touched graphics still emits the delete-all bytes on both paths
  (this is the "harmless everywhere" guarantee, not an opt-in).

Acceptance:

- Delete-all bytes appear on EVERY exit and EVERY emergency-cleanup transcript, with no
  configuration flag to disable them.
- Delete-all bytes always precede `exitAltScreen`'s bytes when alt-screen was active, on
  both the normal and emergency paths.
- A failed graphics-cleanup flush in `exit()` never prevents raw-mode/alt-screen/paste
  teardown from completing.

### Step 4.3 — Extend the Ghostty snapshot harness with graphics inspection endpoints

- Files:
  - `Sources/TesseraTerminalSnapshotSupport/VirtualTerminal.swift`
  - new `Sources/TesseraTerminalSnapshotSupport/RenderedKittyGraphics.swift`
  - `Sources/TesseraTerminalSnapshotSupport/VirtualTerminal+Ghostty.swift`
  - `Sources/TesseraTerminalSnapshotSupport/VirtualTerminal+ghosttyUnavailable.swift`
  - `Tests/TesseraTerminalSnapshotSupportTests/VirtualTerminalTests.swift`
  - `Tests/TesseraTerminalANSITests/ANSIEncoderTests.swift`
- The vendored `Sources/CGhosttyVT/include/ghostty/vt/kitty_graphics.h` (pinned revision
  `ae52f97dcac558735cfa916ea3965f247e5c6e9e`, per `scripts/ghostty-vt-version.txt`)
  already exposes a complete inspection API — READ THIS HEADER before writing this step,
  along with `selection.h` and `grid_ref.h` for the placement-rect return shape. Key entry
  points confirmed present in the pinned revision:
  - `ghostty_terminal_get()` with `GHOSTTY_TERMINAL_DATA_KITTY_GRAPHICS` to obtain a
    `GhosttyKittyGraphics` handle from an existing terminal.
  - Enabling storage: `GHOSTTY_TERMINAL_OPT_KITTY_IMAGE_STORAGE_LIMIT` (a non-zero limit
    must be set before any image is stored) and, for PNG format tests,
    `GHOSTTY_SYS_OPT_DECODE_PNG` via `ghostty_sys_set()`.
  - `ghostty_kitty_graphics_placement_iterator_new`/`_free`/`_set`/`_next`/`_get` to walk
    placements; `GhosttyKittyGraphicsPlacementData` fields include `IMAGE_ID`,
    `PLACEMENT_ID`, `COLUMNS`, `ROWS`, `Z`.
  - `ghostty_kitty_graphics_image`/`_get` for image metadata
    (`GhosttyKittyGraphicsImageData`), including format (`GhosttyKittyImageFormat`:
    RGB/RGBA/PNG/GRAY_ALPHA/GRAY).
  - `ghostty_kitty_graphics_placement_rect(iterator:image:terminal:out_selection:)`
    resolves a placement's on-screen grid rectangle (a `GhosttySelection`); the placement
    data fields alone (`X_OFFSET`/`Y_OFFSET`/`COLUMNS`/`ROWS`) do not include an anchor
    grid position, so this is the accessor to use for screen position, not manual
    reconstruction from the other fields.
  - If any needed accessor is missing from the pinned revision, bump it per
    `docs/UpdatingGhosttyVT.md` rather than shelling out to a raw C call from Swift.
- Add two new `unimplemented`-defaulted endpoints to `VirtualTerminal`, following the
  exact pattern `cell`/`cursor`/`snapshot` already use (placeholder values, wired through
  both `VirtualTerminal.ghostty(cols:rows:)` and `.ghosttyUnavailable`):

  ```swift
  public var kittyImages: @Sendable () -> [RenderedKittyImage]
  public var kittyPlacements: @Sendable () -> [RenderedKittyPlacement]
  ```

- Add the two new public value types in a new file, following `RenderedCell.swift`'s
  plain-struct style:

  ```swift
  public struct RenderedKittyImage: Sendable, Equatable {
    public let id: UInt32
    public let width: Int
    public let height: Int
  }

  public struct RenderedKittyPlacement: Sendable, Equatable {
    public let imageID: UInt32
    public let placementID: UInt32
    public let column: Int
    public let row: Int
    public let columns: Int
    public let rows: Int
    public let zIndex: Int32
  }
  ```

  (Exact field set may grow slightly once the header's return shapes are read in full;
  keep it minimal — image id/dimensions and placement id/position/extent/z are the fields
  the acceptance tests below need.)

- Implement `GhosttyTerminalState.kittyImages()`/`kittyPlacements()` in
  `VirtualTerminal+Ghostty.swift`, following the existing `cell(row:column:)`/
  `snapshot()` pattern (acquire the `Mutex<GhosttyTerminalHandles>`, call the C API,
  translate `GhosttyResult` failures via the existing `check`/`report` helpers).
  `VirtualTerminal+ghosttyUnavailable.swift` gets loud `unimplemented` closures for both,
  matching its existing style for every other endpoint.

Add tests for:

- `Tests/TesseraTerminalSnapshotSupportTests/VirtualTerminalTests.swift`: after enabling
  Kitty image storage and feeding a small RGB transmit + place sequence (built with
  `ControlSequence.kittyGraphics(...).bytes`, not hand-written escape strings),
  `kittyImages()`/`kittyPlacements()` report the expected id, format, dimensions,
  position, and z-index — following this file's existing
  `.disabled(if: VirtualTerminal.isGhosttyUnavailable, ...)` convention.
- `Tests/TesseraTerminalANSITests/ANSIEncoderTests.swift`: a round-trip test (matching
  this file's existing `feed([...], into: terminal)` convention) that transmits, places,
  then RE-PLACES the same `(id, placement)` at a new position and asserts the placement
  MOVED rather than duplicated (`kittyPlacements()` still returns exactly one entry for
  that id/placement pair).
- Deleting via `.delete(.all)` clears `kittyImages()`/`kittyPlacements()` to empty.
- A cell inside a placed image's `Frame.placeImage`-reserved region, written with normal
  text via a DIFFERENT, later `Frame` write in the SAME row but outside the placement's
  columns, still renders that OTHER text correctly — proving opaque marking does not leak
  beyond the reserved region.

Acceptance:

- Every new snapshot test is `.disabled(if: VirtualTerminal.isGhosttyUnavailable, ...)`,
  matching every existing Ghostty-backed test in this codebase.
- The harness proves the full `transmit -> place -> re-place -> delete` lifecycle against
  a real libghostty-vt terminal, not just against Tessera's own byte encoder.

## Phase 5 — Example app and validation

**Goal**: Reviewers can see a real image placed and self-healed across resizes without
waiting for Phase 4's `Image` view, using only bytes Tessera generates procedurally (no
bundled asset, no PNG dependency).

### Step 5.1 — Add the graphics panel to `Phase3ProtocolsDemo`

- Files:
  - `Examples/Sources/Phase3ProtocolsDemo/Phase3ProtocolsDemo.swift`
  - `Examples/Package.swift` only if the target's dependency list needs
    `TesseraTerminalANSI`/`TesseraTerminalCore` added explicitly (check current
    dependencies first — `TesseraTerminal` may already re-export what is needed)
- `Phase3ProtocolsDemo` currently has NO panel navigation at all — it is a single paste
  demo (`Phase3ProtocolsDemo.swift` has no `1`/`2`/`3` digit switching yet, because no
  prior Phase 3 slice's example work has landed in this tree). By the time this slice is
  implemented, prior slices (paste, focus, mouse, kitty keyboard, hyperlinks,
  capabilities) may already have added their own numbered panels. Inspect the demo's
  CURRENT panel list at implementation time and claim the NEXT unclaimed digit — do not
  hardcode a specific number in this plan or in the implementation.
- Add a graphics panel that:
  - Generates a small RGBA gradient PROCEDURALLY at startup (e.g. a 32x32 or similar small
    buffer where each pixel's channels are a function of its x/y coordinates) — NO bundled
    image asset, NO PNG decoding dependency. Build the raw byte buffer directly and pass
    it as `KittyGraphicsTransmission(id:format: .rgba(width:height:), data:)`.
  - Calls `terminal.transmitImage(...)` once (e.g. on first draw of this panel, guarded so
    it does not re-transmit every frame).
  - Calls `frame.placeImage(...)` every time this panel draws, anchored at a fixed
    position with `occupying` sized from the gradient's cell-column/row footprint (a small
    fixed `columns`/`rows`, e.g. 8x4 cells — this slice does not compute cell extent from
    `cellPixelSize`).
  - Displays `await terminal.cellPixelSize` (formatted as `WxH px/cell` or "unknown" when
    `nil`) so reviewers can see the new geometry signal.
  - Notes graceful degradation directly in the panel text: on a terminal without KGP
    support, the placement APC is silently ignored, the reserved region simply shows blank
    cells, and the rest of the app keeps working — no error, no crash.

Wireframe:

```text
Phase3ProtocolsDemo — Graphics                                    80x24
q quit · 1 paste · ... · N graphics
Terminal: 80x24 · cell pixels: 9x18 px

Kitty Graphics Protocol
  transmitted image id 1 (32x32 RGBA gradient, procedurally generated)
  placement occupies 8x4 cells at column 2, row 5
  on unsupported terminals, this region stays blank — nothing else breaks

  [ image placement renders here in supporting terminals ]

Recent events
  0012 resize 80x24
```

Acceptance:

- No bundled image file, PNG decoder, or third-party image dependency is added anywhere in
  `Examples/`.
- The panel calls `transmitImage` at most once per gradient (not once per frame); it calls
  `placeImage` every frame so the placement self-heals across resize.
- The app still runs, navigates, and renders every other panel on a terminal without KGP
  support.

### Step 5.2 — Run narrow encoder, parser, IO, session, snapshot, and example checks

Run:

```fish
swift test --filter TesseraTerminalANSITests
swift test --filter TesseraTerminalInputTests
swift test --filter TesseraTerminalIOTests
swift test --filter TesseraTerminalTests
swift test --filter TesseraTerminalSnapshotSupportTests
swift build --package-path Examples --product Phase3ProtocolsDemo
just quality changed
```

Acceptance:

- Every KGP encoder, parser, pixel-geometry, session/frame, cleanup, and snapshot-harness
  test passes, alongside every pre-existing test in these five targets.
- The example package builds with the new graphics panel.
- `just quality changed` is clean on every file this plan touches.
