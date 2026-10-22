---
kind: widget
status: ready
---

# SplitView

`SplitView` lays out an ordered, adjacent sequence of application-owned panes on one axis,
with a one-cell interactive divider between each visible pair. It is deliberately not
navigation: a pane is neither a route nor a destination, collapsing it never selects or
replaces a route, and applications decide what every pane contains. The application owns
each pane's stable identity, minimum/requested-ideal/maximum sizing, and collapsed
visibility through one ordered binding; the child view supplies the existing
`.layoutPriority(_:)` value. The widget retains only an in-progress drag and a
focus-return candidate in `NodeState`.

## Prior art

- Ratatui:
  `https://github.com/ratatui/ratatui/blob/main/ratatui-core/src/layout/constraint.rs` and
  `https://github.com/ratatui/ratatui/blob/main/ratatui-core/src/layout/flex.rs` define
  named, integer layout constraints and deterministic allocation. Copy their explicit
  constraint vocabulary and bounded integer negotiation; reject a solver, ratios that
  silently change a user's requested pane size, and any widget-owned persistent state.
- Ratatui:
  `https://github.com/ratatui/ratatui/blob/main/ratatui-core/src/layout/layout.rs` is the
  reference for allocating adjacent rectangles from a direction and constraints. Copy
  adjacent-rectangle composition; reject rendering borders as the split itself.
