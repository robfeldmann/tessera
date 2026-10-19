---
kind: widget
status: wireframed
---

# Markdown

`Markdown` renders a Markdown source string as rich text: headings, emphasis, inline code,
links, ordered, unordered and task lists, block quotes, fenced code blocks and pipe
tables. It is display-only apart from links, which take focus and activation. Fenced code
is drawn by the [code view](code-view.md). Pipe tables are drawn by the [Table](table.md)
renderer in its `grid` style, so the catalog has one table renderer.

This widget follows the controlled-widget rule in
[Slice 7](../../docs/Spec.md#slice-7-catalog-integration--list-section-controlled-widgets-and-the-showcase).
The application owns the source string. Markdown owns only the rendered layout.

Owner decision, omp2 review, 2026-10: Markdown is adopted for 1.0 as omp2 draws it, except
math typesetting, which stays out of 1.0
([discussion #31](https://github.com/robfeldmann/tessera/discussions/31)).

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

## Anatomy

Default block at 80 columns: a level 1 heading, a paragraph with strong, emphasis, inline
code and a link, a level 2 heading, and a paragraph with inline code.

```wireframe 80x8
Release notes

Version 2.4 adds streaming output and a faster render path. See the changelog
(https://example.com/changelog) for details.

Known issues

The cache can go stale after a git pull; run just warm to rebuild it.
```

```text
Callouts (80x8, 0-based):
1. r0 c0-c12    Heading level 1 -- Text, `accent` bold underline
2. r2 c8-c10    Strong run "2.4" -- Text, `primary` bold
3. r2 c17-c25   Emphasis run "streaming" -- Text, `primary` italic
4. r2 c47-c52   Inline code "render" -- Text, `warning` on `hover`
5. r2 c68-c76   Link text "changelog" -- Text, `accent` underline
6. r3 c0-c30    Link destination in parentheses -- Text, `primary` dim
7. r5 c0-c11    Heading level 2 -- Text, `accent` bold
8. r7 c31-c38   Inline code "git pull" -- Text, `warning` on `hover`
9. r7 c45-c53   Inline code "just warm" -- Text, `warning` on `hover`
10. r1, r4, r6  Block spacing -- one blank row between blocks
```

Styled grid for the same block. Colour, weight and underline matter here, so the roles are
shown. Legend roles are the omp2 captures renamed to Tessera roles (`fg` is `primary`,
`warn` is `warning`).

```text
── chars ──
Release notes

Version 2.4 adds streaming output and a faster render path. See the changelog
(https://example.com/changelog) for details.

Known issues

The cache can go stale after a git pull; run just warm to rebuild it.
── style ──
AAAAAAAAAAAAA

BBBBBBBBCCCBBBBBBDDDDDDDDDBBBBBBBBBBBBBBBBBBBBBEEEEEEBBBBBBBBBBBBBBBFFFFFFFFF
GGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGBBBBBBBBBBBBB

HHHHHHHHHHHH

BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBEEEEEEEEBBBBBBEEEEEEEEEBBBBBBBBBBBBBBB
── legend ──
.  default
A  fg=accent bold underline
B  fg=primary
C  fg=primary bold
D  fg=primary italic
E  fg=warning bg=hover
F  fg=accent underline
G  fg=primary dim
H  fg=accent bold
```

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
4. r3 c7-c12    Inline code "render" -- Text, `warning` on `hover`
5. r3 c28-c36   Link text "changelog" -- Text, `accent` underline
6. r4 c0-c30    Link destination in parentheses -- Text, `primary` dim
7. r7 c0-c11    Heading level 2 -- Text, `accent` bold
8. r9 c31-c38   Inline code "git pull" -- Text, `warning` on `hover`
9. r10 c4-c12   Inline code "just warm" -- Text, `warning` on `hover`
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
E  fg=warning bg=hover
F  fg=accent underline
G  fg=primary dim
H  fg=accent bold
```

### Minimum

Owner decision, 2026-10-10: Markdown has no minimum width. It renders in whatever width it
is given. Unbreakable tokens character-wrap, other text word-wraps, and whatever the width
cannot hold is truncated. The state is drawn at the minimum mobile size, 40 columns, so
the wrapped link destination shows the character wrap.

```wireframe 40x5
Release notes

Read the changelog at
(https://example.com/changelog/2.4/rel
ease-notes/details-and-migration).
```

```text
Callouts (40x5, 0-based):
1. r0 c0-12 Heading level 1 -- Text, `accent` bold underline
2. r3-r4 c0-37 Link destination, character-wrapped -- Text, `primary` dim
```

### Fenced code

A fenced block with a language tag. The fence rows are literal text in the border role.
The body is drawn by the [code view](code-view.md) with syntax highlighting from the app's
installed [syntax highlighter hook](code-view.md#syntax-highlighter-hook)
(`.syntaxHighlighter(_:)`), indented two columns and not boxed. The 80-column capture
clips at the panel edge and does not wrap.

````wireframe 80x7
Read the cache path from the config:

```rust
  fn cache_dir(home: &Path) -> PathBuf {
      home.join(".cache").join("tessera")
  }
```
````

````text
Callouts (80x7, 0-based):
1. r0       Paragraph -- Text, `primary`
2. r2, r6   Fence rows "```rust" and "```" -- literal text, `border` (token pending plan 032 step 5.3)
3. r3-r5    Code body -- CodeView, indented two columns, no box; roles in the styled grid
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
AACC.DDDDDDDDDEAAAAE.C....E.EE.........E
AA.........DDDDEEBBBBBBEE.DDDDEEBBBBBBBEE
AAE
BBB
── legend ──
.  default
A  fg=primary
B  fg=border
C  fg=accent
D  fg=success
E  fg=output
````

Syntax roles in the code body are omp2 palette names. Tessera names are open; see Open
questions.

### Lists

Ordered, nested unordered and task lists. Markers take `info`. Item text takes `primary`.

```wireframe 80x8
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
Callouts (80x8, 0-based):
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

### Block quote

A quote draws one rail per level in `muted`. Quoted text is `muted` dim italic; emphasis
inside a quote is `primary` dim italic. A nested quote indents one more level.

```wireframe 40x4
│ The rail marks quoted text.
│
│ │ Nested quotes indent one more level.
│ │ They keep emphasis as well.
```

```text
Callouts (40x4, 0-based):
1. r0-r3 c0      Quote rail "│" -- Text, `muted`
2. r0, r2        Quoted text -- Text, `muted` dim italic
3. r3 c14-c21    Emphasis "emphasis" -- Text, `primary` dim italic
4. r2-r3 c2      Second rail, one level deeper -- Text, `muted`
```

```text
── chars ──
│ The rail marks quoted text.
│
│ │ Nested quotes indent one more level.
│ │ They keep emphasis as well.
── style ──
AAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAABBBBBBBBAAAAAAAAA
── legend ──
.  default
A  fg=muted dim italic
B  fg=primary dim italic
```

### Pipe table

A pipe table with left, centre and right alignment renders through the [Table](table.md)
`grid` style. The grid is 31 columns wide, so it fits both the 40- and 80-column designs.
Inline code in cells takes `warning` on `hover`. Grid lines take the Table renderer's
border colour, captured here as `primary`.

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
3. r3, r5, r7 c2-c10  First-column cells "text-leaf", "pre", "markdown" -- Text, `warning` on `hover`
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
C  fg=warning bg=hover
```

## State model

Schema: [README](../README.md#state-model-table).

| State           | Owner     | Type   | Reset or clamp rule                                                      |
| --------------- | --------- | ------ | ------------------------------------------------------------------------ |
| Source string   | Binding   | String | Re-renders on change; the widget keeps no copy                           |
| Rendered layout | derived   | Layout | Recomputed per layout pass from the source and width                     |
| Focused link    | NodeState | Int?   | nil when the source string changes; clamps to the last link on re-render |

No streaming output in 1.0 (owner decision, 2026-10-10): a changed source string
re-renders in full. omp2's `reveal` and `partial` props are post-1.0.

## Key table

Schema: [README](../README.md#key-table). Markdown takes keys only to move link focus and
activate the focused link (owner decision, 2026-10-10).

| Key       | Precondition                           | Effect                                                              | Consumed                                               |
| --------- | -------------------------------------- | ------------------------------------------------------------------- | ------------------------------------------------------ |
| Tab       | focused, Source string contains a link | moves Focused link to the next link, or to the first when it is nil | conditional (Focused link is nil or not the last link) |
| Shift-Tab | focused, Focused link is set           | moves Focused link to the previous link                             | conditional (Focused link is not the first link)       |
| Enter     | focused, Focused link is set           | activates Focused link via the activation handler                   | yes                                                    |

## Mouse table

Schema: [README](../README.md#mouse-table). Markdown takes pointer input only on link text
(owner decision, 2026-10-10): a click activates the link. Other rendered text is not
hit-tested.

| Event | Region    | Precondition | Effect                                                                                                 | Consumed |
| ----- | --------- | ------------ | ------------------------------------------------------------------------------------------------------ | -------- |
| click | Link text | always       | activates the clicked link and sets Focused link to it; the destination goes to the activation handler | yes      |

## Sizing

Schema: [README](../README.md#sizing-table). Width drives wrapping: paragraphs re-wrap to
the proposed width, as the 80- and 40-column captures show. Height is the sum of the
rendered blocks. The rules for nil, tight and over-maximum proposals are not decided.
Under-minimum has no minimum (owner decision, 2026-10-10); see Minimum.

| Proposal                 | Result           | Rule                                                                                                     |
| ------------------------ | ---------------- | -------------------------------------------------------------------------------------------------------- |
| nil x nil                | Not decided      | Open question                                                                                            |
| tight                    | Not decided      | Open question                                                                                            |
| 12 x nil (under-minimum) | 12 x n           | Width = proposal; height = wrapped rows. Under the minimum, characters wrap (owner decision, 2026-10-10) |
| any width                | Width = proposal | Height = wrapped rows at that width (owner decision, 2026-10-10)                                         |
| 40 x n                   | Re-wrapped       | Paragraphs re-wrap; table grows to fit                                                                   |
| 80 x n                   | Re-wrapped       | Paragraphs re-wrap; table keeps 31 columns                                                               |

## Environment

Tokens consumed, each defined in [tokens.md](../tokens.md).

- `semantic.primary`: body text, strong and emphasis runs, table header.
- `semantic.accent`: headings, link text.
- `semantic.disabled`: not used.
- `semantic.focus`: text of the focused link; see [focus](../tokens.md#focus).

Roles without a `tokens.md` row yet, token pending plan 032 step 5.3:

- `muted`: quote rail and quoted text.
- `info`: list markers.
- `warning` and `hover`: inline code.
- `success` and `border`: syntax palette and fence rows (see [code view](code-view.md)).
- `output`: no Tessera role has been named; see Open questions.

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
- `markdown renders inline code in warning on the hover role` (Anatomy callouts 4, 8, 9)
- `markdown separates blocks with one blank row` (Anatomy callout 10)
- `markdown re-wraps paragraphs at the proposed width and keeps run roles` (Mobile)
- `markdown draws fenced code through the code view without a box` (Fenced code)
- `markdown draws ordered, bullet and task markers in info` (Lists callouts 1-3)
- `markdown draws one quote rail per level in muted` (Block quote callouts 1, 4)
- `markdown renders a pipe table through the table grid style` (Pipe table callout 1)
- `markdown aligns pipe table columns left, centre and right as written` (Pipe table
  callouts 4, 5)
- `markdown does not typeset math` (owner decision, omp2 review, 2026-10)
- `markdown renders the full layout again when the source string changes` (State model;
  owner decision, 2026-10-10)
- `markdown does not reveal streamed source in 1.0` (State model; owner decision,
  2026-10-10)
- `markdown character-wraps unbreakable tokens at any width` (Minimum; owner decision,
  2026-10-10)
- `markdown moves link focus with Tab and Shift-Tab` (Key table; owner decision,
  2026-10-10)
- `markdown activates the focused link with Enter` (Key table; owner decision, 2026-10-10)
- `markdown activates a link on click of its link text` (Mouse table; owner decision,
  2026-10-10)

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
decision, 2026-10-10). Behaviour of inline roles and quote dimming under 16-colour
terminals is not decided; see Open questions.

## Open questions

- Colour roles without a token row: `muted`, `info`, `warning`, `hover`, `success`,
  `border`. Blocks `ready`. Unblocked by plan 032 step 5.3 (token rows).
- `output` (the body colour of code blocks, `syntax.*` roles): no Tessera role name yet.
  Blocks `ready`. Unblocked by plan 032 step 5.3.
- Sizing for nil x nil and tight proposals: not decided. Blocks `specified`.
- Link activation handler: the signature by which the app receives a link destination on
  activation is not decided. Blocks `specified`. Unblocked by the Slice 7
  controlled-widget API decision.
- 16-colour behaviour of inline roles and quote dimming. Unblocked by the degradation
  ladder.

## Inspiration

None yet.
