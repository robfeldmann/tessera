## Framing

Tessera is the Swift counterpart to Ratatui — a cell-buffer rendering and view layer for
terminal apps — with a compositional layout API inspired by Lip Gloss's Join/Place/Compose
primitives. Architecture-agnostic; bring your own state management.

- A cell buffer ✓
- A renderer with damage tracking ✓
- A View protocol and built-in views ✓
- Layout primitives ✓
- Input parsing ✓
- An optional runtime, architecture-agnostic ✓

## Phase 0: Foundation

Phase 0 has exactly one job: **prove your development loop works before you write anything
interesting.** That's it. Every minute you spend in Phase 0 is a minute you're not
learning about terminals, so the goal is to get _out_ of Phase 0 as fast as possible while
still having a foundation you won't have to rebuild.

A useful test: when you finish Phase 0, you should be able to say "I can edit a Swift
file, run `swift test`, see it pass locally, push to GitHub, see CI pass on three OSes,
and generate DocC — all without thinking about it." If any of those friction-causes you,
Phase 0 isn't done. If all of them are smooth, Phase 0 _is_ done, even if your library
does literally nothing yet.

### Repo and package structure

- [x] Git repo initialized
- [x] `Package.swift` with two library products declared: `TesseraTerminal` and `Tessera`
      plus associated test targets.
- [x] A _placeholder_ public symbol in each module so each product exports _something_ and
      DocC has something to render
- [x] A trivial test per target that imports the module and asserts on the placeholder,
      proving the test target is wired correctly
- [x] Swift 6 strict concurrency settings
- [x] Formatting (swift-format?) and linting (SwiftLint?) configured
- [x] DocC generation configured
- [x] `README.md` with the pitch
- [x] A `CONTRIBUTING.md` or equivalent if you want one, though this can wait
- [ ] GitHub Actions matrix running `swift build` and `swift test` on macOS, Ubuntu, and
      Windows
- [ ] `DESIGN.md` (live decisions log)

### Setup Github CI

For Phase 0 done, the matrix needs `swift build` and `swift test` passing on:

- **macOS** — latest runner, Swift 6.x toolchain (whatever ships with current Xcode)
- **Ubuntu** — latest LTS, official Swift toolchain
- **Windows** — Server 2022 runner, official Swift toolchain

The Windows one is the one most likely to bite you. Swift on Windows has matured a lot but
SwiftPM behavior, path handling, and toolchain installation still have rough edges
compared to Apple platforms. Worth getting it working _now_ with an empty package, because
debugging "why doesn't my termios shim compile on Windows" is much harder when CI itself
is also broken.

#### Concrete workflow shape

A minimal `.github/workflows/ci.yml` that I'd suggest for Phase 0:

```yaml
name: CI
on:
  push:
    branches: [main]
  pull_request:

jobs:
  test:
    strategy:
      fail-fast: false
      matrix:
        os: [macos-latest, ubuntu-latest, windows-latest]
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4
      - uses: SwiftyLab/setup-swift@latest
        with:
          swift-version: "6.1" # or whatever your Package.swift requires
      - run: swift build
      - run: swift test

  lint:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - run: swift format lint --recursive --strict Sources Tests
      # plus SwiftLint if you're using it

  docs:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - run: swift package generate-documentation --target Tessera
      - run: swift package generate-documentation --target TesseraTerminal
```

`fail-fast: false` is important — when Windows breaks, you want to see whether Linux and
macOS still pass, not have the whole matrix abort.

#### A note on `SwiftyLab/setup-swift`

It's the de facto community action for installing Swift toolchains across all three OSes.
Apple doesn't ship an official one. There's also `swift-actions/setup-swift` which is
older and less maintained. Either works; `SwiftyLab` is the safer current choice as
of 2026.

#### Things to consciously _not_ do in Phase 0 CI

- **No release builds.** `swift build -c release` is slower and you don't need it yet.
- **No code coverage.** Adds setup time, irrelevant when you have one placeholder test.
- **No DocC _publishing_.** Generating in CI is fine (it catches broken doc comments
  early); deploying to Pages can wait until you have something worth documenting.
- **No caching.** Tempting, but premature. The build is empty; there's nothing to cache.
  Add it in Phase 2 when builds get slow.
- **No branch protection rules requiring green CI.** Set those up _after_ you've seen the
  matrix go green at least once organically.

### What "Phase 0 done" looks like, concretely

When you can do all of the following without thinking, Phase 0 is done:

1. `git push` to main, CI runs and goes green on macOS + Linux + Windows within ~5
   minutes.
2. `swift test` locally produces a passing test (the placeholder).
3. `swift package generate-documentation` produces DocC output without warnings.
4. `swift format lint` exits 0.
5. A new contributor (or future-you on a new machine) can clone, run `swift test`, and
   have it work.

If any of these are not yet smooth, that's the work. If all of them are smooth, **stop and
move to Phase 1.** Don't gild Phase 0.

### A heads-up about a likely Windows snag

When you do push and Windows CI runs for the first time, the most common failure is one
of:

- **Toolchain install timing out** — sometimes the Swift Windows installer is slow.
  Usually fixes itself on retry; not a real problem.
- **Path separator issues in `Package.swift`** — unlikely with a fresh package, but if
  you've hand-written any paths with `/` they may misbehave. SwiftPM mostly handles this,
  but watch for it.
- **Line ending issues** — if your repo doesn't have a `.gitattributes` enforcing LF for
  `.swift` files, Windows may check out CRLF and confuse the toolchain. Worth adding:

  ```ini
  # .gitattributes
  * text=auto eol=lf
  *.swift text eol=lf
  ini
  ```

None of these are blocking; they're just the usual "first time on Windows CI" papercuts.
If something else weird shows up, paste me the error and we'll work through it.

### Explicitly NOT in Phase 0

- ❌ No Ghostty / libghostty-vt integration
- ❌ No snapshot test harness
- ❌ No termios code
- ❌ No ANSI encoder
- ❌ No buffer type
- ❌ No view protocol
- ❌ Nothing that touches a terminal

---

## Phase 1: The Walking Skeleton

Phase 1 is the **walking skeleton**: the smallest end-to-end slice that proves the
architecture works. You should be able to run a tiny program, see a character on screen,
press `a` key, see it acknowledged, press `q`, and exit cleanly with your terminal
restored.

The goal is _not_ a usable library. The goal is to have touched every layer of the stack
at least once, in its crudest possible form, so you understand what each layer is for
before you build it properly in Phase 2.

Concretely, when Phase 1 is done you can:

1. Run `swift run HelloTessera` in your example app.
2. See "Hello, Tessera. Press q to quit." rendered in the alt screen.
3. Press any key and see "You pressed: X" update.
4. Press `q` and exit — your shell prompt comes back, your terminal is sane, scrollback is
   intact.
5. If you `kill -9` the process mid-run, your terminal is _not_ sane (we don't fix that
   until Phase 2 with proper signal handling). That's fine for now.

This is deliberately the _minimum viable version_ of each layer. The discipline is: build
the crudest thing that works, prove it works, then in Phase 2 replace each piece with the
real implementation.

### PlatformIO — minimum viable

> [!note] Ratatui References
>
> - Ratatui separates terminal I/O into a `Backend` trait (`ratatui-core/src/backend.rs`,
>   line 158) and concrete backend implementations.
> - The crossterm backend (`ratatui-crossterm/src/lib.rs`, line 123) wraps a `Write` and
>   delegates to crossterm for raw mode, alt screen, cursor, and size.
> - The `init` module (`ratatui/src/init.rs`, lines 396–404 for `try_init`, lines 554–559
>   for `try_restore`) shows the setup/teardown order: `enable_raw_mode` →
>   `EnterAlternateScreen` → backend → `Terminal`. Restore reverses: `disable_raw_mode` →
>   `LeaveAlternateScreen`.
> - The `Backend::size()` trait method (`ratatui-core/src/backend.rs`, line 315) maps to
>   `terminal::size()` in crossterm (line 337) or `termion::terminal_size()` in termion
>   (`ratatui-termion/src/lib.rs`, line 259), both ultimately `TIOCGWINSZ`. Input events
>   in examples use `crossterm::event::read()` — in Phase 1 we bypass that library and
>   read raw bytes from stdin directly.

- **POSIX only.** No Windows yet. (`#if os(macOS) || os(Linux)`.)
- Raw mode via `termios`: save current, set `ICANON`/`ECHO` off, apply. Restore on exit.
- Alt screen enter/exit via hardcoded byte strings (`\x1b[?1049h` / `\x1b[?1049l`). The
  ANSI encoder isn't built yet, so we cheat.
- Stdin reads: blocking read of single bytes in a `Task`. No `AsyncStream` plumbing yet,
  just enough to get bytes flowing.
- Stdout writes: direct `write(2)` calls, no buffering.
- Terminal size: one `TIOCGWINSZ` call at startup. No resize handling yet — if the user
  resizes mid-run, things look broken until restart.
- **No signal handling.** This is the deliberate scary part. If the user Ctrl-C's, their
  terminal stays in raw mode. We accept this in Phase 1 and fix it in Phase 2.

### ControlSequence — skip entirely

In Phase 1, you have maybe 4-5 ANSI sequences to emit, all hardcoded:

- `\x1b[?1049h` — enter alt screen
- `\x1b[?1049l` — exit alt screen
- `\x1b[2J` — clear screen
- `\x1b[H` — move cursor home
- `\x1b[{row};{col}H` — move cursor (one `String(format:)` call)

Resist the urge to start building the encoder enum yet. You don't know enough about what
shape it wants. Phase 2 builds it for real, informed by the bytes you actually emitted in
Phase 1.

### Buffer — real, but minimal

> [!note] Ratatui References
>
> - `Buffer` is a flat `Vec<Cell>` backed by a `Rect` area
>   (`ratatui-core/src/buffer/buffer.rs`, line 48). `Index`/`IndexMut` impls (lines
>   279–296) provide subscript-style access via `Position`. `set_string` (line 220)
>   iterates graphemes with width clamping.
> - `Cell` stores `symbol: Option<CompactString>` to support grapheme clusters, plus `fg`,
>   `bg`, and `modifier` fields (`ratatui-core/src/buffer/cell.rs`, line 44).
>   `Cell::EMPTY` is the blank default (line 74). `PartialEq` treats `None` and
>   `Some(" ")` as equal (line 196).
> - `CellWidth` trait on `str` and `Cell` (`ratatui-core/src/buffer/cell_width.rs`,
>   line 16) uses the `unicode_width` crate. For Phase 1, naive `width = 1` is sufficient.
> - `Size` is a simple `width: u16`, `height: u16` struct with `area()` method
>   (`ratatui-core/src/layout/size.rs`, line 42).
> - `Position` is `x: u16`, `y: u16` — maps to the spec's `Point` type
>   (`ratatui-core/src/layout/position.rs`, line 46).
> - `Style` is a full struct with `fg: Option<Color>`, `bg: Option<Color>`,
>   `add_modifier`, `sub_modifier` (`ratatui-core/src/style.rs`, line 157). For Phase 1
>   the spec calls for an empty struct — just the type shell.

This one I think you should build _properly_ in Phase 1, because the buffer is the central
abstraction everything else hangs off, and a half-built buffer will warp every layer above
it.

Minimum viable but real:

```swift
public struct Buffer: Sendable, Equatable {
    public struct Size: Sendable, Equatable {
        public let cols, rows: Int
    }
    public let size: Size
    private var cells: [Cell]

    public init(size: Size, fill: Cell = .blank)
    public subscript(row: Int, col: Int) -> Cell { get set }
    public mutating func write(_ string: String, at: Point, style: Style)
}

public struct Cell: Sendable, Equatable {
    public var character: Character
    public var style: Style
    public var width: Int  // 1 for now; CJK/emoji is Phase 2
}

public struct Style: Sendable, Equatable {
    // Empty for Phase 1; just the type exists.
}
```

Width handling can be naive (assume 1 column per character — broken for CJK, fine for
"Press q to quit"). Style can be an empty struct. But the _shape_ of the type — value
semantics, `subscript`, `write(at:)` — should be right.

### Renderer — naive, no diff

> [!note] Ratatui References
>
> - `Terminal::try_draw` (`ratatui-core/src/terminal/render.rs`, line 118) is the full
>   render pipeline: autoresize → render callback → flush → cursor → swap buffers →
>   backend flush. Phase 1 skips all of this and writes bytes directly.
> - `Terminal::flush` (`ratatui-core/src/terminal/buffers.rs`, line 96) computes the diff
>   between previous and current buffer via `Buffer::diff_iter`, then passes changed cells
>   to `Backend::draw`. Phase 1 does no diffing — it repaints every cell.
> - `BufferDiff` iterator (`ratatui-core/src/buffer/diff.rs`, line 10) yields
>   `(x, y, &Cell)` for changed cells. Phase 2 replaces the naive renderer with this
>   diff-based approach.
> - `CrosstermBackend::draw` (`ratatui-crossterm/src/lib.rs`, line 213) iterates
>   `(x, y, &Cell)` tuples, queues `MoveTo(x, y)` + style attrs + `Print(symbol)` for
>   each. Shows the pattern of cursor movement + character output that Phase 1 mimics with
>   raw `\x1b[H` and CR/LF.

The Phase 1 renderer is dead simple:

```swift
func render(_ buffer: Buffer, to io: PlatformIO) async {
    var bytes: [UInt8] = []
    bytes.append(contentsOf: "\x1b[H".utf8)  // home
    for row in 0..<buffer.size.rows {
        for col in 0..<buffer.size.cols {
            bytes.append(contentsOf: String(buffer[row, col].character).utf8)
        }
        if row < buffer.size.rows - 1 {
            bytes.append(0x0d)  // CR
            bytes.append(0x0a)  // LF
        }
    }
    await io.write(bytes)
}
```

Full repaint every frame. No diffing. No damage tracking. No synchronized output. It'll
flicker. That's _fine_ — Phase 2 fixes it. The point of Phase 1's renderer is to prove
that "buffer in, bytes out" works end-to-end.

### InputParser — only `q` and one other key

> [!note] Ratatui References
>
> - Ratatui has no input layer of its own — it delegates entirely to crossterm's `event`
>   module. The demo app (`examples/apps/demo/src/crossterm.rs`, line 45) shows the
>   canonical event loop: `event::poll(timeout)` → `event::read()` → match on `KeyCode`.
>   Phase 1 replaces all of this with raw byte reads from stdin.
> - `crossterm::event::Event` and `KeyCode::Char` are the types used in the demo. Phase
>   1's `Phase1Event` is a minimal analog — just `.quit` and `.char(Character)`.
> - Raw mode via `enable_raw_mode()` (`ratatui/src/init.rs`, line 396) puts stdin into
>   character-at-a-time mode so `read()` returns immediately. Phase 1 does this manually
>   with `termios` (see the Mode section), which is what makes single-byte reads possible.

You need exactly two things working:

1. Detect a `q` byte (0x71) and signal "quit."
2. Detect any other printable byte and signal "user pressed X."

Don't build a state machine yet. Don't handle escape sequences. Don't think about
modifiers. If the user presses an arrow key in Phase 1, they get garbage on screen (the
raw `\x1b[A` bytes). That's _fine_. Phase 2 builds the real parser.

```swift
// Phase 1 "parser":
enum Phase1Event {
    case quit
    case char(Character)
}

func parsePhase1(_ byte: UInt8) -> Phase1Event? {
    if byte == 0x71 { return .quit }
    if let scalar = Unicode.Scalar(byte), scalar.isASCII {
        return .char(Character(scalar))
    }
    return nil  // ignore everything else
}
```

### Mode lifecycle — none

No `ModeLifecycle` type yet. Mode management is "main function turns alt screen on at
startup and off at exit, hopes nothing goes wrong." Phase 2 builds the real lifecycle
manager with proper teardown discipline.

### View layer — one `Text` view, no protocol yet

You don't even need the `View` protocol in Phase 1. The example app can just write
directly into the buffer:

```swift
// HelloTessera/main.swift
var buffer = Buffer(size: terminalSize)
buffer.write("Hello, Tessera. Press q to quit.", at: Point(0, 0), style: Style())
buffer.write("You pressed: \(lastKey)", at: Point(0, 1), style: Style())
await renderer.render(buffer)
```

This feels wrong — "but we're building a _view_ library!" — but it's deliberate. In Phase
1 you don't yet know what the right `View` protocol shape is. Phase 3 builds it informed
by what you learned writing to the buffer directly. Resisting premature abstraction here
is important.

### The run loop — a single `while`

```swift
let io = try PlatformIO()
try await io.enterRawMode()
try await io.enterAltScreen()
defer { Task { try? await io.exitAltScreen(); try? await io.exitRawMode() } }

var lastKey: Character = " "
var buffer = Buffer(size: try await io.size)

renderLoop: while true {
    buffer.clear()
    buffer.write("Hello, Tessera. Press q to quit.", at: Point(0, 0), style: Style())
    buffer.write("You pressed: \(lastKey)", at: Point(0, 1), style: Style())
    await renderer.render(buffer, to: io)

    for await byte in io.bytes {
        switch parsePhase1(byte) {
        case .quit: break renderLoop
        case .char(let c): lastKey = c; continue renderLoop
        case nil: continue
        }
    }
}
```

