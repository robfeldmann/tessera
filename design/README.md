# Tessera design catalog

This directory is the design catalog for Tessera's view-layer components: the low-level
primitives (Text, Divider, Border, ...) and the widgets (TextField, List, Table, ...) that
Phase 4 of [the spec](../docs/Spec.md) builds. The spec stays the constitution —
architecture, the controlled-widget rule, `NodeState` discipline, the layout protocol —
while this catalog owns per-component detail: appearance, interaction tables, state
models, and requirements. Never restate a spec rule here; link to it, for example
[Slice 7](../docs/Spec.md#slice-7-catalog-integration--list-section-controlled-widgets-and-the-showcase).

The Showcase is the runnable integration catalog; its design lives in
[showcase.md](showcase.md).

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
  showcase.md       reference integration app composing the catalog
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
it uses. `app` is reserved for runnable integration designs such as Showcase.

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
use any natural component size. Full `desktop` mockups are only required when the
component's whole point is filling a screen.

## Wireframe conventions

Every wireframe is a fenced block tagged with its exact size:

````text
```wireframe 12x3
┌──────────┐
│ OK       │
└──────────┘
```
````

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
character grid and an aligned attribute grid plus a legend. Style grids are not linted;
keep them aligned by construction.

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
  - `Environment` -- styling or configuration; must be a token defined in
    [tokens.md](tokens.md).
  - `derived` -- recomputed during layout or render, never stored.
- `Reset or clamp rule`: what happens when the app mutates the binding underneath the
  widget. Every `NodeState` and `derived` row must answer this; "clamps on every update"
  is the
  [Slice 7 baseline](../docs/Spec.md#slice-7-catalog-integration--list-section-controlled-widgets-and-the-showcase).

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

## Index

| Component                                               | Kind      | Status     | Blocked on                                                |
| ------------------------------------------------------- | --------- | ---------- | --------------------------------------------------------- |
| [Background](primitives/background.md)                  | primitive | sketch     | Slice 3 sizing, style, and Slice 5 hit-testing decisions  |
| [Button](widgets/button.md)                             | widget    | wireframed | focus/key routing + hit testing + semantic style API      |
| [Border](primitives/border.md)                          | primitive | sketch     | Slice 3 glyph, sizing, and degenerate-frame decisions     |
| [Box](primitives/box.md)                                | primitive | sketch     | Border, Text, Padding, and title-policy design            |
| [Divider](primitives/divider.md)                        | primitive | ready      | —                                                         |
| [Frame](primitives/frame.md)                            | primitive | ready      | —                                                         |
| [Flex](primitives/flex.md)                              | primitive | ready      | —                                                         |
| [Linear stacks](primitives/stacks.md)                   | primitive | ready      | —                                                         |
| [List](widgets/list.md)                                 | widget    | sketch     | Slice 3 style + Slice 4/5 routing + List contract design  |
| [NavigationSplitView](widgets/navigation-split-view.md) | widget    | wireframed | SplitView + List/Section + compact policy                 |
| [Overlay](primitives/overlay.md)                        | primitive | sketch     | Slice 3 sizing plus Slice 5 layer-hit policy              |
| [Padding](primitives/padding.md)                        | primitive | ready      | —                                                         |
| [Picker](widgets/picker.md)                             | widget    | sketch     | focus/key routing + control contract design               |
| [Section](widgets/section.md)                           | widget    | sketch     | List composition + grouping contract design               |
| [Showcase](showcase.md)                                 | app       | wireframed | component contracts + reconciliation questions            |
| [ScrollIndicator](primitives/scroll-indicator.md)       | primitive | wireframed | axis/API spelling + shared style protocol                 |
| [ScrollView](widgets/scroll-view.md)                    | widget    | ready      | —                                                         |
| [SplitView](widgets/split-view.md)                      | widget    | ready      | —                                                         |
| [Stepper](widgets/stepper.md)                           | widget    | sketch     | focus/key routing + control contract design               |
| [Style modifiers](primitives/style-modifiers.md)        | primitive | sketch     | `Style` API and environment-inheritance design            |
| [Table](widgets/table.md)                               | widget    | specified  | Text truncation + ScrollIndicator primitives (ready gate) |
| [Text](primitives/text.md)                              | primitive | ready      | —                                                         |
| [TextField](widgets/text-field.md)                      | widget    | wireframed | focus/key/paste + hardware cursor + semantic style API    |
| [Tokens](tokens.md)                                     | tokens    | ready      | —                                                         |
| [Toggle](widgets/toggle.md)                             | widget    | sketch     | focus/key routing + control contract design               |
| [ZStack](primitives/z-stack.md)                         | primitive | ready      | —                                                         |
