---
kind: app
status: wireframed
---

# Tessera Showcase

## Purpose and 1.0 boundary

**Tessera Showcase** is the runnable Phase 4 integration catalog: a dense app that
composes the public Tessera surface, demonstrates one focused contract at a time, and
presents its live local graph through developer diagnostics. It is neither a second
component specification nor a tutorial, source browser, file mapper, or alternate
application shell.

The [design catalog process](README.md) remains authoritative for component anatomy,
state, sizing, input, degradation, and requirements. Showcase owns only integration
composition: catalog selection, runnable specimen state, responsive presentation, local
diagnostics presentation, and proof that public components compose. Every inventory row
links to its source contract instead of copying one.

The 1.0 public surface is **Button, Toggle, Picker, Stepper, TextField, List, ScrollView,
Section, Table, SplitView, and NavigationSplitView**. System styles and custom styles are
both public directions; semantic roles are complete `Style` values, never color aliases.
`Form`, `Outline`, source browsing, and source-to-node mapping remain post-1.0.

The Showcase uses public controls for every user operation. In particular, Catalog,
Inspector, and Close/Open affordances are visible Buttons at compact sizes; they are not
undiscoverable key-only chrome. The app model owns selections, control values, visibility,
and viewport bindings. Widgets retain only their documented ephemeral `NodeState`.

## Responsive policy

