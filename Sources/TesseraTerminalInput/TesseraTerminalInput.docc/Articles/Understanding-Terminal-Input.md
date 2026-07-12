# Understanding Terminal Input

``InputParser`` turns an incremental byte stream into a bounded vocabulary of
``InputEvent`` values. It is a parser, not a byte source: supply bytes from the I/O boundary
that your application owns, then handle semantic events rather than interpreting escape
sequences in the rest of the application.

## Feed bytes incrementally

Keep one parser for one continuous input stream. A terminal sequence may be split across
reads, so feed each received chunk to the same value:

```swift
import TesseraTerminalInput

var parser = InputParser()
let chunks: [[UInt8]] = [
  [0x1B, 0x5B],
  [0x41],
]

for chunk in chunks {
  for event in parser.feed(contentsOf: chunk) {
    switch event {
    case .key(let key):
      print(key.code)
    default:
      break
    }
  }
}
```

The first chunk above is the beginning of a CSI sequence and produces no event. The next
byte completes the sequence, producing a key event for the Up Arrow. ``InputParser/feed(_:)``
and ``InputParser/feed(contentsOf:)`` can therefore return an empty array while they retain
just enough state to recognize a later byte.

Escape has an unavoidable ambiguity: a lone Escape byte can be an Escape key or the first
byte of an escape sequence. The parser waits for the next byte rather than emitting a key too
early. When the caller knows that no continuation belongs to the current input, call
``InputParser/flush()``. It emits a pending bare Escape as ``InputEvent/key(_:)`` with
``KeyCode/escape``; other unfinished sequences become ``InputEvent/unknown(_:)``. Choosing
when input has ended or when to resolve that ambiguity belongs to the byte-source owner, not
to this module.

## Recognize modern terminal reports

The parser preserves state across every one of these reports, including when their bytes cross
chunk boundaries:

- **Bracketed paste.** `CSI 200~` starts a paste payload and `CSI 201~` ends it. Bytes between
  the markers become one ``InputEvent/paste(_:)`` value, rather than individual key events.
- **Focus.** Focus-in and focus-out reports become ``InputEvent/focusGained`` and
  ``InputEvent/focusLost``.
- **SGR mouse.** SGR mouse reports become ``InputEvent/mouse(_:)`` values with a
  ``MouseEvent/kind``, ``MouseEvent/position``, and ``MouseEvent/modifiers``.
- **Kitty keyboard.** Kitty keyboard reports produce a ``Key`` with its ``Key/code``,
  ``Key/modifiers``, and ``Key/kind``. When present in a report, the parser also retains the
  Kitty-specific ``Key/shiftedCode``, ``Key/baseLayoutCode``, and ``Key/associatedText``.

These are decoding rules, not a promise that a particular terminal will send a report. The
module does not enable input modes, negotiate keyboard behavior, or perform terminal I/O.

## Handle capability responses as typed events

Some terminal replies are not user input, but they still arrive in the same byte stream.
``InputEvent`` represents the supported responses with typed cases:

- ``InputEvent/primaryDeviceAttributes(_:)`` carries a primary device-attributes response.
- ``InputEvent/kittyKeyboardEnhancementFlags(_:)`` carries the reported Kitty keyboard
  enhancement flags.
- ``InputEvent/privateModeStatus(_:)`` carries a ``PrivateModeStatus``, whose
  ``PrivateModeStatus/state`` is a ``PrivateModeState``.
- ``InputEvent/kittyGraphicsResponse(_:)`` carries a Kitty Graphics Protocol response.

Dispatch these cases alongside keyboard, paste, focus, and mouse input. Bytes that do not form
a recognized event are surfaced as ``InputEvent/unknown(_:)``, allowing the byte-stream owner
to make its own diagnostic or compatibility decision.

## Topics

### Parsing

- ``InputParser``

### Events

- ``InputEvent``
- ``Key``
- ``MouseEvent``
- ``PrivateModeStatus``
