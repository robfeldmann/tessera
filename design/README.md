# Tessera design catalog

This directory is the design catalog for Tessera's view-layer components: the low-level
primitives (Text, Divider, Border, ...) and the widgets (TextField, List, Table, ...) that
Phase 4 of [the spec](../docs/Spec.md) builds. The spec stays the constitution —
architecture, the controlled-widget rule, `NodeState` discipline, the layout protocol —
while this catalog owns per-component detail: appearance, interaction tables, state
models, and requirements. Never restate a spec rule here; link to it, for example
[Slice 7](../docs/Spec.md#slice-7-catalog-integration--list-section-controlled-widgets-and-the-showcase).

The catalog's core trick: a terminal UI's medium is a character grid, so a wireframe drawn
at exact dimensions is simultaneously the full-fidelity design and a candidate golden
fixture for the [snapshot harness](../docs/Spec.md#slice-1-the-snapshot-harness).
Everything below exists to keep wireframes fixture-grade and behavior tables test-grade.

## Layout

```text
design/
  README.md         this file: process, conventions, table schemas, index
  tokens.md         shared visual vocabulary: viewports, borders, selection, ...
  inbox.md          append-only inspiration capture
  templates/        starting points for new docs
    primitive.md
    widget.md
  primitives/       render/layout vocabulary: stateless, no focus, no bindings
  widgets/          stateful, focusable, controlled components
```

## Status ladder

```yaml
---
kind: widget # widget | primitive | tokens | app
status: sketch # sketch | wireframed | specified | ready | implemented
---
```

`tokens` is the shared-vocabulary catalog kind. Its promotion follows the same ladder, but
it has no component anatomy or interaction tables: it is `specified` when every token row
defines its full and degradation behavior, and `ready` when those decisions are closed,
its requirements trace to token rows, and every `ready` catalog consumer can name the row
it uses. `app` is reserved for runnable integration designs.

Promotion gates:

| Status        | Gate                                                                                                                                                                                                                                                                                            |
| ------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `sketch`      | Doc exists from the template. Overview written; at least one prior-art citation. Legal to be wrong everywhere else.                                                                                                                                                                             |
| `wireframed`  | Anatomy wireframe with callouts. Widgets additionally show `mobile` and `min` states. All wireframe blocks pass `scripts/check-wireframes.py`.                                                                                                                                                  |
| `specified`   | Every schema table complete and schema-valid. Requirements written as test-name sentences, each traced to a table row or wireframe state. Degradation documented. Open questions explicit.                                                                                                      |
| `ready`       | All primitive dependencies are `ready` or `implemented`. Open questions resolved, or explicitly deferred to an exact `docs/Spec.md` anchor / issue. Reviewed against the [Phase 4 theses](../docs/Spec.md#phase-4--view-layer-the-tessera-module). Eligible to become an `.agents/plans/` plan. |
| `implemented` | Code merged. Durable content migrated to a DocC extension file (see Graduation). Wireframes landed as snapshot fixtures. The catalog doc shrinks to a stub pointing at both.                                                                                                                    |

Partial ideas are first-class: dropping one paragraph into a `sketch` doc, or one line
into `inbox.md`, is always legal. Only promotion costs effort.

## Viewports

Canonical sizes live in [tokens.md](tokens.md#viewports) and are referenced by name.
Widgets must wireframe `mobile` and `min` to pass `wireframed`; the anatomy wireframe may
use any natural component size. A component is wireframed at its natural height: its
`mobile` state is the component at 40 columns, not padded to a 40x16 frame (owner
decision, 2026-10-10). Full-height `mobile` and `desktop` mockups are only required when
the component's whole point is filling a screen.

## Wrap and truncation

Tessera shows as much of the information as it can (owner decision, 2026-10-18). Four
rules hold catalog-wide:

1. **Width:** content word-wraps at any finite width, whatever the height. A word wider
   than the space breaks between grapheme clusters; it is never clipped. A nil width
   proposal does not wrap.
2. **Rows:** content gets every row it needs when the height is unbounded (a nil height
   proposal, or ScrollView content). Under a fixed row budget it fills the rows, and only
   the last visible row ends in `…` (tail is the default truncation mode). `lineLimit(n)`
   is an app-chosen row budget.
3. **Chrome** is single-line and keeps its drop and truncate rules: glyphs, key hints,
   badges, tab chips, segments, status strips, and Button labels. A control label is
   chrome only where its design fixes it to one row; otherwise it is content.
4. **Apps can always override** with `lineLimit` and `truncationMode`. Both flow through
   the environment to content; chrome pins its own values.

[Text](primitives/text.md#wrapping) owns the mechanics,
[ScrollView](widgets/scroll-view.md#rows-and-variable-height-content) the row-based
scrolling that List, Picker menus, and Form build on, and
[Readable width](primitives/readable-width.md) the prose width cap. Anatomy callouts say
whether each text region is `content, wraps` or `chrome, one row`. A minimum width is the
smallest width at which the component's primary content still shows every word whole.

A component may break rule 1 or 2 on purpose. Exceptions are not rules: each one is
written in the component's own doc, beside the behavior it changes, as a blockquote that
starts `Wrap exception`, names the broken rule, and gives a one-line reason:

```markdown
> Wrap exception (rule 1): the title stays on one row and tail-truncates. A second row
> would break the top border it sits in.
```

## Wireframe conventions

Every wireframe is a fenced block tagged with its exact size and, optionally, a stable id:

````text
```wireframe 12x3 id=confirm
┌──────────┐
│ OK       │
└──────────┘
```
````

`NAME` in `id=NAME` is lowercase words joined by hyphens (`[a-z0-9]+(-[a-z0-9]+)*`) and
unique within its doc. A wireframe's identity is its doc's file name plus its `id`, or,
when it has none, its 0-based position among the doc's `wireframe` fences. Tests and
gallery renders (`.build/tessera-dev/<slug>/<id-or-index>-current.svg`) are keyed by that
identity: give an `id` to any wireframe a test pins, because inserting a wireframe shifts
every later position.

Rules, enforced by `scripts/check-wireframes.py`:

1. **Dimensions:** exactly H rows; every row's display width is at most W. Rows are
   trailing-trimmed (matching the harness `.terminalText(trim: .trailing)` policy), so no
   trailing spaces and no tabs, which also keeps prettier and markdownlint away from
   mockups.
2. **Geometry:** without annotations, the checker validates closed light, rounded, heavy,
   and double Unicode boxes rooted at a top-left corner. Geometry is measured at practical
   extended-grapheme cluster starts: combining marks, variation selectors, emoji
   modifiers, ZWJ sequences, regional-indicator pairs, and keycap marks stay with their
   base. A ZWJ-, emoji-presentation-, or keycap cluster occupies two columns;
   combining-only additions occupy zero; other clusters use their visible base's width. It
   checks reciprocal side and bottom connections, permits titles or text gaps on a top
   border, and points out likely one- or two-column shifted vertical connections.
   Compatible trailing scroll indicators (`│`, `┃`, `█`, or ASCII `|`, `#`) must keep
   their last non-space display column across adjacent rows. Within a detected box
   network, a Unicode junction with at least two reciprocal neighbors must have a
   reciprocal neighbor for every declared arm. Outside a detected box network, the same
   rule applies only when at least three declared arms have reciprocal neighbors; this
   catches real crosshairs while leaving two-neighbor dividers and standalone specimen
   glyphs clean. This is deliberately conservative: it does not infer or validate ASCII
   `+`/`-`/`|` boxes (other than `|`/`#` trailing indicator continuity), arbitrary diagram
   geometry, or visual intent beyond the supported Unicode box-drawing glyphs.
3. The grid is pristine: no markers, arrows, or prose inside or beside it. Anything you
   would diff lives in the grid; anything you would explain lives in the callouts.
4. Coordinates are 0-based, `rN` / `cN`, matching the harness `cell(row:column:)`.
5. Grapheme width follows the geometry rule above; CJK, emoji-presentation, keycap, and
   ZWJ clusters count 2 columns, while combining-only additions count 0.
6. **Header:** the fence header is `WxH` or `WxH id=NAME` and nothing else; `NAME` is
   valid and unique as described above, and does not equal the position of an id-less
   wireframe in the same doc.

Each wireframe is followed by a callout list in a `text` fence. Callouts name the regions
of the component and cite the primitive or token responsible:

```text
Callouts (46x9, 0-based):
1. r0      Header row -- Text, token `table.header`; pinned, excluded from scroll
2. r1      Header rule -- Divider, token `divider.light`, full width
3. r3 c0   Selection bar -- token `selection.bar`; row also gets `selection.fill`
```

Region names introduced in callouts ("header row", "selection bar") are the only valid
values for the mouse table's Region column. That cross-reference keeps anatomy and
behavior in sync.

For hairy geometry, an annotated copy of the grid with a ruler and markers drawn in is
allowed in a plain `text` fence, labeled `(annotated copy -- not a fixture)`. It is
non-normative; the tagged wireframe stays the truth.

Style overlays (color, bold) use the spec's
[styled-grid convention](../docs/Spec.md#snapshot-representations): a `text` fence with a
character grid and an aligned attribute grid plus a legend. The catalog fixes that
convention in [Styled grids](#styled-grids), and the checker lints it.

### Styled grids

A styled grid layers colour and attributes over a wireframe. It is one `text` fence with
three sections, in this order and no others: `── chars ──`, `── style ──`, `── legend ──`.

````text
```wireframe 6x1 id=save
▐Save▌
```

```text
── chars ──
▐Save▌
── style ──
ABBBBA
── legend ──
.  default
A  fg=accent -- the half-block caps
B  fg=contrast bg=accent bold -- the label on the solid fill
```
````

Rules, enforced by `scripts/check-wireframes.py` (it reports `file:line` for each
violation):

1. **Ownership:** a styled grid belongs to the nearest preceding `wireframe` fence in the
   same doc, and its chars rows must equal that wireframe's rows (trailing spaces
   ignored). A grid that illustrates no wireframe opens with ` ```text standalone `
   instead; it skips the matching rule and is still linted.
2. **Style rows:** one letter per display cell, and `.` is the default style. A style row
   may be shorter than its chars row (the missing cells are the default style) and may run
   past the trimmed chars, up to the wireframe's width W, to style trailing blanks. There
   are no more style rows than chars rows. A `standalone` grid has no W to cap its rows.
3. **Legend lines:** `L  SPEC` or `L  SPEC -- description`. `L` is one character, unique
   in the legend, and `.  default` is the default entry (it may be omitted). `SPEC` is one
   or more space-separated tokens: `fg=ROLE` or `bg=ROLE` (at most one of each) and the
   attributes `bold`, `dim`, `italic`, `underline`, `reverse`, `strikethrough`. `ROLE` is
   a name from the backticked first column of the role tables in
   [tokens.md](tokens.md#roles) (`primary`, `accent`, `selection.fill`, `syntax.plain`,
   `contrast`, and so on) or `faint(R)` with `R` such a role. `solid(R)` is not a role; a
   legend spells it `fg=contrast bg=R bold`.
4. **Prose:** free text goes only in the description after the `--` divider (a space on
   each side), never in the spec. A word the grammar does not know (`tinted fill`,
   `fg=focus: cursor`, `fg=focus, bold`) is an error.
5. **Letters:** every style letter used is defined in the legend, and every legend letter
   other than `.` is used.

## Linking and portability

- Standard relative markdown links only: `[Divider](../primitives/divider.md)`. Section
  anchors work in the same syntax, same-file and cross-file: `[gates](#status-ladder)`,
  `[viewports](tokens.md#viewports)`. Anchors are the GitHub slug of the heading
  (lowercase, spaces to hyphens, punctuation stripped), so keep catalog headings free of
  punctuation and renaming a heading means fixing inbound links.
- Wireframes in `wireframe` fences, everything else in `text` fences, tables as pipe
  tables. All three survive the eventual DocC migration nearly verbatim.

## Table schemas

The behavior sections of a component doc are tables with fixed columns and closed
vocabularies. Read this section before writing any of them. A table that violates its
schema fails review; a precondition that references undeclared state usually means the
state model is missing a row.

### Key table

Columns: `Key | Precondition | Effect | Consumed`

- `Key`: normalized notation mapping 1:1 onto the spec's `Key`/`Modifiers` (Phase 2 Slice
  5): arrows as glyphs, `Enter`, `Esc`, `Tab`, `Backspace`, `Delete`, `Home`, `End`,
  `PgUp`, `PgDn`, `Space`, printable characters, chords with fixed modifier order
  `Ctrl-Alt-Shift-` (`Ctrl-a`, `Alt-Left`).
- `Precondition`: `always`, `focused`, or a predicate referencing only rows of this doc's
  state model table (`selection is set`, `offset below max`).
- `Effect`: imperative; must name which state-model row changes and through what
  (`moves selection via binding`, `mutates NodeState offset`).
- `Consumed`: `yes`, `no`, or `conditional (...)`. Default is `no`; the
  [routing rule](../docs/Spec.md#phase-4--view-layer-the-tessera-module) is that the graph
  never consumes input unless a handler says so, so every `yes` is a deliberate claim.

Example:

| Key  | Precondition | Effect                                   | Consumed |
| ---- | ------------ | ---------------------------------------- | -------- |
| Down | focused      | moves selection to next row via binding  | yes      |
| Home | focused      | moves selection to first row via binding | yes      |

### Mouse table

Columns: `Event | Region | Precondition | Effect | Consumed`

- `Event`: `click`, `double-click`, `drag`, `wheel-up`, `wheel-down`, `wheel-left`, or
  `wheel-right`. `move` is allowed but flagged: it is the noisy stream the input thesis
  bounds.
- `Region`: must be a region named in this doc's anatomy callouts. Nothing else is valid.
- Remaining columns as in the key table.

Example:

| Event    | Region   | Precondition   | Effect                            | Consumed |
| -------- | -------- | -------------- | --------------------------------- | -------- |
| click    | data row | always         | sets selection to row via binding | yes      |
| wheel-up | anywhere | offset above 0 | decrements NodeState offset       | yes      |

### State model table

Columns: `State | Owner | Type | Reset or clamp rule`

- `Owner` is one of:
  - `Binding` -- app-owned; must appear in the init signature.
  - `NodeState` -- ephemeral; throwing it away may lose position (scroll, cursor) but
    never data. If losing it loses data, it must be a binding.
  - `Environment` -- styling or configuration read from the environment; a styling value
    must be a token defined in [tokens.md](tokens.md).
  - `derived` -- recomputed during layout or render, never stored.
- `Reset or clamp rule`: what happens when the app mutates the binding underneath the
  widget. Every `NodeState` and `derived` row must answer this; "clamps on every update"
  is the
  [Slice 7 baseline](../docs/Spec.md#slice-7-catalog-integration--list-section-controlled-widgets-and-the-showcase).

Runtime ownership invariant: every `NodeState` row has exactly one live storage owner. A
stateful `LeafView` handles events through `LeafView.handleEvent`, so measurement,
rendering, and events share that `NodeState`. A component must not mirror the same
ephemeral value into a separate responder or wrapper store, or transfer it between
independent stores across graph updates. Measurement and `body` stay pure: state changes
only through event handling.

Example:

| State         | Owner     | Type          | Reset or clamp rule                      |
| ------------- | --------- | ------------- | ---------------------------------------- |
| selection     | Binding   | `Element.ID?` | app-owned; widget never invents a value  |
| scroll offset | NodeState | `Int`         | clamps to content bounds on every update |

### Sizing table

Columns: `Proposal | Result | Rule`

- `Proposal`: `WxH` with `nil` allowed per axis (`nil` means unconstrained: report the
  ideal). Mandatory rows: `nil x nil`, a tight fit, under-minimum, over-maximum.
- `Result`: exact integers. The spec's layout testing posture is
  [tolerance-free](../docs/Spec.md#testing-posture-tessera-native-oracles); if a result
  needs a tolerance, the rule is wrong.
- `Rule`: one sentence naming the sizing behavior that produced the number.

Example:

| Proposal  | Result | Rule                                    |
| --------- | ------ | --------------------------------------- |
| nil x nil | 24x1   | ideal is content width, height always 1 |
| 10x5      | 10x1   | fills proposed width, height always 1   |

### Requirements list

Not a table, but schema'd: each entry is a backticked sentence-style Swift Testing
function name (per `AGENTS.md`), must be assertable with graph + dispatch + buffer
snapshot (no clocks, no live terminal), and must trace to a specific table row or
wireframe state in parentheses. An untraceable requirement means a missing table row or a
missing wireframe.

```text
- `selection stays visible when table scrolls` (key table: Down; state: scroll offset)
```

## Prior art

Every doc cites concrete sources in its prior-art section. Local references first:

- Ratatui widgets: `~/Developer/ratatui/ratatui/main/ratatui-widgets/src/` (`table.rs`,
  `list.rs`, `scrollbar.rs`, `block.rs`, `paragraph.rs`, ...).
- Bubbles (Charm) for interaction feel -- useful as contrast, since bubbles widgets own
  their state and Tessera's are controlled.
- Textual (Python) for widget-gallery breadth.
- SwiftUI for API vocabulary and sizing semantics.

## Inbox workflow

`inbox.md` is append-only: dated one-liners, zero structure required. Triage periodically;
every entry either dies or moves into a component doc's inspiration section. The inbox is
the only file where unsorted thoughts are welcome.

## Graduation

When a component is implemented, its doc ships instead of rotting:

1. Durable content (overview, anatomy wireframe, interaction tables) moves into a DocC
   extension file at `Sources/Tessera/Tessera.docc/Extensions/ComponentName.md` whose
   first line is a symbol-link heading, for Table:

   ```text
   # ``Tessera/Table``
   ```

   DocC merges the file into the symbol page above the generated API listing -- curated
   design up top, live properties and methods below.

2. Wireframes additionally land as snapshot fixtures; CI enforces the pictures from then
   on.
3. The catalog doc becomes a stub: frontmatter `status: implemented`, a link to the DocC
   page, and any process-only residue (rejected alternatives, deferred questions).

This migration step is part of the component's implementation definition of done, not an
optional cleanup.

## Validation

```fish
just quality wireframes
npm run check:markup
```

These repository-local commands run the pinned wireframe and Markdown-formatting gates; do
not substitute globally installed `pnpx`, `prettier`, or markdownlint commands.

## Component gallery

```fish
python3 scripts/gallery-serve.py   # http://127.0.0.1:8790/
```

The gallery lists every catalog doc by slug, grouped by folder, with its status, and shows
each doc's wireframes. It reads the `wireframe` fences of `primitives/*.md` and
`widgets/*.md` directly, so there is no second copy to keep in step, and a banner offers a
reload when a doc changes. Each fence is one entry, labelled with the nearest heading, its
`WxH` and its [viewport](tokens.md#viewports) name. A styled grid that belongs to the
fence colours it for the theme chosen with `?theme=` (the five review themes in
`DevTools/gallery/themes.json`), and its callouts show under it. `/tokens` draws the role
swatches of [tokens.md](tokens.md) in its three tiers beside catalog samples on every
theme. The script needs only the standard library; `--port` and `--host` change where it
listens.

Each entry also has empty **Current** and **Previous** slots for the renders of the real
widgets. Later they read `.build/tessera-dev/<slug>/<id-or-index>-current.svg` and
`<id-or-index>-previous.svg` as `tessera-dev` writes them (plan 033, Phase C), and say
"not built yet" until then; the stem is the fence's `id` when it has one, else its 0-based
position among the doc's `wireframe` fences. The gallery only displays files; it never
decides pass or fail. A `standalone` styled grid has no wireframe to compare, so it is
drawn as its own entry after the doc's wireframes, without slots. What the gallery cannot
honour (a grid that matches no wireframe, an unknown legend token, a style letter the
legend does not define) shows as a warning badge on the entry; the checker above is the
gate.

## Index

Statuses below are the documents' own. Plan 032 step 5.2 wrote the owner's omp2 review
decisions into these docs, and the token decisions in [tokens.md](tokens.md) are now
applied; what remains are the open questions and gates each doc lists.

| Component                                                     | Kind      | Status     | Blocked on                                                                   |
| ------------------------------------------------------------- | --------- | ---------- | ---------------------------------------------------------------------------- |
| [Background](primitives/background.md)                        | primitive | ready      | —                                                                            |
| [Badge](primitives/badge.md)                                  | primitive | wireframed | capsule shape (Slice 3)                                                      |
| [Border](primitives/border.md)                                | primitive | ready      | —                                                                            |
| [Box](primitives/box.md)                                      | primitive | ready      | —                                                                            |
| [Button](widgets/button.md)                                   | widget    | specified  | touch (Phase 5)                                                              |
| [Callout](widgets/callout.md)                                 | widget    | wireframed | promotion check                                                              |
| [Code view](widgets/code-view.md)                             | widget    | specified  | Phase 4 theses review                                                        |
| [ContentUnavailableView](widgets/content-unavailable-view.md) | widget    | wireframed | promotion check (loading requirement trace); blank Search icon under Unicode |
| [Divider](primitives/divider.md)                              | primitive | ready      | —                                                                            |
| [Flex](primitives/flex.md)                                    | primitive | ready      | —                                                                            |
| [Form](widgets/form.md)                                       | widget    | specified  | ViewThatFits doc                                                             |
| [Frame](primitives/frame.md)                                  | primitive | ready      | —                                                                            |
| [Grid](primitives/grid.md)                                    | primitive | sketch     | Flex + public API and measurement decisions; ViewThatFits                    |
| [Image](widgets/image.md)                                     | widget    | wireframed | protocol tiers (Kitty slice)                                                 |
| [KeyLegend](widgets/key-legend.md)                            | widget    | specified  | Phase 4 theses review                                                        |
| [Label](primitives/label.md)                                  | primitive | specified  | Phase 4 theses review                                                        |
| [LabeledContent](widgets/labeled-content.md)                  | widget    | wireframed | promotion check                                                              |
| [Leading rail](primitives/leading-rail.md)                    | primitive | specified  | Phase 4 theses review                                                        |
| [Linear stacks](primitives/stacks.md)                         | primitive | ready      | —                                                                            |
| [List](widgets/list.md)                                       | widget    | specified  | context menus, bulk expand chords; mouse routing                             |
| [Markdown](widgets/markdown.md)                               | widget    | specified  | Phase 4 theses review                                                        |
| [MultiPicker](widgets/multi-picker.md)                        | widget    | specified  | ViewThatFits doc                                                             |
| [NavigationSplitView](widgets/navigation-split-view.md)       | widget    | wireframed | post-1.0 (owner decision, 2026-10-09)                                        |
| [Outline](widgets/outline.md)                                 | widget    | wireframed | promotion check                                                              |
| [Overlay](primitives/overlay.md)                              | primitive | ready      | —                                                                            |
| [Padding](primitives/padding.md)                              | primitive | ready      | —                                                                            |
| [Picker](widgets/picker.md)                                   | widget    | specified  | ViewThatFits doc                                                             |
| [ProgressView](widgets/progress-view.md)                      | widget    | wireframed | ViewThatFits doc                                                             |
| [Readable width](primitives/readable-width.md)                | primitive | specified  | Phase 4 theses review                                                        |
| [ScrollIndicator](primitives/scroll-indicator.md)             | primitive | specified  | environment key spelling (`.scrollIndicatorStyle(_:)`)                       |
| [ScrollView](widgets/scroll-view.md)                          | widget    | specified  | ScrollIndicator ready gate                                                   |
| [Section](widgets/section.md)                                 | widget    | specified  | List ready gate                                                              |
| [SplitView](widgets/split-view.md)                            | widget    | ready      | —                                                                            |
| [Stepper](widgets/stepper.md)                                 | widget    | specified  | Phase 4 theses review                                                        |
| [Style modifiers](primitives/style-modifiers.md)              | primitive | ready      | —                                                                            |
| [TabView](widgets/tab-view.md)                                | widget    | wireframed | promotion check                                                              |
| [Table](widgets/table.md)                                     | widget    | specified  | Shift-range selection                                                        |
| [Text](primitives/text.md)                                    | primitive | ready      | —                                                                            |
| [Text selection](primitives/text-selection.md)                | primitive | sketch     | hit testing, pointer capture, and copy policy                                |
| [TextField](widgets/text-field.md)                            | widget    | wireframed | initializer and style signatures                                             |
| [Tokens](tokens.md)                                           | tokens    | ready      | —                                                                            |
| [Toggle](widgets/toggle.md)                                   | widget    | specified  | Phase 4 theses review                                                        |
| [ZStack](primitives/z-stack.md)                               | primitive | ready      | —                                                                            |