Crude, single-threaded-feeling, no concurrency story yet. That's intentional. Phase 2
introduces the real actor-based runtime.

### Definition of done for Phase 1

When all of these are true:

1. `swift run HelloTessera` runs and shows the greeting in the alt screen on macOS and
   Linux.
2. Typing letters updates the "You pressed" line.
3. Pressing `q` exits cleanly; terminal is restored, scrollback intact.
4. The `Buffer` type has tests covering: init, subscript get/set, write at position, write
   past end (clips).
5. The naive renderer has tests covering: empty buffer produces N newlines worth of
   spaces, buffer with text produces expected bytes (golden fixture).
6. Total LOC across `Sources/` is somewhere around 300-500. If it's much more, you've
   over-built.

### What you'll learn in Phase 1 (the real point)

Phase 1's deliverable isn't the code — it's the _understanding_. By the time you're done
you'll have first-hand answers to:

- What does `termios` actually feel like to set up and tear down?
- How quickly does naive full-repaint flicker, and at what terminal sizes does it become
  unbearable?
- What's the latency between a keystroke and a visible change? Does it feel responsive?
- What goes wrong when you forget to restore raw mode? (You _will_ forget at least once
  during development. This is educational.)
- How do you actually feed bytes from `read(2)` into an async Swift program?

These are the questions Phase 2 needs answers to. Phase 1 is the field research that makes
Phase 2's design decisions concrete instead of theoretical.

### Three things to flag

1. **The "no `View` protocol yet" decision.** Some people will hate this — it feels
   backwards to build a view library by _not_ building the view abstraction. I think it's
   correct, but I want to check that you're comfortable with deferring it. The alternative
   is a hand-wavy `View` protocol in Phase 1 that you immediately throw away in Phase 3.

2. **The "no signal handling, terminal can be left broken" decision.** This is the
   spiciest call. The original spec was emphatic that this is _non-negotiable_. I'm
   proposing to violate it in Phase 1 to keep the phase small. Defensible argument: "Phase
   1 is a learning exercise, not a release; we add signal handling immediately in Phase 2
   before anything ships." Counterargument: "Get it right from the start so you build the
   muscle memory." Your call — I lean toward deferring, but it's defensible either way.

3. **The Phase 1 LOC estimate (300-500).** If you find yourself blowing past this, it's
   almost always because you started building Phase 2 features. Treat the LOC budget as a
   smell detector, not a hard limit.

---

## Phase 2: Real terminal foundation

Snapshot harness, ANSI encoder, damage-tracking renderer, mode lifecycle, signal handling,
real PlatformIO with `AsyncStream`, Windows support, width handling, and the _legacy_
input parser (just escape sequences for arrow keys, function keys, basic stuff — no Kitty,
no mouse, no paste yet).

### Slice 1: The snapshot harness

#### Why this is first

By the end of Phase 1 you have a naive renderer emitting raw bytes you wrote by hand.
You're about to throw that away and replace it with a real damage-tracking renderer that
emits _minimal_ bytes — exactly the situation where regression risk is highest. Unit tests
on the buffer don't catch encoder bugs. Unit tests on the encoder catch
individual-sequence bugs but not "the renderer emitted a sequence of correct sequences
that interact badly." Snapshot tests catch all of these by feeding the bytes through a
real VT and asserting on the resulting screen state.

Building the harness first means **every renderer change in Phase 2 lands with a snapshot
test**. That's the discipline the original spec was reaching for, and it's right — it was
just mis-scheduled into Phase 0.

#### What the harness needs to be, concretely

A test-only target called `TesseraSnapshotTests` that exposes a small Swift API:

```swift
public final class VirtualTerminal {
    public init(cols: Int, rows: Int)
    public func feed(_ bytes: [UInt8])
    public func feed(_ string: String)   // convenience

    // Inspection
    public func text(row: Int) -> String
    public func cell(row: Int, col: Int) -> RenderedCell
    public func cursorPosition() -> Point
    public func snapshot() -> ScreenSnapshot  // whole-screen value
}

public struct RenderedCell: Sendable, Equatable {
    public let character: Character
    public let foreground: RenderedColor
    public let background: RenderedColor
    public let bold, italic, underline, reverse: Bool
}

public struct ScreenSnapshot: Sendable, Equatable {
    public let cells: [[RenderedCell]]
    public let cursor: Point
    // Equality + a nice debug description for failing tests
}
```

That's the _whole_ API your tests need. Whatever's behind it can be ugly C interop — tests
don't care, they just want `feed → inspect`.

#### libghostty-vt via C interop

##### One important caveat about libghostty-spm