`120x24` is the natural three-role ideal fixture, not a breakpoint or global viewport
token. The catalog's canonical `desktop` and `mobile` sizes remain defined by
[tokens](tokens.md#viewports); `40x16` remains the canonical mobile fixture. The Showcase
minimum is independently `23x10`: width below 23 **or** height below 10 renders only the
resize guard.

Final SplitView negotiation keeps Catalog and Inspector symmetric and capped while the
Playground absorbs shrink and surplus:

| Role       | Minimum | Requested ideal | Maximum | `layoutPriority` | Rule                                                      |
| ---------- | ------- | --------------- | ------- | ---------------- | --------------------------------------------------------- |
| Catalog    | 23      | 24              | 24      | 1                | Stable leading side column; never consumes surplus.       |
| Playground | 23      | 70              | nil     | 0                | Shrinks first and receives all surplus after side ideals. |
| Inspector  | 23      | 24              | 24      | 1                | Matches Catalog exactly in the three-role presentation.   |

The two-role presentation reuses the same Catalog and Playground constraints. Throughout
its 48–72-column band, negotiation compresses Playground to `W - 25` without mutating its
controlled ideal of 70. Role replacement happens before a regular side pane is squeezed
below its 24-cell requested ideal. Showcase defines no pane-specific priority state.

| Bounds                    | Showcase presentation                                  | Preservation rule                                                                                             |
| ------------------------- | ------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------- |
| `W >= 73`, `H >= 10`      | Catalog + Playground + Inspector                       | side panes remain 24 cells; Playground receives `W - 50` and every region scrolls independently               |
| `48 <= W < 73`, `H >= 10` | Catalog + Playground, Inspector replacement            | Catalog remains 24 cells; Playground receives `W - 25`; selection and specimen state survive role replacement |
| `23 <= W < 48`, `H >= 10` | one full-screen Catalog, Playground, or Inspector role | use NavigationSplitView compact replacement and a ScrollView around critical content                          |
| `W < 23` **or** `H < 10`  | resize guard                                           | render only the resize instruction and preserve app model without a partial workspace                         |

The responsive fixture matrix exercises each predicate independently and brackets every
width transition:

| Fixture                                                 | Expected state |
| ------------------------------------------------------- | -------------- |
| `22x10`, `23x9`, `22x9`                                 | resize guard   |
| `23x10`, `24x10`, `40x16`, `47x10`                      | one role       |
| `48x10`, `49x10`, `72x10`                               | two roles      |
| `73x10`, `74x10`, `80x24`, `119x24`, `120x24`, `121x24` | three roles    |

At 40x16, compact presentation remains dense but touch-operable: labeled Buttons remain
visible, software keyboard and dictation commit into the focused TextField through the
same input path, arrows remain a keyboard fallback, and critical material is inside a
ScrollView rather than silently clipped.

## Catalog inventory and composition ownership

The accepted 1.0 components without a component document yet—Toggle, Picker, Stepper, and
Section—remain catalog work; Showcase uses their eventual public interfaces but never owns
their contracts. The linked inventory is the catalog available for composition now.

| Public surface                                          | Catalog status | Showcase entry and composition responsibility                                            | 1.0 decision                  |
| ------------------------------------------------------- | -------------- | ---------------------------------------------------------------------------------------- | ----------------------------- |
| [Button](widgets/button.md)                             | wireframed     | action, enabled, role, and system/custom-style specimens                                 | accepted                      |
| [TextField](widgets/text-field.md)                      | wireframed     | focus, overflow, Unicode, software-keyboard, and dictation specimen                      | accepted clean public name    |
| [List](widgets/list.md)                                 | sketch         | flat Catalog selection and final integration                                             | accepted                      |
| [ScrollView](widgets/scroll-view.md)                    | ready          | clipped playground and all critical compact overflow                                     | accepted                      |
| [Table](widgets/table.md)                               | specified      | dense data/solver specimen                                                               | accepted                      |
| [SplitView](widgets/split-view.md)                      | ready          | pane size/collapse playground and regular adjacency                                      | accepted                      |
| [NavigationSplitView](widgets/navigation-split-view.md) | wireframed     | regular and compact Catalog/Playground/Inspector composition                             | accepted                      |
| [Divider](primitives/divider.md)                        | ready          | documented rules and SplitView handles only                                              | accepted primitive dependency |
| [ScrollIndicator](primitives/scroll-indicator.md)       | wireframed     | shared, output-only overflow geometry in ScrollView, List, and Table                     | accepted primitive dependency |
| [Text](primitives/text.md)                              | specified      | ordinary, Unicode, multiline, constrained, wrapped, and truncated text specimens         | accepted primitive dependency |
| [Frame](primitives/frame.md)                            | specified      | fixed, bounded, aligned, and clipped allocation specimens                                | accepted primitive dependency |
| [Linear stacks](primitives/stacks.md)                   | specified      | HStack, VStack, Spacer, priority, remainder, and overflow specimens                      | accepted primitive dependency |
| [Padding](primitives/padding.md)                        | specified      | uniform, asymmetric, nested, and Button-label inset specimens                            | accepted primitive dependency |
| [ZStack](primitives/z-stack.md)                         | specified      | aligned overlay and source-order paint specimens                                         | accepted primitive dependency |
| [Border](primitives/border.md)                          | sketch         | decoration specimens and focus chrome                                                    | accepted primitive dependency |
| [Box](primitives/box.md)                                | sketch         | framed composition specimens                                                             | accepted primitive dependency |
| [Background](primitives/background.md)                  | sketch         | background style composition                                                             | accepted primitive dependency |
| [Overlay](primitives/overlay.md)                        | sketch         | selected-frame presentation overlay                                                      | accepted primitive dependency |
| [Style modifiers](primitives/style-modifiers.md)        | sketch         | system/custom style replacement specimens                                                | accepted primitive dependency |
| [tokens](tokens.md)                                     | sketch         | complete semantic Styles, focus, selection, border, truncation, and indicator vocabulary | shared contract               |

A catalog row is a link and a selection target, not a duplicate design document. The
Showcase may prove that components compose; it must not define a second input table,
sizing table, or style protocol. Its fixtures below are application-composition evidence;
the linked catalog documents remain the per-component contract.

## Diagnostics presentation

The
[Slice 1 diagnostics contract](../docs/Spec.md#slice-1-tesseracore--view-viewgraph-reconciliation-text)
is normative. The Inspector presents the Spec-defined immutable snapshot from the most
recent completed graph pass. Selecting a node changes only app selection; the Inspector
reads the completed snapshot and cannot mutate the graph or trigger a pass. Its frame and
clip overlay is presentation only: it is not hit testing, source mapping, a rendering
pass, or a value-recording debugger.

## Runnable composition

The flat Catalog is a `List` grouped by `Section`: Overview, Primitives, Text and style,
Controls, Collection and scrolling, Layout, and Diagnostics. Selection is an app binding.
Each focused entry contains a title, a link to its catalog document, a small runnable
specimen, public contextual controls, and inspector access. Loading, empty, and error are
app child states: a ScrollView clips and translates whichever child it receives but
invents no business status.

### Dense default Overview

This is the canonical simultaneous three-region composition at the Responsive policy's
120-column ideal. Catalog and Inspector retain symmetric 24-cell panes; Playground owns
the 70-cell flexible middle. Each region uses its own ScrollView as necessary.

```wireframe 120x24
Tessera Showcase  Overview  [Catalog] [Inspect] [Close]
Catalog                 │ Overview                                                             │ Inspector
Overview                │ [Run] Theme: System  Density: Dense                                  │ Graph / Playground
Primitives              │ ─────────────────────────────────────────────────                    │ > Root
Text and style          │ [Save] [Disabled] [Delete]                                           │   Catalog
Controls                │ Toggle: [x] Border  Picker: System                                   │   Playground
Collection and scrolling│ Stepper: [-] 3 [+]                                                   │   Button
Layout                  │ Search                                                               │
Diagnostics             │ ╭───────────────────────────────────────────────╮                    │ Node Button.save
> Overview              │ │東京👩🏽‍💻 release-notes.md                        │                    │ frame: 29,4 19x3
  Button                │ ╰───────────────────────────────────────────────╯                    │ proposal: 57x20
  TextField             │ [Open Button playground]                                             │ measured: 19x3
  ScrollView            │                                                                      │ clip: 29,1 57x22
  Table                 │ Dense system styles and long specimens scroll.                       │ handlers: key mouse
  SplitView             │                                                                      │ focusable: true
  NavigationSplitView   │                                                                      │ requested: mouse
                        │                                                                      │ effective: session
                        │                                                                      │
                        │                                                                      │
                        │                                                                      │
                        │                                                                      │
                        │                                                                      │
                        │                                                                      │
Tab next  Enter invoke  Arrows scroll  [Inspect] replacement  [Close] hides selected region
```

```text
Callouts (120x24, 0-based):
0. r0 c0-c61 Application header -- title plus visible public Catalog, Inspect, and Close Buttons.
1. r1-r22 c0-c23 Catalog region -- flat List + Section composition; its selected Overview row is app-owned.
2. r1-r22 c25-c94 Playground region -- live public controls and specimen, not a copied component contract.
3. r1-r22 c96-c119 Inspector region -- immutable local diagnostic snapshot for the selected node.
4. r7-r10 c25-c94 TextField specimen -- focusable controlled field; its content never becomes diagnostic raw data.
5. r23 c0-c119 Input legend -- Tab and arrows are fallback paths alongside visible Buttons and touch targets.
```

### ScrollView playground — desktop

The viewport is intentionally unframed. Its ScrollIndicator is the shared primitive, while
the app owns content, loading/empty/error copy, and the optional offset binding.

```wireframe 80x24
Tessera Showcase  ScrollView                         [Catalog] [Inspect]
ScrollView  vertical + horizontal  offset: (12,8)    [Top] [Bottom]
release notes — Q3 preview — internal draft                          │
the document is translated by the app-owned offset                   │
content outside the clipped viewport is not painted                  │
keyboard arrows move one cell when this viewport is focused          █
page keys move one viewport; Home and End clamp                      █
wheel or touch-wheel changes the same offset binding                 █
inner viewport gets first wheel delivery                             █
at an edge the event bubbles to an enclosing viewport                █
indicators are output only; they have no drag or focus               │
loading: [Load]  empty: [Clear]  error: [Retry]                      │

────────────■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■──────────────

Focusable viewport: yes   Controlled offset: yes   Content: app-owned







Tab next  Up/Down/Left/Right  PgUp/PgDn  Home/End  Wheel at edge bubbles
```

```text
Callouts (80x24, 0-based):
0. r2-r11 c0-c68 Viewport content -- translated, clipped child cells; this is the focus and wheel region.
1. r2-r11 c69 Vertical indicator -- mounted shared ScrollIndicator only because the vertical extent overflows.
2. r13 c0-c78 Horizontal indicator -- shared primitive on the bottom reserved edge for horizontal overflow.
3. r11 c0-c47 App status controls -- Button actions choose app child loading, empty, or error state; ScrollView owns none.
4. r23 c0-c79 Keyboard and pointer legend -- focused keys and boundary bubbling share the same effective offset.
```

### ScrollView playground — mobile

The mobile fixture reserves its trailing indicator cell and keeps every critical control
in the scrolling content. `Dictation text` and software-keyboard commits travel to the
focused TextField when present; terminal arrows remain available when a hardware keyboard
exists.

```wireframe 40x16
ScrollView                  [Catalog]
[Top] [Bottom]  offset: y=8
Release notes                         │
A clipped viewport, not a second      │
layout system.                        │
[Load] [Clear] [Retry]                █
Touch wheel moves this same binding.  █
At an edge it bubbles outward.        █
Indicators do not take focus.         █
Critical controls stay reachable.     █
Software keyboard input is host text. │
Arrow keys remain a fallback.         │
Dictation commits to focused fields.  │
No smooth animation.                  │

Tab next  Up/Down scroll  [Inspect]
```

```text
Callouts (40x16, 0-based):
0. r2-r14 c0-c38 Mobile viewport content -- dense translated child content, including reachable public Buttons.
1. r2-r14 c39 Vertical indicator -- one trailing shared ScrollIndicator strip; no second focus stop.
2. r5 c0-c21 State controls -- touch-operable public Buttons for app-owned loading, empty, and error children.
3. r10-r12 c0-c38 Mobile input guidance -- host software keyboard and dictation commit through ordinary focused input; arrows remain fallback.
4. r15 c0-c39 Compact legend -- selection of Inspector is a visible replacement action, not hidden navigation.
```

### NavigationSplitView — regular composition

Regular navigation composes generic supplied Catalog, Playground, and Inspector role
children through SplitView with app-controlled role visibility. The Showcase happens to
supply a `List`/`Section` Catalog child; neither type is a NavigationSplitView dependency.
Catalog selection is app-owned; no role means source navigation, destination ownership, or
history.

```wireframe 80x24
[Close Catalog] Playground                              [Close Inspector]
──────────────────────┬────────────────────────────────┬──────────────────────
Components            │ NavigationSplitView            │ Inspector
> Button              │ Three supplied roles compose.  │ selection: Button
  TextField           │ [Open Catalog] [Inspect]       │ frame: 23,2 32x20
  ScrollView          │                                │ clip: 23,2 32x20
  SplitView           │ Catalog selection recomposes   │ children: 5
  NavigationSplitView │ this playground.               │
  Table               │                                │ diagnostics local
                      │ Regular visibility: all        │ in memory only
[Open Playground]     │                                │
                      │[Close Catalog][Close Inspector]│
                      │                                │
                      │                                │
                      │                                │
                      │                                │
                      │                                │






Tab next  Enter/Space toggle  Divider arrows resize  Drag handle  [Inspect]
```

```text
Callouts (80x24, 0-based):
0. r0 c0-c14 Catalog close Button -- labeled, focusable, and touch-visible visibility binding control.
1. r0 c55-c71 Inspector close Button -- same public Button contract for the detail role.
2. r1-r22 c0-c21 Catalog role -- Showcase composes a List + Section child here; its selection is not container business state.
3. r1-r22 c23-c54 Playground role -- generic supplied child composed through SplitView.
4. r1-r22 c56-c79 Inspector role -- generic supplied detail child reading the local immutable diagnostic snapshot.
5. r23 c0-c79 Regular interaction legend -- SplitView owns divider keyboard/drag semantics; NavigationSplitView owns role replacement.
```

### NavigationSplitView — compact Catalog

```wireframe 40x16
Catalog                    [Inspect]
────────────────────────────────────────
Components
> Button
  TextField
  ScrollView
  SplitView
  NavigationSplitView
  Table

[Open Playground]
[Open Inspector]

Catalog scrolls when records overflow.

Tab next  Enter select  [Close]
```

```text
Callouts (40x16, 0-based):
0. r0 c27-c35 Inspector Button -- touch-visible detail replacement target.
1. r2-r9 c0-c39 Catalog role -- sole compact supplied role; List selection remains app-owned.
2. r10-r11 c0-c16 Open Buttons -- visible paths to the other supplied compact roles.
3. r13 c0-c38 Overflow notice -- catalog uses ScrollView rather than clipping additional records.
4. r15 c0-c39 Compact input legend -- keyboard selection is an additional path, not the only path.
```

### NavigationSplitView — compact Playground

```wireframe 40x16
[Catalog] Playground         [Inspect]
────────────────────────────────────────
Button playground
[Save]
[Disabled]
[Delete]

System: rounded focus chrome
Custom: compact outline style

[Open Catalog]
[Open Inspector]

Specimen scrolls if controls overflow.

Tab next  Enter invoke  [Close]
```

```text
Callouts (40x16, 0-based):
0. r0 c0-c8 Catalog Button -- labeled compact replacement target.
1. r0 c29-c37 Inspector Button -- labeled compact replacement target.
2. r2-r8 c0-c39 Playground role -- sole compact live specimen with multiple public Buttons.
3. r10-r11 c0-c16 Open Buttons -- duplicate reachable role controls inside the content flow.
4. r13 c0-c38 Overflow policy -- focused specimen content must scroll instead of becoming inaccessible.
5. r15 c0-c39 Compact input legend -- Button activation remains available by focus and visible touch targets.
```

### NavigationSplitView — compact Inspector

```wireframe 40x16
[Catalog] Inspector           [Close]
────────────────────────────────────────
Node Button.save
frame: 4,3 32x3
proposal: 40x14
measured: 32x3
clip: 0,2 40x13
handlers: key mouse
requested: mouse
effective: session

[Open Playground]
[Open Catalog]

Inspector scrolls node facts.
Tab next  Enter open  [Close]
```

```text
Callouts (40x16, 0-based):
0. r0 c0-c8 Catalog Button -- compact replacement control for the Catalog role.
1. r0 c31-c37 Close Button -- visible dismissal that returns to app-selected compact presentation.
2. r2-r9 c0-c39 Inspector role -- selected immutable diagnostic metadata; no controlled raw value is displayed.
3. r11-r12 c0-c16 Open Buttons -- direct paths to the other full-screen roles.
4. r14 c0-c38 Inspector overflow policy -- node facts are vertically scrollable at compact height.
5. r15 c0-c39 Compact interaction legend -- open/close actions are public Button actions.
```

### SplitView — resize and collapse playground

The surrounding specimen gives SplitView app-owned pane identities, requested integer
sizes, and collapsed flags. Divider behavior is public SplitView behavior and its rules
use [Divider](primitives/divider.md); no custom pane allocator appears in Showcase.

```wireframe 80x16
Tessera Showcase  SplitView   [Collapse Files] [Restore Files]
Files               │ Document                                   │ Inspector
Inbox               │ release-notes.md                           │ width: 16
Sent                │                                            │ [Collapse]
Drafts              │ Drag or arrow resize the selected handle.  │
                    │                                            │
                    │                                            │
                    │                                            │
                    │                                            │
                    │                                            │
                    │                                            │
                    │                                            │
Files collapsed: false  requested: 16 / 46 / 16  focused: files-document


[Left] [Right] resize focused divider  Drag divider  [Collapse Files]
```

```text
Callouts (80x16, 0-based):
0. r0 c31-c46 Collapse Files Button -- app mutates the files pane collapsed binding.
1. r1-r12 c0-c19 Files pane -- application-supplied child with stable identity.
2. r1-r12 c20 Divider handle -- one-cell SplitView region rendering Divider; focus, arrows, and drag belong to SplitView.
3. r1-r12 c21-c64 Document pane -- adjacent application child resized only with its neighboring pair.
4. r1-r12 c65 Divider handle -- second independent neighboring-pair handle.
5. r1-r12 c66-c79 Inspector pane -- application child, not a navigation destination.
6. r13 c0-c79 Bound-state readout -- pane sizing/collapse values are app-owned and survive resize.
7. r15 c0-c79 Interaction legend -- arrow fallback and drag exercise the same controlled pane configuration.
```

Collapsed result after the visible Button action:

```wireframe 80x16
Tessera Showcase  SplitView   [Collapse Files] [Restore Files]
Document                                                       │ Inspector
release-notes.md                                               │ width: 16
                                                               │ [Collapse]
Files pane is collapsed; its stable ID and sizing values stay  │
in the binding, but it has no visible rectangle or handle.     │
                                                               │
                                                               │
                                                               │
                                                               │
                                                               │
                                                               │
                                                               │
Files collapsed: true  ideal: 16 / 62 / 16

[Restore Files]  Focus returns only when no newer focus exists.
```

```text
Callouts (80x16, 0-based):
0. r1-r12 c0-c62 Document pane -- reclaimed visible space after the files pane is omitted.
1. r1-r12 c63 Divider handle -- only the remaining adjacent visible-pair handle.
2. r3-r4 c0-c62 Collapse explanation -- stable identity remains bound without automatic navigation or content substitution.
3. r13 c0-c50 Bound-state readout -- collapse preserves the hidden sizing for later restoration.
4. r15 c0-c79 Restore policy -- focus restoration occurs only when focus is clear, as SplitView specifies.
```

### TextField — focus, overflow, Unicode, and input sources

Both controls are focusable; the first tests horizontal reveal and the second tests
grapheme/display-cell boundaries. The diagrammatic caret marks a hardware cursor request,
not a character inserted into the app binding.

```wireframe 80x16
Tessera Showcase  TextField                       [Catalog] [Inspect]
Repository path  bound: 102 cells  viewport: 78  reveal offset: 25
╭──────────────────────────────────────────────────────────────────────────────╮
│Users/mruiz/Documents/2026/releases/platform/desktop/release-notes-final-q.md▏│
╰──────────────────────────────────────────────────────────────────────────────╯
Display name
╭──────────────────────────────────────────────────────────────────────────────╮
│東京👩🏽‍💻 é▏                                                                     │
╰──────────────────────────────────────────────────────────────────────────────╯
[Submit] [Clear]  Focus: Repository path  Cursor: hardware
Software keyboard and Paste insert normal text; dictation commits likewise.
Left/Right move whole graphemes; Home/End reveal; Tab advances to Display name.
Overflow is a clipped editable viewport: no ellipsis and no binding mutation.

[Focus path] Repository path -> Display name -> Submit -> Clear
Tab next  Arrow edit  Enter submit  [Close]
```

```text
Callouts (80x16, 0-based):
0. r1-r4 c0-c79 First TextField -- complete bound value is `/workspace/releases/platform/desktop/release-notes-final-q.md`; its 25-cell hidden prefix leaves a 77-cell visible suffix, with the caret as the 78th viewport cell.
1. r5-r8 c0-c79 Second TextField -- independently focusable Unicode field; wide and combining graphemes retain boundary-safe caret placement.
2. r9 c0-c15 Public Buttons -- submit and clear actions exercise app-owned bindings without widget business state.
3. r10 c0-c79 Mobile host input policy -- software keyboard, Paste, and dictation feed the same focused text-event path.
4. r11 c0-c79 Keyboard fallback policy -- arrows and Home/End are routed field input; Tab advances through the explicit focus order.
5. r14 c0-c79 Focus path -- confirms at least two focusable controls plus public action controls participate in traversal.
```

### Button — states, styles, and role playground

The same public Button API renders compact system, bordered, plain-menu, destructive, and
custom-style instances. Style selection affects presentation only; all enabled instances
retain standard focus and activation semantics.

```wireframe 80x16
Tessera Showcase  Button                          [Catalog] [Inspect]
Compact system style
[Save] [Disabled] [Delete]
Focused: Save (accent content)  Pressed: full accent frame

Bordered style
╭────────────╮  ┌────────────┐  ┌──────────────┐
│    Save    │  │  Disabled  │  │    Delete    │
╰────────────╯  └────────────┘  └──────────────┘
Plain menu: Save  Delete
Custom: <Save> <Delete>
Role: default / disabled / destructive
Enabled action count: 3
[Focus Save] [Disable Save] [Reset count]

Tab next  Enter or Space invoke  Touch target is the allocated Button frame
```

```text
Callouts (80x16, 0-based):
0. r2 c0-c5 Compact Save Button -- enabled default-style action with full accent focus and press treatment.
1. r2 c7-c16 Compact Disabled Button -- visible but excluded from focus and activation.
2. r2 c18-c25 Compact Delete Button -- destructive semantic role without alternate event semantics.
3. r5-r7 c0-c47 Bordered Buttons -- explicitly selected larger standalone style; Save alone has rounded accent focus chrome.
4. r8 c0-c23 Plain menu Buttons -- unframed label actions remain focusable and activate by the same public contract.
5. r9 c0-c21 Custom Buttons -- custom `ButtonStyle` specimens preserve public activation behavior.
6. r12 c0-c38 Control Buttons -- public app actions change enabled state and action-count binding.
7. r14 c0-c79 Interaction proof -- both keyboard activation and full allocated touch target reach the ordinary Button action.
```

### Dense color and style sheet

This dense sheet demonstrates token resolution, not an independent palette. Semantic roles
are complete Style values: foreground, background, and attributes resolve together through
the environment. The list is vertically scrollable; a `ScrollIndicator` appears only when
it overflows.

```wireframe 80x24
Tessera Showcase  Styles                            [Catalog] [Inspect]
Styles  [System] [Custom]  Capability: full
Semantic primary       The quick brown fox                          │
Semantic secondary     The quick brown fox                          │
Semantic accent        The quick brown fox                          │
Semantic disabled      The quick brown fox                          │
Semantic destructive   The quick brown fox                          │
────────────────────────────────────────────────────────────────────│
Text normal            Bold  Dim  Italic  Strike                    █
Underline              Off  Single  Double  Curly                   █
Borders                Light Rounded Heavy Double ASCII             █
Focus                  border accent / content selection            █
Selection              bar fill inactive ascii                      █
Scroll indicator       track thumb vertical horizontal              █
Truncation             tail …   ASCII ~                             █
────────────────────────────────────────────────────────────────────│
System style resolves roles from environment.                       │
Custom style replaces a role for this subtree only.                 │
No hard-coded RGB or component-private palette.                     │




Tab next  Up/Down scroll  Enter inspect selected style specimen
```

```text
Callouts (80x24, 0-based):
0. r2-r6 c0-c67 Semantic role rows -- complete primary, secondary, accent, disabled, and destructive Style specimens.
1. r7-r14 c0-c67 Token rows -- dense text, underline, border, focus, selection, indicator, and truncation results.
2. r2-r19 c68 Overflow indicator -- shared ScrollIndicator mounted only when the sheet exceeds its viewport.
3. r16-r18 c0-c67 Style source notes -- system and custom style environment replacement without a Showcase-only palette.
4. r23 c0-c79 Inspection legend -- selected specimen points to style metadata, not a raw resolved control value.
```

### Inspector — selected node and overlay

The inspector begins from the
[Slice 1 immutable diagnostic snapshot](../docs/Spec.md#slice-1-tesseracore--view-viewgraph-reconciliation-text).
Selecting a node changes only app selection. The overlay uses that snapshot's selected
frame and clip; it is not hit-testing, source mapping, a rendering pass, or a debugger
that records values.

```wireframe 80x24
Tessera Showcase  Inspector                         [Catalog] [Close]
Graph tree                     │ Live playground + selected-frame overlay
> Root                         │ ┌──────────────────────────────────────────┐
  Catalog                      │ │ Button playground                        │
  Playground                   │ │ ┏━━━━━━━━━━ selected Button.save ━━━━━━┓ │
  Button.save                  │ │ ┃   Save                               ┃ │
  Inspector                    │ │ ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛ │
                               │ │ [Disabled] [Delete]                      │
Node: Button.save              │ └──────────────────────────────────────────┘
type: Button<Text>             │
parent: Playground             │ Overlay frame: 27,4 40x3
proposal: 54x20                │ Overlay clip: 25,2 54x9
measured: 14x3                 │
frame: 27,4 14x3               │
clip: 25,2 54x9                │
handlers: key, mouse           │
focusable: true                │
requested: mouse               │
effective: session             │
style overrides: ButtonStyle   │
state summary: press feedback  │
                               │

Tab tree  Enter select  [Close]  Snapshot is local immutable developer metadata
```

```text
Callouts (80x24, 0-based):
0. r2-r7 c0-c29 Graph tree -- app-selected node path from immutable local diagnostics.
1. r2-r8 c31-c79 Playground overlay -- selected frame and clip metadata rendered over the live specimen without source or event routing behavior.
2. r9-r20 c0-c29 Node facts -- structural, layout, handler, requirement, and redacted diagnostic metadata only.
3. r11-r12 c31-c79 Overlay facts -- exact selected frame and clip used by the overlay.
4. r23 c0-c79 Inspector boundary — selection reads the prior completed in-memory snapshot; it performs no serialization, logging, telemetry, or raw-value capture.
```

## How the Showcase grows

The Showcase grows slice by slice according to the
[Phase 4 slice plan](../docs/Spec.md#phase-4--view-layer-the-tessera-module). Each slice
adds the specimens and public components that its dependencies make possible, then deletes
the temporary Showcase scaffold it replaces. Phase 2.5 installs the final Flex-backed
SplitView geometry before styling and input; Grid, Table, NavigationSplitView, and
[final catalog integration](../docs/Spec.md#slice-7-catalog-integration--list-section-controlled-widgets-and-the-showcase)
retain their later dependency-ordered landings.

## Verification intent

When implementation begins, snapshot every tagged fixture here at its declared dimensions;
dispatch deterministic key, mouse, wheel, text-input, and resize scripts; and compare
rendered buffers with app bindings, documented ephemeral state, and local diagnostic
metadata. Prove that a selected inspector overlay comes from a completed immutable
snapshot, that ScrollIndicator geometry is shared by ScrollView/List/Table once each
consumer lands, that all compact roles are reachable through visible Buttons, and that
terminal requirements are requested by graph content but effective only by session
decision. Component contract tests remain in their linked catalog documents; Showcase
tests prove only their integration.
