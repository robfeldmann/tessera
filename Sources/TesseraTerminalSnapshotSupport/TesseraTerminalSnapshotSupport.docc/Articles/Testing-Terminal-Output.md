# Testing Terminal Output

A renderer emits control bytes, but users see a cursor and a grid of styled cells.
Asserting every emitted byte binds a test to an encoding sequence, ordering choice, or
reset that may change without changing the visible result. Feed that output to a
``VirtualTerminal`` instead, then assert the screen state that is meaningful to the
feature under test.

## Assert the visible result

Create a virtual terminal with a deliberate viewport, feed the bytes or text produced
by the renderer, and inspect one focused cell. The following test checks both the
character and its rendered ANSI color without asserting the particular byte sequence
that produced them.

```swift
import Testing
import TesseraTerminalSnapshotSupport

@Test
func failure_is_rendered_in_red() {
  let terminal = VirtualTerminal.ghosttyOrUnavailable(cols: 20, rows: 2)

  terminal.feed("\u{1B}[31mFAIL\u{1B}[0m")

  #expect(terminal.cell(row: 0, column: 0).character == "F")
  #expect(terminal.cell(row: 0, column: 0).foreground == .indexed(1))
}
```

Use ``VirtualTerminal/text(row:)`` when a row's visible text is the contract. Use
``VirtualTerminal/cell(row:column:)`` when styling, hyperlinks, or an individual
character matters. A test can also make a focused snapshot assertion rather than
matching a serialized terminal payload:

```swift
let screen = terminal.snapshot()
#expect(screen.cells[0][0].character == "F")
#expect(screen.cursor.column == 4)
#expect(screen.cursor.row == 0)
```

``ScreenSnapshot`` contains the visible cell grid and cursor. ``RenderedCell`` and
``RenderedColor`` let tests be as specific as the observable contract requires.
For graphics output, inspect ``VirtualTerminal/kittyImages`` and
``VirtualTerminal/kittyPlacements`` rather than parsing Kitty protocol payloads.

## Choose the Ghostty-backed terminal deliberately

``VirtualTerminal/ghostty(cols:rows:)`` attempts to construct a Ghostty-backed virtual
terminal when `CGhosttyVT` is compiled into the build. If construction fails, it
reports the issue and returns the default virtual terminal. Its `libghostty-vt`
parser reconstructs screen state for tests; it is not evidence that every terminal
emulator will render or interpret the same output in the same way.

``VirtualTerminal/ghosttyOrUnavailable(cols:rows:)`` uses that factory when it is
compiled in and otherwise returns ``VirtualTerminal/ghosttyUnavailable``. The
unavailable factory deliberately fails loudly when its terminal operations are used,
so a test does not silently pass without terminal-state inspection. Check
``VirtualTerminal/isGhosttyUnavailable`` only when a test needs to recognize that
build configuration explicitly.

Ghostty support is present whenever `CGhosttyVT` is compiled. On Windows, that module
is compiled only with the `TESSERA_GHOSTTY_WINDOWS=1` opt-in. Without that opt-in,
``VirtualTerminal/ghosttyOrUnavailable(cols:rows:)`` returns the loudly unavailable
factory.