[GhosttyKit - Swift Package Registry](https://swiftpackageregistry.com/Lakr233/libghostty-spm)
is Apple-platforms only: macOS 13+, iOS 16+, Mac Catalyst 16+ — no Linux, no Windows [^1].
The XCFramework is a pre-built libghostty static library trimmed for embedded Apple use.

This is **fine for Tessera's purposes**, but it requires being deliberate about the
implications:

- **The library itself remains cross-platform.** `TesseraTerminal` and `Tessera` have zero
  dependency on GhosttyKit. They run on macOS, Linux, Windows as planned.
- **`TesseraSnapshotTests` becomes macOS-only.** Conditional on `#if os(macOS)`, gated in
  the GitHub Actions matrix to only run there.
- **CI on Linux/Windows runs `TesseraTerminalTests` and `TesseraTests` only** — unit tests
  of the encoder against golden byte fixtures, buffer/view tests against in-memory
  buffers. These are sufficient to catch most regressions.
- **Cross-platform parity is verified by:** (a) the encoder unit tests being identical
  everywhere, (b) the snapshot tests on macOS proving the _bytes_ (which are
  platform-independent) produce correct terminal state. If macOS snapshot tests pass,
  Linux/Windows will too, because all three platforms emit the same bytes — only the I/O
  layer differs.

#### What you'll use from GhosttyKit

For the snapshot harness you only need the **`GhosttyKit`** product (the raw C API
re-export). You do _not_ need:

- `GhosttyTerminal` — that's the SwiftUI/AppKit display layer; you don't render the
  terminal, you inspect its state.
- `GhosttyTheme` — color schemes; irrelevant for tests.
- `ShellCraftKit` — shell emulation; way out of scope.

So your `Package.swift` dependency is narrow: pull in libghostty-spm, depend on the
`GhosttyKit` product from the `TesseraSnapshotTests` target only. The main library has no
Ghostty dependency at all.

#### Revised "snapshot harness" definition of done

1. `libghostty-spm` added as a package dependency, `GhosttyKit` product wired only into
   `TesseraSnapshotTests` target.
2. `VirtualTerminal` Swift class with the same API as before (`feed`, `text(row:)`,
   `cell(row:col:)`, `cursorPosition()`, `snapshot()`), now backed by libghostty's
   Parser+Terminal API rather than a hand-rolled VT.
3. ~5-10 tests proving the harness itself works: feed known sequences (cursor move, SGR,
   character write), assert the inspected state matches.
4. One integration test: Phase 1 walking skeleton's output bytes → `VirtualTerminal` →
   asserted screen state.
5. CI matrix updated so `TesseraSnapshotTests` runs on macOS only; Linux and Windows CI
   jobs skip it explicitly.

#### Future work: Linux snapshot test coverage

Linux snapshot test coverage requires building libghostty from source. Until then, Linux
CI runs `TesseraTerminalTests` and `TesseraTests` only; cross-platform correctness is
inferred from byte-level encoder unit tests being identical across platforms.

Postponed because it's more work than dropping in a SwiftPM package. **libghostty itself
is "a cross-platform, zero-dependency C and Zig library"** [^1], so the constraint is
purely about how libghostty-spm distributes a pre-built Apple XCFramework, not about
libghostty's portability.

On Linux you'd build from source — CMake 3.19+, Ninja, a C compiler, Zig 0.15.x, and a
handful of X11 dev packages [^3]. There's also an open discussion (#11730, March 2026)
asking for libghostty-vt to be buildable as a static library — currently it's
shared-library only [^2]. That static-build option would make CI integration much cleaner
if/when it lands.

So the practical Linux story is: **possible, but not as simple as adding a SwiftPM
dependency.** You'd need a build step in CI that compiles libghostty from source, then a
Swift system module that links against the resulting `.so`. Tracked-as-an-issue territory,
not blocker territory.

[^1]:
    [Ghostty is a fast, feature-rich, and cross-platform terminal ... - GitHub](https://github.com/ghostty-org/ghostty)
    (44%)

[^2]:
    [Allow building libghostty-vt as a static library #11730 - GitHub](https://github.com/ghostty-org/ghostty/discussions/11730)
    (32%)

[^3]:
    [ghostty-org/ghostling: A minimum viable terminal emulator built on top...](https://github.com/ghostty-org/ghostling)
    (24%)

#### Definition of done for the snapshot harness (slice 1 of Phase 2)

1. `VirtualTerminal` Swift class exists with the API above.
2. Hand-rolled VT supports: cursor positioning (`CUP`, `CUH`), erase (`ED`, `EL`), SGR
   (colors + bold/italic/underline/reverse), character writes, basic CR/LF behavior.
   That's roughly it.
3. ~20 tests covering each supported sequence: feed bytes, assert on resulting
   cells/cursor.
4. One _integration_ test that's the Phase 1 walking skeleton's bytes → `VirtualTerminal`
   → asserted screen. This proves the harness works end-to-end against your real code.
5. An open GitHub issue: "Migrate snapshot harness to libghostty-vt" with a link to
   #11348.

That's it. Resist the urge to make the mini-VT comprehensive. You only need to parse what
your renderer emits.

---

### Slice 2: ANSI Encoder

Slice 2 is where you start building the only piece of the codebase that's allowed to know
what an ANSI escape sequence looks like. Get the encoder's _shape_ right and the rest of
`TesseraTerminal` falls into place; get it wrong and you'll be plumbing escape codes
through five layers forever.

#### What the encoder is, in one sentence

> [!note] Ratatui References
>
> - The `Backend` trait (`ratatui-core/src/backend.rs`, line 157) defines the contract for
>   drawing, cursor movement, and clearing — the encoder is what fulfills this contract by
>   producing the bytes that each backend method emits.
> - `CrosstermBackend` (`ratatui-crossterm/src/lib.rs`, line 160) wraps a `Write` and
>   delegates to crossterm's `queue!`/`execute!` macros (line 85) to emit sequences. The
>   Tessera encoder replaces this delegation: instead of calling into crossterm, we
>   produce the bytes ourselves.
> - The `Backend::draw` method (`ratatui-crossterm/src/lib.rs`, line 232) iterates cells
>   and emits `MoveTo`, `SetColors`, and `Print` — exactly the kind of "semantic operation
>   → bytes" mapping the encoder encapsulates.

A pure, synchronous, zero-I/O module that turns semantic terminal operations
(`moveCursor(row:5, col:10)`, `setForeground(.red)`, `enterAltScreen`) into the exact
bytes that produce them. **It does not write anywhere. It does not allocate file handles.
It does not know what a `PlatformIO` is.** Bytes in, bytes out — that's the whole
interface to the rest of the system.

This isolation is what makes the encoder testable against golden fixtures and what lets
the snapshot harness exist: every byte your program emits flows through this module, so
testing this module covers everything downstream.

#### The shape question: enum vs. free functions vs. builder

> [!note] Ratatui References
>
> - Ratatui delegates to crossterm's `Command` trait (`crossterm` crate) which is an
>   enum-like set of types (`MoveTo`, `Hide`, `Show`, `SetColors`, `Clear`, `Print`) that
>   implement a common `queue`/`execute` interface. This is the closest analogue to Option
>   A (enum with associated values).
> - The `CrosstermBackend::draw` method (`ratatui-crossterm/src/lib.rs`, lines 232–292)
>   builds a sequence of commands per cell — `MoveTo`, modifier diffs, color changes,
>   `Print` — and queues them into a single buffer. This is exactly the "compose sequences
>   as data" pattern Option A enables.
> - `ModifierDiff` (`ratatui-crossterm/src/lib.rs`, line 535) computes the minimal set of
>   attribute changes between two `Modifier` states and queues only the deltas. The
>   Tessera renderer (slice 4) will need equivalent diffing logic, which is natural when
>   sequences are data (Option A) rather than side effects.

There are three reasonable Swift idioms here, and the choice matters because every other
layer of the stack will be calling into this one.

**Option A: enum with associated values + a single `encode` function.**

```swift
public enum ControlSequence: Sendable, Equatable {
    case cursorPosition(row: Int, col: Int)
    case cursorVisible(Bool)
    case eraseInDisplay(EraseMode)
    case setForeground(Color)
    case enterAltScreen
    // ... ~30 cases total for Phase 2
}

public func encode(_ sequence: ControlSequence, into buffer: inout [UInt8])
```

**Option B: free functions returning bytes.**

```swift
public enum ControlSequence {
    public static func cursorPosition(row: Int, col: Int, into: inout [UInt8])
    public static func enterAltScreen(into: inout [UInt8])
    // ...
}
```

**Option C: a builder/writer type.**

```swift
public struct SequenceWriter {
    public mutating func cursorPosition(row: Int, col: Int)
    public mutating func enterAltScreen()
    public func finish() -> [UInt8]
}
```

**My recommendation: Option A.** Reasons:

1. **The renderer wants to compose sequences as data, not effects.** A damage-tracking
   renderer in slice 4 will build up a `[ControlSequence]` representing "what changed this
   frame" before emitting bytes. That's natural with an enum, awkward with free functions,
   and a category error with a builder.
2. **Equatable enum cases make tests legible.**
   `#expect(sequences == [.cursorPosition(row: 0, col: 0), .setForeground(.red), .text("hi")])`
   reads beautifully. Comparing byte arrays in tests is much worse.
3. **Exhaustive `switch` in the encoder.** When you add a new sequence in Phase 3 (Kitty
   keyboard, say), the compiler tells you exactly where to handle it. Free functions
   silently let you forget.
4. **It mirrors how every mature terminal library models this** — Ratatui's `Command`,
   crossterm's `Command`, vty libraries' opcodes. It's the load-bearing abstraction in
   this domain.

The one downside is allocation: building `[ControlSequence]` per frame is more allocation
than streaming directly to a byte buffer. Premature concern. If profiling later shows it
matters, you can add a streaming fast-path alongside without breaking the enum API.

#### The encoding interface

> [!note] Ratatui References
>
> - The `Backend::draw` signature (`ratatui-core/src/backend.rs`, line 183) takes an
>   iterator of `(u16, u16, &Cell)` — the crossterm backend consumes this and queues
>   commands into the writer's internal buffer via `queue!`
>   (`ratatui-crossterm/src/lib.rs`, line 85). The `encode(into: inout [UInt8])` pattern
>   mirrors this: accumulate into a shared buffer rather than return new allocations per
>   call.
> - `crossterm::queue!` vs `crossterm::execute!` (`ratatui-crossterm/src/lib.rs`, line
>   85): `queue!` buffers without flushing (used in `draw`), `execute!` flushes
>   immediately (used in `hide_cursor`, `clear`). The Tessera encoder's `inout [UInt8]` is
>   the queue! side — flush is the caller's responsibility.

```swift
public enum ControlSequence: Sendable, Equatable {
    // ... cases ...
}

extension ControlSequence {
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

The `inout [UInt8]` is load-bearing — the renderer will build one big byte buffer per
frame and `encode(into:)` many sequences into it. Returning fresh `[UInt8]` per call would
mean N small allocations per frame. This shape costs nothing and scales.

#### The Phase 2 sequence catalog

> [!note] Ratatui References
>
> - Cursor control maps to `Backend::set_cursor_position` (`ratatui-core/src/backend.rs`,
>   line 229) and `hide_cursor`/`show_cursor` (lines 188, 202). The crossterm backend uses
>   `MoveTo(x, y)` (`ratatui-crossterm/src/lib.rs`, line 245), `Hide` (line 295), and
>   `Show` (line 299) — all crossterm `Command` impls that emit CSI sequences.
> - Erase maps to `Backend::clear` (`ratatui-core/src/backend.rs`, line 259) and
>   `clear_region` with `ClearType` (`ratatui-core/src/backend.rs`, line 121). The
>   crossterm backend uses `Clear` from crossterm (`ratatui-crossterm/src/lib.rs`, lines
>   313–322).
> - SGR styling maps to the `Color` enum (`ratatui-core/src/style/color.rs`, line 69) and
>   `Modifier` bitflags (`ratatui-core/src/style.rs`, line 104). The crossterm backend
>   emits `SetColors` (line 259), `SetForegroundColor`/`SetBackgroundColor` (lines
>   280–289), and `SetAttribute` via `ModifierDiff` (line 535).
> - Alt screen is handled by crossterm's `EnterAlternateScreen`/`LeaveAlternateScreen`
>   (`ratatui-crossterm/src/lib.rs`, lines 127, 145) — the backend itself doesn't expose
>   these as `Backend` trait methods; they're applied at the application level.
> - `Print` (`ratatui-crossterm/src/lib.rs`, line 274) is crossterm's command for literal
>   text output — the analogue of `text(String)` as a `ControlSequence` case.

Concrete list of cases the encoder needs for Phase 2 (informed by the layer-by-layer Phase
1 work; nothing speculative):

**Cursor control**

- `cursorPosition(row: Int, col: Int)` — CSI `row;colH` (1-indexed in the wire format;
  convert from 0-indexed at the boundary)
- `cursorUp(Int)`, `cursorDown(Int)`, `cursorForward(Int)`, `cursorBack(Int)`
- `cursorVisible(Bool)` — DEC private modes 25
- `cursorSave`, `cursorRestore` — DECSC/DECRC

**Erase**

- `eraseInDisplay(EraseMode)` where `EraseMode` is
  `.toEnd | .toBeginning | .all | .allAndScrollback`
- `eraseInLine(EraseMode)` (same enum, sans scrollback)

**SGR (styling)**

- `resetAttributes` — SGR 0 (worth a dedicated case; emitted constantly)
- `setForeground(Color)`, `setBackground(Color)` — 16-color, 256-color, and truecolor
  variants behind a single `Color` enum
- `setBold(Bool)`, `setItalic(Bool)`, `setUnderline(Bool)`, `setReverse(Bool)`,
  `setDim(Bool)`, `setStrikethrough(Bool)`

**Modes**

- `enterAltScreen`, `exitAltScreen` — DEC private mode 1049
- `enterSynchronizedOutput`, `exitSynchronizedOutput` — DEC private mode 2026 (critical
  for flicker-free updates; we'll lean on this hard in the renderer)
- `enableLineWrap(Bool)` — DECAWM

**Misc**

- `setWindowTitle(String)` — OSC 0/2
- `text(String)` — literal text (just appends UTF-8 bytes; included as a case so a
  `[ControlSequence]` can fully represent a frame's output)
- `bell` — 0x07, occasionally useful

That's roughly 25-30 cases. Resist adding more "just in case." Phase 3 will add bracketed
paste, focus, mouse, Kitty, OSC 8 as their own cases — that's the right time.

#### The `Color` type

> [!note] Ratatui References
>
> - Ratatui's `Color` enum (`ratatui-core/src/style/color.rs`, line 69) has cases:
>   `Reset`, 16 named ANSI colors (`Black` through `White`, lines 75–112),
>   `Rgb(u8, u8, u8)` (line 118), and `Indexed(u8)` (line 124). This closely matches the
>   spec's four-case design (`default` → `Reset`, `ansi` → named cases, `rgb`, `indexed`).
> - The `IntoCrossterm<CrosstermColor>` impl (`ratatui-crossterm/src/lib.rs`, line 408)
>   shows the encoding mapping: `Reset` → `CrosstermColor::Reset`, named colors →
>   crossterm's `DarkRed`/`Red` etc., `Indexed(i)` → `AnsiValue(i)`, `Rgb(r,g,b)` →
>   `Rgb { r, g, b }`.
> - The `anstyle` conversion module (`ratatui-core/src/style/anstyle.rs`, line 1) provides
>   bidirectional conversion between Ratatui's `Color` and `anstyle`'s
>   `AnsiColor`/`Ansi256Color`/ `RgbColor`, confirming the three color spaces (16-color,
>   256-color, truecolor) are a standard split.

This is the one place where modeling decisions get fiddly. ANSI has three color spaces and
they're not unified:

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
```

A few decisions baked in here worth flagging:

- **`default` is a first-class case**, not "fall back to ANSI 0". Resetting to default fg
  is a different SGR code than setting black, and confusing the two creates subtle
  rendering bugs.
- **`ansi` and `indexed(0..<16)` are kept distinct** even though they overlap.
  `ansi(.red)` emits SGR 31; `indexed(1)` emits SGR 38;5;1. Terminals may render these
  slightly differently (ANSI 16 typically respects user palette; indexed always uses the
  256-color cube), and being explicit matters.
- **No 256-color named constants.** If a user wants `indexed(208)`, they pass 208. Naming
  256 colors is a job for a _theme_ library, not the encoder.
- **No down-conversion.** If the user asks for `rgb(...)` on a terminal that doesn't
  support truecolor, the encoder still emits the truecolor sequence — and that's correct.
  Terminal capability detection is a separate concern (Phase 5+), and even then, the
  encoder shouldn't silently lie about what bytes it produced.

#### What the encoder does _not_ do

> [!note] Ratatui References
>
> - The crossterm backend's `draw` method (`ratatui-crossterm/src/lib.rs`, lines 232–292)
>   tracks state across the loop (`fg`, `bg`, `modifier`, `last_pos`) to minimize
>   redundant SGR emissions. This is the "buffering of state" that the Tessera encoder
>   deliberately pushes to the renderer layer — the encoder itself is stateless, the
>   renderer decides what to emit.
> - `ModifierDiff` (`ratatui-crossterm/src/lib.rs`, line 535) computes minimal attribute
>   deltas between frames. Tessera's renderer will need equivalent logic, not the encoder.
> - `BufferDiff` (`ratatui-core/src/buffer/diff.rs`, line 10) and `Buffer::diff_iter`
>   (`ratatui-core/src/buffer/buffer.rs`, line 506) compute which cells changed between
>   frames. This is the "no batching" / "no clamping" boundary: the diff layer decides
>   what changed, the encoder just produces bytes for what it's told.
> - `TestBackend` (`ratatui-core/src/backend/test.rs`, line 32) is Ratatui's in-memory
>   backend for golden-byte-style testing — it records what was drawn and lets you assert
>   on the resulting `Buffer`. The Tessera `VirtualTerminal` (libghostty) plays a similar
>   role but at a lower level (byte → terminal state, not cell → buffer).

This list matters as much as the catalog:

- **No buffering of state.** The encoder doesn't remember "the current foreground is red,
  don't re-emit the SGR." That's the renderer's job (and the renderer will need to do it
  carefully to minimize bytes). The encoder is stateless.
- **No batching.** `encode(into:)` produces exactly the bytes for the one sequence it's
  called with. Sequencing is the caller's problem.
- **No clamping.** If you ask for `cursorPosition(row: -5, col: 9999)` the encoder emits
  exactly those bytes. Validation belongs at a higher layer if it belongs anywhere.
- **No querying.** Sequences that request a response from the terminal (DA1, cursor
  position report) are not Phase 2. They need a response-parsing infrastructure that's
  better designed later.
- **No assumptions about the I/O sink.** The encoder writes bytes into a `[UInt8]`;
  whether those bytes go to stdout, a pipe, a `VirtualTerminal` in tests, or `/dev/null`
  is not its concern.

#### Testing strategy for the encoder

> [!note] Ratatui References
>
> - `TestBackend` (`ratatui-core/src/backend/test.rs`, line 32) provides an in-memory
>   implementation of `Backend` that records all draw operations into a `Buffer`.
>   Ratatui's widget tests use it for golden-buffer assertions: draw a widget, compare the
>   resulting buffer to expected output. This is the "golden byte fixture" pattern at the
>   cell level.
> - The buffer diff tests (`ratatui-core/src/buffer/buffer.rs`, lines 1094–1121) test
>   `diff_iter` against known inputs — `diff_empty_empty`, `diff_empty_filled`, etc. This
>   is the structural analogue of Tessera's golden-byte tests: known input → known output,
>   no terminal involved.
> - Ratatui does not have a byte-level encoder test suite because encoding is delegated to
>   crossterm. Tessera's encoder _is_ the encoding layer, so the golden-byte +
>   VirtualTerminal round-trip strategy fills the gap that Ratatui's delegation model
>   sidesteps.

This is the part that pays the harness back. For every `ControlSequence` case, two tests:

1. **Golden byte fixture.**
   `#expect(ControlSequence.cursorPosition(row: 0, col: 0).bytes == [0x1b, 0x5b, 0x31, 0x3b, 0x31, 0x48])`
   — i.e., `\e[1;1H`. Tedious to write the first time; immortal regression coverage
   forever.
2. **Round-trip through `VirtualTerminal`.** Feed the bytes to libghostty, assert the
   terminal state changed as expected. This catches "I emitted bytes that _look_ right but
   the actual escape sequence does something else."

Together these cover both "the bytes are what I think they are" and "the bytes do what I
think they do." Either alone is insufficient.

I'd also write **one negative test per ambiguous case** — e.g., assert that
`setForeground(.default)` emits SGR 39, not SGR 30. The cases where you might guess wrong
are exactly the cases worth pinning down.

#### Definition of done for slice 2

1. `ControlSequence` enum with the ~25-30 cases listed above.
2. `Color` and `ANSIColor` types.
3. `encode(into:)` implementation for every case.
4. ~60 tests: one golden-byte test per case (~30) plus one `VirtualTerminal` round-trip
   per case (~30).
5. Documentation comments on every case linking to the relevant VT100/xterm/DEC reference.
   (The encoder is the project's institutional memory for "why is this byte 0x1b and not
   0x9b" — it deserves comments.)
6. The Phase 1 walking skeleton is rewritten to use `ControlSequence` instead of hardcoded
   byte strings. This is a small refactor and proves the encoder is usable from the
   renderer's perspective.

Roughly another couple of evenings of work. Most of it is mechanical; the design decisions
are all up front, which is why we're spending so much time on them now.

#### Three things to flag

> [!note] Ratatui References
>
> - Ratatui does not currently emit synchronized output (DEC 2026) sequences. The
>   `CrosstermBackend::draw` method (`ratatui-crossterm/src/lib.rs`, line 232) queues
>   commands directly without wrapping in `DEC private mode 2026`. This is a known gap —
>   crossterm itself has `EnableLineWrap`/`DisableLineWrap` but no sync output command in
>   the versions Ratatui supports.

1. **Synchronized Output (DEC 2026) is in the Phase 2 catalog.** This is a relatively new
   mode — not all terminals support it, but the ones that do (Ghostty, iTerm2, Kitty,
   modern Alacritty, WezTerm) make a huge difference for flicker. Terminals that don't
   support it just ignore the sequence, so emitting it is always safe. The damage-tracking
   renderer in slice 4 will wrap every frame in
   `enterSynchronizedOutput`/`exitSynchronizedOutput`. Worth knowing now so the encoder
   API supports it.

2. **`text(String)` as a case feels weird but is correct.** It lets a `[ControlSequence]`
   be a complete representation of a frame's output (styling + cursor moves + actual text
   content interleaved). The alternative — text is "outside" the encoder — fragments the
   model and makes the renderer ugly. Worth pushing back on if it bothers you, but I think
   it's the right call.

3. **The `Color` type is going to be load-bearing across the whole stack** — `Style` will
   hold one, themes will produce them, view APIs will accept them. The shape we pin down
   here is hard to change later. The four-case design above (`default`, `ansi`, `indexed`,
   `rgb`) is what every serious terminal library converges on, but worth confirming you're
   happy with it before we move on.

---

### Slice 3: mode lifecycle + real PlatformIO + signal handling

This slice is where Tessera grows up. Phase 1's "main function turns alt screen on, hopes
nothing goes wrong" gets replaced with a real lifecycle manager that **guarantees** the
terminal is restored no matter how the program exits — clean exit, thrown error, `Ctrl-C`,
`SIGTERM`, `SIGHUP` from a disconnected ssh session, panic, anything. The promise is: _if
Tessera ever touches the terminal, Tessera puts it back._

This is the load-bearing reliability commitment of the whole library. Get this wrong and
every user has to know how to type `reset` in a broken terminal. Get it right and Tessera
disappears.

#### The three problems this slice solves

1. **Mode lifecycle.** Raw mode and alt screen aren't booleans you flip; they're nested
   state with strict ordering. Enter raw mode _then_ alt screen; exit alt screen _then_
   raw mode. Doing it in the wrong order leaves the terminal subtly broken. We need a type
   that enforces this.

2. **Async I/O.** Phase 1's "blocking `read(2)` in a `Task`" is fine for a walking
   skeleton but doesn't compose with the rest of an async program. We need `bytes` as an
   `AsyncSequence<UInt8>` and `write(_:)` as an async function — both backed by
   non-blocking I/O with proper cancellation.

3. **Catastrophic-exit recovery.** Swift's `defer` runs on normal scope exit and thrown
   errors. It does _not_ run on signal-induced termination. `SIGINT`, `SIGTERM`, `SIGHUP`,
   `SIGQUIT` will kill the process with the terminal still in raw mode unless we install
   handlers.

Each problem has a tidy solution; the work is in getting them to compose.

#### The `ModeLifecycle` type

> [!note] Ratatui References
>
> - Ratatui's `init` module (`ratatui/src/init.rs`) provides `try_init` (line 397) and
>   `try_restore` (line 554) which encode the enter/exit ordering: `enable_raw_mode` →
>   `EnterAlternateScreen` on enter, `disable_raw_mode` → `LeaveAlternateScreen` on exit.
> - The `run` function (`ratatui/src/init.rs`, line 318) wraps a closure with setup and
>   guaranteed cleanup — the closest Rust analogue to Tessera's `enter`/`exit` contract.
> - Unlike Tessera's all-or-nothing set semantics, Ratatui's `try_init` enables modes
>   sequentially without rollback; a failure midway leaves the terminal partially
>   modified. Tessera's `ModeLifecycle.enter` improves on this by rolling back on partial
>   failure.

This is the user-facing entry point. The shape:

```swift
public actor ModeLifecycle {
    public enum Mode: Sendable {
        case rawMode
        case altScreen
        case mouseTracking(MouseMode)       // Phase 3
        case bracketedPaste                 // Phase 3
        case focusEvents                    // Phase 3
        case kittyKeyboard(KittyFlags)      // Phase 3
    }

    public init(io: PlatformIO)

    public func enter(_ modes: Set<Mode>) async throws
    public func exit() async throws

    public var activeModes: Set<Mode> { get async }
}
```

A few load-bearing properties of this design:

- **Modes are entered as a set, all-or-nothing.** Either every requested mode is active or
  none are. If entering alt screen succeeds but enabling mouse tracking fails, the
  lifecycle rolls back the alt screen before throwing. This is critical — partial states
  are how terminals end up broken.

- **`enter` is idempotent-ish.** Calling `enter` twice with overlapping mode sets is an
  error, not a no-op. Tessera applications enter modes once at startup; if you find
  yourself wanting to call `enter` mid-run, something is wrong with your design. (The
  exception is Phase 3's `mouseTracking`, which you may legitimately toggle. We'll handle
  that when we get there.)

- **`exit` always works.** Even if state tracking gets confused, `exit` emits the disable
  sequence for every mode it _believes_ might be active _and_ the mode it _requested_ be
  active. Over-cleaning is fine; under-cleaning is what causes broken terminals. We bias
  hard toward over-cleaning.

- **It's an actor, not a struct.** Mode state is shared mutable state by definition (the
  terminal is the state). Wrapping it in an actor gets Swift 6's strict concurrency happy
  and serializes mode transitions, which is exactly the semantics you want.

#### The teardown discipline (the spicy part)

> [!note] Ratatui References
>
> - Ratatui installs a panic hook via `set_panic_hook()` (`ratatui/src/init.rs`, line 566)
>   that calls `restore()` before delegating to the previous hook. This covers panics but
>   not signal-induced termination — Tessera's layered approach (defer + signal handlers +
>   atexit) goes further.
> - The `Terminal` struct implements `Drop` (`ratatui-core/src/terminal.rs`, line 473) to
>   restore cursor visibility on scope exit, analogous to Tessera's `defer` layer.
> - Ratatui's `restore()` (`ratatui/src/init.rs`, line 524) and `try_restore()` (line 554)
>   perform the actual teardown (`disable_raw_mode` → `LeaveAlternateScreen`). Tessera's
>   signal handler must replicate this logic using only signal-safe syscalls.

`defer` is not enough. Here's the layered approach:

**Layer 1: Swift `defer` for normal and thrown exits.**

```swift
let lifecycle = ModeLifecycle(io: io)
try await lifecycle.enter([.rawMode, .altScreen])
defer { Task { try? await lifecycle.exit() } }
```

This catches the 95% case: normal exit, thrown errors, task cancellation. The `Task`
wrapper is needed because `defer` blocks can't be `async` in Swift, but it works — the
task is created synchronously on the way out and runs to completion.

**Layer 2: signal handlers for SIGINT, SIGTERM, SIGHUP, SIGQUIT.**

The handler does the _bare minimum_ to restore the terminal, then re-raises the signal so
the process dies with the right exit status. This means: write the mode-exit byte
sequences directly to stdout using `write(2)`, then `signal(sig, SIG_DFL); raise(sig)`.

Critical constraint: **signal handlers run in a _very_ restricted context.** No Swift
runtime, no `String` allocation, no async, no actor hops. Just `write(2)` of a
pre-computed byte buffer of disable sequences. The bytes are computed at `lifecycle.enter`
time and stored in a global atomic pointer; the handler reads the pointer and writes the
bytes.

This is the only place in Tessera that touches a global. It's unavoidable — POSIX signal
handlers are inherently global. Containing the ugliness to one file is the best you can
do.

**Layer 3: `atexit` as a backstop.**

`atexit` is called on normal process exit _and_ on `exit()` calls but _not_ on signals.
Used as belt-and-braces for the case where the program calls `Foundation.exit()` directly
(bypassing `defer`). Same restricted-context constraints as signal handlers: just write
pre-computed bytes.

**Layer 4: documented escape hatch.**

For users whose programs _do_ die without running our handlers (segfault, `kill -9`, power
outage), Tessera ships a `tessera-reset` shell command that emits the universal "fix my
terminal" byte string. Document this prominently. You can't catch every failure mode; you
can make recovery a one-command operation.

#### The real `PlatformIO`

> [!note] Ratatui References
>
> - The `Backend` trait (`ratatui-core/src/backend.rs`, line 157) defines the contract for
>   terminal I/O: `draw`, `flush`, `size`, `window_size`, cursor ops. Tessera's
>   `PlatformIO` combines this with input — Ratatui splits input into the crossterm event
>   system.
> - `CrosstermBackend` (`ratatui-crossterm/src/lib.rs`, line 160) wraps a `Write` and
>   implements `Backend`. Its `flush` (line 358) delegates to `self.writer.flush()` —
>   analogous to Tessera's explicit `flush()` after buffered writes.
> - `Backend::size()` (`ratatui-core/src/backend.rs`, line 315) and
>   `Backend::window_size()` (line 322) map to `terminal::size()` in crossterm, ultimately
>   `TIOCGWINSZ`. Tessera's `PlatformIO.size()` and `sizeChanges` stream serve the same
>   purpose.
> - `WindowSize` (`ratatui-core/src/backend.rs`, line 139) carries both character
>   dimensions (`columns_rows: Size`) and pixel dimensions (`pixels: Size`). Tessera's
>   `TerminalSize` starts with just columns/rows.
> - Input events in Ratatui use `crossterm::event::poll()` and `event::read()` (see
>   `examples/apps/demo/src/crossterm.rs`, lines 57, 62). Tessera replaces this with a
>   non-blocking `AsyncStream<UInt8>` backed by `poll` + `read(2)`.

Phase 1's `PlatformIO` was a stub. Slice 3 is where it becomes real.

```swift
public actor PlatformIO {
    public init() throws

    // Output
    public func write(_ bytes: [UInt8]) async throws
    public func write(_ bytes: ArraySlice<UInt8>) async throws
    public func flush() async throws

    // Input
    public nonisolated var bytes: AsyncStream<UInt8> { get }

    // Terminal queries
    public func size() async throws -> TerminalSize
    public var sizeChanges: AsyncStream<TerminalSize> { get }

    // Mode primitives (called by ModeLifecycle, not directly by users)
    internal func enableRawMode() async throws
    internal func disableRawMode() async throws
    internal func savedTermios() -> termios?  // for signal handler
}
```

Design notes:

- **Writes are buffered, with explicit `flush`.** Each `write` appends to an internal
  buffer; `flush` issues the actual `write(2)` syscall(s). The renderer in slice 4 will
  compose a whole frame, then flush once — one syscall per frame is the target.
  Per-`encode(into:)` syscalls would be catastrophic for performance.

- **`bytes` is an `AsyncStream`, not an `AsyncSequence` protocol.** Concrete type, single
  owner, no generic gymnastics. Created in `init`, lives for the lifetime of the
  `PlatformIO`. The producer is a detached task doing non-blocking `read(2)` calls with
  `EAGAIN` handling and a self-pipe for cancellation.

- **`sizeChanges` is driven by SIGWINCH.** Same global-atomic + signal-handler trick as
  the teardown: handler sets a flag, a polling task in `PlatformIO` notices, queries the
  new size via `TIOCGWINSZ`, yields to the stream.

- **No Windows yet.** All of the above is POSIX-specific. Slice 3 is POSIX-only; Windows
  is a separate slice later in Phase 2. Conditional compilation guards the
  Windows-incompatible bits; on Windows, `PlatformIO.init()` throws `.unsupportedPlatform`
  for now.

#### The non-blocking read loop

> [!note] Ratatui References
>
> - Ratatui delegates input to crossterm's event system: `crossterm::event::poll(timeout)`
>   followed by `event::read()` (`examples/apps/demo/src/crossterm.rs`, lines 57, 62).
>   Crossterm internally uses `poll`/`epoll`/`kqueue` depending on platform — Tessera
>   re-implements this directly with POSIX `poll` for full control.
> - The crossterm event loop is synchronous and blocking within `poll`'s timeout.
>   Tessera's `AsyncStream<UInt8>` approach is async-native, yielding individual bytes via
>   a `AsyncStreamContinuation` from a detached task.
> - Crossterm's cancellation is implicit (the `poll` timeout bounds the block). Tessera
>   uses an explicit self-pipe trick so cancellation returns immediately without waiting
>   for the timeout.

This is the one place where the implementation details genuinely matter, because getting
it wrong leads to either CPU-spinning or dropped keystrokes. The shape:

```swift
// Inside PlatformIO, a detached Task started in init():
private func inputLoop() async {
    let fd = STDIN_FILENO
    // Set O_NONBLOCK once at startup.

    var buffer = [UInt8](repeating: 0, count: 256)

    while !Task.isCancelled {
        // poll() on stdin + self-pipe-for-cancellation, with timeout
        let readable = await poll(fds: [stdin, cancelPipe], timeoutMs: 100)

        guard readable.contains(stdin) else { continue }

        let n = read(fd, &buffer, buffer.count)
        if n > 0 {
            for i in 0..<n {
                bytesContinuation.yield(buffer[i])
            }
        } else if n == -1 && errno == EAGAIN {
            continue  // shouldn't happen after poll, but defensive
        } else if n == 0 {
            // EOF; finish the stream
            bytesContinuation.finish()
            return
        }
        // Other errors: log and continue, or finish — TBD.
    }
}
```

Three details worth pinning down here:

1. **`poll` over `select`.** `poll` has saner FD-set semantics and is fine on macOS/Linux.
   `epoll`/`kqueue` would be lower-overhead but the difference is irrelevant for one or
   two FDs.
2. **A 100ms `poll` timeout.** Lets the loop check `Task.isCancelled` periodically without
   busy-waiting. 100ms is a totally arbitrary number; it just needs to be small enough
   that cancellation feels responsive and large enough that we're not waking up
   constantly. Tune later if profiling cares.
3. **The self-pipe for cancellation.** Standard POSIX trick: a pipe whose write end is
   touched when we want `poll` to return immediately. Otherwise cancellation has to wait
   for the timeout. Worth implementing properly.

#### The `Cleanup` registration mechanism

> [!note] Ratatui References
>
> - Ratatui's `set_panic_hook()` (`ratatui/src/init.rs`, line 566) captures the cleanup
>   logic in a closure via `std::panic::take_hook` / `set_hook`. Tessera's
>   `CleanupRegistry` uses a global atomic pointer instead, because POSIX signal handlers
>   cannot invoke Swift closures or the Swift runtime.
> - Ratatui's `restore()` (`ratatui/src/init.rs`, line 524) calls `try_restore()`
>   (line 554) which runs `disable_raw_mode()` then `LeaveAlternateScreen`. Tessera's
>   `performEmergencyCleanup` must replicate this with only `tcsetattr` + `write(2)` — no
>   crossterm library calls, no allocation.
> - The `Terminal::drop` impl (`ratatui-core/src/terminal.rs`, line 473) restores cursor
>   visibility as a best-effort cleanup. Tessera has no equivalent in its signal handler;
>   cursor state is restored as part of the broader termios restoration.

To support layer 2 (signal handlers) and layer 3 (`atexit`), `ModeLifecycle` needs to
publish the current "if we die right now, what bytes should we emit" to a global location.
Sketch:

```swift
// Internal to TesseraTerminal.
enum CleanupRegistry {
    static let current = AtomicReference<CleanupState?>(nil)

    struct CleanupState {
        let teardownBytes: [UInt8]    // pre-encoded mode-exit sequences
        let savedTermios: termios     // for tcsetattr restoration
    }

    static func install(_ state: CleanupState)
    static func clear()
    static func performEmergencyCleanup()  // called from signal handler
}
```

`performEmergencyCleanup` is the signal-safe function: it reads the atomic pointer, calls
`tcsetattr` to restore termios, calls `write(2)` with the teardown bytes. No allocation,
no Swift runtime calls, no async. Just syscalls.

This is the single ugliest file in the library. It deserves a long doc comment explaining
what's safe to do in a signal handler context and why.

#### Definition of done for slice 3

1. `ModeLifecycle` actor with `enter`/`exit`/`activeModes` for `rawMode` and `altScreen`.
   (Other modes deferred to Phase 3.)
2. Real `PlatformIO` actor: buffered writes, `AsyncStream<UInt8>` input, `size()` query,
   `sizeChanges` stream.
3. Signal handlers installed for SIGINT, SIGTERM, SIGHUP, SIGQUIT that restore the
   terminal and re-raise.
4. `atexit` backstop installed.
5. `tessera-reset` executable target that emits the universal terminal-reset byte string.
6. The Phase 1 walking skeleton is rewritten to use `ModeLifecycle` and the real
   `PlatformIO`. Manually verifying: `Ctrl-C` mid-run leaves the terminal sane. Sending
   `SIGTERM` from another shell leaves the terminal sane. Closing the terminal tab while
   the program runs leaves... nothing, because the terminal is gone, but the process exits
   cleanly.
7. Tests:
   - Unit test for `ModeLifecycle`'s rollback: inject a `PlatformIO` that fails on the
     second mode-enable, assert that the first mode is rolled back.
   - Unit test for the buffered-write semantics: many writes, one flush, one underlying
     syscall (use a mock `PlatformIO` for this).
   - Snapshot test for `ModeLifecycle.enter([.rawMode, .altScreen])` followed by `exit()`:
     feed the emitted bytes into the `VirtualTerminal`, assert the terminal ends in the
     default state.
   - **No automated test for signal handling.** Spawning a subprocess and signalling it
     from a test is fragile across platforms; this corner gets manual verification.
     Document the manual test procedure in `CONTRIBUTING.md`.

#### What's _not_ in this slice

For clarity, things that look like they belong here but don't:

- **Windows support.** Separate slice. POSIX-only for now.
- **The damage-tracking renderer.** That's slice 4. The renderer uses `PlatformIO.write`
  and `flush`; it doesn't change `PlatformIO` itself.
- **The full input parser.** Slice 5 reads from `bytes` and produces `InputEvent`s. Slice
  3 just delivers raw `UInt8`s.
- **Width handling for CJK/emoji.** That's a buffer concern, slice 4 territory.
- **Mode toggling mid-run.** Slice 3 establishes the lifecycle; Phase 3's modes introduce
  the dynamic-toggle patterns when they're needed.

#### Three things to flag

1. **The "ModeLifecycle is an actor" decision.** It costs you the ability to use
   `defer { lifecycle.exit() }` synchronously — you need the
   `Task { try? await lifecycle.exit() }` dance. The alternative is making it a class with
   a lock, which is uglier. I think the actor wins, but it's worth knowing the ergonomic
   cost is real.

2. **The signal handler approach is genuinely subtle and easy to get wrong.** I'd plan to
   write that one file very carefully, with citations to async-signal-safe function lists
   in the doc comments, and have it reviewed by anyone you trust who knows POSIX well.
   It's the part of Tessera most likely to have a latent bug that bites someone six months
   from now.

3. **`tessera-reset` as a shipped executable is a small detail that punches above its
   weight for user trust.** When (not if) someone's terminal ends up in a weird state
   during early development, "run `tessera-reset`" is a much better story than "type the
   magic incantation `reset` or `stty sane && printf '\e[?1049l\e[?25h'`." It's ~20 lines
   of code and turns a class of bad first impressions into a non-issue.

### Slice 4: Width-aware `Buffer` + damage-tracking renderer

Slice 4 is the conceptual heart of `TesseraTerminal`. Everything before it was plumbing —
bytes in, bytes out, modes managed. Slice 4 is where Tessera starts being _good_ at what
it does. The buffer becomes faithful to the terminal's grid model (wide characters,
combining marks, emoji), and the renderer learns to emit _only what changed_ — turning the
Phase 1 "full repaint, visible flicker" into "smooth, responsive updates indistinguishable
from a native app."

