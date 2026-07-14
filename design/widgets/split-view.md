---
kind: widget
status: wireframed
---

# SplitView

`SplitView` lays out an ordered, adjacent sequence of application-owned panes on one axis,
with a one-cell interactive divider between each visible pair. It is deliberately not
navigation: a pane is neither a route nor a destination, collapsing it never selects or
replaces a route, and applications decide what every pane contains. The application owns
each pane's stable identity, integer requested size, and collapsed visibility through
bindings; the widget retains only an in-progress drag and a focus-return candidate in
`NodeState`.

## Prior art

- Ratatui:
  `/Users/rob/Developer/ratatui/ratatui/main/ratatui-core/src/layout/constraint.rs` and
  `/Users/rob/Developer/ratatui/ratatui/main/ratatui-core/src/layout/flex.rs` define
  named, integer layout constraints and deterministic allocation. Copy their explicit
  constraint vocabulary and bounded integer negotiation; reject a solver, ratios that
  silently change a user's requested pane size, and any widget-owned persistent state.
- Ratatui: `/Users/rob/Developer/ratatui/ratatui/main/ratatui-core/src/layout/layout.rs`
  is the reference for allocating adjacent rectangles from a direction and constraints.
  Copy adjacent-rectangle composition; reject rendering borders as the split itself.
