# ``TextField``

`TextField` is a controlled, single-line editor. The application owns its
`Binding<String>`; accepted printable input, committed paste, deletion, and selection
replacement write through that binding immediately.

Caret, selection anchor, and horizontal reveal are ephemeral node state. They are clamped
to extended grapheme boundaries whenever the bound value changes, and display-cell
measurement keeps the caret out of combining and wide-grapheme interiors. A primary pointer
click maps the local display cell to a valid grapheme boundary and moves the caret without
writing text. Focused fields request the terminal hardware cursor for the resolved caret; they
do not draw a software cursor or store a shadow text value.

`TextField` accepts committed terminal characters and normalizes paste newlines to spaces.
`onSubmit` receives the current bound value on Enter when supplied. Tab and Escape bubble to
application focus and dismissal policy. Shift movement extends the selected range; printable
input, Backspace, Delete, and committed paste replace selected whole graphemes. Alt word
movement and deletion are supported, while Ctrl word movement is consumed only for Kitty
reports that distinguish the chord. IME pre-edit and secure-entry masking are outside this
contract.

Use `.focusable(_:)` to provide a stable application-owned focus identity:

```swift
TextField(
  "Name",
  text: $name,
  prompt: Text("Required"),
  onSubmit: submit
)
.focusable(FocusID("name"))
```
