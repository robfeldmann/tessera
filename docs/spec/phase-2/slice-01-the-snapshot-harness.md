---
type: spec
description: "Slice 1: The snapshot harness"
---

# Slice 1: The snapshot harness

## Why this is first

By the end of Phase 1 you have a naive renderer emitting raw bytes you wrote by hand.
You're about to evolve that into a damage-tracking renderer that emits _minimal_ bytes —
exactly the situation where regression risk is highest. Unit tests on the buffer don't
catch encoder bugs. Unit tests on the encoder catch individual-sequence bugs but not "the
renderer emitted a sequence of correct sequences that interact badly." Snapshot tests
catch all of these by feeding the bytes through a real VT and asserting on the resulting
screen state.

Building the harness first means **every renderer change in Phase 2 lands with a screen
snapshot or focused screen assertion**. That's the discipline the original spec was
reaching for, and it's right — it was just mis-scheduled into Phase 0.

## Testing strategy: libghostty-vt for rendering tests

Tessera's renderer contract is not "emit this exact byte sequence." Its contract is "emit
bytes that a terminal interprets into the intended screen." Many byte streams can be
visually equivalent: redundant SGR resets, different cursor paths, or a later
minimal-damage renderer replacing a naive full repaint. Renderer tests that assert only on
raw bytes are brittle because they lock in _how_ Tessera draws rather than _what_ the user
sees.

The harness closes the loop with Ghostty's standalone VT library:

```text
Buffer/view intent → Tessera renderer → terminal bytes → libghostty-vt → screen state
```

`libghostty-vt` parses terminal bytes and maintains terminal state: visible cells, styles,
cursor position, modes, scrollback, and render-state metadata. Tessera encodes intent into
bytes; Ghostty independently decodes those bytes into a screen. Agreement between the
expected screen and Ghostty's reconstructed screen is strong evidence that Tessera's
output is correct for the behavior being tested.

Phrase the role carefully: Ghostty is not a proof that every terminal in existence will
behave identically in every edge case. It is a high-quality, shipping terminal parser and
a much better reference than byte equality for screen-level behavior.

This strategy applies only to **output**. Input parsing is the opposite direction — bytes
from the terminal to Tessera events — and remains plain byte-in/event-out tests for
`InputParser`.

Raw byte tests still have a place. The ANSI encoder should have exact byte tests for
small, scalar API behavior:

```text
ControlSequence → ANSIEncoder → exact bytes
```

Renderer and view tests should prefer Ghostty-backed screen assertions unless the test is
specifically about the byte-level encoder contract.

## Harness shape and package boundaries

The durable Swift API is `VirtualTerminal`, not `GhosttyScreen` or another Ghostty-named
public type. Ghostty is an implementation detail behind a test-support boundary:

```text
TesseraTerminalRenderingTests
  └─ TesseraTerminalSnapshotSupport
       └─ VirtualTerminal
            └─ CGhosttyVT
                 └─ libghostty-vt
```

`Tessera` and `TesseraTerminal` must not re-export the harness. App authors should never
see `VirtualTerminal` from normal imports. The target may use `public` Swift access
control because tests and helper targets need to import it, but it remains test/support
API unless a deliberate `TesseraTerminalSnapshotSupport` product is added later for
downstream test authors.

The harness API should stay small, but separate **how tests request a terminal** from the
**mutable terminal session** itself.

Model the seam as a plain struct of `@Sendable` endpoint closures. This support module is
test-only and is never re-exported, so it needs no dependency-injection framework: tests
construct a terminal directly through a factory. Keep the endpoint closures public, with
`unimplemented` defaults so an unexpected call reports an issue:

```swift
import IssueReporting

public struct VirtualTerminal: Sendable {
    public var feed: @Sendable ([UInt8]) -> Void
    public var text: @Sendable (Int) -> String
    public var cell: @Sendable (_ row: Int, _ column: Int) -> RenderedCell
    public var cursor: @Sendable () -> TerminalPosition
    public var snapshot: @Sendable () -> ScreenSnapshot

    public init(
        feed: @escaping @Sendable ([UInt8]) -> Void =
            unimplemented("VirtualTerminal.feed"),
        text: @escaping @Sendable (Int) -> String =
            unimplemented("VirtualTerminal.text", placeholder: ""),
        cell: @escaping @Sendable (_ row: Int, _ column: Int) -> RenderedCell =
            unimplemented("VirtualTerminal.cell", placeholder: .blank),
        cursor: @escaping @Sendable () -> TerminalPosition =
            unimplemented("VirtualTerminal.cursor", placeholder: .zero),
        snapshot: @escaping @Sendable () -> ScreenSnapshot =
            unimplemented("VirtualTerminal.snapshot", placeholder: .empty)
    )
}
```

