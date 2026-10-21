---
kind: widget
status: wireframed
---

# NavigationSplitView

> **Post-1.0.** Owner decision, omp2 review, 2026-10: NavigationSplitView moves out of 1.0
> and stays in the catalog until it is scheduled
> ([Spec](../../docs/Spec.md#navigationsplitview-is-post-10)). Apps compose multi-column
> layouts from nested [SplitViews](split-view.md) for 1.0.

`NavigationSplitView` is a controlled semantic container for **sidebar**, **content**, and
optional **inspector** columns. It owns exactly the coordination every multi-pane app
re-derives by hand -- responsive presentation tiers, rendered-column resolution from an
app-owned visibility binding, compact single-column replacement driven by an app-owned
preference binding, and focus continuity across tier changes -- and nothing else. It
paints no chrome: no titlebar, no toggle buttons, no close controls, no per-column
headers. In regular and standard space it composes the supplied columns through
`SplitView`, whose dividers are the only cells this container causes to be painted; in
compact space it renders exactly one supplied, full-screen column. The container never
owns selection, destinations, a history stack, or source/browser behavior. There is no
`NodeState`, implicit animation, or alternate divider solver.

Every affordance for showing or hiding a column belongs to the app: a keybinding surfaced
in an app hint bar, a menu item, or an app-composed Button that writes the visibility
binding. This matches every surveyed TUI ecosystem (see prior art), where pane toggles are
keybindings advertised in a bottom hint bar or menu -- never buttons baked into container
chrome. An app names its three supplied columns and binds its own toggle keys. A component
catalog's sidebar lists components, not source navigation.

Which column has focus is communicated by the column's own content, not by container
chrome: a child `List` dims its selection from `selection.fill` to `selection.inactive`
when unfocused, and an app that wants a hunk/omp-style emphasized column wraps a column in
a `Box` hosting delegated focus appearance so its border tints with `focus` while any
descendant is focused. The container paints no emphasis of its own.

Provisional public direction accepts two- and three-column initializers with optional
`columnVisibility` and `preferredCompactColumn` bindings, app-configurable tier
breakpoints defaulting to the catalog thresholds, and per-column width bounds forwarded to
`SplitView` pane sizing. A `NavigationSplitViewStyle` protocol is deliberately absent (see
Decisions).

## Prior art

No surveyed TUI framework ships a navigation container -- every ecosystem hand-rolls
panes, which is the argument for Tessera owning the _policy_ while copying the chrome
conventions those apps converged on.

- Ratatui: `~/Developer/ratatui/ratatui/main/ratatui-core/src/layout.rs` -- panes are
  `Layout` constraint splits; no container exists. Copy the bottom key-hint bar from
  `examples/apps/demo2/src/app.rs` (`render_bottom_bar`) as the affordance surface. From
  [gitui](https://github.com/gitui-org/gitui) (`src/ui/style.rs`, `Theme::block`), copy
  dimming the _unfocused_ pane's chrome rather than brightening the focused one.
- Textual `containers.py` and `design.py` -- no split container; copy the
  `$border`/`$border-blurred` token pair and Harlequin's `:focus-within` border swap as
  the column-emphasis model, and the `Footer`-renders-`BINDINGS` hint-bar pattern. Its
  `HORIZONTAL_BREAKPOINTS` (3.2.0) confirms size-tier presentation as a declarative
  policy. Reject `ContentSwitcher`'s single-visible-child swap semantics.
- Charm: no container in bubbles/lipgloss; crush hard-drops its sidebar below 120x30
  (`crush/internal/ui/model/ui.go`), soft-serve names the
  `ActiveBorderColor`/`InactiveBorderColor` pair (`pkg/ui/styles/styles.go`), gh-dash
  binds pane toggles to plain keys surfaced via `bubbles/help`
  (`internal/tui/keys/keys.go`). Copy hard tier breakpoints and key-bound toggles; reject
  any clickable pane chrome -- none exists in the ecosystem.
- OpenTUI (`sst/opentui`, used by hunk): copy `focusedBorderColor` +
  `hasFocusedDescendant` ancestor cascade (`renderables/Box.ts`, `Renderable.ts`) -- the
  same shape as Tessera's delegated focus appearance. hunk toggles its sidebar with the
  bare key `s` via a View-menu checkbox and renders no pane titlebars and no close `X`
  anywhere; copy that restraint. Reject hunk's _absence_ of a pane focus signal -- it gets
  away with one linear selection stream; a multi-column container does not.
- herdr ([`herdrdev/herdr`](https://github.com/herdrdev/herdr), v0.8.0 `Cargo.toml`:
  `ratatui = "0.30"`) -- the model-selector UI that prompted this review is a ratatui app,
  not OpenTUI; further evidence that pane composition and chrome are hand-rolled app
  conventions on top of bare layout splits, not framework containers.
- Apple SwiftUI
  [`NavigationSplitView`](https://developer.apple.com/documentation/swiftui/navigationsplitview)
  -- copy two/three-column construction, the `columnVisibility` and
  `preferredCompactColumn` bindings, compact single-column replacement, and the
  `navigationSplitViewColumnWidth(min:ideal:max:)` shape for per-column width bounds.
  Reject automatic "useful column" inference, `NavigationStack`/`NavigationLink`, and
  toolbar injection. Naming departs deliberately: Tessera's wide primary surface is
  `content` and its optional trailing column is `inspector` (Apple's separate
  [inspector presentation](<https://developer.apple.com/documentation/swiftui/view/inspector(ispresented:content:)>));
  SwiftUI's `detail` name is rejected (see Decisions).
- Apple AppKit
  [`NSSplitViewController`](https://developer.apple.com/documentation/appkit/nssplitviewcontroller)
  -- copy sidebar/inspector terminology. Reject controller child ownership, Auto Layout,
  lazy loading, divider delegation, and animated collapse.
- omp2's settings screen is the nearest counterpart, per the
  [translation key](../translation-key.md): a round `box` whose body puts a fixed-width
  section sidebar and the settings list side by side around a vertical `hr`
  ([settings.rs](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/chat/src/overlays/settings.rs#L1771-L1796)).
  While the user searches, it drops the sidebar and shows the list alone. Copy the
  sidebar-plus-content composition: per-column width bounds forward to SplitView pane
  sizing (keys B2, G5), and the `hr` is SplitView's `light` divider (key K7). omp2 has no
  tiers, visibility binding, or inspector, and its search swap is app recomposition, as
  Desktop replacement is here.

## Anatomy

Wide regular composition (`desktop`, 80x24). Everything visible except the two vertical
dividers is app-supplied content: the column headers, the header rule, the sidebar `List`,
the hint bar. Equal-height column headers are an app convention -- the container reserves
no header slot, so the app keeps each header the same height (one row here) for the rule
to meet cleanly. The container contributes tier policy and the `SplitView` composition
whose resolved divider columns the app's header rule meets with `┼` through
[blended junctions](../primitives/divider.md#blended-junctions).

```wireframe 80x24
Catalog                │ Button                              │ Inspector
───────────────────────┼─────────────────────────────────────┼──────────────────
  Overview             │ A focusable, activatable control.   │ role      primary
▌ Button               │                                     │ label        Save
  Toggle               │ [ Save ]   [ Cancel ]               │ focus         [x]
  Picker               │                                     │
  Stepper              │ Activation writes through the       │ Selection and
  TextField            │ app-owned action binding.           │ focus are app
                       │                                     │ state; columns
                       │ The sidebar List drives this        │ render from
                       │ column through its selection        │ bindings.
                       │ binding.                            │
                       │                                     │
                       │                                     │
                       │                                     │
                       │                                     │
                       │                                     │
                       │                                     │
                       │                                     │
                       │                                     │
                       │                                     │
                       │                                     │
                       │                                     │
Tab focus · s sidebar · i inspector · q quit
```

```text
Callouts (80x24, 0-based):
1. r0 c0-c71       Column headers -- app-supplied content inside each column; the
   container renders no titlebar and no header slot.
2. r1              Header rule -- app-composed blended Divider, token `divider.light`;
   its `┼` junctions union with the resolved SplitView divider columns. Until the buffer
   merge seam lands, fixtures may render `│` at exactly those cells.
3. r0-r22 c23      Leading divider -- `SplitView` geometry, token `divider.light`; the
   only cells the container itself causes to be painted.
4. r0-r22 c61      Trailing divider -- `SplitView` geometry, token `divider.light`.
5. r3 c0           Sidebar selection -- app child `List`; `selection.bar` and
   `selection.fill`, dimming to `selection.inactive` when the sidebar loses focus.
6. r2-r22 c24-c60  Content column -- the app-provided wide primary surface.
7. r2-r22 c62-c79  Inspector column -- the app-provided optional trailing column.
8. r23 c0-c43      Hint bar -- app-supplied affordance row; column toggles are app
   keybindings that write the visibility binding, never container buttons.
```

## States

### Desktop replacement

The visibility binding can hide both side columns; the content column then receives the
full regular width. This is recomposition from a binding write, not a route, and the
container renders no affordance chrome of its own for restoring the hidden columns.

```wireframe 80x24
Button
────────────────────────────────────────────────────────────────────────────────
The app set column visibility to the content column only.

Content receives the full width. The sidebar List and Inspector are not
composed; restoring them is an app affordance -- the app binds s and i.

















Tab focus · s sidebar · i inspector · q quit
```

```text
Callouts (80x24, 0-based):
1. r0-r1     Column header and rule -- app-supplied; no divider columns exist while one
   column renders.
2. r2-r22    Content column -- full-width primary surface.
3. r23       Hint bar -- app-supplied; the restore affordances live here.
```

### Standard sidebar

At `48 <= W < 73`, standard presentation renders the content column plus at most one side
column, resolved from the visibility binding without writing back. Which side renders when
the binding names both is settled with the visibility-shape open question below; the
writes themselves always come from app affordances.

```wireframe 60x16
Catalog                  │ Button
─────────────────────────┼──────────────────────────────────
  Overview               │ Standard space composes the
▌ Button                 │ center plus one side column.
  Toggle                 │
  Picker                 │ Showing the other side hides
  Stepper                │ this one; the toggles remain
  TextField              │ app keybindings.
                         │
                         │
                         │
                         │
                         │
                         │
                         │
Tab focus · s sidebar · i inspector · q quit
```

```text
Callouts (60x16, 0-based):
1. r0-r13 c25      Leading divider -- resolved `SplitView` divider column.
2. r3 c0           Sidebar selection -- app child `List` selection.
3. r2-r13 c26-c59  Content column -- the app-provided primary surface.
4. r15             Hint bar -- app-supplied affordance row.
```

### Mobile Catalog

Compact presentation (`23 <= W < 48`) renders exactly one full-screen column, chosen by
the app's preferred-compact-column binding among the available columns.

```wireframe 40x16
Catalog
────────────────────────────────────────
  Overview
▌ Button
  Toggle
  Picker
  Stepper
  TextField

Select a component to open content.

visible: sidebar
preferred: sidebar


Tab focus · s sidebar · i inspector
```

```text
Callouts (40x16, 0-based):
1. r0-r1   Column header and rule -- app-supplied sidebar chrome.
2. r3 c0   Sidebar selection -- app-owned child `List` selection.
3. r2-r14  Sidebar column -- the sole compact rendered column.
4. r15     Hint bar -- app-supplied; compact keeps every toggle reachable.
```

### Mobile content

```wireframe 40x16
Button
────────────────────────────────────────
A focusable, activatable control.

[ Save ]   [ Cancel ]

Compact renders exactly one column;
the app prefers the content column.

visible: content
preferred: content




Tab focus · s sidebar · i inspector
```

```text
Callouts (40x16, 0-based):
1. r0-r1   Column header and rule -- app-supplied content chrome.
2. r2-r14  Content column -- the sole compact rendered column.
3. r15     Hint bar -- app-supplied affordance row.
```

### Two-column missing-inspector state

A two-column construction has only sidebar and content. Inspector is absent, never an
empty pane, and no opener affordance is invented for it.

```wireframe 80x12
Catalog                                   │ Button
──────────────────────────────────────────┼─────────────────────────────────────
  Overview                                │ Two-column construction
▌ Button                                  │ composes sidebar and content.
  Toggle                                  │
  Picker                                  │ No inspector column is supplied;
  Stepper                                 │ none is rendered -- absence,
  TextField                               │ never a blank pane.
                                          │
                                          │
                                          │
Tab focus · s sidebar · q quit
```

```text
Callouts (80x12, 0-based):
1. r0-r10 c42      Leading divider -- resolved `SplitView` divider column.
2. r3 c0           Sidebar selection -- app-owned selection drives content.
3. r2-r10 c43-c79  Content column -- no blank inspector pane follows it.
4. r11             Hint bar -- app-supplied affordance row.
```

### Minimum

The declared compact floor is `23x10`. Below 23 columns or 10 rows, the container presents
a resize guard rather than a compact column.

```wireframe 23x10
Button
───────────────────────
Compact floor: one
rendered column.

visible: content
preferred: content


s sidebar · i inspect
```

```text
Callouts (23x10, 0-based):
1. r0-r1  Column header and rule -- app-supplied content chrome.
2. r2-r8  Content column -- compact content at the declared floor.
3. r9     Hint bar -- app-supplied; truncation is the app's own policy.
```

## Draft state model

| State                    | Owner       | Type                                                        | Reset or clamp rule                                                                                                                                                                                                      |
| ------------------------ | ----------- | ----------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| column visibility        | Binding     | `NavigationSplitViewVisibility`                             | app-owned; recomputes rendered columns on every update; standard tier enforces side mutual exclusivity when resolving, without writing back                                                                              |
| preferred compact column | Binding     | `NavigationSplitViewColumn`                                 | app-owned; an unavailable preference falls back by semantic order without mutating the binding                                                                                                                           |
| available columns        | derived     | `Set<NavigationSplitViewColumn>`                            | recomputes from supplied closures; inspector is absent for two-column construction                                                                                                                                       |
| presentation tier        | derived     | `regular`, `standard`, `compact`, or `guard`                | recomputes from proposal against app-configurable breakpoints; defaults: guard when `W < 23` or `H < 10`, otherwise regular `W >= 73`, standard `48...72`, or compact `23...47`                                          |
| rendered columns         | derived     | `[NavigationSplitViewColumn]`                               | recomputes from availability, visibility, tier, and compact preference                                                                                                                                                   |
| tier focus continuity    | derived     | `FocusID?`                                                  | when a tier or visibility change hides the column containing the focused descendant, choose the first focusable descendant of the next rendered column, then the previous, otherwise nil; business bindings never mutate |
| divider styling          | Environment | `divider.light`, `divider.ascii`                            | `SplitView` resolves every regular or standard render                                                                                                                                                                    |
| column focus emphasis    | Environment | the [Focus](../tokens.md#focus) rules, `selection.inactive` | children and app-hosted delegated focus appearance resolve per render; the container paints no emphasis of its own                                                                                                       |

The container exposes no control focus initializer arguments and installs no focusable
chrome; its focus stops are entirely the supplied children plus `SplitView`'s divider
handles. Business selection -- which sidebar row is chosen -- lives in the app's child
`List` binding, never in this container. The container owns no ephemeral interaction
state: an implementation must not mirror visibility, compact preference, focus, or
selection into `NodeState` or `_ResponderView.ResponderState`.

## Draft key table

The container defines and consumes no keys. Column toggles are app keybindings that write
the visibility or compact-preference binding (an app may bind `s` and `i` and surface them
in its [KeyLegend](key-legend.md), key E8). A sidebar `List`'s Up/Down selection writes --
and the content recomposition they trigger -- are ordinary child-binding behavior, not
container delegation. The rows below document delegation, not container behavior.

| Key       | Precondition           | Effect                                                                                                                             | Consumed |
| --------- | ---------------------- | ---------------------------------------------------------------------------------------------------------------------------------- | -------- |
| Tab       | any focused descendant | left to the app's `.onKey(.tab)` traversal over shown columns and divider handles (key E4); the container adds no stops of its own | no       |
| Shift-Tab | any focused descendant | left to the app's reverse traversal (key E4); the container adds no stops of its own                                               | no       |
| Left      | focused divider handle | `SplitView` keyboard resize per its own key table                                                                                  | no       |
| Right     | focused divider handle | `SplitView` keyboard resize per its own key table                                                                                  | no       |

## Draft mouse table

Slice 5 supplies click-to-focus. The container installs no pointer handlers; `SplitView`
owns divider drag, and clicks route to the children under the pointer.

| Event | Region           | Precondition                  | Effect                                                                         | Consumed |
| ----- | ---------------- | ----------------------------- | ------------------------------------------------------------------------------ | -------- |
| drag  | leading divider  | tier is regular or standard   | delegates to `SplitView`; content keeps `layoutPriority(1)`, sides default 0   | yes      |
| drag  | trailing divider | tier is regular               | delegates to `SplitView`; content keeps `layoutPriority(1)`, sides default 0   | yes      |
| click | content column   | Slice 5 click-to-focus landed | routes to the clicked child responder; the container adds no handler           | no       |
| wheel | content column   | child viewport under pointer  | routes to child viewports; boundary events bubble past the container untouched | no       |

## Sizing

The container is greedy when proposed. Regular and standard allocation, clipping, divider
placement, and drag policy belong to `SplitView`; compact measures only its one rendered
child. The content column has `layoutPriority(1)` while sidebar and inspector use the
default 0, so a divider drag changes the requested side pane on its first press rather
than consuming slack.

Per-column width bounds are app-declared: a `columnWidth(min:ideal:max:)`-style per-column
declaration forwards into `SplitView` pane sizing (minimum/requested-ideal/maximum), so
column geometry, clamping, and drag negotiation stay in `SplitView`'s one solver. An
undeclared width uses `SplitView`'s defaults; whether an undeclared minimum should instead
derive from the column child's minimum intrinsic width is an open question below.

| Proposal  | Result | Rule                                                                          |
| --------- | ------ | ----------------------------------------------------------------------------- |
| nil x nil | 80x24  | anatomy sample ideal is column ideals plus dividers, per `SplitView`          |
| 80 x 24   | 80x24  | regular fit fills and composes up to three columns through `SplitView`        |
| 60 x 16   | 60x16  | standard fit fills the content column plus at most one side column            |
| 40 x 16   | 40x16  | compact fit fills with exactly one rendered column                            |
| 23 x 10   | 23x10  | declared compact floor fills with the preferred available column              |
| 22 x 10   | 22x10  | guard fills safely and requests a larger viewport without hidden column state |
| 200 x 50  | 200x50 | no layout maximum; it fills and gives surplus to children through `SplitView` |

## Environment

The container itself consumes only the divider tokens through `SplitView`: `divider.light`
and `divider.ascii` from [tokens](../tokens.md). Everything else is resolved by children
or app-hosted chrome: `selection.bar` (ASCII `>`), `selection.fill`, and
`selection.inactive` by a sidebar `List`; the [Focus](../tokens.md#focus) rules by
app-hosted delegated focus appearance when a column wants hunk/omp-style emphasis. Planned
semantic styles remain complete `Style` values -- `primary`, `secondary`, `accent`,
`disabled`, `destructive` -- with no new token names introduced by this widget.

## Primitive dependencies

- [SplitView](split-view.md) -- regular and standard geometry, dividers, min-size
  negotiation, divider drag, and collapse focus targeting. Ready.
- [Divider](../primitives/divider.md) -- canonical divider vocabulary. Ready.
  [Blended junctions](../primitives/divider.md#blended-junctions) -- specified 2026-08-17,
  awaiting the buffer merge seam; the anatomy's `┼` junctions depend on it.
- [Text](../primitives/text.md) -- labels and safe clipping. Ready.
- [List](list.md) -- the sidebar child and the inactive-selection dimming story. Ready.
- Delegated focus appearance
  ([Slice 4](../../docs/Spec.md#slice-4-focus-and-key-routing-the-responder-system)) --
  lands in plan 032 step 10.2; the app-side mechanism for emphasizing a focused column
  without container chrome.
- Button -- no longer a container dependency: toggles are app affordances the app composes
  wherever it wants them.

## Slice availability and progressive sequence

1. [Slice 2](../../docs/Spec.md#slice-2-the-layout-protocol-and-stack-containers) supplies
   placement, clipping, and static regular geometry.
2. [Phase 2.5](../../docs/Spec.md#phase-25-flex-and-final-splitview-negotiation) supplies
   final negotiated SplitView panes and the responsive tier thresholds.
3. [Slice 4](../../docs/Spec.md#slice-4-focus-and-key-routing-the-responder-system)
   supplies focus traversal, removal-clears-focus behavior, and delegated focus appearance
   for app-hosted column emphasis.
4. [Slice 5](../../docs/Spec.md#slice-5-mouse-and-hit-testing) supplies click-to-focus
   inside columns; divider drag remains `SplitView`.
5. [Slice 6](../../docs/Spec.md#slice-6-grid-table-and-fitting) records this container as
   post-1.0
   ([NavigationSplitView is post-1.0](../../docs/Spec.md#navigationsplitview-is-post-10));
   once scheduled, it composes regular, standard, and compact generic column children
   through those established contracts.
6. [Slice 7](../../docs/Spec.md#slice-7-catalog-integration--list-section-and-controlled-widgets)
   supplies the controlled `List` for a sidebar column.

Before these land, app-supplied columns may be static content only. They must not
substitute a private navigator, animation shim, source browser, or layout solver.

## Requirements

- `regular three-column layout composes supplied columns through split view` (anatomy;
  sizing: 80 x 24)
- `standard presentation shows the content column plus at most one side column` (standard
  sidebar; state: rendered columns)
- `compact presentation renders exactly the preferred available column` (mobile states;
  state: preferred compact column)
- `unavailable compact preference falls back by semantic order without mutating its binding`
  (state: preferred compact column)
- `column visibility recomposes columns without any container chrome` (desktop
  replacement; state: column visibility)
- `two-column construction omits inspector instead of rendering a blank pane` (two-column
  missing-inspector state; state: available columns)
- `custom tier breakpoints recompose presentation at the configured widths` (state:
  presentation tier)
- `column width declarations forward to split view pane sizing` (sizing)
- `tier change moves focus to a rendered column without mutating business bindings`
  (state: tier focus continuity)
- `container consumes no keys and installs no pointer handlers` (key table; mouse table)
- `divider drag changes the side pane on its first press` (mouse table: leading divider;
  sizing)
- `sidebar selection dims to inactive when its column loses focus` (anatomy callout 5;
  environment)
- `under-minimum proposal presents a resize guard without hidden column state` (sizing: 22
  x 10; state: presentation tier)
- `ascii degradation preserves column structure and divider junctions` (degradation)

## Degradation

- **No color:** child selection and focus emphasis fall back per their own contracts; the
  container has no chrome of its own to degrade.
- **16-color:** roles resolve to their slots columns in [roles](../tokens.md#roles);
  behavior is unchanged.
- **ASCII-only:** `│`, `┼`, and `─` become `|`, `+`, and `-` per canonical tokens; all
  affordances are already app text.
- **Below `23x10`:** present the resize guard, mutate no business binding, and never
  substitute animation or a layout failure.

## Decisions

- **Column vocabulary (2026-08-17 hunk review):** the noun is _column_ -- "role" is
  retired as column terminology; it was SwiftUI-flavored, not a TUI term of art. (Button's
  own semantic role -- `primary`, `destructive` -- is a different concept and keeps its
  name; the anatomy's Inspector panel displays it.) The three columns are `sidebar`,
  `content`, and `inspector`: content is the wide primary surface, inspector the optional
  trailing column, named for Apple's inspector presentation. SwiftUI's `detail` is
  rejected -- its master/detail lineage reads as the _main_ surface and contradicts a
  trailing auxiliary column.
- **Pattern name** (owner decision, omp2 review, 2026-10-08): the sidebar-and-content
  pattern is called "list-detail", which replaces "master-detail".
- **No `NavigationSplitViewStyle` protocol in 1.0** (2026-08-17 hunk review): left out
  unless a need is discovered; the container paints nothing a style protocol would vary.
  Divider appearance customization stays on the existing token/environment path.
- **No framework-suggested toggle keys** (2026-08-17 hunk review): a demo serves as the
  canonical example in API documentation; the framework implements no default keys.
- **Column emphasis** (2026-08-17 hunk review): child chrome plus app-hosted delegated
  focus appearance is the emphasis model; the container paints no emphasis and no divider
  dimming of its own.
- **Tier breakpoints are configurable** (2026-08-17 hunk review): init parameters with the
  catalog defaults (regular 73, standard 48, compact 23, guard floor 23x10).

## Open questions

Deferred to post-1.0 (owner decision, 2026-10-10): all three questions stay open with no
action until this container is scheduled. They are not blocking any 1.0 deliverable.

- Does visibility name columns or visible sets for two and three columns -- and which side
  resolves in standard space when the binding names both? The resolution must be a
  stateless rule: "last-toggled wins" would require remembered state the container must
  not own.
- Is unavailable compact fallback content/sidebar/inspector or sidebar/content/inspector,
  while retaining the binding?
- Should an undeclared column minimum width derive from the column child's minimum
  intrinsic width (content compression resistance)? Unblock: Layout-protocol
  minimum-intrinsic measurement support.

## Inspiration

- 2026-07-06 -- [inbox](../inbox.md) identifies `SplitView` as the exemplar for divider
  drag, min-size negotiation, and collapse. This design preserves those as `SplitView`
  geometry and layers controlled semantic navigation columns for a demo.
- 2026-08-17 -- Adversarial review against hunk's three-column layout and omp's `/model`
  selector, backed by a four-ecosystem survey (Ratatui/gitui, Textual/Harlequin,
  Charm/crush/soft-serve/gh-dash, OpenTUI/hunk): no framework ships container chrome, all
  toggles are keybindings surfaced in hint bars or menus, and focused panes are marked by
  border/selection emphasis. The container's titlebar toggles, centered title, and bare
  `X` closes were removed and returned to the app. This supersedes, at the container
  level, the 2026-07-24 QA decision that NavigationSplitView must render the settled
  titlebar chrome; that chrome remains valid as app-owned composition.
- 2026-08-17 -- hunk review feedback (11 threads): column vocabulary replaced "role";
  blended divider junctions specced in
  [divider.md](../primitives/divider.md#blended-junctions); tier breakpoints made
  configurable; per-column width bounds specced; HintBar and a searchable `?` shortcut
  overlay triaged to the [inbox](../inbox.md).