This is also the slice where snapshot tests start paying for themselves daily.
Damage-tracking renderers are notoriously easy to break in subtle ways — an off-by-one in
the diff produces a tearing artifact you'd never catch by reading the code, but a snapshot
test catches instantly.

#### The four problems this slice solves

1. **Width is not 1.** A buffer that assumes one character per column is correct for ASCII
   and lies about everything else. CJK characters are 2 cells wide. Emoji are 2 cells. A
   flag emoji is one grapheme made of two scalars and is 2 cells. The skin-toned thumbs-up
   "👍🏽" is one grapheme made of two scalars joined by a variation selector and is 2 cells.
   Getting this right is the difference between "looks fine in English" and "actually
   usable for real applications."

2. **Full repaint is unacceptable.** Phase 1's renderer flickers because it rewrites every
   cell every frame. A typing app updates one cell per keystroke; emitting bytes for
   200×60 = 12,000 cells per keystroke is comically wasteful and visibly bad. The renderer
   needs to emit the bytes for the ~1 cell that actually changed.

3. **Naive diff is also wasteful.** Even per-cell diffing produces too many bytes if done
   naively: every cell change emits a cursor-move + SGR + character + SGR-reset. For a row
   of consecutive changes that's 4× the bytes it needs to be. The renderer needs to
   _coalesce_ — when adjacent cells change, batch them; when style is the same as the last
   cell emitted, skip the SGR; when the cursor is already where you want it, skip the
   move.

4. **Tearing.** Even with damage tracking, if the terminal redraws mid-update, you see a
   half-rendered frame. Synchronized Output (DEC 2026) solves this — wrap each frame in
   `enter`/`exit` synchronized output, and conformant terminals show the frame atomically.

These four problems compose into a single design: a buffer that tracks width per cell, a
renderer that compares two buffers and emits a minimized byte stream, all wrapped in
synchronized-output discipline.

#### The width-aware `Buffer`

> [!note] Ratatui References
>
> - `Buffer` (`ratatui-core/src/buffer/buffer.rs`, line 67) is a flat `Vec<Cell>` keyed by
>   `row * width + col` over a `Rect` area — the same layout choice Tessera bakes into its
>   design. `set_stringn` (line 336) iterates graphemes via `unicode_segmentation`,
>   advances by each grapheme's `cell_width()`, and resets trailing cells for multi-width
>   graphemes (line 356) — the "continuation cell" pattern Tessera makes explicit with
>   `.continuation`.
> - `Cell` (`ratatui-core/src/buffer/cell.rs`, line 37) stores
>   `symbol: Option<CompactString>` (a grapheme cluster), `fg`, `bg`, `modifier`, and
>   `diff_option`. Ratatui resets trailing cells to `Cell::EMPTY` (blank + Reset style)
>   rather than using a dedicated continuation enum case — Tessera's `.continuation`
>   variant is a stricter invariant that the type system enforces.
> - `CellWidth` trait (`ratatui-core/src/buffer/cell_width.rs`, line 19) computes display
>   width via `unicode-width` with a correction for halfwidth katakana dakuten/handakuten
>   (U+FF9E/U+FF9F) — Ratatui's answer to the "width is not 1" problem. Tessera uses
>   `swift-displaywidth` for the same purpose.
> - `StyledGrapheme` (`ratatui-core/src/text/grapheme.rs`, line 12) pairs a `&str` symbol
>   with a `Style` — Ratatui's intermediate representation between text and buffer,
>   analogous to Tessera's `Cell.Content.grapheme(String)` + `Style`.

Building on Phase 1's `Buffer` skeleton, we add width awareness at the _cell_ level, not
the buffer level.

```swift
public struct Cell: Sendable, Equatable {
    public enum Content: Sendable, Equatable {
        case grapheme(String)       // 1- or 2-cell-wide grapheme cluster
        case continuation           // right half of a wide grapheme
        case blank                  // empty cell, no styling baggage
    }

    public var content: Content
    public var style: Style

    public var width: Int {
        switch content {
        case .grapheme(let g): return g.terminalWidth  // from swift-displaywidth
        case .continuation: return 0                   // not "1" — it's a phantom
        case .blank: return 1
        }
    }
}
```

A few design choices worth pinning down:

- **A wide character occupies two cells, not one.** Cell `[r, c]` holds the grapheme; cell
  `[r, c+1]` holds `.continuation`. This makes width a _property of the grid_, not just of
  the data — which is correct, because the terminal _does_ allocate two display columns
  for it.
- **Continuation cells are first-class.** Reading `[r, c+1]` doesn't error and doesn't
  lie; it tells you "this column is the right half of the grapheme at column c." Renderer
  logic depends on this.
- **`Content.grapheme` holds a `String`, not a `Character`.** Swift's `Character` is a
  grapheme cluster _as defined by Swift's Unicode tables_, which doesn't always match the
  terminal's notion of "one printable unit." Storing the raw grapheme `String` (e.g.,
  `"👨‍👩‍👧"` as a 5-scalar ZWJ sequence) preserves what we got. The encoder writes whatever
  bytes UTF-8 produces.
- **Width is computed, not stored.** Recomputing on access is cheap and avoids "what if
  `style` changes but `width` doesn't update" bugs. `swift-displaywidth` is built for this
  and is one of the spec's load-bearing dependencies.

The buffer mutation API gets one new responsibility: maintaining the cell/continuation
invariant.