A factory builds a Ghostty-backed terminal at the requested size, falling back to a
loudly-`unimplemented` terminal on platforms without libghostty-vt:

```swift
extension VirtualTerminal {
    public static func ghosttyOrPlatformUnsupported(cols: Int, rows: Int) -> Self {
        #if os(Windows)
            platformUnsupported
        #else
            ghostty(cols: cols, rows: rows)
        #endif
    }
}
```

Each test constructs the size it needs and skips where the backing is unavailable:

```swift
@Test(
    .disabled(
        if: VirtualTerminal.isPlatformUnsupported,
        "Windows snapshot coverage is deferred until libghostty-vt builds on Windows.")
)
func `text writes into cells`() {
    let terminal = VirtualTerminal.ghosttyOrPlatformUnsupported(cols: 5, rows: 2)
    terminal.feed("Hello")
    #expect(terminal.text(row: 0) == "Hello")
}
```

The screen-state values remain plain data:

```swift
public struct RenderedCell: Sendable, Equatable {
    public let character: Character
    public let foreground: RenderedColor
    public let background: RenderedColor
    public let bold, italic, underline, reverse: Bool
}

public enum RenderedColor: Sendable, Equatable {
    case `default`
    case indexed(UInt8)
    case rgb(UInt8, UInt8, UInt8)
}

public struct ScreenSnapshot: Sendable, Equatable {
    public let cells: [[RenderedCell]]
    public let cursor: TerminalPosition
}
```

That is the whole API tests need. Whatever C interop or build machinery sits behind it
should remain private to `TesseraTerminalSnapshotSupport`.

## Direct libghostty-vt integration, not GhosttyKit

The Phase 2 Slice 1 spike validated two approaches:

1. Existing SwiftPM wrappers such as `libghostty-spm` / `GhosttyKit`.
2. A direct `libghostty-vt` build owned by Tessera.

Use the direct `libghostty-vt` path.

The existing wrappers package the broader Ghostty app/surface embedding API and Apple
binary artifacts. That API can write bytes and read viewport text, but it pulls in
surface/rendering/platform concerns that are unnecessary for a headless test harness. The
harness needs the standalone VT API instead:

- `ghostty_terminal_new`
- `ghostty_terminal_resize`
- `ghostty_terminal_vt_write`
- `ghostty_render_state_update`
- render-state row/cell iteration
- cell graphemes, style flags, resolved colors, and cursor data

A tiny `CGhosttyVT` system-library-style module should expose the C headers to Swift.
Tessera can then implement `VirtualTerminal` in Swift on top of those C calls.

`libghostty-vt` is cross-platform in principle. Platform support for Tessera's snapshot
tests should be based on the actual build path we wire into CI, not on SwiftPM's
`platforms` array and not on assumptions from Apple-only wrapper packages. This slice must
make the Ghostty harness work on both macOS and Linux. Windows snapshot coverage can wait
until Phase 2 Slice 6 or until the libghostty-vt build path is proven there.

## Concurrency model

Treat a `VirtualTerminal` instance as isolated mutable terminal state. Do not share one
Ghostty terminal handle across concurrent tests or tasks.

Preferred design:

- Keep `VirtualTerminal` synchronous and non-`Sendable` if Swift accepts the usage.
- Keep `VirtualTerminal` as a stateless dependency/factory; do not store a shared Ghostty
  handle in the dependency value.
- If isolation becomes necessary, wrap each Ghostty handle in an actor or provide an
  actor-backed test helper.
- Avoid `@unchecked Sendable` unless there is a documented invariant proving the handle is
  never used concurrently.

Swift Testing may run tests in parallel, but each test should create and own its own
`VirtualTerminal`. That is enough isolation for the normal harness use case.

## Snapshot representations

A terminal screen is a 2D text grid, which makes it unusually well suited to text
snapshots. Use multiple readable representations rather than one giant dump for every
test:

| Strategy    | Captures                                | Use for                               |
| ----------- | --------------------------------------- | ------------------------------------- |
| text grid   | characters only                         | layout and everyday renderer behavior |
| styled grid | characters + parallel style glyph grid  | color/bold/underline behavior         |
| debug dump  | cells, cursor, modes, selected metadata | complex failures and diagnostics      |

The text-grid strategy should have an explicit whitespace policy:

```swift
.terminalText(trim: .trailing)
.terminalText(trim: .none)
```

Trailing trim is friendlier for layout snapshots. Exact rows are better when spaces are
semantically important.

