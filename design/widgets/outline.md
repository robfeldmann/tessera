---
kind: widget
status: wireframed
---

# Outline

`Outline` is Tessera's focusable, virtualized hierarchy: a vertical run of rows where
branches expand and collapse. Each row can carry an expander, a status column, a lead
icon, and a label. It is the 1.0 home for omp2's `Tree` and for the path mode of its
`Files` view. It is controlled in the same sense as [List](list.md): the app supplies the
nodes and binds selection as `Binding<ID?>`, like List, and expansion as
`Binding<Set<ID>>`. Outline owns only an ephemeral scroll offset (owner decision,
2026-10-10).

Outline scrolls itself, like [List](list.md) and [Table](table.md). When its rows are
taller than the space it has, it reserves its last column and mounts the shared
[ScrollIndicator](../primitives/scroll-indicator.md), using the
[ScrollView](scroll-view.md) styles the app chose. The app does not wrap an Outline in a
`ScrollView`. Owner decision, omp2 review, 2026-10.

## Prior art

- omp2 `Tree`,
  [tree.rs](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/tree.rs#L61-L120)
  (builders),
  [L369-L515](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/tree.rs#L369-L515)
  (paint),
  [L516-L609](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/tree.rs#L516-L609)
  (keys),
  [L610-L664](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/tree.rs#L610-L664)
  (mouse), and
  [L990-L1026](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/tree.rs#L990-L1026)
  (virtualization test). Copy the virtualized rows, the guide families, the selection
  rail, and the open and closed expanders. Reject the single lead slot: owner decision,
  omp2 review, 2026-10, is that a status column and an icon both show. Reject the missing
  scroll position indicator. Decorated rows, annotations and action chips are post-1.0
  (owner decision, 2026-10-10).
- omp2 `Files`,
  [files.rs](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/files.rs#L72-L143)
  (rebuild),
  [L158-L228](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/files.rs#L158-L228)
  (paint), and
  [L230-L298](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/files.rs#L230-L298)
  (split and flatten). Copy path folding (single-child directory chains become one row
  joined by `/`) and bold directories. Reject the root heading as drawn (accent and bold,
  no icon): owner decision, omp2 review, 2026-10, puts a folder icon before the `/`.
- omp2 glyph families and expanders,
  [context.rs](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/context.rs#L132-L156).
  Glyphs are resolved through the [Label](../primitives/label.md) icon catalog where a
  name exists. `folder-open`, `folder` and `file` are owner-agreed catalog additions
  (owner decision, 2026-10-10).
- Lazygit's working-tree view is the owner's comparison for the file-tree states: a folder
  icon before the root, and a status column shown before the file icon rather than
  replacing it.

## Anatomy

A changed-files tree at 40 columns, Unicode charset: the root row, two open folders, one
closed folder, and files with two-letter git status letters in a status column. Rows read
left to right: expander, status column, lead icon, label. The status column is a fixed two
cells wide (owner decision, omp2 review, 2026-10). The owner's grid shows the selected row
with its status colours; the styled grid follows the callouts.

```wireframe 40x9
▾ 📂 /
  ▾ 📂 .agents/plans
    ?? 📄 014-collections-and-tables.md
   M 📄 .codespellrc
  ▸ 📁 Examples/TesseraDemos
  ▾ 📂 design
     M 📄 README.md
    AM 📄 component-index.md
    ▸ 📁 screenshots
```

```text
Callouts (40x9, 0-based):
0. r0 c0        Expander -- `disclosure.expanded` `▾` (ASCII `v`), muted; the root is open;
                chrome, one row
1. r0 c2-c3     Lead icon -- open folder 📂 (U+1F4C2), accent; the root's folder icon
                sits before `/`; chrome, one row
2. r0 c5        Label -- root `/`, bold primary; content, one row (wrap exception)
3. r2 c4-c5     Status column -- two-cell slot; `??` in `error` (untracked), before the
                icon; chrome, one row
4. r2 c7-c8     Lead icon -- file 📄 (U+1F4C4), accent; one column right of a folder
                icon at the same depth; chrome, one row
5. r2 c10-c37   Label -- file name, primary; content, one row (wrap exception), tail
                truncates
6. r3 c3        Status column -- `M` in `warning` (modified), right-aligned in its slot
7. r4 c2        Expander -- `▸` collapsed folder, muted (ASCII `>`)
8. r4 c4-c5     Lead icon -- closed folder 📁 (U+1F4C1), accent
9. r4 c7-c26    Label -- folder name, bold primary; content, one row (wrap exception)
10. r7 c4-c5    Status column -- `AM` in `success` (added) on the selected row
11. r7 c0-c38   Selection row -- `selection.fill` (reverse video) across the row, from the owner's grid
12. r0-r8 c0-c39  Row -- any cell of a row; the mouse region `Row`
```

> Wrap exception (rule 1): rows stay single-line and the label tail-truncates. The
> expander, status, and icon columns and the tree guides need one row per node. (owner
> decision, 2026-10-18)

Outline pins `lineLimit(1)` on each label, so an app's inherited `lineLimit` never adds
rows; the label's `truncationMode` still comes from the environment (default tail).

```text
── chars ──
▾ 📂 /
  ▾ 📂 .agents/plans
    ?? 📄 014-collections-and-tables.md
   M 📄 .codespellrc
  ▸ 📁 Examples/TesseraDemos
  ▾ 📂 design
     M 📄 README.md
    AM 📄 component-index.md
    ▸ 📁 screenshots
── style ──
EEIIID
..EEIIIDDDDDDDDDDDDD
....RRNIIINNNNNNNNNNNNNNNNNNNNNNNNNNNNN
..NWNIIINNNNNNNNNNNN
..EEIIIDDDDDDDDDDDDDDDDDDDDD
..EEIIIDDDDDD
....NWNIIINNNNNNNNN
LLLLswLllLLLLLLLLLLLLLLLLLLLLLLLLLLLLLL
....EEIIIDDDDDDDDDDD
── legend ──
.  default
E  fg=muted
I  fg=accent
N  fg=primary
D  fg=primary bold
R  fg=error
W  fg=warning
L  fg=primary, selection.fill
l  fg=accent, selection.fill
s  fg=success, selection.fill
w  fg=warning, selection.fill
```

## States

### Scrolled

Rows taller than the viewport scroll to keep the selection visible, and the last column
shows where the viewport sits. Twelve rows with four visible, scrolled down seven, gives a
one-cell thumb on the third row: the thumb length is `max(1, floor(4 × 4 / 12)) = 1`, and
its row is `floor(7 × (4 − 1) / (12 − 4)) = 2`. The selection highlight stops at column
38, one column before the indicator.

```wireframe 40x4
  │ └─ lib.rs                          │
  ├─ ▾ vocab                           │
  │ └─ lib.rs                          █
▌ └─ ▾ tessera                         │
```

```text
Callouts (40x4, 0-based):
0. r0-r3 c0-c38  Viewport -- the Outline's rows, clipped to 39 columns; the scroll track
                 begins at c39
1. r0-r3 c39     Scroll track -- ScrollIndicator, `muted` `│` (default track)
2. r2 c39        Scroll thumb -- `accent` `█`, one cell at row 2 (see the formulas above)
3. r3 c0         Selection bar -- `▌` (`selection.bar`) in `accent`, on the selected row only
4. r3 c0-c38     Selection highlight -- `selection.fill` (reverse video); stops one column before the indicator
5. r0-r3 c2-c4   Tree guides -- `muted` `│` and `└─` / `├─`, depth lines
```

```text
── chars ──
  │ └─ lib.rs                          │
  ├─ ▾ vocab                           │
  │ └─ lib.rs                          █
▌ └─ ▾ tessera                         │
── style ──
AABBBBBCCCCCC..........................T
AABBBBBCCCCC...........................T
AABBBBBCCCCCC..........................U
DDEEEEEFFFFFFFGGGGGGGGGGGGGGGGGGGGGGGGGT
── legend ──
.  default
A  fg=accent
B  fg=muted
C  fg=primary
D  fg=accent, selection.fill
E  fg=muted, selection.fill
F  fg=primary, selection.fill
G  selection.fill
T  fg=muted
U  fg=accent
```

### Mobile

The 40-column tree from omp2's `Tree` at its default settings: two open branches, one
closed branch, and a leaf, with plain indentation and no tree guides. The selected row is
the root, with a `selection.fill`. The six rows fit the viewport with no scroll indicator.

```wireframe 40x6
▌ ▾ services
   ▾ api
      auth
      billing
   ▸ workers
     edge
```

```text
Callouts (40x6, 0-based):
0. r0 c0         Selection bar -- `▌` (`selection.bar`) in `accent`; the selected root row has a
                 `selection.fill` across c0-c39
1. r0 c2         Expander -- `▾` open root branch, muted
2. r0 c4-c10     Label -- `services`, primary on `selection.fill`
3. r1 c3         Expander -- `▾` open branch `api`, muted
4. r2 c6-c9      Leaf -- `auth`; two cells of plain indentation per depth, no expander
5. r4 c3         Expander -- `▸` collapsed branch `workers`, muted
6. r5 c5-c8      Leaf -- `edge`
```

```text
── chars ──
▌ ▾ services
   ▾ api
      auth
      billing
   ▸ workers
     edge
── style ──
ADBDCCCCCCCCDDDDDDDDDDDDDDDDDDDDDDDDDDDD
EE.FFGGG
EE..FFGGGG
EE..FFGGGGGGG
EE.FFGGGGGGG
EE.FFGGGG
── legend ──
.  default
A  fg=accent, selection.fill
B  fg=muted, selection.fill
C  fg=primary, selection.fill
D  selection.fill
E  fg=accent
F  fg=muted
G  fg=primary
```

### Declared minimum

The owner accepted this floor of 12 columns by 3 rows (owner decision, 2026-10-10). No
owner grid exists at this size, so it is derived with the scrolled rule. The content is 12
rows and the viewport 3: the thumb length is `max(1, floor(3 × 3 / 12)) = 1`, and at
scroll offset 5 its row is `floor(5 × (3 − 1) / (12 − 3)) = 1`, the position the mock
draws. Labels truncate with `…` before the indicator column, as the wrap exception
requires. Below the floor, labels truncate at the tail (see [Sizing](#sizing)); rows never
wrap, so the floor is not re-derived from whole words.

```wireframe 12x3
▌ ▾ vocab  │
  ├─ tesse…█
  └─ ben…  │
```

```text
Callouts (12x3, 0-based):
0. r0 c0-c10   Viewport -- three rows, labels truncated with `…`
1. r0-r2 c11   Scroll track and thumb -- ScrollIndicator; `muted` `│` track, `accent` `█`
               thumb at r1
2. r0 c0       Selection bar -- `▌` in `accent` on the selected row
```

### Path mode

The `Files` path mode: four input paths become one hierarchy. Directories with a single
child folder fold into one row (`coding-agent/src/tools`, `tui/README.md`), so a deep
chain reads as one path. Directory rows are bold and guides are muted. Path mode uses the
tree's keys and mouse, and its overflow follows the tree: Outline scrolls itself, and the
indicator uses the ScrollView styles the app chose (owner decision, 2026-10-10).

```wireframe 40x6
└─ packages
  ├─ coding-agent/src/tools
  │ ├─ read.ts
  │ ├─ write.ts
  │ └─ bash.ts
  └─ tui/README.md
```

```text
Callouts (40x6, 0-based):
0. r0 c0-c2     Root guide -- `└─` muted
1. r0 c3-c10    Root label -- `packages`, bold; a relative path, no leading `/`
2. r1 c2-c4     Branch guide -- `├─` muted
3. r1 c5-c26    Folded directory -- `coding-agent/src/tools`, bold; single-child folders
                joined with `/` into one row
4. r2-r4 c2     Continuation -- `│` muted under the branch
5. r5 c2-c4     Last branch guide -- `└─` muted
6. r5 c5-c17    File -- `tui/README.md`, default style; a path with `/` stays one row
```

```text
── chars ──
└─ packages
  ├─ coding-agent/src/tools
  │ ├─ read.ts
  │ ├─ write.ts
  │ └─ bash.ts
  └─ tui/README.md
── style ──
AAABBBBBBBB
AAAAABBBBBBBBBBBBBBBBBBBBBB
AAAAAAA.......
AAAAAAA........
AAAAAAA.......
AAAAA.............
── legend ──
.  default
A  fg=muted
B  bold
```

### Icon charsets

The Nerd Font and ASCII charsets change only the glyphs. Expanders, status letters, and
styles are the same as [Anatomy](#anatomy). In the owner's ASCII grid, the expanders are
`v` and `>`, and the icons use the icon catalog's text forms `[O]` (open folder), `[D]`
(closed folder), and `[F]` (file).

#### Nerd Font

```wireframe 40x9
▾  /
  ▾  .agents/plans
    ??  014-collections-and-tables.md
   M  .codespellrc
  ▸  Examples/TesseraDemos
  ▾  design
     M  README.md
    AM  component-index.md
    ▸  screenshots
```

```text
Callouts (40x9, 0-based):
0. r0 c2        Lead icon -- open folder U+F07C, accent; one cell wide
1. r2 c7        Lead icon -- file U+F15B, accent
2. r4 c4        Lead icon -- closed folder U+F07B, accent
3. r2 c4-c5     Status column -- `??` in `error`; the same slot as Anatomy callout 3
```

```text
── chars ──
▾  /
  ▾  .agents/plans
    ??  014-collections-and-tables.md
   M  .codespellrc
  ▸  Examples/TesseraDemos
  ▾  design
     M  README.md
    AM  component-index.md
    ▸  screenshots
── style ──
EEIID
..EEIIDDDDDDDDDDDDD
....RRNIINNNNNNNNNNNNNNNNNNNNNNNNNNNNN
..NWNIINNNNNNNNNNNN
..EEIIDDDDDDDDDDDDDDDDDDDDD
..EEIIDDDDDD
....NWNIINNNNNNNNN
LLLLswLlLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLL
....EEIIDDDDDDDDDDD
── legend ──
.  default
E  fg=muted
I  fg=accent
N  fg=primary
D  fg=primary bold
R  fg=error
W  fg=warning
L  fg=primary, selection.fill
l  fg=accent, selection.fill
s  fg=success, selection.fill
w  fg=warning, selection.fill
```

#### ASCII

```wireframe 40x9
v [O] /
  v [O] .agents/plans
    ?? [F] 014-collections-and-tables.md
   M [F] .codespellrc
  > [D] Examples/TesseraDemos
  v [O] design
     M [F] README.md
    AM [F] component-index.md
    > [D] screenshots
```

```text
Callouts (40x9, 0-based):
0. r0 c0        Expander -- `v` open, the ASCII form of `disclosure.expanded`
1. r0 c2-c4     Lead icon -- `[O]` open folder, accent
2. r2 c4-c5     Status column -- `??` in `error`, unchanged from Unicode
3. r2 c7-c9     Lead icon -- `[F]` file, accent
4. r4 c2        Expander -- `>` collapsed, the ASCII form of `disclosure.collapsed`
5. r4 c4-c6     Lead icon -- `[D]` closed folder, accent
```

```text
── chars ──
v [O] /
  v [O] .agents/plans
    ?? [F] 014-collections-and-tables.md
   M [F] .codespellrc
  > [D] Examples/TesseraDemos
  v [O] design
     M [F] README.md
    AM [F] component-index.md
    > [D] screenshots
── style ──
EEIIIID
..EEIIIIDDDDDDDDDDDDD
....RRNIIIINNNNNNNNNNNNNNNNNNNNNNNNNNNNN
..NWNIIIINNNNNNNNNNNN
..EEIIIIDDDDDDDDDDDDDDDDDDDDD
..EEIIIIDDDDDD
....NWNIIIINNNNNNNNN
LLLLswLlllLLLLLLLLLLLLLLLLLLLLLLLLLLLLL
....EEIIIIDDDDDDDDDDD
── legend ──
.  default
E  fg=muted
I  fg=accent
N  fg=primary
D  fg=primary bold
R  fg=error
W  fg=warning
L  fg=primary, selection.fill
l  fg=accent, selection.fill
s  fg=success, selection.fill
w  fg=warning, selection.fill
```

## State model

Schema: [README](../README.md#state-model-table).

| State          | Owner       | Type                            | Reset or clamp rule                                                                                                  |
| -------------- | ----------- | ------------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| selection      | Binding     | `Binding<ID?>`                  | app-owned; Outline writes it through the binding on a key or click; single selection, like List                      |
| expansion      | Binding     | `Binding<Set<ID>>`              | app-owned; Outline writes it through the binding on →, ←, Enter, or an expander click                                |
| scroll offset  | NodeState   | `Int` (rows above the viewport) | clamps to content bounds on every update; keeps the selection visible; rows are single-line, so one row is one node  |
| row line limit | Environment | `Int?` pinned to 1              | Outline pins `lineLimit(1)` on each label (Wrap exception); an inherited app `lineLimit` never changes the row count |

Selection and expansion are app-owned bindings (owner decision, 2026-10-10), so they
appear in the table as `Binding` rows. The scroll offset is Outline's own.

## Key table

The omp2 `Tree` key handling
([tree.rs L516-L609](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/tree.rs#L516-L609))
is the baseline the owner agreed (owner decision, 2026-10-10). Path mode uses the same
keys.

| Key   | Precondition              | Effect                                                                                                                 | Consumed                        |
| ----- | ------------------------- | ---------------------------------------------------------------------------------------------------------------------- | ------------------------------- |
| ↓     | focused                   | moves selection to the next row via the selection binding                                                              | yes                             |
| ↑     | focused                   | moves selection to the previous row via the selection binding                                                          | yes                             |
| →     | focused, selection is set | on a collapsed branch, expands it via the expansion binding; on an expanded branch, moves selection to its first child | conditional (not on a leaf)     |
| ←     | focused, selection is set | on an expanded branch, collapses it via the expansion binding; otherwise moves selection to the parent                 | conditional (not on a root row) |
| Enter | focused, selection is set | toggles expansion of the selected branch via the expansion binding                                                     | conditional (not on a leaf)     |

## Mouse table

The omp2 `Tree` mouse handling
([tree.rs L610-L664](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/tree.rs#L610-L664))
is the baseline the owner agreed (owner decision, 2026-10-10). Regions are named in the
Anatomy callouts.

| Event      | Region   | Precondition     | Effect                                                          | Consumed |
| ---------- | -------- | ---------------- | --------------------------------------------------------------- | -------- |
| click      | Row      | always           | sets the selection to the clicked row via the selection binding | yes      |
| click      | Expander | always           | toggles the row's expansion via the expansion binding           | yes      |
| wheel-up   | Row      | offset above 0   | decrements the scroll offset in NodeState                       | yes      |
| wheel-down | Row      | offset below max | increments the scroll offset in NodeState                       | yes      |

## Sizing

Owner decisions, 2026-10-10: a `nil x nil` proposal sizes to the widest row by the row
count, 39x9 for the Anatomy tree. Under the [declared minimum](#declared-minimum), labels
truncate at the tail, because rows are single-line (see the wrap exception in
[Anatomy](#anatomy)). The tight-fit row is that ideal proposed back; the over-maximum row
fills the proposal as List and Table do, since Outline scrolls itself like them.

| Proposal  | Result | Rule                                                                                                                               |
| --------- | ------ | ---------------------------------------------------------------------------------------------------------------------------------- |
| nil x nil | 39x9   | widest row by the row count                                                                                                        |
| 39 x 9    | 39x9   | tight fit: the proposal equals the ideal, so every row fits and no indicator column is reserved                                    |
| 10 x 2    | 10x2   | under the declared minimum, labels truncate at the tail                                                                            |
| 80 x 20   | 80x20  | over the maximum: fills the proposal like List and Table; rows keep their one-row height and the rows below the content stay blank |

## Environment

Tokens consumed, each defined in [tokens.md](../tokens.md) unless marked.

- `primary` -- `semantic.primary`; labels, root and folder names with `bold`.
- `accent` -- `semantic.accent`; open and closed folder icons, file icons, the selection
  bar, and the scroll thumb.
- `selection.bar` (`▌`) and `selection.fill` (reverse video), as in [List](list.md): the
  selected row.
- `muted` -- token pending plan 032 step 5.3. Expanders, guides, and the scroll track.
- `error`, `warning`, `success` (status letters) -- token pending plan 032 step 5.3.
- `scrollbar.weight` -- token pending plan 032 step 5.3. This doc uses the ScrollIndicator
  default.
- `scrollbar.track` -- the [ScrollIndicator](../primitives/scroll-indicator.md) axes,
  supplied by the app's ScrollView style.

## Primitive dependencies

- [ScrollIndicator](../primitives/scroll-indicator.md) (`specified`): the trailing
  indicator when rows overflow; the default look is `█` over `│` (owner decision,
  2026-10-10).
- [Label](../primitives/label.md) (`wireframed`): icon names. Owner decision, 2026-10-10:
  the catalog gains `folder-open` (`[O]`), `folder` (`[D]`) and `file` (`[F]`) rows.
- [Badge](../primitives/badge.md) (`wireframed`): not used for the status column, which is
  a plain two-cell letter slot, not a capsule. Badge stays for capsule counts, as in List.
- [Text](../primitives/text.md#row-budget) (`ready`): `lineLimit(1)` and
  [truncation](../primitives/text.md#truncation) on each label; blocks `ready` until the
  Text wrapping slice lands (`Sources/TesseraCore/Views/Text.swift` is still the
  non-wrapping Slice 1 leaf).

## Requirements

Schema: [README](../README.md#requirements-list). Traced to the states and tables above.

- `scrolls itself without a ScrollView wrapper` (Scrolled)
- `reserves the last column for the vertical indicator when rows overflow` (Scrolled)
- `stops the selection highlight one column before the indicator` (Scrolled)
- `thumb length and row follow the scrolled formulas` (Scrolled)
- `draws the selected row with selection.bar and selection.fill` (Scrolled)
- `shows a folder icon before the root slash` (Anatomy)
- `shows the status column before the lead icon` (Anatomy)
- `keeps status columns two cells wide so icons align with expanders` (Anatomy)
- `colours each status letter by its git status` (Anatomy)
- `draws folders bold with open and closed folder icons` (Anatomy)
- `draws plain indentation without tree guides` (Mobile)
- `shows one cell of thumb in a three-row viewport at the declared minimum` (Declared
  minimum)
- `folds single-child directory chains into one row` (Path mode)
- `uses the tree keys and mouse in path mode` (Path mode)
- `renders expanders as v and > and icons as [O], [D] and [F] in ASCII` (ASCII)
- `binds selection as Binding<ID?> and expansion as Binding<Set<ID>>, both app-owned`
  (State model)
- `moves selection with the up and down arrows` (Key table)
- `expands, collapses and moves selection with the left and right arrows` (Key table)
- `toggles a branch on Enter` (Key table)
- `selects a row on click and toggles a branch on expander click` (Mouse table)
- `scrolls the rows on wheel-up and wheel-down` (Mouse table)
- `sizes a nil x nil proposal to the widest row by the row count` (Sizing)
- `truncates labels at the tail below the declared minimum` (Sizing)
- `keeps rows single-line under an inherited line limit` (Anatomy: wrap exception)
- `sizes a tight-fit proposal to the ideal with no indicator column` (Sizing: 39 x 9)
- `fills an over-maximum proposal and leaves rows below the content blank` (Sizing: 80
  x 20)
- `draws git status letters as plain text under NO_COLOR with nothing added` (Degradation:
  NO_COLOR)

## Degradation

Reference the [degradation ladder](../tokens.md#degradation-ladder).

- ASCII: the scroll indicator uses `scrollbar.ascii` (`|` track, `#` thumb), expanders
  become `v` and `>`, icons become `[O]`, `[D]` and `[F]`, and the status letters keep
  their text (owner grid).
- `NO_COLOR`: the git status letters are the cue. They stay plain text in their two-cell
  slot and nothing is added: no marker, glyph, or word (owner decision, 2026-10-18).
- Below the floor: labels truncate at the tail (see [Sizing](#sizing)).

## Open questions

None open.

## Inspiration

Triage destination for inbox entries about this component.