- Apple:
  [NSSplitViewController](https://developer.apple.com/documentation/appkit/nssplitviewcontroller)
  manages an ordered array of adjacent children and their dividers, supports both
  side-by-side and top-to-bottom arrangements, and distinguishes collapse from loading.
  Copy adjacent-child and collapse vocabulary; reject controller ownership, lazy loading,
  animation, and navigation/sidebar policy.

## Anatomy

### Natural two-pane vertical divider

`axis: .horizontal`; two visible panes have requested widths 24 and 55. The 80-column
fixture has one divider cell at `c24`; the trailing pane owns the remaining 55 cells.

```wireframe 80x8
 Mailboxes              │ Subject: Sprint plan
 Inbox (3)              │ From: Ada
 Sent                   │
 Drafts                 │ The proposal keeps its own state.
                        │
                        │
                        │
                        │
```

```text
Callouts (80x8, 0-based):
1. r0-r7 c0-c23  Leading pane -- application content, clipped to its assigned rect
2. r0-r7 c24     Divider handle -- one-cell SplitView hit region rendering Divider `light`
3. r0-r7 c25-c79 Trailing pane -- application content, clipped to its assigned rect
```

The handle is not a `Divider` interaction added after the fact. It draws the vertical
[Divider](../primitives/divider.md) glyph in a one-cell rect, while SplitView alone
registers mouse and key handlers for that rect.

### Natural three-pane vertical divider

The visible sequence is stable by pane ID, not positional index: `files` is 16 cells,
`editor` is 46, and `inspector` is 16. The two handles consume `c16` and `c63`.

```wireframe 80x10
 Files          │ Letter.md                                    │ Info
 Inbox          │ To: Ada                                      │ 3 changes
 Sent           │                                              │
 Drafts         │ Body…                                        │
                │                                              │
                │                                              │
                │                                              │
                │                                              │
                │                                              │
                │                                              │
```

```text
Callouts (80x10, 0-based):
1. r0-r9 c0-c15   Leading pane -- application content for stable ID `files`
2. r0-r9 c16      Divider handle -- resizes `files` and `editor` only
3. r0-r9 c17-c62  Middle pane -- application content for stable ID `editor`
4. r0-r9 c63      Divider handle -- resizes `editor` and `inspector` only
5. r0-r9 c64-c79  Trailing pane -- application content for stable ID `inspector`
```

### Drag result

Dragging the first handle eight cells toward the middle changes the bound requested sizes
from `[files: 16, editor: 46, inspector: 16]` to `[files: 24, editor: 38, inspector: 16]`.
It preserves the adjacent pair's 62-cell total, leaves the third pane untouched, and never
manufactures a new pane identity.

```wireframe 80x8
 Files                  │ Letter.md                            │ Info
 Inbox                  │ To: Ada                              │ 3 changes
 Sent                   │                                      │
 Drafts                 │ Body…                                │
                        │                                      │
                        │                                      │
                        │                                      │
                        │                                      │
```

```text
Callouts (80x8, 0-based):
1. r0-r7 c0-c23   Leading pane -- `files` after its bound requested size became 24
2. r0-r7 c24      Divider handle -- drag target for the `files` / `editor` pair
3. r0-r7 c25-c62  Middle pane -- `editor` after its bound requested size became 38
4. r0-r7 c63      Divider handle -- unchanged `editor` / `inspector` boundary
5. r0-r7 c64-c79  Trailing pane -- unchanged `inspector` rect
```

### Collapsed pane

The application has set `files.isCollapsed` to `true`. Its stable ID and requested size
remain in the binding, but it has a zero main-axis rect and no hit region. The visible
sequence becomes `editor`, `inspector`; only their one divider is rendered. There is no
implicit route selection, content substitution, or automatic uncollapse at this width.

```wireframe 80x8
 Letter.md                                                     │ Info
 To: Ada                                                       │ 3 changes
                                                               │
 Body…                                                         │
                                                               │
                                                               │
                                                               │
                                                               │
```

```text
Callouts (80x8, 0-based):
1. r0-r7 c0-c62   Leading visible pane -- stable ID `editor`; it occupies the former visible space
2. r0-r7 c63      Divider handle -- resizes the adjacent visible `editor` / `inspector` pair
3. r0-r7 c64-c79  Trailing visible pane -- stable ID `inspector`
```

### Over-constrained parent allocation

This is a 24x6 parent allocation of three panes whose negotiated floors total 30 cells
including two handles. The SplitView never gives a pane a negative rect: it shrinks
negotiable space using the Slice 6 Flex order, then clips trailing placement at the
parent's clip rect. `inspector` begins at `c22` and only its first two cells are visible.

```wireframe 24x6
 Files  │ Edit       │In
 Inbox  │ To: Ada    │
 Sent   │            │
 Drafts │ Body…      │
        │            │
        │            │
```

```text
Callouts (24x6, 0-based):
1. r0-r5 c0-c7   Leading pane -- negotiated to its 8-cell floor
2. r0-r5 c8      Divider handle -- still one cell at the first visible boundary
3. r0-r5 c9-c20  Middle pane -- negotiated to its 12-cell floor
4. r0-r5 c21     Divider handle -- still one cell at the second visible boundary
5. r0-r5 c22-c23 Trailing pane -- clipped leading portion of the 8-cell `inspector` rect
```

### Mobile density

At the canonical `mobile` viewport, all three application-selected panes remain visible:
8 + 1 + 24 + 1 + 6 = 40 cells. Labels use each pane's own truncation policy; SplitView
does not collapse or replace a pane merely because the terminal is narrow.

```wireframe 40x16
Files   │Letter.md               │Info
Inbox   │To: Ada                 │3 chg
Sent    │                        │
Drafts  │Body…                   │
        │                        │
        │                        │
        │                        │
        │                        │
        │                        │
        │                        │
        │                        │
        │                        │
        │                        │
        │                        │
        │                        │

```

```text
Callouts (40x16, 0-based):
1. r0-r15 c0-c7   Leading pane -- 8-cell `files` allocation
2. r0-r15 c8      Divider handle -- one-cell boundary
3. r0-r15 c9-c32  Middle pane -- 24-cell `editor` allocation
4. r0-r15 c33     Divider handle -- one-cell boundary
5. r0-r15 c34-c39 Trailing pane -- 6-cell `inspector` allocation
```

### Declared minimum

For this two-pane fixture, the declared floor is **17x4**: two children each report an
8-cell main-axis floor, and their one divider reports one. This is a measurement floor,
not a mandate that the parent provide enough cells; an undersized parent clips the placed
result as shown above.

```wireframe 17x4
 Files  │Body
 Inbox  │
 Sent   │
        │
```

```text
Callouts (17x4, 0-based):
1. r0-r3 c0-c7   Leading pane -- first 8-cell child floor
2. r0-r3 c8      Divider handle -- one-cell boundary at the floor
3. r0-r3 c9-c16  Trailing pane -- second 8-cell child floor
```

### Horizontal divider

`axis: .vertical` stacks panes top-to-bottom. The interactive Divider row is one cell high
across the complete assigned width; horizontal pointer motion resizes neither pane.

```wireframe 24x8
 Project
 files/
 src/
────────────────────────
 Preview
 Build passed
 Ready

```

```text
Callouts (24x8, 0-based):
1. r0-r2  Leading pane -- application content above the boundary
2. r3     Divider handle -- one-cell horizontal SplitView hit region rendering Divider `light`
3. r4-r7  Trailing pane -- application content below the boundary
```

## States

The fixtures cover natural two-pane and three-pane arrangements, a completed drag,
application-driven collapse, a 24x6 over-constrained allocation, the 40x16 `mobile`
viewport, the declared 17x4 `min` viewport, and both axes. Idle is any stable fixture
without an active pointer drag; loading, empty, and error remain pane-content states and
are rendered by the application-provided child, not by SplitView. A disabled handle is
visually secondary and has no resize interaction when its adjacent visible panes cannot
change their controlled sizes.

## State model

| State                     | Owner     | Type                                                                                                     | Reset or clamp rule                                                                                                                                                                                                                         |
| ------------------------- | --------- | -------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| pane configuration        | Binding   | ordered `[SplitViewPane]` containing stable `ID`, integer `requestedSize`, and `isCollapsed`             | App is authoritative. On every update, retain IDs as supplied; a collapsed pane retains its requested size and receives a zero main-axis rect.                                                                                              |
| axis                      | Binding   | `Axis`                                                                                                   | App is authoritative. On change, transpose main/cross-axis negotiation, cancel `pointer drag`, and clear a `focused divider handle` that is no longer live.                                                                                 |
| visible pane sequence     | derived   | ordered `[Pane.ID]`                                                                                      | Recompute from `pane configuration` on every update; omit collapsed panes without changing their identity or order in the binding.                                                                                                          |
| negotiated pane rects     | derived   | `[Pane.ID: Rect]`                                                                                        | Recompute from `pane configuration`, `axis`, child measurements, and parent bounds on every layout; clamp all extents to nonnegative integers and parent clipping.                                                                          |
| focused divider handle    | derived   | `FocusID?`                                                                                               | Recompute from the FocusManager after layout; clear if its adjacent visible pair disappears or becomes nonresizable.                                                                                                                        |
| pointer drag              | NodeState | optional `(leadingID: Pane.ID, trailingID: Pane.ID, origin: Int, leadingStart: Int, trailingStart: Int)` | Set only during a drag on a live `divider handle`; retain through ordinary reconciliation while the same stable adjacent pane pair remains live; clear only on release, axis change, pair disappearance, focus loss, or node identity loss. |
| focus return candidate    | NodeState | `[Pane.ID: FocusID]`                                                                                     | When a focused descendant is hidden by `pane configuration`, remember it only if it belongs to that pane; discard it when that focus ID is no longer live.                                                                                  |
| keyboard resizing enabled | Binding   | `Bool`                                                                                                   | App is authoritative. When false, omit divider focusability and clear `focused divider handle` on reconciliation.                                                                                                                           |

A pane's ID is stable across a size or visibility mutation. Reordering the binding is an
explicit application operation; SplitView must not interpret a changed index as the old
pane. `requestedSize` is a nonnegative whole-cell value. A visible pane's actual
allocation is derived, so an over-constrained parent can shrink or clip it without
mutating that binding.

## Interaction

### Focus, collapse, and restoration

A live divider receives an explicit focus ID derived from its ordered pair of stable pane
IDs, for example `split.files.editor`; it is focusable only while
`keyboard resizing enabled` is true and the pair has an adjustable cell. Clicking a handle
follows Slice 5's click-to-focus rule before this widget's mouse action.

When the application collapses a pane containing the graph's focused descendant, SplitView
records that descendant as the pane's `focus return candidate`, then requests the nearest
focusable descendant in the next visible pane; if none exists, it requests the previous
visible pane; if neither exists, it clears focus. This is restoration from an invalidated
target, not navigation. On a later application expansion, SplitView restores the candidate
only when the FocusManager focus is still `nil` and the candidate is live; it never steals
a user's newer focus. If the candidate was removed while hidden, it is discarded and focus
remains unchanged.

### Key table

| Key   | Precondition                                             | Effect                                                                                                                                                                                               | Consumed |
| ----- | -------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- |
| Left  | `focused divider handle` is set and `axis` is horizontal | Decrements the leading adjacent pane's `requestedSize` by one and increments the trailing adjacent pane's `requestedSize` by one through `pane configuration`; clamps at the negotiated pair bounds. | yes      |
| Right | `focused divider handle` is set and `axis` is horizontal | Increments the leading adjacent pane's `requestedSize` by one and decrements the trailing adjacent pane's `requestedSize` by one through `pane configuration`; clamps at the negotiated pair bounds. | yes      |
| Up    | `focused divider handle` is set and `axis` is vertical   | Decrements the leading adjacent pane's `requestedSize` by one and increments the trailing adjacent pane's `requestedSize` by one through `pane configuration`; clamps at the negotiated pair bounds. | yes      |
| Down  | `focused divider handle` is set and `axis` is vertical   | Increments the leading adjacent pane's `requestedSize` by one and decrements the trailing adjacent pane's `requestedSize` by one through `pane configuration`; clamps at the negotiated pair bounds. | yes      |
| Tab   | `focused divider handle` is set                          | Leaves focus routing to the application's installed handler; does not mutate `pane configuration`.                                                                                                   | no       |
| Esc   | `focused divider handle` is set                          | Leaves the event available to ancestors and the application; does not mutate `pane configuration`.                                                                                                   | no       |

### Mouse table

| Event | Region         | Precondition                                                                               | Effect                                                                                                                                                                                                                                       | Consumed |
| ----- | -------------- | ------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- |
| click | Divider handle | `pointer drag` is empty and the handle's pair exists in `visible pane sequence`            | Focuses the corresponding `focused divider handle`; leaves `pane configuration` unchanged.                                                                                                                                                   | yes      |
| drag  | Divider handle | the handle's pair exists in `visible pane sequence` and both panes have an adjustable cell | On the first event, records `pointer drag`; on each event, converts pointer displacement on `axis` to an integer delta, then updates only the pair's `requestedSize` values through `pane configuration`, clamped to negotiated pair bounds. | yes      |
| drag  | Divider handle | `pointer drag` is set and its pair is absent from `visible pane sequence`                  | Clears `pointer drag` and leaves `pane configuration` unchanged.                                                                                                                                                                             | yes      |

Dragging accepts displacement only along the main axis: vertical movement on a vertical
handle, and horizontal movement on a horizontal handle. No hover, wheel, double-click, or
click-to-collapse behavior is specified. That restraint keeps a one-cell boundary
predictable and leaves visibility entirely controlled by the app.

## Sizing

`SplitView` measures and places only visible panes plus `visiblePaneCount - 1` handles.
Its main-axis intent is the sum of negotiated pane ideals plus handles; its cross-axis
intent is the largest visible child ideal. For a finite proposal, each visible child is
measured under the Slice 2 protocol and allocated with the Slice 6 Flex resolution order:
minimum floors, requested ideal, maximum ceiling, then weighted growth or shrink. Integer
remainders go to the earliest eligible pane. With a negative remainder, flexible space
shrinks first, then panes above their floors; after floors are exhausted, trailing rects
clip at the parent rather than becoming negative. A collapsed pane contributes neither
size nor a handle.

The table is intentionally fixture-specific so every result is exact. The natural
three-pane fixture has ideal 80x10 and maximum 80x10; the two-pane `min` fixture has a
17x4 floor. An ancestor may place the reported size into a smaller clip rect, which is how
the 24x6 over-constrained fixture is produced.

| Proposal                                        | Result | Rule                                                                                                                                                               |
| ----------------------------------------------- | ------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| nil x nil                                       | 80x10  | Natural three-pane measurement sums 16 + 1 + 46 + 1 + 16 on the main axis and takes the 10-cell cross-axis ideal.                                                  |
| 80x10                                           | 80x10  | Tight proposal exactly matches the natural three-pane negotiated ideal.                                                                                            |
| 12x3                                            | 17x4   | Under the declared two-pane 17x4 floor, measurement reports the floor; a parent that assigns only 12x3 clips placement rather than requesting negative pane sizes. |
| 120x20                                          | 80x10  | Over the fixture's maximum, measurement reports its 80x10 maximum; SplitView does not invent unconstrained blank pane growth.                                      |
| 40x16                                           | 40x16  | Mobile's controlled 8 + 1 + 24 + 1 + 6 allocation exactly fills the proposed main axis and takes the proposed cross axis.                                          |
| 24x6 parent allocation after a 30x6 measurement | 30x6   | Three pane floors and handles measure 8 + 1 + 12 + 1 + 8; Slice 2 clipping produces the 24x6 over-constrained rendering.                                           |

## Environment

- `splitView.style` -- a `SplitViewStyle` selected from the environment. The standard
  style is the default; custom styles are accepted public direction. A style supplies full
  `Style` values named `primary`, `secondary`, `accent`, `disabled`, and `destructive`.
  The standard style uses `primary` for pane content inheritance, `secondary` for an
  unfocused handle, `accent` for a focused handle, and `disabled` for a nonresizable
  handle. `destructive` is available to custom app policy but is not applied by standard
  resizing behavior. These are semantic full styles, not hard-coded colors or partial
  foreground overrides.
- `divider.style` -- [Divider](../primitives/divider.md) glyph selection. Standard
  SplitView draws `light`; it receives the same geometry for every style.
- `focus.border` and the focus degradation rules in [tokens.md](../tokens.md#focus) --
  focus presentation for the one-cell handle without inventing a component-specific focus
  color.
- `truncation.mark` and the degradation ladder in [tokens.md](../tokens.md) -- consumed by
  pane content and the split's ASCII fallback; SplitView never cuts a grapheme itself.

The default `standard` style and public custom `SplitViewStyle` protocol are accepted
direction. Concrete protocol requirements, generic versus type-erased storage, and the
initializer signature remain deliberately open until Slice 3 establishes the final `Style`
environment surface.

## Primitive dependencies

- [Divider](../primitives/divider.md) (`specified`) -- supplies only the one-cell rule
  glyph and sizing; SplitView owns handle focus, hit testing, and drag.
- `Text` (Slice 1) -- pane labels and content in the fixtures; actual child content is
  application supplied.
- `FocusManager` and `.focusable` (Slice 4) -- divider keyboard focus and safe focus
  reassignment during collapse.
- `.onMouse` and hit testing (Slice 5) -- pointer drag and click-to-focus on a handle.
- `Flex` (Slice 6) -- the canonical integer min/ideal/max negotiation; SplitView must
  reuse its resolution order rather than creating a competing splitter allocator.

No `Form` or `Outline` dependency is introduced before 1.0. Source browsing, directory
mapping, and route-oriented sidebars are post-1.0 application composition concerns, not
responsibilities of this low-level adjacency widget.

## Progressive availability

1. **Slice 2** supplies integer proposal, placement, absolute frames, clipping, stable
   view IDs, and the stack measurement baseline. SplitView can measure passive adjacent
   panes but exposes neither focusable handles nor input behavior at this point.
2. **Slice 4** adds focusable divider handles, arrow-key resizing, and the collapse focus
   restoration rule. It depends on the graph's explicit FocusID and routing order.
3. **Slice 5**, after Phase 3 Slice 3 mouse support, adds click-to-focus and raw drag
   dispatch. The visual one-cell handle remains available without mouse capability.
4. **Slice 6** replaces any interim size arithmetic with the shared Flex min/ideal/max
   resolver and enables the over-constrained behavior documented here.
5. **Slice 7 and later** may place controlled application widgets inside panes. SplitView
   remains separate from navigation semantics throughout; it is available progressively as
   layout/input capabilities arrive rather than waiting for a navigation shell.

## Requirements

- `split view preserves stable pane identity across requested size changes` (state model:
  pane configuration; drag wireframe)
- `split view renders one one-cell handle between each adjacent visible pane` (natural
  two-pane and three-pane anatomy)
- `split view omits collapsed panes and their handles without replacing application content`
  (collapsed wireframe; state model: visible pane sequence)
- `split view restores a hidden focused descendant only when focus remains clear` (focus,
  collapse, and restoration)
- `split view moves focus to the nearest visible pane when collapsing the focused pane`
  (focus, collapse, and restoration)
- `horizontal divider handle arrow keys resize only its adjacent controlled pane pair`
  (key table: Left and Right)
- `vertical divider handle arrow keys resize only its adjacent controlled pane pair` (key
  table: Up and Down)
- `split view leaves tab and escape available to application routing` (key table: Tab and
  Esc)
- `dragging a divider updates adjacent bound sizes with integer clamping` (mouse table:
  drag; drag result wireframe)
- `active split drag survives reconciliation for a stable pane pair` (state model: pointer
  drag)
- `split view cancels a stale drag when its pane pair disappears` (mouse table: second
  drag row)
- `split view uses flex floors before clipping trailing panes under over-constraint`
  (sizing: 24x6 parent allocation; over-constrained wireframe)
- `split view reports its declared minimum before a smaller parent clips placement`
  (sizing: 12x3; declared minimum wireframe)
- `split view reports its fixture maximum without allocating invented blank growth`
  (sizing: 120x20)
- `split view retains all application-selected panes at the mobile viewport` (mobile
  wireframe)
- `split view transposes divider hit geometry for vertical axis` (horizontal divider
  anatomy)
- `standard split view style applies semantic full styles without hard-coded colors`
  (environment)

## Degradation

- **`NO_COLOR`:** preserve Divider glyphs, one-cell geometry, hit regions, and keyboard
  behavior. `SplitViewStyle` expresses focus with the token ladder's bold treatment
  instead of a color distinction.
- **16-color:** retain the same semantic `primary`, `secondary`, `accent`, `disabled`, and
  `destructive` full styles using the environment's indexed approximation; allocation and
  clipping do not change.
- **ASCII-only:** replace `│` and `─` with the Divider `ascii` glyphs `|` and `-`; replace
  pane-content truncation `…` with `~` according to
  [tokens.md](../tokens.md#degradation-ladder). Handles remain exactly one cell and fully
  interactive.
- **Below the declared minimum:** report the floor during measurement, accept the parent's
  smaller clip rect during placement, and paint only visible leading cells. Never collapse
  a pane, mutate requested sizes, or substitute navigation content automatically.

## Open questions

- **Public pane construction:** Should the controlled input be a single binding to an
  ordered `SplitViewPane` collection, or separate bindings for sizes and collapse state
  keyed by ID? Resolve after Slice 7 establishes the collection-binding ergonomics; both
  choices must preserve the state model here.
- **Requested-size lowering:** The exact public adapter from `requestedSize` plus child
  measurements to Slice 6 `FlexConstraint` values is open. Resolve when Flex's public
  measurement API is implemented; it must produce the documented floors, ideals, maxima,
  rounding, and clipping behavior.
- **Custom style protocol shape:** Should `SplitViewStyle` return a decorated handle view
  or only full semantic `Style` values? Resolve alongside Slice 3's standard/custom style
  protocol design; a custom style must not gain access to or ownership of pane business
  state.
- **Programmatic expansion focus policy:** This draft restores a saved descendant only
  when focus is nil. Confirm with application examples whether an explicit app expansion
  request should be able to opt into restoring focus even when another pane is focused.
- **Pane removal during drag:** This draft cancels rather than retargets the drag. Confirm
  after reconciliation exposes its exact mutation ordering; retargeting by index is
  prohibited because it breaks stable identity.

## Inspiration

- 2026-07-06 -- `SplitView` is the right second widget exemplar: it uniquely exercises
  divider drag, min-size negotiation, and collapse (Slice 5 hit testing), none of which
  Table touches. (triaged from [inbox.md](../inbox.md))
