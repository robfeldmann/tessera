---
kind: widget
status: ready
---

# TextField

`TextField` is Tessera's controlled, single-line text-entry widget. It presents an
optional label and prompt while the application owns the `Binding<String>`; each accepted
edit writes that binding immediately. Its only `NodeState` is the caret and selection's
grapheme boundaries plus horizontal reveal position, all disposable and clamped whenever
the app replaces the string. The public API uses `TextField` with no compatibility alias.

The public direction is a string-only field with a label, an optional prompt, an optional
submit closure, the standard/default style, and an environment-applied
`.characterLimit(_:)` (owner decision, 2026-10-10). Custom `TextFieldStyle` is deferred
with Toggle and Button (owner decision, 2026-10-10). [API direction](#api-direction) gives
the initializers, derived from the translation key and catalog precedent. `TextField` is
neither a multiline editor nor secure entry in 1.0.

## Prior art

- Ratatui user-input example:
  `~/Developer/ratatui/ratatui/main/examples/apps/user-input/src/main.rs` -- copy its
  explicit cursor request after rendering and the left/right/backspace/Enter interaction
  vocabulary; reject its app-owned input buffer, character-index model, and explicitly
  unsupported Unicode handling.
- Ratatui Paragraph: `~/Developer/ratatui/ratatui/main/ratatui-widgets/src/paragraph.rs`
  -- copy the no-wrap horizontal-offset rendering shape at lines 420-445 and cell-width
  rendering at lines 461-480; reject its character-count horizontal offset because a
  controlled field must reveal only cluster boundaries and position its caret by display
  cells.
- Apple SwiftUI [`TextField`](https://developer.apple.com/documentation/swiftui/textfield)
  -- copy the label + optional prompt vocabulary, continuous `Binding<String>` updates,
  `onSubmit`, and environment-applied default/custom style direction; reject value/format
  initializers, scrollable-axis text fields, and the platform-specific `Form` presentation
  before 1.0.
- omp2 `Input`
  ([`input.rs`](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/input.rs#L138-L147))
  is the counterpart. Copy its grapheme-safe caret motion and deletion
  ([`edit`](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/input.rs#L203-L343)),
  the horizontal reveal that keeps the caret in view and the real terminal cursor at the
  insertion point instead of a drawn caret
  ([L488-L510](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/input.rs#L488-L510)),
  which is omp2's `beam` (key K3), click-to-caret
  ([L536-L574](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/input.rs#L536-L574)),
  and paste with newlines folded to spaces
  ([L576-L590](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/input.rs#L576-L590)).
  Reject its internal text, cursor, undo stack, and kill ring
  ([L43-L55](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/input.rs#L43-L55)):
  the text is the app's binding (key D1), the caret and reveal are NodeState (key D5), and
  edit history is rejected for 1.0 (key D6). Reject its `Changed` event and value
  harvesting
  ([L393-L402](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/input.rs#L393-L402),
  [L592-L596](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/input.rs#L592-L596)):
  an edit is a binding write (keys C6 and A10). Reject the cursor-glyph prefix and the
  focus rail
  ([L443-L459](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/input.rs#L443-L459)):
  the standard style frames the input, and focus is the heavy set in `focus` (keys E2 and
  K7). Reject the italic placeholder that hides on focus
  ([L482-L487](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/input.rs#L482-L487)):
  the prompt shows whenever the text is empty (key B11). Reject the `mask` flag: secure
  entry is post-1.0 (key M8).
- omp2's `Input` counter
  ([limit](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/input.rs#L196-L201),
  [render](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/input.rs#L511-L518))
  shows the remaining count right-aligned in muted, and a limit counts without capping
  input (key M7). Copy that placement and the non-capping rule; reject its `-N` overage
  and warn role, which the owner replaced with `+N` in `error` (owner decision, omp2
  review, 2026-10).

## API direction

These signatures follow the [translation key](../translation-key.md) and catalog
precedent; the owner adopted them for the Spec (owner decision, 2026-10-21):

```swift
public struct TextField<Label: View>: View {
    public init(
        text: Binding<String>,
        prompt: String? = nil,
        onSubmit: (() -> Void)? = nil,
        @ViewBuilder label: () -> Label
    )
}

extension TextField where Label == Text {
    public init(
        _ title: String,
        text: Binding<String>,
        prompt: String? = nil,
        onSubmit: (() -> Void)? = nil
    )
}

extension View {
    public func characterLimit(_ limit: Int?) -> some View
}

// Deferred with Toggle and Button; outside 1.0 (owner decision, 2026-10-10).
public protocol TextFieldStyle {
    associatedtype Body: View
    @ViewBuilder func makeBody(configuration: TextFieldStyleConfiguration) -> Body
}

extension View {
    public func textFieldStyle(_ style: some TextFieldStyle) -> some View
}
```

- The text is an app-owned `Binding<String>` that every accepted edit writes (keys D1 and
  C6); the field never takes an initial value.
- The label is a `@ViewBuilder label:` with a `String` title convenience, as Toggle and
  Button take theirs (keys A7 and B11).
- The prompt is a plain `String?` (key B11: omp2's `placeholder` is `prompt:`), as
  Callout's optional title and badge are.
- Submit is the optional `onSubmit:` closure, because the control that submits owns it
  (key C3). It is `() -> Void`, following [Button](button.md)'s action, an owner decision
  of 2026-10-10 for Button: the app reads the submitted text from its own binding (owner
  decision, 2026-10-21).
- `.characterLimit(_:)` sets an environment value (key M7).
- There is no `.textFieldStyle(_:)` in 1.0. The standard style is the one built-in look,
  and a closed set of one look has nothing to select (key B12). The `TextFieldStyle`
  protocol and its modifier wait with Toggle's and Button's custom styles.

```swift
// email is a Binding<String> from the app's model.
TextField("Email address", text: email, prompt: "you@example.com", onSubmit: signIn)
    .characterLimit(254)
    .focusable(emailFocusID)
```

Focus stays explicit at the call site: the field joins the focus ring through
`.focusable(_:)` with an app-supplied `FocusID` (keys B10 and E1), reads `isFocused` from
the environment to draw its focus frame (key E2), and handles keys only while focused.

A style receives the label, prompt, text display region, focus/enabled state, and caret
request site; it may change chrome but cannot own text, selection, or submit behavior.
Roles are complete `Style` values, not hard-coded colors: `primary`, `secondary`,
`border`, `focus`, `disabled` and `error` ([roles](../tokens.md#roles)); the field names
roles, never colours (key J1). Slice 7 supplies the environment keys and the exact
style-configuration protocol for the standard/default style; custom `TextFieldStyle` is
deferred with Toggle and Button (owner decision, 2026-10-10). This document uses the roles
and focus rules in [tokens](../tokens.md).

Inside a [Form](form.md) row the Form draws the field's title in its label column and the
row cursor in its gutter, and the field draws its value in the value column, with the
character counter at the row's trailing edge (see
[Character counter](#character-counter)). The Form owns that row's editing keys (Form's
key table); how they relate to the key table below is an [open question](#open-questions).

## Anatomy

The default field puts the label above a single rounded input row. The frame is compact
rather than recreating application chrome; styles can choose a borderless body while
preserving the same input region and interaction contract.

```wireframe 48x4
Email address
╭──────────────────────────────────────────────╮
│alice@example.com                             │
╰──────────────────────────────────────────────╯
```

```text
Callouts (48x4, 0-based):
1. r0       Label -- caller-supplied Label, style role `primary`; omitted only
            when the caller supplies an empty label; content, wraps above the frame.
2. r1-r3    Field frame -- standard style, the heavy set in `focus` when focused
            ([Focus](../tokens.md#focus), rule 1);
            rounded border set is visual chrome, not a hit target.
3. r2 c1-c46 Input line -- single unwrapped display viewport; the edited text, one row,
            scrolls horizontally around the caret, no wrap, no tail mark (Wrap exception
            below); primary click-to-caret region and the only mouse region in this document.
4. r2 c1-c46 Prompt slot -- the same input line when text is empty; prompt uses its
            `secondary` role and never becomes bound text; content, one-row budget
            (the input line), so a long prompt ends in `…`.
5. r2       Caret site -- derived terminal position; a focused enabled field requests the
            hardware cursor here instead of rendering a virtual cursor glyph.
```

> Wrap exception (rule 1): the editing line stays single-line and scrolls horizontally
> around the caret, with no wrap and no tail mark. Wrapping would move text under the
> caret as the user types. Prompt and label are content (owner decision, 2026-10-18).

The label is content: it word-wraps at the field's width, and the label rows add to the
field's height (see [Label wrapping](#label-wrapping)). The prompt is content too, but it
lives in the input line, whose row budget is one row, so under that fixed budget it marks
its last (only) visible row with `…` instead of growing the frame, which would shift the
frame when the first character replaces it. The label and prompt inherit `lineLimit` and
`truncationMode` from the environment; the editing line pins its own single-line behavior.

Region names for the mouse table: input line.

## States

### Mobile

`mobile` is the component at 40 columns at its natural four rows, not padded to a 40x16
frame. A single-line field does not manufacture vertical padding to fill a phone terminal
(owner decision, 2026-10-10).

```wireframe 40x4
Username
╭──────────────────────────────────────╮
│mruiz2@icloud.com                     │
╰──────────────────────────────────────╯
```

```text
Callouts (40x4, 0-based):
1. r0       Label -- visible before prompt because the 40-column viewport exceeds the
            declared minimum; content, wraps (it fits one row here).
2. r1-r3    Field frame -- compact default-style chrome; width tracks the offered 40 cells.
3. r2 c1-c38 Input line -- 38-cell viewport; editing line, content reveals horizontally
            instead of wrapping.
```

### Minimum

The declared normal-rendering floor is `12x4` (owner decision, 2026-10-18 re-derivation):
the larger of 12 columns and the label's widest word, by one frame of three rows plus the
rows the label needs at that width. Twelve columns leaves ten cells of input viewport
inside the frame, which keeps caret reveal usable; that count is a design choice, not
derived from words, and the input line has none to break. The fixture label `Search` has a
widest word of 6, so one label row and `12x4`. A label with a wider word raises the floor
to that word's width. The editing line never wraps.

```wireframe 12x4
Search
╭──────────╮
│find      │
╰──────────╯
```

```text
Callouts (12x4, 0-based):
1. r0       Label -- `Search`, whole at the floor; content, wraps. Below the floor it wraps
            and breaks between graphemes rather than dropping.
2. r1-r3    Field frame -- the smallest complete default-style frame.
3. r2 c1-c10 Input line -- ten-cell single-line viewport; editing and hardware-cursor
            placement still work at the floor.
```

### Empty prompt

The prompt appears only while the bound string is empty. It occupies the input line but is
not a default value, is not selected by a click, and disappears on the first accepted
edit.

```wireframe 48x4
Email address
╭──────────────────────────────────────────────╮
│you@example.com                               │
╰──────────────────────────────────────────────╯
```

```text
Callouts (48x4, 0-based):
1. r0       Label -- caller-supplied field name in the `primary` role; content, wraps.
2. r1-r3    Field frame -- unfocused default-style border.
3. r2 c1-c46 Prompt slot -- `secondary` text in the input line; content, one-row
            budget; its displayed characters are not part of the bound string.
```

### Focused

The fixture's `▏` is a diagrammatic proxy for the terminal's hardware cursor. It replaces
the underlying `l` cell in the fixture; it is not a glyph inserted into the buffer or
binding. Focus changes the frame to the heavy set in `focus` ([Focus](../tokens.md#focus),
rule 1); no animated cursor or software caret is introduced.

```wireframe 48x4
Email address
┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃alice@examp▏e.com                             ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
```

```text
Callouts (48x4, 0-based):
1. r0       Label -- unchanged by focus; emphasis stays on the editing region; content, wraps.
2. r1-r3    Field frame -- heavy border in `focus` ([Focus](../tokens.md#focus), rule 1).
3. r2 c1-c46 Input line -- bound text rendered without wrapping; editing line.
4. r2 c12   Caret site -- hardware cursor overlays the `l` cell at the grapheme boundary
            before it; `▏` replaces that cell in this fixture only.
```

### Horizontal overflow

The whole binding is longer than the input line. `horizontal reveal offset` moves to a
legal cluster boundary just far enough to make the caret visible; it is a viewport offset,
not an ellipsis or a mutation of the binding. Here the omitted leading clusters are
outside the viewport and the end caret is visible.

```wireframe 48x4
Repository path
╭──────────────────────────────────────────────╮
│Users/mruiz/Documents/2026/release-notes.md▏  │
╰──────────────────────────────────────────────╯
```

```text
Callouts (48x4, 0-based):
1. r0       Label -- identifies the independently bound field; content, wraps.
2. r1-r3    Field frame -- focus styling remains visible during reveal.
3. r2 c1-c46 Input line -- clipped, unwrapped slice of a longer bound value; editing
            exception: neither side receives `truncation.mark`, because this is an editable viewport.
4. r2 c41   Caret site -- end boundary remains in the viewport after reveal offset clamps.
```

### Grapheme, CJK, emoji, and combining marks

Cursor and viewport calculations use extended grapheme clusters and their display widths.
`東` and `京` each occupy two cells, the emoji cluster occupies two cells, and `é` is one
cluster with one display cell even though its source uses a combining mark. A movement or
delete never lands inside any of those clusters.

```wireframe 48x4
Display name
╭──────────────────────────────────────────────╮
│東京👩🏽‍💻 é▏                                     │
╰──────────────────────────────────────────────╯
```

```text
Callouts (48x4, 0-based):
1. r0       Label -- ordinary `primary` text, independent of input-cluster
            measurement; content, wraps.
2. r1-r3    Field frame -- unchanged for wide or combining input.
3. r2 c1-c46 Input line -- display-cell viewport: `東京` is four cells, `👩🏽‍💻` is two,
            and `é` is one.
4. r2 c9    Caret site -- hardware cursor immediately after the `é` grapheme boundary;
            `▏` is a documentation overlay, not text.
```

### Disabled

A disabled field renders its label, value, and chrome in the `disabled` role. Style. It
never requests a hardware cursor, never changes its binding, and does not intercept keys
or mouse events, so an ancestor can handle them.

```wireframe 48x4
Email address
╭──────────────────────────────────────────────╮
│alice@example.com                             │
╰──────────────────────────────────────────────╯
```

```text
Callouts (48x4, 0-based):
1. r0       Label -- `disabled` role rather than a second color palette; content, wraps.
2. r1-r3    Field frame -- disabled chrome; it has no focus accent.
3. r2 c1-c46 Input line -- read-only visual value and noninteractive hit region.
```

### Label wrapping

The label is content (owner decision, 2026-10-18): at a finite width it word-wraps above
the frame, a word wider than the field breaks between grapheme clusters, and the field
grows by the rows the label needs. A finite height is a fixed row budget; see
[Sizing](#sizing) for which region gives up rows first. The prompt, in the one-row input
line, ends in `…` when it is too long.

```wireframe 16x5
Email address
for billing
╭──────────────╮
│bob@acme.io   │
╰──────────────╯
```

```text
Callouts (16x5, 0-based):
1. r0-r1     Label -- `Email address for billing` wrapped at 16 columns; content, wraps.
2. r2-r4     Field frame -- unchanged three-row chrome below the label rows.
3. r3 c1-c14 Input line -- editing line, one row; bound text `bob@acme.io`.
```

```wireframe 20x4
Work email
╭──────────────────╮
│you@example.com (…│
╰──────────────────╯
```

```text
Callouts (20x4, 0-based):
1. r0       Label -- `Work email`; content, wraps (fits one row).
2. r1-r3    Field frame -- chrome.
3. r2 c1-c18 Prompt slot -- `you@example.com (work)` under a one-row budget: the 18-cell line keeps 17 cells and ends in `…`; content, one row.
```

### Character counter

Owner decision, omp2 review, 2026-10. A field with an app-supplied character limit shows a
right-aligned counter. At or under the limit it shows the remaining count in `secondary`;
over it it shows `+N`, the number of grapheme clusters past the limit, in `error`. The
counter never caps input: an over-limit value stays bound and editable through `text`. The
two sample rows show both states: row 1 has 21 grapheme clusters under a limit of 40, and
row 2 has 25 grapheme clusters over a limit of 12.

Owner decision, 2026-10-10: the counter unit is grapheme clusters, matching the cursor and
edits. An exact limit shows `0` in `secondary`. The limit is set by `.characterLimit(_:)`
in the environment, so it is configuration rather than state.

```wireframe 40x2
❯ Release notes for 2.4               19
❯ build-and-test-everything          +13
```

```text
Callouts (40x2, 0-based):
1. c0-c1    row cursor `❯` -- `accent` on the focused row and `secondary` on the other. It is
            host-row chrome (Focus border rule 3), not TextField output.
2. c2-c26   input text -- bound value in `primary`; row 1 is 21 grapheme clusters, row 2 is 25.
3. r0 c38-c39 remaining count `19` -- `secondary`: the limit of 40 minus 21 grapheme clusters; chrome, one row.
4. r1 c37-c39 overflow count `+13` -- `error`: 25 grapheme clusters minus the limit of 12; chrome, one row.
```

Styled grid (owner review, verbatim):

```text
── chars ──
❯ Release notes for 2.4               19
❯ build-and-test-everything          +13
── style ──
AABBBBBBBBBBBBBBBBBBBBB...............CC
CCBBBBBBBBBBBBBBBBBBBBBBBBB..........RRR
── legend ──
.  default
A  fg=accent
B  fg=primary
C  fg=secondary
R  fg=error
```

### Degraded

This is the ASCII-only focused fixture. `+`, `-`, and `|` come from the `ascii` border
set; `|` at the caret site is a hardware-cursor diagram proxy that replaces the underlying
`l` cell in the fixture. In `NO_COLOR`, the focused frame switches to the heavy set in
bold; in 16-colour, `focus` is the default foreground in bold
([focus](../tokens.md#focus)); in ASCII-only, the frame changes as shown and text still
measures by display cell.

```wireframe 48x4
Email address
+----------------------------------------------+
|alice@examp|e.com                             |
+----------------------------------------------+
```

```text
Callouts (48x4, 0-based):
1. r0       Label -- plain terminal-default text when color is unavailable; content, wraps.
2. r1-r3    Field frame -- token `borders.ascii`, preserving the component boundary without
            Unicode glyphs.
3. r2 c1-c46 Input line -- remains the same editable display viewport under degradation; editing line.
4. r2 c12   Caret site -- terminal cursor overlay represented by ASCII `|`; it replaces
            the underlying `l` cell in this fixture only.
```

## State model

| State                                    | Owner       | Type                                | Reset or clamp rule                                                                                                                                                                                    |
| ---------------------------------------- | ----------- | ----------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| text                                     | Binding     | `Binding<String>`                   | App-owned source of truth; every accepted edit replaces its value immediately, and external replacement is authoritative.                                                                              |
| cursor grapheme offset                   | NodeState   | `Int`                               | Clamp to `0...graphemeCount(text)` on every reconciliation; if the app changes text, keep the nearest surviving grapheme boundary.                                                                     |
| selection anchor grapheme offset         | NodeState   | `Int`                               | Clamp to `0...graphemeCount(text)` on every reconciliation; equal to the cursor when no range is selected, and never points inside a grapheme.                                                         |
| selected grapheme range                  | derived     | `Range<Int>`                        | The half-open range between anchor and cursor; replacement and deletion operate on whole graphemes only.                                                                                               |
| horizontal reveal offset                 | NodeState   | `Int` display-cell offset           | Clamp on every layout/update to a legal grapheme boundary between `0` and the maximum reveal; adjust minimally to keep the caret within the input line. The editing line never wraps.                  |
| grapheme boundaries and display advances | derived     | `[String.Index]` plus cell advances | Recompute from current `text` during layout/render; combining marks advance zero and wide clusters reserve their measured cells.                                                                       |
| input viewport width                     | derived     | `Int` cells                         | Recompute from final input-line bounds on every layout; zero width yields no cursor request.                                                                                                           |
| effective enabled                        | derived     | `Bool`                              | Recompute from the inherited enabled configuration on every update; false disables focus/edit behavior without copying text.                                                                           |
| focused                                  | derived     | `Bool`                              | Read from the `isFocused` environment value that `FocusManager` supplies (keys E1 and E2); if this node disappears, focus clears under Slice 4 and the cursor request disappears.                      |
| has submit handler                       | derived     | `Bool`                              | Recompute from the optional `onSubmit` closure on every update; true exactly when the closure is non-nil.                                                                                              |
| caret terminal position                  | derived     | `TerminalPosition?`                 | Recompute from bounds, reveal offset, and cursor boundary; nil unless focused, enabled, and a visible input cell exists.                                                                               |
| character limit                          | Environment | `Int?`                              | Configuration, not state: read on every render from `.characterLimit(_:)`; nil draws no counter. The limit counts but never caps input (accepted sample: 25 over 12). Owner decision, 2026-10-10.      |
| character count                          | derived     | `Int` graphemes                     | Recompute as `graphemeCount(text)` on every render; the unit is grapheme clusters (owner decision, 2026-10-10).                                                                                        |
| counter display                          | derived     | `Int?` plus role                    | At or under the limit, including exactly `0` remaining: `limit - count` in `secondary` (owner decision, 2026-10-10). Over it: `count - limit` as `+N` in `error`. Nil without a limit; never negative. |

## Key table

`Tab` and `Esc` deliberately bubble: focus traversal and dismissal are app policies under
[Slice 4](../../spec/phase-4/slice-04-focus-and-key-routing.md) (key E4). Each consumed
key below is a deliberate row and every unlisted key bubbles (key E3). Rows match
normalized `Key` and `Modifiers` chords; rebinding belongs to apps (key E5), and there is
no undo or yank (key D6). Word-wise movement uses Unicode word segmentation at legal
grapheme boundaries; no byte or Unicode-scalar cursor fallback is permitted.

| Key                 | Precondition                                                                           | Effect                                                                                                                                                               | Consumed                                            |
| ------------------- | -------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------- |
| printable character | focused and effective enabled                                                          | Replaces the selected whole-grapheme range, if any, through Binding; otherwise inserts at `cursor grapheme offset`, then collapses the selection and adjusts reveal. | yes                                                 |
| Left                | focused and effective enabled                                                          | Decrements `cursor grapheme offset` by one legal grapheme boundary and adjusts reveal.                                                                               | yes                                                 |
| Right               | focused and effective enabled                                                          | Increments `cursor grapheme offset` by one legal grapheme boundary and adjusts reveal.                                                                               | yes                                                 |
| Shift-Left/Right    | focused and effective enabled                                                          | Extends the selected range from the anchor by one legal grapheme boundary and adjusts reveal.                                                                        | yes                                                 |
| Alt-Left            | focused and effective enabled                                                          | Moves `cursor grapheme offset` to the preceding word boundary and adjusts reveal.                                                                                    | yes                                                 |
| Alt-Right           | focused and effective enabled                                                          | Moves `cursor grapheme offset` to the following word boundary and adjusts reveal.                                                                                    | yes                                                 |
| Ctrl-Left           | focused and effective enabled                                                          | Moves `cursor grapheme offset` to the preceding word boundary when the negotiated keyboard protocol distinguishes this chord; otherwise bubbles.                     | conditional (keyboard protocol distinguishes chord) |
| Ctrl-Right          | focused and effective enabled                                                          | Moves `cursor grapheme offset` to the following word boundary when the negotiated keyboard protocol distinguishes this chord; otherwise bubbles.                     | conditional (keyboard protocol distinguishes chord) |
| Home                | focused and effective enabled                                                          | Sets `cursor grapheme offset` and `horizontal reveal offset` to the leading legal boundary.                                                                          | yes                                                 |
| End                 | focused and effective enabled                                                          | Sets `cursor grapheme offset` to `graphemeCount(text)` and adjusts reveal to show it.                                                                                | yes                                                 |
| Backspace           | focused and effective enabled and cursor grapheme offset greater than 0                | Removes the preceding whole grapheme from `text` through Binding, decrements cursor, and adjusts reveal.                                                             | yes                                                 |
| Delete              | focused and effective enabled and cursor grapheme offset less than graphemeCount(text) | Removes the following whole grapheme from `text` through Binding and adjusts reveal.                                                                                 | yes                                                 |
| Enter               | focused and effective enabled and has submit handler is true                           | Calls the app-owned `onSubmit` closure, which reads `text` from its own binding (key C3); widget state and Binding are otherwise unchanged.                          | yes                                                 |
| Enter               | focused and effective enabled and has submit handler is false                          | Leaves all state unchanged so an ancestor may handle submit.                                                                                                         | no                                                  |
| Tab                 | focused                                                                                | Leaves all state unchanged so focus traversal may bubble to an app handler.                                                                                          | no                                                  |
| Esc                 | focused                                                                                | Leaves all state unchanged so dismissal or focus clearing may bubble to an app handler.                                                                              | no                                                  |

## Paste-input contract

Paste reaches the focused field like a key (key E7). The existing
[bracketed-paste `InputEvent.paste(String)` event](../../spec/phase-3/slice-01-bracketed-paste-mode.md)
is handled only while `focused and effective enabled`. Slice 7 normalizes each `\r\n`
pair, standalone `\r`, and standalone `\n` in that payload to one U+0020 space, then
inserts the resulting grapheme clusters at `cursor grapheme offset` through `text`'s
Binding, advances the cursor to the inserted end, and adjusts `horizontal reveal offset`.
The event is consumed. This preserves word separation without ever inserting a line break
or invoking submit, matching the field's single-line printable-input behavior. When
unfocused or disabled, the paste event leaves `text`, cursor, and reveal unchanged and
bubbles.

Software-keyboard and dictation-produced committed characters are ordinary printable
input: they are routed as printable `Key` characters and follow the printable-character
row above, one grapheme at a time. They do not declare a separate TextField event or a
second mutable text store.

## Mouse table

Mouse support declares the Slice 5 requirement only while an enabled TextField is live.
The input line is the field's one hit region (key F1). A primary press focuses a focusable
node before delivery, then the click acts (key F6); click-to-caret then uses the final
input-line bounds. Hit testing must not map a click onto the trailing cell of a wide
cluster as an interior cursor position. Right and middle clicks have no TextField use (key
F3).

| Event        | Region     | Precondition               | Effect                                                                                                                                                                                                           | Consumed |
| ------------ | ---------- | -------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- |
| click        | input line | effective enabled          | Maps the x cell plus `horizontal reveal offset` to the nearest legal grapheme boundary, sets `cursor grapheme offset`, adjusts reveal, and requests redraw; built-in click-to-focus occurs before this delivery. | yes      |
| double-click | input line | effective enabled          | Leaves the keyboard selection anchor/cursor unchanged; word-wise pointer selection is outside this single-line interaction slice and bubbles.                                                                    | no       |
| drag         | input line | always                     | Leaves the keyboard selection anchor/cursor unchanged; pointer range selection is outside this interaction slice and bubbles.                                                                                    | no       |
| click        | input line | effective enabled is false | Leaves `text`, cursor, and reveal unchanged.                                                                                                                                                                     | no       |

## Sizing

These exact results use the default style, label `Email address`, empty text, and prompt
`you@example.com`; the default style places the label rows plus a three-row rounded field.
A custom style controls its own chrome metrics but must still offer a single unwrapped
input line and respect the offered bounds. `nil` is the layout protocol's unconstrained
axis.

Under a finite height, the rows are shared by the label, the frame, and the input line.
The input line keeps its row first; the frame (chrome) drops before the label loses rows;
the label then takes the remaining rows and marks its last visible row with `…`; a label
left with zero rows is absent (owner decision, 2026-10-18).

| Proposal  | Result | Rule                                                                                                                                                                                                                 |
| --------- | ------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| nil x nil | 17x4   | Ideal width is max(label 13, prompt 15) plus the two frame columns; default-style height is label plus three frame rows.                                                                                             |
| 17x4      | 17x4   | Tight fit accepts the ideal width and intrinsic four-row height.                                                                                                                                                     |
| 11x2      | 11x2   | Under the declared `12x4` floor, accepts the offered bounds. The input line keeps its row, the frame drops, and the label takes the one remaining row: `Email addr…` over the input line. The binding is never lost. |
| 80x24     | 80x4   | Over maximum height stays intrinsic while offered width becomes the single-line viewport width.                                                                                                                      |
| 12xnil    | 12x5   | Label `Email address` wraps to `Email` and `address` (two rows), then the three-row frame; the editing line stays one row.                                                                                           |
| 11x1      | 11x1   | The input line keeps the only row; the frame and the label drop (a zero-row label is absent); the prompt ends in `…`.                                                                                                |

## Environment

- The focused frame takes the heavy set in `focus` ([Focus](../tokens.md#focus), rule 1);
  the field never names a colour.
- `rounded`, `heavy` and `ascii` from [border sets](../tokens.md#border-sets) supply the
  default, focused and degraded frame glyphs.
- The [degradation ladder](../tokens.md#degradation-ladder) governs `NO_COLOR`, 16-color,
  and ASCII-only fallbacks.
- The field consumes inherited enabled state and the complete `Style` roles `primary`,
  `secondary`, `border`, `focus`, `disabled` and `error`; custom `TextFieldStyle` and
  `textFieldStyle(_:)` are deferred with Toggle and Button (owner decision, 2026-10-10),
  outside 1.0.
- The character counter consumes `secondary` for the remaining count and `error` for the
  overflow count ([roles](../tokens.md#roles)). The character limit is environment
  configuration set by `.characterLimit(_:)` (owner decision, 2026-10-10), not a style
  role.

## Primitive dependencies

- [Text](../primitives/text.md) (`ready`) -- label, prompt, and cluster-safe input slice;
  it must expose Phase 2 Slice 4 display-width/cluster measurement rather than TextField
  reimplementing it (key I4).
- [Border](../primitives/border.md) (`ready`) -- default rounded frame, heavy frame when
  focused, and ascii frame, using the canonical token sets (key K4).
- Slice 4 focusable-view, `FocusManager`, and key-routing support (plan 032 Phase 10) --
  the focus/key dependency only; it exposes no public TextField.
- Slice 5 hit testing and mouse dispatch (plan 032 step 11.1) -- the click-to-caret
  dependency only; it exposes no public TextField pointer behavior.
- `Binding` and `NodeState` -- controlled text and disposable cursor/reveal storage from
  [Slice 7](../../spec/phase-4/slice-07-catalog-integration.md).

## Progressive slice availability

1. Plan 032 Phase 10 (Slice 4) supplies the focus/key-routing dependency only; it does not
   expose TextField or a TextField hardware-cursor contract.
2. Plan 032 step 11.1 (Slice 5) supplies the click-to-caret dependency only; it does not
   expose TextField pointer behavior.
3. Plan 032 step 13.4 ships the whole controlled TextField on the shared text editing core
   ([Spec](../../spec/phase-4/slice-04-focus-and-key-routing.md#controls-and-focused-viewport-interaction)):
   hardware cursor, Binding edits, grapheme cursor/selection/reveal, paste/newline
   normalization, submit, and deterministic buffer/cursor fixtures. Custom
   `TextFieldStyle` is deferred with Toggle and Button (owner decision, 2026-10-10).
4. The character counter is the TextField demo step (plan 032 step 13.4) (owner decision,
   2026-10-10).
5. Secure entry, edit history, and clipboard work are deferred until post-1.0 (see
   [Deferred post-1.0](#deferred-post-10)).

## Requirements

- `text field continuously writes printable graphemes through its binding` (key table:
  printable character)
- `text field normalizes focused paste input into one single-line binding edit`
  (Paste-input contract: `InputEvent.paste(String)`)
- `text field routes software keyboard and dictation characters as ordinary printable input`
  (Paste-input contract: software keyboard and dictation; key table: printable character)
- `text field clamps its cursor after the app replaces bound text` (state model: cursor
  grapheme offset)
- `text field clamps its selection anchor after the app replaces bound text` (state model:
  selection anchor grapheme offset)
- `text field replaces whole selected graphemes through its binding` (state model:
  selected grapheme range; key table: printable character)
- `text field never positions caret inside CJK emoji or combining graphemes` (Grapheme,
  CJK, emoji, and combining marks wireframe; key table: Left)
- `text field reveals the hardware caret without inserting an ellipsis into editable text`
  (Horizontal overflow wireframe; state model: horizontal reveal offset)
- `text field label word-wraps above the frame and grows the field height` (Label wrapping
  wireframe 16x5; sizing: 12xnil).
- `text field editing line stays single-line with no wrap and no tail mark` (Wrap
  exception; Horizontal overflow wireframe; Mobile wireframe).
- `text field prompt ends in the truncation mark under the one-row input line` (Label
  wrapping wireframe 20x4).
- `text field keeps the input row first, then the frame, then label rows under a fixed height`
  (sizing: 11x2, 11x1).
- `text field invokes submit without owning or clearing app text` (key table: Enter with
  has submit handler is true)
- `text field bubbles Enter when has submit handler is false` (key table: Enter with has
  submit handler is false)
- `text field bubbles Tab and Esc for app focus and dismissal policy` (key table: Tab; key
  table: Esc)
- `text field deletes whole graphemes on both sides of the caret` (key table: Backspace;
  key table: Delete)
- `text field maps an enabled input-line click to a grapheme boundary` (mouse table: click
  with effective enabled)
- `text field requests a focused enabled hardware cursor at its visible caret boundary`
  (state model: caret terminal position; render contract: no software cursor)
- `text field leaves disabled bindings and routing untouched` (Disabled wireframe; key
  table: printable character; mouse table: disabled click)
- `text field reports a 17x4 ideal and tight default-style size` (sizing: nil x nil;
  sizing: 17x4)
- `text field stays single-line at mobile and minimum proposals` (Mobile wireframe;
  Minimum wireframe; sizing: 11x2)
- `text field applies ascii degradation without creating a software cursor` (Degraded
  wireframe)
- `text field shows the remaining count in secondary under its limit` (Character counter
  wireframe; state model: counter display)
- `text field shows a zero remaining count in secondary when the count equals its limit`
  (state model: counter display; owner decision, 2026-10-10)
- `text field shows an overflow count in error without capping its binding` (Character
  counter wireframe; state model: counter display and character limit)
- `text field draws no counter without an app-supplied limit` (state model: character
  limit)

## Degradation

At normal capability, the default style uses the rounded frame, and the heavy set in
`focus` when focused. At `NO_COLOR`, the focused frame takes the heavy set in bold, per
the ladder. At 16-colour it uses each role's slots column ([roles](../tokens.md#roles)),
never a hard-coded RGB approximation. At ASCII-only it uses the degraded fixture's
`+`/`-`/`|` frame and `|` cursor diagram convention; editable text remains
grapheme/display-width-safe. Below `12x4`, it reports the offered size. Under a fixed
height the input line keeps its row, then the frame drops, then the label loses rows (its
last visible row ends in `…`); in width the label wraps and breaks between graphemes, and
the editing line scrolls and never wraps. At zero input cells it makes no cursor request.
No degradation changes the Binding or turns prompt text into data. The counter keeps its
text at every capability level; its `secondary` and `error` colours follow the
[degradation ladder](../tokens.md#degradation-ladder).

## Deferred post-1.0

- **Secure entry:** Defer `SecureField`/masking, reveal-last-character timing, clipboard
  policy, and accessibility implications until post-1.0. A secure option must not silently
  be added to TextField because it changes rendering and input-policy contracts. A masked
  value's display is Form's `secret` icon; editing masked text is this deferral (key M8).
- **Edit history:** undo and yank are rejected for 1.0, so the key table has neither (key
  D6). If the shared text editing core adds them, history is NodeState: losing it loses no
  committed text.
- **Clipboard:** TextField does no clipboard work in 1.0; text reaches it through paste
  only (see [Paste-input contract](#paste-input-contract)), and copy policy belongs to
  [Text selection](../primitives/text-selection.md) (key C11).

This design was reviewed against the [Phase 4 theses](../../spec/phase-4.md): the text is
the app's binding and the field keeps no copy; the caret, anchor, and reveal are NodeState
with one owner, clamped on every update; keys, paste, and clicks change state
synchronously through documented rows; and the field requests the hardware cursor from the
session instead of writing it.

## Open questions

Each question is deferred to plan 032 step 13.4, which builds the shared text editing
core; the contract above holds until the owner decides.

- Readline chords (key E5). omp2's Input binds Ctrl-a, Ctrl-e, Ctrl-b, Ctrl-f, Ctrl-d,
  Ctrl-k, Ctrl-u, and Ctrl-w. Picker's and MultiPicker's draft rows list Ctrl-U and Ctrl-W
  as the shared core's keys, and Form's text rows bind them too, but this key table has no
  Ctrl chords except Ctrl-Left and Ctrl-Right, so they bubble. Does TextField take Ctrl-U
  and Ctrl-W from the shared core, and any other readline chord?
- Form text rows. Inside a Form row the Form's key table edits the text append-only (no
  caret, Backspace at the end), as omp2's Form does; this doc's caret editing applies
  standalone. Whether a Form row hands its editing keys to this key table is
  [Form's open question](form.md#open-questions).

## Inspiration

The compact label-above-field shape preserves terminal density while SwiftUI's
label/prompt vocabulary avoids overloading placeholder text. Ratatui demonstrates the
value of an actual terminal cursor, while its own Unicode caveat makes the counterexample
explicit: Tessera's field must measure clusters and display cells before it can claim
editing support.
