---
name: tui-design
description: Sketch a terminal screen before it is built and review it after, so that what it shows, what state it is in, and what the keys do are obvious without explanatory text. Use before building or changing a demo, an example app, or any screen of a Tessera app, when reviewing one from `tessera shot` output, a styled grid, or a screenshot, or when a screen feels ugly or unclear.
version: 0.1.0
---

# TUI design

A terminal screen is intuitive when someone who has never seen it can say, in a few seconds and without reading a sentence of explanation, what they are looking at, what state it is in, and what they can do next. Good TUIs get there by drawing, not by describing: the subject is the most prominent thing on screen, its invisible parts are made visible, state changes where the eye already is, and the keys sit beside what they act on. A title line, a "what to watch" sentence, or a bolted-on key list never repairs a screen that fails at this; it adds one more thing to read.

This skill has two modes. **Sketch** runs before a screen is built and produces a wireframe the owner can take in at a glance. **Review** runs after and judges the built screen against the sketch and the checklist. The principles, checklist, and anti-patterns apply to any TUI; [Tessera specifics](#tessera-specifics) at the end maps them onto Tessera's catalog, roles, and commands. The evidence behind every principle is in [Intuitive TUI design](../../../docs/research/intuitive-tui-design.md).

Wireframes here use the catalog's dialect: a `wireframe WxH` fence holds exactly the screen's cells, and a styled grid below it gives each cell a role (`primary`, `secondary`, `border`, `accent`, `focus`, …).

## Principles

### 1. One subject, and it is the loudest thing

Decide what the screen is about, then give that one thing the most weight: the boldest ink, the centre of the space, the largest area. Chrome (titles, rules, legends, status) gets the least. When everything has the same weight, the eye has nowhere to land and starts reading left to right, top to bottom, like prose.

Before: the title, two rules, and the legend outweigh the count, which sits alone at the far right edge.

```wireframe 40x5 id=counter-before
Counter
────────────────────────────────────────
Count                                  0
────────────────────────────────────────
+ up   - down   0 reset   q quit
```

After: the value is centred and bold, the keys that change it flank it, and the only legend left is for the keys that are not already on screen.

```wireframe 40x5 id=counter-after

               -   12   +
                 count

0 reset · q quit
```

```text
── chars ──

               -   12   +
                 count

0 reset · q quit
── style ──

...............K...VV...K
.................DDDDD

KDDDDDDDSSKDDDDD
── legend ──
.  default
V  fg=primary bold -- the value, the one thing that changes
K  fg=secondary bold -- keys, beside what they change
D  fg=secondary -- the label and the key descriptions
S  fg=border -- separators
```

### 2. Draw what is invisible

Much of what a screen is about has no glyph of its own: empty space, a container's bounds, padding, the size a view reports, focus, selection. Draw it, quietly, and label it with its measured value, not with a sentence about it. A layout is understood the moment its space is visible and its sizes are numbers.

Before: the caption explains a rule the row cannot show, because the space the Spacers took is blank.

```wireframe 40x2 id=spacers-before
two Spacers: earlier gets the odd cell
L                   M                  R
```

After: the space is drawn and measured, so 19 against 18 shows which Spacer took the odd cell. Here the space is the subject, so it gets the accent.

```wireframe 40x2 id=spacers-after
two spacers share the row
L<─────── 19 ──────>M<────── 18 ──────>R
```

```text
── chars ──
two spacers share the row
L<─────── 19 ──────>M<────── 18 ──────>R
── style ──
SSSSSSSSSSSSSSSSSSSSSSSSS
PAAAAAAAAANNAAAAAAAAPAAAAAAAANNAAAAAAAAP
── legend ──
.  default
S  fg=secondary -- the case, in words
A  fg=accent -- the space each Spacer took, the subject
N  fg=accent bold -- its measured width
P  fg=primary -- the views the space sits between
```

### 3. Let frames name things

Put a thing's name in its frame (a border title, a tab, a header row) instead of on a line of its own above it. The frame then does three jobs: it groups, it shows the bounds, and it labels, at no cost in rows. Name things by what they mean to the reader. A framework demo may show the API name of a value, since that is what the reader will type, but a caption should never be code (`pad+frame`, `priority 1: first Spacer and neighbours`).

Before: alignment can only be judged against the container's edges, and no edge is drawn, so centred text looks ragged.

```wireframe 28x4 id=alignment-before
leading   center    trailing
a            a            a
bbbbbbb   bbbbbbb   bbbbbbb
cc          cc           cc
```

After: three identical frames, each titled with its alignment, the same three lines in each. One variable changes from frame to frame, so the comparison is the picture.

```wireframe 40x5 id=alignment-after
┌ leading ─┐  ┌ center ──┐  ┌ trailing ┐
│a         │  │    a     │  │         a│
│bbbbbbb   │  │ bbbbbbb  │  │   bbbbbbb│
│cc        │  │    cc    │  │        cc│
└──────────┘  └──────────┘  └──────────┘
```

### 4. Change state where the eye already is

Every interaction must change something visibly at the place it acts on: a selection moves, a value changes, a label flips, a row re-lays out. Never answer a key press only with a sentence in a status line somewhere else. If a change cannot be seen, the interaction is not finished.

### 5. Keys belong to what they act on

Keys are found in one of two places. Either inside the control they drive (the key letter of a label in the accent, the `-` and `+` beside a value), or in one quiet legend row that lists only the keys that apply to what has focus and changes when focus moves. A legend uses two inks, the key bolder than its description, and recedes below the content; it is found when wanted and ignored otherwise. A key whose effect is on screen needs no legend entry.

Before: the knob's state is narrated two rows away from the sample it changes, and the legend lists every key in the same ink as everything else.

```wireframe 40x7 id=knob-before
fixed 8x3  min 6   max 4
Go······   Go····  ────
········
········
────────────────────────────────────────
alignment topLeading
a alignment   + - padding   q quit
```

After: the knob's name, its key, and its value ride the frame of the thing it changes, and the dotted backdrop shows the size the framed view reports.

```wireframe 24x5 id=knob-after
┌ alignment topLeading ┐
│Go····················│
│······················│
│······················│
└──────────────────────┘
```

```text
── chars ──
┌ alignment topLeading ┐
│Go····················│
│······················│
│······················│
└──────────────────────┘
── style ──
BTKTTTTTTTTTVVVVVVVVVVTB
B..BBBBBBBBBBBBBBBBBBBBB
BBBBBBBBBBBBBBBBBBBBBBBB
BBBBBBBBBBBBBBBBBBBBBBBB
BBBBBBBBBBBBBBBBBBBBBBBB
── legend ──
.  default
B  fg=border -- the frame and the dotted backdrop: the size the framed view reports
T  fg=secondary -- the knob's name
K  fg=accent bold -- its key, inside its name
V  fg=primary bold -- the knob's value, on the thing it changes
```

### 6. Compare like with like

When a screen shows variants, give them identical frames of the same size, side by side or in rows under one scale, and change one variable between them. A wall of different specimens with different shapes is an inventory, not a demonstration. Fewer variants that each teach something beat every variant at once.

### 7. Use real content

Content that means something explains the screen by itself: an inbox shows that the highlighted row is the open message, a recipe shows that a list scrolls. `Item 0` to `Item 19`, `A B C`, and `foo` make the reader work out what the structure is for.

### 8. Emphasis with restraint

Use a few roles, not many hues: ordinary content, receding text, structural lines, one accent for the subject or the current thing, and a focus style. Reserve reverse video or a fill for selection. Every distinction must survive monochrome (bold, dim, reverse, position, a glyph); colour may reinforce a difference but never be the only carrier of it. Prefer whitespace and alignment to rules; a rule between every block flattens the hierarchy it was meant to create.

### 9. Design the edges

Empty, loading, error, and too-narrow states are screens too, and they are where users get lost. An empty state says what is absent and how to fill it, ideally in the place the content would appear (a placeholder that is also the affordance). Loading shows progress where the result will appear. An error names what failed next to the thing that failed.

### 10. Fit the viewport

Design at the smallest size first, then decide what the larger sizes gain. When space runs out, drop whole things by priority (a legend entry, a side pane) rather than truncating mid-word or clipping. At large sizes, use the space for the subject; do not leave the subject hugging one edge with the rest empty, or stretch a label and its value to opposite edges.

### 11. Motion only for life

Animate only to show that something is live or in progress: a spinner while waiting, a graph that scrolls with time. Motion draws the eye harder than anything else, so it must point at the subject.

## Sketch mode

Run before a screen is built. The output is short enough for the owner to take in at a glance and precise enough to review the built screen against. Record it where the work is reviewed, so the owner can glance at it and the review can compare against it; [Sketching a demo](#sketching-a-demo) names the place for a Tessera slice. The owner's glance never blocks the build: when the owner is away, build against the sketch, and the owner approves or redirects it when reviewing the work.

1. Write the subject in one sentence, for yourself and the owner, not for the screen: "a value that steps up and down and resets".
2. List the states the screen can be in (including empty, error, and narrow) and every interaction: the key, and what visibly changes where.
3. Draw the smallest viewport first, then the largest, as `wireframe WxH` fences at the real sizes. Use real content.
4. Add a styled grid for each wireframe that carries emphasis: which cells are the subject, which recede, which are structure.
5. Write the eye path: the first three things the eye lands on, in order, by region and cell (`r1 c19`). The subject must be first.
6. Write the interaction table. Every "where" must be the subject, the region the eye is on, or the control the key is drawn in; a "where" in a status line elsewhere is a design bug.
7. Run the checklist below against the sketch, then record it.

Output:

````markdown
## Sketch: NAME

Subject: one sentence.

### mobile (40x16)

```wireframe 40x16 id=mobile
...
```

(styled grid)

Eye path: 1. r1 c19 value; 2. r1 c15, c24 the - and + keys; 3. r4 legend.

### desktop (80x24)

(wireframe, styled grid, eye path)

| Key | What changes | Where |
| --- | --- | --- |
| `+` | the value goes up by one | the value, r1 |

States not drawn: empty (as mobile with `0`), narrow (legend drops `q quit` first).
````

## Review mode

Run after the screen is built, on the built screen, and before the work is handed off for review, so the findings are fixed or listed when a reviewer first sees it. Inputs: the sketch, the screen at every viewport, the screen after each interaction, the styles, and a picture of the real terminal when one is available.

1. **Glance test.** Look at the shot for a moment, cover the legend, and write down what you are looking at and the three things the eye lands on, in order. Compare with the sketch's subject and eye path. If you cannot name the subject from the screen alone, that is the first finding.
2. **Interaction test.** For each row of the interaction table, compare the screen before and after the key. Which cells changed? Are they the subject or the control, and is the change large enough to notice without comparing row by row? A key whose only visible effect is in a status line, or that has none, is a finding.
3. **Monochrome test.** Read the styles with colour removed. Does every distinction still hold through bold, dim, reverse, position, or a glyph?
4. **Viewport test.** At the smallest size, is anything clipped mid-word, or does chrome crowd out the subject? At the largest, is the space used for the subject?
5. **Checklist pass.**
6. **Report**, ranked:
   - **Blocker:** the subject cannot be named from the screen; an interaction has no visible effect where it acts; something reads as a bug (an overlap that looks like a typo, a focus nobody can see).
   - **Major:** the eye lands on chrome first; state narrated instead of shown; keys not tied to what they act on; meaning carried by colour alone.
   - **Minor:** weight, spacing, wording, density.

   Each finding gives the evidence (the viewport, the rows and columns, the before and after), the principle it breaks, and the change, as a wireframe fragment when it is not obvious. Judge the screen, not the code; when the cause is in the toolkit rather than the screen, say so.

## Checklist

- [ ] The subject can be named from the screen in a few seconds, and it is the loudest thing on it.
- [ ] The eye lands on the subject first; chrome is the quietest ink.
- [ ] Space, bounds, focus, and selection that matter are drawn, and sizes are shown as numbers.
- [ ] Each group is framed or set apart by whitespace and named in its frame; captions are words, not code.
- [ ] Every interaction changes something visible where it acts; no state lives only in a status line.
- [ ] Keys are inside the controls they drive, or in one quiet legend row for the focused thing, the key bolder than its description.
- [ ] Variants share one frame shape and differ in one variable.
- [ ] Content is real.
- [ ] Every distinction survives monochrome; one accent at most.
- [ ] Empty, loading, error, and narrow states are designed.
- [ ] The smallest viewport drops whole things; the largest uses its space for the subject.

## Anti-patterns

- **A title line that restates the app's name**, with a full-width rule under it. Name things in their frames.
- **A "what to watch" sentence** or a caption that explains a rule the picture should show.
- **A status line that narrates state** (`alignment topLeading`, `spacing 1`, `focus=catalog`) away from the thing that changed.
- **A global key list in the content's ink**, listing keys for things that are not on screen or not focused.
- **Rules between every block.** Whitespace and frames group better and stay quieter.
- **Invisible containers**: alignment, padding, or spacing shown without the edges that make them visible.
- **Labels in code** (`fill(1) fill(1)`, `pad+frame`) instead of meaning and measured values.
- **Placeholder content** (`Item 0`, `foo`, `A B C`) where real content would explain itself.
- **Specimen sheets**: every variant at once, in different shapes, with nothing to say which matters.
- **Overlaps that read as typos** (`OKatus`) and empties that read as glitches (`[]`) with no frame to explain them.
- **Colour as the only signal**, or many hues on chrome.
- **A label and its value at opposite edges** of a wide screen, or the subject hugging one edge with the rest empty.
- **Focus that cannot be seen**, or focus on something that is not on screen.

## Tessera specifics

### The dialect and the roles

- Wireframes and styled grids follow [Wireframe conventions](../../../docs/design.md#wireframe-conventions) and [Styled grids](../../../docs/design.md#styled-grids); callouts and region names follow the same page. Validate a sketch kept in a file with `scripts/check-wireframes.py PATH`.
- Roles come from [tokens.md, Roles](../../../docs/design/tokens.md#roles): `primary` for content, `secondary` for receding text (captions, legend keys bold and descriptions), `border` for structural lines, `focus` (bold default foreground, never a fill), one `accent`, the tones `info`, `success`, `warning`, and `error`, and `selection.fill` for selected rows. In the 16-colour `slots` tier and under `NO_COLOR`, `secondary` and `border` are dim, and under `NO_COLOR` `accent` is bold, so a sketch that only works in colour fails principle 8.
- Viewports are named in [tokens.md, Viewports](../../../docs/design/tokens.md#viewports): `mobile` is 40x16 and `desktop` 80x24. Sketch `mobile` first.
- A catalog component's look (KeyLegend, Box, Badge, …) is in its doc under `docs/design/`, and a sketch should use that look rather than invent one. A component is available to a screen only once [the index](../../../docs/design.md#index) lists it as `implemented`; until then a screen cannot draw it, and imitating it from `Text` (a box drawn from `│` strings, a legend styled by hand) is a workaround. When the right design needs an unbuilt component, the sketch says so instead.
- What every screen can use today: `Text(_:style:)`, whose `Style` takes a foreground, a background, and the attributes `bold`, `dim`, `italic`, `reverse`, and `strikethrough`; `Divider`; `HStack`, `VStack`, `ZStack`, `Spacer`, and `Flex`; `frame` and `padding`; and `ScrollView` and `SplitView`. Attributes alone carry most of principle 8: bold for the subject, dim for chrome, reverse for selection.

### Sketching a demo

A demo is an `Application` in `Examples/Sources/DemoSupport` that conforms to `Demo` (the [`tessera-contributing` skill](../tessera-contributing/SKILL.md) says how to add one). Every slice that adds or changes a demo has a designer agent with this skill sketch it before it is written, at `mobile` and `desktop`, and review it once it is built. Record the sketch in the slice's pull request description, under `## Demo sketch`, and, when the slice records its evidence on the plan's Progress line, cite the sketch there too. Run the review on the built demo before the slice's critic review hands the pull request to the owner, and put its findings, fixed or listed, in the pull request. The owner glances at the sketch when available; in an unattended run the slice builds against the sketch, and the owner approves or redirects in pull request review.

### Reviewing with the `tessera` commands

The [`tessera` skill](../tessera/SKILL.md) documents each command; contributors run them as `mise run dev:shot`, `dev:tree`, and `dev:run`.

- `tessera shot NAME mobile --pretty` and `tessera shot NAME desktop --pretty` give each viewport's screen as text; read them for the glance and viewport tests.
- `tessera tree NAME mobile --pretty` gives every node's frame, for measuring what the screen draws (is the subject the largest region; where did the space go).
- Before and after each interaction, and the styles: write a scratch scenario outside the repository with one `shot` per state, run it once with `--record`, and read the goldens it writes. `NAME.txt` is the screen; `NAME.grid.txt` is the screen with one style letter per cell, so a grid whose legend is only `.  default` has no emphasis at all. Run it again with `term colors=none` for the monochrome test.

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