A styled-grid snapshot should keep character and attribute positions aligned, for example:

```text
── chars ──
OK
── style ──
GG....
```

where `G` could mean green + bold and `.` means default. For precise style checks, prefer
focused scalar assertions against `cell(row:column:)`.

Snapshot helpers belong in `TesseraTerminalTestSupport`, not ad hoc test files, when they
are likely to be reused.

## Example test shapes

Harness smoke tests should land before renderer integration tests. They prove the harness
itself works without depending on Tessera rendering code:

```swift
@Test
func `plain text lands on row zero`() {
    let terminal = VirtualTerminal(cols: 80, rows: 24)

    terminal.feed("Hello, Tessera!")

    #expect(terminal.text(row: 0) == "Hello, Tessera!")
}

@Test
func `cursor movement is reflected in inspected cells`() {
    let terminal = VirtualTerminal(cols: 80, rows: 24)

    terminal.feed("\u{1B}[3;5HX")

    #expect(terminal.cell(row: 2, column: 4).character == "X")
}

@Test
func `sgr style is reflected in inspected cells`() {
    let terminal = VirtualTerminal(cols: 8, rows: 2)

    terminal.feed("\u{1B}[1;4;38;5;196;48;2;1;2;3mXY")
    let x = terminal.cell(row: 0, column: 0)

    #expect(x.character == "X")
    #expect(x.bold)
    #expect(x.underline)
    #expect(x.foreground == .indexed(196))
    #expect(x.background == .rgb(1, 2, 3))
}
```

Renderer tests then feed real Tessera output through the same harness:

```swift
@Test
func `renderer output can be inspected as terminal state`() {
    var buffer = Buffer(size: TerminalSize(columns: 4, rows: 2))
    buffer.write("Hi", at: TerminalPosition(column: 1, row: 0))
    buffer.write("q", at: TerminalPosition(column: 3, row: 1))

    let terminal = VirtualTerminal(cols: 4, rows: 2)
    terminal.feed(Renderer.render(buffer))

    #expect(terminal.text(row: 0) == " Hi ")
    #expect(terminal.text(row: 1) == "   q")
}
```

The key Phase 2 damage-tracking test compares screens, not bytes:

```swift
@Test
func `damage tracking is visually identical to a full repaint`() {
    let full = VirtualTerminal(cols: 10, rows: 1)
    full.feed(Renderer.renderFull(frame2))

    let diffed = VirtualTerminal(cols: 10, rows: 1)
    diffed.feed(Renderer.renderFull(frame1))
    diffed.feed(Renderer.renderDiff(previous: frame1, current: frame2))

    #expect(diffed.snapshot() == full.snapshot())
}
```

The two byte streams are deliberately different. The final screen snapshots must be the
same. This is the correctness property that justifies the test.

## Build order for this slice

1. Add the direct `libghostty-vt` build/link path and `CGhosttyVT` module boundary for
   macOS and Linux.
2. Add `VirtualTerminal` as a closure-based factory seam, with a Ghostty live
   implementation.
3. Replace the `VirtualTerminal` placeholder with the durable per-terminal inspection API.
4. Add harness smoke tests: text, cursor movement, erase behavior, SGR style/color.
5. Add reusable text/styled/debug snapshot strategies in `TesseraTerminalTestSupport`.
6. Add one renderer integration test: Phase 1 renderer bytes → `VirtualTerminal` →
   asserted screen state.
7. Keep encoder byte tests separate for exact `ControlSequence` output.
8. Prove the harness in local/CI macOS and Linux test runs; document Windows as future
   work unless it is also proven.

## Definition of done for the snapshot harness

1. `CGhosttyVT` or equivalent C module exposes the direct `libghostty-vt` API to Swift.
2. The direct `libghostty-vt` build path is documented, scripted, and validated on macOS
   and Linux.
3. `VirtualTerminal` exists as a macro-free closure-based client with a Ghostty live
   implementation.
4. `VirtualTerminal`, `RenderedCell`, `RenderedColor`, and `ScreenSnapshot` exist in
   `TesseraTerminalSnapshotSupport` and are not exported by `Tessera` or
   `TesseraTerminal`.
5. Harness smoke tests prove plain text, cursor movement, erase behavior, SGR style/color,
   and cursor inspection.
6. Reusable SnapshotTesting strategies exist for text-grid, styled-grid, and debug output.
7. At least one real renderer integration test feeds Tessera renderer bytes through
   `VirtualTerminal` and asserts the resulting screen.
8. CI runs the harness on macOS and Linux. Windows skips are documented as future work.

---
