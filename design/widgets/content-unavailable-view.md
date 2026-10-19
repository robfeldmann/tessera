---
kind: widget
status: wireframed
---

# ContentUnavailableView

`ContentUnavailableView` tells the user that a region has nothing to show. It draws an
icon, a bold title, a description, and optional actions, centred in the space it is given.
It covers three states: empty, search with no results, and error. Loading is not a case: a
loading region is a centred [ProgressView](progress-view.md), as in SwiftUI (owner
decision, omp2 review, 2026-10). The app owns every string, icon, and action; the view
stores nothing and is controlled. See
[Slice 7](../../docs/Spec.md#slice-7-catalog-integration--list-section-controlled-widgets-and-the-showcase).

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
  `ProgressView` instead (owner decision, omp2 review, 2026-10). Apps that want an
  omp2-style wait panel compose their own view.
- omp2 `Select` filter flow
  ([select.rs](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/select.rs#L464-L486))
  -- the empty filter result is one of the empty states this view covers. Copy the single
  view for empty states rather than a per-widget line of text (owner decision, omp2
  review, 2026-10).

## Anatomy

One wireframe at a natural component size, followed by callouts. Callout region names are
the vocabulary for the mouse table. Schemas and conventions:
[README](../README.md#wireframe-conventions).

The empty state is shown because it uses every region. The 40-column design width is the
mobile width; the mobile state at natural height is under States.

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
2. r3-r8 c2-c37    Content stack -- VStack, centred horizontally and vertically in the proposal
3. r3 c19          Icon -- `Label` icon from the semantic icon catalog (`mail`); styled `muted`
4. r5 c14-c24      Title -- Text, `semantic.primary` bold
5. r6 c2-c37       Description -- Text, `semantic.secondary`; wraps, each line centred
6. r8 c13-c25      Action -- Button ([button.md](button.md)); the first action is `.filled`
                   as the default action (`accent` fill, `contrast` text, bold)
```

Colour and weight matter here, so the styled grid follows. Roles `muted`, `contrast`, and
`border` have no token yet (token pending plan 032 step 5.3).

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
I  fg=muted
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

```wireframe 40x12
┌──────────────────────────────────────┐
│                                      │
│                                      │
│                  🔍                  │
│                                      │
│       No results for "deploy"        │
│     Check the spelling or try a      │
│             new search.              │
│                                      │
│                                      │
│                                      │
└──────────────────────────────────────┘
```

```text
Callouts (40x12, 0-based):
1. r3 c19-c20      Icon -- `search` icon, two cells wide (emoji); styled `muted`
2. r5 c8-c30       Title -- Text, `semantic.primary` bold; framework wording
3. r6-r7 c6-c32    Description -- Text, `semantic.secondary`; two centred lines
```

```text
── chars ──
┌──────────────────────────────────────┐
│                                      │
│                                      │
│                  🔍                  │
│                                      │
│       No results for "deploy"        │
│     Check the spelling or try a      │
│             new search.              │
│                                      │
│                                      │
│                                      │
└──────────────────────────────────────┘
── style ──
RRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRR
R......................................R
R......................................R
R..................II..................R
R......................................R
R.......TTTTTTTTTTTTTTTTTTTTTTT........R
R.....DDDDDDDDDDDDDDDDDDDDDDDDDDD......R
R.............DDDDDDDDDDD..............R
R......................................R
R......................................R
R......................................R
RRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRR
── legend ──
.  default
I  fg=muted
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
1. r2 c19          Icon -- `warning` icon, `warning` tone
2. r4 c9-c30       Title -- Text, `semantic.primary` bold
3. r5-r6 c4-c34    Description -- Text, `semantic.secondary`; two centred lines
4. r8 c10-c16      Action -- Button, first action, `.filled` as the default action
5. r8 c19-c28      Action -- Button, second action, `.tinted`
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
v  tinted fill (`.tinted`)
V  fg=accent (`.tinted` label)
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
1. r0 c19           Icon -- `mail` icon, styled `muted`
2. r2 c14-c24       Title -- Text, `semantic.primary` bold
3. r3 c2-c37        Description -- Text, `semantic.secondary`
4. r5 c13-c25       Action -- Button, `.filled` as the default action
5. r0-r5 c0-c39     Content stack -- VStack at natural height; no rows added
```

### Min (13x3)

The floor is 13x3 (owner decision, 2026-10-10). Under it the title truncates first, then
the description drops, then actions after the first. The viewport frame is omitted here so
the content gets the full floor, and the icon is not drawn at the floor.

Styling follows the grid below.

```wireframe 13x3
 No messages

▐New Message▌
```

```text
Callouts (13x3, 0-based):
1. r0 c1-c11       Title -- Text, `semantic.primary` bold; the icon and description are dropped
2. r2 c0-c12       Action -- Button, `.filled` as the default action; the only action shown
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

Schema: [README](../README.md#state-model-table).

| State                                       | Owner | Type                                   | Reset or clamp rule                                  |
| ------------------------------------------- | ----- | -------------------------------------- | ---------------------------------------------------- |
| Content (title, icon, description, actions) | app   | `ContentUnavailableView` configuration | stateless; recomputed on each layout, nothing stored |

## Key table

Schema: [README](../README.md#key-table).

| Key    | Precondition | Effect                                                              | Consumed |
| ------ | ------------ | ------------------------------------------------------------------- | -------- |
| (none) | --           | The view owns no keys; actions are Buttons ([button.md](button.md)) | --       |

## Mouse table

Schema: [README](../README.md#mouse-table). Regions must be named in Anatomy callouts.

| Event  | Region | Precondition | Effect                                                                 | Consumed |
| ------ | ------ | ------------ | ---------------------------------------------------------------------- | -------- |
| (none) | --     | --           | The view owns no pointer regions; the action Buttons handle activation | --       |

## Sizing

Schema: [README](../README.md#sizing-table). Mandatory rows: nil x nil, tight,
under-minimum, over-maximum.

| Proposal                              | Result                         | Rule                                                                                                                                                         |
| ------------------------------------- | ------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| nil x nil                             | 36 x 6 (empty)                 | Width is the widest unwrapped line (the description). Height is the stacked rows: icon, gap, title, description, gap, actions.                               |
| 40x12 (tight)                         | empty anatomy, as drawn        | Content centred in the proposal; the description wraps to the width less one-cell margins.                                                                   |
| 40 x any (mobile)                     | 40 x 6 (empty, natural height) | Content stack at natural height; no blank rows above or below.                                                                                               |
| under 13x3 (under-minimum)            | 12 x 2 (clipped)               | Owner decision, 2026-10-10. The title truncates first, then the description drops (below 5 rows), then actions after the first; the proposal clips the rest. |
| larger than the design (over-maximum) | not decided                    | See open question 3.                                                                                                                                         |

## Environment

Tokens consumed, each defined in [tokens.md](../tokens.md).

- `semantic.primary`: title (bold).
- `semantic.secondary`: description.
- `semantic.accent` with `contrast` text: the `.filled` default action.
- `muted` (token pending plan 032 step 5.3): icon.
- `warning` (token pending plan 032 step 5.3): warning-toned icon in the error state.
- `.tinted` action (the other actions): label in `accent` with a faint fill derived from
  it (owner decision, 2026-10-10; [Button emphasis](button.md#emphasis)).
- `border` (token pending plan 032 step 5.3): viewport outline and the grid frame.

## Primitive dependencies

- [Text](../primitives/text.md): title and description.
- [Button](button.md): actions.
- [Stacks](../primitives/stacks.md): the centred vertical content stack.
- [Frame](../primitives/frame.md): centring within the proposal.
- [Label](../primitives/label.md): the icon, from its semantic icon catalog. Label owns
  the catalog (owner decision, 2026-10-10).

## Requirements

Backticked sentence-style test names, each traced to a table row or wireframe state.
Schema: [README](../README.md#requirements-list).

- `empty state centres the icon, title, description, and actions in the proposal`
  (Anatomy: Empty; Sizing)
- `first action is filled as the default action; other actions are tinted` (Anatomy:
  Empty; Error; owner decision, 2026-10-10)
- `search state shows the framework no-results title and description` (States: Search)
- `error state draws a warning-toned icon above two actions` (States: Error)
- `description wraps to the width less one-cell margins and stays centred` (Sizing: tight)
- `mobile state draws the content at 40 columns and natural height, with no blank rows`
  (States: Mobile)
- `under the 13x3 floor the title truncates first, then the description drops, then actions after the first`
  (States: Min; Sizing)
- `icons render their ASCII text forms when the icon catalog is ASCII` (Degradation)
- `loading is not a content-unavailable case; it renders a centred ProgressView` (Prior
  art; owner decision)

## Degradation

What changes at `NO_COLOR`, 16-color, ascii-only, and below `min`. Reference the
[degradation ladder](../tokens.md#degradation-ladder).

- ASCII: icons render their text forms on the icon row, centred: `mail`, `[/]`, and `[!]`
  (owner decision, omp2 review, 2026-10). Button caps follow
  [Button degradation](button.md#degradation). The border follows the `ascii` border set.
- `NO_COLOR` and 16-color: the filled action keeps bold and loses the accent fill, and the
  warning icon loses its tone; both follow the ladder's colour rows.
- Below the 13x3 floor: the title truncates first, then the description drops, then
  actions after the first (owner decision, 2026-10-10).

## Open questions

Decisions deliberately not made yet, each with what unblocks it.

1. Icon catalog rows: `mail` and `search` are not in the
   [Label icon catalog](../primitives/label.md#icon-catalog), and their ASCII forms are
   not decided. The Degradation `[/]` text waits on the same row. Label owns the catalog
   (owner decision, 2026-10-10). Unblocked by adding the rows to Label.
2. Tokens: `muted`, `contrast`, `warning`, and `border` are not in
   [tokens.md](../tokens.md). Unblocked by plan 032 step 5.3. The doc stays `wireframed`
   until then.
3. Over-maximum: the owner gave no rule for proposals larger than the design width.
   Unblocked by the owner.

## Inspiration

Triage destination for inbox entries about this component.
