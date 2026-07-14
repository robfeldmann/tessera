---
kind: widget
status: wireframed
---

# NavigationSplitView

`NavigationSplitView` is a controlled semantic container for **sidebar**, optional
**content**, and **detail** roles. Leading app-owned business selection recomposes later
app-provided columns; the container never owns selection, destinations, a history stack,
or source/browser behavior. In regular space it composes supplied roles through
`SplitView`; in compact space it replaces that composition with exactly one supplied,
full-screen role. Visibility, preferred compact role, and restoration focus are app-owned
bindings. There is no `NodeState`, implicit animation, or alternate divider solver.

The Showcase names its three supplied roles Catalog, Playground, and Inspector. Catalog is
a component catalog, not source navigation: no file, directory, URL, mapping, or browser
behavior is part of this widget.

Provisional public direction accepts two- and three-column initializers with optional
`columnVisibility` and `preferredCompactColumn` bindings. A standard style is default; a
custom `NavigationSplitViewStyle` protocol is accepted public direction. Its concrete
signatures and configuration types remain open.

## Prior art

- Ratatui `List`: `~/Developer/ratatui/ratatui/main/ratatui-widgets/src/list.rs` -- copy
  visible selection treatment; reject widget-owned `ListState` selection for Tessera.
- Ratatui `Block`: `~/Developer/ratatui/ratatui/main/ratatui-widgets/src/block.rs` -- copy
  compact sectional titling; reject a screen-wide decorative frame.
- Ratatui `Scrollbar`: `~/Developer/ratatui/ratatui/main/ratatui-widgets/src/scrollbar.rs`
  -- use only within a scrolling child; reject a container navigation-position indicator.
