---
kind: widget
status: ready
---

# ContentUnavailableView

`ContentUnavailableView` tells the user that a region has nothing to show. It draws an
icon, a bold title, a description, and optional actions, centred in the space it is given.
It fills its proposal and centres its content column in it as before; the column's width
is capped by [`.readableWidth()`](../primitives/readable-width.md), 72 cells by default,
not the old 40-column design width. The modifier is a maximum only: it does not fill or
centre anything itself (owner decisions, 2026-10-18). It covers three states: empty,
search with no results, and error. Loading is not a case: a loading region is a centred
[ProgressView](progress-view.md), as in SwiftUI (owner decision, omp2 review, 2026-10).
The app owns every string, icon, and action; the view stores nothing and is controlled.
See
[Slice 7](../../docs/Spec.md#slice-7-catalog-integration--list-section-and-controlled-widgets).

## Prior art

Cite concrete sources with paths or links, and say what to copy and what to reject.

- SwiftUI
  [`ContentUnavailableView`](https://developer.apple.com/documentation/swiftui/contentunavailableview)
  -- copy the shape: an icon, a bold title, a description, and optional actions, centred.
  Copy the built-in
  [`search(text:)`](<https://developer.apple.com/documentation/swiftui/contentunavailableview/search(text:)>)
  no-results view and its wording. Reject a loading case.
- omp2 `Loader`
  ([loader.rs](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/loader.rs#L20-L134))
  -- reject as a reference for this widget. Its bordered wait panel is a centred
  `ProgressView` instead (owner decision, omp2 review, 2026-10), so its spinner frames,
  clock and wake scheduling (keys K11, L1, L2, L3) belong to
  [ProgressView](progress-view.md). Apps that want an omp2-style wait panel compose their
  own view.
- omp2 `Select` filter flow
  ([select.rs](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/select.rs#L464-L486))
  -- the empty filter result is one of the empty states this view covers. Copy the single
  view for empty states rather than a per-widget line of text (owner decision, omp2
  review, 2026-10). The filtering itself is not 1.0 (keys C7, M2): an app that filters its
  own data shows `ContentUnavailableView.search(text:)` when nothing matches.

## API direction

SwiftUI's shape, with the icon named from the [icon catalog](../tokens.md#icon-catalog)
instead of an SF Symbol (key K2). The title is a `String` and the description and actions
are named `@ViewBuilder` slots (keys B11, A7); the actions are Buttons with their own
closures (key C2). Every value is app-owned and redeclared on every update (key D2). Plan
032 step 16.2 settles the Swift spellings.

```swift
ContentUnavailableView("No messages", icon: "mail") {
    Text("Messages from your team appear here.")
} actions: {
    Button("New Message") { compose() }
}

// The built-in no-results view: the framework's title and description, no icon under
// .unicode, and no actions.
ContentUnavailableView.search(text: "deploy")
```

SwiftUI takes the title and icon as a `Label` builder and stacks them with a label style.
Tessera's [Label](../primitives/label.md) is a one-row icon and title pair with no label
styles, so the view takes the title and the icon name and stacks them itself. The first
action is `.filled` as the default action and the others are `.tinted` (owner decision,
2026-10-10). The icon takes `secondary`, except that a tone icon (`warning`, `error`,
`success`, `info`) keeps its catalog role (inferred from the Empty and Error states).
There is no loading case (owner decision, omp2 review, 2026-10): a loading region is a
centred [ProgressView](progress-view.md).

## Anatomy

One wireframe at a natural component size, followed by callouts. Callout region names are
the vocabulary for the mouse table. Schemas and conventions:
[README](../README.md#wireframe-conventions).

The empty state is shown because it uses every region. The 40-column frame is the mobile
width, where the column is the whole proposal; the mobile state at natural height is under
States. Title and description are content and wrap; the icon and the action Buttons are
chrome and stay on one row.

### Empty

```wireframe 40x12
┌──────────────────────────────────────┐
│                                      │
│                                      │
│                  ✉                   │
│                                      │
│             No messages              │
│ Messages from your team appear here. │
│                                      │
│            ▐New Message▌             │
│                                      │
│                                      │
└──────────────────────────────────────┘
```

```text
Callouts (40x12, 0-based):
1. r0-r11 c0-c39   Viewport -- the 40-column design frame, outside the view; styled `border`
2. r3-r8 c2-c37    Content stack -- VStack in the readable column (the whole 40 columns here), centred horizontally and vertically in the proposal
3. r3 c19          Icon -- `Label` icon `mail` from the [icon catalog](../tokens.md#icon-catalog); styled `secondary`; chrome, one row
4. r5 c14-c24      Title -- Text, `primary` bold; content, wraps
5. r6 c2-c37       Description -- Text, `secondary`; content, wraps, each line centred
6. r8 c13-c25      Action -- Button ([button.md](button.md)); chrome, one row; the first action is `.filled`
                   as the default action (`accent` fill, `contrast` text, bold)
```

Colour and weight matter here, so the styled grid follows. Roles `secondary`, `contrast`
and `border` are defined in [tokens.md](../tokens.md#roles).

```text
── chars ──
┌──────────────────────────────────────┐
│                                      │
│                                      │
│                  ✉                   │
│                                      │
│             No messages              │
│ Messages from your team appear here. │
│                                      │
│            ▐New Message▌             │
│                                      │
│                                      │
└──────────────────────────────────────┘
── style ──
RRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRR
R......................................R
R......................................R
R..................I...................R
R......................................R
R.............TTTTTTTTTTT..............R
R.DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD.R
R......................................R
R............PpppppppppppP.............R
R......................................R
R......................................R
RRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRR
── legend ──
.  default
I  fg=secondary
T  fg=primary bold
D  fg=secondary
p  fg=contrast bg=accent bold
P  fg=accent
R  fg=border
```

## States

Required to reach `wireframed`: `mobile` (40 columns at natural height) and `min` (the
13x3 floor). Recommended: empty, focused vs unfocused, overflow, degraded
(ascii/no-color).

The owner's first set assumed a loading reason for every unavailable state. The three
states below are the ones that replaced it (owner decision, omp2 review, 2026-10).

### Search

`ContentUnavailableView.search(text: "deploy")`, the built-in no-results view. The title
and description are the framework's wording, as in SwiftUI. There are no actions.

Under `.unicode` the `search` icon has no glyph
([icon catalog](../tokens.md#icon-catalog); owner decision, 2026-10-19). The icon row and
the gap row under it collapse, and the shorter stack recentres, as
[Label](../primitives/label.md) draws a glyphless icon as no icon and no gap (owner
decision, 2026-10-19). Under `.nerdFont` and `.ascii` (`[/]`) the icon row draws, as in
the Empty state.

```wireframe 40x12
┌──────────────────────────────────────┐
│                                      │
│                                      │
│                                      │
│       No results for "deploy"        │
│     Check the spelling or try a      │
│             new search.              │
│                                      │
│                                      │
│                                      │
│                                      │
└──────────────────────────────────────┘
```

```text
Callouts (40x12, 0-based):
1. r4-r6 c6-c32    Content stack -- title and description only; the glyphless icon row and its gap collapse, and the stack recentres
2. r4 c8-c30       Title -- Text, `primary` bold; framework wording; content, wraps
3. r5-r6 c6-c32    Description -- Text, `secondary`; content, wraps; two centred lines
```

```text
── chars ──
┌──────────────────────────────────────┐
│                                      │
│                                      │
│                                      │
│       No results for "deploy"        │
│     Check the spelling or try a      │
│             new search.              │
│                                      │
│                                      │
│                                      │
│                                      │
└──────────────────────────────────────┘
── style ──
RRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRR
R......................................R
R......................................R
R......................................R
R.......TTTTTTTTTTTTTTTTTTTTTTT........R
R.....DDDDDDDDDDDDDDDDDDDDDDDDDDD......R
R.............DDDDDDDDDDD..............R
R......................................R
R......................................R
R......................................R
R......................................R
RRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRR
── legend ──
.  default
T  fg=primary bold
D  fg=secondary
R  fg=border
```

### Error

An unavailable state with two actions and a warning-toned icon.

```wireframe 40x12
┌──────────────────────────────────────┐
│                                      │
│                  ⚠                   │
│                                      │
│        Can't reach the server        │
│   Changes are saved here and sent    │
│     when the connection returns.     │
│                                      │
│         ▐Retry▌  ▐Settings▌          │
│                                      │
│                                      │
└──────────────────────────────────────┘
```

```text
Callouts (40x12, 0-based):
1. r2 c19          Icon -- `warning` icon, `warning` tone; chrome, one row
2. r4 c9-c30       Title -- Text, `primary` bold; content, wraps
3. r5-r6 c4-c34    Description -- Text, `secondary`; content, wraps; two centred lines
4. r8 c10-c16      Action -- Button, first action, `.filled` as the default action; chrome, one row
5. r8 c19-c28      Action -- Button, second action, `.tinted`; chrome, one row
```

```text
── chars ──
┌──────────────────────────────────────┐
│                                      │
│                  ⚠                   │
│                                      │
│        Can't reach the server        │
│   Changes are saved here and sent    │
│     when the connection returns.     │
│                                      │
│         ▐Retry▌  ▐Settings▌          │
│                                      │
│                                      │
└──────────────────────────────────────┘
── style ──
RRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRR
R......................................R
R..................W...................R
R......................................R
R........TTTTTTTTTTTTTTTTTTTTTT........R
R...DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD....R
R.....DDDDDDDDDDDDDDDDDDDDDDDDDDDD.....R
R......................................R
R.........PpppppP..VvvvvvvvvV..........R
R......................................R
R......................................R
RRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRR
── legend ──
.  default
T  fg=primary bold
D  fg=secondary
v  fg=accent bg=faint(accent) -- `.tinted` label on its fill
V  fg=faint(accent) -- `.tinted` caps
p  fg=contrast bg=accent bold
P  fg=accent
W  fg=warning
R  fg=border
```

### Mobile (40 columns)

The 40-column states above are the design width. The mobile state is the empty content at
40 columns and natural height: six rows, with no blank rows above or below, since
components are wireframed at their natural height (owner decision, 2026-10-10). The
viewport outline is not drawn.

```wireframe 40x6
                   ✉

              No messages
  Messages from your team appear here.

             ▐New Message▌
```

```text
Callouts (40x6, 0-based):
1. r0 c19           Icon -- `mail` icon, styled `secondary`; chrome, one row
2. r2 c14-c24       Title -- Text, `primary` bold; content, wraps
3. r3 c2-c37        Description -- Text, `secondary`; content, wraps
4. r5 c13-c25       Action -- Button, `.filled` as the default action; chrome, one row
5. r0-r5 c0-c39     Content stack -- VStack at natural height; no rows added
```

### Narrow (24 columns)

At 24 columns and a nil height the description wraps to the column width less one-cell
margins (22 cells) and the stack grows by a row; nothing is truncated (owner decision,
2026-10-18).

```wireframe 24x7
           ✉

      No messages
   Messages from your
   team appear here.

     ▐New Message▌
```

```text
Callouts (24x7, 0-based):
1. r0 c11          Icon -- `mail` icon, styled `secondary`; chrome, one row
2. r2 c6-c16       Title -- Text, `primary` bold; content, wraps
3. r3-r4 c3-c20    Description -- Text, `secondary`; content, wraps; each line centred
4. r6 c5-c17       Action -- Button, `.filled` as the default action; chrome, one row
```

### Min (13x3)

The floor is 13x3 (owner decision, 2026-10-10), re-derived under the wrap rules (owner
decision, 2026-10-18): the first action is the widest atomic run, a 13-cell Button (label
`New Message` plus caps, chrome that never wraps), and the title's widest word,
`messages`, is 8, so 13 is unchanged. At 3 rows the title and the first action keep their
rows. Under a fixed row budget the description gives up rows first (its last visible row
ends in `…`; zero rows means absent), then the icon, then actions after the first. The
viewport frame is omitted here so the content gets the full floor.

Styling follows the grid below.

```wireframe 13x3
 No messages

▐New Message▌
```

```text
Callouts (13x3, 0-based):
1. r0 c1-c11       Title -- Text, `primary` bold; content, wraps; the icon and description are dropped
2. r2 c0-c12       Action -- Button, `.filled` as the default action; chrome, one row; the only action shown
```

```text
── chars ──
 No messages

▐New Message▌
── style ──
.TTTTTTTTTTT.
.............
PpppppppppppP
── legend ──
.  default
T  fg=primary bold
p  fg=contrast bg=accent bold
P  fg=accent
```

## State model

Schema: [README](../README.md#state-model-table). Every `Binding` row is app-owned display
data, a plain initializer parameter redeclared on every update (key D2). The view stores
nothing: it has no `NodeState` row and no responder of its own.

| State          | Owner       | Type                   | Reset or clamp rule                                                                                            |
| -------------- | ----------- | ---------------------- | -------------------------------------------------------------------------------------------------------------- |
| title          | Binding     | `String`               | app-owned display data, redeclared on every update (key D2); `.search(text:)` supplies the framework's wording |
| icon           | Binding     | `IconName?`            | app-owned (key D2); nil, or a name with no glyph in the active charset, collapses the icon row and its gap     |
| description    | Binding     | `@ViewBuilder` content | app content, redeclared on every update; wraps, each line centred                                              |
| actions        | Binding     | `@ViewBuilder` Buttons | app content; each Button owns its own action and focus (key C2)                                                |
| readable width | Environment | cells                  | caps the content column; 72 by default                                                                         |

## Key table

Schema: [README](../README.md#key-table). None. The view owns no keys; its actions are
Buttons with their own key tables ([Button](button.md#key-table)).

## Mouse table

Schema: [README](../README.md#mouse-table). None. The view owns no pointer regions; the
action Buttons handle activation ([Button](button.md#mouse-table)).

## Sizing

Schema: [README](../README.md#sizing-table). Mandatory rows: nil x nil, tight,
under-minimum, over-maximum. The view fills a finite proposal and centres its content
column in it; the column is `min(width, readableWidth)` cells wide, since
`.readableWidth()` is a maximum only (owner decisions, 2026-10-18).

| Proposal              | Result | Rule                                                                                                                                                                                                                                                                                |
| --------------------- | ------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| nil x nil             | 36x6   | Empty state. A nil width proposes the 72-cell readable width to the column; width is the widest row (the description, 36), and height is every row: icon, gap, title, description, gap, actions.                                                                                    |
| 40x12 (tight)         | 40x12  | Empty anatomy, as drawn: content centred in the proposal; the column is the whole 40 columns and the description wraps to the width less one-cell margins.                                                                                                                          |
| 40 x nil (mobile)     | 40x6   | Empty state: the content stack at natural height; no blank rows above or below.                                                                                                                                                                                                     |
| 24 x nil              | 24x7   | Empty state: the description wraps to 22 cells and takes two rows; nothing is truncated (Narrow).                                                                                                                                                                                   |
| 12x2 (under-minimum)  | 12x2   | Floor re-derived in Min (owner decisions, 2026-10-10 and 2026-10-18). Nothing clips silently: the title wraps, the Button follows its own one-row truncate rule, and the two rows go to the title and the first action; the description, icon and later actions give up rows first. |
| 100x30 (over-maximum) | 100x30 | The view fills the proposal: the content column is capped at 72 cells, the view's own centring places it at c14-c85 with the content centred vertically, and the description wraps to 70 cells (owner decision, 2026-10-18).                                                        |

## Environment

Tokens consumed, each defined in [tokens.md](../tokens.md).

- `primary`: title (bold).
- `secondary`: description.
- `accent` fill with `contrast` text (`solid(accent)`,
  [composite styles](../tokens.md#composite-styles)): the `.filled` default action.
- `secondary`: the icon, except that a tone icon keeps its catalog role (see API
  direction).
- `warning`: the warning icon in the error state, its catalog role
  ([icon catalog](../tokens.md#icon-catalog)).
- `.tinted` action (the other actions): label in `accent` with a faint fill derived from
  it (owner decision, 2026-10-10; [Button emphasis](button.md#emphasis)).
- `border`: viewport outline and the grid frame.
- `readableWidth` (environment): caps the content column's width (maximum only), default
  72; see [Readable width](../primitives/readable-width.md).

## Primitive dependencies

- [Text](../primitives/text.md): title and description.
- [Button](button.md): actions.
- [Stacks](../primitives/stacks.md): the centred vertical content stack.
- [Frame](../primitives/frame.md): centring within the proposal.
- [Readable width](../primitives/readable-width.md): `.readableWidth()` caps the content
  column's width; the environment value `readableWidth` (default 72) is read here.
- [Label](../primitives/label.md): the icon, named from the
  [icon catalog](../tokens.md#icon-catalog).

## Requirements

Backticked sentence-style test names, each traced to a table row or wireframe state.
Schema: [README](../README.md#requirements-list).

- `empty state centres the icon, title, description, and actions in the proposal`
  (Anatomy: Empty; Sizing)
- `first action is filled as the default action; other actions are tinted` (Anatomy:
  Empty; Error; owner decision, 2026-10-10)
- `search state shows the framework no-results title and description` (States: Search)
- `error state draws a warning-toned icon above two actions` (States: Error)
- `description wraps to the width less one-cell margins and stays centred` (Sizing: tight;
  Narrow)
- `content column is capped at the readable width and the view centres it when the proposal is wider`
  (Sizing: over-maximum; owner decision, 2026-10-18)
- `view fills a finite proposal` (Sizing: over-maximum; owner decision, 2026-10-18)
- `mobile state draws the content at 40 columns and natural height, with no blank rows`
  (States: Mobile)
- `under the 13x3 floor the title wraps and the description, icon, then later actions give up rows first`
  (States: Min; Sizing; owner decision, 2026-10-18)
- `icons render their ASCII text forms when the icon catalog is ASCII` (Degradation)
- `search state collapses the glyphless icon row and its gap under the unicode charset`
  (States: Search; state model: icon; Label precedent, owner decision, 2026-10-19)
- `search state draws the search icon row under the ascii and nerd font charsets` (States:
  Search; Degradation)

## Degradation

What changes at `NO_COLOR`, 16-color, ascii-only, and below `min`. Reference the
[degradation ladder](../tokens.md#degradation-ladder).

- ASCII: icons render their text forms on the icon row, centred: `[@]` for `mail`, `[/]`
  for `search` and `[!]` for `warning` ([icon catalog](../tokens.md#icon-catalog); owner
  decision, omp2 review, 2026-10). Button caps follow
  [Button degradation](button.md#degradation). The border follows the `ascii` border set.
- `NO_COLOR` and 16-color: the filled action keeps bold and loses the accent fill, and the
  warning icon loses its tone; both follow the ladder's colour rows.
- Below the 13x3 floor: the title wraps (breaking between graphemes under 8 cells), the
  Button keeps its own one-row truncation, and under a fixed height the description gives
  up rows first, then the icon, then actions after the first (owner decisions, 2026-10-10
  and 2026-10-18).

This design was reviewed against the
[Phase 4 theses](../../docs/Spec.md#phase-4--view-layer-the-tessera-module): every string,
icon and action is an app-owned value redeclared on every update; the view stores nothing,
owns no keys or pointer regions, and leaves activation to its Buttons; and the centred
column is deterministic integer-cell layout through stacks, Frame and the readable-width
cap.

## Open questions

- **Swift spellings (deferred to plan 032 step 16.2).** The initializer in API direction
  is a sketch: its parameter names and the `.search(text:)` spelling are settled when the
  view is built.

## Inspiration

Triage destination for inbox entries about this component.