```swift
extension Buffer {
    /// Writes a string starting at `point`, advancing by each grapheme's width.
    /// Wide graphemes write both the grapheme cell and the continuation cell.
    /// Writes past the right edge are clipped at the row boundary (no wrap).
    public mutating func write(_ string: String, at point: Point, style: Style)

    /// Writes a single grapheme at `point`, returning the next column.
    /// Returns `nil` if the grapheme doesn't fit.
    public mutating func write(grapheme: String, at point: Point, style: Style) -> Int?
}
```

The "no wrap" behavior is deliberate. The view layer (Phase 4) handles wrapping as a
layout concern; the buffer is a _grid_, and grids don't wrap, they clip. Decoupling the
two means `HStack` and `VStack` can do their work without fighting the buffer.

##### The edge cases that will bite you

> [!note] Ratatui References
>
> - `Buffer::set_stringn` (`ratatui-core/src/buffer/buffer.rs`, line 336) handles clipping
>   at the row boundary by checking `remaining_width` before each grapheme (line 348) —
>   wide graphemes that don't fit are silently dropped. The orphan rule is implicit:
>   trailing cells of a previous wide grapheme are `Cell::EMPTY` (reset by `set_stringn`,
>   line 356), so overwriting half a wide grapheme leaves the other half as blank — which
>   is correct, but not enforced by the type system the way Tessera's `.continuation` is.

These are worth pinning down in the spec because they're where bugs hide:

1. **Writing a wide grapheme at the last column.** No room for the continuation cell. The
   cell stays as it was; the write reports clipping. Don't write half a grapheme.

2. **Overwriting one half of an existing wide grapheme.** If `[r, 5]` is a wide grapheme
   with continuation at `[r, 6]`, and you write a normal character at `[r, 6]`, what
   happens to `[r, 5]`? Answer: `[r, 5]` becomes `.blank`. You can't leave a
   half-grapheme; that's incoherent. This is the "orphan" rule and it applies
   symmetrically: writing to `[r, 5]` orphans `[r, 6]` if it was a continuation.

3. **Combining marks.** "é" can be one scalar (U+00E9) or two ("e" + U+0301). Swift's
   grapheme clustering merges these, so `string.unicodeScalars` may have multiple scalars
   per `Character`. We rely on this — `Content.grapheme` stores the whole cluster as a
   `String`, and the terminal handles rendering. We do _not_ try to apply combining marks
   to a cell that already has content.

