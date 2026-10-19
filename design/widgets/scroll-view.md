---
kind: widget
status: specified
---

# ScrollView

`ScrollView` is a viewport widget: it exposes a translated, clipped window onto one child
in `.vertical`, `.horizontal`, or both axes. The app owns content and any supplied
`TerminalPosition` offset binding. It is deliberately a cell viewport, not a physics
simulation: every accepted keyboard input changes an integer offset immediately, and it
offers neither zoom nor smooth animation.

The implemented initializer is:

```swift
public init(
    _ axes: Axis.Set = .vertical,
    offset: Binding<TerminalPosition>? = nil,
    @ViewBuilder content: () -> Content
)

func focusable(whileScrollable id: FocusID) -> ScrollView
```

A `ScrollView` becomes keyboard-focusable in one of two ways. Preferred: supply an offset
and mark it `focusable(whileScrollable:)`; the viewport then registers itself as focusable
only while its content actually overflows on an enabled axis, so focus traversal never
stops on a viewport with nothing to scroll, and it drops out of the focus order again when
a resize or content change makes everything fit:

```swift
ScrollView(.vertical, offset: offset) { content }
    .focusable(whileScrollable: scrollFocusID)
```

Alternatively, compose an explicit external identity, which registers unconditionally:

```swift
ScrollView(.vertical, offset: offset) { content }
    .focusable(scrollFocusID)
    .focused(focused, equals: scrollFocusID)
```

The offset binding is both the app's programmatic-scroll input and the recipient of
keyboard scroll changes. ScrollView renders from `EnvironmentValues.isFocused` or its own
focus identity, and handles keys when `ResponderContext.isFocused` is true or when focus
lives inside its subtree (`ResponderContext.isFocusWithin`), so keys a focused descendant
declines scroll the nearest able enclosing viewport. An owned
`focusable(whileScrollable:)` identity additionally requires the offset binding and
registers or withdraws as soon as a layout pass settles. Its effective enabled state gates
all of this, so a disabled viewport paints no focus chrome and does not consume scroll
keys. Disabled-axis components render and behave as zero. A binding value outside the
newly measured range is effectively clamped for layout and rendering, but passive
reconciliation does not write a corrective value into app state; the next user scroll
begins from that effective value.

> Deferred: An uncontrolled fallback scroll position and mouse, wheel, or drag scrolling
> land in a later slice.

## Prior art

