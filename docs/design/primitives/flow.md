---
kind: primitive
status: ready
---

# Flow

`Flow` is a stateless layout container that places its children left to right in source
order and starts a new line when the next child would pass the proposed width. Each child
keeps its ideal width, capped at the line width, and the lines stack top to bottom. Flow
never splits a child, never stretches or shrinks one to fill a line, and distributes no
surplus. It draws no cells, holds no state, takes no focus and handles no input. `HStack`
never wraps ([stacks decisions](stacks.md#decisions-and-deferred-scope)); Flow is the
wrapping row (key G6 of the [translation key](../translation-key.md);
[fitting](../../docs/Spec.md#flow-layout-and-viewthatfits)). Flow wraps items within one
arrangement, and [ViewThatFits](view-that-fits.md) chooses between arrangements.

## Prior art

- omp2 Row in `wrap` mode
  ([row.rs#L13-L17](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/row.rs#L13-L17))
  "flows children into as many lines as the width allows". Copy its greedy break
  ([row.rs#L106-L143](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/row.rs#L106-L143)):
  a child that would pass the width starts a new line, and a line always keeps its first
  child. Copy the child's pack width, its natural width capped at the line
  ([row.rs#L91-L104](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/row.rs#L91-L104)),
  the wrapping minimum, which is the widest child's rather than the sum
  ([row.rs#L409-L446](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/row.rs#L409-L446)),
  and the height, the sum of each line's tallest child
  ([row.rs#L448-L469](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/row.rs#L448-L469)).
  Reject the per-line track solving (`grow`, percent widths) and the `justify` modes: Flow
  items keep their ideal widths, and weighted allocation belongs to [Flex](flex.md).
  Reject the cross-axis stretch default (key G7) and the `sep` separator chrome, which
  never crosses a line
  ([row.rs#L616-L627](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/row.rs#L616-L627));
  a separator in Tessera belongs inside an item.
- omp2 Tabs
  ([tabs.rs#L183-L199](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/tabs.rs#L183-L199))
  wraps its chips with the same rule: when the next chip would pass the width and the row
  is not empty, a new row starts.
- CSS [flex-wrap](https://developer.mozilla.org/en-US/docs/Web/CSS/flex-wrap) is the web's
  wrapping row. Flow keeps the wrap and start alignment and leaves grow, shrink, and
  `align-content` out.
- Tessera [Slice 2](../../docs/Spec.md#slice-2-the-layout-protocol-and-stack-containers)
  names a trivial flow layout as the proof that the public `Layout` protocol is enough for
  third parties. Flow's algorithm uses only that public surface.

## Anatomy

The tags fixture, at 16 columns:

```swift
Flow(spacing: 1) {
  Text("swift"); Text("terminal"); Text("tui"); Text("layout")
}
```

```wireframe 16x2 id=anatomy
swift terminal
tui layout
```

```text
Callouts (16x2, 0-based):
1. r0 c0-c13  First line -- `swift`, one spacing cell, `terminal`: 14 cells. `tui` would
              make it 18, so `tui` starts the next line.
2. r0 c5      Spacing cell -- `spacing: 1`, only between adjacent items on one line.
3. r1 c0-c9   Second line -- `tui` and `layout`. A line starts at its leading edge with no
              spacing before its first item.
4. r0 c14-c15 Unused width -- Flow reports its widest line, 14 cells, and fills nothing;
              r1 c10-c15 is unused too.
```

Narrower, the items take more lines. At 10 columns `tui layout` fills a line exactly:

```wireframe 10x3 id=narrow
swift
terminal
tui layout
```

```text
Callouts (10x3, 0-based):
1. r0 c0-c4   Line 1 -- `swift`; `terminal` would need 14 cells.
2. r1 c0-c7   Line 2 -- `terminal`; `tui` would need 12 cells.
3. r2 c0-c9   Line 3 -- `tui layout`: 3 + 1 + 6 = 10 cells, exactly the width.
```

The minimum width at which every item stays whole is the widest item's ideal width,
`terminal` at eight cells:

```wireframe 8x4 id=min
swift
terminal
tui
layout
```

```text
Callouts (8x4, 0-based):
1. r1 c0-c7   Widest item -- `terminal` fills the eight cells; it sets the floor.
2. r2-r3      `tui` and `layout` -- together they need ten cells, so each takes a line.
```

Below the minimum an item wider than the line gets a line of its own, proposed the line
width, and wraps by its own rules. Text breaks the word between grapheme clusters
([Text](text.md#wrapping)); nothing is clipped:

```wireframe 6x5 id=under-minimum
swift
termin
al
tui
layout
```

```text
Callouts (6x5, 0-based):
1. r1-r2 c0-c5 Over-wide item -- `terminal` (8 cells) alone on its line, proposed six
               cells; Text breaks it into `termin` and `al`; content, wraps.
2. r4 c0-c5   `layout` -- six cells, exactly the width.
```

## Public vocabulary

```swift
public struct Flow<Content: View>: View {
  public init(
    alignment: Alignment = .topLeading,
    spacing: Int = 0,
    lineSpacing: Int = 0,
    @ViewBuilder content: () -> Content
  )
}
```

Flow is a `View`, like `HStack` and `Flex`, so it can publish `stackAxis` to its items;
its algorithm uses only the public [Layout protocol](../../docs/Spec.md#the-protocol). The
items are the content's direct children, enumerated as a stack enumerates its children.

| Configuration                       | Default       | Effect                                                                                                              |
| ----------------------------------- | ------------- | ------------------------------------------------------------------------------------------------------------------- |
| `spacing: n`                        | 0             | `n` blank cells between adjacent items on one line; none at a line's start or end.                                  |
| `lineSpacing: n`                    | 0             | `n` blank rows between adjacent lines; none above the first line or below the last.                                 |
| `alignment: a`                      | `.topLeading` | `a.horizontal` places each line in Flow's width; `a.vertical` places each item in its line's height.                |
| negative `spacing` or `lineSpacing` | --            | Rejected by `precondition` before layout ([catalog layout decisions](../../docs/Spec.md#catalog-layout-decisions)). |
| no items                            | --            | Reports `0x0` and paints nothing.                                                                                   |
| one item                            | --            | That item alone on one line, proposed the smaller of its ideal width and the width.                                 |
| `.layoutPriority(_:)` on an item    | --            | Ignored: items do not compete for space. Priority on the Flow itself is read by its parent.                         |

Defaults follow the stacks: no gap unless asked for, and top-leading placement. Sums of
item widths, spacing and line heights saturate at `Int.max` rather than wrapping negative,
as in [Flex](flex.md#public-vocabulary).

## Line breaking

This rule is normative. `sizeThatFits` and `placeSubviews` both run it with the proposal's
width, so measurement and placement produce the same lines. For a proposal `W x H` and
items in source order:

1. **Ideal.** Measure each item at `nil x H`. Its ideal width is `wᵢ`.
2. **Slot.** With a finite `W`, each item's slot is `pᵢ = min(wᵢ, W)` cells.
3. **Greedy lines.** The first item opens line 1. Each next item joins the current line
   when the line's slots so far, the spacing between them, one more `spacing`, and `pᵢ`
   add up to at most `W`. Otherwise it opens a new line. A line always takes its first
   item, so an item wider than `W` sits alone on a line, in a slot of the whole width.
4. **Item size.** Measure each item at `pᵢ x H` for its size `sᵢ`. An item never moves to
   a narrower or wider slot to fill a line.
5. **Line size.** A line's width is its slots plus the spacing between them, or wider when
   an item reports more than its slot (a rigid item wider than `W`). Its height is its
   tallest `sᵢ`.
6. **Result.** Flow reports its widest line, and the sum of the line heights plus
   `lineSpacing` between adjacent lines. It never reports the proposal's width just to
   fill it.

A nil width does not wrap: every item is measured at `nil x H` and all of them share one
line. A zero width gives each item of positive ideal width a line of its own.

The height proposal `H` passes through to every item, as an `HStack` passes its height to
its children; it never changes where lines break. Flow is layout, not content, so it has
no row budget of its own: when its lines need more rows than a finite `H`, it reports them
all and its parent clips the trailing lines, as it clips a stack's trailing children
([stack algorithm](../../docs/Spec.md#the-stack-algorithm-normative)). A Flow whose every
line must stay reachable goes in a [ScrollView](../widgets/scroll-view.md).

The lines are stable under their own width. A parent that measures Flow at one width and
then re-proposes the width Flow reported gets the same lines: every line still fits, and
every break was forced at the wider width too. The [stack fixture](#in-stacks-and-flex)
pins this.

## Placement

- Lines go top to bottom from the bounds' top edge, with `lineSpacing` rows between them.
- Each line is offset in the bounds' width by `alignment.horizontal`: leading 0, center
  half the slack rounded down, trailing all of it. Odd slack gives the leading side the
  lower coordinate, as in [Frame](frame.md#variants). Negative slack places the line at 0.
- Items in a line go left to right from the line's offset, one slot each, with `spacing`
  cells between them. Each is placed with the proposal `pᵢ x H` it was measured with.
- Each item is offset in its line's height by `alignment.vertical`: top 0, center half the
  slack rounded down, bottom all of it. Items keep their measured height (key G7).
- Paint order is source order.

### Alignment fixtures

The tags fixture at `16 x nil` reports `14x2` and is placed in `14x2` bounds unless a row
says otherwise. Its first line is 14 cells and its second 10.

| Flow configuration and proposal                                                      | Child frames                                                                 | Rule                                                                        |
| ------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------- | --------------------------------------------------------------------------- |
| tags, `.topLeading`, `16 x nil`                                                      | swift `(0,0) 5x1`; terminal `(6,0) 8x1`; tui `(0,1) 3x1`; layout `(4,1) 6x1` | Lines start at the leading edge; spacing only between items on one line.    |
| tags, `.top`, `16 x nil`                                                             | tui `(2,1) 3x1`; layout `(6,1) 6x1`                                          | The second line has four cells of slack and is offset by two.               |
| tags, `.topTrailing`, `16 x nil`                                                     | tui `(4,1) 3x1`; layout `(8,1) 6x1`                                          | The second line takes all four cells of slack before it.                    |
| tags, `lineSpacing: 1`, `16 x nil`                                                   | tui `(0,2) 3x1`; layout `(4,2) 6x1`; size `14x3`                             | One blank row between the lines; none after the last.                       |
| `Flow(spacing: 1, alignment: .bottomLeading) { Text("a\nb"); Text("c") }`, nil x nil | `a\nb` `(0,0) 1x2`; `c` `(2,1) 1x1`; size `3x2`                              | The line is as tall as its tallest item; `c` sits on the line's bottom row. |
| same with `.leading`, nil x nil                                                      | `c` `(2,0) 1x1`                                                              | Center: one row of slack, rounded down to an offset of 0.                   |

```wireframe 14x2 id=centered
swift terminal
  tui layout
```

```text
Callouts (14x2, 0-based):
1. r0 c0-c13  First line -- 14 cells, no slack.
2. r1 c2-c11  Second line -- `.top` alignment centers it: four cells of slack, two each
              side.
```

```wireframe 14x3 id=line-spacing
swift terminal

tui layout
```

```text
Callouts (14x3, 0-based):
1. r1         Line spacing -- `lineSpacing: 1`, one blank row between the two lines.
```

## Wide graphemes

Every item measures itself in display cells, so a two-cell cluster (CJK, emoji
presentation) counts two, as in [Text](text.md#sizing). Flow breaks only between items and
never splits one, so a wide grapheme never straddles the end of a line: an item whose slot
would pass the width moves whole to the next line. An item wider than the line is proposed
the line width, and Text breaks it between grapheme clusters; a two-cell grapheme in a
one-cell line draws `truncation.mark` in its place ([Text](text.md#wrapping)).

```swift
Flow(spacing: 1) { Text("東京"); Text("大阪"); Text("札幌") }
```

```wireframe 9x2 id=wide
東京 大阪
札幌
```

```text
Callouts (9x2, 0-based):
1. r0 c0-c3   `東京` -- two two-cell graphemes.
2. r0 c4      Spacing cell.
3. r0 c5-c8   `大阪` -- ends exactly at the ninth cell.
4. r1 c0-c3   `札幌` -- would need 14 cells on the first line.
```

```wireframe 8x3 id=wide-narrow
東京
大阪
札幌
```

```text
Callouts (8x3, 0-based):
1. r0 c0-c3   `東京` -- four cells, then four free.
2. r1 c0-c3   `大阪` -- needs one spacing cell and four more, nine in all, so it moves whole
              to the next line rather than split a cluster across the line end.
3. r2 c0-c3   `札幌` -- the same.
```

## In stacks and Flex

To an enclosing `HStack`, `VStack`, or [Flex](flex.md), a Flow is one child. Its ideal (a
nil width) is one line. Its minimum (a zero width) is the widest item's size at width
zero, since each item takes its own line; with Text items that is 0, so the Flow is
flexible. The parent allocates by its own rules, and the Flow wraps within its allocation.
`.layoutPriority(_:)` on the Flow is read by that parent like any child's.

The radio-group pattern, a cursor gutter beside a Flow of items:

```swift
HStack(spacing: 1) {
  Text(">")
  Flow(spacing: 1) { Text("sol"); Text("terra"); Text("kimi"); Text("fable") }
}
```

| Stack proposal and children | Child frames                         | Rule                                                                                                                                                                                                                     |
| --------------------------- | ------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `14 x nil`                  | `>`: `(0,0) 1x1`; Flow: `(2,0) 10x2` | After one spacing cell, 13 cells remain: `>` is offered 7 and takes 1, and the Flow is offered 12. `kimi` would make the first line 14, so it wraps; the Flow reports 10x2 and is re-measured at 10 with the same lines. |
| `nil x nil`                 | `>`: `(0,0) 1x1`; Flow: `(2,0) 20x1` | A nil width is one line: 3 + 1 + 5 + 1 + 4 + 1 + 5 = 20.                                                                                                                                                                 |

```wireframe 14x2 id=in-stack
> sol terra
  kimi fable
```

```text
Callouts (14x2, 0-based):
1. r0 c0      Gutter -- `>`; in Picker's radio group, the focus cursor.
2. r0-r1 c2-c11 Flow -- allocated 10 cells; the second line starts at c2, under the first
              item.
3. r0-r1 c12-c13 Unused width -- the stack reports 12 cells.
```

Flex measures a Flow's ideal and minimum the same way and places it in its resolved
segment, where it wraps.

## Identity and focus

Every item is a structural child of the Flow with its own identity
([identity model](../../docs/Spec.md#identity-model)). A reflow changes frames only: no
node is created or destroyed when items move between lines, so every item's `NodeState`
survives a resize. The focus order is the depth-first source order
([focus model](../../docs/Spec.md#focus-model)), and Flow places items in source order,
line by line, so focus order and reading order agree.

## Sizing

Schema: [README](../README.md#sizing-table). The tags fixture is the one in
[Anatomy](#anatomy): items of 5, 8, 3 and 6 cells with `spacing: 1`.

| Proposal  | Result | Rule                                                                                                        |
| --------- | ------ | ----------------------------------------------------------------------------------------------------------- |
| nil x nil | 25x1   | A nil width does not wrap: one line of ideal widths and three spacing cells.                                |
| 25x1      | 25x1   | Tight: every item fits one line exactly.                                                                    |
| 16 x nil  | 14x2   | `tui` would make the first line 18, so it starts line 2; Flow reports its widest line, 14.                  |
| 10 x nil  | 10x3   | `swift`, `terminal`, then `tui layout` at exactly 10.                                                       |
| 8 x nil   | 8x4    | Minimum: the widest item, `terminal`, stays whole; every item takes its own line.                           |
| 6 x nil   | 6x5    | Under-minimum: `terminal` is alone in a six-cell slot and Text breaks it into two rows; nothing is clipped. |
| 0 x nil   | 0x4    | Zero width: each item takes its own line in a zero slot, and Text reports `0x1`.                            |
| 80x24     | 25x1   | Over-maximum: one line fits; Flow stretches nothing, and the height proposal adds no rows.                  |
| 16x1      | 14x2   | A finite height never changes where lines break: Flow reports both lines, and its parent clips the second.  |

The wide fixture in [Wide graphemes](#wide-graphemes) adds these rows:

| Proposal        | Result | Rule                                                                                                                 |
| --------------- | ------ | -------------------------------------------------------------------------------------------------------------------- |
| wide, nil x nil | 14x1   | One line: three four-cell items and two spacing cells.                                                               |
| wide, 9 x nil   | 9x2    | Two items fit nine cells exactly; the third starts line 2.                                                           |
| wide, 8 x nil   | 4x3    | A second item would need nine cells, so each item takes a line, whole.                                               |
| wide, 3 x nil   | 3x6    | Each item is wider than the line: alone in a three-cell slot, where Text puts each two-cell grapheme on its own row. |

## Environment

Flow consumes no token. Like `HStack`, it publishes `stackAxis` `.horizontal` to its
items, because each line runs horizontally ([Linear stacks](stacks.md#environment)). A
`Divider` item is therefore a one-column vertical rule. Flow proposes items its own
height, so under a nil height that rule is one row.

| Value                  | Source                               | Default | Effect                                                  |
| ---------------------- | ------------------------------------ | ------- | ------------------------------------------------------- |
| `Subview.priority`     | existing `.layoutPriority(_:)` value | 0       | ignored for items; the Flow's own is read by its parent |
| descendant `stackAxis` | Flow                                 | --      | `.horizontal`: a Divider item renders the vertical rule |

## Consumers

- [Picker radio group](../widgets/picker.md#radio-group), and
  [MultiPicker's](../widgets/multi-picker.md): a cursor gutter beside
  `Flow(spacing: 1) { chips }`, as in the [stack fixture](#in-stacks-and-flex). Wrapped
  lines start under the first chip; a chip wider than the line is proposed the line width
  and tail-truncates by its own one-row rule; a nil width keeps every chip on one line.
- [TabView](../widgets/tab-view.md): the bar wraps its chips onto more rows with Flow (key
  G6); no chip wraps internally.

## Requirements

Schema: [README](../README.md#requirements-list).

- `flow lays out one line of ideal widths under a nil width` (sizing: nil x nil)
- `flow fits every item on one line at a tight width` (sizing: 25x1)
- `flow starts a new line when the next item would pass the width` (line breaking: step 3;
  sizing: 16 x nil; anatomy)
- `flow puts spacing only between items on the same line` (anatomy: spacing cell and
  second line; alignment fixtures: tags, `.topLeading`)
- `flow reports its widest line and fills no extra width` (line breaking: step 6; sizing:
  16 x nil and 80x24)
- `flow keeps every item whole down to the widest item` (sizing: 8 x nil; anatomy: min)
- `flow gives an item wider than the line a line of its own at the line width` (line
  breaking: step 3; sizing: 6 x nil; anatomy: under-minimum)
- `flow puts each item on its own line under a zero width` (sizing: 0 x nil)
- `flow never splits an item at a wide grapheme` (wide graphemes; sizing: wide, 8 x nil;
  anatomy: wide-narrow)
- `flow measures wide graphemes in display cells` (sizing: wide, 9 x nil; anatomy: wide)
- `flow ignores a finite height when it breaks lines` (sizing: 16x1)
- `flow makes each line as tall as its tallest item` (line breaking: step 5; alignment
  fixtures: `.bottomLeading` row)
- `flow aligns lines horizontally and items vertically by its alignment` (alignment
  fixtures: `.top`, `.topTrailing`, `.bottomLeading`, and `.leading` rows; anatomy:
  centered)
- `flow puts line spacing rows only between lines` (alignment fixtures: `lineSpacing: 1`;
  anatomy: line-spacing)
- `flow rejects negative spacing and line spacing before layout` (public vocabulary:
  negative `spacing` or `lineSpacing`)
- `empty flow reports zero and paints nothing` (public vocabulary: no items)
- `flow ignores layout priority on its items` (public vocabulary: `.layoutPriority(_:)` on
  an item; environment: `Subview.priority`)
- `flow wraps within its allocation in a stack` (in stacks and Flex: `14 x nil`; anatomy:
  in-stack)
- `flow keeps its lines when a stack re-proposes its reported width` (in stacks and Flex:
  `14 x nil`)
- `flow paints items in source order` (placement: paint order)
- `flow item node state survives a reflow` (identity and focus; sizing: 16 x nil and 10 x
  nil)
- `flow publishes a horizontal stack axis to its items` (environment: descendant
  `stackAxis`)

## Degradation

Flow emits no cells and reads no terminal capability. Items measure themselves at the
active rung of the [degradation ladder](../tokens.md#degradation-ladder), so a fallback
glyph of a different width can move a line break; Picker keeps its chip widths equal at
every rung for that reason. Breaking, placement and paint order are otherwise identical at
every rung.

## Decisions

- **Items keep their ideal widths.** Flow distributes no surplus and compresses nothing;
  `Spacer` and other flexible items take their nil-width ideal. Weighted allocation is
  Flex's, and Flex keeps one policy rather than start, end and space-around modes
  ([Flex decisions](flex.md#decisions)), so Flow has no `justify`.
- **One `Alignment`.** Its horizontal part places lines and its vertical part places items
  in a line, reusing the type `ZStack` and `frame` take, with the stacks' top-leading
  default.
- **No row cap and no separators.** Collections and stacks take no cap (key B8); a Flow
  that must stay reachable scrolls. omp2's `sep` chrome is not carried over; a separator
  belongs inside an item.
- **Rows only.** Flow wraps a horizontal row. A column that wraps into new columns has no
  1.0 consumer.
- **The name.** `Flow` follows the [inbox](../inbox.md) entry of 2026-08-24, key G6 ("Flow
  layout"), and the catalog's container names without a suffix (`HStack`, `Flex`, `Grid`).

This contract was reviewed against the
[Phase 4 theses](../../docs/Spec.md#phase-4--view-layer-the-tessera-module). Flow is a
value, and its lines are a pure function of the proposal and the items' measured sizes.
Its frames show in `dump()`. It retains nothing, so a reflow moves frames and never state,
and it has no capability of its own.

## Open questions

- None.

## Inspiration

Tag lists, filter chips and key hints in a status area all want "as many per line as fit,
in order, never cut off". Picker's radio group and TabView's bar are the first two, and a
Flow inside a `ViewThatFits` candidate covers the case where an arrangement also changes
shape when it wraps.
