---
kind: widget
status: ready
---

# CodeView

`CodeView` shows preformatted source text: spacing and line breaks are kept verbatim, and
lines do not word-wrap: they clip at the panel edge (Wrap exception, below). It can draw a
line-number gutter, syntax-highlight the text through an app-supplied highlighter, and cap
its height with an overflow footer that counts the hidden lines. It is display-only.
[Markdown](markdown.md) draws its fenced code blocks through it.

This widget follows the controlled-widget rule in
[Slice 7](../../spec.md#slice-7-catalog-integration--list-section-and-controlled-widgets).
The application owns the source text. CodeView owns only the rendered rows.

Owner decision, omp2 review, 2026-10: the code view (omp2 `Pre`) is adopted for 1.0 as
omp2 draws it, with syntax highlighting. Owner decision, 2026-10-10: 1.0 ships no grammar.
Tessera supplies the rendering; the app supplies tokens through a highlighter hook (see
[Syntax highlighter hook](#syntax-highlighter-hook)).

## Prior art

- omp2 `Pre` component, which the key maps to the code view (key I3):
  [text.rs#L443-L555](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/text.rs#L443-L555).
  Copy the verbatim, unwrapped rendering. Copy the numbered gutter rows at
  [#L564-L589](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/text.rs#L564-L589).
- Gutter width:
  [line_number_prefix](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/text.rs#L417-L440).
  The gutter is the decimal width of the last line number, plus three columns (`│`).
- Overflow footer (key B8):
  [paint_overflow_footer](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/mod.rs#L120-L138),
  with the row cap from
  [overflow_plan](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/mod.rs#L104-L117).
  The footer counts toward `maxRows`.
- Syntax token colours (key M3):
  [syntax_token](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/text.rs#L517-L530).
  Reject omp2's built-in grammars and its palette names as Tessera roles. The eight
  `syntax.*` roles are defined in [tokens](../tokens.md#syntax-roles).
- omp2's `set_text` updates have no counterpart (key A8): the app redeclares the source on
  every update.

## API direction

```swift
CodeView(source, path: "src/render/table.rs")
    .lineNumbers(startingAt: 40)
    .maxRows(4)
```

`source` and `path` are plain initializer parameters, redeclared on every update (key D2).
`path` gives the language: the file extension after the last dot. It is passed to the
installed highlighter and to the tab-width closure. `lineNumbers(startingAt:)` turns the
gutter on. `maxRows(_:)` caps the height, and the overflow footer counts toward it; it is
the catalog's spelling of omp2's `max-rows` (key B8). The modifier names are a proposal,
and plan 032 step 16.3 settles them.

### Syntax highlighter hook

Owner decision, 2026-10-10: 1.0 ships no grammar and no parser. Tessera owns rendering,
the gutter, clipping and the `syntax.*` roles; the app supplies the tokens. A small
protocol, installed once on an ancestor view, serves every CodeView and Markdown code
block below it (key M3). The protocol shape is the reviewer's example, accepted by the
owner; the names `SyntaxToken`, `.syntaxHighlighter(_:)` and the `tokens:` parameter are
design choices, not owner decisions, and plan 032 step 16.3 settles them.

```swift
protocol SyntaxHighlighter {
    func tokens(for source: String, language: String) -> [SyntaxToken]
}

struct SyntaxToken {
    var range: Range<Int>  // UTF-8 byte offsets into the source (inferred)
    var role: SyntaxRole   // one of the eight syntax.* roles (../tokens.md#syntax-roles)
}

ContentView()
    .syntaxHighlighter(myHighlighter)

CodeView(source, path: "scripts/setup.fish", tokens: explicitTokens)
```

The rules, in order:

- An explicit `tokens:` argument wins over the installed highlighter.
- With no `tokens:` argument and no installed highlighter, the source draws plain.
- With no `path`, there is no language: the highlighter is not called and the source draws
  plain (inferred).
- Markdown fenced code draws through CodeView, so it uses the installed highlighter by
  reference.

Apps can put an existing library behind the protocol. Swift projects use tree-sitter
through SwiftTreeSitter (with Neon for editor integration), Splash (Swift source only), or
Highlightr (highlight.js in JavaScriptCore). Tessera does not endorse one. Apple's
documentation has no public syntax-highlighting API. swift-syntax can classify Swift code;
that claim is unchecked.

### Tab width

Owner decision, 2026-10-10: tabs expand to 2 display cells by default. An app can override
the width through the environment, as a fixed width or as a closure from the language,
because fish code commonly uses 4 cells. The modifier names are a design choice, not an
owner decision, and plan 032 step 16.3 settles them.

```swift
ContentView()
    .codeTabWidth(2)

ContentView()
    .codeTabWidth { language in language == "fish" ? 4 : 2 }
```

The closure receives the CodeView's language, or nil when the CodeView has no `path`
(inferred). A tab advances to the next multiple of the tab width, counted in display cells
from the start of its line (inferred). CodeView expands tabs before rows reach
[Text](../primitives/text.md). omp2's `Pre` does not expand tabs
([text.rs#L443-L555](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/text.rs#L443-L555)
has no tab rule). Its Markdown renderer replaces each tab with three spaces
([markdown/mod.rs#L1631-L1650](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/markdown/mod.rs#L1631-L1650)),
as its diff view does
([diff.rs#L29-L32](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/diff.rs#L29-L32)),
so Tessera's 2-cell default does not come from omp2.

## Anatomy

Default block at 80 columns: a box drawn in the source, an indented line that keeps its
spaces, and a long line clipped at the panel edge. No gutter, no roles.

```wireframe 80x6
+-----------+
| build ok  |
|  12 tests |
+-----------+
    indented   line   keeps   its   spaces
a very long line that is clipped rather than wrapped when it exceeds the panel w
```

```text
Callouts (80x6, 0-based):
1. r0-r3 c0-c12   Source box, literal characters -- CodeView, default role; preformatted, no wrap
2. r4 c0-c41      Indented line; leading and inner spaces kept -- CodeView, default role; preformatted, no wrap
3. r5 c0-c79      Long line clipped at the panel edge, not wrapped -- CodeView, default role; preformatted, no wrap
```

> Wrap exception (rule 1): code lines do not word-wrap; they keep clipping at the panel
> edge. Wrapping would break indentation and alignment (owner decision, 2026-10-18). Each
> source line is one `Text` row with `.lineLimit(1)` and `.truncationMode(.clip)`, so the
> cut carries no mark; the `… N more lines` footer is the only cue that rows are hidden,
> and it counts hidden rows, not hidden columns. A nil width proposal does not wrap
> either, so the ideal width stays the gutter plus the widest line.

## States

### Mobile

The same default block at 40 columns. Lines clip at the 40-column edge; nothing wraps.

```wireframe 40x6
+-----------+
| build ok  |
|  12 tests |
+-----------+
    indented   line   keeps   its   spac
a very long line that is clipped rather
```

```text
Callouts (40x6, 0-based):
1. r0-r3 c0-c12   Source box, literal characters -- CodeView, default role; preformatted, no wrap
2. r4 c0-c39      Indented line, clipped at column 40 -- CodeView, default role; preformatted, no wrap
3. r5 c0-c39      Long line, clipped at column 40 -- CodeView, default role; preformatted, no wrap
```

### Minimum

Owner decision, 2026-10-10: the minimum is 8 columns by 3 rows, the line-number gutter
(four columns for a one-digit last line number) plus four source cells. Lines clip at the
minimum width, as they do at every width. Code has no words to keep whole, so the
wrap-aware floor derivation does not change this number (owner decision, 2026-10-18: code
exception).

```wireframe 8x3
1 │ stru
2 │ main
3 │ }
```

```text
Callouts (8x3, 0-based):
1. r0-r2 c0-c3   Line-number gutter -- CodeView, `secondary`; its `│` separator `border`
2. r0-r2 c4-c7   Source cells, clipped at column 8 -- CodeView, default role
```

### Numbered gutter

A numbered block whose gutter starts at line 40. The gutter is the decimal width of the
last line number plus three columns (`│`), so two-digit numbers give a five-column gutter.
The gutter takes `secondary`, and its `│` separator takes `border`. The code body takes
`primary`.

```wireframe 40x6
40 │ fn main() {
41 │     let args = std::env::args().ski
42 │     for arg in args {
43 │         println!("{arg}");
44 │     }
45 │ }
```

```text
Callouts (40x6, 0-based):
1. r0-r5 c0-c4   Line-number gutter "40 │ " through "45 │ " -- CodeView gutter, `secondary` (the `│` at c3 `border`)
2. r0-r5 c5-c39  Code body, verbatim, clipped at column 40 -- CodeView, `primary`
```

```text
── chars ──
40 │ fn main() {
41 │     let args = std::env::args().ski
42 │     for arg in args {
43 │         println!("{arg}");
44 │     }
45 │ }
── style ──
AAAGA
AAAGA
AAAGA
AAAGA
AAAGA
AAAGA
── legend ──
.  default
A  fg=secondary
G  fg=border
```

### Overflow footer

A block capped at four rows. Three source rows and the footer share the cap, so the footer
is counted in `maxRows`. The footer `… 4 more lines` takes `secondary`.

```wireframe 80x4
1 │ line one of the captured log
2 │ line two of the captured log
3 │ line three of the captured log
… 4 more lines
```

```text
Callouts (80x4, 0-based):
1. r0-r2 c0-c33   Numbered source rows -- CodeView gutter `secondary` (`│` `border`), body `primary`
2. r3 c0-c13      Overflow footer "… N more lines" -- CodeView footer, `secondary`; chrome, one row
```

```text
── chars ──
1 │ line one of the captured log
2 │ line two of the captured log
3 │ line three of the captured log
… 4 more lines
── style ──
AAGA
AAGA
AAGA
AAAAAAAAAAAAAA
── legend ──
.  default
A  fg=secondary
G  fg=border
```

### Syntax highlighting

A numbered block with `path=src/render/table.rs`, drawn through the installed highlighter
(language `rs`). Keywords take `syntax.keyword`; the styled grid below uses the
[syntax roles](../tokens.md#syntax-roles).

```wireframe 40x7
1 │ use std::fmt::Write;
2 │
3 │ pub fn header(title: &str) -> String
4 │     let mut out = String::new();
5 │     let _ = write!(out, "== {title}
6 │     out
7 │ }
```

```text
Callouts (40x7, 0-based):
1. r0-r6 c0-c3   Line-number gutter "1 │" through "7 │" -- CodeView gutter, `secondary`; the `│` at c2 `border`
2. r0 c4-c6      Keyword "use" -- `syntax.keyword`
3. r0-r6         Other tokens: identifiers, punctuation, strings -- syntax roles, see the styled grid
```

```text
── chars ──
1 │ use std::fmt::Write;
2 │
3 │ pub fn header(title: &str) -> String
4 │     let mut out = String::new();
5 │     let _ = write!(out, "== {title}
6 │     out
7 │ }
── style ──
AAGAKKK....PP...PPTTTTTP
AAG
AAGAKKK.KK.FFFFFFP.....P.PTTTP.PP.TTTTTT
AAGA....KKK.KKK.....P.TTTTTTPPFFFPPP
AAGA....KKK...P.FFFFFPP...P.SSSSSSSSSSS
AAGA.......
AAGAP
── legend ──
.  default -- syntax.plain
A  fg=secondary
G  fg=border
K  fg=syntax.keyword
F  fg=syntax.function
T  fg=syntax.type
S  fg=syntax.string
P  fg=syntax.punctuation
```

Roles come from the highlighter's tokens: the eight `syntax.*` roles in
[tokens](../tokens.md#syntax-roles). The [migration map](../tokens.md#migration-map)
records how the grid's earlier letters map to these roles.

## State model

Schema: [README](../../design.md#state-model-table).

| State           | Owner       | Type                                  | Reset or clamp rule                                                                                            |
| --------------- | ----------- | ------------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| Source text     | Binding     | `String`                              | app-owned display data, redeclared on every update (key D2); a change re-renders, and the widget keeps no copy |
| Path            | Binding     | `String?`                             | app-owned (key D2); gives the language; a change re-highlights the text                                        |
| Explicit tokens | Binding     | `[SyntaxToken]?`                      | app-owned (key D2); when present, wins over the installed highlighter                                          |
| Highlighter     | Environment | `SyntaxHighlighter?`                  | installed on an ancestor with `.syntaxHighlighter(_:)` (key M3); none draws plain                              |
| Tab width       | Environment | cells, or a closure from the language | 2 cells by default; set with `.codeTabWidth(_:)`                                                               |
| Rendered rows   | derived     | rows                                  | recomputed each layout pass from the source, tokens, width, tab width and `maxRows`; never stored (key D10)    |

## Key table

Schema: [README](../../design.md#key-table). None. CodeView is display-only: it takes no
focus and consumes no keys.

## Mouse table

Schema: [README](../../design.md#mouse-table). None. CodeView takes no pointer input in
1.0.

## Sizing

Schema: [README](../../design.md#sizing-table). Width does not wrap (Wrap exception):
lines clip at the proposed width, as the Anatomy (80 columns) and Mobile (40 columns)
states show. Owner decision, 2026-10-10: the ideal width is the gutter plus the widest
source line in display cells, and the ideal height is `min(rows, maxRows)`, where `rows`
is the source line count. An under-minimum proposal clips at the proposed size. An
over-maximum proposal fills the proposed width with blank cells and keeps the ideal
height. The overflow footer uses one of the rows under the cap and does not change the
ideal size.

The examples use a three-line source, `fn main() {`, `run();` indented four spaces, and
`}`, whose widest line is 11 cells.

| Proposal  | Result | Rule                                                                                |
| --------- | ------ | ----------------------------------------------------------------------------------- |
| nil x nil | 11x3   | Ideal size, gutter off: widest line 11 cells, height min(3, no maxRows) = 3         |
| nil x nil | 15x3   | Ideal size with `lineNumbers(startingAt: 1)`: gutter 4 (last line 3) plus 11 cells  |
| nil x nil | 11x2   | Ideal height capped by `maxRows(2)`: min(3, 2) = 2 rows, footer counts toward them  |
| 11x3      | 11x3   | Tight fit: the proposal equals the ideal size, so nothing clips or fills (inferred) |
| 9x3       | 9x3    | Narrower than the ideal: lines clip at column 9, height unchanged                   |
| 6x2       | 6x2    | Under-minimum: below the 8x3 minimum, the block clips at the proposed 6x2           |
| 40x9      | 40x3   | Over-maximum: fills 40 columns with blank cells; height stays at the ideal 3 rows   |

## Environment

Tokens consumed, each defined in [tokens.md](../tokens.md).

- `primary`: source text.
- `syntax.keyword`: keywords.
- `disabled`: not used.

Roles, each defined in tokens.md:

- `secondary`: line-number gutter and overflow footer; `border`: the `│` gutter separator.
- `syntax.*`: the roles a highlighter returns; see
  [syntax roles](../tokens.md#syntax-roles).

Environment values, not tokens: `.syntaxHighlighter(_:)` and `.codeTabWidth(_:)`; see
[API direction](#api-direction).

## Primitive dependencies

- [Text](../primitives/text.md): preformatted rows, one `Text` per source line with
  `.lineLimit(1)` and `.truncationMode(.clip)`. CodeView expands tabs before rows reach
  Text, so Text receives no tab characters (see [Tab width](#tab-width)).

## Requirements

Schema: [README](../../design.md#requirements-list). Each entry traces to a callout or
state above.

- `code view keeps spacing and line breaks verbatim` (Anatomy callout 2)
- `code view clips long lines at the panel edge and never wraps them, whatever the height proposal`
  (Wrap exception; Anatomy callout 3, Mobile)
- `code view draws the line-number gutter in secondary` (Numbered gutter callout 1)
- `code view draws the gutter separator in border` (Numbered gutter callout 1)
- `code view sizes the gutter to the decimal width of the last line number plus three columns`
  (Numbered gutter)
- `code view counts the overflow footer toward maxRows` (Overflow footer)
- `code view draws the overflow footer as "… N more lines" in secondary` (Overflow footer
  callout 2)
- `code view draws plain text when no highlighter is installed` (Syntax highlighting;
  Degradation)
- `code view prefers explicit tokens over the installed highlighter` (Syntax highlighter
  hook)
- `code view draws each token in the syntax role its highlighter returns` (Syntax
  highlighter hook)
- `code view passes the path extension as the highlighter language` (API direction)
- `code view expands tabs to 2 cells by default` (Tab width)
- `code view takes its tab width from a language closure when one is set` (Tab width)
- `code view sizes nil by nil as gutter plus widest line by min of rows and maxRows`
  (Sizing, nil x nil)
- `code view keeps the ideal size for a tight proposal` (Sizing, tight)
- `code view clips proposals below its minimum` (Sizing, under-minimum)
- `code view fills proposals wider than its ideal width` (Sizing, over-maximum)
- `code view draws its minimum at 8x3: a four-column gutter and four source cells`
  (Minimum; owner decision, 2026-10-10)
- `code view keeps syntax hues on at 16 colours and resolves a hue below 3:1 to syntax.plain`
  (Degradation)

## Degradation

Follows the [degradation ladder](../tokens.md#degradation-ladder). Under `NO_COLOR`,
syntax roles keep only their attributes: comments italic and dim, punctuation dim, every
other role plain. At 16 colours the syntax hues stay on in the slot palette, except that a
hue whose slot is below 3:1 against a known background resolves as `syntax.plain`
(readability floor; [syntax roles](../tokens.md#syntax-roles)). The source text and gutter
remain. With no highlighter installed, or no `path`, the source draws plain. Below the 8x3
minimum the block clips at the proposed size (see [Sizing](#sizing)); lines still never
wrap and the cut carries no mark.

This design was reviewed against the
[Phase 4 theses](../../spec.md#phase-4--view-layer-the-tessera-module): the source, path
and tokens are app-owned values redeclared on every update; the highlighter is an
app-installed environment value behind a synchronous protocol, so Tessera ships no grammar
and owns no business state; rows are recomputed each pass and clipped in integer cells;
and the view takes no input.

## Open questions

None open. The grammar question is closed for 1.0: no grammar ships, and apps supply
tokens through the hook (owner decision, 2026-10-10). The sizing rules are in
[Sizing](#sizing), and the tab rule is in [Tab width](#tab-width). The Swift spellings of
the modifiers, `SyntaxToken` and the `tokens:` parameter are deferred to plan 032 step
16.3; `.maxRows(_:)` follows the key's spelling (key B8).

## Inspiration

None yet.