- Apple:
  [NSSplitViewController](https://developer.apple.com/documentation/appkit/nssplitviewcontroller)
  manages an ordered array of adjacent children and their dividers, supports both
  side-by-side and top-to-bottom arrangements, and distinguishes collapse from loading.
  Copy adjacent-child and collapse vocabulary; reject controller ownership, lazy loading,
  animation, and navigation/sidebar policy.
- omp2's settings screen, per the [translation key](../translation-key.md): its body is a
  `row` holding a section sidebar and the settings list, split by a vertical `hr`
  ([settings.rs](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/chat/src/overlays/settings.rs#L1783-L1787)).
  The sidebar's `w` is its longest group label, capped at 22 cells, plus four, and the
  list takes the rest with a 20-cell floor
  ([L1730-L1738](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/chat/src/overlays/settings.rs#L1730-L1738)).
  Copy the content-measured leading pane and the trailing pane that absorbs the slack: `w`
  and the floor become the panes' `SplitViewPaneSizing`, which SplitView lowers to Flex
  (keys B2, G5), and the `hr` is the divider's `light` line (key K7). omp2's rule is
  static; focus, resizing, and collapse are Tessera's.

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

Dragging the first handle eight cells toward the middle changes the bound requested ideals
from `[files: 16, editor: 46, inspector: 16]` to `[files: 24, editor: 38, inspector: 16]`.
It preserves the adjacent pair's 62-cell total, leaves each pane's minimum and maximum
untouched, leaves the third pane untouched, and never manufactures a new pane identity.

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
1. r0-r7 c0-c23   Leading pane -- `files` after its bound requested ideal became 24
2. r0-r7 c24      Divider handle -- drag target for the `files` / `editor` pair
3. r0-r7 c25-c62  Middle pane -- `editor` after its bound requested ideal became 38
4. r0-r7 c63      Divider handle -- unchanged `editor` / `inspector` boundary
5. r0-r7 c64-c79  Trailing pane -- unchanged `inspector` rect
```

### Collapsed pane

The application has set `files.isCollapsed` to `true`. Its stable ID and sizing remain in
the binding, but it has a zero main-axis rect and no hit region. The visible sequence
becomes `editor`, `inspector`; only their one divider is rendered. There is no implicit
route selection, content substitution, or automatic uncollapse at this width.

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
including two handles. The SplitView never gives a pane a negative rect: it uses the
shared [Flex](../primitives/flex.md) compression order, then clips trailing placement at
the parent's clip rect. `inspector` begins at `c22` and only its first two cells are
visible.

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
8 + 1 + 24 + 1 + 6 = 40 cells. Text in each pane wraps or marks its own cut; SplitView
does not collapse or replace a pane merely because the terminal is narrow.

Wireframed at its natural height: 40 columns by 10 rows (cross-axis ideal 10; see the
sizing table), not padded to a 40x16 frame (owner decision, 2026-10-10).

```wireframe 40x10
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
```

```text
Callouts (40x10, 0-based):
1. r0-r9 c0-c7   Leading pane -- 8-cell `files` allocation
2. r0-r9 c8      Divider handle -- one-cell boundary
3. r0-r9 c9-c32  Middle pane -- 24-cell `editor` allocation
4. r0-r9 c33     Divider handle -- one-cell boundary
5. r0-r9 c34-c39 Trailing pane -- 6-cell `inspector` allocation
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

### Nested layout with junctions

`files` is the leading pane of the outer SplitView. The middle column is a nested vertical
SplitView holding `editor` over `terminal`; `inspector` is the trailing pane. The inner
handle meets both outer handles, so each boundary joins instead of crossing or stopping:
`├` where it meets the leading handle and `┤` where it meets the trailing one. SplitView
sets `divider.blending` on its divider cells, so each junction is the arm-union of the
crossing light rules.

```wireframe 80x14
 Files       │ main.swift                                   │ Inspector
 ▾ Sources   │ import Tessera                               │ Size   1.2 KB
   App.swift │                                              │ Lines  48
   main.swift│ @main                                        │ Saved  2 min ago
 ▸ Tests     │ struct Demo: App {                           │
             │     var body: some Scene { … }               │
             │ }                                            │
             │                                              │
             ├──────────────────────────────────────────────┤
             │ Terminal                                     │
             │ $ swift build                                │
             │ Compiling Demo main.swift                    │
             │ Build complete!                              │
             │                                              │
```

```text
Callouts (80x14, 0-based):
1. r0-r13 c0-c12   Leading pane -- stable ID `files`, clipped to its assigned rect
2. r0-r13 c13      Divider handle -- outer handle, Divider `light`; `├` at r8 joins the inner handle
3. r0-r7 c14-c59   Upper pane -- stable ID `editor`, leading pane of the inner SplitView
4. r8 c14-c59      Divider handle -- inner handle between `editor` and `terminal`, Divider `light`
5. r9-r13 c14-c59  Lower pane -- stable ID `terminal`, trailing pane of the inner SplitView
6. r0-r13 c60      Divider handle -- outer handle; `┤` at r8 joins the inner handle
7. r0-r13 c61-c79  Trailing pane -- stable ID `inspector`
```

```text
── chars ──
 Files       │ main.swift                                   │ Inspector
 ▾ Sources   │ import Tessera                               │ Size   1.2 KB
   App.swift │                                              │ Lines  48
   main.swift│ @main                                        │ Saved  2 min ago
 ▸ Tests     │ struct Demo: App {                           │
             │     var body: some Scene { … }               │
             │ }                                            │
             │                                              │
             ├──────────────────────────────────────────────┤
             │ Terminal                                     │
             │ $ swift build                                │
             │ Compiling Demo main.swift                    │
             │ Build complete!                              │
             │                                              │
── style ──
.HHHHH.......D.HHHHHHHHHH...................................D.HHHHHHHHH
.PPPPPPPPP...D.PPPPPPPPPPPPPP...............................D.PPPPPPPPPPPPP
.PPPPPPPPPPP.D..............................................D.PPPPPPPPP
.SSSSSSSSSSSSD.AAAAA........................................D.PPPPPPPPPPPPPPPP
.PPPPPPP.....D.PPPPPPPPPPPPPPPPPP...........................D
.............D.PPPPPPPPPPPPPPPPPPPPPPPPPPPPPP...............D
.............D.P............................................D
.............D..............................................D
.............DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD
.............D.HHHHHHHH.....................................D
.............D.PPPPPPPPPPPPP................................D
.............D.MMMMMMMMMMMMMMMMMMMMMMMMM....................D
.............D.KKKKKKKKKKKKKKK..............................D
.............D..............................................D
── legend ──
.  default
D  fg=border
H  fg=secondary bold
P  fg=primary
M  fg=secondary
A  fg=accent
S  fg=primary bg=selection.fill
K  fg=success
```

### Focused horizontal divider

The handle between `editor` and `terminal` has keyboard focus. It draws the `heavy` line
`━` in the focus role, foreground-only bold, with no background. This replaces the accent
colour the catalog used before (owner decision, omp2 review, 2026-10). Its junctions on
the focused side use the heavy set's junction glyphs, `┣` and `┫` (owner decision,
2026-10-10), so the joint is heavy rather than mixed-weight (focus border rule 4;
[Focus](../tokens.md#focus)).

```wireframe 80x14
 Files       │ main.swift                                   │ Inspector
 ▾ Sources   │ import Tessera                               │ Size   1.2 KB
   App.swift │                                              │ Lines  48
   main.swift│ @main                                        │ Saved  2 min ago
 ▸ Tests     │ struct Demo: App {                           │
             │     var body: some Scene { … }               │
             │ }                                            │
             │                                              │
             ┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
             │ Terminal                                     │
             │ $ swift build                                │
             │ Compiling Demo main.swift                    │
             │ Build complete!                              │
             │                                              │
```

```text
Callouts (80x14, 0-based):
1. r0-r13 c0-c12   Leading pane -- stable ID `files`, clipped to its assigned rect
2. r0-r13 c13      Divider handle -- outer handle, Divider `light`; `┣` at r8 is the heavy
                   junction on the focused side
3. r0-r7 c14-c59   Upper pane -- stable ID `editor`, leading pane of the inner SplitView
4. r8 c14-c59      Divider handle -- focused inner handle, Divider `heavy` line in the
                   focus role
5. r9-r13 c14-c59  Lower pane -- stable ID `terminal`, trailing pane of the inner SplitView
6. r0-r13 c60      Divider handle -- outer handle, Divider `light`; `┫` at r8 is the heavy
                   junction on the focused side
7. r0-r13 c61-c79  Trailing pane -- stable ID `inspector`
```

```text
── chars ──
 Files       │ main.swift                                   │ Inspector
 ▾ Sources   │ import Tessera                               │ Size   1.2 KB
   App.swift │                                              │ Lines  48
   main.swift│ @main                                        │ Saved  2 min ago
 ▸ Tests     │ struct Demo: App {                           │
             │     var body: some Scene { … }               │
             │ }                                            │
             │                                              │
             ┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
             │ Terminal                                     │
             │ $ swift build                                │
             │ Compiling Demo main.swift                    │
             │ Build complete!                              │
             │                                              │
── style ──
.HHHHH.......D.HHHHHHHHHH...................................D.HHHHHHHHH
.PPPPPPPPP...D.PPPPPPPPPPPPPP...............................D.PPPPPPPPPPPPP
.PPPPPPPPPPP.D..............................................D.PPPPPPPPP
.SSSSSSSSSSSSD.AAAAA........................................D.PPPPPPPPPPPPPPPP
.PPPPPPP.....D.PPPPPPPPPPPPPPPPPP...........................D
.............D.PPPPPPPPPPPPPPPPPPPPPPPPPPPPPP...............D
.............D.P............................................D
.............D..............................................D
.............FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
.............D.HHHHHHHH.....................................D
.............D.PPPPPPPPPPPPP................................D
.............D.MMMMMMMMMMMMMMMMMMMMMMMMM....................D
.............D.KKKKKKKKKKKKKKK..............................D
.............D..............................................D
── legend ──
.  default
D  fg=border
F  fg=focus bold
H  fg=secondary bold
P  fg=primary
M  fg=secondary
A  fg=accent
S  fg=primary bg=selection.fill
K  fg=success
```

### Focused vertical divider

The handle between `files` and the nested column has focus. It draws the `heavy` line `┃`
in the focus role, foreground-only bold, with no background. This replaces the accent
colour the catalog used before (owner decision, omp2 review, 2026-10). The inner `light`
handle meets it at `┣`, the heavy-set junction (owner decision, 2026-10-10).

```wireframe 80x14
 Files       ┃ main.swift                                   │ Inspector
 ▾ Sources   ┃ import Tessera                               │ Size   1.2 KB
   App.swift ┃                                              │ Lines  48
   main.swift┃ @main                                        │ Saved  2 min ago
 ▸ Tests     ┃ struct Demo: App {                           │
             ┃     var body: some Scene { … }               │
             ┃ }                                            │
             ┃                                              │
             ┣──────────────────────────────────────────────┤
             ┃ Terminal                                     │
             ┃ $ swift build                                │
             ┃ Compiling Demo main.swift                    │
             ┃ Build complete!                              │
             ┃                                              │
```

```text
Callouts (80x14, 0-based):
1. r0-r13 c0-c12   Leading pane -- stable ID `files`, clipped to its assigned rect
2. r0-r13 c13      Divider handle -- outer handle, focused: Divider `heavy` line; `┣` at r8
                   is the heavy-set junction
3. r0-r7 c14-c59   Upper pane -- stable ID `editor`, leading pane of the inner SplitView
4. r8 c14-c59      Divider handle -- inner handle, Divider `light`; `┤` at r8 c60 joins the
                   outer handle
5. r9-r13 c14-c59  Lower pane -- stable ID `terminal`, trailing pane of the inner SplitView
6. r0-r13 c60      Divider handle -- outer handle, Divider `light`
7. r0-r13 c61-c79  Trailing pane -- stable ID `inspector`
```

```text
── chars ──
 Files       ┃ main.swift                                   │ Inspector
 ▾ Sources   ┃ import Tessera                               │ Size   1.2 KB
   App.swift ┃                                              │ Lines  48
   main.swift┃ @main                                        │ Saved  2 min ago
 ▸ Tests     ┃ struct Demo: App {                           │
             ┃     var body: some Scene { … }               │
             ┃ }                                            │
             ┃                                              │
             ┣──────────────────────────────────────────────┤
             ┃ Terminal                                     │
             ┃ $ swift build                                │
             ┃ Compiling Demo main.swift                    │
             ┃ Build complete!                              │
             ┃                                              │
── style ──
.HHHHH.......F.HHHHHHHHHH...................................D.HHHHHHHHH
.PPPPPPPPP...F.PPPPPPPPPPPPPP...............................D.PPPPPPPPPPPPP
.PPPPPPPPPPP.F..............................................D.PPPPPPPPP
.SSSSSSSSSSSSF.AAAAA........................................D.PPPPPPPPPPPPPPPP
.PPPPPPP.....F.PPPPPPPPPPPPPPPPPP...........................D
.............F.PPPPPPPPPPPPPPPPPPPPPPPPPPPPPP...............D
.............F.P............................................D
.............F..............................................D
.............FDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD
.............F.HHHHHHHH.....................................D
.............F.PPPPPPPPPPPPP................................D
.............F.MMMMMMMMMMMMMMMMMMMMMMMMM....................D
.............F.KKKKKKKKKKKKKKK..............................D
.............F..............................................D
── legend ──
.  default
D  fg=border
F  fg=focus bold
H  fg=secondary bold
P  fg=primary
M  fg=secondary
A  fg=accent
S  fg=primary bg=selection.fill
K  fg=success
```

### Content minimum at 40 columns

At 40 columns `files` uses the content minimum: it keeps the 13 cells its rows need.
`editor` takes the remaining 26 cells. Its code rows are `Text(...).lineLimit(1)`, so each
row that does not fit marks its own cut with `…`. The app has collapsed `inspector`, which
has no rect and no handle.

```wireframe 40x8
 Files       │ main.swift
 ▾ Sources   │ import Tessera
   App.swift │
   main.swift│ @main
 ▸ Tests     │ struct Demo: App {
             │     var body: some Sce…
             │ }
             │
```

```text
Callouts (40x8, 0-based):
1. r0-r7 c0-c12   Leading pane -- stable ID `files`; `.content` minimum, floor 13 cells
2. r0-r7 c13      Divider handle -- one-cell boundary between `files` and `editor`, Divider `light`
3. r0-r7 c14-c39  Trailing pane -- stable ID `editor`, 26-cell remainder; its rows are
                  `Text(...).lineLimit(1)`, so row 5 ends in the Text's own `…`;
                  SplitView adds no ellipsis
```

```text
── chars ──
 Files       │ main.swift
 ▾ Sources   │ import Tessera
   App.swift │
   main.swift│ @main
 ▸ Tests     │ struct Demo: App {
             │     var body: some Sce…
             │ }
             │
── style ──
.HHHHH.......D.HHHHHHHHHH
.PPPPPPPPP...D.PPPPPPPPPPPPPP
.PPPPPPPPPPP.D
.SSSSSSSSSSSSD.AAAAA
.PPPPPPP.....D.PPPPPPPPPPPPPPPPPP
.............D.PPPPPPPPPPPPPPPPPPPPPPP
.............D.P
.............D
── legend ──
.  default
D  fg=border
H  fg=secondary bold
P  fg=primary
A  fg=accent
S  fg=primary bg=selection.fill
```

## States

The fixtures cover natural two-pane and three-pane arrangements, a completed drag,
application-driven collapse, a 24x6 over-constrained allocation, the 40-column `mobile`
state at natural height (40x10), the declared 17x4 `min` viewport, both axes, nested
junctions, focused handles in both axes, and a 40x8 content-minimum pane. Idle is any
stable fixture without an active pointer drag; loading, empty, and error remain
pane-content states and are rendered by the application-provided child, not by SplitView.
A disabled handle draws in the `disabled` role and has no resize interaction when its
adjacent visible panes cannot change their controlled sizes.

## State model

| State                     | Owner        | Type                                                                                                     | Reset or clamp rule                                                                                                                                                                                                                         |
| ------------------------- | ------------ | -------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| pane configuration        | Binding      | ordered `[SplitViewPane]` containing stable `ID`, `SplitViewPaneSizing`, and `isCollapsed`               | App is authoritative. Every sizing value is valid by construction. Drag and keys change only `sizing.ideal`; `defaultIdeal` changes only through the binding. A collapsed pane retains its sizing and receives a zero main-axis rect.       |
| axis                      | Binding      | `Axis`                                                                                                   | App is authoritative. On change, transpose main/cross-axis negotiation, cancel `pointer drag`, and clear a `focused divider handle` that is no longer live.                                                                                 |
| visible pane sequence     | derived      | ordered `[Pane.ID]`                                                                                      | Recompute from `pane configuration` on every update; omit collapsed panes without changing their identity or order in the binding.                                                                                                          |
| pane priority             | layout value | integer from the child view's `.layoutPriority(_:)`; default 0                                           | Read on every layout. The shared Flex resolver grows the highest-priority pane first, capped at its maximum, and compresses lower priorities first; SplitViewPane does not store a second priority.                                         |
| negotiated pane rects     | derived      | `[Pane.ID: Rect]`                                                                                        | Recompute from `pane configuration`, pane priority, `axis`, and parent bounds through the shared Flex resolver; clamp all extents to nonnegative integers and parent clipping.                                                              |
| focused divider handle    | derived      | `FocusID?`                                                                                               | Recompute from the FocusManager after layout; clear if its adjacent visible pair disappears or becomes nonresizable.                                                                                                                        |
| pointer drag              | NodeState    | optional `(leadingID: Pane.ID, trailingID: Pane.ID, origin: Int, leadingStart: Int, trailingStart: Int)` | Set only during a drag on a live `divider handle`; retain through ordinary reconciliation while the same stable adjacent pane pair remains live; clear only on release, axis change, pair disappearance, focus loss, or node identity loss. |
| focus return candidate    | NodeState    | `[Pane.ID: FocusID]`                                                                                     | When a focused descendant is hidden by `pane configuration`, remember it only if it belongs to that pane; discard it when that focus ID is no longer live.                                                                                  |
| keyboard resizing enabled | Binding      | `Bool`                                                                                                   | App is authoritative. When false, omit divider focusability and clear `focused divider handle` on reconciliation.                                                                                                                           |
| collapse focus target     | derived      | `FocusID?`                                                                                               | When a focused descendant is hidden, choose the first focusable descendant in the next visible pane, then the previous visible pane, otherwise nil; recompute whenever visibility or focusability changes.                                  |
| split view styles         | Environment  | role `Style` values                                                                                      | Resolve `primary`, `border`, `focus`, and `disabled` each render; never retain style in widget state.                                                                                                                                       |

A pane's ID is stable across a sizing or visibility mutation. Reordering the binding is an
explicit application operation; SplitView must not interpret a changed index as the old
pane. `SplitViewPaneSizing` validates its bounds at construction, and a `.content` minimum
is measured at layout. A visible pane's actual allocation is derived, so over-constraint
can shrink or clip it without mutating the binding.

## Interaction

### Focus, collapse, and restoration

A live divider receives an explicit focus ID derived from its ordered pair of stable pane
IDs, for example `split.files.editor`; it is focusable only while
`keyboard resizing enabled` is true and the pair has an adjustable cell. Clicking a handle
follows Slice 5's click-to-focus rule before this widget's mouse action.

Divider identities are the narrow stable-runtime-identity exception: SplitView derives
each live divider's manager-only `FocusID` from its stable adjacent pane pair and axis.
They are not public `id:` or `focused:` initializer arguments, and callers do not receive
automatic IDs. Ordinary controls still require explicit caller composition with
`.focusable(id).focused(binding, equals: id)`.

When the application collapses a pane containing the graph's focused descendant, SplitView
records that descendant as the pane's `focus return candidate`, then requests the nearest
focusable descendant in the next visible pane; if none exists, it requests the previous
visible pane; if neither exists, it clears focus. This is restoration from an invalidated
target, not navigation. On a later application expansion, SplitView restores the candidate
only when the FocusManager focus is still `nil` and the candidate is live; it never steals
a user's newer focus. If the candidate was removed while hidden, it is discarded and focus
remains unchanged.

### Key table

| Key         | Precondition                                             | Effect                                                                                                                                                                                               | Consumed |
| ----------- | -------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- |
| Left        | `focused divider handle` is set and `axis` is horizontal | Decrements the leading adjacent pane's `sizing.ideal` by one and increments the trailing adjacent pane's `sizing.ideal` by one through `pane configuration`; clamps at the negotiated pair bounds.   | yes      |
| Right       | `focused divider handle` is set and `axis` is horizontal | Increments the leading adjacent pane's `sizing.ideal` by one and decrements the trailing adjacent pane's `sizing.ideal` by one through `pane configuration`; clamps at the negotiated pair bounds.   | yes      |
| Up          | `focused divider handle` is set and `axis` is vertical   | Decrements the leading adjacent pane's `sizing.ideal` by one and increments the trailing adjacent pane's `sizing.ideal` by one through `pane configuration`; clamps at the negotiated pair bounds.   | yes      |
| Down        | `focused divider handle` is set and `axis` is vertical   | Increments the leading adjacent pane's `sizing.ideal` by one and decrements the trailing adjacent pane's `sizing.ideal` by one through `pane configuration`; clamps at the negotiated pair bounds.   | yes      |
| Shift-Left  | `focused divider handle` is set and `axis` is horizontal | Decrements the leading adjacent pane's `sizing.ideal` by five and increments the trailing adjacent pane's `sizing.ideal` by five through `pane configuration`; clamps at the negotiated pair bounds. | yes      |
| Shift-Right | `focused divider handle` is set and `axis` is horizontal | Increments the leading adjacent pane's `sizing.ideal` by five and decrements the trailing adjacent pane's `sizing.ideal` by five through `pane configuration`; clamps at the negotiated pair bounds. | yes      |
| Shift-Up    | `focused divider handle` is set and `axis` is vertical   | Decrements the leading adjacent pane's `sizing.ideal` by five and increments the trailing adjacent pane's `sizing.ideal` by five through `pane configuration`; clamps at the negotiated pair bounds. | yes      |
| Shift-Down  | `focused divider handle` is set and `axis` is vertical   | Increments the leading adjacent pane's `sizing.ideal` by five and decrements the trailing adjacent pane's `sizing.ideal` by five through `pane configuration`; clamps at the negotiated pair bounds. | yes      |
| `=`         | `focused divider handle` is set                          | Sets the leading and trailing adjacent panes' `sizing.ideal` to their `sizing.defaultIdeal` through `pane configuration`; other panes are unchanged.                                                 | yes      |
| Tab         | `focused divider handle` is set                          | Leaves focus routing to the application's installed handler; does not mutate `pane configuration`.                                                                                                   | no       |
| Esc         | `focused divider handle` is set                          | Leaves the event available to ancestors and the application; does not mutate `pane configuration`.                                                                                                   | no       |

With the flexible, slack-absorbing pane at the higher priority, each successful arrow-key
resize moves the resolved divider boundary on its first key press rather than consuming
slack by refilling a fixed side pane.

### Mouse table

| Event        | Region         | Precondition                                                                                                | Effect                                                                                                                                                                                                                                                          | Consumed |
| ------------ | -------------- | ----------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- |
| click        | Divider handle | `pointer drag` is empty and the handle's pair exists in `visible pane sequence`                             | Focuses the corresponding `focused divider handle`; leaves `pane configuration` unchanged.                                                                                                                                                                      | yes      |
| drag         | Divider handle | the handle's pair exists in `visible pane sequence` and both panes have capacity within their sizing bounds | On the first event, records `pointer drag`; on each event, converts pointer displacement on `axis` to an integer delta, then updates only the pair's `sizing.ideal` values through `pane configuration`, preserving the pair total whenever both bounds permit. | yes      |
| drag         | Divider handle | `pointer drag` is set and its pair is absent from `visible pane sequence`                                   | Clears `pointer drag` and leaves `pane configuration` unchanged.                                                                                                                                                                                                | yes      |
| double-click | Divider handle | the handle's pair exists in `visible pane sequence`                                                         | Focuses the handle as a click does, then sets the pair's `sizing.ideal` values to their `sizing.defaultIdeal` through `pane configuration`, as `=` does.                                                                                                        | yes      |

Dragging accepts displacement only along the main axis: vertical movement on a vertical
handle, and horizontal movement on a horizontal handle. The grab zone is the one-cell
handle plus one cell on each side in the direction the handle moves (left and right for a
vertical divider, up and down for a horizontal one). Those extra cells take hit-test
precedence over pane content but draw nothing, so the rendered divider stays one cell.
Double-click on a handle, or `=` while it is focused, resets the pair to
`sizing.defaultIdeal`. No hover, wheel, or click-to-collapse behavior is specified:
visibility stays entirely under app control, and nothing collapses automatically when
panes are clipped.

## Sizing

The public controlled sizing value is independent of `FlexConstraint`:

```swift
public struct SplitViewPaneSizing: Equatable, Sendable {
  public enum Minimum: Equatable, Sendable, ExpressibleByIntegerLiteral {
    case cells(Int)
    case content  // the child's measured main-axis minimum

    public init(integerLiteral value: Int) { self = .cells(value) }
  }

  public init(minimum: Minimum = .cells(0), ideal: Int, defaultIdeal: Int? = nil, maximum: Int? = nil)
}
```

All values are whole cells. For `.cells(n)`, construction requires
`0 <= n <= ideal <= maximum` when maximum is present; `.content` is checked against
`maximum` only, and `defaultIdeal` is checked like `ideal`. `nil` maximum is unbounded.
The pane's child may render an intrinsic ideal larger than its assigned segment; explicit
pane sizing wins. Text children lay out again at the assigned width (they wrap or mark
their last visible row); non-text geometry clips, rather than silently changing
application state.

`.content` is a floor measured on every layout from the child's main-axis minimum and
capped at `maximum`. It is never stored: the resolver raises the initial allocation to the
floor when the floor is larger, and the binding's `ideal` is unchanged. `ideal` is the
requested size; `defaultIdeal` is the reset target. It defaults to `ideal` and changes
only through the binding, never through drag or keys. Drag and keys change `ideal` alone,
and `=` or a double-click moves the pair back to `defaultIdeal`.

SplitView reserves one cell per adjacent visible pair, then lowers each visible pane to
the exact [Flex resolver item fields](../primitives/flex.md#constraint-resolution):

| Pane input             | Flex resolver field                                                                                |
| ---------------------- | -------------------------------------------------------------------------------------------------- |
| `sizing.minimum`       | `floor`: `.cells(n)` gives `n`; `.content` gives the child's measured minimum, capped at `maximum` |
| `sizing.ideal`         | `initial allocation`; raised to the floor when the floor is larger                                 |
| `sizing.maximum`       | `growth cap`; nil remains unbounded                                                                |
| `sizing.defaultIdeal`  | none; reset target only, never a resolver item                                                     |
| range adapter          | `growth weight = 1`; `compression phase = minimum`                                                 |
| child `layoutPriority` | separate priority metadata; never copied into the resolver item                                    |
| `isCollapsed == true`  | no resolver item, zero rect, no handle; retain every controlled bound value                        |

The resolver begins at requested ideals. Positive remainder grows higher-priority panes
first up to their maxima, with earliest-source integer remainder. Negative remainder
compresses lower-priority panes first toward their minima, with later-source remainder
yielding first. A container that needs immediate divider response gives its flexible,
slack-absorbing pane the higher priority, so fixed side panes remain at their requested
ideals instead of being refilled from slack. If visible minima plus handles still exceed
the proposal, SplitView reports that floor and the parent clips trailing placement. It
never writes reconciled sizes back to the binding.

A pane that does not fit is clipped at the trailing edge of the parent's clip rect.
SplitView adds no ellipsis itself: a Text inside a pane wraps to the assigned width or
marks its own last visible row, per [Text](../primitives/text.md#truncation). Nothing
collapses automatically. An app that prefers collapsing sets `isCollapsed` itself, for
example from a width check.

The table is fixture-specific so every result is exact:

| Proposal                                        | Result | Rule                                                                                                                               |
| ----------------------------------------------- | ------ | ---------------------------------------------------------------------------------------------------------------------------------- |
| nil x nil                                       | 80x10  | Natural three-pane requested ideals sum 16 + 1 + 46 + 1 + 16; cross-axis ideal is 10.                                              |
| 80x10                                           | 80x10  | Tight proposal exactly matches the natural three-pane requested ideals.                                                            |
| 12x3                                            | 17x4   | Two pane minima plus one handle report the 17x4 floor; a parent assigning 12x3 clips placement.                                    |
| 120x20                                          | 80x10  | All fixture panes have reached their maxima, so SplitView reports 80x10 and leaves parent slack unused.                            |
| 40x nil                                         | 40x10  | Mobile's controlled 8 + 1 + 24 + 1 + 6 requested allocation fills the main axis; cross-axis ideal is 10 at natural height.         |
| 24x6 parent allocation after a 30x6 measurement | 30x6   | Three pane minima and handles measure 8 + 1 + 12 + 1 + 8; graph clipping produces the 24x6 over-constrained rendering.             |
| 40x8                                            | 40x8   | `files` is `.content` and keeps the 13 cells its rows need; collapsed `inspector` has no item, so `editor` takes the remaining 26. |

## Environment

- `primary` -- inherited by ordinary pane content.
- `border` -- applied to an unfocused divider handle.
- `focus` -- applied as a bold foreground-only overlay to a focused divider (owner
  decision, 2026-10-19: the terminal's default foreground, no hue). The focus role has no
  background and no rounded corner glyphs (owner decision, 2026-10-10). A focused handle
  draws the `heavy` line of Divider's glyph table, and its junctions are the heavy set's
  `┣ ┫ ┳ ┻ ╋` (owner decision, 2026-10-10). The heavy junction column is in
  [border sets](../tokens.md#border-sets).
- `disabled` -- applied to a nonresizable divider handle.
- `divider.style` -- [Divider](../primitives/divider.md) glyph selection. SplitView draws
  `light` by default, switches a focused handle to `heavy`, and receives identical
  geometry for every glyph style.
- `divider.blending` -- `.blended` on SplitView's divider cells, so crossing light handles
  join as `├`, `┤`, `┬`, `┴`, or `┼`; ASCII junctions are `+`.
- The [Focus](../tokens.md#focus) rules (rule 4 for split dividers and rule 6 for ASCII)
  -- provide the foreground-only focus presentation for the one-cell handle without
  inventing a component-specific focus color, and without the background or rounded corner
  glyphs of the focus border (owner decision, 2026-10-10).
- `truncation.mark` and the degradation ladder in [tokens.md](../tokens.md) -- consumed by
  pane content and the split's ASCII fallback; SplitView never cuts a grapheme itself.

System and custom styling use the shared complete-`Style` environment merge fixed by
[system and custom style plumbing](../../docs/Spec.md#system-and-custom-style-plumbing).
The focused divider is the exception: it overlays only the focus foreground and boldness,
leaving its background transparent. This replaces the accent color the divider used before
(owner decision, omp2 review, 2026-10). SplitView does not introduce a parallel
`SplitViewStyle` protocol or expose pane business state to styling.

## Primitive dependencies

- [Divider](../primitives/divider.md) (`ready`) -- supplies the `light` and `heavy` rule
  glyphs, the blended junction rule, and sizing; SplitView owns handle focus, hit testing,
  and drag. The heavy junction column is in [border sets](../tokens.md#border-sets).
- [Text](../primitives/text.md) (`ready`) -- pane labels and content in the fixtures;
  actual child content is application supplied.
- `FocusManager` and `.focusable` (Slice 4) -- divider keyboard focus and safe focus
  reassignment during collapse.
- `.onMouse` and hit testing (Slice 5) -- pointer drag and click-to-focus on a handle.
- [Flex](../primitives/flex.md) (`ready`) -- the canonical integer constraint resolver;
  SplitView adapts pane ranges to it, measures `.content` floors from its child, and never
  owns a competing allocator.

SplitView depends on neither Form nor Outline. Source browsing, directory mapping, and
route-oriented sidebars are post-1.0 application composition concerns, not
responsibilities of this low-level adjacency widget.

## Progressive availability

1. **Slice 2** supplies integer proposal, placement, absolute frames, clipping, stable
   view IDs, and the static controlled foundation.
2. **Phase 2.5** deletes the static allocator and installs the shared Flex resolver plus
   the final min/ideal/max pane adapter, including `.content` floors, documented here. All
   later behavior consumes its immutable resolved pane frames.
3. **Slice 4** adds focusable divider handles, arrow-key resizing, Shift-arrow five-cell
   steps, `=` reset, and the collapse focus restoration rule. It depends on the graph's
   explicit FocusID and routing order. These land in plan 032 step 15.1.
4. **Slice 5**, after mouse support, adds click-to-focus, raw drag dispatch, the wider
   grab zone, and double-click reset, also in plan 032 step 15.1. The visual one-cell
   handle remains available without mouse capability.
5. **Slice 7 and later** may place controlled application widgets inside panes. SplitView
   remains separate from navigation semantics throughout; it is available progressively as
   layout and input capabilities arrive rather than waiting for a navigation shell.

## Requirements

- `split view preserves stable pane identity and sizing across requested ideal changes`
  (state model: pane configuration; drag wireframe)
- `split view renders one one-cell handle between each adjacent visible pane` (natural
  two-pane and three-pane anatomy)
- `split view omits collapsed panes and their handles without replacing application content`
  (collapsed wireframe; state model: visible pane sequence)
- `split view restores a hidden focused descendant only when focus remains clear` (state
  model: focus return candidate)
- `split view moves focus to the nearest visible pane when collapsing the focused pane`
  (state model: collapse focus target)
- `focused divider arrow keys move the boundary on first press with flexible slack` (key
  table; sizing: resolver rules)
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
- `split view grows higher priority panes before lower priority panes reach surplus`
  (sizing: pane adapter table)
- `a higher-priority flexible pane absorbs surplus before fixed side panes are refilled`
  (sizing: resolver rules)
- `split view never writes effective negotiated sizes back to pane configuration` (state
  model: pane configuration; sizing: resolver rules)
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
- `focused divider styling overlays only a bold focus foreground with no background`
  (environment: `focus`)
- `split view moves a focused divider five cells with shift arrow keys` (key table:
  Shift-Left, Shift-Right, Shift-Up, Shift-Down)
- `split view resets a focused divider pair to defaultIdeal with equals` (key table: `=`)
- `split view resets a divider pair to defaultIdeal on double-click` (mouse table:
  double-click row)
- `divider grab zone hit-tests one cell to each side without drawing extra cells`
  (interaction: grab zone; nested anatomy)
- `split view changes defaultIdeal only through the pane binding` (state model: pane
  configuration; sizing: defaultIdeal row)
- `content minimum floor is measured from the child on every layout and capped at maximum`
  (sizing: minimum enum; Flex table)
- `split view keeps a content-minimum pane at the cells its rows need at 40 columns`
  (narrow-40 wireframe; sizing: minimum enum)
- `split view clips a pane that does not fit at the trailing edge with no ellipsis`
  (sizing: clipping paragraph; declared minimum wireframe)
- `split view never collapses a pane automatically under over-constraint` (degradation:
  below the declared minimum; collapsed wireframe)
- `nested split handles join at blended junctions` (nested layout anatomy)
- `focused divider draws the heavy line in the focus style` (nested-focused and
  divider-focused anatomy; environment: `focus`)
- `focused divider junctions render heavy junction glyphs` (nested-focused anatomy; owner
  decision, 2026-10-10)
- `ascii fallback draws plus at junctions and bolds a focused divider` (degradation:
  ASCII-only)

## Degradation

- **`NO_COLOR`:** preserve Divider glyphs, one-cell geometry, hit regions, and keyboard
  behavior. The focused divider's foreground-only focus treatment degrades through the
  token ladder's bold treatment instead of a color distinction.
- **16-color:** retain the same semantic `primary`, `secondary`, `focus`, and `disabled`
  styles using the environment's indexed approximation; a focused divider still overlays
  only its bold focus foreground, with no background fill. Allocation and clipping do not
  change.
- **ASCII-only:** replace `│` and `─` with the Divider `ascii` glyphs `|` and `-`, and
  junctions with `+`. A focused divider cannot take the heavier line, so it stays `|` or
  `-` and is drawn in bold instead. Replace pane-content truncation `…` with `~` according
  to [tokens.md](../tokens.md#degradation-ladder). Handles remain exactly one cell and
  fully interactive.
- **Below the declared minimum:** report the floor during measurement, accept the parent's
  smaller clip rect during placement, and paint only visible leading cells. Never collapse
  a pane, mutate its sizing, or substitute navigation content automatically.

## Decisions and exact deferrals

- **Public pane construction:** The controlled input is one binding to an ordered
  `[SplitViewPane]`. Each element contains its stable ID, valid `SplitViewPaneSizing`, and
  collapsed flag. Separate parallel bindings are rejected because they can diverge in
  membership or order.
- **Sizing adapter:** `SplitViewPaneSizing` owns the minimum (fixed cells or `.content`),
  requested ideal, reset target, and optional maximum. The child view's existing
  `.layoutPriority(_:)` value controls growth and compression tiers. SplitView lowers both
  into the shared [Flex contract](../primitives/flex.md), keeps the public pane model
  independent of `FlexConstraint`, and has no static fallback allocator.
- **Styling:** SplitView consumes the shared semantic complete-`Style` values. A focused
  divider draws the `heavy` line and overlays only the bold focus foreground, leaving its
  background transparent; it does not define a separate style protocol. Custom application
  styling uses the same environment merge fixed by
  [system and custom style plumbing](../../docs/Spec.md#system-and-custom-style-plumbing).
- **Programmatic expansion focus:** A saved descendant is restored only while focus is
  nil. Expansion never steals a newer focus selection.
- **Pane removal during drag:** Removing either stable pane cancels the drag. SplitView
  never retargets by positional index.
- **Nested junctions:** nested splits join where their handles meet, using blended light
  junctions; a focused heavy handle's junctions use the heavy set's `┣ ┫ ┳ ┻ ╋` (owner
  decision, 2026-10-10). Blended light junctions: owner decision, omp2 review, 2026-10.
- **Content minimum:** each pane chooses a fixed cell minimum or `.content`, the child's
  measured minimum. Owner decision, omp2 review, 2026-10.
- **Keyboard step and reset:** Shift-arrow keys move a focused divider five cells; `=` and
  double-click reset the pair to `sizing.defaultIdeal`. Owner decision, omp2 review,
  2026-10.
- **Grab zone:** a handle hit-tests one cell to each side; drawn cells are unchanged.
  Owner decision, omp2 review, 2026-10.
- **Clipping:** a parent too small for every minimum clips trailing panes with no
  ellipsis; nothing collapses automatically, and an app may collapse explicitly. Owner
  decision, omp2 review, 2026-10.
- **ASCII focus:** junctions are `+`, and a focused divider is bold. Owner decision, omp2
  review, 2026-10.
- **Divider focus identity (key E1):** dividers take manager-only focus IDs derived from
  their stable adjacent pane pair and axis (see
  [Focus, collapse, and restoration](#focus-collapse-and-restoration)); every other focus
  stop keeps key E1's explicit, caller-composed ID. Collapse restoration covers a hidden
  pane only: a removed focused node still clears focus, as key E1 requires.

This design was reviewed against the
[Phase 4 theses](../../docs/Spec.md#phase-4--view-layer-the-tessera-module): pane data is
controlled, drag state is ephemeral and identity-bound, input is routed explicitly, and
all geometry is deterministic integer-cell output.

## Open questions

None. Junction and focus-role decisions are recorded under Environment and Decisions
(owner decision, 2026-10-10).

## Inspiration

- 2026-07-06 -- `SplitView` is the right second widget exemplar: it uniquely exercises
  divider drag, min-size negotiation, and collapse (Slice 5 hit testing), none of which
  Table touches. (triaged from [inbox.md](../inbox.md))
