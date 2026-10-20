---
kind: widget
status: specified
---

# Section

`Section` is Tessera's grouping element for [List](list.md) (and future Form composition):
a header, its grouped rows, and an optional app-owned expansion binding. Section presents
structure and forwards everything else -- its rows keep their own bindings, focus, and
input untouched, and Section itself owns no data, selection, or expansion state. A header
is a noninteractive label; supplying `isExpanded: Binding<Bool>` makes it collapsible,
with the app owning that bit per the
[Slice 7](../../docs/Spec.md#slice-7-catalog-integration--list-section-controlled-widgets-and-the-showcase)
controlled-only rule. In 1.0 Section is legal only inside List; Form revisits standalone
use post-1.0. There is no footer in 1.0.

Provisional API shape (vocabulary, not a commitment):

```swift
public struct Section<Header: View, Content: View>: View {
    public init(
        _ title: String,
        isExpanded: Binding<Bool>? = nil,
        @ViewBuilder content: () -> Content
    )
    public init(
        isExpanded: Binding<Bool>? = nil,
        @ViewBuilder content: () -> Content,
        @ViewBuilder header: () -> Header
    )
}
```

An absent `isExpanded` binding means always expanded and renders no disclosure glyph; an
absent header means the section contributes rows only. Inter-section spacing (one blank
row) is List chrome, not a Section margin, so adjacent sections never double-space.

Grouped rows follow [List](list.md): they are content, so they wrap by default and
`.lineLimit(1)` restores single-line rows (owner decision, 2026-10-18). The header is the
one exception, see [Anatomy](#anatomy).

## Prior art

- SwiftUI `Section` -- copy the header/content vocabulary and the
  `Section(_:isExpanded:content:)` controlled collapse form verbatim; reject footers for
  1.0 and reject the deprecated positional `init(header:content:)` spellings.
- Textual `Tree`/`TreeNode` (`src/textual/widgets/_tree.py`) -- copy the
  expanded-vs-`allow_expand` state split (collapsibility is structural, expansion is
  state); reject widget-owned `_expanded` in favor of the app binding.
- Ratatui `List` has no section concept; its ecosystem hand-rolls styled header rows that
  arrow keys then land on (`sectioned-picker` exists to patch this). Section is the
  first-class answer: headers are unselectable by construction in
  [List's traversal](list.md#key-table).
- Lip Gloss `tree.Node.Hidden()` -- copy the mechanism: a collapsed section is filtered
  from the flattened render walk, computed from external state, never a second data model.

## Anatomy

Two adjacent sections inside a List (gutter column and selection rendered by the host
List): an expanded collapsible section with a badge row, then a collapsed one. Grouped
rows indent two columns past the gutter -- Section geometry, applied uniformly whether or
not the section has a header; sectionless List rows stay flush.

```wireframe 24x6
▾ Mailboxes
   Inbox            12
▌  Drafts            3
   Sent

▸ Projects
```

```text
Callouts (24x6, 0-based):
1. r0       Header -- Text `semantic.secondary`; noninteractive except collapse; the
            disclosure glyph `disclosure.expanded` occupies the host List's gutter column;
            chrome, one row (wrap exception)
2. r0 c0    Disclosure -- `disclosure.expanded` / `disclosure.collapsed`; rendered only
            when an expansion binding is supplied; chrome, one row
3. r1-r3    Grouped rows -- forwarded row content, indented two columns; selection and
            focus belong to the host List and the rows themselves; content, wraps (as
            List rows)
4. r4       Section spacer -- host List chrome between adjacent sections, shown for
            context; not Section geometry
5. r5       Collapsed header -- rows hidden; header remains the only contribution;
            chrome, one row
```

> Wrap exception (rule 1): the header stays on one row and tail-truncates. A wrapped
> header would break the gutter and row geometry under it. (owner decision, 2026-10-18)

Section pins `lineLimit(1)` on the header Text, so an app's inherited `lineLimit` reaches
the grouped rows and never the header. The header's `truncationMode` still comes from the
environment (default tail).

Region names for the mouse table: header, grouped rows.

## States

Mobile (40x16): grouped settings-style sections at the mobile viewport; a headerless
section contributes rows only, and an empty section renders its header and reserves no
body space.

```wireframe 40x16
▾ Appearance
   Theme                        System
   Density                       Dense
▌  Show borders                    [x]

▾ Behavior
   Confirm on delete               [x]
   Autosave                        [ ]
   Wrap long lines                 [ ]

   Reset layout
   Export settings

▸ Advanced

▾ Experiments
```

```text
Callouts (40x16, 0-based):
1. r0, r5      Expanded collapsible headers
2. r10-r11     Headerless section -- rows only, no header row reserved; still indented
3. r13         Collapsed header -- `Advanced` rows hidden
4. r15         Empty section -- `Experiments` has zero rows; header only, no body space
5. r4, r9, r12, r14 Section spacers -- host List chrome
```

Min (8x2, the declared floor): a truncated header above one row. The floor is derived from
the primary content, the grouped rows: indent 3 plus the widest row word `Inbox` (5) is 8
cells, so every row word shows whole at 8. The header is chrome and does not set the
floor; it tail-truncates with `truncation.mark` (`▾ Mailboxes` needs 11). The row is
content and wraps in the cells after the indent (owner decision, 2026-10-18).

```wireframe 8x2
▾ Mailb…
   Inbox
```

Degradation is glyph-only: the collapsed/expanded disclosure becomes `+`/`-` in ASCII (see
[List's degraded state](list.md#states) for the composed picture); geometry never changes.

## State model

| State             | Owner       | Type                    | Reset or clamp rule                                                                                                                         |
| ----------------- | ----------- | ----------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| expansion         | Binding     | `Bool` (optional param) | app-owned; absent binding means always expanded; Section never writes it except for the header-click row below                              |
| collapsibility    | derived     | `Bool`                  | structural: true exactly when an expansion binding was supplied at init; decides whether a disclosure glyph renders                         |
| rows              | derived     | forwarded content       | recomputed from the app's content builder on every update; contributes nothing to the flattened list when collapsed                         |
| header styling    | Environment | `semantic.secondary`    | header text default                                                                                                                         |
| header line limit | Environment | `Int?` pinned to 1      | Section pins `lineLimit(1)` on the header Text (Wrap exception); an inherited app `lineLimit` reaches the grouped rows and never the header |
| disclosure glyphs | Environment | `disclosure.*` tokens   | expanded/collapsed pair; ASCII pair below capability                                                                                        |

Collapsing while a grouped row is selected is the host List's "hidden selection" case: the
List renders no selection and never mutates its binding
([List state model](list.md#state-model)). Section holds no `NodeState` at all.

## Key table

Section consumes no keyboard input of its own; the host List dispatches these while
focused, writing this Section's expansion binding ([List key table](list.md#key-table)).

| Key   | Precondition                                                     | Effect                              | Consumed |
| ----- | ---------------------------------------------------------------- | ----------------------------------- | -------- |
| Left  | host List focused, selection in this section, expansion is true  | sets expansion to false via binding | yes      |
| Right | host List focused, selection in this section, expansion is false | sets expansion to true via binding  | yes      |

## Mouse table

| Event | Region       | Precondition            | Effect                         | Consumed |
| ----- | ------------ | ----------------------- | ------------------------------ | -------- |
| click | header       | collapsibility is true  | toggles expansion via binding  | yes      |
| click | header       | collapsibility is false | none -- noninteractive label   | no       |
| click | grouped rows | always                  | forwarded untouched to the row | no       |

## Sizing

Section reports the extent of its current contribution to the host List's flattened rows;
the List, not the Section, is greedy. Numbers use the anatomy's data set.

| Proposal              | Result | Rule                                                                                                                                                                                   |
| --------------------- | ------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| nil x nil             | 11x4   | ideal: widest of header and rows, unwrapped (a nil width does not wrap); height = header + 3 rows while expanded                                                                       |
| 24 x 4                | 24x4   | fills the proposed width; header and rows fit unwrapped here, so height stays content-driven                                                                                           |
| nil x nil (collapsed) | 11x1   | header only; rows contribute nothing                                                                                                                                                   |
| 12 x nil              | 12x4   | narrow width, nil height, with one row `Drafts and old mail`: the header stays one row; the row wraps in the 9 cells after the indent (`Drafts`, `and old`, `mail`), so height = 1 + 3 |
| 8 x 2                 | 8x2    | the declared floor (indent 3 + `Inbox` 5): header tail-truncates (`▾ Mailb…`), the row shows whole                                                                                     |
| 6 x nil               | 6x3    | under-minimum: header tail-truncates (`▾ Mai…`), the row breaks `Inbox` between graphemes after the indent (`Inb`, `ox`), so height = 1 + 2; never a layout failure                    |
| 200 x 4               | 200x4  | fills width; height never exceeds header + rows                                                                                                                                        |

The 12 x nil row uses a Mailboxes section holding the single row `Drafts and old mail`.

An empty section is header + 0 rows (height 1); a headerless section is rows only.

## Environment

- `semantic.secondary` -- header text default
- `disclosure.expanded`, `disclosure.collapsed`, `disclosure.ascii`
  ([tokens](../tokens.md#disclosure))
- `truncation.mark`
- `lineLimit` / `truncationMode` (environment) -- reach the grouped rows; the header pins
  its own `lineLimit(1)`

## Primitive dependencies

- [Text](../primitives/text.md#row-budget) -- header rendering with `lineLimit(1)` and
  tail truncation; row wrapping follows [List](list.md). Blocks `ready` until the Text
  wrapping slice lands, shared with List (`Sources/TesseraCore/Views/Text.swift` is still
  the non-wrapping Slice 1 leaf).
- [List](list.md) -- host widget owning traversal, selection, spacing, and scrolling;
  specified in the same pass.

## Requirements

- `header is not focusable and not selectable` (anatomy: callout 1;
  [List traversal](list.md#key-table))
- `collapsed section renders header only` (anatomy: callout 5)
- `empty section renders header and reserves no body space` (states: mobile callout 4)
- `headerless section contributes rows only` (states: mobile callout 2)
- `absent expansion binding means always expanded with no disclosure glyph` (state model:
  collapsibility)
- `click on a collapsible header toggles expansion through the binding` (mouse table:
  header)
- `click on a noninteractive header is not consumed` (mouse table: header, not
  collapsible)
- `section forwards row focus input and bindings without interception` (mouse table:
  grouped rows; state model: rows)
- `collapsing never mutates the host lists selection binding` (state model: expansion;
  [List state model](list.md#state-model))
- `header truncates with the truncation mark at the floor` (states: min)
- `header stays one row and tail-truncates under an inherited line limit` (anatomy: wrap
  exception; state model: header line limit)
- `grouped rows wrap like List rows and take every row they need` (anatomy: callout 3;
  sizing: 12 x nil)
- `narrow width wraps the rows and keeps the header on one row` (sizing: 12 x nil)
- `ascii disclosure glyphs substitute below capability` (states: degradation)

## Degradation

- `NO_COLOR`: header falls back to dim; disclosure glyphs unchanged.
- 16-color: unchanged.
- ASCII-only: `disclosure.ascii` -- `-` expanded, `+` collapsed; `~` truncation mark.
- Below `min` (8x2): tail-truncated header, rows breaking between graphemes, never a
  layout failure.

## Open questions

- Footer: excluded from 1.0 (decided above); Form's post-1.0 design owns whether a footer
  slot returns and whether it reserves space when empty.
- Keyboard expansion without a selected row in the section (a fully collapsed List has
  nothing for Left/Right to anchor on): needs either a header-cursor concept or an app
  keybinding through the expansion bindings; deferred until a real use case, since the
  bindings already permit the app path.

## Inspiration

A Section should make a flat list easier to scan without becoming a second container state
model; its value is visible structure and faithful forwarding. Collapse is presentation of
an app-owned bit, exactly like Toggle's `isOn`.
