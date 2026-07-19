---
kind: widget
status: ready
---

# ScrollView

`ScrollView` is the mobile-critical viewport widget: it exposes a translated, clipped
window onto one child in `.vertical`, `.horizontal`, or both axes. The app owns content
and, when supplied, its `TerminalPosition` through an optional binding; the widget owns
only an uncontrolled fallback position in `NodeState`. It is deliberately a cell viewport,
not a physics simulation: every input changes an integer offset immediately, and it offers
neither zoom nor smooth animation. Its public viewport and programmatic-offset foundation
begins in [Slice 2](../../docs/Spec.md#slice-2-the-layout-protocol-and-stack-containers)
and its final style/public-API delivery completes in
[Slice 7](../../docs/Spec.md#slice-7-catalog-integration--list-section-controlled-widgets-and-the-showcase).

Public viewport vocabulary:

```swift
public struct ScrollView<Content: View>: View {
    public init(
        _ axes: Axis.Set = .vertical,
        offset: Binding<TerminalPosition>? = nil,
        @ViewBuilder content: () -> Content
    )
}
```

`offset` is `(x, y)` in cells. Disabled-axis components render and behave as zero. A
supplied binding is both the app's programmatic-scroll input and the recipient of user
scroll changes. A binding value outside the newly measured range is **effectively clamped
for layout and rendering**, but passive reconciliation does not write a corrective value
into app state; the next user scroll begins from that effective value. The no-binding form
creates the fallback position only in `NodeState`.

## Prior art

- Ratatui scrollbar:
  `/Users/rob/Developer/ratatui/ratatui/main/ratatui-widgets/src/scrollbar.rs` -- copy its
  distinct vertical/horizontal orientations and thumb geometry derived from content
  length, viewport length, and position. Reject its separately constructed, caller-owned
  `ScrollbarState`, endpoint arrows, and decorative track configuration: Tessera derives
  indicator state from the viewport and uses the canonical token glyphs.
- Ratatui paragraph:
  `/Users/rob/Developer/ratatui/ratatui/main/ratatui-widgets/src/paragraph.rs` -- copy the
  two-dimensional offset concept and the discipline of rendering only into the intersected
  area (its `scroll((y, x))` is intentionally reversed from Tessera's
  `TerminalPosition(x:y:)`). Reject paragraph-specific post-wrap scrolling: ScrollView
  moves arbitrary already-laid-out content before clipping, so it must not reflow or
  reinterpret the child.
- Ratatui list state:
  `/Users/rob/Developer/ratatui/ratatui/main/ratatui-widgets/src/list/state.rs` -- copy
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
release notes — Q3 preview — internal draft        │
the document is translated by offset (12, 8)       │
content outside the viewport is not painted here.  │
left edge begins after a long hidden line prefix   █
visible content remains unstyled by the scroll view█
long lines extend beyond the right edge            █
scroll indicators occupy viewport edge cells only  █
not app-owned content or additional chrome         █
programmatic offset uses the same integer position │
no zoom and no animated intermediate position      │
wheel bubbles when this offset reaches an edge     │
──────────■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■─│
```

```text
Callouts (52x12, 0-based):
0. r0-r10 c0-c50  Viewport content -- child `View` rendered through a translated, clipped
                   `RenderRegion`; this is the primary wheel and click region
1. r0-r10 c51     Vertical scroll indicator -- `scrollbar.track` / `scrollbar.thumb`; five-cell
                   thumb at r3-r7, present only for vertical overflow
2. r11 c0-c50     Horizontal scroll indicator -- `scrollbar.track` / `scrollbar.thumb`; forty-cell
                   thumb at c10-c49, present only for horizontal overflow
3. r11 c51        Indicator corner -- reserved intersection of the two indicator edges; no
                   content and no independent action
```

Indicators have no endpoint arrows and do not change the child proposal. If only one axis
overflows, only its one-cell edge is reserved; if neither overflows, the child receives
the whole assigned rectangle. For each overflowing axis, with track length `T`, viewport
extent `V`, content extent `C`, and effective offset `O`, the thumb has
`max(1, floor(T * V / C))` cells and starts at `floor(O * (T - thumb) / max(1, C - V))`.
The last formula puts the thumb exactly at the trailing/bottom end when the position is
maximum. An indicator is visible only when its enabled axis overflows and the stabilized
reservation leaves a content viewport at least `1x1`; otherwise that edge is omitted.

## States

### Mobile

Mobile is the required `40x16` fixture. It is vertical-only with content `39x24`,
effective offset `(0, 8)`, and `T = 16`, `V = 16`, `C = 24`, `O = 8`. Its proportional
thumb is `max(1, floor(16 * 16 / 24)) = 10` cells; at the maximum offset it starts at
`floor(8 * (16 - 10) / (24 - 16)) = 6`, occupying r6-r15. The width remains useful for
prose because ScrollView does not add a border or inset.

```wireframe 40x16
Release notes                          │
ScrollView is a clipped viewport, not  │
a second layout system.                │
The app owns content and may own its   │
position binding.                      │
NodeState is used only with no binding │
Arrow keys move one cell.              █
Page keys move one viewport.           █
Touch terminals report wheel events.   █
At an edge the event bubbles outward.  █
The trailing edge is an indicator.     █
It does not become a second focus stop █
No zoom. No smooth animation.          █
Programmatic updates clamp on layout.  █
Content stays app-owned.               █
                                       █
```

```text
Callouts (40x16, 0-based):
0. r0-r15 c0-c38  Viewport content -- translated child cells; the same region as Anatomy callout 0
1. r0-r15 c39     Vertical scroll indicator -- mobile trailing edge; the ten-cell thumb is r6-r15
```

### Declared minimum

`12x4` is the declared floor. At the floor, useful content remains eleven cells wide after
the trailing indicator; the widget still clips and scrolls. There is no title, padding, or
status text to sacrifice. The short thumb is intentionally still one cell rather than
disappearing.

```wireframe 12x4
scrolling  │
clips only █
integer    │
content.   │
```

```text
Callouts (12x4, 0-based):
0. r0-r3 c0-c10  Viewport content -- clipped child cells, tail clipping is the child's concern
1. r0-r3 c11     Vertical scroll indicator -- one-cell minimum thumb at r1
```

Below `12x4`, ScrollView takes the assigned non-negative rectangle and continues clipping.
Each indicator is omitted whenever its overflowing-axis reservation would leave the
content viewport narrower or shorter than one cell; visible indicator reservations
therefore always leave at least one content cell on both axes. It never creates a negative
proposal or a layout failure.

### Horizontal only

Horizontal scrolling reserves only a bottom edge. The fixture is `52x6`, content is
`80x5`, and effective offset is `(18, 0)`; vertical movement is disabled and always
remains zero.

```wireframe 52x6
segment 18: component content continues to the right
segment 19: translated slice is visible
segment 20: vertical wheel input is not claimed here
segment 21: Left and Right are the focused controls
segment 22: position x is clamped after every layout
────────────■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■────
```

```text
Callouts (52x6, 0-based):
0. r0-r4 c0-c51  Viewport content -- horizontally translated child cells
1. r5 c0-c51     Horizontal scroll indicator -- bottom edge; proportional thumb is present
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
Release notes                          |
Clipped cells remain readable.         #
The app still owns the position.       #
Boundary events still bubble.          |
No animation is introduced.            |
                                       |
```

```text
Callouts (40x6, 0-based):
0. r0-r5 c0-c38  Viewport content -- same translated and clipped child region
1. r0-r5 c39     Vertical scroll indicator -- `scrollbar.ascii`; `#` is the thumb
```

## State model

| State                           | Owner       | Type                          | Reset or clamp rule                                                                                                                                                                                                               |
| ------------------------------- | ----------- | ----------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| axes                            | derived     | `Axis.Set`                    | Re-derived from the immutable initializer on every reconciliation; disabled components of every offset are zero.                                                                                                                  |
| controlled offset               | Binding     | `Binding<TerminalPosition>?`  | Exists only when supplied; app mutations are read on every layout, then effective offset clamps to the current bounds without passively rewriting the binding.                                                                    |
| fallback offset                 | NodeState   | `TerminalPosition`            | Exists only when controlled offset is nil; clamps each layout, resize, content update, and axes update to `0...maximum` per enabled axis.                                                                                         |
| effective offset                | derived     | `TerminalPosition`            | Chooses controlled or fallback offset, zeroes disabled axes, and clamps to `0...maximum` on every layout before rendering or event handling.                                                                                      |
| content extent                  | derived     | `TerminalSize`                | Re-measured each layout; scrollable axes are proposed `nil`, non-scrollable axes receive the assigned viewport proposal.                                                                                                          |
| viewport extent                 | derived     | `TerminalSize`                | Recomputed after reserving only visible indicator edges; never negative and, whenever an edge is reserved, remains at least `1x1`.                                                                                                |
| maximum offset                  | derived     | `TerminalPosition`            | Recomputed as `max(0, content extent - viewport extent)` per enabled axis after resize, content, axes, or binding changes.                                                                                                        |
| vertical indicator visibility   | derived     | `Bool`                        | True exactly when axes contains vertical, content height exceeds the stabilized viewport height, and the trailing-edge reservation leaves the stabilized content viewport at least `1x1`; otherwise no trailing edge is reserved. |
| horizontal indicator visibility | derived     | `Bool`                        | True exactly when axes contains horizontal, content width exceeds the stabilized viewport width, and the bottom-edge reservation leaves the stabilized content viewport at least `1x1`; otherwise no bottom edge is reserved.     |
| scroll view styles              | Environment | semantic `Style` roles        | Resolve `semantic.primary`, `semantic.secondary`, and `semantic.accent` each render; never retain style in widget state.                                                                                                          |
| motion model                    | derived     | immediate integer translation | Every accepted input writes a whole-cell offset synchronously; there is no zoom factor, fractional position, animation, or momentum state.                                                                                        |

The potentially circular indicator calculation resolves deterministically: first measure
content with `nil` on enabled axes; start with the full assigned rectangle; reserve an
axis edge only when its enabled axis overflows and that reservation leaves the candidate
content viewport at least `1x1`; re-evaluate the other axis after that reservation until
visibility is stable (at most one additional reservation per axis); then compute viewport,
maxima, offset, and thumbs.

## Key table

| Key   | Precondition                                                                    | Effect                                                                                                                        | Consumed |
| ----- | ------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------- | -------- |
| Down  | focused, axes contains vertical, effective offset is below vertical maximum     | increments the effective vertical offset by one and writes it through controlled offset or fallback offset                    | yes      |
| Up    | focused, axes contains vertical, effective offset is above 0                    | decrements the effective vertical offset by one and writes it through controlled offset or fallback offset                    | yes      |
| Right | focused, axes contains horizontal, effective offset is below horizontal maximum | increments the effective horizontal offset by one and writes it through controlled offset or fallback offset                  | yes      |
| Left  | focused, axes contains horizontal, effective offset is above 0                  | decrements the effective horizontal offset by one and writes it through controlled offset or fallback offset                  | yes      |
| PgDn  | focused, axes contains vertical, effective offset is below vertical maximum     | increments the effective vertical offset by viewport extent height and writes it through controlled offset or fallback offset | yes      |
| PgUp  | focused, axes contains vertical, effective offset is above 0                    | decrements the effective vertical offset by viewport extent height and writes it through controlled offset or fallback offset | yes      |
| Home  | focused, effective offset is not origin                                         | sets every enabled component of effective offset to 0 and writes it through controlled offset or fallback offset              | yes      |
| End   | focused, effective offset is below maximum offset                               | sets every enabled component of effective offset to maximum offset and writes it through controlled offset or fallback offset | yes      |
| Down  | focused, axes contains vertical, effective offset is at vertical maximum        | leaves effective offset unchanged and returns ignored for ancestor routing                                                    | no       |
| Up    | focused, axes contains vertical, effective offset is at origin vertically       | leaves effective offset unchanged and returns ignored for ancestor routing                                                    | no       |
| Right | focused, axes contains horizontal, effective offset is at horizontal maximum    | leaves effective offset unchanged and returns ignored for ancestor routing                                                    | no       |
| Left  | focused, axes contains horizontal, effective offset is at origin horizontally   | leaves effective offset unchanged and returns ignored for ancestor routing                                                    | no       |

The focused widget is the only key claimant. `Tab` remains unclaimed so the app's explicit
focus policy from
[Slice 4](../../docs/Spec.md#slice-4-focus-and-key-routing-the-responder-system) can
advance focus. There is no key for zoom, inertial motion, or animation.

## Mouse table

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

For a vertical-only instance with `nil x 12`, the child is measured at ideal width and
proposed height `nil`; it reports `64x12` for this data. For a horizontal-only instance
with `52 x nil`, the child is proposed width `nil` and ideal height; it reports `52x24`.
These asymmetric cases pin the nil-axis rule without making a second measurement protocol.

## Environment

Existing canonical tokens consumed by the standard/default rendering are:

- `scrollbar.track`, `scrollbar.thumb`, and `scrollbar.ascii` for proportional edge
  indicators.
- `focus.border` and `focus.content` when the surrounding style elects to expose focus;
  ScrollView adds no focus chrome by itself.
- `truncation.mark` only if the child `Text` chooses tail truncation. ScrollView clips; it
  never inserts a truncation glyph.

The semantic environment roles are complete `Style` values named `semantic.primary`,
`semantic.secondary`, `semantic.accent`, `semantic.disabled`, and `semantic.destructive`,
never colors or partial foreground values. Standard rendering uses `semantic.primary` for
child-default text, `semantic.secondary` for tracks, and `semantic.accent` for thumbs and
focus. Custom applications replace those same environment values; ScrollView does not
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
- `vertical-only scroll view measures its scrollable nil axis at ideal size` (sizing:
  `nil x 12`)
- `horizontal-only scroll view measures its scrollable nil axis at ideal size` (sizing:
  `52 x nil`)
- `controlled offsets clamp without rewriting app state` (state model: controlled offset)
- `uncontrolled fallback offset clamps after resize content and axes changes` (state
  model: fallback offset)
- `disabled axes always render and retain zero offset components` (state model: axes)
- `focused arrow keys move one cell on their enabled axis` (key table: Down and Right)
- `page home and end keys clamp to the viewport bounds` (key table: PgDn, PgUp, Home, End)
- `keyboard input bubbles from a scroll view at its boundary` (key table: boundary rows)
- `wheel input changes the matching enabled axis without changing app content` (mouse
  table: wheel-down and wheel-right)
- `nested scroll views give the clipped inner viewport first wheel precedence` (mouse
  table: viewport content; nested-scroll routing)
- `wheel input bubbles to an ancestor when the inner viewport reaches its boundary` (mouse
  table: wheel boundary rows)
- `horizontal wheel input moves the horizontal axis and bubbles at its boundary` (mouse
  table: wheel-left and wheel-right boundary rows)
- `scroll indicators do not capture pointer drags` (mouse table: drag rows)
- `no-overflow child renders with no reserved indicator edge` (states: no overflow and
  empty child)
- `indicator reservation preserves one content cell per axis` (states: declared minimum;
  sizing: `10x3`)
- `empty loading and error child states remain app-owned` (states: no overflow and empty
  child)
- `minimum viewport clips without a negative proposal or layout failure` (states: declared
  minimum; sizing: `10x3`)
- `ascii degradation preserves scroll geometry and boundary routing` (states: degraded)
- `scroll view exposes no zoom or smooth animation transition` (state model: motion model)

## Degradation

- `NO_COLOR`: keep the same glyph geometry; focus falls back to bold and any child
  selection uses reverse video according to the
  [degradation ladder](../tokens.md#degradation-ladder).
- 16-color: resolve `semantic.primary`, `semantic.secondary`, and `semantic.accent` to
  indexed terminal styles; tracks remain `semantic.secondary` and thumbs/focus remain
  `semantic.accent`.
- ASCII-only: use `|` track, `#` thumb, and any child truncation's `~`, as the degraded
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
- **Pointer drag:** Indicators are output-only in 1.0. Clicks and drags return ignored;
  wheel boundary bubbling remains the only pointer-scroll contract.

This design was reviewed against the
[Phase 4 theses](../../docs/Spec.md#phase-4--view-layer-the-tessera-module): content and
optional position are controlled, fallback position is ephemeral, input changes integer
state synchronously, and rendering is a translated clipped region.

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