- Ratatui scrollbar:
  `https://github.com/ratatui/ratatui/blob/main/ratatui-widgets/src/scrollbar.rs` -- copy
  its distinct vertical/horizontal orientations and thumb geometry derived from content
  length, viewport length, and position. Reject its separately constructed, caller-owned
  `ScrollbarState` and endpoint arrows. Tessera derives indicator state from the viewport
  and reads glyphs from the catalog. Tessera's look is one curated `ScrollIndicatorStyle`
  preset, fixing each thumb and track pair, which reverses the earlier rejection of
  configurable styles (owner decision, omp2 review, 2026-10; presets owner decision,
  2026-10-10; see [ScrollIndicator](../primitives/scroll-indicator.md#decisions)).
- Ratatui paragraph:
  `https://github.com/ratatui/ratatui/blob/main/ratatui-widgets/src/paragraph.rs` -- copy
  the two-dimensional offset concept and the discipline of rendering only into the
  intersected area (its `scroll((y, x))` is intentionally reversed from Tessera's
  `TerminalPosition(x:y:)`). Reject paragraph-specific post-wrap scrolling: ScrollView
  moves arbitrary already-laid-out content before clipping, so it must not reflow or
  reinterpret the child.
- Ratatui list state:
  `https://github.com/ratatui/ratatui/blob/main/ratatui-widgets/src/list/state.rs` -- copy
  the visible-offset invariant and saturating boundary behavior. Reject coupling offset to
  a selected row and the hand-managed state object; ScrollView has neither a selection nor
  business state.
- Apple
  [SwiftUI `ScrollView`](https://developer.apple.com/documentation/swiftui/scrollview)
  (verified 2026-07-12) -- copy `Axis.Set` vocabulary, horizontal/vertical/both coverage,
  programmatic-position intent, and the explicit absence of zoom. Reject temporary,
  gesture-timed indicators and `ScrollViewReader`: terminal indicators remain stable while
  overflow exists, and the optional position binding is the single programmatic mechanism.

## Anatomy

Natural fixture: both axes overflow. The proposed frame is `52x12`, content's ideal extent
is `64x24`, and effective offset is `(12, 8)`. The content viewport is `51x11`: the
vertical and horizontal indicator edges reserve one cell each. Its vertical thumb is five
cells (`max(1, floor(11 * 11 / 24))`) at r3-r7. The horizontal thumb is forty cells
(`max(1, floor(51 * 51 / 64))`) beginning at c10. The component has no border, title, or
padding of its own.

```wireframe 52x12
Here's to the crazy ones. The misfits. The rebels. │
The troublemakers. The round pegs in the square    │
holes. The ones who see things differently. They're│
not fond of rules. And they have no respect for the█
status quo. You can quote them, disagree with them,█
glorify or vilify them. About the only thing you   █
can't do is ignore them. Because they change       █
things. They push the human race forward. And while█
some may see them as the crazy ones, we see genius.│
Because the people who are crazy enough to think   │
they can change the world, are the ones who do.    │
──────────🬋🬋🬋🬋🬋🬋🬋🬋🬋🬋🬋🬋🬋🬋🬋🬋🬋🬋🬋🬋🬋🬋🬋🬋🬋🬋🬋🬋🬋🬋🬋🬋🬋🬋🬋🬋🬋🬋🬋🬋─│
```

```text
Callouts (52x12, 0-based):
0. r0-r10 c0-c50  Viewport content -- child `View` rendered through a translated, clipped
                   `RenderRegion`; this is the primary wheel and click region
1. r0-r10 c51     Vertical scroll indicator -- `█` thumb (`accent`) on a `│` track
                   (`muted`); five-cell thumb at r3-r7, present only for vertical overflow
2. r11 c0-c50     Horizontal scroll indicator -- `🬋` thumb (`accent`) on a `─` track
                   (`muted`); forty-cell thumb at c10-c49, present only for horizontal
                   overflow
3. r11 c51        Indicator corner -- reserved intersection of the two indicator edges; no
                   content and no independent action
```

Indicators have no endpoint arrows and do not change the child proposal. If only one axis
overflows, only its one-cell edge is reserved; if neither overflows, the child receives
the whole assigned rectangle. A fixed cross-axis proposal owns that reservation inside its
assigned extent. When the cross axis is unspecified, `ScrollView` includes the one-cell
edge in its natural size so an indicator never replaces the content's final row or column.
For each overflowing axis, with track length `T`, viewport extent `V`, content extent `C`,
and effective offset `O`, the thumb has `max(1, floor(T * V / C))` cells and starts at
`floor(O * (T - thumb) / max(1, C - V))`. The last formula puts the thumb exactly at the
trailing/bottom end when the position is maximum. An indicator is visible only when its
enabled axis overflows and the stabilized reservation leaves a content viewport at least
`1x1`; otherwise that edge is omitted.

## Indicator styles

The default look is omp2's vertical one: an accent `█` thumb on a muted `│` track. For
horizontal scrolling the thumb is `🬋`, a centred one-third bar on a `─` track, which is
thicker than omp2's `━` (owner decision, 2026-10-11). The look is one curated
`ScrollIndicatorStyle` preset, set with
`.scrollIndicatorStyle(_ style: ScrollIndicatorStyle)`; each preset fixes its thumb and
track together for both axes, so a mismatched pair cannot be written. Placement inside a
box's border is a separate opt-in modifier. The preset list (confirmed, owner decision,
2026-10-11) and its glyphs for both axes are in
[ScrollIndicator](../primitives/scroll-indicator.md#variants). All of them ship in 1.0
(owner decision, 2026-10-10).

### Standard

Six rows show the default `standard` preset: the thumb is three cells at r1-r3 and the
track is `muted`.

```wireframe 40x6
step 04 compile tui                    │
step 05 compile cli                    █
step 06 link binaries                  █
step 07 run unit tests                 █
step 08 run doc tests                  │
step 09 run lints                      │
```

```text
Callouts (40x6, 0-based):
0. r0-r5 c0-c38  Viewport content -- child rows translated and clipped; the same region as
                 Anatomy callout 0
1. r0, r4-r5 c39 Vertical track -- `muted` `│` (the `standard` track)
2. r1-r3 c39     Vertical thumb -- `accent` `█` (the `standard` thumb), three cells
```

```text
── chars ──
step 04 compile tui                    │
step 05 compile cli                    █
step 06 link binaries                  █
step 07 run unit tests                 █
step 08 run doc tests                  │
step 09 run lints                      │
── style ──
.......................................A
.......................................B
.......................................B
.......................................B
.......................................A
.......................................A
── legend ──
.  default
A  fg=muted
B  fg=accent
```

### Placement in a box border

When a ScrollView fills a bordered Box and `.scrollIndicatorPlacement(.border)` is set,
the thumb replaces part of the box's right border instead of taking a column of its own,
as lazygit does. The border line is the track, so the preset's track glyph does not paint
and no cell is reserved. The placement applies only when the ScrollView's nearest ancestor
is a bordered Box; otherwise the default placement from Anatomy applies. Owner decision,
omp2 review, 2026-10. Each box names its preset in its title and shows the thumb in the
top band at rows 2-4 and in the bottom band at rows 10-12.

```wireframe 40x16
┌─ standard ───────┐┌─ thin ───────────┐
│ 04 compile tui   ││ 04 compile tui   │
│ 05 compile cli   █│ 05 compile cli   ┃
│ 06 link binaries █│ 06 link binaries ┃
│ 07 run unit test █│ 07 run unit test ┃
│ 08 run doc tests ││ 08 run doc tests │
│ 09 run lints     ││ 09 run lints     │
└──────────────────┘└──────────────────┘
┌─ outer ──────────┐┌─ inner ──────────┐
│ 04 compile tui   ││ 04 compile tui   │
│ 05 compile cli   ▐│ 05 compile cli   ▌
│ 06 link binaries ▐│ 06 link binaries ▌
│ 07 run unit test ▐│ 07 run unit test ▌
│ 08 run doc tests ││ 08 run doc tests │
│ 09 run lints     ││ 09 run lints     │
└──────────────────┘└──────────────────┘
```

```text
Callouts (40x16, 0-based):
0. r0-r7 c0-c19    Bordered Box `standard` -- title in the top border (`secondary` bold); the
                   ScrollView fills the interior r1-r6 c1-c18
1. r0-r7 c20-c39   Bordered Box `thin` -- same placement
2. r8-r15 c0-c19   Bordered Box `outer` -- same placement
3. r8-r15 c20-c39  Bordered Box `inner` -- same placement
4. r2-r4 c19       Thumb `accent` `█` replacing part of the right border; the `border` role
                   keeps the rest of the column
5. r2-r4 c39       Thumb `accent` `┃` (`thin`)
6. r10-r12 c19     Thumb `accent` `▐` (`outer`)
7. r10-r12 c39    Thumb `accent` `▌` (`inner`)
```

```text
── chars ──
┌─ standard ───────┐┌─ thin ───────────┐
│ 04 compile tui   ││ 04 compile tui   │
│ 05 compile cli   █│ 05 compile cli   ┃
│ 06 link binaries █│ 06 link binaries ┃
│ 07 run unit test █│ 07 run unit test ┃
│ 08 run doc tests ││ 08 run doc tests │
│ 09 run lints     ││ 09 run lints     │
└──────────────────┘└──────────────────┘
┌─ outer ──────────┐┌─ inner ──────────┐
│ 04 compile tui   ││ 04 compile tui   │
│ 05 compile cli   ▐│ 05 compile cli   ▌
│ 06 link binaries ▐│ 06 link binaries ▌
│ 07 run unit test ▐│ 07 run unit test ▌
│ 08 run doc tests ││ 08 run doc tests │
│ 09 run lints     ││ 09 run lints     │
└──────────────────┘└──────────────────┘
── style ──
RRHHHHHHHHHRRRRRRRRRRRHHHHHHRRRRRRRRRRRR
R..................RR..................R
R..................BR..................B
R..................BR..................B
R..................BR..................B
R..................RR..................R
R..................RR..................R
RRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRR
RRHHHHHHHRRRRRRRRRRRRRHHHHHHHRRRRRRRRRRR
R..................RR..................R
R..................BR..................B
R..................BR..................B
R..................BR..................B
R..................RR..................R
R..................RR..................R
RRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRR
── legend ──
.  default
B  fg=accent
H  fg=secondary bold
R  fg=border
```

## States

> Deferred: Keyboard-interaction claims in the following fixtures apply only when callers
> compose explicit focus modifiers. Mouse, wheel, and drag interaction remain deferred.

### Mobile

Mobile is the required `40x16` fixture. It is vertical-only with content `39x24`,
effective offset `(0, 8)`, and `T = 16`, `V = 16`, `C = 24`, `O = 8`. Its proportional
thumb is `max(1, floor(16 * 16 / 24)) = 10` cells; at the maximum offset it starts at
`floor(8 * (16 - 10) / (24 - 16)) = 6`, occupying r6-r15. The width remains useful for
prose because ScrollView does not add a border or inset.

```wireframe 40x16
Here's to the crazy ones. The misfits. │
The rebels. The troublemakers. The     │
round pegs in the square holes. The    │
ones who see things differently.       │
They're not fond of rules. And they    │
have no respect for the status quo. You│
can quote them, disagree with them,    █
glorify or vilify them. About the only █
thing you can't do is ignore them.     █
Because they change things. They push  █
the human race forward. And while some █
may see them as the crazy ones, we see █
genius. Because the people who are     █
crazy enough to think they can change  █
the world, are the ones who do.        █
                                       █
```

```text
Callouts (40x16, 0-based):
0. r0-r15 c0-c38  Viewport content -- translated child cells; the same region as Anatomy callout 0
1. r0-r15 c39     Vertical scroll indicator -- mobile trailing edge; `accent` `█` thumb,
                   ten cells at r6-r15, on a `muted` `│` track
```

### Declared minimum

`12x4` is the declared floor. At the floor, useful content remains eleven cells wide after
the trailing indicator; the widget still clips and scrolls. There is no title, padding, or
status text to sacrifice. The short thumb is intentionally still one cell rather than
disappearing.

```wireframe 12x4
Here's to  │
the crazy  █
ones. The  │
misfits.   │
```

```text
Callouts (12x4, 0-based):
0. r0-r3 c0-c10  Viewport content -- clipped child cells, tail clipping is the child's concern
1. r0-r3 c11     Vertical scroll indicator -- one-cell minimum `accent` `█` thumb at r1
```

Below `12x4`, ScrollView takes the assigned non-negative rectangle and continues clipping.
Each indicator is omitted whenever its overflowing-axis reservation would leave the
content viewport narrower or shorter than one cell; visible indicator reservations
therefore always leave at least one content cell on both axes. It never creates a negative
proposal or a layout failure.

### Horizontal only

Horizontal scrolling reserves only a bottom edge. The fixture is `52x6`, content is
`80x5`, and effective offset is `(18, 0)`; vertical movement is disabled and always
remains zero. The fence shows columns 18-69 of the 80-wide content, so lines enter and
exit mid-word -- that is the translation, not a typo.

```wireframe 52x6
y ones. The misfits. The rebels. The troublemakers.
 holes. The ones who see things differently. They're
 have no respect for the status quo. You can quote t
, glorify or vilify them. About the only thing you c
se they change things. They push the human race forw
────────────🬋🬋🬋🬋🬋🬋🬋🬋🬋🬋🬋🬋🬋🬋🬋🬋🬋🬋🬋🬋🬋🬋🬋🬋🬋🬋🬋🬋🬋🬋🬋🬋🬋───────
```

```text
Callouts (52x6, 0-based):
0. r0-r4 c0-c51  Viewport content -- horizontally translated child cells
1. r5 c0-c51     Horizontal scroll indicator -- bottom edge; `accent` thumb on a `muted`
                  track; thirty-three-cell thumb at c12-c44 (`max(1, floor(52 * 52 / 80))`
                  cells starting at `floor(18 * (52 - 33) / (80 - 52))`)
```

### No overflow and empty child

With an assigned `52x5` rectangle and `24x2` child, neither indicator appears and the
child is not translated. `ScrollView` does not invent an empty view: this fixture's
message is app-provided content. An `EmptyView` child renders blank cells under the same
rule.

```wireframe 52x5
Nothing to scroll




```

```text
Callouts (52x5, 0-based):
0. r0-r4 c0-c51  Viewport content -- un-translated child; no indicator region exists because
                  neither axis overflows
```

Loading and error are likewise child/app states, not ScrollView state: a loading child can
render its static loading message and an error child its recovery message. Either receives
normal measurement, translation, and clipping; indicators appear only if that child
actually overflows. This keeps the container controlled rather than making it own business
status.

### Degraded

This `40x6` vertical-overflow fixture uses the canonical ASCII glyph replacements and no
color. Geometry and input routing match the full-capability state.

```wireframe 40x6
Here's to the crazy ones. The misfits. |
The rebels. The troublemakers. The     #
round pegs in the square holes. The    #
ones who see things differently.       |
They're not fond of rules. And they    |
                                       |
```

```text
Callouts (40x6, 0-based):
0. r0-r5 c0-c38  Viewport content -- same translated and clipped child region
1. r0-r5 c39     Vertical scroll indicator -- `scrollbar.ascii`: `|` track, `#` thumb
```

## State model

| State                           | Owner       | Type                          | Reset or clamp rule                                                                                                                                                                                                               |
| ------------------------------- | ----------- | ----------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| axes                            | derived     | `Axis.Set`                    | Re-derived from the immutable initializer on every reconciliation; disabled components of every offset are zero.                                                                                                                  |
| controlled offset               | Binding     | `Binding<TerminalPosition>?`  | Exists only when supplied; app mutations are read on every layout, then effective offset clamps to the current bounds without passively rewriting the binding.                                                                    |
| effective offset                | derived     | `TerminalPosition`            | Uses the supplied binding when present; otherwise it is the origin. It zeroes disabled axes and clamps to `0...maximum` on every layout before rendering or event handling.                                                       |
| content extent                  | derived     | `TerminalSize`                | Re-measured each layout; scrollable axes are proposed `nil`, non-scrollable axes receive the assigned viewport proposal.                                                                                                          |
| viewport extent                 | derived     | `TerminalSize`                | Recomputed after reserving only visible indicator edges; never negative and, whenever an edge is reserved, remains at least `1x1`.                                                                                                |
| maximum offset                  | derived     | `TerminalPosition`            | Recomputed as `max(0, content extent - viewport extent)` per enabled axis after resize, content, axes, or binding changes.                                                                                                        |
| vertical indicator visibility   | derived     | `Bool`                        | True exactly when axes contains vertical, content height exceeds the stabilized viewport height, and the trailing-edge reservation leaves the stabilized content viewport at least `1x1`; otherwise no trailing edge is reserved. |
| horizontal indicator visibility | derived     | `Bool`                        | True exactly when axes contains horizontal, content width exceeds the stabilized viewport width, and the bottom-edge reservation leaves the stabilized content viewport at least `1x1`; otherwise no bottom edge is reserved.     |
| scroll view styles              | Environment | semantic `Style` roles        | Resolve `semantic.primary`, `muted` (tracks, token pending plan 032 step 5.3), and `semantic.accent` (thumbs) each render; never retain style in widget state.                                                                    |
| is focused                      | Environment | `Bool`                        | Injected below the explicit `.focusable` modifier from the FocusManager's live identity; ScrollView reads it for rendering and checks `ResponderContext.isFocused` for keyboard movement.                                         |
| owned focus eligibility         | derived     | `FocusID?`                    | `focusable(whileScrollable:)` publishes its identity exactly when enabled, offset-bound, and overflowing an enabled axis; recomputed as each layout pass settles, so registration and withdrawal never lag a graph update.        |
| is focus-within                 | Responder   | `Bool`                        | Supplied per dispatch as `ResponderContext.isFocusWithin`; lets the viewport consume unmodified press/repeat scroll keys its focused descendant declined.                                                                         |
| motion model                    | derived     | immediate integer translation | Every accepted input writes a whole-cell offset synchronously; there is no zoom factor, fractional position, animation, or momentum state.                                                                                        |

The potentially circular indicator calculation resolves deterministically: first measure
content with `nil` on enabled axes; start with the full assigned rectangle; reserve an
axis edge only when its enabled axis overflows and that reservation leaves the candidate
content viewport at least `1x1`; re-evaluate the other axis after that reservation until
visibility is stable (at most one additional reservation per axis); then compute viewport,
maxima, offset, and thumbs.

## Key table

These keys are handled by a ScrollView with a required `offset` binding that is focused or
whose subtree holds focus (focus-within), on unmodified press and repeat events alike, so
a held key keeps scrolling and keys a focused descendant cannot use scroll the nearest
able enclosing viewport. Every successful movement writes through that offset binding.

| Key   | Precondition                                                                    | Effect                                                      | Consumed |
| ----- | ------------------------------------------------------------------------------- | ----------------------------------------------------------- | -------- |
| Down  | focused, axes contains vertical, effective offset is below vertical maximum     | increments the effective vertical offset by one             | yes      |
| Up    | focused, axes contains vertical, effective offset is above 0                    | decrements the effective vertical offset by one             | yes      |
| Right | focused, axes contains horizontal, effective offset is below horizontal maximum | increments the effective horizontal offset by one           | yes      |
| Left  | focused, axes contains horizontal, effective offset is above 0                  | decrements the effective horizontal offset by one           | yes      |
| PgDn  | focused, axes contains vertical, effective offset is below vertical maximum     | increments the effective vertical offset by viewport height | yes      |
| PgUp  | focused, axes contains vertical, effective offset is above 0                    | decrements the effective vertical offset by viewport height | yes      |
| Home  | focused, effective offset is not origin                                         | sets every enabled component to 0                           | yes      |
| End   | focused, effective offset is below maximum offset                               | sets every enabled component to maximum offset              | yes      |
| Down  | focused, axes contains vertical, effective offset is at vertical maximum        | leaves offset unchanged for ancestor routing                | no       |
| Up    | focused, axes contains vertical, effective offset is at origin vertically       | leaves offset unchanged for ancestor routing                | no       |
| Right | focused, axes contains horizontal, effective offset is at horizontal maximum    | leaves offset unchanged for ancestor routing                | no       |
| Left  | focused, axes contains horizontal, effective offset is at origin horizontally   | leaves offset unchanged for ancestor routing                | no       |

`Tab` remains unclaimed so the app's explicit focus policy can advance focus. The
non-focus initializer receives no keyboard scroll events. There is no key for zoom,
inertial motion, or animation.

## Focus appearance

`ScrollView` delegates automatic focus appearance to an enclosing willing focus host such
as `Box`; that host paints after descendants without acquiring a focus-list entry or any
key events. Its border glyphs use the focus color as a bold foreground-only overlay, with
their background unchanged. The ScrollView remains the focused key responder and retains
its own edge-riding, overflow-only scroll indicator. The indicator is the focus telegraph:
a focused viewport paints its indicator thumbs bold in the focus accent and applies no
other local treatment, so scrolled content is never restyled. A focused fitting viewport
therefore shows no local treatment (only reachable through an external `.focusable`
identity, since `focusable(whileScrollable:)` withdraws when nothing can scroll); callers
that need a visible ring host one with `focusAppearance(_:)` or a `Box`. Unfocused thumbs
remain a secondary `semantic.accent` affordance.

## Mouse table

> Deferred: This mouse table lands in a later slice.

| Event       | Region                      | Precondition                                                           | Effect                                                                                                                                          | Consumed |
| ----------- | --------------------------- | ---------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- | -------- |
| click       | Viewport content            | always                                                                 | receives Slice 5's built-in click-to-focus before ordinary handler routing; ScrollView returns ignored and does not reinterpret the child click | no       |
| wheel-down  | Viewport content            | axes contains vertical, effective offset is below vertical maximum     | increments vertical effective offset by the normalized wheel step through controlled offset or fallback offset                                  | yes      |
| wheel-up    | Viewport content            | axes contains vertical, effective offset is above 0 vertically         | decrements vertical effective offset by the normalized wheel step through controlled offset or fallback offset                                  | yes      |
| wheel-down  | Viewport content            | axes contains vertical, effective offset is at vertical maximum        | leaves effective offset unchanged and returns ignored so an enclosing ScrollView may handle the event                                           | no       |
| wheel-up    | Viewport content            | axes contains vertical, effective offset is at origin vertically       | leaves effective offset unchanged and returns ignored so an enclosing ScrollView may handle the event                                           | no       |
| wheel-right | Viewport content            | axes contains horizontal, effective offset is below horizontal maximum | increments horizontal effective offset by the normalized wheel step through controlled offset or fallback offset                                | yes      |
| wheel-left  | Viewport content            | axes contains horizontal, effective offset is above 0 horizontally     | decrements horizontal effective offset by the normalized wheel step through controlled offset or fallback offset                                | yes      |
| wheel-right | Viewport content            | axes contains horizontal, effective offset is at horizontal maximum    | leaves effective offset unchanged and returns ignored so an enclosing ScrollView may handle the event                                           | no       |
| wheel-left  | Viewport content            | axes contains horizontal, effective offset is at origin horizontally   | leaves effective offset unchanged and returns ignored so an enclosing ScrollView may handle the event                                           | no       |
| drag        | Vertical scroll indicator   | vertical indicator visibility                                          | returns ignored; indicators are output-only and never capture a drag                                                                            | no       |
| drag        | Horizontal scroll indicator | horizontal indicator visibility                                        | returns ignored; indicators are output-only and never capture a drag                                                                            | no       |
| click       | Indicator corner            | always                                                                 | returns ignored; the corner has no independent action                                                                                           | no       |

Terminal touchpads and touch terminals that synthesize wheel events use these same rows:
no second gesture recognizer or pointer capture is introduced. Hit testing is
deepest-first and clips before routing, so an inner ScrollView gets a wheel first; it
consumes only while it can advance on the event's matching enabled axis. At its boundary
it returns ignored, permitting the normal ancestor bubble to scroll the outer viewport.
The terminal substrate already normalizes vertical and horizontal wheel reports to
`wheel-up`, `wheel-down`, `wheel-left`, and `wheel-right`; ScrollView does not reinterpret
Shift-wheel or signed deltas.

## Sizing

The sizing examples use the `64x24` intrinsic child from Anatomy. ScrollView is greedy for
a finite proposal; it never imposes a content-sized maximum. A `nil` component means
"report the child's ideal on that component" and gives the child a `nil` proposal on that
scrollable axis.

| Proposal  | Result | Rule                                                                                                                                                                                            |
| --------- | ------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| nil x nil | 64x24  | Both axes are ideal: child receives `nil x nil`, and ScrollView reports its complete ideal extent with no clipping.                                                                             |
| 52x12     | 52x12  | Tight proposal fills exactly; after overflow determination, one trailing and one bottom cell become indicator edges and the child is translated/clipped into `51x11`.                           |
| 12x4      | 12x4   | Declared minimum fills exactly; a vertical indicator consumes the trailing cell and the remaining `11x4` viewport clips content.                                                                |
| 10x3      | 10x3   | Under minimum fills exactly; both overflowing axes reserve edges because the remaining `9x2` viewport retains at least one content cell on both axes, while any edge that would not is omitted. |
| 120x40    | 120x40 | Over maximum fills exactly; the child is measured with nil enabled axes, blank surplus remains child/parent layout space, and no indicator appears if content no longer overflows.              |

For a vertical-only instance under a `nil x 12` parent proposal, the child receives an
unspecified scrolling-axis proposal and reports its `64x24` ideal size; the viewport
reports `65x12`, including the vertical indicator column. The symmetric horizontal case
under `52 x nil` reports `52x25`, including the horizontal indicator row. Degenerate `5x1`
horizontal and `1x5` vertical content similarly report `3x2` and `2x3` viewports when
constrained to three cells on the scrolling axis. These cases pin the nil-axis indicator
contract without introducing a second measurement protocol.

## Environment

Existing canonical tokens consumed by the standard/default rendering are:

- `scrollbar.ascii` for the ASCII fallback of proportional edge indicators (`|` track, `#`
  thumb). Thumb and track glyphs come from the indicator's style selection, see
  [ScrollIndicator](../primitives/scroll-indicator.md#environment); their token rows are
  pending plan 032 step 5.3.
- `focus.border` and `focus.content` when the surrounding style elects to expose focus;
  ScrollView adds no focus chrome by itself.
- `truncation.mark` only if the child `Text` chooses tail truncation. ScrollView clips; it
  never inserts a truncation glyph.

The semantic environment roles are complete `Style` values named `semantic.primary`,
`semantic.secondary`, `semantic.accent`, `semantic.disabled`, and `semantic.destructive`,
never colors or partial foreground values. Standard rendering uses `semantic.primary` for
child-default text, `muted` for tracks (token pending plan 032 step 5.3), and
`semantic.accent` for unfocused thumbs; a focused viewport paints its thumbs bold in the
focus accent (`semantic.focus`'s background color), which is the viewport's entire focus
telegraph. Custom applications replace those same environment values; ScrollView does not
introduce a parallel `ScrollViewStyle` protocol. No hex colors, ANSI sequences, or
noncanonical glyph set is introduced here.

## Primitive dependencies

- Viewport substrate --
  [Slice 2](../../docs/Spec.md#slice-2-the-layout-protocol-and-stack-containers):
  `ProposedSize`, child ideal measurement, absolute placement, clipping, and the
  translated `RenderRegion` operation are required before a static viewport can exist.
- [Text](../../docs/Spec.md#slice-1-tesseracore--view-viewgraph-reconciliation-text) --
  supplies normal content measurement; wrapping and truncation remain Text's
  responsibility.
- Focus/key dispatch --
  [Slice 4](../../docs/Spec.md#slice-4-focus-and-key-routing-the-responder-system):
  required for focused keyboard movement and boundary bubbling.
- Mouse/hit testing -- [Slice 5](../../docs/Spec.md#slice-5-mouse-and-hit-testing):
  required for wheel routing, clipped hit testing, and touch-generated wheel delivery.
- [ScrollIndicator](../primitives/scroll-indicator.md) is an exact later cutover, not a
  readiness dependency of the static viewport foundation. The foundation owns the same
  proportional one-cell output until the shared primitive lands at
  [`ScrollIndicator`](../../docs/Spec.md#scrollindicator), then deletes that renderer so
  ScrollView, List, and Table share one geometry owner.
- `Form`, `Outline`, and a separate `ScrollViewStyle` protocol are neither dependencies
  nor proposals before 1.0.

## Progressive delivery

1. **Slice 2 — public viewport and programmatic-offset foundation:** deliver the public
   viewport with its axes and optional `offset` binding, layout measurement with `nil`
   enabled-axis proposals, translated clipping, effective clamping after
   content/resize/app updates, and static no-overflow/overflow buffer snapshots. The
   foundation owns proportional one-cell indicator output. There is no focus or pointer
   behavior yet.
2. **Slice 3 — ScrollIndicator cutover:** replace the foundation's indicator output with
   the shared `ScrollIndicator`; delete the original renderer so the primitive owns thumb
   rounding, track/thumb glyph output, and output-only presentation.
3. **Slice 4 — keyboard:** make ScrollView focusable; add the key table's one-cell, page,
   home/end moves and key boundary bubbling. This is the first interactive vertical,
   horizontal, and two-axis viewport.
4. **Slice 5 — pointer and touch wheel:** request mouse capability only while the widget
   is live; route vertical wheel events through the mouse table, including touch-generated
   wheels, clipped nested precedence, and boundary bubbling. Indicators remain
   output-only.
5. **Slice 7 — integration:** retain the initializer and ownership contract specified here
   while composing ScrollView with catalog controls. `ScrollIndicator` remains the
   established indicator owner; integration does not take that ownership back.

## Requirements

- `vertical scrolling translates and clips arbitrary child content` (Anatomy: viewport
  content)
- `both-axis indicators preserve a one-cell viewport` (Anatomy: vertical and horizontal
  scroll indicators; state model: indicator visibility)
- `scroll indicator thumb is proportional and reaches the trailing bound` (Anatomy: thumb
  formula; states: mobile)
- `intrinsic sizing reserves indicator edges only for overflowing axes` (sizing:
  `nil x 12`, `52 x nil`, and single-row/single-column degenerate content)
- `controlled offsets clamp without rewriting app state` (state model: controlled offset)
- `disabled axes always render and retain zero offset components` (state model: axes)
- `focused arrow keys move one cell on their enabled axis` (key table: Down and Right)
- `page home and end keys clamp to the viewport bounds` (key table: PgDn, PgUp, Home, End)
- `keyboard input bubbles from a focusable scroll view at its boundary` (key table:
  boundary rows)
- `no-overflow child renders with no reserved indicator edge` (states: no overflow and
  empty child)
- `focused scroll view delegates a foreground-only box border while retaining key ownership and its edge-riding indicator`
  (focus appearance)
- `focused fitting scroll view shows no local treatment without an indicator` (focus
  appearance; states: no overflow and empty child)
- `focused viewport paints indicator thumbs in the focus accent without restyling content`
  (focus appearance)
- `owned focus identity registers and withdraws as layout settles` (state model: owned
  focus eligibility)
- `owned focus identity requires an offset binding` (state model: owned focus eligibility)
- `key repeats scroll exactly like presses` (key table preamble)
- `unconsumed scroll keys bubble to a focus-within ancestor viewport` (state model: is
  focus-within)
- `indicator reservation preserves one content cell per axis` (states: declared minimum;
  sizing: `10x3`)
- `empty loading and error child states remain app-owned` (states: no overflow and empty
  child)
- `minimum viewport clips without a negative proposal or layout failure` (states: declared
  minimum; sizing: `10x3`)
- `ascii degradation preserves scroll geometry and boundary routing` (states: degraded)
- `scroll view exposes no zoom or smooth animation transition` (state model: motion model)
- `standard preset paints an accent block thumb on a muted track` (Indicator styles:
  standard)
- `a preset fixes its thumb and track glyphs and keeps the proportional geometry`
  (Indicator styles; ScrollIndicator Variants)
- `thumbOnly preset paints no track cells` (ScrollIndicator Variants: presets)
- `the indicator look is set only by a curated preset; no thumb or track parameter exists`
  (Indicator styles)
- `in-border placement draws the thumb over the box's right border without reserving a column`
  (Indicator styles: placement)
- `in-border placement applies only under a nearest bordered Box ancestor` (Indicator
  styles: placement)

> Deferred: Pointer, wheel, drag, and uncontrolled-fallback requirements land in a later
> slice.

## Degradation

- `NO_COLOR`: keep the same glyph geometry; focus falls back to bold and any child
  selection uses reverse video according to the
  [degradation ladder](../tokens.md#degradation-ladder).
- 16-color: resolve `semantic.primary`, `muted`, and `semantic.accent` to indexed terminal
  styles; tracks use `muted` and thumbs `semantic.accent`, while a host border remains
  foreground-only in the focus color.
- ASCII-only: every preset draws `#` as its thumb and `|` (vertical) or `-` (horizontal)
  as its track, and `thumbOnly` draws no track; child truncation's `~`, as the degraded
  fixture shows. No Unicode-only gesture affordance carries meaning.
- Below `12x4`: fill the proposed non-negative rectangle, clip first, then omit any
  indicator edge whose reservation would leave the content viewport below `1x1`. No
  content is fabricated and no layout failure is allowed.

## Decisions

- **Horizontal wheel input:** The terminal substrate decodes horizontal wheel reports as
  `wheel-left` and `wheel-right`. ScrollView applies each wheel event to its matching
  enabled axis and uses the same boundary-bubbling rule on both axes. It does not infer a
  direction from Shift-wheel or a signed delta.
- **Controlled out-of-range writeback:** Layout clamps only the derived effective offset.
  Passive reconciliation never rewrites the binding and exposes no separate clamp
  callback. The next accepted user movement writes from the effective value.
- **Styling:** ScrollView consumes shared semantic complete-`Style` environment values,
  following
  [system and custom style plumbing](../../docs/Spec.md#system-and-custom-style-plumbing).
  It has no separate style protocol.
- **Indicator presentation (owner decision, omp2 review, 2026-10):** omp2's look stays the
  default vertically: an accent `█` thumb on a muted `│` track. Horizontally the default
  thumb is `🬋` on `─` (owner decision, 2026-10-11). The look is one curated
  `ScrollIndicatorStyle` preset, set with `.scrollIndicatorStyle(_ style:)`; each preset
  fixes its thumb and track together for both axes. The confirmed preset list is
  `standard` (default), `thin`, `inner`, `outer`, `dashed`, `dotted`, `heavy`, and
  `thumbOnly`; `thick`, `smooth`, and `stipple` were dropped in review. Placement inside a
  box's border is a separate opt-in modifier, `.scrollIndicatorPlacement(.border)`; it
  applies only when the ScrollView's nearest ancestor is a bordered Box, and the border
  line then serves as the track. Without one it falls back to `reserved`. This reverses
  the earlier rejection of configurable indicator styles recorded in
  [ScrollIndicator](../primitives/scroll-indicator.md#decisions). Every preset and
  `.border` placement ship in 1.0 (owner decision, 2026-10-10).
- **Reconciliation:** Unchanged ScrollView subtrees skip reconciliation and reuse cached
  measurements; this is a performance property, not a behavior or API change.
- **Pointer drag:** Indicators are output-only in 1.0. Clicks and drags return ignored;
  wheel boundary bubbling remains the only pointer-scroll contract.

This design was reviewed against the
[Phase 4 theses](../../docs/Spec.md#phase-4--view-layer-the-tessera-module): content and
optional position are controlled, fallback position is ephemeral, input changes integer
state synchronously, and rendering is a translated clipped region.

## Open questions

- Track role: the accepted wireframes paint tracks in the `muted` role, which `tokens.md`
  does not define; token pending plan 032 step 5.3.
- Token rows for the preset thumb and track roles are pending plan 032 step 5.3.

## Inspiration

- The anatomy deliberately treats a scroll viewport as a translated clipped rectangle, not
  a text-only reflow primitive; that preserves arbitrary composition and matches the
  Ratatui paragraph source's explicit two-dimensional scroll offset while rejecting its
  text coupling.
- Mobile uses the content edge rather than a border because `40x16` has no spare chrome;
  this is the constraint that made ScrollView the first advanced mobile-critical widget.
- Stable, compact indicators communicate extent in a terminal better than transient
  animated overlays, while the explicit binding supplies the programmatic-position
  affordance users expect from SwiftUI vocabulary.