4. **Zero-width characters in isolation.** A bare ZWJ or variation selector with no base
   character is technically a grapheme of width 0. Treat as blank; don't put a width-0
   grapheme in a cell. (`swift-displaywidth`'s API will tell you the width; we trust it.)

5. **Control characters.** Anything below 0x20 except possibly tab — the buffer doesn't
   store them. Writes silently drop. Document this clearly: the buffer is for
   _displayable_ content; control sequences are the encoder's job.

#### The damage-tracking renderer

> [!note] Ratatui References
>
> - `Terminal` (`ratatui-core/src/terminal.rs`, line 398) maintains a double-buffered pair
>   of `Buffer`s. `flush()` (`ratatui-core/src/terminal/buffers.rs`, line 97) runs
>   `diff_iter` and passes the resulting iterator to `Backend::draw()`. `swap_buffers()`
>   (line 121) resets the inactive buffer — the same invalidate-and-redraw discipline
>   Tessera's `Renderer.invalidate()` implements.
> - `Backend::draw()` (`ratatui-core/src/backend.rs`, line 166) takes an iterator of
>   `(u16, u16, &'a Cell)` triples — the backend receives exactly the changed cells, not a
>   full buffer. In Ratatui the concrete backend (crossterm, termion) is responsible for
>   cursor moves, SGR emission, and character output; in Tessera this logic lives in the
>   `Renderer` itself since there is no separate backend abstraction.

The renderer's job: given a previous `Buffer` and a current `Buffer`, emit the minimum
bytes that transform the terminal's display from the previous state to the current one.

```swift
public actor Renderer {
    public init(io: PlatformIO)

    /// Draws `buffer`, computing diffs from the previously drawn buffer.
    /// First call after `init` emits a full repaint.
    public func draw(_ buffer: Buffer) async throws

    /// Forces the next `draw` to emit a full repaint, ignoring history.
    /// Used after resize, after losing/regaining focus, on demand.
    public func invalidate() async
}
```

Three pieces of internal state:

- The last-drawn buffer (`Buffer?` — `nil` triggers full repaint).
- The currently active `Style` on the terminal (so we know whether SGR needs re-emitting).
- The currently believed cursor position (so we know whether `cursorPosition` needs
  emitting).

##### The diff algorithm

> [!note] Ratatui References
>
> - `BufferDiff` (`ratatui-core/src/buffer/diff.rs`, line 10) is a zero-allocation
>   iterator that yields `(x, y, &Cell)` for changed cells. It handles multi-width skip
>   (line 78), VS16 trailing-cell explicit clears (line 88), and `CellDiffOption`
>   directives — the same row-by-row, multi-width-aware diff strategy Tessera describes in
>   its pseudocode.
> - `CellDiffOption` (`ratatui-core/src/buffer/cell.rs`, line 12) provides `Skip`,
>   `AlwaysUpdate`, and `ForcedWidth` — Ratatui's mechanism for telling the diff iterator
>   how to treat cells covered by escape sequences (images, links). `ForcedWidth` is how
>   Ratatui handles wide-grapheme trailing cells during diffing without a continuation
>   enum.

Row-by-row, with run coalescing. Pseudocode:

```
for each row r:
    if rows are equal: skip
    find the first column c0 where cells differ
    find the last column c1 where cells differ
    emit cursor-position(r, c0)
    for each column c in c0...c1:
        if cell(r, c).style != currentTerminalStyle:
            emit SGR delta to reach cell.style
            currentTerminalStyle = cell.style
        emit text bytes for cell.content
        (continuation cells: emit nothing — the previous grapheme already drew them)
```

Properties of this approach:

- **One cursor move per dirty row** instead of per dirty cell.
- **SGR is only emitted when style changes**, so a row of cells in the same style emits a
  single SGR up front and then just text.
- **Continuation cells emit nothing** — they're not "drawn," they're consumed by the wide
  grapheme to their left.
- **Equal rows skip entirely.** For a screen where one row changes per frame (e.g., a
  status line update), one row's worth of work happens; everything else is a
  row-comparison and a skip.

This is roughly the algorithm Ratatui uses, and it's well-trodden territory.

##### SGR delta emission

> [!note] Ratatui References
>
> - `Style` (`ratatui-core/src/style.rs`, line 239) is an incremental style with `fg`,
>   `bg`, `add_modifier`, and `sub_modifier` fields — styles compose via patch, not
>   replace. `Modifier` (line 104) is a bitflag enum (BOLD, DIM, ITALIC, UNDERLINED,
>   SLOW_BLINK, RAPID_BLINK, REVERSED, HIDDEN, CROSSED_OUT). This matches Tessera's SGR
>   delta approach where only changed attributes are emitted.

The naive approach is "if styles differ, reset and re-set everything." Better: emit only
the SGR codes for the attributes that actually changed. Concretely:

```swift
func sgrDelta(from old: Style, to new: Style, into bytes: inout [UInt8]) {
    // If the new style strictly *adds* attributes, emit just the additions.
    // If anything was *removed*, emit reset (SGR 0) then full new style.
    // This is the right tradeoff: removal is rare, reset+set is short anyway.
}
```

For the first frame and after `invalidate()`, the "previous style" is `nil` and we emit a
reset followed by the full style. This handles startup correctly without special-casing.

There's a subtle invariant: **after `draw` returns, the terminal's SGR state must match a
known value, and the renderer must remember that value.** If you let the terminal end a
frame in arbitrary SGR state, the next frame's delta computation breaks. The standard
discipline: end every frame with `resetAttributes` and remember "current style is the
default." Costs a few bytes per frame; eliminates a whole class of bugs.

##### Cursor positioning optimization

> [!note] Ratatui References
>
> - `Terminal` tracks `last_known_cursor_pos` (`ratatui-core/src/terminal.rs`, line 434)
>   as a best-effort record of where it last wrote. `flush()`
>   (`ratatui-core/src/terminal/buffers.rs`, line 104) updates it from the last diffed
>   cell. Ratatui doesn't use this to skip cursor moves during diff emission — that
>   optimization lives in the backend's `draw()` implementation, not in the diff layer.

After emitting the bytes for cell `[r, c]`, the terminal cursor is at `[r, c+width]`. If
the next cell to emit is exactly there, no cursor-position emission is needed. The
renderer tracks "believed cursor position" and only emits `cursorPosition` when it doesn't
match the next write target.

In practice this matters most for the "first dirty cell in a row" — if the previous row's
last write left the cursor at the start of the next row, you may not need a cursor move.
Modest byte savings, but free if you're already tracking position.

##### Synchronized Output wrapping

> [!note] Ratatui References
>
> - Synchronized Output (DEC 2026) is not implemented in Ratatui — no
>   `enter_sync`/`exit_sync` methods exist on any backend. Tessera's unconditional
>   sync-output wrapping is a design decision without a Ratatui precedent.

Every frame:

```
enter synchronized output
... diff bytes ...
exit synchronized output
```

Two notes:

- **Always emit it, even when no cells changed.** A "no-op" frame should still bracket
  itself; that's how terminals with synchronized output learn "the previous frame ended."
  Sending just `enter; exit` is a few bytes and harmless.
- **Terminals that don't support DEC 2026 ignore the sequences.** Documented xterm
  behavior: unknown private modes are silently ignored. No need for capability detection
  here.

#### Resize handling

> [!note] Ratatui References
>
> - `Terminal::resize()` (`ratatui-core/src/terminal/resize.rs`, line 23) updates buffer
>   sizes, clears the viewport, and resets the previous buffer so the next draw is a full
>   repaint — matching Tessera's "discard last-drawn buffer" discipline. `autoresize()`
>   (line 64) checks the backend size during every render pass and calls `resize()` when
>   it changes.
> - `Terminal::clear()` (`ratatui-core/src/terminal/buffers.rs`, line 136) emits
>   `ClearType::All` for fullscreen viewports — the same "eraseInDisplay(.all)" Tessera
>   emits after resize.

When `PlatformIO.sizeChanges` yields a new size, the renderer needs to:

1. Discard its last-drawn buffer (next frame is a full repaint).
2. The view layer (Phase 4) re-lays out at the new size and produces a new buffer.
3. The renderer draws it fresh.

For slice 4 — pre-view-layer — resize just invalidates the renderer; the example app is
responsible for noticing and producing a new buffer of the new size. This is awkward and
that's fine; Phase 4 makes it elegant.

One sharp edge: **after resize, the terminal's screen may contain garbage from the old
size.** The renderer's first post-resize frame should emit `eraseInDisplay(.all)` before
drawing. Build this into `invalidate()` — invalidating means "assume the screen is
unknown, paint everything, including erasing first."

#### Testing strategy for the renderer

This is where slice 1's snapshot harness shines. Every renderer change ships with a
snapshot test of the form: "given previous buffer X and current buffer Y, the renderer
emits bytes B; feeding B to `VirtualTerminal` (starting in state matching X) produces a
terminal state matching Y." End-to-end correctness, automated.

Plus targeted unit tests:

- **Pure diff tests.** Two buffers in, byte sequence out, golden fixture. Catches the
  "wrong bytes" case directly.
- **Equal-row skip test.** Two identical rows produce no bytes for that row.
- **SGR delta tests.** Style A → Style B emits the expected minimal SGR.
- **Cursor optimization tests.** Two consecutive cells in the same row don't emit an
  intermediate cursor move.
- **Wide-grapheme tests.** Writing "你好" produces a buffer with cells laid out correctly
  (grapheme, continuation, grapheme, continuation), and the rendered bytes are what we
  expect.
- **Orphan-rule tests.** Overwriting half a wide grapheme blanks the other half; rendered
  bytes reflect this.
- **Invalidate test.** After `invalidate()`, next frame is a full repaint including erase.

Roughly 30-40 tests for slice 4, weighted toward the snapshot end. The library's
reliability rests on these.

#### Performance posture

> [!note] Ratatui References
>
> - `Buffer` stores cells as a flat `Vec<Cell>` (`ratatui-core/src/buffer/buffer.rs`,
>   line 73) indexed by `row * width + col` — the same cache-friendly layout Tessera
>   chooses. `CellWidth` (`ratatui-core/src/buffer/cell_width.rs`, line 19) computes width
>   on access from the stored symbol string, matching Tessera's "width is computed, not
>   stored" principle.

For Phase 2, the target is "good enough that you can't see the difference." Concretely:

- 200×60 cell buffer, one cell changed per frame: well under 1 KB of bytes emitted, well
  under 1 ms of renderer work. Easy.
- 200×60 cell buffer, full repaint: ~30-50 KB of bytes, a few ms. Acceptable; only happens
  on resize/invalidate.
- 200×60 cell buffer, ~10% cells changed (e.g., scrolling a log view): a few KB, well
  under 1 ms. Easy.

We're not benchmarking yet — that's Phase 5 polish work. But the design should not
preclude future perf work. The two things that _would_ preclude it: storing the buffer as
a 2D Array of Arrays (cache-hostile) and recomputing widths on every comparison (wasted
CPU). Counter-decisions baked into the design: flat `[Cell]` indexed as
`row * cols + col`, and width as a cheap computed property over already-stored grapheme
strings.

#### Definition of done for slice 4

1. `Cell` redesigned with `Content` enum (`grapheme`/`continuation`/`blank`) and computed
   `width`.
2. `Buffer.write(_:at:style:)` correctly handles wide graphemes, continuation cells, the
   orphan rule, and clipping at row boundaries.
3. `swift-displaywidth` added as a dependency and used for all width queries.
4. `Renderer` actor with `draw(_:)`, `invalidate()`, internal SGR/cursor state tracking,
   row-by-row diff with run coalescing, synchronized output wrapping.
5. Renderer integrates with `PlatformIO`: buffered writes per frame, one `flush` at end of
   frame.
6. Phase 1 walking skeleton is updated to use the real renderer. Visible result: no more
   flicker; typing feels instant.
7. ~30-40 tests covering: width handling, orphan rule, diff correctness, SGR minimization,
   cursor optimization, synchronized-output wrapping, invalidate behavior. Mix of unit
   tests and snapshot tests through `VirtualTerminal`.
8. The `tessera-reset` resilience story still holds: a `kill -INT` during a render leaves
   the terminal sane (verified manually).

#### What's not in this slice

- **Scrollback handling.** The renderer assumes alt screen, where scrollback doesn't
  apply. Inline (non-alt-screen) rendering is a separate concern for Phase 5+.
- **Partial repaints triggered by view changes.** Slice 4 diffs whole buffers. The view
  layer in Phase 4 may eventually want to _invalidate regions_ for efficiency, but for now
  the diff is the optimization.
- **Hardware scrolling.** Some renderers detect "row 5 is now what row 4 used to be" and
  emit scroll-region commands instead of redrawing. We don't. The complexity isn't worth
  it for TUI apps, which rarely scroll-shift the whole screen.
- **Reflow on resize.** The renderer just invalidates and asks for a new buffer. The view
  layer handles re-layout.
- **Color quantization.** If a user asks for truecolor on a terminal that only supports
  256 colors, the encoder emits truecolor anyway. Capability-aware quantization is a Phase
  5 concern.

#### Three things to flag

1. **The `Cell.Content` design with `.continuation` as a first-class case** is the most
   architecturally consequential decision in slice 4. The alternative — storing wide
   graphemes "spanning" two cells via some marker on the right cell — is what some
   libraries do, and it ends up being more error-prone. Making continuation an enum case
   means the type system forces you to handle it explicitly, which is exactly what you
   want for a tricky invariant.

2. **Synchronized output unconditionally** is the right call, but worth being explicit
   that we're not detecting terminal capability. The bet is that the cost of emitting 8
   bytes per frame to non-supporting terminals is dwarfed by the win on supporting ones.
   If profiling ever shows otherwise, capability detection can be added without changing
   the renderer's design.

3. **The renderer is an actor, like `PlatformIO` and `ModeLifecycle`.** Three actors in
   `TesseraTerminal` is starting to feel like a lot, and you might wonder whether they
   should be merged. I think keeping them separate is right — each has a distinct
   concurrency boundary and a distinct testability story (you can mock `PlatformIO` to
   test `Renderer` in isolation, etc.) — but it's worth being explicit that "three actors"
   is a deliberate choice and not accidental complexity.

---

### Slice 5: Legacy input parser (escape sequences, arrow keys, function keys, modifiers)

Slice 5 is where Tessera learns to listen. Slice 2 turned semantic operations into bytes
flowing out; slice 5 turns bytes flowing in back into semantic events. It's the mirror
image, but the asymmetry we discussed earlier (different vocabularies, no real
parser-printer duality) means the design lands in a different place — a state machine, not
a reversed encoder.

This slice is also where you start hitting the historical sediment of the terminal world.
Input encoding is a mess of overlapping, contradictory, and ambiguous protocols
accumulated over five decades. The discipline here is to handle the _legacy_ layer
correctly and completely, knowing that Phase 3's Kitty keyboard protocol will eventually
replace most of it — but only on terminals that support it.

#### The four problems this slice solves

> [!note] Ratatui References
>
> - Ratatui itself has no input layer — it delegates entirely to crossterm. The `Event`
>   enum (`crossterm` `src/event.rs`, line 550) is the top-level type: `Key(KeyEvent)`,
>   `Mouse(MouseEvent)`, `Resize(u16, u16)`, `Paste(String)`, `FocusGained`/`FocusLost`.
> - The four problems map directly to crossterm's design: (1) byte-by-byte buffering is
>   handled by the `Parser` struct (`src/event/source/unix/mio.rs`, line 168) which
>   accumulates bytes in a `Vec<u8>` buffer until `parse_event` succeeds; (2) ESC
>   ambiguity is resolved by the `input_available` parameter to `parse_event`
>   (`src/event/sys/unix/parse.rs`, line 26) — when no more bytes are pending, bare ESC
>   emits `KeyCode::Esc`; (3) irregular modifier encoding is handled by `parse_modifiers`
>   (`src/event/sys/unix/parse.rs`, line 313) which decodes the semicolon-separated
>   modifier mask; (4) UTF-8 assembly is in `parse_utf8_char`
>   (`src/event/sys/unix/parse.rs`, line 825) which validates continuation bytes against
>   the expected sequence length.

1. **Multi-byte sequences arrive byte-by-byte.** A press of the up arrow generates the
   three bytes `\e [ A`. They may arrive in one `read(2)` call or three separate ones
   depending on buffering, network conditions (ssh), and terminal implementation. The
   parser must buffer partial sequences and complete them across reads.

2. **The ESC ambiguity.** A bare ESC byte is both "the user pressed Escape" and "the
   beginning of an escape sequence." You can't know which until you wait for more bytes —
   or wait long enough that you're confident none are coming. This is the single most
   annoying design problem in terminal input handling, and there's no clean solution, only
   better and worse tradeoffs.

3. **Legacy modifier encoding is irregular.** Shift+Tab is `\e[Z`. Ctrl+A is `\x01` (a
   single byte, no escape at all). Alt+a is `\e a` (escape followed by literal 'a').
   Ctrl+Shift+arrow is `\e[1;6A` (semicolon-separated modifier parameter). Each of these
   is its own format. The parser needs a table-driven approach because there's no
   underlying grammar to exploit.

4. **Unicode input from paste or IME.** A user typing or pasting "你好" sends UTF-8
   multi-byte sequences that are _not_ escape sequences and need to be assembled into
   graphemes. The parser needs to distinguish "byte is part of a UTF-8 character" from
   "byte is part of an escape sequence" — usually trivial (escape sequences are
   ASCII-only) but worth being explicit about.

#### The shape: a streaming state machine

> [!note] Ratatui References
>
> - crossterm's parser is not exposed as a public type — it's a private `Parser` struct
>   (`src/event/source/unix/mio.rs`, line 168) with a `buffer: Vec<u8>` and
>   `internal_events: VecDeque<InternalEvent>`. It implements `Iterator`, yielding
>   `InternalEvent` items. This is the Rust equivalent of Tessera's `InputParser`.
> - The `advance` method (`src/event/source/unix/mio.rs`, line 198) feeds bytes one at a
>   time into `parse_event`, clearing the buffer on success or keeping it on `Ok(None)`
>   (partial sequence). This is the same byte-by-byte streaming pattern Tessera uses with
>   `feed(_:)`.
> - Unlike Tessera's pull-model `feed` returning `[InputEvent]`, crossterm's parser pushes
>   completed events into a `VecDeque` and yields them via `Iterator::next()`. Tessera's
>   design is cleaner for async — the caller drives the stream, the parser doesn't own
>   time.

The parser is a struct with mutable state that consumes bytes one at a time and yields
events when sequences complete. Concretely:

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

- **The parser is a `struct`, not an actor.** Single-threaded by construction (called from
  one place: the input task in `PlatformIO`). No need for concurrency primitives.
- **`feed` returns events, doesn't yield them.** Pull model, not push. The caller is the
  input task, which already drives an `AsyncStream<InputEvent>`; pushing into a stream
  from inside the parser would conflate concerns.
- **`flush` is the ESC-ambiguity escape valve.** When input pauses (no bytes for ~25-50ms
  after an ESC), `flush` resolves the dangling ESC as a literal Escape keypress.
- **No `reset`.** The parser is always in a valid state; partial sequences are pending
  data, not errors.

#### The `InputEvent` type

> [!note] Ratatui References
>
> - crossterm's `KeyEvent` struct (`src/event.rs`, line 937) is the direct analog of
>   Tessera's `Key`: it carries `code: KeyCode`, `modifiers: KeyModifiers`,
>   `kind: KeyEventKind` (Press/Repeat/Release), and `state: KeyEventState` (keypad,
>   caps-lock, num-lock). Tessera's Phase 2 drops `kind` and `state` — those are Phase 3
>   (Kitty protocol).
> - `KeyCode` enum (`src/event.rs`, line 1226) covers: `Char(char)`, `Backspace`, `Enter`,
>   `Left`/`Right`/`Up`/`Down`, `Home`, `End`, `PageUp`, `PageDown`, `Tab`, `BackTab`,
>   `Delete`, `Insert`, `F(u8)`, `Esc`, `Null`, plus Kitty-only keys (`CapsLock`, `Media`,
>   `Modifier`). Tessera's Phase 2 `KeyCode` is a subset of this.
> - `KeyModifiers` (`src/event.rs`, line 840) is a `bitflags` OptionSet with `SHIFT`,
>   `CONTROL`, `ALT`, `SUPER`, `HYPER`, `META`. Tessera's Phase 2 uses only `shift`,
>   `alt`, `control` — matching what legacy protocols can report.
> - `KeyEvent::normalize_case()` (`src/event.rs`, line 973) encodes the same "shift only
>   for non-character keys" convention Tessera documents: uppercase chars get SHIFT added,
>   lowercase with SHIFT get uppercased.

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
    public static let shift   = Modifiers(rawValue: 1 << 0)
    public static let alt     = Modifiers(rawValue: 1 << 1)
    public static let control = Modifiers(rawValue: 1 << 2)
}
```

Design notes:

- **`KeyCode.char` carries a `Character`, not a byte.** UTF-8 assembly happens _inside_
  the parser; consumers see graphemes. Same logic as the buffer: terminals deal in
  graphemes, so we do too.
- **No `super`/`meta`/`hyper` modifiers.** Legacy protocols can't represent them; Phase
  3's Kitty support will add them.
- **No `KeyCode.unknown` — there's `InputEvent.unknown` instead.** A recognized key with
  unrecognized modifiers is still a recognized key. Unknown is reserved for "bytes that
  don't fit any known sequence shape."
- **Shift is included as a modifier but is often redundant.** `Key(.char("A"), [.shift])`
  and `Key(.char("A"), [])` represent the same thing visually. Convention: shift modifier
  is set _only_ for non-character keys (Shift+Tab, Shift+Arrow). For letters, the case
  carries the shift information. This is what legacy protocols actually report, and trying
  to normalize is a losing battle.

#### The state machine

> [!note] Ratatui References
>
> - crossterm doesn't use an explicit enum for parser states — the state machine is
>   implemented as a series of match branches in `parse_event`
>   (`src/event/sys/unix/parse.rs`, line 26). The `.ground` state is the top-level
>   `match buffer[0]`; `.escape` is the `b'\x1B'` branch (line 31); `.csi` is the
>   `parse_csi` function (line 137); `.ss3` is the `b'O'` sub-branch inside escape (line
>   48). The implicit state is carried by which function is called and the remaining
>   buffer slice.
> - The `.utf8` state is handled by `parse_utf8_char` (`src/event/sys/unix/parse.rs`,
>   line 825) which validates continuation bytes against expected sequence lengths (2, 3,
>   or 4 bytes based on leading byte). Returns `Ok(None)` when more bytes needed — the
>   caller's buffer retains the partial sequence.
> - Tessera's explicit state enum (`.ground`, `.utf8`, `.escape`, `.csi`, `.ss3`) is a
>   cleaner design than crossterm's implicit state-in-the-call-stack, making it easier to
>   reason about and test.

Conceptually, the parser is in one of these states:

- **`.ground`** — waiting for a fresh byte. ASCII control char → emit. Printable ASCII →
  emit. UTF-8 leading byte → enter `.utf8`. ESC → enter `.escape`.
- **`.utf8(expectedBytes: Int, accumulated: [UInt8])`** — assembling a multi-byte UTF-8
  character. Each continuation byte advances; once complete, decode and emit as
  `.char(...)`.
- **`.escape`** — saw an ESC, waiting to disambiguate. `[` → enter `.csi`. `O` → enter
  `.ss3` (function keys F1-F4 on some terminals). Letter → Alt+letter, emit and return to
  `.ground`. Anything else weird → emit Escape + the byte separately.
- **`.csi(params: String, intermediates: String)`** — inside a CSI sequence (`\e[...`).
  Accumulate parameter bytes (digits + `;`), then a final byte (`A`-`Z`, `~`) triggers
  lookup-and-emit.
- **`.ss3`** — saw `\eO`, expecting one letter. The letter selects a function key (`P`=F1,
  `Q`=F2, `R`=F3, `S`=F4).

Per-state transition tables make this implementation tedious but straightforward. The
trick is to keep the state machine _small_ — handle only what real terminals actually
send, fall through to `.unknown` for everything else, and refine over time.

#### The legacy sequence catalog

> [!note] Ratatui References
>
> - ASCII control range: `parse_event` handles `b'\x01'..=b'\x1A'` as Ctrl+letter (line
>   97), `b'\x1C'..=b'\x1F'` as Ctrl+4..Ctrl+/ (line 101), `b'\r'`/`b'\n'` as Enter (lines
>   82–88), `b'\t'` as Tab (line 90), `b'\x7F'` as Backspace (line 92), and `b'\0'` as
>   Ctrl+Space (line 105). Matches Tessera's catalog exactly.
> - CSI arrows: `parse_csi` handles `\e[A`/`B`/`C`/`D` as Up/Down/Right/Left (line 146),
>   `\e[H`/`\e[F` as Home/End (line 150), `\e[Z` as Shift+Tab/BackTab (line 155).
> - CSI tilde keys: `parse_csi_special_key_code` (line 619) maps `1~`/`7~`→Home,
>   `2~`→Insert, `3~`→Delete, `4~`/`8~`→End, `5~`→PageUp, `6~`→PageDown, and ranges
>   `11~`–`26~` to F1–F12. Matches Tessera's vt220-style catalog.
> - SS3 function keys: the `b'O'` branch in `parse_event` (line 48) handles `\eOP`–`\eOS`
>   as F1–F4 and `\eOA`–`\eOD` as arrows in application mode (lines 51–68).
> - CSI modifier keys: `parse_csi_modifier_key_code` (line 348) parses `\e[1;<mods>A` etc.
>   with `parse_modifiers` (line 313) decoding the mask. Matches Tessera's modifier
>   scheme.

The concrete set of sequences the parser needs to recognize for Phase 2:

**ASCII control range (single bytes)**

- `0x00..0x1F` (except 0x09 Tab, 0x0A/0x0D Enter, 0x1B ESC, 0x7F Backspace): Ctrl+letter.
  `Ctrl+A` = `0x01`, `Ctrl+B` = `0x02`, ..., `Ctrl+Z` = `0x1A`. Compute as `byte + 0x40`
  to get the letter.
- `0x09`: Tab.
- `0x0A` (LF) and `0x0D` (CR): both Enter. Terminals differ on which they send; treat both
  as Enter.
- `0x7F` (DEL): Backspace. (Counterintuitively. The "Backspace" key on most keyboards
  sends DEL; the `0x08` BS code is rarely sent.)
- `0x08` (BS): Ctrl+H, which is also sometimes Backspace. Emit Ctrl+H; let the application
  decide.
- `0x1B` (ESC) alone: handled via the `.escape` state and timer.

**ESC + letter (Alt+letter)**

- `\e<letter>`: Alt+letter. `\ea` = Alt+a.
- This is the source of the ESC ambiguity. Distinguishing "Alt+a" from "Escape then a"
  requires the timer.

**CSI sequences (\e[ ...)**

- `\e[A` / `B` / `C` / `D`: Up / Down / Right / Left.
- `\e[H` and `\e[F`: Home and End (xterm style).
- `\e[1~`, `\e[4~`: Home and End (vt220 style — some terminals use this).
- `\e[2~`, `\e[3~`: Insert and Delete.
- `\e[5~`, `\e[6~`: PageUp and PageDown.
- `\e[Z`: Shift+Tab (the one truly weird one).
- `\e[11~`..`\e[15~`, `\e[17~`..`\e[21~`, `\e[23~`, `\e[24~`: F1-F12 (vt220 style).
- `\e[1;<mods><letter>`: arrow/home/end with modifiers. Mods encoded as `2`=Shift,
  `3`=Alt, `4`=Shift+Alt, `5`=Ctrl, `6`=Shift+Ctrl, `7`=Alt+Ctrl, `8`=Shift+Alt+Ctrl. So
  `\e[1;5A` is Ctrl+Up.
- `\e[<N>;<mods>~`: same modifier scheme for tilde-style keys. `\e[3;5~` is Ctrl+Delete.

**SS3 sequences (\eO ...)**

- `\eOP`, `\eOQ`, `\eOR`, `\eOS`: F1-F4 (xterm application-mode style).
- `\eOA`/`B`/`C`/`D`: arrows in application keypad mode. Rare but worth handling.

**UTF-8 multi-byte**

- Leading byte `0xC2..0xF4` → 2-, 3-, or 4-byte sequence. Standard UTF-8 decoding.

That's the Phase 2 catalog. Roughly 40-50 distinct recognized sequences. Phase 3 adds
bracketed paste (`\e[200~ ... \e[201~`), SGR mouse (`\e[<...M` / `m`), focus (`\e[I` /
`\e[O`), and Kitty keyboard (`\e[<unicode>;<mods>;<text>u` — a whole new world).

#### The ESC ambiguity, in detail

> [!note] Ratatui References
>
> - crossterm resolves ESC ambiguity in `parse_event` (`src/event/sys/unix/parse.rs`,
>   lines 31–35): when the buffer is exactly `[0x1B]` (length 1), it checks the
>   `input_available` boolean — `false` (no more bytes pending) emits `KeyCode::Esc`,
>   `true` (more bytes may arrive) returns `Ok(None)` to wait. The timeout that determines
>   "are more bytes coming?" is the `poll` timeout in `UnixInternalEventSource::try_read`
>   (`src/event/source/unix/mio.rs`, line 68) which uses `PollTimeout`
>   (`src/event/timeout.rs`, line 5).
> - Unlike Tessera's explicit 25ms configurable timeout in the input task, crossterm's
>   timeout is whatever the caller passes to `poll()` — there's no built-in ESC-specific
>   timeout. The `EventStream` async type (`src/event/stream.rs`, line 33) polls with zero
>   timeout and relies on mio's readiness notification, which means ESC latency depends on
>   when the next byte arrives (no explicit timeout flush).
> - `KeyboardEnhancementFlags::DISAMBIGUATE_ESCAPE_CODES` (`src/event.rs`, line 292) is
>   the Phase 3 escape hatch: when enabled, Escape sends `\e[27u` which is unambiguous.
>   Tessera mirrors this with Kitty protocol support.

The standard solution is a timeout: after receiving a bare ESC, wait some number of
milliseconds for more bytes. If something arrives within the window, it's an escape
sequence; if not, it's a literal Escape keypress.

The classic value is 25-50ms. Lower than ~25ms and you get false positives on slow
connections (ssh over a bad link). Higher than ~50ms and the Escape key feels laggy.
**Tessera's choice: 25ms by default, configurable.**

Where the timer lives matters. It can't live in `InputParser` because the parser is
synchronous and doesn't own time. It lives in the _input task_ in `PlatformIO`:

```
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

The parser exposes "am I in a pending-escape state?" via a property; the input task
adjusts its poll timeout accordingly. Clean separation: parser knows shapes, task knows
time.

There's a sharper alternative — _Kitty keyboard protocol_ in Phase 3 eliminates ESC
ambiguity entirely by sending Escape as `\e[27u`. Once enabled, the timer can be set to 0.
Worth noting in a comment, but not relevant to slice 5.

#### A note on bracketed paste (which is _not_ in slice 5)

Without bracketed paste enabled, when a user pastes a block of text, every character
arrives as individual keystrokes. There's no way to distinguish typed from pasted input.
This is _fine_ for slice 5 — the parser correctly emits N `KeyCode.char` events for an
N-character paste, and the application handles them like any other input.

The bracketed paste mode (`\e[?2004h`) makes the terminal wrap pasted content in
`\e[200~ ... \e[201~`, letting the parser emit a single `InputEvent.paste(String)` event.
That's Phase 3 territory. Slice 5 just needs to _not preclude_ this — which it doesn't,
because the parser's escape-sequence handling already extends cleanly.

#### Wiring into `PlatformIO`

> [!note] Ratatui References
>
> - crossterm's `InternalEventReader` (`src/event/read.rs`, line 12) is the singleton that
>   wraps the platform-specific `EventSource` and provides `poll()` and `read()` methods.
>   It's held behind a `parking_lot::Mutex` as a static (`src/event.rs`, line 149) — only
>   one event reader exists per process.
> - `UnixInternalEventSource` (`src/event/source/unix/mio.rs`, line 24) uses mio's `Poll`
>   to multiplex stdin (TTY_TOKEN), SIGWINCH signals (SIGNAL_TOKEN), and an optional waker
>   (WAKE_TOKEN). On SIGWINCH, it calls `crate::terminal::size()` and yields
>   `Event::Resize(columns, rows)` (line 123). This is the same pattern Tessera uses:
>   unify keyboard input and resize events into one stream.
> - The `EventStream` async type (`src/event/stream.rs`, line 33) implements
>   `futures_core::stream::Stream` and spawns a background thread that blocks on
>   `poll_internal` and wakes the async task when events arrive. This is the closest
>   analog to Tessera's `AsyncStream<InputEvent>`.

Slice 3 gave you `PlatformIO.bytes: AsyncStream<UInt8>`. Slice 5 layers on top:

```swift
extension PlatformIO {
    public var events: AsyncStream<InputEvent> { get }
}
```

The implementation is the input task we sketched: read bytes, feed parser, yield events,
manage timeout for ESC ambiguity. The raw `bytes` stream stays available for users who
want to bypass the parser (rare but legitimate — Phase 3's Kitty support might need this).

A `SIGWINCH` arriving via the cleanup-registry mechanism also yields an
`InputEvent.resize(TerminalSize)` through the same stream. This unifies "user input" and
"terminal state changes" into one event channel — exactly what application code wants.

#### Testing strategy

> [!note] Ratatui References
>
> - crossterm's parser tests live in the `#[cfg(test)] mod tests` block at the bottom of
>   `src/event/sys/unix/parse.rs` (line 1183). They cover: `test_esc_key` (bare ESC),
>   `test_possible_esc_sequence` (ESC with more bytes pending), `test_alt_key`
>   (Alt+letter), `test_parse_csi` (arrow keys), `test_parse_csi_modifier_key_code`
>   (modified arrows), `test_parse_csi_special_key_code` (tilde keys),
>   `test_parse_csi_focus` (focus events), `test_utf8` (multi-byte UTF-8 validation),
>   `test_parse_char_event_uppercase` (shift convention), and CSI-u encoded key tests
>   (Kitty protocol).
> - The `test_parse_event_subsequent_calls` test (line 1205) feeds complete byte sequences
>   and asserts the parsed event — the golden-test pattern Tessera describes.
> - crossterm lacks explicit multi-byte split tests (feeding `[0x1b]`, then
>   `[0x5b, 0x31]`, then `[0x35, 0x41]` separately). Tessera's spec calls these out
>   explicitly as a test category — a worthwhile addition over crossterm's coverage.

The parser is the most fixture-heavy module in the library. The shape of the tests:

- **Per-sequence golden tests.** For every entry in the catalog, feed the byte sequence
  and assert the emitted event. ~50 tests, mechanical.
- **Multi-byte split tests.** Feed `\e[1;5A` as three separate `feed` calls: `[0x1b]`,
  `[0x5b, 0x31, 0x3b]`, `[0x35, 0x41]`. Assert no premature events, final event is
  Ctrl+Up. Catches "parser assumes whole sequence in one call" bugs.
- **ESC-ambiguity tests.** Feed `\e`, no more bytes, call `flush()`, assert Escape
  keypress. Feed `\e`, then `a`, assert Alt+a (no flush). Feed `\e`, flush, feed `a`,
  assert Escape then 'a' (two separate events).
- **UTF-8 tests.** Feed multi-byte UTF-8 characters byte-by-byte; assert single `.char`
  event with correct grapheme.
- **Unknown-sequence tests.** Feed garbage like `\e[99X`; assert `InputEvent.unknown` with
  the captured bytes.
- **Integration test via `PlatformIO`.** With a fake stdin source, feed byte streams,
  assert events flow through correctly with realistic timing.

Roughly 60-80 tests for the parser. Most are tiny. The whole test file becomes the de
facto specification of what Tessera accepts as input.

#### Definition of done for slice 5

1. `InputEvent`, `Key`, `KeyCode`, `Modifiers` public types.
2. `InputParser` struct with `feed(_:)` and `flush()` methods, state machine
   implementation, full Phase 2 sequence catalog.
3. `PlatformIO.events: AsyncStream<InputEvent>` derived from `bytes`, with ESC-timeout
   handling in the input task.
4. `SIGWINCH` yields `InputEvent.resize` through the same stream.
5. ~60-80 tests covering: every catalog sequence, multi-byte splits, ESC ambiguity, UTF-8
   assembly, unknown sequences, end-to-end via `PlatformIO`.
6. Phase 1 walking skeleton is updated: replace the Phase 1 byte-detection with
   `for await event in io.events`. Arrow keys now work. Ctrl-C still triggers SIGINT
   (handled by the signal handler, restoring the terminal). Escape-to-exit works without
   200ms lag.

#### What's not in this slice

> [!note] Ratatui References
>
> - crossterm's bracketed paste is behind the `bracketed-paste` feature flag.
>   `EnableBracketedPaste` (`src/event.rs`, line 421) emits `\e[?2004h`;
>   `DisableBracketedPaste` emits `\e[?2004l`.
> - The parser function `parse_csi_bracketed_paste` (`src/event/sys/unix/parse.rs`,
>   line 813) looks for `\e[200~` prefix and `\e[201~` suffix, extracting the pasted
>   string between them. Returns `Ok(None)` if the closing marker hasn't arrived yet
>   (partial paste).
> - The `Event::Paste(String)` variant is conditionally compiled with
>   `#[cfg(feature = "bracketed-paste")]` on the `Event` enum (line 550). Tessera's design
>   of deferring this to Phase 3 mirrors crossterm's feature-gated approach.

- **Bracketed paste.** Phase 3.
- **SGR mouse events.** Phase 3.
- **Focus events.** Phase 3.
- **Kitty keyboard protocol.** Phase 3.
- **Mode-aware parsing.** Some sequences are ambiguous between protocols; once Phase 3
  adds Kitty support, the parser will need to know which mode is active. Not yet.
- **IME / dead keys / composition input.** Tessera receives whatever the terminal sends;
  if the terminal does IME natively (as macOS Terminal does for some methods), we get the
  composed result. If the terminal sends raw scan codes, we don't try to compose. This is
  a terminal concern.
- **Bidirectional text handling.** Not Tessera's job — the terminal renders, we just feed
  it bytes.

#### Three things to flag

> [!note] Ratatui References
>
> - ESC timeout: crossterm has no configurable ESC timeout — the resolution depends
>   entirely on the caller's `poll` timeout. `EventStream` uses zero-timeout polling with
>   mio readiness, so ESC latency is unbounded (waits for next byte forever). This is a
>   known limitation; crossterm relies on Kitty protocol (`DISAMBIGUATE_ESCAPE_CODES`,
>   line 292) as the proper fix rather than tuning a timeout.
> - Shift modifier convention: `KeyEvent::normalize_case()` (`src/event.rs`, line 973) and
>   `char_code_to_event()` (`src/event/sys/unix/parse.rs`, line 112) both implement the
>   "uppercase char implies SHIFT" convention. crossterm's `PartialEq` for `KeyEvent`
>   (line 1003) normalizes before comparison, so `KeyEvent(Char('A'), SHIFT)` equals
>   `KeyEvent(Char('A'), NONE)` — the equivalence Tessera's spec describes.
> - Unknown events: crossterm does not have an equivalent to `InputEvent.unknown(bytes:)`.
>   Unrecognized sequences cause `parse_event` to return `Err` (line 26), which propagates
>   as an `io::Error` from `read()`. The `Parser::advance` method (line 198) silently
>   clears the buffer on error and moves on. Tessera's choice to surface unknown bytes is
>   a deliberate improvement over this behavior.

1. **The 25ms ESC timeout is the single most user-visible knob in the library**, and the
   default matters. 25ms is responsive but can cause false positives on slow ssh; 100ms is
   safe but makes Escape feel sticky. I'd ship 25ms and surface the configuration
   prominently in docs. The Kitty keyboard escape hatch (Phase 3) eliminates the tradeoff
   entirely; nudging users toward Kitty-capable terminals is a long-term win.

2. **The "shift modifier is set only for non-character keys" convention is the kind of
   thing that will confuse exactly one user per year, forever.** It's the correct behavior
   — matching what legacy terminals actually send — but worth a prominent doc-comment
   example. Phase 3's Kitty protocol fixes this too (reports shift always), but for the
   legacy layer, the convention has to hold.

3. **`InputEvent.unknown(bytes:)` as a public case** is a deliberate choice to surface
   protocol gaps rather than swallow them. The cost is that _any_ unrecognized sequence
   becomes part of the public API surface and users may pattern-match on it. The win is
   enormous for debugging — when someone files "my key doesn't work," they can
   `print(event)` and immediately see the bytes. I think this is the right trade, but
   worth noting it commits us to keeping that case in the API forever.

### Slice 6: Windows support for `PlatformIO` (SetConsoleMode, ReadConsoleInput, Windows signal equivalents)

Slice 6 is the last slice of Phase 2 and the one that makes "cross-platform" go from spec
aspiration to demonstrable fact. The good news: because slices 2-5 were designed around
bytes-in/bytes-out, the encoder, parser, buffer, and renderer don't care what OS they're
running on. The Windows-specific work is confined to `PlatformIO` and the
signal-equivalent layer. The bad news: Windows console programming is its own world with
its own footguns, and "confined to one file" is still a meaningful amount of work.

#### The strategic decision: VT mode everywhere

> [!note] Ratatui References
>
> - Ratatui's `CrosstermBackend` (`ratatui-crossterm/src/lib.rs`, line 160) wraps a
>   `Write` and delegates all terminal manipulation to crossterm, which internally selects
>   between ANSI (VT) output and `winapi` fallback on Windows.
> - The `ScrollUpInRegion` and `ScrollDownInRegion` commands
>   (`ratatui-crossterm/src/lib.rs`, lines 737, 785) implement `execute_winapi` returning
>   `Unsupported` — Ratatui explicitly does not support the legacy Windows console API for
>   scrolling, reinforcing the VT-mode-only strategy.
> - `TermionBackend` (`ratatui-termion/src/lib.rs`, line 97) is POSIX-only and provides no
>   Windows path — another signal that the ecosystem treats VT mode as the cross-platform
>   baseline.
> - This aligns with Tessera's decision: require `ENABLE_VIRTUAL_TERMINAL_PROCESSING` on
>   Windows, don't maintain a legacy `INPUT_RECORD` / `WriteConsoleOutput` code path.

Modern Windows (10 build 1809+ and all of 11) supports ANSI escape sequences natively when
you enable two console mode flags: `ENABLE_VIRTUAL_TERMINAL_PROCESSING` on the output
handle and `ENABLE_VIRTUAL_TERMINAL_INPUT` on the input handle. Once enabled, the terminal
behaves much like a POSIX terminal: your encoder's bytes are interpreted correctly, and
stdin delivers ANSI sequences for arrow keys, function keys, etc.

This is the load-bearing strategic call for Windows: **require VT mode, don't fall back to
legacy console APIs.** The alternative — `INPUT_RECORD` events from `ReadConsoleInput`,
`WriteConsoleOutput` for rendering, separate code paths for input parsing — would roughly
double the size of `TesseraTerminal` and have you maintaining two different input parsers
forever. The minimum-Windows-version cost (Windows 10 1809, October 2018) is acceptable;
anyone running anything older is outside Tessera's target audience.

The practical consequence: **slices 2, 4, and 5 work on Windows unchanged.** No
conditional code in the encoder, renderer, or parser. The whole Windows port lives in
`PlatformIO` and the cleanup machinery.

#### The three problems this slice solves

1. **Mode setup is different.** Windows has no `termios`; it has `GetConsoleMode` /
   `SetConsoleMode` with a set of bit flags. The flags-to-set and flags-to-clear differ
   from POSIX, and you do them on two separate handles (input and output).

2. **There are no signals.** Windows has `SetConsoleCtrlHandler`, which catches Ctrl-C /
   Ctrl-Break / window close / logoff / shutdown. The lifecycle is different: handlers run
   on a dedicated thread, not in the interrupted thread's context, and the process is
   given a short window to clean up before being killed.

3. **No `poll` or `select` on stdin.** Windows uses `WaitForSingleObject` (or
   `WaitForMultipleObjects`) on console handles. The async-input pattern from slice 3
   needs to be rebuilt against this primitive. The shape is similar — wait with a timeout,
   read available bytes, yield — but the API is foreign.

#### The Windows `PlatformIO`

> [!note] Ratatui References
>
> - The `Backend` trait (`ratatui-core/src/backend.rs`, line 157) defines the platform
>   abstraction: `draw`, `clear`, `size`, `window_size`, `flush`, cursor manipulation.
>   Tessera's `PlatformIO` mirrors this split — one trait/actor with platform-specific
>   implementations behind `#if os(Windows)`.
> - `CrosstermBackend` (`ratatui-crossterm/src/lib.rs`, line 160, `Backend` impl at
>   line 226) shows the pattern: wrap a writer, implement `Backend` methods by queuing
>   crossterm commands. On Windows, crossterm's `Command::execute_winapi` is the fallback;
>   with VT mode enabled, `write_ansi` is used instead.
> - `TermionBackend` (`ratatui-termion/src/lib.rs`, line 97, `Backend` impl at line 162)
>   is Unix-only — its `size()` at line 259 uses `termion::terminal_size()` which maps to
>   `TIOCGWINSZ`. The contrast with Windows' `GetConsoleScreenBufferInfo` is instructive.
> - `TestBackend` (`ratatui-core/src/backend/test.rs`, line 32) renders to an in-memory
>   `Buffer` and provides `resize()` (line 138) and `assert_buffer_lines()` (line 199) —
>   the model for Tessera's platform-independent encoder/parser tests.
> - `WindowSize` struct (`ratatui-core/src/backend.rs`, line 139) carries both character
>   dimensions (`columns_rows: Size`) and pixel dimensions — Tessera's `TerminalSize` is
>   the character-only equivalent.

The public API stays identical to slice 3's POSIX version. The whole point of the
abstraction is that callers don't know which platform they're on:

```swift
public actor PlatformIO {
    public init() throws
    public func write(_ bytes: [UInt8]) async throws
    public func flush() async throws
    public nonisolated var bytes: AsyncStream<UInt8> { get }
    public func size() async throws -> TerminalSize
    public var sizeChanges: AsyncStream<TerminalSize> { get }
    internal func enableRawMode() async throws
    internal func disableRawMode() async throws
}
```

Inside, the file splits by platform:

```swift
#if os(Windows)
import WinSDK
// Windows implementation
#else
import Darwin  // or Glibc
// POSIX implementation
#endif
```

Two parallel implementations behind one public surface. The duplication is acceptable
because each is small (~300 LOC) and the platform-specific concerns don't share much.

##### Mode setup on Windows

The Windows equivalent of "raw mode + alt screen" is a flag dance on two handles:

```swift
// Input handle (GetStdHandle(STD_INPUT_HANDLE))
//   Disable: ENABLE_ECHO_INPUT, ENABLE_LINE_INPUT, ENABLE_PROCESSED_INPUT
//   Enable:  ENABLE_VIRTUAL_TERMINAL_INPUT, ENABLE_WINDOW_INPUT
//
// Output handle (GetStdHandle(STD_OUTPUT_HANDLE))
//   Enable:  ENABLE_VIRTUAL_TERMINAL_PROCESSING,
//            DISABLE_NEWLINE_AUTO_RETURN,
//            ENABLE_PROCESSED_OUTPUT
```

A few notes worth pinning down:

- **`ENABLE_WINDOW_INPUT` is how you get resize events on Windows.** With it set, the
  input stream yields `WINDOW_BUFFER_SIZE_EVENT` records when the console resizes. We
  translate those into `TerminalSize` and yield to `sizeChanges`.
- **`DISABLE_NEWLINE_AUTO_RETURN` matters more than it sounds.** Without it, Windows
  secretly turns `\n` at the right margin into `\r\n` and _suppresses scrolling_ in some
  cases — exactly the kind of subtle alteration that breaks a renderer designed against
  POSIX byte semantics.
- **Save the original flags before modifying.** Same teardown discipline as POSIX: `init`
  captures the pre-existing modes, `disableRawMode` restores them. Stored in the cleanup
  registry for emergency exit.
- **Alt screen still uses `\e[?1049h` / `\e[?1049l`**, because with
  `ENABLE_VIRTUAL_TERMINAL_PROCESSING` set, the Windows console interprets those sequences
  correctly. This is the payoff of the VT-mode strategy.

##### The input read loop on Windows

The Windows equivalent of slice 3's `poll` loop:

```swift
private func inputLoop() async {
    let handle = GetStdHandle(STD_INPUT_HANDLE)
    var buffer = [UInt8](repeating: 0, count: 256)

    while !Task.isCancelled {
        let result = WaitForSingleObject(handle, 100)  // 100ms timeout

        switch result {
        case WAIT_OBJECT_0:
            // Data available — but it might be a non-character event
            // (window resize, focus, mouse) that we need to filter.
            // With ENABLE_VIRTUAL_TERMINAL_INPUT, key events arrive as
            // bytes via ReadFile, but resize events still arrive as
            // INPUT_RECORDs and need PeekConsoleInput / ReadConsoleInput.
            handleAvailableInput(handle, into: &buffer)

        case WAIT_TIMEOUT:
            continue  // loop, check cancellation

        default:
            break  // error
        }
    }
}
```

The wrinkle: even with `ENABLE_VIRTUAL_TERMINAL_INPUT`, **resize and focus events don't
come through as escape sequences in the byte stream.** They arrive as `INPUT_RECORD`s that
you have to drain via `ReadConsoleInput`. The handle is "signaled" when _any_ event is
available, character or otherwise.

The standard pattern is:

1. `PeekConsoleInput` to see what events are queued.
2. For each event: if it's a key event, leave it for `ReadFile` to deliver as bytes. If
   it's a resize or focus event, consume it with `ReadConsoleInput` and yield to the
   appropriate stream.
3. Then call `ReadFile` to drain pending character bytes.

This is more contorted than POSIX. It works, it's well-documented, and Microsoft's own
`conhost` source confirms this is the intended pattern — but it's the one part of slice 6
most likely to have subtle bugs.

##### Output writes on Windows

Comparatively easy. `WriteFile` on `STD_OUTPUT_HANDLE` with the byte buffer. With
`ENABLE_VIRTUAL_TERMINAL_PROCESSING` set, the bytes are interpreted as ANSI sequences.
Same buffered-write + `flush` pattern as POSIX.

One Windows-specific subtlety: `WriteFile` to a console can do partial writes in extremely
large buffers. Loop until the whole buffer is consumed. POSIX has the same issue but it's
rarely hit in practice; on Windows it's more common.

##### Terminal size on Windows

`GetConsoleScreenBufferInfo` returns a struct with the window rect. The visible size is
`srWindow.Right - srWindow.Left + 1` by `srWindow.Bottom - srWindow.Top + 1`. (Not
`dwSize`, which is the scrollback buffer size — a classic confusion.)

For `sizeChanges`, the `WINDOW_BUFFER_SIZE_EVENT` from `ReadConsoleInput` includes the new
size directly. No need to re-query.

#### Signal-equivalent handling on Windows

> [!note] Ratatui References
>
> - The `init` module (`ratatui/src/init.rs`) installs a panic hook via `set_panic_hook()`
>   (line 566) that calls `restore()` before re-invoking the original hook. This is the
>   Ratatui equivalent of Tessera's cleanup registry: ensure terminal state is restored on
>   any exit path.
> - `try_restore()` (`ratatui/src/init.rs`, lines 554–560) performs `disable_raw_mode()`
>   then `LeaveAlternateScreen` — the teardown order. On Windows, Tessera's
>   `tesseraCtrlHandler` does the analogous work: `SetConsoleMode` restore + teardown
>   bytes via `WriteFile`.
> - `try_init()` (`ratatui/src/init.rs`, lines 397–404) shows the setup order:
>   `set_panic_hook` → `enable_raw_mode` → `EnterAlternateScreen` → backend → `Terminal`.
>   Tessera's `PlatformIO.init` follows the same discipline: register cleanup before
>   modifying terminal state.
> - Windows `SetConsoleCtrlHandler` runs on a dedicated thread (not the interrupted
>   thread), which is simpler than POSIX signal handlers where async-signal-safety
>   constraints apply. Ratatui avoids this complexity entirely by delegating to
>   crossterm's platform layer.

Windows has `SetConsoleCtrlHandler`, which lets you register a callback for these events:

- `CTRL_C_EVENT` — user pressed Ctrl-C (sort of equivalent to SIGINT)
- `CTRL_BREAK_EVENT` — user pressed Ctrl-Break (SIGQUIT-ish)
- `CTRL_CLOSE_EVENT` — user clicked the window close button (SIGHUP-ish)
- `CTRL_LOGOFF_EVENT` — user logging off (service processes only)
- `CTRL_SHUTDOWN_EVENT` — system shutting down (service processes only)

The handler is called on a dedicated thread spun up by the system, with the process given
approximately **5 seconds** to return before being killed (the close event window is even
tighter — about 5 seconds, but the OS UI may force the issue sooner).

The Tessera handler does the same minimal work as the POSIX signal handler: read the
cleanup registry's saved console modes, restore them via `SetConsoleMode`, write the
teardown bytes via `WriteFile`. Then return `FALSE` from the handler, which lets the
default behavior proceed (terminating the process).

```swift
internal func tesseraCtrlHandler(_ ctrlType: DWORD) -> WindowsBool {
    switch ctrlType {
    case DWORD(CTRL_C_EVENT), DWORD(CTRL_BREAK_EVENT), DWORD(CTRL_CLOSE_EVENT):
        CleanupRegistry.performEmergencyCleanup()
        return false  // let default handler proceed (process termination)
    default:
        return false
    }
}
```

Two design notes:

- **The handler runs in a separate thread, not in the main thread's context.** This is
  different from POSIX (where signal handlers interrupt the current thread) but actually
  _simpler_ — you don't need to worry about async-signal-safety in the same way, because
  you're not interrupting anything. You still need to be careful about touching shared
  state, but standard locks work; you're not banned from allocating, for example. This is
  a small but real ergonomic improvement.
- **Return `FALSE` so the default handler proceeds.** Returning `TRUE` would mark the
  event as handled and prevent termination, which sounds appealing but means Ctrl-C
  silently does nothing — usually not what users expect. Let the process die; our job was
  to clean up first.

##### What about `atexit`?

Windows has `atexit`, and it works the same way. Use it as the layer-3 backstop, identical
pattern to POSIX.

##### What about catastrophic exit?

A `TerminateProcess` (analogous to `kill -9`) bypasses all handlers on Windows just like
POSIX. The `tessera-reset` executable still applies — it emits the universal
terminal-reset bytes, which work on any VT-capable Windows console. The escape hatch is
identical.

#### The cleanup registry, generalized

> [!note] Ratatui References
>
> - Ratatui's cleanup is orchestrated by `restore()` (`ratatui/src/init.rs`, lines
>   524–532) and `try_restore()` (lines 554–560), which call `disable_raw_mode()` followed
>   by `LeaveAlternateScreen`. The panic hook (`set_panic_hook`, line 566) wraps
>   `restore()` to cover the panic path.
> - Tessera's `CleanupRegistry` is the Swift analog: a single atomic reference holding
>   `CleanupState` (platform-specific saved modes), with `performEmergencyCleanup` as the
>   restore function. The `#if os(Windows)` conditional in `CleanupState` parallels how
>   crossterm internally branches between `termios` restore on POSIX and `SetConsoleMode`
>   restore on Windows.
> - The `DefaultTerminal` type alias (`ratatui/src/init.rs`, line 213) binds
>   `Terminal<CrosstermBackend<Stdout>>` — a single concrete type that works on all
>   platforms because crossterm handles the platform divergence internally. Tessera
>   achieves the same with `PlatformIO`'s `#if os(Windows)` split.

Slice 3 introduced `CleanupRegistry` with a POSIX-shaped `CleanupState` holding `termios`.
Slice 6 generalizes it:

```swift
internal struct CleanupState {
    let teardownBytes: [UInt8]

    #if os(Windows)
    let savedInputMode: DWORD
    let savedOutputMode: DWORD
    let inputHandle: HANDLE
    let outputHandle: HANDLE
    #else
    let savedTermios: termios
    let fd: Int32
    #endif
}
```

The `performEmergencyCleanup` function branches on platform internally. The rest of the
registry — the atomic reference, install/clear API, the contract that it only writes
pre-computed bytes — stays identical.

This is the one place in `TesseraTerminal` with non-trivial conditional code. Keeping it
walled off in one file means the rest of the library stays platform-clean.

#### A note on PowerShell, conhost, and Windows Terminal

Three contexts to know about:

- **Windows Terminal** (the modern app): excellent VT support, no quirks, the target
  environment.
- **`conhost.exe`** (the legacy console window): VT support with
  `ENABLE_VIRTUAL_TERMINAL_PROCESSING` on Windows 10 1809+, but with some minor SGR
  rendering quirks. Works fine for Tessera.
- **PowerShell ISE**: not a real console. Doesn't support raw mode, won't work. Detect via
  `GetConsoleMode` failing and throw a clear error: "Tessera requires a console terminal;
  PowerShell ISE is not supported. Use Windows Terminal or PowerShell in a normal
  console."

The detection-and-clear-error pattern is the right move for any unsupported environment
(mintty in legacy mode, very old conhost, redirected stdin/stdout to a pipe). Tessera
should fail fast and explain rather than silently misbehave.

#### CI and the snapshot harness on Windows

Two things to set up:

1. **Windows in the GitHub Actions matrix** is finally not skipped. The `swift build` /
   `swift test` jobs run on `windows-latest`, and `TesseraTerminalTests` + `TesseraTests`
   execute normally. This validates the encoder, parser, buffer, renderer, and
   `PlatformIO` mode logic on Windows.

2. **`TesseraSnapshotTests` remains macOS-only** because libghostty-spm is Apple-only.
   Windows snapshot coverage waits until either (a) libghostty-vt gets a Windows binary
   distribution, or (b) we add the Linux/Windows from-source build path tracked from
   earlier. Cross-platform correctness for now is inferred from the encoder unit tests
   (which run identically on all platforms) plus macOS snapshot coverage.

This is the same compromise as the Linux situation, and the same reasoning applies: byte
streams are platform-independent, so macOS snapshot tests prove the _encoding_ is right;
the platform-specific code in `PlatformIO` is small, well-isolated, and verified by its
own targeted tests on each platform.

#### Testing strategy for slice 6

The asymmetry: most of `TesseraTerminal`'s tests are platform-independent and just need to
_also_ run on Windows. The Windows-specific work has a smaller, more focused test set:

- **`PlatformIO` mode tests on Windows.** Verify `enableRawMode` sets the right flags and
  `disableRawMode` restores them. Use a mock console handle if possible; otherwise
  integration-test against the real console with careful save/restore.
- **Resize event translation test.** Inject a `WINDOW_BUFFER_SIZE_EVENT` (or, more
  realistically, structure the code so the event-translation function is unit-testable in
  isolation) and assert it yields a correct `TerminalSize`.
- **Ctrl handler installation test.** Verify `SetConsoleCtrlHandler` is called during
  `init` and removed on teardown. Behavior of the handler itself is manual-verification
  territory, like the POSIX signal handler.
- **The full Phase 1+2 walking skeleton on Windows.** Run it manually in Windows Terminal,
  in conhost, and in a PowerShell console. Verify: arrow keys work, q exits cleanly,
  Ctrl-C restores the terminal, resizing the window updates the layout. Same manual
  procedure documented in `CONTRIBUTING.md` as for POSIX.

Roughly 15-25 Windows-specific tests, plus the existing platform-independent tests now
running on the Windows matrix entry.

#### Definition of done for slice 6

1. `PlatformIO` has a complete Windows implementation behind `#if os(Windows)`, with the
   same public API as POSIX.
2. Console mode setup using `GetConsoleMode` / `SetConsoleMode` with the documented flag
   combinations on the input and output handles.
3. Async input loop using `WaitForSingleObject` + `ReadConsoleInput` + `ReadFile`,
   draining non-character events (resize, focus) and yielding character bytes through the
   same `AsyncStream<UInt8>`.
4. `WINDOW_BUFFER_SIZE_EVENT` translation into `sizeChanges` stream.
5. `SetConsoleCtrlHandler` installed for `CTRL_C_EVENT`, `CTRL_BREAK_EVENT`,
   `CTRL_CLOSE_EVENT`. Handler restores console modes and writes teardown bytes via the
   cleanup registry.
6. `CleanupRegistry` generalized to hold either POSIX or Windows state, with
   platform-specific `performEmergencyCleanup`.
7. `atexit` backstop installed on Windows (same pattern as POSIX).
8. `tessera-reset` builds and runs on Windows, emitting the universal reset bytes.
9. Fail-fast detection for unsupported environments (ISE, redirected I/O, very old
   Windows): `PlatformIO.init` throws a clear error explaining the requirement.
10. GitHub Actions matrix runs the test suite on `windows-latest`; snapshot tests skipped
    on Windows with an explicit comment.
11. Manual verification on Windows Terminal and conhost: walking skeleton works, Ctrl-C
    restores cleanly, resize works, exit is clean.
12. ~15-25 Windows-specific unit tests for the mode-setting and event-translation logic.

#### What's not in this slice

- **Windows snapshot test coverage.** Tracked as a separate issue; depends on
  libghostty-vt Windows distribution or from-source build path.
- **Legacy console (`conhost` pre-1809) support.** Out of scope; we require modern
  Windows.
- **WSL-specific behavior.** WSL terminals are POSIX from Tessera's point of view — they
  run Linux Swift, talk to a Linux PTY. No special handling needed; works through the
  POSIX path.
- **Windows-specific ANSI quirks.** Some sequences behave subtly differently on conhost
  vs. Windows Terminal (e.g., certain OSC sequences). For Phase 2, we don't paper over
  these; if a user reports a specific issue, it gets a targeted workaround in Phase 5
  polish.
- **`STD_ERROR_HANDLE` handling.** Tessera writes to stdout; stderr is the application's
  concern.
- **Cygwin / MSYS2 terminals.** They emulate POSIX badly and inconsistently; not
  supported. Users in those environments should use Windows Terminal directly.

#### Three things to flag

1. **Requiring Windows 10 1809+ is a real but defensible cost.** It's been seven years;
   corporate environments may still have Windows 10 LTSC versions without it, but those
   users are already constrained in many other ways. A clearer-error-than-segfault on
   older Windows ("Tessera requires Windows 10 version 1809 or newer for VT support") is
   the right move. Worth documenting prominently.

2. **The `INPUT_RECORD` event filtering inside the read loop is the most subtle code in
   slice 6.** Specifically: when the input handle is signaled, you don't always want to
   call `ReadFile` — sometimes the only queued event is a non-character event, and
   `ReadFile` would block waiting for actual characters. The `PeekConsoleInput` +
   selective drain pattern handles this correctly but is easy to get subtly wrong. Worth
   writing carefully and commenting heavily; future-you will not remember why this loop is
   shaped the way it is.

3. **The "two parallel implementations behind one public API" structure** is the right
   call for slice 6 but it does increase the project's surface area meaningfully. From
   here forward, every change to `PlatformIO`'s public API needs to be implemented twice.
   The duplication is bounded (~300 LOC per side) and the platforms diverge fundamentally
   enough that _attempting_ to unify them would be worse — but worth being explicit that
   this is the project's cross-platform tax, paid in one specific place.

---

That's slice 6, and with it Phase 2 is complete. `TesseraTerminal` is now a
publishable-as-alpha cross-platform terminal foundation: cell-accurate buffer,
damage-tracking renderer, full legacy input parser, robust teardown discipline, and
demonstrable parity across macOS, Linux, and Windows.

Phase 3 (modern terminal protocols) is the next phase. Ready to start it, or pause here
for retrospective on Phase 2?

### End of Phase 2

Publishable-as-alpha TesseraTerminal. You can write a program that renders text in any
style, handles standard keyboard input, runs on macOS/Linux/Windows, and recovers cleanly
from any exit.

---

## Phase 3: Modern terminal protocols (bracketed paste, focus events, SGR mouse, Kitty keyboard, OSC 8)

A single phase, probably 4-5 slices, each adding one modern protocol layer to
`TesseraTerminal`. None of these change existing APIs; they extend the encoder, parser,
and lifecycle.

- Bracketed paste mode (distinguishing typed input from pasted text)
- Focus events (terminal-gained-focus / terminal-lost-focus)
- SGR mouse tracking (clicks, drags, scroll, with modifier keys)
- Kitty keyboard protocol (disambiguated keys, all-modifier reporting)
- OSC 8 hyperlinks
- Possibly: terminal capability detection (DA1, XTGETTCAP) so views can adapt

**End of Phase 3:** `TesseraTerminal` is feature-complete for a modern terminal app.
Everything above this is the view library.

## Phase 4 — View layer (the `Tessera` module)

This is the largest phase and where the Lip Gloss-flavored API actually shows up. Likely
5-7 slices.

- `View` protocol + the rendering pipeline (view → buffer)
- Style values (`Style.bold.foreground(.red).padding(2)` chains)
- Built-in primitive views (`Text`, `Spacer`, `Box`, `Divider`)
- Layout primitives (`HStack`, `VStack`, `ZStack`, `Join`, `Place`, `Compose`)
- Borders, padding, alignment
- Focus management (which view receives keyboard input)
- A small standard widget set (text input, list, scroll view) — the Tessera analog of
  `bubbles`

**End of Phase 4:** the library does what it says on the tin. You can build real TUI apps.

## Phase 5 — Runtime + polish

- The immediate-mode API (Ratatui-shaped: you own the loop, call `terminal.draw { … }`)
- The optional convenience loop (Bubble Tea-shaped: model/update/view, for users who want
  it)
- Example apps (counter, file browser, chat client, etc. — these double as integration
  tests)
- DocC tutorial content
- Performance pass (profiling, capacity reservation, the `@inlinable` work, etc.)
- Linux snapshot-test story (libghostty from source, or the static-build path if #11730
  lands)
- 1.0 release prep

**End of Phase 5:** Tessera 1.0.