- Apple SwiftUI
  [`NavigationSplitView`](https://developer.apple.com/documentation/swiftui/navigationsplitview)
  -- copy two/three roles, regular visibility and preferred-compact bindings, and compact
  single-column replacement. Reject automatic “useful column” inference,
  `NavigationStack`/`NavigationLink`, toolbar injection, and container width modifiers.
- Apple AppKit
  [`NSSplitViewController`](https://developer.apple.com/documentation/appkit/nssplitviewcontroller)
  -- copy sidebar/inspector terminology and explicit toggles. Reject controller child
  ownership, Auto Layout, lazy loading, divider delegation, and animated collapse.

## Anatomy

Wide regular composition (`desktop`, 80x24): the container supplies only dividers and
labeled open/close controls. The selected Catalog row and all content are supplied by the
app.

```wireframe 80x24
[Close] Catalog       │ Playground                    │ [Close] Inspector
──────────────────────┼───────────────────────────────┼─────────────────────────
  Buttons             │ NavigationSplitView           │ Selection
▌ Navigation          │                               │ app-owned
  Layout              │ A semantic three-column       │ visible: all
  Inputs              │ navigation container.         │ compact: playground
                      │                               │
                      │ Catalog selection presents    │ Inspector reads
                      │ this Playground.              │ current app state.
                      │                               │
                      │ It owns neither selection     │
                      │ nor destination.              │
                      │                               │
                      │ [Close Catalog]               │ [Hide Inspector]
                      │                               │
                      │                               │
                      │                               │
                      │                               │
                      │                               │
                      │                               │
                      │                               │
                      │                               │

regular: SplitView sidebar / content / detail
```

```text
Callouts (80x24, 0-based):
1. r0 c0-c6    Sidebar toggle -- touch-visible `[Close]`; mutates app-owned visibility.
2. r0 c56-c62  Inspector toggle -- touch-visible `[Close]`; mutates app-owned visibility.
3. r1 c22      Leading divider -- `SplitView` geometry using `divider.light`.
4. r1 c54      Trailing divider -- `SplitView` geometry using `divider.light`.
5. r3 c0       Catalog selection -- app child `List`; `selection.bar`/`selection.fill`.
6. r2-r22 c23-c53  Playground column -- app-provided content role.
7. r2-r22 c55-c79  Inspector column -- app-provided detail role.
8. r13 c23-c38  Sidebar toggle -- second touch-visible close affordance.
9. r13 c55-c70  Inspector toggle -- second touch-visible close affordance.
```

## States

### Desktop replacement

The regular visibility binding can hide both side roles. Playground then replaces the
whole regular composition; it is not a route. Both reversible controls remain visible.

```wireframe 80x24
[Open Catalog] Playground                                      [Open Inspector]
────────────────────────────────────────────────────────────────────────────────
NavigationSplitView Playground

The app requested detail-only visibility.

Playground now receives the full regular width.

[Open Catalog] restores the sidebar without changing
Catalog business selection.

[Open Inspector] restores detail without changing
Inspector app state.










regular replacement: Playground only
```

```text
Callouts (80x24, 0-based):
1. r0 c0-c13   Sidebar toggle -- `[Open Catalog]` renders sidebar through the app-owned visibility binding; then restores focus from its non-nil app-supplied target.
2. r0 c56-c71  Inspector toggle -- `[Open Inspector]` renders detail through the app-owned visibility binding; then restores focus from its non-nil app-supplied target.
3. r7 c0-c13   Sidebar toggle -- duplicate touch target.
4. r10 c0-c15  Inspector toggle -- duplicate touch target.
5. r2-r21      Playground column -- full-width replacement, not a route or browser.
```

### Mobile Catalog

```wireframe 40x16
Catalog                    [Inspector]
────────────────────────────────────────
Components
▌ Navigation
  Split
  Button
  Scroll

Select a component to open Playground.

visible: Catalog
preferred: Playground

[Open Playground]

Catalog 1 of 4
```

```text
Callouts (40x16, 0-based):
1. r0 c27-c37  Inspector toggle -- labeled compact detail target.
2. r3 c0       Catalog selection -- app-owned child `List` selection.
3. r13 c0-c16  Sidebar toggle -- `[Open Playground]`, requests content presentation.
```

### Mobile Playground

```wireframe 40x16
[Catalog] Playground         [Inspector]
────────────────────────────────────────
NavigationSplitView
A semantic navigation container.

Sidebar -> Playground -> Inspector

Selection is app-owned.
No source or browser behavior.

visible: Playground
preferred: Playground

[Open Catalog]
[Open Inspector]
Playground / Navigation
```

```text
Callouts (40x16, 0-based):
1. r0 c0-c8    Sidebar toggle -- `[Catalog]` requests compact Catalog.
2. r0 c29-c39  Inspector toggle -- `[Inspector]` requests compact Inspector.
3. r12 c0-c13  Sidebar toggle -- duplicate labeled touch target.
4. r13 c0-c15  Inspector toggle -- duplicate labeled touch target.
5. r2-r15      Playground column -- sole compact supplied role.
```

### Mobile Inspector

```wireframe 40x16
[Catalog] Inspector             [Close]
────────────────────────────────────────
NavigationSplitView

selection: Navigation
regular visibility: all
compact role: Inspector

Inspector is app-provided detail.

[Open Playground]
[Open Catalog]

Close returns to the app requested
compact role; no animation is required.
Inspector / Navigation
```

```text
Callouts (40x16, 0-based):
1. r0 c0-c8    Sidebar toggle -- labeled compact Catalog target.
2. r0 c33-c39  Inspector toggle -- `[Close]` requests app's next compact presentation.
3. r9 c0-c16   Inspector toggle -- `[Open Playground]`, requests supplied content.
4. r10 c0-c13  Sidebar toggle -- duplicate labeled Catalog target.
5. r2-r15      Inspector column -- sole compact app-provided detail role.
```

### Collapsed state

After the app writes `.sidebar` to `preferredCompactColumn`, compact presentation is one
Catalog column, not a squeezed three-pane layout. The container does not choose a “useful”
role or retain a back stack.

```wireframe 40x16
Catalog                    [Open Detail]
────────────────────────────────────────
Components
▌ Navigation
  Split
  Button
  Scroll

compact: sidebar
selection: Navigation

[Open Playground]
[Open Inspector]

No implicit back stack.
Catalog / Navigation
```

```text
Callouts (40x16, 0-based):
1. r0 c27-c39  Inspector toggle -- `[Open Detail]`, requests supplied detail.
2. r3 c0       Catalog selection -- app-owned child selection.
3. r11 c0-c16  Sidebar toggle -- `[Open Playground]`, requests content.
4. r12 c0-c15  Inspector toggle -- `[Open Inspector]`, requests detail.
```

### Two-column missing-content state

A two-column construction has only Sidebar -> Detail. Content is absent, never an empty
pane, and no content opener is rendered.

```wireframe 80x12
[Close] Catalog                         │ [Close] Inspector
────────────────────────────────────────┼───────────────────────────────────────
Components                              │ NavigationSplitView
▌ Navigation                            │
  Split                                 │ Two-column construction
  Button                                │ Sidebar selection presents detail.
                                        │
                                        │ No content column was supplied.
                                        │
[Hide Catalog]                          │ [Hide Inspector]
                                        │
two columns: sidebar / detail
```

```text
Callouts (80x12, 0-based):
1. r0 c0-c6    Sidebar toggle -- labeled close target.
2. r0 c42-c48  Inspector toggle -- labeled close target.
3. r3 c0       Catalog selection -- app-owned selection presents detail.
4. r9 c0-c13   Sidebar toggle -- duplicate affordance.
5. r9 c42-c57  Inspector toggle -- duplicate affordance.
6. r2-r10 c42-c79  Inspector column -- no blank content role precedes it.
```

### Minimum

The declared floor is `24x8`; below it secondary chrome drops before the focused compact
child.

```wireframe 24x8
[Catalog] Playground
────────────────────────
NavigationSplitView

compact: Playground

[Open Inspector]
Playground
```

```text
Callouts (24x8, 0-based):
1. r0 c0-c8    Sidebar toggle -- labeled compact Catalog target.
2. r6 c0-c15   Inspector toggle -- labeled compact Inspector target.
3. r2-r7       Playground column -- compact content at the declared floor.
```

## Draft state model

| State                      | Owner       | Type                                                                       | Reset or clamp rule                                                                                                                                                                                               |
| -------------------------- | ----------- | -------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| column visibility          | Binding     | `NavigationSplitViewVisibility`                                            | app-owned; recomputes rendered columns on every update                                                                                                                                                            |
| preferred compact column   | Binding     | `NavigationSplitViewColumn`                                                | app-owned; unavailable role falls back by semantic order without mutating binding                                                                                                                                 |
| focus binding              | Binding     | `FocusID?`                                                                 | Slice 4 clears it when its rendered node disappears; after an opened role renders, the widget writes that role's non-`nil` target here; it guesses no neighbour                                                   |
| focus restoration targets  | Binding     | `[NavigationSplitViewColumn: FocusID?]`                                    | app-supplied and read-only to the widget; after an opened role renders, it reads that role's non-`nil` target and writes it to focus binding; it never mutates this map; a `nil` entry makes no restoration write |
| available columns          | derived     | `Set<NavigationSplitViewColumn>`                                           | recomputes from supplied closures; content is absent for two columns                                                                                                                                              |
| presentation mode          | derived     | `regular` or `compact`                                                     | recomputes from proposal; compact renders exactly one available role                                                                                                                                              |
| rendered columns           | derived     | `[NavigationSplitViewColumn]`                                              | recomputes from availability, visibility, compact preference, and mode                                                                                                                                            |
| focused navigation control | derived     | `NavigationSplitViewColumn?`                                               | recomputes from focus binding; becomes `nil` when control is removed                                                                                                                                              |
| selection styling          | Environment | `selection.bar`, `selection.fill`, `selection.inactive`, `selection.ascii` | child selection resolves styling each render; container stores none                                                                                                                                               |
| divider styling            | Environment | `divider.light`, `divider.ascii`                                           | `SplitView` resolves every regular render                                                                                                                                                                         |
| focus styling              | Environment | `focus.border`, `focus.content`                                            | controls resolve every render; focus appearance is not cached                                                                                                                                                     |

## Draft key table

Directional keys belong to the focused supplied child. The graph has no implicit Tab
policy; an app may install Slice 4 focus advance.

| Key   | Precondition                                                                                                                           | Effect                                                                                                                                                                                                                                                                                                            | Consumed |
| ----- | -------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- |
| Enter | focused navigation control is sidebar, rendered columns excludes sidebar, and focus restoration targets has a non-`nil` sidebar target | opens sidebar through the controlled column visibility binding in regular mode or preferred compact column binding in compact mode; after sidebar renders, reads its non-`nil` `FocusID` from the app-supplied focus restoration targets map and writes that value to focus binding; never mutates the target map | yes      |
| Space | focused navigation control is sidebar, rendered columns excludes sidebar, and focus restoration targets has a non-`nil` sidebar target | opens sidebar through the controlled column visibility binding in regular mode or preferred compact column binding in compact mode; after sidebar renders, reads its non-`nil` `FocusID` from the app-supplied focus restoration targets map and writes that value to focus binding; never mutates the target map | yes      |
| Enter | focused navigation control is sidebar, rendered columns excludes sidebar, and focus restoration targets has no sidebar target          | opens sidebar through the controlled column visibility binding in regular mode or preferred compact column binding in compact mode; after sidebar renders, makes no restoration write to focus binding and never mutates the target map                                                                           | yes      |
| Space | focused navigation control is sidebar, rendered columns excludes sidebar, and focus restoration targets has no sidebar target          | opens sidebar through the controlled column visibility binding in regular mode or preferred compact column binding in compact mode; after sidebar renders, makes no restoration write to focus binding and never mutates the target map                                                                           | yes      |
| Enter | focused navigation control is sidebar, presentation mode is regular, and rendered columns includes sidebar                             | mutates column visibility to hide sidebar; focused navigation control becomes `nil` if removed                                                                                                                                                                                                                    | yes      |
| Space | focused navigation control is sidebar, presentation mode is regular, and rendered columns includes sidebar                             | mutates column visibility to hide sidebar; focused navigation control becomes `nil` if removed                                                                                                                                                                                                                    | yes      |
| Enter | focused navigation control is detail, rendered columns excludes detail, and focus restoration targets has a non-`nil` detail target    | opens detail through the controlled column visibility binding in regular mode or preferred compact column binding in compact mode; after detail renders, reads its non-`nil` `FocusID` from the app-supplied focus restoration targets map and writes that value to focus binding; never mutates the target map   | yes      |
| Space | focused navigation control is detail, rendered columns excludes detail, and focus restoration targets has a non-`nil` detail target    | opens detail through the controlled column visibility binding in regular mode or preferred compact column binding in compact mode; after detail renders, reads its non-`nil` `FocusID` from the app-supplied focus restoration targets map and writes that value to focus binding; never mutates the target map   | yes      |
| Enter | focused navigation control is detail, rendered columns excludes detail, and focus restoration targets has no detail target             | opens detail through the controlled column visibility binding in regular mode or preferred compact column binding in compact mode; after detail renders, makes no restoration write to focus binding and never mutates the target map                                                                             | yes      |
| Space | focused navigation control is detail, rendered columns excludes detail, and focus restoration targets has no detail target             | opens detail through the controlled column visibility binding in regular mode or preferred compact column binding in compact mode; after detail renders, makes no restoration write to focus binding and never mutates the target map                                                                             | yes      |
| Enter | focused navigation control is detail, presentation mode is regular, and rendered columns includes detail                               | mutates column visibility to hide detail; focused navigation control becomes `nil` if removed                                                                                                                                                                                                                     | yes      |
| Space | focused navigation control is detail, presentation mode is regular, and rendered columns includes detail                               | mutates column visibility to hide detail; focused navigation control becomes `nil` if removed                                                                                                                                                                                                                     | yes      |
| Esc   | focused navigation control is detail, rendered columns includes detail                                                                 | requests non-detail presentation through bindings without changing business selection                                                                                                                                                                                                                             | yes      |
| Tab   | always                                                                                                                                 | leaves focus advancement to an app-installed Slice 4 handler                                                                                                                                                                                                                                                      | no       |
| Left  | focused                                                                                                                                | leaves navigation to the focused supplied child                                                                                                                                                                                                                                                                   | no       |
| Right | focused                                                                                                                                | leaves navigation to the focused supplied child                                                                                                                                                                                                                                                                   | no       |

## Draft mouse table

The only handlers are the anatomy's labeled controls. Slice 5 supplies click-to-focus;
this container installs no hover, drag, wheel, divider, or browser handler.

| Event | Region           | Precondition                                                                                                                                                      | Effect                                                                                                                                                                                                                             | Consumed |
| ----- | ---------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- |
| click | sidebar toggle   | presentation mode is regular, rendered columns excludes sidebar, and focus restoration targets has a non-`nil` sidebar target                                     | mutates column visibility to render sidebar; after sidebar renders, reads its non-`nil` `FocusID` from the app-supplied focus restoration targets map and writes that value to focus binding; never mutates the target map         | yes      |
| click | sidebar toggle   | presentation mode is regular, rendered columns excludes sidebar, and focus restoration targets has no sidebar target                                              | mutates column visibility to render sidebar; after sidebar renders, makes no restoration write to focus binding and never mutates the target map                                                                                   | yes      |
| click | sidebar toggle   | presentation mode is regular, rendered columns includes sidebar                                                                                                   | mutates column visibility to hide sidebar; focused navigation control becomes `nil` if removed                                                                                                                                     | yes      |
| click | sidebar toggle   | presentation mode is compact, rendered columns excludes sidebar, available columns includes sidebar, and focus restoration targets has a non-`nil` sidebar target | mutates preferred compact column to request sidebar; after sidebar renders, reads its non-`nil` `FocusID` from the app-supplied focus restoration targets map and writes that value to focus binding; never mutates the target map | yes      |
| click | sidebar toggle   | presentation mode is compact, rendered columns excludes sidebar, available columns includes sidebar, and focus restoration targets has no sidebar target          | mutates preferred compact column to request sidebar; after sidebar renders, makes no restoration write to focus binding and never mutates the target map                                                                           | yes      |
| click | inspector toggle | presentation mode is regular, rendered columns excludes detail, and focus restoration targets has a non-`nil` detail target                                       | mutates column visibility to render detail; after detail renders, reads its non-`nil` `FocusID` from the app-supplied focus restoration targets map and writes that value to focus binding; never mutates the target map           | yes      |
| click | inspector toggle | presentation mode is regular, rendered columns excludes detail, and focus restoration targets has no detail target                                                | mutates column visibility to render detail; after detail renders, makes no restoration write to focus binding and never mutates the target map                                                                                     | yes      |
| click | inspector toggle | presentation mode is regular, rendered columns includes detail                                                                                                    | mutates column visibility to hide detail; focused navigation control becomes `nil` if removed                                                                                                                                      | yes      |
| click | inspector toggle | presentation mode is compact, rendered columns excludes detail, available columns includes detail, and focus restoration targets has a non-`nil` detail target    | mutates preferred compact column to request detail; after detail renders, reads its non-`nil` `FocusID` from the app-supplied focus restoration targets map and writes that value to focus binding; never mutates the target map   | yes      |
| click | inspector toggle | presentation mode is compact, rendered columns excludes detail, available columns includes detail, and focus restoration targets has no detail target             | mutates preferred compact column to request detail; after detail renders, makes no restoration write to focus binding and never mutates the target map                                                                             | yes      |

## Sizing

The container is greedy when proposed. Regular allocation, clipping, divider placement,
and drag policy belong to `SplitView`; compact measures only its one rendered child.

| Proposal  | Result | Rule                                                                                                         |
| --------- | ------ | ------------------------------------------------------------------------------------------------------------ |
| nil x nil | 80x24  | anatomy sample ideal is child ideals plus two dividers                                                       |
| 80 x 24   | 80x24  | tight regular fit fills and composes all three roles through `SplitView`                                     |
| 24 x 8    | 24x8   | declared minimum fills with one compact role and labeled open controls                                       |
| 12 x 4    | 12x4   | under-minimum fills safely, clips text, and never creates hidden columns or negative rects                   |
| 200 x 50  | 200x50 | over the preferred 80x24 fixture maximum, there is no layout maximum; it fills and gives surplus to children |

## Environment

Canonical [tokens](../tokens.md) are `divider.light`, `divider.ascii`, `selection.bar`,
`selection.fill`, `selection.inactive`, `selection.ascii`, `focus.border`, and
`focus.content`. Planned semantic roles are complete `Style` values, not colors or new
token names: `primary`, `secondary`, `accent`, `disabled`, and `destructive`. Standard
style uses primary for active title, secondary for labels, accent for focused/open
controls, disabled for unavailable missing-role openers, and never treats ordinary close
navigation as destructive. Exact Style environment keys remain open.

## Primitive dependencies

- `SplitView` -- regular geometry, dividers, min-size negotiation, and any divider drag;
  pending design, blocks `ready`.
- [Divider](../primitives/divider.md) -- canonical divider vocabulary; `specified`.
- `Text` -- labels and safe clipping from
  [Slice 3](../../docs/Spec.md#slice-3-styling-text-wrapping-and-decoration); pending
  catalog entry.
- `Button` -- labeled focusable open/close controls; pending widget design.
- `List` -- optional controlled Showcase Catalog child, not generic container state.

## Slice availability and progressive sequence

1. [Slice 2](../../docs/Spec.md#slice-2-the-layout-protocol-and-stack-containers) supplies
   placement and clipping; `SplitView` proves regular geometry.
2. [Slice 4](../../docs/Spec.md#slice-4-focus-and-key-routing-the-responder-system)
   supplies explicit focus, routing, removal-clears-focus behavior, and the focus-binding
   write after an opened role renders.
3. [Slice 5](../../docs/Spec.md#slice-5-mouse-and-hit-testing) supplies click-to-focus and
   the two toggle targets; divider drag remains `SplitView`.
4. [Slice 6](../../docs/Spec.md#slice-6-flex-grid-and-composition) supplies composition
   and constraints for regular `SplitView`.
5. [Slice 7](../../docs/Spec.md#slice-7-catalog-integration--list-section-controlled-widgets-and-the-showcase)
   supplies controlled Catalog `List` selection for the Showcase.

Before these land, showcase columns may be static app-supplied content only. They must not
substitute a private navigator, animation shim, source browser, or layout solver.

## Requirements

- `regular three-column layout composes supplied roles through SplitView` (anatomy;
  sizing: 80 x 24)
- `detail-only visibility replaces desktop columns without a route or animation` (desktop
  replacement; state: column visibility)
- `compact presentation renders exactly the app-preferred supplied role` (mobile and
  collapsed states; state: preferred compact column)
- `catalog selection recomposes playground without container-owned business selection`
  (anatomy callout 5; mobile Catalog)
- `two-column construction omits content instead of rendering a blank pane`
  (missing-content state; state: available columns)
- `opening a role restores its non-nil target without mutating the target map` (key and
  mouse open rows; state: focus restoration targets)
- `opening a role with no target makes no focus write` (key and mouse open rows; state:
  focus restoration targets)
- `hiding focused detail clears focus rather than guessing a neighbour` (mouse inspector
  visible; state: focus binding)
- `compact navigation controls remain operable with Enter and Space` (key table: Enter and
  Space)
- `container does not consume Tab or directional child navigation` (key table: Tab, Left,
  Right)
- `minimum compact layout preserves labeled navigation affordances` (minimum; sizing: 24
  x 8)
- `under-minimum proposal clips safely without hidden column state` (sizing: 12 x 4)
- `ascii compact layout preserves role order and labeled controls` (degradation:
  ASCII-only)

## Degradation

- **No color:** reverse-video selection and bold focus preserve geometry.
- **16-color:** full semantic Styles resolve to indexed equivalents; behavior is
  unchanged.
- **ASCII-only:** `│`, `┼`, `─`, and `▌` become `|`, `+`, `-`, and `>` per canonical
  tokens; bracketed controls are already ASCII.
- **Below `24x8`:** clip through `Text`, omit secondary controls before the focused
  compact child, mutate no business binding, and never substitute animation or a layout
  failure.

## Open questions

- Does visibility name roles or visible sets for two and three columns?
- Is focus restoration a role-to-`FocusID?` binding, configuration plus focus binding, or
  callback?
- Are duplicate desktop header/in-body controls both needed after real target-size
  measurement?
- Which standard `SplitView` constraints fit sidebar/content/detail without a second
  solver?
- Is unavailable compact fallback sidebar/content/detail, or detail/content/sidebar, while
  retaining the binding?
- Must custom styles provide testable compact open/close slots or may they replace them?

## Inspiration

- 2026-07-06 -- [inbox](../inbox.md) identifies `SplitView` as the exemplar for divider
  drag, min-size negotiation, and collapse. This design preserves those as `SplitView`
  geometry and layers controlled semantic navigation roles for the Showcase.
