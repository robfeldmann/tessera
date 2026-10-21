---
kind: widget
status: specified
---

# Markdown

`Markdown` renders a Markdown source string as rich text: headings, emphasis, inline code,
links, ordered, unordered and task lists, block quotes, fenced code blocks and pipe
tables. It is display-only: links draw as text and are written as OSC 8 hyperlinks, so the
terminal opens them and Markdown takes no focus, keys or pointer input. Fenced code is
drawn by the [code view](code-view.md). Pipe tables are drawn by the [Table](table.md)
renderer in its `grid` style, so the catalog has one table renderer.

This widget follows the controlled-widget rule in
[Slice 7](../../docs/Spec.md#slice-7-catalog-integration--list-section-controlled-widgets-and-the-showcase).
The application owns the source string. Markdown owns only the rendered layout.

Owner decision, omp2 review, 2026-10: Markdown is adopted for 1.0 as omp2 draws it, except
math typesetting, which stays out of 1.0
([discussion #31](https://github.com/robfeldmann/tessera/discussions/31)).

Links are OSC 8 only in 1.0 (owner decision, 2026-10-18), so Markdown is display-only.
In-app link activation (focus, keys, a handler) is post-1.0; see
[discussion #40](https://github.com/robfeldmann/tessera/discussions/40).

## Prior art

- omp2 `Markdown` component:
  [markdown.rs#L41-L385](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/markdown.rs#L41-L385).
  Copy the element coverage and one blank row between blocks. Reject the `<md>` markup
  wrapper: Tessera takes a `String`.
- omp2 pipe tables:
  [markdown/mod.rs#L1529-L1541](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/markdown/mod.rs#L1529-L1541),
  delimiter row check at
  [#L1467-L1474](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/markdown/mod.rs#L1467-L1474).
  Copy the boxed grid with per-column alignment (left, centre, right). Copy the ASCII
  fallback (`+`, `-`, `|`).
- omp2 fenced code:
  [markdown/mod.rs#L892-L943](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/markdown/mod.rs#L892-L943).
  Copy the rule that fence rows are literal text in the code border role, and that the
  body is highlighted and indented two columns with no box around it.

## API direction

```swift
Markdown("Version **2.4** adds *streaming* output. See the [changelog](https://example.com/changelog).")
```

`Markdown` takes its source as a `String`. Block and inline styling come from the
environment. No styling modifiers are decided here.

Markdown applies [`.readableWidth()`](../primitives/readable-width.md) to its prose blocks
(paragraphs, headings, list items and quotes) by default (owner decision, 2026-10-18), not
to the body as a whole. The modifier is a maximum only: above 72 cells (the default; apps
set `.environment(\.readableWidth, n)`) a prose block is capped at 72, and at or below 72
it has no effect. Fenced code and pipe tables are not capped: code does not wrap and
tables drop columns, so a 72-cell cap would hide content on a wide terminal. Every block
stays leading-aligned in the body, so prose and code share a left edge, and code and
tables may extend to the full available width.

Wrap rules ([README](../README.md#wrap-and-truncation)): paragraph, heading, list item and
quote text is content and word-wraps at the column width; a word wider than the column
breaks between grapheme clusters. Fenced code is the one exception, below. Pipe tables
follow [Table](table.md): cells are single-line by default.

## Anatomy

Default block at 80 columns: a level 1 heading, a paragraph with strong, emphasis, inline
code and a link, a level 2 heading, and a paragraph with inline code. An 80-column
proposal caps the prose at the 72-cell readable width, so these blocks are 72 cells wide
and sit at the leading edge. Text regions are content, wraps.

```wireframe 72x8
Release notes

Version 2.4 adds streaming output and a faster render path. See the
changelog (https://example.com/changelog) for details.

Known issues

The cache can go stale after a git pull; run just warm to rebuild it.
```

````text
Callouts (72x8, 0-based):
1. r0 c0-c12    Heading level 1 -- Text, `accent` bold underline; content, wraps
2. r2 c8-c10    Strong run "2.4" -- Text, `primary` bold; content, wraps
3. r2 c17-c25   Emphasis run "streaming" -- Text, `primary` italic; content, wraps
4. r2 c47-c52   Inline code "render" -- Text, `warning` on `surface`; content, wraps
5. r3 c0-c8     Link text "changelog" -- Text, `accent` underline, written as an OSC 8 hyperlink; content, wraps
6. r3 c10-c40   Link destination in parentheses -- Text, `primary` dim; content, wraps
7. r5 c0-c11    Heading level 2 -- Text, `accent` bold; content, wraps
8. r7 c31-c38   Inline code "git pull" -- Text, `warning` on `surface`; content, wraps
9. r7 c45-c53   Inline code "just warm" -- Text, `warning` on `surface`; content, wraps
10. r1, r4, r6  Block spacing -- one blank row between blocks

Styled grid for the same block. Colour, weight and underline matter here, so the roles are
shown. Legend roles are the omp2 captures renamed to Tessera roles (`fg` is `primary`,
`warn` is `warning`).

```text
── chars ──
Release notes

Version 2.4 adds streaming output and a faster render path. See the
changelog (https://example.com/changelog) for details.

Known issues

The cache can go stale after a git pull; run just warm to rebuild it.
── style ──
AAAAAAAAAAAAA

BBBBBBBBCCCBBBBBBDDDDDDDDDBBBBBBBBBBBBBBBBBBBBBEEEEEEBBBBBBBBBBBBBB
FFFFFFFFFBGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGBBBBBBBBBBBBB

HHHHHHHHHHHH

BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBEEEEEEEEBBBBBBEEEEEEEEEBBBBBBBBBBBBBBB
── legend ──
.  default
A  fg=accent bold underline
B  fg=primary
C  fg=primary bold
D  fg=primary italic
E  fg=warning bg=surface
F  fg=accent underline
G  fg=primary dim
H  fg=accent bold
````

## States

### Mobile

The same default block at 40 columns. Paragraphs re-wrap at the column edge; run roles and
block spacing are unchanged.

```wireframe 40x11
Release notes

Version 2.4 adds streaming output and a
faster render path. See the changelog
(https://example.com/changelog) for
details.

Known issues

The cache can go stale after a git pull;
run just warm to rebuild it.
```

```text
Callouts (40x11, 0-based):
1. r0 c0-c12    Heading level 1 -- Text, `accent` bold underline
2. r2 c8-c10    Strong run "2.4" -- Text, `primary` bold
3. r2 c17-c25   Emphasis run "streaming" -- Text, `primary` italic
4. r3 c7-c12    Inline code "render" -- Text, `warning` on `surface`
5. r3 c28-c36   Link text "changelog" -- Text, `accent` underline
6. r4 c0-c30    Link destination in parentheses -- Text, `primary` dim
7. r7 c0-c11    Heading level 2 -- Text, `accent` bold
8. r9 c31-c38   Inline code "git pull" -- Text, `warning` on `surface`
9. r10 c4-c12   Inline code "just warm" -- Text, `warning` on `surface`
```

```text
── chars ──
Release notes

Version 2.4 adds streaming output and a
faster render path. See the changelog
(https://example.com/changelog) for
details.

Known issues

The cache can go stale after a git pull;
run just warm to rebuild it.
── style ──
AAAAAAAAAAAAA

BBBBBBBBCCCBBBBBBDDDDDDDDDBBBBBBBBBBBBB
BBBBBBBEEEEEEBBBBBBBBBBBBBBBFFFFFFFFF
GGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGBBBB
BBBBBBBB

HHHHHHHHHHHH

BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBEEEEEEEEB
BBBBEEEEEEEEEBBBBBBBBBBBBBBB
── legend ──
.  default
A  fg=accent bold underline
B  fg=primary
C  fg=primary bold
D  fg=primary italic
E  fg=warning bg=surface
F  fg=accent underline
G  fg=primary dim
H  fg=accent bold
```

### Minimum

Owner decision, 2026-10-10: Markdown has no minimum width. It renders in whatever width it
is given. Other text word-wraps, and a word wider than the width breaks between grapheme
clusters, so nothing is clipped or truncated; only a fixed height ends the last visible
row in `…` (see [Sizing](#sizing); owner decision, 2026-10-18). The state is drawn at the
minimum mobile size, 40 columns, so the wrapped link destination shows the grapheme break.

```wireframe 40x5
Release notes

Read the changelog at
(https://example.com/changelog/2.4/relea
se-notes/details-and-migration).
```

```text
Callouts (40x5, 0-based):
1. r0 c0-12 Heading level 1 -- Text, `accent` bold underline
2. r3-r4 c0-39 Link destination, broken between graphemes (r3 fills 40 cells, r4 is 32) -- Text, `primary` dim
```

### Fenced code

A fenced block with a language tag. The fence rows are literal text in the border role.
The body is drawn by the [code view](code-view.md) with syntax highlighting from the app's
installed [syntax highlighter hook](code-view.md#syntax-highlighter-hook)
(`.syntaxHighlighter(_:)`), indented two columns and not boxed. The capture is drawn at 72
columns for comparison; the code block itself is not capped by the readable width and may
extend to the full available width.

> Wrap exception (rule 1): code lines do not word-wrap and clip at the available width's
> right edge as [CodeView](code-view.md) does. Wrapping would break indentation and
> alignment. (owner decision, 2026-10-18)

````wireframe 72x7
Read the cache path from the config:

```rust
  fn cache_dir(home: &Path) -> PathBuf {
      home.join(".cache").join("tessera")
  }
```
````

````text
Callouts (72x7, 0-based):
1. r0       Paragraph -- Text, `primary`; content, wraps
2. r2, r6   Fence rows "```rust" and "```" -- literal text, `border`
3. r3-r5    Code body -- CodeView, indented two columns, no box; chrome, one row per line (code exception); roles in the styled grid
````

````text
── chars ──
Read the cache path from the config:

```rust
  fn cache_dir(home: &Path) -> PathBuf {
      home.join(".cache").join("tessera")
  }
```
── style ──
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA

BBBBBBB
..KK.FFFFFFFFFP....P.PTTTTP.PP.TTTTTTT.P
..........PFFFFPSSSSSSSSPPFFFFPSSSSSSSSSP
..P
BBB
── legend ──
.  syntax.plain
A  fg=primary
B  fg=border
F  fg=syntax.function
K  fg=syntax.keyword
P  fg=syntax.punctuation
S  fg=syntax.string
T  fg=syntax.type
````

Code-body roles are the `syntax.*` roles in [syntax roles](../tokens.md#syntax-roles):
`syntax.keyword` for keywords, `syntax.function` for function names, `syntax.type` for
types and builtins, `syntax.string` for literals, `syntax.punctuation` for punctuation and
operators, `syntax.plain` otherwise.

### Lists

Ordered, nested unordered and task lists. Markers take `info`. Item text takes `primary`.
Item text is content and wraps; a continuation row hangs under the item's text, after the
marker (see Wrapped items). The captures below fit the 72-cell prose cap, so no item
wraps.

```wireframe 72x8
1. Read the component entry
2. Write the fixtures
  - default look
  - interactive states
3. Validate every charset
- [x] Capture text-leaf
- [x] Capture pre
- [ ] Capture markdown
```

```text
Callouts (72x8, 0-based):
1. r0, r1, r4    Ordered markers "1. ", "2. ", "3. " -- Text, `info`
2. r2, r3 c2-c3  Nested bullet markers "- " -- Text, `info`
3. r5-r7 c0-c1   Task list markers "- " -- Text, `info`
4. r5-r7 c2-c4   Task checkboxes "[x]" and "[ ]" -- Text, `primary` bold
```

```text
── chars ──
1. Read the component entry
2. Write the fixtures
  - default look
  - interactive states
3. Validate every charset
- [x] Capture text-leaf
- [x] Capture pre
- [ ] Capture markdown
── style ──
AAABBBBBBBBBBBBBBBBBBBBBBBB
AAABBBBBBBBBBBBBBBBBB
BBAABBBBBBBBBBBB
BBAABBBBBBBBBBBBBBBBBB
AAABBBBBBBBBBBBBBBBBBBBBB
AABBBBBBBBBBBBBBBBBBBBB
AABBBBBBBBBBBBBBB
AABBBBBBBBBBBBBBBBBBBB
── legend ──
.  default
A  fg=info
B  fg=primary
```

### Wrapped items

At 24 columns an ordered item, a task item and a quote wrap (owner decision, 2026-10-18).
A wrapped item hangs its continuation rows under the item's text, after the marker. A
wrapped quote repeats the rail on every row. The blank row between the list and the quote
is block spacing.

```wireframe 24x7
1. Read the component
   entry first
- [ ] Capture the
      markdown fixtures

│ The rail repeats on
│ every wrapped row.
```

```text
Callouts (24x7, 0-based):
1. r0, r2 c0-c1    Item markers "1. " and "- " -- Text, `info`; chrome, one row
2. r0-r1 c3-c20    Ordered item text, hanging indent at c3 -- Text, `primary`; content, wraps
3. r2 c2-c4        Task checkbox "[ ]" -- Text, `primary` bold; chrome, one row
4. r2-r3 c6-c22    Task item text, hanging indent at c6 -- Text, `primary`; content, wraps
5. r5-r6 c0        Quote rail "│" repeated on each wrapped row -- Text, `border`; chrome, one row
6. r5-r6 c2-c20    Quoted text -- Text, `secondary` italic; content, wraps
```

```text
── chars ──
1. Read the component
   entry first
- [ ] Capture the
      markdown fixtures

│ The rail repeats on
│ every wrapped row.
── style ──
AAABBBBBBBBBBBBBBBBBB
BBBBBBBBBBBBBB
AABBBBBBBBBBBBBBB
BBBBBBBBBBBBBBBBBBBBBBB

G.CCCCCCCCCCCCCCCCCCC
G.CCCCCCCCCCCCCCCCCC
── legend ──
.  default
A  fg=info
B  fg=primary
C  fg=secondary italic
G  fg=border
```

### Block quote

A quote draws one rail per level in `border`. Quoted text is `secondary` italic; emphasis
inside a quote is `primary` dim italic. A nested quote indents one more level. Quoted text
is content and wraps inside the rails; every wrapped row repeats them.

```wireframe 40x4
│ The rail marks quoted text.
│
│ │ Nested quotes indent one more level.
│ │ They keep emphasis as well.
```

```text
Callouts (40x4, 0-based):
1. r0-r3 c0      Quote rail "│" -- Text, `border`
2. r0, r2        Quoted text -- Text, `secondary` italic
3. r3 c14-c21    Emphasis "emphasis" -- Text, `primary` dim italic
4. r2-r3 c2      Second rail, one level deeper -- Text, `border`
```

```text
── chars ──
│ The rail marks quoted text.
│
│ │ Nested quotes indent one more level.
│ │ They keep emphasis as well.
── style ──
G.AAAAAAAAAAAAAAAAAAAAAAAAAAA
G
G.G.AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
G.G.AAAAAAAAAABBBBBBBBAAAAAAAAA
── legend ──
.  default
A  fg=secondary italic
B  fg=primary dim italic
G  fg=border
```

### Pipe table

A pipe table with left, centre and right alignment renders through the [Table](table.md)
`grid` style. The grid is 31 columns wide, so it fits 72 and the 40-column design. Inline
code in cells takes `warning` on `surface`. Grid lines take the Table renderer's border
colour, captured here as `primary`. Cells follow Table's single-line default (owner
decision Q15, 2026-10-18) and Markdown opts no column into wrapping; a column narrower
than its content tail-truncates, and a column set narrower than the grid follows Table's
narrow-width rules ([Table](table.md)), so the table is the one block that can show less
than its source at a narrow width.

```wireframe 40x9
┌───────────┬─────────┬───────┐
│ Component │ Status  │ Cases │
├───────────┼─────────┼───────┤
│ text-leaf │  done   │     5 │
├───────────┼─────────┼───────┤
│ pre       │  done   │     4 │
├───────────┼─────────┼───────┤
│ markdown  │ pending │     5 │
└───────────┴─────────┴───────┘
```

```text
Callouts (40x9, 0-based):
1. r0-r8           Table grid -- Table `grid` style, light box set
2. r1              Header row -- Table header, `primary` bold
3. r3, r5, r7 c2-c10  First-column cells "text-leaf", "pre", "markdown" -- Text, `warning` on `surface`
4. r3-r7 c14-c20   Status column, centred -- Table cell alignment
5. r3-r7 c28       Cases column, right-aligned -- Table cell alignment
```

```text
── chars ──
┌───────────┬─────────┬───────┐
│ Component │ Status  │ Cases │
├───────────┼─────────┼───────┤
│ text-leaf │  done   │     5 │
├───────────┼─────────┼───────┤
│ pre       │  done   │     4 │
├───────────┼─────────┼───────┤
│ markdown  │ pending │     5 │
└───────────┴─────────┴───────┘
── style ──
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AABBBBBBBBBAAABBBBBBBAAABBBBBAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AACCCCCCCCCAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AACCCAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AACCCCCCCCAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
── legend ──
.  default
A  fg=primary
B  fg=primary bold
C  fg=warning bg=surface
```

## State model

Schema: [README](../README.md#state-model-table).

| State           | Owner   | Type   | Reset or clamp rule                                  |
| --------------- | ------- | ------ | ---------------------------------------------------- |
| Source string   | Binding | String | Re-renders on change; the widget keeps no copy       |
| Rendered layout | derived | Layout | Recomputed per layout pass from the source and width |

No streaming output in 1.0 (owner decision, 2026-10-10): a changed source string
re-renders in full. omp2's `reveal` and `partial` props are post-1.0.

## Key table

Schema: [README](../README.md#key-table). Markdown is display-only and takes no keys:
links are OSC 8 only in 1.0, so the terminal opens them (owner decision, 2026-10-18).
In-app activation is post-1.0; see
[discussion #40](https://github.com/robfeldmann/tessera/discussions/40).

| Key    | Precondition | Effect | Consumed |
| ------ | ------------ | ------ | -------- |
| (none) | --           | --     | --       |

## Mouse table

Schema: [README](../README.md#mouse-table). Markdown takes no pointer input in 1.0; a
click on link text is the terminal's OSC 8 handling, not Tessera's (owner decision,
2026-10-18).

| Event  | Region | Precondition | Effect | Consumed |
| ------ | ------ | ------------ | ------ | -------- |
| (none) | --     | --           | --     | --       |

## Sizing

Schema: [README](../README.md#sizing-table). Prose blocks (paragraphs, headings, list
items, quotes) sit under a `.readableWidth()` maximum: their width is
`min(proposal, readableWidth)`. Fenced code and pipe tables are not capped and may extend
to the proposal (owner decision, 2026-10-18). Markdown's width is its widest block, and
every block is leading-aligned. Height is the sum of the rendered blocks at those widths:
with a nil or unbounded height every row shows. A finite height is a row budget
([Text](../primitives/text.md#row-budget)): rows past it are not drawn, and when a text
row is the last visible one it is re-laid as the rest of its source line and ends in `…`.
A code or table row at the cut clips with no mark (non-text geometry). There is no minimum
width (owner decision, 2026-10-10); see Minimum. Rows use the Anatomy block as the
fixture.

| Proposal                      | Result | Rule                                                                                                                                                       |
| ----------------------------- | ------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------- |
| nil x nil                     | 69x8   | A nil width proposes the 72-cell readable width to prose and reports the widest row (69); height is every row (owner decision, 2026-10-18)                 |
| 72 x nil (tight)              | 72x8   | Tight: prose wraps at 72 and the height is every row                                                                                                       |
| 80 x nil                      | 72x8   | Prose capped at 72, leading-aligned; same wrapped rows as Anatomy                                                                                          |
| 100 x nil (over-maximum)      | 72x8   | Prose capped at 72; it does not fill the proposal and the wrapped rows are the same as at 72                                                               |
| 100 x nil, code line 90 cells | 100x n | Prose wraps at 72 and the code line is not capped, so it shows all 90 cells; both start at c0 (width is the widest block)                                  |
| 100 x nil, pipe table         | 72 x n | The 31-column table fits under the cap and the prose sets the width; a table wider than 72 would extend to its natural width up to 100                     |
| 40 x nil                      | 40x11  | Under the cap the column is the proposal; paragraphs re-wrap to 11 rows (Mobile)                                                                           |
| 12 x nil (under-minimum)      | 12 x n | Width = proposal; height = wrapped rows. A word wider than 12 breaks between grapheme clusters, never clipped (owner decisions, 2026-10-10 and 2026-10-18) |
| 72 x 3 (fixed height)         | 72x3   | Three-row budget: heading, spacer, and the first paragraph row re-laid as its whole source line cut at 71 cells plus `…`                                   |
| 24 x nil                      | 24 x n | Items and quotes wrap with hanging indents and repeated rails (Wrapped items); a pipe table follows Table's narrow-width rules                             |

## Environment

Tokens consumed, each defined in [tokens.md](../tokens.md).

- `primary`: body text, strong and emphasis runs, table header.
- `accent`: headings, link text.
- `disabled`: not used.
- `readableWidth` (environment): the prose blocks' maximum width, default 72; see
  [Readable width](../primitives/readable-width.md).

Further roles, each defined in tokens.md:

- `border`: quote rail and fence rows; `secondary` italic: quoted text.
- `info`: list markers.
- `warning` on `surface`: inline code.
- `syntax.*`: code block body; see [code view](code-view.md) and
  [syntax roles](../tokens.md#syntax-roles).

## Primitive dependencies

- [Table](table.md): pipe tables, `grid` style.
- [CodeView](code-view.md): fenced code bodies.
- [Text](../primitives/text.md): inline runs. The assessment requires styled runs in Text
  before Markdown can start.

## Requirements

Schema: [README](../README.md#requirements-list). Each entry traces to a callout or state
above.

- `markdown renders a level one heading in accent bold underline` (Anatomy callout 1)
- `markdown renders strong and emphasis runs in primary bold and primary italic` (Anatomy
  callouts 2, 3)
- `markdown renders inline code in warning on the surface role` (Anatomy callouts 4, 8, 9)
- `markdown separates blocks with one blank row` (Anatomy callout 10)
- `markdown re-wraps paragraphs at the proposed width and keeps run roles` (Mobile)
- `markdown caps prose width at the readable width, 72 by default, and does not fill a wider proposal`
  (Sizing 80 x nil, 100 x nil; owner decision, 2026-10-18)
- `markdown does not cap fenced code or pipe tables at the readable width` (Sizing, 100 x
  nil with a code line; owner decision, 2026-10-18)
- `markdown reports the widest row at the readable width for a nil x nil proposal` (Sizing
  nil x nil; owner decision, 2026-10-18)
- `markdown ends the last visible text row in an ellipsis under a fixed height` (Sizing 72
  x 3; owner decision, 2026-10-18)
- `markdown wraps list items with a hanging indent and repeats the quote rail on wrapped rows`
  (Wrapped items callouts 2, 4, 5; owner decision, 2026-10-18)
- `markdown does not word-wrap fenced code` (Fenced code wrap exception; owner decision,
  2026-10-18)
- `markdown keeps pipe table cells single-line and opts no column into wrapping` (Pipe
  table; owner decision, 2026-10-18)
- `markdown writes link text as an OSC 8 hyperlink` (Anatomy callout 5; owner decision,
  2026-10-18)
- `markdown takes no focus, keys or pointer input` (Key table, Mouse table; owner
  decision, 2026-10-18)
- `markdown draws fenced code through the code view without a box` (Fenced code)
- `markdown draws ordered, bullet and task markers in info` (Lists callouts 1-3)
- `markdown draws one quote rail per level in border` (Block quote callouts 1, 4)
- `markdown draws quoted text in secondary italic` (Block quote callout 2; Wrapped items
  callout 6)
- `markdown draws fenced code body in syntax roles and fence rows in border` (Fenced code
  callouts 2, 3)
- `markdown renders a pipe table through the table grid style` (Pipe table callout 1)
- `markdown aligns pipe table columns left, centre and right as written` (Pipe table
  callouts 4, 5)
- `markdown does not typeset math` (owner decision, omp2 review, 2026-10)
- `markdown renders the full layout again when the source string changes` (State model;
  owner decision, 2026-10-10)
- `markdown does not reveal streamed source in 1.0` (State model; owner decision,
  2026-10-10)
- `markdown breaks a word wider than the width between grapheme clusters` (Minimum; owner
  decisions, 2026-10-10 and 2026-10-18)

## Degradation

Follows the [degradation ladder](../tokens.md#degradation-ladder). The pipe table switches
to the ASCII set (`+`, `-`, `|`), as captured:

```wireframe 40x9
+-----------+---------+-------+
| Component | Status  | Cases |
+-----------+---------+-------+
| text-leaf |  done   |     5 |
+-----------+---------+-------+
| pre       |  done   |     4 |
+-----------+---------+-------+
| markdown  | pending |     5 |
+-----------+---------+-------+
```

Under `NO_COLOR`, inline roles become attributes: each keeps its bold, italic or underline
and drops its colour. Quoted text becomes dim, and the quote rail keeps its glyph (owner
decision, 2026-10-10). At 16 colours, inline roles and quoted text follow their slots
columns in [roles](../tokens.md#roles) and the
[degradation ladder](../tokens.md#degradation-ladder); inline code's `surface` fill is
ANSI 8 on dark terminals and absent on light ones (owner decision, 2026-10-19).

A terminal without OSC 8 support ignores the hyperlink sequence, and the link text still
draws in `accent` underline with its destination in parentheses, so no information is
lost.

## Open questions

None open.

## Inspiration

None yet.
