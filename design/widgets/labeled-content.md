---
kind: widget
status: wireframed
---

# LabeledContent

`LabeledContent` is a read-only row of a label and a value: a supporting label on the left
and the value beside it. It stays inline while both fit on one line. When the value is too
long to sit beside the label, the value stacks beneath it and wraps within the width. The
label and the value are both content and wrap rather than truncate (owner decision,
2026-10-18). It has no focus, keys or pointer behaviour; use it for status and metadata
lists, not inputs.

Owner decision, omp2 review, 2026-10: adopt the omp2 layout as captured. Label and value
share the row with one column of gap and no shared column across rows. The label draws in
the `secondary` role, as SwiftUI's does, rather than omp2's `muted`, and the value in
`primary` (owner decision, 2026-10-10). Foreground styling is set on the view.

Rows never align to a shared label column, inside a `Form` or elsewhere: space is often
short in a terminal, and each value starting one column after its own label keeps rows as
narrow as they can be (owner decision, 2026-10-10). An opt-in aligned layout may come
later.

## Prior art

- omp2 Fact,
  [fact.rs](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/fact.rs#L15-L25),
  defines the label/value row. Its geometry is at
  [#L74-L114](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/fact.rs#L74-L114)
  and its paint at
  [#L131-L215](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/fact.rs#L131-L215).
  Copy the inline/stacked split, the wrap under the value column, and the one-column gap.
  Reject the `<fact>` markup tag and the omp2-only `color` prop (see Styling).
- SwiftUI's `LabeledContent` gives the API shape. Its label is drawn in the secondary
  style and its content in the primary style.

## API direction

```swift
public struct LabeledContent<Label: View, Content: View>: View {
    public init(
        @ViewBuilder label: () -> Label,
        @ViewBuilder content: () -> Content
    )
}

extension LabeledContent where Label == Text {
    public init(_ title: String, @ViewBuilder content: () -> Content)
}
```

```swift
LabeledContent("Model") {
    Text("claude-sonnet-4")
}
```

### Styling

`LabeledContent` takes its foreground from the modifier applied to the whole row, as
SwiftUI does. The modifier tints both parts, the same as omp2's `fg`:

```swift
LabeledContent("Build") {
    Text("passing")
}
.foregroundStyle(.success)
```

To tone only the value, style the value view. The label keeps its `secondary` default:

```swift
LabeledContent("Build") {
    Text("passing").foregroundStyle(.success)
}
```

To tone only the label, style the label view:

```swift
LabeledContent {
    Text("cold")
} label: {
    Text("Cache").foregroundStyle(.secondary)
}
```

No `color`-style prop is needed. Styling the label view covers omp2's `color` case.

## Anatomy

Inline rows, 40 columns:

```wireframe 40x4
Model claude-sonnet-4
Session 4f2a9c1e
Branch feature/tree-guides
Workdir ~/src/tessera
```

```text
Callouts (40x4, 0-based):
1. r0-r3 c0..label-1  Label -- LabeledContent label view, secondary role, the label's own width; content, wraps
2. r0-r3 c(label+1)   Gap -- one column, primary role, no shared column across rows
3. r0-r3 value cols   Value -- LabeledContent content view, primary role; content, wraps
```

The value is content like any other, so a single-word value such as the Session row's
`4f2a9c1e` stays whole whenever it fits (its width is its widest word) and breaks between
grapheme clusters only below that, the same as any other word. The Location path is the
same case at a larger scale. (owner decision, 2026-10-18)

```text
── chars ──
Model claude-sonnet-4
Session 4f2a9c1e
Branch feature/tree-guides
Workdir ~/src/tessera
── style ──
AAAAA.BBBBBBBBBBBBBBB
AAAAAAA.BBBBBBBB
AAAAAA.BBBBBBBBBBBBBBBBBBB
AAAAAAA.BBBBBBBBBBBBB
── legend ──
.  default
A  fg=secondary
B  fg=primary
```

## States

### Mobile (40 columns): value wraps under the value column

A value too long for the row beside the label wraps within the remaining width. It keeps
the value column; the label stays on the first line. Stacking follows ViewThatFits, which
compares the unwrapped ideal size: inline only when label width + 1 + the widest value
word fits, else stacked (plan 032 step 14.1; owner decision, 2026-10-10). At 40 columns
the Location row stacks, because its single 56-cell path word does not fit beside the
8-cell label; the path breaks between grapheme clusters. Status stays inline.

```wireframe 40x6
Location
/Users/rob/Developer/robfeldmann/tessera
/main/crates/tui
Status All 312 tests passed on the last
       run and the release build is
       green.
```

```text
Callouts (40x6, 0-based):
1. r0, r3 c0-7    Label -- secondary role; content, wraps
2. r1-r2, r3-r5   Value -- primary role; content. Stacked Location value starts at column 0 and
                  breaks between grapheme clusters; inline Status value wraps within width
                  minus the label column
3. r4-r5          Continuation lines -- indented to the value column, no label
```

```text
── chars ──
Location
/Users/rob/Developer/robfeldmann/tessera
/main/crates/tui
Status All 312 tests passed on the last
       run and the release build is
       green.
── style ──
AAAAAAAA
BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB
BBBBBBBBBBBBBBBB
AAAAAA.BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB
.......BBBBBBBBBBBBBBBBBBBBBBBBBBBB
.......BBBBBB
── legend ──
.  default
A  fg=secondary
B  fg=primary
```

### Minimum (8 columns): stacked

The floor is 8 columns (owner decision, 2026-10-18; it replaces the 12-column floor of
2026-10-10). It is derived under the wrap rules: the widest word in the fixture's primary
content, the labels and the short values, is 8 cells (`Location` and `4f2a9c1e`), so every
label and short value shows whole at 8. At 8 the layout is stacked: the label has its own
row and the value starts at column 0. The Location path is a long unbreakable run, which
breaks between grapheme clusters at any width, so it does not set the floor (a path is
ordinary text, not a special case; main's decision, following rule 1). The fixture takes
18 rows, so the floor is 8x18. Below 8 columns nothing is truncated or dropped: words
break between grapheme clusters, down to one column.

```wireframe 8x18
Location
/Users/r
ob/Devel
oper/rob
feldmann
/tessera
/main/cr
ates/tui
Status
All 312
tests
passed
on the
last run
and the
release
build is
green.
```

```text
Callouts (8x18, 0-based):
1. r0, r8 c0-7    Label -- secondary role, own line; content, wraps
2. r1-r7, r9-r17  Value -- primary role, starts at c0, wraps within 8 columns; content, wraps
```

```text
── chars ──
Location
/Users/r
ob/Devel
oper/rob
feldmann
/tessera
/main/cr
ates/tui
Status
All 312
tests
passed
on the
last run
and the
release
build is
green.
── style ──
AAAAAAAA
BBBBBBBB
BBBBBBBB
BBBBBBBB
BBBBBBBB
BBBBBBBB
BBBBBBBB
BBBBBBBB
AAAAAA
BBBBBBB
BBBBB
BBBBBB
BBBBBB
BBBBBBBB
BBBBBBB
BBBBBBB
BBBBBBBB
BBBBBB
── legend ──
.  default
A  fg=secondary
B  fg=primary
```

### Foreground tones (40 columns)

`.foregroundStyle` on the row tints the label and the value together. The Cache row styles
only its label, so its value keeps `primary`.

```wireframe 40x5
Build passing
Lint 3 warnings
Tests 2 failed
Release v0.9.0-rc.2
Cache cold
```

```text
Callouts (40x5, 0-based):
1. r0 whole row   Build -- foregroundStyle(.success) on the LabeledContent, both parts success
2. r1 whole row   Lint -- foregroundStyle(.warning) on the row
3. r2 whole row   Tests -- foregroundStyle(.error) on the row
4. r3 whole row   Release -- foregroundStyle(.accent) on the row
5. r4 label       Cache -- label view styled secondary, value view left primary
```

```text
── chars ──
Build passing
Lint 3 warnings
Tests 2 failed
Release v0.9.0-rc.2
Cache cold
── style ──
AAAAA.AAAAAAA
BBBB.BBBBBBBBBB
CCCCC.CCCCCCCC
DDDDDDD.DDDDDDDDDDD
EEEEE.FFFF
── legend ──
.  default
A  fg=success
B  fg=warning
C  fg=error
D  fg=accent
E  fg=secondary
F  fg=primary
```

### Bold labels and values (40 columns)

Bold applies per view. A bold label keeps its secondary colour. A value styled inside the
row keeps its own colour.

```wireframe 40x2
Task Refactor the tree gutter renderer
Owner robfeldmann
```

```text
Callouts (40x2, 0-based):
1. r0 c0-3    Task -- label view, secondary bold
2. r0 value   Value -- primary bold
3. r1 c0-4    Owner -- label view, secondary bold
4. r1 value   Value -- accent bold, styled on the value view
```

```text
── chars ──
Task Refactor the tree gutter renderer
Owner robfeldmann
── style ──
AAAA.BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB
AAAAA.CCCCCCCCCCC
── legend ──
.  default
A  fg=secondary bold
B  fg=primary bold
C  fg=accent bold
```

## Variants

| Layout  | Condition                                        | Label            | Value                 |
| ------- | ------------------------------------------------ | ---------------- | --------------------- |
| inline  | label width + 1 + widest value word fits         | beside the value | wraps at value column |
| stacked | label width + 1 + widest value word does not fit | own line         | starts at column 0    |

## State model

Not focusable: no state model.

## Key table

Not focusable: no key table.

## Mouse table

Not focusable: no mouse table.

## Sizing

Schema: [README](../README.md#sizing-table). Mandatory rows: nil x nil, tight,
under-minimum, over-maximum.

| Proposal              | Result                                                                       | Rule                                                                                                                      |
| --------------------- | ---------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| nil x nil             | Inline row at the label width plus one column plus the value's width         | A nil width does not wrap, so a single-line value gives 21x1 for the Model row; height is the value's explicit line count |
| 40 x nil              | Inline when it fits, else stacked; inline value wraps under the value column | Mobile state: Location stacks (56-cell word), Status stays inline; 40x6 fixture                                           |
| 40 x 1 (fixed height) | 40x1                                                                         | One-row budget: the label stays whole and the value's last visible row ends in `…` (owner decision, 2026-10-18)           |
| 8 x nil               | Stacked, value at column 0 wrapping within 8 columns; 8x18 fixture           | Minimum state; floor is 8 (owner decision, 2026-10-18)                                                                    |
| under 8               | Words break between grapheme clusters                                        | Nothing truncated or dropped, down to one column (owner decision, 2026-10-18)                                             |
| over-max              | Single-line inline row; no maximum width                                     | Value takes the proposed width                                                                                            |

## Environment

- Label role `secondary`: [tokens.md](../tokens.md#semantic-styles) `semantic.secondary`.
- Value role `primary`: `semantic.primary`.
- Foreground roles `success`, `warning`, `error`: token pending plan 032 step 5.3.
  [tokens.md](../tokens.md#semantic-styles) defines no such roles.
- `accent`: `semantic.accent`.

## Primitive dependencies

- [Text](../primitives/text.md): value and label wrapping, and the one-row budget's mark.
  Status `ready`.

## Requirements

- `labeled content keeps the label and value inline when both fit on one line` (States:
  Anatomy)
- `labeled content stacks a value whose widest word does not fit beside the label and wraps a long inline value under the value column`
  (States: Mobile)
- `labeled content stacks the value beneath the label at the minimum width` (States:
  Minimum)
- `labeled content wraps the value and the label instead of truncating them` (Anatomy;
  Mobile; Minimum; owner decision, 2026-10-18)
- `labeled content keeps a single-word value whole while it fits and breaks it between grapheme clusters only below its width`
  (Anatomy: Session row; Sizing; owner decision, 2026-10-18)
- `labeled content breaks words between grapheme clusters below the 8-column floor and draws something at every width`
  (States: Minimum; Sizing; owner decision, 2026-10-18)
- `labeled content ends the value's last visible row in an ellipsis under a fixed height`
  (Sizing 40 x 1; owner decision, 2026-10-18)
- `labeled content picks inline or stacked through ViewThatFits` (Variants; owner
  decision, 2026-10-10)
- `labeled content draws the label in the secondary role and the value in the primary role`
  (Anatomy)
- `labeled content foregroundStyle on the row tints the label and the value` (States:
  Foreground tones)
- `labeled content styling the value view leaves the label in the secondary role` (States:
  Foreground tones, Cache)
- `labeled content styling the label view leaves the value in the primary role` (States:
  Foreground tones, Cache)
- `labeled content applies bold per view` (States: Bold)

## Degradation

- `NO_COLOR`: the label and value text still separate the two parts. The secondary label
  loses its dim per the [degradation ladder](../tokens.md#degradation-ladder). Foreground
  tones lose their colour; the text is unchanged.
- 16-colour: roles follow their token rows once plan 032 step 5.3 defines them.
- Below 8 columns: words break between grapheme clusters; nothing is truncated or dropped
  (owner decision, 2026-10-18).

## Open questions

- Foreground roles `success`, `warning`, `error`: no token rows. Unblocks: plan 032 step
  5.3.

## Inspiration

- None yet.
