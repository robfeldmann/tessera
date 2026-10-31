---
name: tui-design
description: Design terminal applications that are useful, look good, and work well, so that what a screen shows, what state it is in, and what the keys do are obvious without explanatory text. Use before building or changing a screen of a TUI (an app, an example, or a Tessera demo) to sketch it, after building to review it from `tessera shot` output, styled grids, or screenshots, or when a screen feels ugly, unclear, or awkward to use.
version: 0.2.0
---

# TUI design

A terminal application is intuitive when someone who has never seen it can say, in a few seconds and without reading a sentence of explanation, what they are looking at, what state it is in, and what they can do next, and when doing it then feels direct. Good TUIs get there by drawing, not by describing: the thing the user is working on is the most prominent thing on screen, its invisible parts are made visible, state changes where the eye already is, and the keys sit beside what they act on. A title line, a "what to watch" sentence, or a bolted-on key list never repairs a screen that fails at this; it adds one more thing to read.

This skill has two modes. **Sketch** runs before a screen is built and produces a wireframe the owner can take in at a glance. **Review** runs after and judges the built screen against the sketch and the checklist. The principles, checklist, and anti-patterns apply to any TUI; [Tessera specifics](#tessera-specifics) at the end maps them onto Tessera's catalog, roles, and commands, and says how Tessera's demos use the skill. The evidence behind every principle is in [Intuitive TUI design](../../../docs/research/intuitive-tui-design.md).

Wireframes here use Tessera's catalog dialect: a `wireframe WxH` fence holds exactly the screen's cells, and a styled grid below it gives each cell a role (`primary`, `secondary`, `border`, `accent`, `focus`, …) or an attribute (`bold`, `dim`, `underline`, `reverse`).

## Principles

### 1. One subject, and it is the loudest thing

Decide what the user is working on, then give that one thing the most weight: the boldest ink, the centre of the space, the largest area. Chrome (titles, rules, legends, status) gets the least. When everything has the same weight, the eye has nowhere to land and starts reading left to right, top to bottom, like prose.

Before: a focus timer whose title, two rules, and key list outweigh the time left, which sits alone at the far right edge.

```wireframe 40x5 id=timer-before
Focus timer
────────────────────────────────────────
Remaining                          24:13
────────────────────────────────────────
space pause   r reset   q quit
```

After: the time is centred and bold, what it belongs to sits quietly under it, and the keys recede into one row.

```wireframe 40x5 id=timer-after

                 24:13
          focus · round 2 of 4

space pause · r reset · q quit
```

```text
── chars ──

                 24:13
          focus · round 2 of 4

space pause · r reset · q quit
── style ──

.................VVVVV
..........DDDDDDDDDDDDDDDDDDDD

KKKKKDDDDDDSSSKDDDDDDSSSKDDDDD
── legend ──
.  default
V  fg=primary bold -- the time left, the one thing that changes
D  fg=secondary -- what the time belongs to, and the key descriptions
K  fg=secondary bold -- keys
S  fg=border -- separators
```

### 2. Draw what is invisible

Much of what a screen is about has no glyph of its own: free space, a container's bounds, padding, a size, a share of a whole, focus, selection. Draw it, quietly, and label it with its measured value, not with a sentence about it. A quantity is understood the moment its extent is visible and its size is a number.

Before: a backup disk described in sentences. The free space, the thing the user wants to know about, is one more number to read.

```wireframe 40x4 id=disk-before
Backup disk
Used: 312 GB of 500 GB (62%)
Photos 180 GB, Mail 72 GB, Misc 60 GB
Free: 188 GB
```

After: the disk is a track, each kind of data a run on it with its size under it, and the free space is the empty part of the track.

```wireframe 40x4 id=disk-after
Backup disk · 312 of 500 GB
██████████████▓▓▓▓▓▓▒▒▒▒▒░░░░░░░░░░░░░░░
Photos        Mail  Misc free
180           72    60   188
```

```text
── chars ──
Backup disk · 312 of 500 GB
██████████████▓▓▓▓▓▓▒▒▒▒▒░░░░░░░░░░░░░░░
Photos        Mail  Misc free
180           72    60   188
── style ──
TTTTTTTTTTTSSSDDDDDDDDDDDDD
PPPPPPPPPPPPPPPPPPPPPPPPPFFFFFFFFFFFFFFF
DDDDDD........DDDD..DDDD.DDDD
NNN...........NN....NN...NNN
── legend ──
.  default
T  fg=primary -- what the screen is about
P  fg=primary -- the used space, one glyph per kind
F  fg=border -- the free space, drawn as a track
N  fg=primary bold -- each run's measured size, in GB
D  fg=secondary -- names and the total
S  fg=border -- separator
```

### 3. Let frames name things

Put a thing's name in its frame (a border title, a tab, a header row) instead of on a line of its own above it. The frame then does three jobs: it groups, it shows the bounds, and it labels, at no cost in rows. Name things by what they mean to the user, never by code (`pane2`, `fill(1)`, `pad+frame`).

Before: headings and rules stack the mail client's two lists, and nothing says which list the keys act on or which mailbox the messages belong to.

```wireframe 40x9 id=mail-before
Mailboxes
────────────────────────────────────────
Inbox 12
Archive
Sent
Messages
────────────────────────────────────────
Ana     Lunch on Friday?
Ben     Re: invoice
```

After: two framed panes side by side, each named in its border; the open mailbox's name and count title the message pane.

```wireframe 40x5 id=mail-after
┌ Mailboxes ┐┌ Inbox · 12 ─────────────┐
│▌Inbox  12 ││ Ana   Lunch on Friday?  │
│ Archive   ││ Ben   Re: invoice       │
│ Sent      ││ Cleo  Slides for Monday │
└───────────┘└─────────────────────────┘
```

```text
── chars ──
┌ Mailboxes ┐┌ Inbox · 12 ─────────────┐
│▌Inbox  12 ││ Ana   Lunch on Friday?  │
│ Archive   ││ Ben   Re: invoice       │
│ Sent      ││ Cleo  Slides for Monday │
└───────────┘└─────────────────────────┘
── style ──
BTTTTTTTTTTTBBTTTTTTTTTTTTBBBBBBBBBBBBBB
BARRRRRRRRRRBB.........................B
B...........BB.........................B
B...........BB.........................B
BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB
── legend ──
.  default
B  fg=border -- frames; each pane's name rides its top border
T  fg=primary -- pane names, and the open mailbox's count
A  fg=accent -- the selection bar
R  reverse -- the selected mailbox
```

### 4. Change state where the eye already is

Every interaction must change something visibly at the place it acts on: a selection moves, a value changes, a label flips, a row re-lays out. Never answer a key press only with a sentence in a status line somewhere else. If a change cannot be seen, the interaction is not finished.

### 5. Keys belong to what they act on

Keys are found in one of two places. Either inside the control they drive (the `-` and `+` beside a value, the underlined key letter of a label, as in a menu bar), or in one quiet legend row that lists only the keys that apply to what has focus and changes when focus moves. A legend uses two inks, the key bolder than its description, and recedes below the content; it is found when wanted and ignored otherwise. A key whose effect is on screen needs no legend entry.

Mark a key letter inside a label with an underline, not with bold or colour alone: the underline survives monochrome and does not compete with the subject's bold. Colour may add to it.

Before: the sort order is narrated under the list, and every key is listed in the same ink as the files.

```wireframe 40x8 id=files-before
Name                Size   Modified
notes.md            4 KB   today
photos/             —      May 2
report.pdf          2 MB   Apr 30
────────────────────────────────────────
sorted by name, ascending
n name  s size  m modified  r reverse
↑↓ move  ⏎ open  d delete  q quit
```

After: each column's label carries its own sort key, the arrow shows the order on the column itself (press the same key again to reverse it), and the legend keeps only the keys that are not already on screen.

```wireframe 40x5 id=files-after
 Name ▲             Size   Modified
▌notes.md           4 KB   today
 photos/            —      May 2
 report.pdf         2 MB   Apr 30
↑↓ move · ⏎ open · d delete · q quit
```

```text
── chars ──
 Name ▲             Size   Modified
▌notes.md           4 KB   today
 photos/            —      May 2
 report.pdf         2 MB   Apr 30
↑↓ move · ⏎ open · d delete · q quit
── style ──
.UDDD.A.............UDDD...UDDDDDDD
ARRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRR


KKDDDDDSSSKDDDDDSSSKDDDDDDDSSSKDDDDD
── legend ──
.  default
U  fg=secondary underline -- each column's sort key, inside its own label
D  fg=secondary -- column labels
A  fg=accent -- the sort direction and the selection bar
R  reverse -- the selected file
K  fg=secondary bold -- keys not already on screen
S  fg=border -- separators
```

### 6. Compare like with like

When a screen shows several of something (accounts, servers, panes, variants), give them identical shapes under one scale and let them differ only where they really differ. A wall of differently shaped blocks reads as an inventory; aligned rows or equal frames read as a comparison.

### 7. Use real content

Content that means something explains the screen by itself: an inbox shows that the highlighted row is the open message, a file list shows that a pane scrolls, an editor's code shows that a pane is the wide one. `Item 0` to `Item 19`, `A B C`, `foo`, and rows of filler dots make the user work out what the structure is for, and they hide the problems real content would show (long names, empty values, wide characters).

### 8. Emphasis with restraint

Use a few roles, not many hues: ordinary content, receding text, structural lines, one accent for the current thing, and a focus style. Every distinction must survive monochrome (bold, dim, reverse, underline, position, a glyph); colour may reinforce a difference but never be the only carrier of it. Prefer whitespace and alignment to rules; a rule between every block flattens the hierarchy it was meant to create.

Selection and focus are different things and never share an attribute. Selection is which item is chosen: reverse video or a fill, with a bar in the gutter. Focus is where the keys go: weight, as a bold label, a heavier frame, or a `❯` cursor. When only attributes are available, keep them apart this way: reverse for selection, bold for focus and for the subject's value, underline for key letters, dim for chrome.

### 9. Design the edges

Empty, loading, error, and too-narrow states are screens too, and they are where users get lost. An empty state says what is absent and how to fill it, ideally in the place the content would appear (a placeholder that is also the affordance). Loading shows progress where the result will appear. An error names what failed next to the thing that failed.

Something that legitimately takes no space (a pane squeezed to nothing, a category with no data, a column hidden by a narrow window) still exists. Keep it named where the user can find it, in a list or legend beside the subject with its value (`Outline 0`), or leave a one-cell mark where it would be. Never let it vanish without trace, and never fake it by drawing space it does not have.

### 10. Fit the viewport

Design at the smallest size first, then decide what the larger sizes gain. When space runs out, drop whole things by priority (a legend entry, a side pane) rather than truncating mid-word or clipping. The exception is a screen whose subject is the cut itself (a truncation setting, a pane squeezed below its content): there, show the cut honestly where it happens, with its ellipsis or clipped edge.

At larger sizes, use the space for the subject: more rows of it, more of its content, a second pane that helps the task. Do not fill space with padding or filler, leave the subject hugging one edge with the rest empty, or stretch a label and its value to opposite edges.

### 11. Motion only for life

Animate only to show that something is live or in progress: a spinner while waiting, a graph that scrolls with time. Motion draws the eye harder than anything else, so it must point at the subject.

## Sketch mode

Run before a screen is built. The output is short enough for the owner to take in at a glance and precise enough to review the built screen against. Record it where the work is reviewed, so the owner can glance at it and the review can compare against it; [Sketching and reviewing a demo](#sketching-and-reviewing-a-demo) names the place for a Tessera slice. The owner's glance never blocks the build: when the owner is away, build against the sketch, and the owner approves or redirects it when reviewing the work.

1. Write the goal in one sentence, for yourself and the owner, not for the screen: who is doing what, and what they need to see ("someone arranging an editor window, watching how wide each pane ends up").
2. List the interactions. Prefer one control that drives the subject through all its states (dragging a window edge, stepping a value) over a key per variant. For each interaction write the key and what visibly changes where.
3. List the states, and for every interaction its extremes: the minimum, the maximum, and the absent case (zero size, nothing selected, empty list, a value that no longer fits). These extremes are drawn, not listed; "states not drawn" is only for states no interaction can reach, because the extremes are where first builds fail.
4. Draw the smallest viewport first, then the largest, as `wireframe WxH` fences at the real sizes, with real content. Where the screen shows computed values (sizes, totals, positions), take them from the rules the toolkit documents and compute them (a throwaway script is fine), so the sketch's numbers can become the tests' expected values; if you cannot, mark them approximate and take the exact ones from the build.
5. Add a styled grid for each wireframe that carries emphasis: which cells are the subject, which recede, which are structure, which mark selection and focus.
6. Write the eye path: the first three things the eye lands on, in order, by region and cell (`r1 c17`). The subject must be first.
7. Write the interaction table. Every "where" must be the subject, the region the eye is on, or the control the key is drawn in; a "where" in a status line elsewhere is a design bug.
8. Run the checklist below against the sketch, then record it.

Output:

````markdown
## Sketch: NAME

Goal: one sentence.

### mobile (40 columns, natural height)

```wireframe 40x7 id=mobile
...
```

(styled grid)

Eye path: 1. r1 c17 the time left; 2. r2 what it belongs to; 3. r4 the keys.

### desktop (80x24)

(wireframe, styled grid, eye path)

### Extremes

(a wireframe per interaction extreme: minimum, maximum, absent)

| Key | What changes | Where |
| --- | --- | --- |
| `space` | the time stops; `paused` replaces the round | the time, r1, and the line under it, r2 |

States not drawn: none (or the states no interaction reaches, and why).
````

## Review mode

Run after the screen is built, on the built screen, and before the work is handed off for review, so the findings are fixed or listed when a reviewer first sees it. Inputs: the sketch, the screen at every viewport, the screen after each interaction and at each extreme, the styles, and a picture of the real terminal when one is available.

1. **Glance test.** Look at the shot for a moment, cover the legend, and write down what you are looking at and the three things the eye lands on, in order. Compare with the sketch's goal and eye path. If you cannot name the subject from the screen alone, that is the first finding. Weight and colour decide the eye path, and text cannot fully show them: confirm it on a picture when one exists, and say so when none does.
2. **Interaction test.** For each row of the interaction table, compare the screen before and after the key, and at each extreme. Which cells changed? Are they the subject or the control, and is the change large enough to notice without comparing row by row? A key whose only visible effect is in a status line, or that has none, is a finding.
3. **Monochrome test.** Read the styles with colour removed. Does every distinction still hold through bold, dim, reverse, underline, position, or a glyph? Are selection and focus still told apart?
4. **Viewport test.** At the smallest size, is anything clipped mid-word that is not the point of the screen, or does chrome crowd out the subject? At the largest, is the space used for the subject?
5. **Checklist pass.**
6. **Report**, ranked:
   - **Blocker:** the subject cannot be named from the screen; an interaction has no visible effect where it acts; something reads as a bug (an overlap that looks like a typo, a focus nobody can see, a thing that vanished without trace).
   - **Major:** the eye lands on chrome first; state narrated instead of shown; keys not tied to what they act on; meaning carried by colour alone; filler instead of real content.
   - **Minor:** weight, spacing, wording, density.

   Each finding gives the evidence (the viewport, the rows and columns, the before and after), the principle it breaks, and the change, as a wireframe fragment when it is not obvious. Judge the screen, not the code; when the cause is in the toolkit rather than the screen, say so.

## Checklist

- [ ] The subject can be named from the screen in a few seconds, and it is the loudest thing on it.
- [ ] The eye lands on the subject first; chrome is the quietest ink.
- [ ] Space, bounds, focus, and selection that matter are drawn, and sizes are shown as numbers.
- [ ] Each group is framed or set apart by whitespace and named in its frame; names are words, not code.
- [ ] Every interaction changes something visible where it acts; no state lives only in a status line.
- [ ] Keys are inside the controls they drive (key letters underlined), or in one quiet legend row for the focused thing, the key bolder than its description.
- [ ] Like things share one shape and differ where they really differ.
- [ ] Content is real.
- [ ] Every distinction survives monochrome; selection and focus use different attributes; one accent at most.
- [ ] Empty, loading, error, narrow, and zero-size states are designed and drawn.
- [ ] The smallest viewport drops whole things (or cuts honestly where the cut is the point); the largest uses its space for the subject.

## Anti-patterns

- **A title line that restates the app's name**, with a full-width rule under it. Name things in their frames.
- **A "what to watch" sentence** or a caption that explains a rule the picture should show.
- **A status line that narrates state** (`sorted by name`, `spacing 1`, `focus=catalog`) away from the thing that changed.
- **A global key list in the content's ink**, listing keys for things that are not on screen or not focused.
- **Rules between every block.** Whitespace and frames group better and stay quieter.
- **Invisible containers**: alignment, padding, or free space shown without the edges that make them visible.
- **Labels in code** (`fill(1) fill(1)`, `pad+frame`) instead of meaning and measured values.
- **Placeholder content** (`Item 0`, `foo`, `A B C`, rows of dots) where real content would explain itself.
- **Specimen sheets**: every variant at once, in different shapes, with no task they serve.
- **Overlaps that read as typos** (`OKatus`) and empties that read as glitches (`[]`) with no frame to explain them.
- **Colour as the only signal**, many hues on chrome, or one attribute carrying both selection and focus.
- **A label and its value at opposite edges** of a wide screen, or the subject hugging one edge with the rest empty.
- **Focus that cannot be seen**, or focus on something that is not on screen.
- **Things that vanish**: a zero-size item that leaves no trace anywhere on screen.

## Tessera specifics

### The dialect and the roles

- Wireframes and styled grids follow [Wireframe conventions](../../../docs/design.md#wireframe-conventions) and [Styled grids](../../../docs/design.md#styled-grids); callouts and region names follow the same page. Validate a sketch kept in a file with `scripts/check-wireframes.py PATH`.
- Roles come from [tokens.md, Roles](../../../docs/design/tokens.md#roles): `primary` for content, `secondary` for receding text (captions, legend keys bold and descriptions), `border` for structural lines, `focus` (bold default foreground, never a fill; [Focus](../../../docs/design/tokens.md#focus) adds the heavy ring and the `❯` cursor), one `accent`, the tones `info`, `success`, `warning`, and `error`, and [Selection](../../../docs/design/tokens.md#selection)'s `selection.fill` and `selection.bar`. In the 16-colour `slots` tier and under `NO_COLOR`, `secondary` and `border` are dim, and under `NO_COLOR` `accent` is bold, so a sketch that only works in colour fails principle 8.
- Until the role environment ships, a screen renders roles with the attributes of that monochrome column: `primary` plain, `secondary` and `border` dim, `focus` bold, `selection.fill` reverse, and `accent` bold or, where bold already marks the subject, a glyph. Key letters are underlined. The harness's grid goldens record those attributes (`dim`, `bold`), so compare a sketch's roles with a build's attributes through this mapping.
- Viewports are named in [tokens.md, Viewports](../../../docs/design/tokens.md#viewports): `desktop` is 80x24; `mobile` is 40 columns at the height the content needs (its natural height); `mobileScreen` is 40x16, for a screen that fills whatever height it is given. Sketch `mobile` first, at its natural height. The harness measures that height from the app's first state, before the app has seen its size, so a screen that adapts to its width should start in its narrow layout.
- A catalog component's look (KeyLegend, Box, Badge, …) is in its doc under `docs/design/`, and a sketch should use that look rather than invent one.
- What every screen can use today: `Text(_:style:)`, whose `Style` takes a foreground, a background, the attributes `bold`, `dim`, `italic`, `reverse`, and `strikethrough`, and an `underlineStyle` (`.single` for a key letter); `Divider`; `HStack`, `VStack`, `ZStack`, `Spacer`, and `Flex`; `frame` and `padding`; `ScrollView` and `SplitView`; and `LeafView` for a view that draws its own cells. A component is available only once [the index](../../../docs/design.md#index) lists it as `implemented`.

### Stand-ins for what the toolkit does not have yet

A design sometimes needs a number or a component Tessera cannot give yet: no view can report the size it was given, and Box and KeyLegend are designed but not built. A screen may then use a stand-in, in this form only:

- One small view, named for what it stands in for, with a comment naming the library piece that replaces it.
- It uses only public API. A measuring stand-in is a `LeafView` that renders the size it was offered (the cells the layout gave it); it never computes what the layout should give, because re-implementing the library's arithmetic would show the screen's arithmetic instead of the library's.
- A key row in the KeyLegend look has exactly one stand-in for all of Tessera's demos (owner decision, 2026-10-30): a single shared view or function in `Examples/Sources/DemoSupport` that every demo calls with its entries and their priorities, with KeyLegend's drop-by-priority rule written once inside it, so that KeyLegend replaces it in one place. A demo never draws its own key row or keeps its own copy of the rule. The first slice whose demo needs a key row builds the shared stand-in; later demos call it.
- The sketch and the pull request list each stand-in as the first thing to delete when the real piece lands.

Anything larger, or anything that hides a library defect, is a workaround, not a stand-in: the library gets the fix.

### Demos are worked applications

A demo is an `Application` in `Examples/Sources/DemoSupport` that conforms to `Demo` (the [`tessera-contributing` skill](../tessera-contributing/SKILL.md) says how to add one). It applies everything above: a demo is a small, concrete application with a goal, a task someone is doing, that the component serves, not a specimen sheet of the component's variants. The component's behaviour then shows as what happens to the task: panes narrowing as a window shrinks, a tag moving when a list is reordered, a message box growing as it wraps. Invent the application first, then make the component the thing that decides how it looks and behaves, with real content throughout. Abstract content (`A B C`, rows of dots, `Item 0`) is the failure this rule exists to prevent.

Demos share one key row: until KeyLegend exists, every demo that shows its keys calls the single KeyLegend stand-in in `DemoSupport` described above, and none draws its own.

The component's own quantities still show, as principle 2 asks, but on the application's own parts. A `Flex` demo as an editor window, with each pane's measured width under it and the constraint it asks for under that:

```wireframe 40x7 id=editor-window
Files       Editor              Docs
main.swift  struct Window: View # Flex
App.swift     Flex(.horizontal) Panes
README.md       Files()         share it
├── 11 ───┤ ├────── 19 ───────┤ ├─ 8 ──┤
length 11   fill 1              length 8
←→ window · ⇥ pane · -+ width · q quit
```

```text
── chars ──
Files       Editor              Docs
main.swift  struct Window: View # Flex
App.swift     Flex(.horizontal) Panes
README.md       Files()         share it
├── 11 ───┤ ├────── 19 ───────┤ ├─ 8 ──┤
length 11   fill 1              length 8
←→ window · ⇥ pane · -+ width · q quit
── style ──
DDDDD.......DDDDDD..............RRRR



BBBBNNBBBBB.BBBBBBBBNNBBBBBBBBB.BBBNBBBB
DDDDDDDDD...DDDDDD..............VVVVVVVV
KKDDDDDDDSSSKDDDDDSSSKKDDDDDDSSSKDDDDD
── legend ──
.  default
D  fg=secondary -- pane names and the constraint each pane asks for
R  reverse -- the selected pane, whose constraint the keys change
V  fg=primary bold -- the selected pane's constraint
B  fg=border -- the run each pane got
N  fg=primary bold -- its width in cells
K  fg=secondary bold -- keys
S  fg=border -- separators
```

The window edge is the one control (`←` `→` change the width offered), `⇥` selects a pane, and `-` `+` change its length; `Editor`, the one `fill`, takes what is left, so its 19 is 40 less the two fixed panes and the two gaps. At the extremes the sketch draws the window just wide enough for the two fixed panes, where `Editor` gets 0 cells and stays named, with its `0`, in a pane list beside the window (principle 9), and a fixed pane wider than the window, cut where the window ends (principle 10's exception). A measuring stand-in draws the width rows, and the key row comes from the shared KeyLegend stand-in in `DemoSupport`, like every demo's.

For a layout component, the sketch's numbers come from the catalog doc's rules (for example [Flex](../../../docs/design/primitives/flex.md)), computed rather than eyeballed; they become the scenarios' `expect node … frame` values. When computing them is impractical, mark them approximate and read the exact frames from `tessera tree` once the demo builds.

### Sketching and reviewing a demo

Every slice that adds or changes a demo has a designer agent with this skill sketch it before it is written, at `mobile` and `desktop`, and review it once it is built. Record the sketch in the slice's pull request description, under `## Demo sketch`, and, when the slice records its evidence on the plan's Progress line, cite the sketch there too. Run the review on the built demo before the slice's critic review hands the pull request to the owner, and put its findings, fixed or listed, in the pull request. The owner glances at the sketch when available; in an unattended run the slice builds against the sketch, and the owner approves or redirects in pull request review.

### Reviewing with the `tessera` commands

The [`tessera` skill](../tessera/SKILL.md) documents each command; contributors run them as `mise run dev:shot`, `dev:tree`, and `dev:run`.

- `tessera shot NAME mobile --pretty` and `tessera shot NAME desktop --pretty` give each viewport's screen as text; read them for the glance and viewport tests.
- `tessera tree NAME mobile --pretty` gives every node's frame, for measuring what the screen draws (is the subject the largest region; where did the space go) and for the exact numbers a sketch marked approximate.
- Before and after each interaction, at each extreme, and the styles: write a scratch scenario outside the repository with one `shot` per state, run it once with `--record`, and read the goldens it writes. `NAME.txt` is the screen; `NAME.grid.txt` is the screen with one style letter per cell, so a grid whose legend is only `.  default` has no emphasis at all. Run it again with `term colors=none` for the monochrome test.

  ```text
  # /tmp/review/counter.scn
  app counter
  size mobile
  term colors=256 theme=dark
  shot before
  type "+"
  shot after-plus
  ```

  `tessera run /tmp/review/counter.scn --record` (or `mise run dev:run …`) writes `/tmp/review/counter/before.txt`, `before.grid.txt`, `after-plus.txt`, and `after-plus.grid.txt`. Never record goldens inside `Examples/Scenarios` for a review.
- A picture: `tessera launch NAME` (`mise run dev:launch NAME`) in a real terminal, and a screenshot of it, from the owner when you have no terminal. Use pictures for weight and colour, which text shots cannot show.
