---
kind: widget
status: wireframed
---

# Button

`Button` is a focusable, controlled action control with an arbitrary `Label: View`, an
app-supplied action, and an optional semantic role. It retains no business state: the app
owns the action's effects and explicit focus binding, while the button may keep only its
transient press bit in `NodeState` so a `ButtonStyle` can draw standard pressed feedback.
This is a widget-layer design following the controlled-widget rule in
[Slice 7](../../docs/Spec.md#slice-7-catalog-integration--list-section-controlled-widgets-and-the-showcase),
with focus and pointer delivery supplied by
[Slices 4–5](../../docs/Spec.md#slice-4-focus-and-key-routing-the-responder-system).

The accepted public direction is `Button<Label: View>` with an action closure, an optional
role, and a label builder. The concrete initializer and protocol signatures intentionally
remain open; they must preserve an arbitrary label and expose no mutable business value.
`ButtonRole.destructive` is required for 1.0; a missing role uses the system default.

## Prior art

- Ratatui application: `~/Developer/ratatui/ratatui/main/examples/apps/demo2/src/app.rs` —
  copy the separation between rendering and event handling, and its explicit,
  application-owned mode transitions. Reject its central `match` over every key as
  Button's interaction model: a Tessera button handles only its focused activation keys
  through the responder chain, and the app owns all global shortcuts and action effects.
- Ratatui block: `~/Developer/ratatui/ratatui/main/ratatui-widgets/src/block.rs` — copy
  the ordering principle that base style, border style, and content style compose in
  layers, and that an inset decoration computes its content area. Reject making `Block`
  the public button API or adding a title/padding configuration surface; a Button style
  decorates the supplied label rather than owning a second content model.
- Apple SwiftUI [Button](https://developer.apple.com/documentation/swiftui/button) — copy
  the action plus arbitrary-label model, optional destructive role, and context-adaptive
  system appearance. Reject convenience image/string initializers for the first Tessera
  release: `Text` and composed label views already express them without a parallel label
  vocabulary.
- Apple SwiftUI
  [ButtonStyle](https://developer.apple.com/documentation/swiftui/buttonstyle) — copy the
  split where `ButtonStyle` changes appearance while retaining standard platform
  interaction. Reject a `PrimitiveButtonStyle` equivalent for 1.0: changing activation
  semantics is deliberately outside this widget's first public contract.

## Anatomy

The system default is `.compact`: a one-row, label-hugging action control for dense
application chrome such as the Showcase header, Catalog/Inspector controls, and action
rows. `.bordered` retains the larger three-row target for applications that need a more
substantial standalone action. `.plain` is an unadorned label action, suitable for menus
and command-like rows. Style selection changes presentation only; every enabled variant
has the same focus, keyboard, and pointer contract.

### Compact fixture

Natural fixture: the default `.compact` style around a `Text("Save")` label, unfocused and
enabled.

```wireframe 6x1
[Save]
```

```text
Callouts (6x1, 0-based):
1. r0 c0-c5 Button hit target -- the complete allocated button frame; primary-pointer
   press and release must both resolve to this same node. It is the sole mouse Region.
2. r0 c0, c5 Compact chrome -- literal square-bracket delimiters in
   `semantic.secondary` while unfocused; the complete compact frame receives the focused,
   pressed, disabled, or role-selected Style when applicable.
3. r0 c1-c4 Label slot -- arbitrary `Label: View`, measured at its ideal size and styled
   with `semantic.primary` unless the role or enabled environment selects another semantic
   Style.
```

### Plain fixture

`.plain` draws no delimiter or implicit padding. It is appropriate when surrounding menu
or command layout already supplies the visual grouping.

```wireframe 4x1
Save
```

The complete label rectangle is both the hit target and label slot. Focus and press remain
visible through the resolved full semantic Style; no focus border is manufactured for this
borderless style.

### Padded compact composition fixture

Interior padding is composition, not a second compact style. A caller applies the shared
[Padding](../primitives/padding.md) modifier to the label inside the Button label builder;
`.compact` then wraps that padded label as normal.

```wireframe 8x1
[ Save ]
```

The two spaces belong to the padded label slot (`r0 c1-c6`), not to a Button-specific
padding property. Padding applied around the Button itself remains ordinary outer layout
spacing rather than changing the compact chrome. This keeps `ButtonStyle` responsible for
decoration while the shared layout modifier owns content insets.

### Bordered fixture

`.bordered` is the former system-style presentation. It hugs the supplied label at its
ideal size, applies internal horizontal space, and uses `Border` decoration.

```wireframe 12x3
┌──────────┐
│   Save   │
└──────────┘
```

```text
Callouts (12x3, 0-based):
1. r0-r2 c0-c11 Button hit target -- the complete allocated button frame; primary-pointer
   press and release must both resolve to this same node. It is the sole mouse Region.
2. r0 c0-c11, r2 c0-c11, r1 c0, r1 c11 Bordered chrome -- `Border` decoration;
   `semantic.secondary` Style while unfocused, `semantic.accent` Style with the `rounded`
   border set while focused.
3. r1 c1-c10 Bordered label slot -- arbitrary `Label: View`, centered by the bordered
   style; `semantic.primary` Style unless the role or enabled environment selects another
   semantic Style.
```

### Focused and pressed fixtures

Focused `.compact` keeps its compact geometry. Its complete frame uses `semantic.accent`;
pressed `.compact` uses that full Style, including its resolved background or other
emphasis, for the same complete frame. This is a styled-grid distinction, not extra glyph
noise.

```wireframe 6x1
[Save]
```

Focused `.bordered` uses token `focus.border`: rounded chrome in `semantic.accent`.
Pressed `.bordered` retains that geometry and applies `semantic.accent` as a full Style to
its complete bordered label slot (`r1 c1-c10`). A primary down or phased `Enter`/`Space`
down begins the press and its matching release ends it; the action runs only on that valid
release. A legacy press-only `Enter` or `Space` event invokes the action immediately and
clears `isPressed` before the event returns.

```wireframe 12x3
╭──────────╮
│   Save   │
╰──────────╯
```

Focus is never inferred from position; the app installs the explicit focus identity
described in
[Slice 4](../../docs/Spec.md#slice-4-focus-and-key-routing-the-responder-system).

### Disabled fixture

```wireframe 6x1
[Save]
```

All compact chrome and label cells use `semantic.disabled`. A disabled button is absent
from the focusable list, never becomes pressed, and leaves keys and clicks unconsumed so
an ancestor may interpret them. `.plain` and `.bordered` use the same disabled interaction
rule with their own geometry.

### Destructive fixture

```wireframe 8x1
[Delete]
```

`role: .destructive` selects `semantic.destructive` for the label and chrome. Focus stays
visible without replacing destructive semantics; pressed state lets that same full Style
supply the emphasis treatment. `.bordered` applies the same role selection to its border
and label slot.

### Long-label truncation fixture

```wireframe 13x1
[Long label…]
```

The source label is `Text("Long label continues")`. In this constrained compact fixture
the label slot is `r0 c1-c11`; default `Text` uses grapheme-safe tail truncation with
`truncation.mark` instead of wrapping or increasing the Button height. A custom label owns
its own layout policy within the rectangle assigned by its selected style.

### Minimum fixtures

Each built-in style has its own natural floor: `.plain` with `Text("Go")` is `2x1`,
`.compact` is `4x1`, and `.bordered` is `6x3`. An empty label remains valid: `.plain`
measures `0x1`, `.compact` measures `2x1` (`[]`), and `.bordered` retains its `6x3` framed
floor.

### Mobile fixture

This `mobile` viewport uses a parent-forced full-width `.compact` allocation. Its 40-cell
horizontal frame, not just the visible label glyphs, is the touch-wide primary hit target.

```wireframe 40x16
[Touch target fills available width    ]















```

### ASCII fixture

`.plain` and `.compact` already use ASCII-safe glyphs. `.bordered` degrades as follows:

```wireframe 12x3
+----------+
|   Save   |
+----------+
```

## States

- **Idle, enabled, unfocused:** `.compact` shows `semantic.secondary` delimiters around a
  `semantic.primary` label; `.plain` has only that label; `.bordered` shows its light
  border and centered label.
- **Focused:** only an explicit `FocusID` match produces focus presentation and keyboard
  delivery. `.compact` and `.plain` use their resolved full focus Style; `.bordered` also
  uses `focus.border`.
- **Pressed:** for phased activation input, `isPressed` exists only from down until the
  matching release, cancellation, focus loss, disabled update, or node removal. Every
  built-in style uses its resolved full pressed Style without changing its geometry. A
  legacy press-only `Enter` or `Space` event invokes and clears it during that same press
  dispatch, so it cannot remain pressed.
- **Disabled:** no action, press feedback, focus participation, or event consumption
  occurs; each style renders all of its visible cells in `semantic.disabled`.
- **Destructive:** the role selects `semantic.destructive` styling, not different event
  semantics.
- **Overflow:** default textual labels tail-truncate in the slot assigned by their chosen
  style. Custom labels may choose a different layout that still fits their assigned
  rectangle.
- **Empty label:** an arbitrary empty label is valid. `.plain` is `0x1`, `.compact` is
  `2x1`, and `.bordered` is `6x3`; every enabled variant has the same activation
  semantics.
- **Pointer and touch:** a primary contact is valid only if press and release hit this
  same `Button hit target` node. A touch contact receives the final allocated width,
  including a parent-forced horizontal width as in the mobile fixture.

## State model

| State                     | Owner       | Type                                                                                                                             | Reset or clamp rule                                                                                                                                                                                                                                                                                                                                                                           |
| ------------------------- | ----------- | -------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| focus identity            | Binding     | `FocusID?`                                                                                                                       | App-owned explicit focus; if this button's focus ID disappears, Slice 4 clears the binding to `nil`; Button never chooses a replacement.                                                                                                                                                                                                                                                      |
| is enabled                | Environment | `Bool`                                                                                                                           | Read on every reconciliation. A transition to `false` clears `isPressed`, removes the node from focusability, and prevents activation immediately.                                                                                                                                                                                                                                            |
| current button style      | Environment | `any ButtonStyle`                                                                                                                | Read on every reconciliation; changing it recomposes from the same label, role, enabled, focus, and press inputs without retaining a previous style.                                                                                                                                                                                                                                          |
| semantic Styles           | Environment | `semantic.primary`, `semantic.secondary`, `semantic.accent`, `semantic.disabled`, and `semantic.destructive` full `Style` values | Read on every render; nearest environment value wins under Slice 3 style inheritance. These canonical semantic roles are planned environment values, with concrete key grouping left open.                                                                                                                                                                                                    |
| is focused                | derived     | `Bool`                                                                                                                           | Recomputed from the explicit focus binding and this node's `FocusID` on every update; false when disabled or when no matching ID exists.                                                                                                                                                                                                                                                      |
| is pressed                | NodeState   | `Bool`                                                                                                                           | Set for primary down or the down phase of enabled phased keyboard activation. Clear on its matching release, cancellation, focus loss, disablement, node removal, and every update where the node is not focused. A legacy press-only `Enter` or `Space` event invokes the action once and clears `isPressed` before its dispatch returns; it never represents app work or action completion. |
| label size and truncation | derived     | `TerminalSize` and rendered grapheme range                                                                                       | Recomputed from the proposed label slot on every layout; clamp to the allocated rectangle and use tail truncation for the selected built-in textual style.                                                                                                                                                                                                                                    |

The role, label closure, action closure, and focus ID are immutable widget configuration,
not retained business state. `isPressed` is supplied to styles solely as visual
interaction feedback; custom styles cannot turn it into an alternate activation mechanism.

## Key table

| Key                  | Precondition                    | Effect                                                                                                                                                                                                                                                                                       | Consumed |
| -------------------- | ------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- |
| Enter                | focused and is enabled          | For a phased key stream, down sets `isPressed`; its matching release invokes the app action once only if focus and enabled state still hold, then clears `isPressed`. For a legacy press-only event, invoke the app action once on that press and clear `isPressed` before dispatch returns. | yes      |
| Space                | focused and is enabled          | For a phased key stream, down sets `isPressed`; its matching release invokes the app action once only if focus and enabled state still hold, then clears `isPressed`. For a legacy press-only event, invoke the app action once on that press and clear `isPressed` before dispatch returns. | yes      |
| Enter                | focused and is enabled is false | Does not mutate `isPressed` or invoke the action; bubbles to ancestors.                                                                                                                                                                                                                      | no       |
| Space                | focused and is enabled is false | Does not mutate `isPressed` or invoke the action; bubbles to ancestors.                                                                                                                                                                                                                      | no       |
| printable characters | focused                         | Does not mutate Button state; bubbles to ancestors.                                                                                                                                                                                                                                          | no       |
| Esc                  | is pressed is true              | Cancels the pending visual press by clearing `isPressed`; does not invoke the action.                                                                                                                                                                                                        | no       |

Press/release pairing uses the normalized key-event phase supplied below the public key
name when that phase is available. A legacy keyboard event has only its press phase, so it
invokes exactly once during that dispatch and clears `isPressed` before returning. A
release after the button lost focus, became disabled, or was removed only clears its
ephemeral press state and cannot invoke the action.

## Mouse table

| Event        | Region            | Precondition        | Effect                                                                                                                                                                                                             | Consumed |
| ------------ | ----------------- | ------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | -------- |
| click        | Button hit target | is enabled          | Slice 5 first focuses the node when it is focusable; an internal primary down sets `isPressed`, and primary release invokes the app action once only when both points hit this same node, then clears `isPressed`. | yes      |
| click        | Button hit target | is enabled is false | Does not focus, press, or invoke; bubbles to an ancestor.                                                                                                                                                          | no       |
| double-click | Button hit target | is enabled          | Has no distinct Button gesture; each constituent valid primary same-node click follows the `click` row and therefore invokes once.                                                                                 | yes      |
| drag         | Button hit target | is pressed is true  | Clears visual `isPressed` when release is outside this node; never invokes the action for that release.                                                                                                            | no       |

The raw primary stream is internal so the built-in and custom `ButtonStyle` paths share
the same press feedback. The public pointer contract is nevertheless exactly Slice 5's
same-node tap semantics, not a drag threshold or label-glyph hit test.

## Sizing

Results name the selected built-in style and fixture label. A parent `frame` may allocate
a larger rectangle after measurement; the Button node always keeps that final rectangle as
its hit target. `.compact` and `.bordered` span a forced horizontal allocation with their
delimiters or border; `.plain` leaves its label unadorned inside the allocation.

| Style and proposal                           | Result | Rule                                                                                                                                                     |
| -------------------------------------------- | ------ | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `.compact`, nil x nil with `Text("Save")`    | 6x1    | Natural default: four label cells plus two square-bracket delimiters.                                                                                    |
| `.plain`, nil x nil with `Text("Save")`      | 4x1    | Natural label size; plain adds neither chrome nor padding.                                                                                               |
| `.compact`, padded `Text("Save")`, nil x nil | 8x1    | Horizontal padding composed inside the label builder contributes two label-slot cells before compact decoration.                                         |
| `.bordered`, nil x nil with `Text("Save")`   | 12x3   | Explicit large presentation: default horizontal space plus a one-cell border ring.                                                                       |
| `.compact`, 5x1                              | 5x1    | Constrain the label slot and tail-truncate default text without changing the one-row geometry.                                                           |
| `.bordered`, 5x2                             | 5x2    | Below the `6x3` bordered floor, omit the border ring rather than draw partial corners; tail-truncate default text and preserve the allocated hit target. |
| `.compact`, 80x24                            | 6x1    | Extra available space does not make a label-hugging button grow opportunistically.                                                                       |
| `.compact`, 40x1 forced frame allocation     | 40x1   | The compact delimiters and primary hit target span the full allocation, as shown by the mobile fixture.                                                  |
| `.compact`, nil x nil with `Text("Go")`      | 4x1    | The compact fixture is the default system-style floor for this label.                                                                                    |
| `.bordered`, nil x nil with `Text("Go")`     | 6x3    | The bordered fixture retains its independently useful framed floor.                                                                                      |

## Environment

`Button` consumes the planned `isEnabled`, `buttonStyle`, and semantic-Style environment
values. The latter names are exactly `semantic.primary`, `semantic.secondary`,
`semantic.accent`, `semantic.disabled`, and `semantic.destructive`; each is a complete
`Style`, not a foreground-color alias, so it can carry foreground, background, and
emphasis coherently. The visual glyph vocabulary comes from [tokens](../tokens.md):
`focus.border`, `rounded`, `ascii`, and `truncation.mark`.

The built-in style direction is `.automatic`, `.plain`, `.compact`, and `.bordered`.
`.automatic` resolves to `.compact` in 1.0; applications select `.bordered` explicitly
when a larger standalone affordance is warranted. Exact environment-key and type-erasure
signatures remain open.

| Style                     | Idle, enabled, no role                                               | Focused and pressed                                                             | Disabled and destructive                                                                                            | Geometry                                            |
| ------------------------- | -------------------------------------------------------------------- | ------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------- |
| `.plain`                  | `semantic.primary` label                                             | Resolved full focus or pressed Style on the label slot                          | All visible label cells resolve `semantic.disabled` or `semantic.destructive`                                       | Unframed label; no implicit padding                 |
| `.compact` / `.automatic` | `semantic.secondary` delimiters; `semantic.primary` label            | Resolved full focus or pressed Style on the complete compact frame              | All visible cells resolve `semantic.disabled` or `semantic.destructive`                                             | Square-bracket delimiters around the label slot     |
| `.bordered`               | `semantic.secondary` light border; `semantic.primary` centered label | `focus.border` rounded accent border; pressed full `semantic.accent` label slot | All visible cells resolve `semantic.disabled` or `semantic.destructive`; focus does not erase destructive semantics | One-cell border ring with internal horizontal space |

There is no Button-specific padding property or padded Button style. To produce
`[ Save ]`, compose the shared layout `padding` modifier inside the label builder; to add
space around a Button in a row or stack, compose that modifier outside the Button. This
keeps content insets in the shared layout vocabulary and lets every `ButtonStyle` receive
the same supplied label.

A system style and custom `ButtonStyle` protocol are accepted public direction. The custom
style receives the label, optional role, `isEnabled`, `isFocused`, and `isPressed`, and is
constrained to this standard activation contract. It may choose geometry and decoration,
but it does not redefine keyboard, focus, pointer, enabled, or action behavior.

## Primitive dependencies

- [`Text` and its truncation policy](../primitives/text.md#progressive-slice-sequence) —
  needed for default textual labels, composed label padding, and grapheme-safe overflow
  behavior; Text itself arrives in Slice 1 and its wrapping/truncation features in
  Slice 3.
- [`Border` decoration and `Style`](../../docs/Spec.md#slice-3-styling-text-wrapping-and-decoration)
  — needed for `.bordered`, focus border treatment, and the five full semantic Styles;
  available with Slice 3.
- [Focus manager and responder context](../../docs/Spec.md#slice-4-focus-and-key-routing-the-responder-system)
  — needed for explicit focus and Enter/Space routing; available with Slice 4.
- [Mouse hit testing](../../docs/Spec.md#slice-5-mouse-and-hit-testing) — needed for
  primary same-node activation, click-to-focus, and touch-width hit geometry; available
  with Slice 5.

`Form` and `Outline` are not Button dependencies and are not part of the 1.0 widget
surface. Source browsing or source-mapping affordances are explicitly post-1.0 and are not
implied by a Button label or action.

## Progressive slice sequence

1. **After Slice 3:** Button may render an arbitrary label through `.plain`, `.compact`,
   `.bordered`, and a custom style; resolve role/enabled semantic Styles; measure its
   default textual label; and show the idle, disabled, destructive, overflow, ASCII, and
   forced-width fixtures. It does not claim focus or activate yet.
2. **After Slice 4:** an explicitly identified enabled Button joins the focus list. It
   receives `Enter` and `Space` through responder routing. For a phased key stream, down
   supplies pressed feedback and the matching release invokes once; for a legacy
   press-only event, that press invokes once and clears `isPressed` before returning.
   Unfocused or disabled input keeps bubbling.
3. **After Slice 5:** Button requests pointer input, gains click-to-focus and valid
   primary same-node activation, and uses its final allocated frame as the touch-wide
   horizontal hit target. The mobile fixture becomes interactive at this point.
4. **At the Phase 4 Showcase:** compact header/action-row buttons, a bordered standalone
   specimen, a plain menu specimen, a custom `ButtonStyle`, and enabled, disabled, and
   destructive states are demonstrated together. No custom activation semantics, Form,
   Outline, or source browsing/mapping is required for this showcase.

## Requirements

- `button renders an arbitrary label at its natural compact-style size` (compact anatomy
  fixture; sizing: `.compact`, nil x nil)
- `plain button renders its label without implicit chrome or padding` (plain fixture;
  environment built-in styles)
- `compact button decorates a padded label without owning padding configuration` (padded
  compact composition fixture; environment padding rule)
- `bordered button renders an arbitrary label at its framed natural size` (bordered
  anatomy fixture; sizing: `.bordered`, nil x nil)
- `button styles preserve the standard focus and activation contract` (anatomy style
  direction; key and mouse tables)
- `button shows focus only for its explicit matching focus identity` (focused fixture;
  state model: is focused)
- `button invokes its action exactly once for a phased enabled enter press and matching release`
  (key table: Enter; state model: is pressed)
- `button invokes its action exactly once for a legacy enabled enter press-only event`
  (key table: Enter; state model: is pressed)
- `button invokes its action exactly once for a phased enabled space press and matching release`
  (key table: Space; state model: is pressed)
- `button invokes its action exactly once for a legacy enabled space press-only event`
  (key table: Space; state model: is pressed)
- `legacy keyboard activation clears isPressed before dispatch returns` (key table: Enter
  and Space; state model: is pressed)
- `button cancels a pending press when focus or enabled state changes before release`
  (state model: is pressed; key release note)
- `disabled button neither joins focus nor invokes or consumes activation input` (disabled
  fixture; key and mouse tables: disabled click)
- `button activates a primary pointer only when press and release hit the same button node`
  (anatomy callout 1; mouse table: click)
- `button uses the full forced horizontal allocation as its touch-wide hit target` (mobile
  fixture; sizing: `.compact`, 40x1 forced frame allocation)
- `button applies semantic.destructive styling without changing standard activation behavior`
  (destructive fixture; environment built-in styles table)
- `button exposes transient isPressed only to standard and custom style rendering`
  (focused and pressed fixtures; state model: is pressed)
- `default textual button tail-truncates long label without changing compact height`
  (long-label fixture; state model: label size and truncation)
- `bordered button degrades its border and truncation mark in ascii-only output` (ASCII
  fixture; degradation: ASCII-only)
- `bordered button stays unframed below its visual minimum` (sizing: `.bordered`, 5x2)
- `custom button style receives semantic interaction configuration` (environment: custom
  style direction; key and mouse tables)

## Degradation

| Capability or space            | Button behavior                                                                                                                                                                                                                                                                        |
| ------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Full capability                | `.plain` remains unframed; `.compact` keeps ASCII-safe square delimiters; `.bordered` uses light/rounded border sets; all styles use semantic full Styles and `…` tail truncation.                                                                                                     |
| `NO_COLOR`                     | `.plain` and `.compact` retain semantic distinction through attributes; focus uses bold and pressed uses reverse video. `.bordered` additionally keeps its border glyphs.                                                                                                              |
| 16-color                       | All styles resolve the five semantic full Styles to the indexed palette; focus retains indexed `semantic.accent` and destructive keeps its distinct indexed Style.                                                                                                                     |
| ASCII-only                     | `.plain` and `.compact` keep their literal glyphs; `.bordered` uses plus, hyphen, and vertical-bar glyphs; tail truncation changes from `…` to `~`; focus uses bold.                                                                                                                   |
| Below a selected style's floor | `.plain` and `.compact` retain their one-row geometry while constraining their label slot. `.bordered` omits its border ring below `6x3`, tail-truncates default text, and leaves the allocated rectangle as the primary hit region. Interaction and enabled semantics do not degrade. |

## Open questions

- **Action closure shape:** whether the public action is `() -> Void` or receives an
  `inout ResponderContext` must be decided alongside the first widget action API. The
  decision is unblocked by a Slice 4 prototype that demonstrates a button action needing
  `setNeedsDisplay` without giving the widget access to app business state.
- **`ButtonStyle` representation:** associated-type protocol, existential environment
  storage, and any type-erasure boundary remain open. The decision is unblocked by
  `.plain`, `.compact`, `.bordered`, and one external custom `ButtonStyle` compiling in a
  minimal Showcase example.
- **Role set beyond destructive:** `destructive` is required; cancel, confirmation, and
  other roles need evidence from a post-Showcase application before expanding the public
  enum. The decision is unblocked by two independently motivated uses with distinct
  semantic styling.
- **Touch event normalization:** the final platform input adapter may expose touch as a
  primary click or as a distinct contact event. The Button invariant is already fixed: the
  whole allocated frame is hit-tested and activation requires press/release on this node.
  The adapter decision is unblocked by the Phase 5 runtime's first touch-capable backend.

## Inspiration

The Phase 4 Showcase should use compact Buttons for dense header and action rows, a plain
menu specimen, an explicitly bordered standalone action, and one visibly custom
`ButtonStyle`. These are review targets for interaction consistency, not commitments to a
Form, Outline, toolbar, source browser, or source-mapping UI.
