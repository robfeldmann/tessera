---
kind: widget
status: wireframed
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
with Toggle and Button (owner decision, 2026-10-10). The concrete initializer signature
remains open. `TextField` is neither a multiline editor nor secure entry in 1.0.

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
- omp2's `Input` counter
  ([limit](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/input.rs#L196-L201),
  [render](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/input.rs#L511-L516))
  shows the remaining count right-aligned in muted, and a limit counts without capping
  input. Copy that placement and the non-capping rule; reject its `-N` overage and warn
  role, which the owner replaced with `+N` in `error` (owner decision, omp2 review,
  2026-10).

## API direction

The names below are accepted public direction, not settled concrete signatures:

```swift
public struct TextField<Label: View>: View {
    // string Binding, optional prompt, label, optional onSubmit
}

// Deferred with Toggle and Button; outside 1.0 (owner decision, 2026-10-10).
public protocol TextFieldStyle {
    associatedtype Body: View
    @ViewBuilder func makeBody(configuration: TextFieldStyleConfiguration) -> Body
}

extension View {
    public func textFieldStyle(_ style: some TextFieldStyle) -> some View
    public func characterLimit(_ limit: Int?) -> some View
}
```

The standard style is selected from the environment, with a default style when no ancestor
supplies one. A style receives the label, prompt, text display region, focus/enabled
state, and caret request site; it may change chrome but cannot own text, selection, or
submit behavior. Planned semantic roles are complete `Style` values, not hard-coded
colors: `semantic.primary`, `semantic.secondary`, `semantic.accent`, `semantic.disabled`,
and `semantic.destructive`. Slice 7 supplies the environment keys and the exact
style-configuration protocol for the standard/default style; custom `TextFieldStyle` is
deferred with Toggle and Button (owner decision, 2026-10-10). Until then, this document
uses only the canonical focus, border, truncation, and degradation tokens in
[tokens](../tokens.md).

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
1. r0       Label -- caller-supplied Label, style role `semantic.primary`; omitted only
            when the caller supplies an empty label; content, wraps above the frame.
2. r1-r3    Field frame -- default TextFieldStyle, token `focus.border` when focused;
            rounded border set is visual chrome, not a hit target.
3. r2 c1-c46 Input line -- single unwrapped display viewport; the edited text, one row,
            scrolls horizontally around the caret, no wrap, no tail mark (Wrap exception
            below); primary click-to-caret region and the only mouse region in this document.
4. r2 c1-c46 Prompt slot -- the same input line when text is empty; prompt uses planned
            `semantic.secondary` Style and never becomes bound text; content, one-row budget
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
1. r0       Label -- caller-supplied field name in the `semantic.primary` role; content, wraps.
2. r1-r3    Field frame -- unfocused default-style border.
3. r2 c1-c46 Prompt slot -- muted `semantic.secondary` text in the input line; content, one-row
            budget; its displayed characters are not part of the bound string.
```

### Focused

The fixture's `▏` is a diagrammatic proxy for the terminal's hardware cursor. It replaces
the underlying `l` cell in the fixture; it is not a glyph inserted into the buffer or
binding. Focus changes the frame through `focus.border`; no animated cursor or software
caret is introduced.

```wireframe 48x4
Email address
╭──────────────────────────────────────────────╮
│alice@examp▏e.com                             │
╰──────────────────────────────────────────────╯
```

```text
Callouts (48x4, 0-based):
1. r0       Label -- unchanged by focus; emphasis stays on the editing region; content, wraps.
2. r1-r3    Field frame -- rounded border in the token `focus.border` accent treatment.
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
1. r0       Label -- ordinary `semantic.primary` text, independent of input-cluster
            measurement; content, wraps.
2. r1-r3    Field frame -- unchanged for wide or combining input.
3. r2 c1-c46 Input line -- display-cell viewport: `東京` is four cells, `👩🏽‍💻` is two,
            and `é` is one.
4. r2 c9    Caret site -- hardware cursor immediately after the `é` grapheme boundary;
            `▏` is a documentation overlay, not text.
```

### Disabled

A disabled field renders its label, value, and chrome in the planned `semantic.disabled`
Style. It never requests a hardware cursor, never changes its binding, and does not
intercept keys or mouse events, so an ancestor can handle them.

```wireframe 48x4
Email address
╭──────────────────────────────────────────────╮
│alice@example.com                             │
╰──────────────────────────────────────────────╯
```

```text
Callouts (48x4, 0-based):
1. r0       Label -- `semantic.disabled` Style rather than a second color palette; content, wraps.
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
right-aligned counter. At or under the limit it shows the remaining count in `muted`; over
it it shows `+N`, the number of grapheme clusters past the limit, in `error`. The counter
never caps input: an over-limit value stays bound and editable through `text`. The two
sample rows show both states: row 1 has 21 grapheme clusters under a limit of 40, and row
2 has 25 grapheme clusters over a limit of 12.

Owner decision, 2026-10-10: the counter unit is grapheme clusters, matching the cursor and
edits. An exact limit shows `0` in `muted`. The limit is set by `.characterLimit(_:)` in
the environment, so it is configuration rather than state.

```wireframe 40x2
❯ Release notes for 2.4               19
❯ build-and-test-everything          +13
```

```text
Callouts (40x2, 0-based):
1. c0-c1    row cursor `❯` -- `accent` on the focused row and `muted` on the other. It is
            host-row chrome (Focus border rule 3), not TextField output.
2. c2-c26   input text -- bound value in `primary`; row 1 is 21 grapheme clusters, row 2 is 25.
3. r0 c38-c39 remaining count `19` -- `muted`: the limit of 40 minus 21 grapheme clusters; chrome, one row.
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
C  fg=muted
R  fg=error
```

### Degraded

This is the ASCII-only focused fixture. `+`, `-`, and `|` come from the `ascii` border
set; `|` at the caret site is a hardware-cursor diagram proxy that replaces the underlying
`l` cell in the fixture. In `NO_COLOR`, the normal rounded frame remains but focus uses
bold; in 16-color, the focus role maps to an indexed accent; in ASCII-only, the frame
changes as shown and text still measures by display cell.

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

| State                                    | Owner       | Type                                | Reset or clamp rule                                                                                                                                                                                |
| ---------------------------------------- | ----------- | ----------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| text                                     | Binding     | `Binding<String>`                   | App-owned source of truth; every accepted edit replaces its value immediately, and external replacement is authoritative.                                                                          |
| cursor grapheme offset                   | NodeState   | `Int`                               | Clamp to `0...graphemeCount(text)` on every reconciliation; if the app changes text, keep the nearest surviving grapheme boundary.                                                                 |
| selection anchor grapheme offset         | NodeState   | `Int`                               | Clamp to `0...graphemeCount(text)` on every reconciliation; equal to the cursor when no range is selected, and never points inside a grapheme.                                                     |
| selected grapheme range                  | derived     | `Range<Int>`                        | The half-open range between anchor and cursor; replacement and deletion operate on whole graphemes only.                                                                                           |
| horizontal reveal offset                 | NodeState   | `Int` display-cell offset           | Clamp on every layout/update to a legal grapheme boundary between `0` and the maximum reveal; adjust minimally to keep the caret within the input line. The editing line never wraps.              |
| grapheme boundaries and display advances | derived     | `[String.Index]` plus cell advances | Recompute from current `text` during layout/render; combining marks advance zero and wide clusters reserve their measured cells.                                                                   |
| input viewport width                     | derived     | `Int` cells                         | Recompute from final input-line bounds on every layout; zero width yields no cursor request.                                                                                                       |
| effective enabled                        | derived     | `Bool`                              | Recompute from the inherited enabled configuration on every update; false disables focus/edit behavior without copying text.                                                                       |
| focused                                  | derived     | `Bool`                              | Recompute from `FocusManager`; if this node disappears, focus clears under Slice 4 and cursor request disappears.                                                                                  |
| has submit handler                       | derived     | `Bool`                              | Recompute from the optional submit closure on every update; true exactly when the closure is non-nil.                                                                                              |
| caret terminal position                  | derived     | `TerminalPosition?`                 | Recompute from bounds, reveal offset, and cursor boundary; nil unless focused, enabled, and a visible input cell exists.                                                                           |
| character limit                          | Environment | `Int?`                              | Configuration, not state: read on every render from `.characterLimit(_:)`; nil draws no counter. The limit counts but never caps input (accepted sample: 25 over 12). Owner decision, 2026-10-10.  |
| character count                          | derived     | `Int` graphemes                     | Recompute as `graphemeCount(text)` on every render; the unit is grapheme clusters (owner decision, 2026-10-10).                                                                                    |
| counter display                          | derived     | `Int?` plus role                    | At or under the limit, including exactly `0` remaining: `limit - count` in `muted` (owner decision, 2026-10-10). Over it: `count - limit` as `+N` in `error`. Nil without a limit; never negative. |

## Key table

`Tab` and `Esc` deliberately bubble: focus traversal and dismissal are app policies under
[Slice 4](../../docs/Spec.md#slice-4-focus-and-key-routing-the-responder-system).
Word-wise movement uses Unicode word segmentation at legal grapheme boundaries; no byte or
Unicode- scalar cursor fallback is permitted.

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
| Enter               | focused and effective enabled and has submit handler is true                           | Invokes the app-owned submit handler with the current `text`; widget state and Binding are otherwise unchanged.                                                      | yes                                                 |
| Enter               | focused and effective enabled and has submit handler is false                          | Leaves all state unchanged so an ancestor may handle submit.                                                                                                         | no                                                  |
| Tab                 | focused                                                                                | Leaves all state unchanged so focus traversal may bubble to an app handler.                                                                                          | no                                                  |
| Esc                 | focused                                                                                | Leaves all state unchanged so dismissal or focus clearing may bubble to an app handler.                                                                              | no                                                  |

## Paste-input contract

The existing
[bracketed-paste `InputEvent.paste(String)` event](../../docs/Spec.md#slice-1-bracketed-paste-mode)
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

Mouse support declares the Slice 5 requirement only while an enabled TextField is live. A
primary press focuses a focusable node before delivery; click-to-caret then uses the final
input-line bounds. Hit testing must not map a click onto the trailing cell of a wide
cluster as an interior cursor position.

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

- `focus.border` and `focus.content` from [tokens](../tokens.md#focus) select focused
  default-style emphasis; the field never names a color.
- `rounded` and `ascii` from [border sets](../tokens.md#border-sets) supply default and
  degraded frame glyphs.
- The [degradation ladder](../tokens.md#degradation-ladder) governs `NO_COLOR`, 16-color,
  and ASCII-only fallbacks.
- The field consumes inherited enabled state and the complete semantic `Style` values
  `semantic.primary`, `semantic.secondary`, `semantic.accent`, and `semantic.disabled`;
  custom `TextFieldStyle` and `textFieldStyle(_:)` are deferred with Toggle and Button
  (owner decision, 2026-10-10), outside this P4.5 acceptance requirement.
- The character counter consumes `muted` for the remaining count and `error` for the
  overflow count; both roles are token pending plan 032 step 5.3. The character limit is
  environment configuration set by `.characterLimit(_:)` (owner decision, 2026-10-10), not
  a style role.

## Primitive dependencies

- `Text` -- label, prompt, and cluster-safe input slice; it must expose Phase 2 Slice 4
  display-width/cluster measurement rather than TextField reimplementing it.
- `Border` -- default rounded/ascii frame using the canonical token sets.
- Slice 4 focusable-view, `FocusManager`, and key-routing support -- the focus/key
  dependency only; it does not expose a public TextField before Slice 7.
- Slice 5 hit testing and mouse dispatch -- the click-to-caret dependency only; it does
  not expose public TextField pointer behavior before Slice 7.
- `Binding` and `NodeState` -- controlled text and disposable cursor/reveal storage from
  [Slice 7](../../docs/Spec.md#slice-7-catalog-integration--list-section-controlled-widgets-and-the-showcase).

## Progressive slice availability

1. Slice 4 supplies the focus/key-routing dependency only; it does not expose TextField or
   a TextField hardware-cursor contract.
2. Slice 5 supplies the click-to-caret dependency only; it does not expose TextField
   pointer behavior.
3. Slice 7 ships the renamed controlled TextField: hardware cursor, Binding edits,
   grapheme cursor/selection/reveal, paste/newline normalization, submit, and
   deterministic buffer/cursor fixtures. Custom `TextFieldStyle` is deferred with Toggle
   and Button (owner decision, 2026-10-10).
4. The character counter is the TextField demo step (plan 032 step 13) (owner decision,
   2026-10-10).
5. Only secure entry is deferred until post-1.0.

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
- `text field shows the remaining count in muted under its limit` (Character counter
  wireframe; state model: counter display)
- `text field shows a zero remaining count in muted when the count equals its limit`
  (state model: counter display; owner decision, 2026-10-10)
- `text field shows an overflow count in error without capping its binding` (Character
  counter wireframe; state model: counter display and character limit)
- `text field draws no counter without an app-supplied limit` (state model: character
  limit)

## Degradation

At normal capability, the default style uses the rounded frame and `focus.border` accent.
At `NO_COLOR`, it retains glyphs but substitutes bold focus, per the ladder. At 16-color
it uses the indexed accent mapping, never a hard-coded RGB approximation. At ASCII-only it
uses the degraded fixture's `+`/`-`/`|` frame and `|` cursor diagram convention; editable
text remains grapheme/display-width-safe. Below `12x4`, it reports the offered size. Under
a fixed height the input line keeps its row, then the frame drops, then the label loses
rows (its last visible row ends in `…`); in width the label wraps and breaks between
graphemes, and the editing line scrolls and never wraps. At zero input cells it makes no
cursor request. No degradation changes the Binding or turns prompt text into data. The
counter keeps its text at every capability level; its `muted` and `error` colours follow
the ladder once those roles have tokens (token pending plan 032 step 5.3).

## Deferred post-1.0

- **Secure entry:** Defer `SecureField`/masking, reveal-last-character timing, clipboard
  policy, and accessibility implications until post-1.0. A secure option must not silently
  be added to TextField because it changes rendering and input-policy contracts.

## Open questions

- **Counter roles (blocks `ready`).** The roles `muted` and `error` are absent from
  `design/tokens.md`; token pending plan 032 step 5.3. Their degradation under `NO_COLOR`
  and 16-color follows once those tokens land.

## Inspiration

The compact label-above-field shape preserves terminal density while SwiftUI's
label/prompt vocabulary avoids overloading placeholder text. Ratatui demonstrates the
value of an actual terminal cursor, while its own Unicode caveat makes the counterexample
explicit: Tessera's field must measure clusters and display cells before it can claim
editing support.
