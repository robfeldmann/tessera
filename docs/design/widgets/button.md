---
kind: widget
status: ready
---

# Button

`Button` is a focusable, controlled action control with an arbitrary `Label: View`, an
app-supplied action, and an optional role. It retains no business state: the app owns the
action's effects, while the button keeps only its transient press bit in `NodeState` and
reads hover from the graph at render, so a style can draw pressed and hovered feedback.
Focus identity and app-owned tracking are attached by composition, not stored by Button.

Every design decision in this doc is an owner decision, 2026-10-10, unless it carries a
later date or cites a [translation key](../translation-key.md) row. The API is identical
in every mode (Nerd Font, Unicode, ASCII, NO_COLOR). Modes change only how a shape and
emphasis are drawn, never which values exist.

```swift
public init(
    role: ButtonRole? = nil,
    action: @escaping () -> Void,
    @ViewBuilder label: () -> Label
)

public init(
    _ title: String,
    role: ButtonRole? = nil,
    action: @escaping () -> Void
) where Label == Text
```

The public action is `() -> Void` (owner decision, 2026-10-10). Redraw comes from the
app's binding write, since state is the app's job; this is SwiftUI parity.

```swift
Button("Deploy") { deploy() }
    .buttonStyle(.filled)
    .buttonBorderShape(.squared)

Button("Save") { save() }
    .keyboardShortcut(.defaultAction)

Button("Cancel", role: .cancel) { close() }
    .keyboardShortcut(.cancelAction)
```

A caller keeps focus identity explicit. The focus binding is app-supplied; the button
never stores it:

```swift
Button("Save") { save() }
    .focusable(saveFocusID)
    .focused(focusedID, equals: saveFocusID)
```

`ButtonRole` has `.cancel` and `.destructive`; `nil` selects the default intent. SwiftUI's
`.confirm` and `.close` are not adopted.

## Prior art

- Ratatui application: `~/Developer/ratatui/ratatui/main/examples/apps/demo2/src/app.rs` —
  copy the separation between rendering and event handling, and its explicit,
  application-owned mode transitions. Reject its central `match` over every key as
  Button's interaction model: a Tessera button handles only its focused activation keys
  through the responder chain, and the app owns all global shortcuts and action effects.
- Ratatui block: `~/Developer/ratatui/ratatui/main/ratatui-widgets/src/block.rs` — copy
  the ordering principle that base style, border style, and content style compose in
  layers, and that an inset decoration computes its content area. Reject making `Block`
  the public button API or adding a title/padding configuration surface; a Button shape
  decorates the supplied label rather than owning a second content model.
- Apple SwiftUI [Button](https://developer.apple.com/documentation/swiftui/button) — copy
  the action plus arbitrary-label model, the optional cancel and destructive roles, and
  context-adaptive system appearance. Tessera also ships the string-title convenience
  above; image and other convenience initializers remain outside this widget's current
  contract.
- Apple SwiftUI
  [ButtonStyle](https://developer.apple.com/documentation/swiftui/buttonstyle) — copy the
  split where `ButtonStyle` changes appearance while retaining standard platform
  interaction. Reject a `PrimitiveButtonStyle` equivalent for 1.0: changing activation
  semantics is deliberately outside this widget's first public contract.
- SwiftUI `.borderedProminent` and `.bordered` are the models for the filled and tinted
  emphases. Tessera names them `.filled` and `.tinted`, because "bordered" reads as a
  drawn box in a terminal.
- omp2 `Button`
  ([`button.rs`](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/button.rs#L13-L345))
  is the counterpart. Copy the capsule caps and charset fallback (`paint_pill` L115-133;
  key K10) and the soft tinted colouring (`soft_colors` L136-157). Its variants (L16-25)
  become emphases, a style modifier (key B12): Pill is `.filled`, Tint is `.tinted`, and
  Ghost is `.plain`; Soft, omp2's toggle chip, has no Button emphasis. Its `cancel` and
  `submit` flags (L92-95) become `role: .cancel` with `.keyboardShortcut(.cancelAction)`
  and `.keyboardShortcut(.defaultAction)` (keys C4, C3), and its `Pressed(id)` event
  (L96-97) is the action closure (key C2). Enter and Space press it (L314-322), as does a
  click on its `Press` hit region (L215-216, L332-333); the Key and Mouse tables below
  carry both (keys E3, F1, F3, F6). It reads focus and hover at paint (L217-218); Tessera
  reads focus from the environment and hover from the graph (keys E2, F4). Reject its
  `Confirm` arming (`armed` L27-30, `press` L86-90): two-step confirmation is rejected
  (key C13), activation stays this widget's contract, and an emphasis or shape changes
  appearance only.

## Anatomy

A Button has four independent dimensions. Intent chooses the colour, emphasis chooses how
that colour is applied, shape chooses the ends, and state changes the result on top. Every
emphasis follows the same state rule.

| Dimension | Decides                                      | API                                                                                      |
| --------- | -------------------------------------------- | ---------------------------------------------------------------------------------------- |
| Intent    | colour                                       | `role:` (`nil`, `.cancel`, `.destructive`) and `.keyboardShortcut(.defaultAction)`       |
| Emphasis  | how the colour is applied                    | `.buttonStyle(.filled / .tinted / .plain)`                                               |
| Shape     | the ends                                     | `.buttonBorderShape(.squared / .capsule / .rectangle / .brackets / .box / .custom(...))` |
| State     | changes on top, same rule for every emphasis | focused, pressed, hovered, disabled (environment / NodeState / graph)                    |

The anatomy fixture is a tinted, squared Button with no default action, which is the
default shape and the default emphasis for a plain `Button`:

```wireframe 6x1
▐Save▌
```

```text
Callouts (6x1, 0-based):
1. r0 c0     Leading end -- half block `▐` in the fill colour, `faint(accent)`.
2. r0 c1-c4  Label slot -- label in `accent` on the `faint(accent)` fill; chrome, one row.
3. r0 c5     Trailing end -- half block `▌` in the fill colour.
4. r0 c0-c5  Button hit target -- the whole allocated frame; press and release must both resolve to this node.
```

```text
── chars ──
▐Save▌
── style ──
ABBBBA
── legend ──
.  default
A  fg=faint(accent)
B  fg=accent bg=faint(accent)
```

### Mobile

At the `mobile` viewport a parent may force a full-width allocation. A filled, squared
Button spans it: the ends sit at the allocation edges, the fill covers the slack, and the
label stays at the leading end (Sizing: 40x1 row).

```wireframe 40x1
▐Touch target fills available width    ▌
```

```text
Callouts (40x1, 0-based):
1. r0 c0       Leading end -- half block `▐` in `accent`.
2. r0 c1-c34   Label slot -- `contrast` bold on the `accent` fill, at the leading end; chrome, one row.
3. r0 c35-c38  Slack -- `accent` fill to the trailing end.
4. r0 c39      Trailing end -- half block `▌` in `accent`.
5. r0 c0-c39   Button hit target -- the whole forced allocation.
```

```text
── chars ──
▐Touch target fills available width    ▌
── style ──
ABBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBCCCCA
── legend ──
.  default
A  fg=accent
B  fg=contrast bg=accent bold
C  bg=accent
```

### Intent

- Roles: `nil` (the default intent), `.cancel`, and `.destructive`.
- Default action: `.keyboardShortcut(.defaultAction)` (SwiftUI spelling) binds Return. A
  cancel button pairs with `.keyboardShortcut(.cancelAction)` (Esc). Each fires when the
  focused responder in the same focus section does not consume the key, and KeyLegend
  lists it (owner decision, 2026-10-10).
- Intent colour C: normal and default action use `accent`; cancel uses `secondary`;
  destructive uses the `error` tone, which `.destructive` maps to (owner decision,
  2026-10-10; see Destructive under States).

### Emphasis

- `.filled`: solid fill in C; label `contrast` bold.
- `.tinted`: faint fill derived from C; label in C.
- `.plain`: label only. Normal and default-action plain labels use `primary`; cancel and
  destructive keep their intent colour (owner decision, 2026-10-10). Plain keeps the
  shape's footprint with blank ends, so switching emphasis never changes layout. Brackets,
  box, and custom glyphs still draw.
- Default: a button with `.keyboardShortcut(.defaultAction)` resolves to `.filled`; every
  other button resolves to `.tinted`. An explicit `.buttonStyle(_:)` on the button or an
  ancestor wins. There is no public `.automatic`.
- Closed set: `.filled`, `.tinted`, and `.plain` are the only emphasis styles in 1.0. An
  app-supplied `ButtonStyle` protocol is deferred with Toggle's `ToggleStyle` to the
  [Slice 7](../../docs/Spec.md#slice-7-catalog-integration--list-section-and-controlled-widgets)
  style contract (owner decision, 2026-10-10).

Colour roles: the roles `primary`, `secondary`, `accent`, `focus`, `disabled`, and
`destructive` are defined in [tokens.md](../tokens.md#roles). `contrast` is `on(R)` inside
`solid(R)`, `faint(R)` is the tinted fill, and `disabled.fill` and `disabled.label` are
the disabled fill roles ([composite styles](../tokens.md#composite-styles),
[fill roles](../tokens.md#fill-roles)). No other token names are used.

Intent colour runs across each row of the intents fixture below; emphasis runs down it.

#### Intents and emphasis

```wireframe 24x3
▐Save▌ ▐Cancel▌ ▐Delete▌
▐Save▌ ▐Cancel▌ ▐Delete▌
 Save   Cancel   Delete
```

```text
Callouts (24x3, 0-based):
1. r0 c0-c5    Filled, normal -- `accent` caps and fill; `contrast` bold label.
2. r0 c7-c14   Filled, cancel -- `secondary` caps and fill; `contrast` bold label.
3. r0 c16-c23  Filled, destructive -- `destructive` caps and fill; `contrast` bold label.
4. r1          Tinted, each intent -- faint fill of the intent colour; label in the intent colour.
5. r2          Plain, each intent -- label only, blank ends; normal `primary`, cancel `secondary`, destructive `destructive`.
```

```text
── chars ──
▐Save▌ ▐Cancel▌ ▐Delete▌
▐Save▌ ▐Cancel▌ ▐Delete▌
 Save   Cancel   Delete
── style ──
ABBBBA.CDDDDDDC.EFFFFFFE
GHHHHG.IJJJJJJI.KLLLLLLK
.MMMM...CCCCCC...EEEEEE.
── legend ──
.  default
A  fg=accent
B  fg=contrast bold bg=accent
C  fg=secondary
D  fg=contrast bold bg=secondary
E  fg=destructive
F  fg=contrast bold bg=destructive
G  fg=faint(accent)
H  fg=accent bg=faint(accent)
I  fg=faint(secondary)
J  fg=secondary bg=faint(secondary)
K  fg=faint(destructive)
L  fg=destructive bg=faint(destructive)
M  fg=primary
```

### Shape

`.buttonBorderShape(_:)` chooses the ends. Shape and emphasis are independent; the filled
shapes fixture below shows filled emphasis on each shape.

| Shape                                      | Nerd Font                                                                                                                                        | Unicode                                                                               | ASCII                                         | NO_COLOR                                                       |
| ------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------- | --------------------------------------------- | -------------------------------------------------------------- |
| `.squared` (default)                       | `▐`/`▌` half blocks in the fill colour: fill reaches half a cell past the label                                                                  | same                                                                                  | falls back to `.rectangle`                    | half blocks in default foreground around a reverse-video label |
| `.capsule`                                 | Powerline round caps U+E0B6/U+E0B4 in the fill colour                                                                                            | falls back to `.squared`                                                              | falls back to `.rectangle`                    | caps in default foreground around a reverse-video label        |
| `.rectangle`                               | one full fill cell each side                                                                                                                     | same                                                                                  | same                                          | reverse-video padded label                                     |
| `.brackets`                                | `[label]`: only the label takes the fill; the brackets are unfilled, in the intent colour (plain: the label colour) (owner decision, 2026-10-10) | same                                                                                  | same                                          | `[` reverse-video label `]`                                    |
| `.box`                                     | three rows: light border in C around the label; interior per emphasis (filled: solid fill; tinted: faint fill; plain: none)                      | same                                                                                  | `+`, `-`, `\|`                                | border and reverse-video label                                 |
| `.custom(leading:trailing:unicode:ascii:)` | the app's `leading`/`trailing` glyphs in the fill colour, like caps                                                                              | the optional `unicode:` pair when the main glyphs need a Nerd Font, else `.rectangle` | the optional `ascii:` pair, else `.rectangle` | as the charset, around a reverse-video label                   |

`.squared` and `.capsule` share a footprint (label + 2 cells), as do `.rectangle`,
`.brackets`, and `.custom`. `.box` is label + 4 cells wide and 3 rows tall: its border
ring plus one interior cell on each side of the label.

Custom fallback pairs are optional and per charset (owner decision, 2026-10-10):

```swift
Button("Save") { save() }
    .buttonBorderShape(.custom(
        leading: "\u{E0B2}",
        trailing: "\u{E0B0}",
        unicode: ("<", ">"),
        ascii: ("<", ">")
    ))
```

A fallback pair is text, not a fill edge, so it draws unfilled in the intent colour, like
brackets. A charset with no pair draws `.rectangle` ends.

#### Filled shapes

```wireframe 30x1
▐Save▌  Save   Save   [Save]
```

```text
Callouts (30x1, 0-based):
1. r0 c0-c5    Squared -- half blocks `▐` and `▌` in `accent`; the fill reaches half a cell past the label.
2. r0 c8-c13   Capsule (Nerd Font) -- Powerline round caps U+E0B6 and U+E0B4 in `accent`; without a Nerd Font this falls back to squared.
3. r0 c16-c21  Rectangle -- one full `accent` fill cell on each side of the label.
4. r0 c24-c29  Brackets -- `[` and `]` unfilled in `accent`; only the label takes the fill.
```

```text
── chars ──
▐Save▌  Save   Save   [Save]
── style ──
ABBBBA..ABBBBA..DBBBBD..ABBBBA
── legend ──
.  default
A  fg=accent
B  fg=contrast bold bg=accent
D  bg=accent
```

#### Box

The box is three rows. Its border is light in C at rest and heavy in `focus` when focused
([focus border rule 1](../primitives/border.md#focus-border)). The heavy focus border wins
over the `rounded` that tokens.md's retired `focus.border` row named; the focus rules are
in [Focus](../tokens.md#focus), rule 1 (owner decision, 2026-10-10). Its interior follows
the emphasis: filled takes a solid fill, tinted takes a faint fill, and plain has none.
Below three rows the box falls back to `.squared`, keeping one-row geometry and the label
(owner decision, 2026-10-10).

```wireframe 17x3
┌──────┐ ┏━━━━━━┓
│ Save │ ┃ Save ┃
└──────┘ ┗━━━━━━┛
```

```text
Callouts (17x3, 0-based):
1. r0-r2 c0-c7   Box, tinted, rest -- light border in `accent`; interior `faint(accent)` fill at c1 and c6; label `accent` at c2-c5.
2. r0-r2 c9-c16  Box, tinted, focused -- heavy border in `focus`; interior `faint(focus)` fill; label `focus` bold.
```

```text
── chars ──
┌──────┐ ┏━━━━━━┓
│ Save │ ┃ Save ┃
└──────┘ ┗━━━━━━┛
── style ──
AAAAAAAA.GGGGGGGG
ADCCCCDA.GHIIIIHG
AAAAAAAA.GGGGGGGG
── legend ──
.  default
A  fg=accent
C  fg=accent bg=faint(accent)
D  bg=faint(accent)
G  fg=focus
H  bg=faint(focus)
I  fg=focus bold bg=faint(focus)
```

#### Brackets

Brackets fill only the label. Under focus, the brackets switch to `focus` with the rest of
the intent colour.

```wireframe 13x2
[Save] [Save]
[Save] [Save]
```

```text
Callouts (13x2, 0-based):
1. r0 c0-c5   Brackets, filled, rest -- `[` and `]` in `accent`; label `contrast` bold on the `accent` fill.
2. r0 c7-c12  Brackets, filled, focused -- brackets in `focus`; label `contrast` bold on the `focus` fill (`solid(focus)`, a default-foreground chip).
3. r1 c0-c5   Brackets, tinted, rest -- brackets in `accent`; label `accent` on the faint fill.
4. r1 c7-c12  Brackets, tinted, focused -- brackets in `focus`; label `focus` bold on `faint(focus)`.
```

```text
── chars ──
[Save] [Save]
[Save] [Save]
── style ──
ABBBBA.GHHHHG
ACCCCA.GIIIIG
── legend ──
.  default
A  fg=accent
B  fg=contrast bold bg=accent
C  fg=accent bg=faint(accent)
G  fg=focus
H  fg=contrast bold bg=focus
I  fg=focus bold bg=faint(focus)
```

#### Custom

```wireframe 6x2
Save
<Save>
```

```text
Callouts (6x2, 0-based):
1. r0 c0-c5  Custom, Nerd Font -- `leading` U+E0B2 and `trailing` U+E0B0 in `accent`, drawn like caps; the label takes the fill.
2. r1 c0-c5  Custom, `unicode:` and `ascii:` pair `("<", ">")` -- unfilled `accent` pair, like brackets; the label takes the fill. A charset with no pair draws `.rectangle` ends.
```

```text
── chars ──
Save
<Save>
── style ──
ABBBBA
ABBBBA
── legend ──
.  default
A  fg=accent
B  fg=contrast bold bg=accent
```

#### ASCII

ASCII drops every cap. Squared and capsule fall back to `.rectangle`. Box uses `+`, `-`,
and `|`. Focus adds bold (focus rule 6); a focused plain label is bold without underline.

```wireframe 30x1
 Save    Save    Save    Save
```

```text
Callouts (30x1, 0-based):
1. r0 c0-c5    Filled, rest -- squared falls back to `.rectangle`: one full `accent` fill cell each side; `contrast` bold label.
2. r0 c8-c13   Tinted, rest -- rectangle on a faint `accent` fill; `accent` label.
3. r0 c16-c21  Filled, focused -- `solid(focus)` chip (default foreground); `contrast` bold label. Bold is the ASCII focus signal (focus rule 6).
4. r0 c24-c29  Plain, focused -- no fill; label in `focus`, bold, no underline.
```

```text
── chars ──
 Save    Save    Save    Save
── style ──
DBBBBD..EFFFFE..GHHHHG...IIII.
── legend ──
.  default
B  fg=contrast bold bg=accent
D  bg=accent
E  bg=faint(accent)
F  fg=accent bg=faint(accent)
G  bg=focus
H  fg=contrast bold bg=focus
I  fg=focus bold
```

```wireframe 6x3
+----+
| Go |
+----+
```

```text
Callouts (6x3, 0-based):
1. r0-r2 c0-c5  Button hit target -- ASCII box floor for `Text("Go")`: `+`, `-`, and `|` border around the label, one interior cell each side.
```

## States

State changes sit on top of emphasis and shape, with the same rule for every emphasis. The
states fixture below shows each state on the three emphases. The pressed and hovered rows
are shown on the idle base. A focused button also takes the pressed trade, on its focused
look (owner decision, 2026-10-10).

### States fixture

```wireframe 20x5
▐Save▌ ▐Save▌  Save
▐Save▌ ▐Save▌  Save
▐Save▌ ▐Save▌  Save
▐Save▌ ▐Save▌  Save
▐Save▌ ▐Save▌  Save
```

```text
Callouts (20x5, 0-based):
1. r0  Idle, enabled -- filled c0-c5 (`accent` caps and fill, `contrast` bold label); tinted c7-c12 (`faint(accent)` caps and fill, `accent` label); plain c14-c19 (`primary` label, blank ends).
2. r1  Focused -- filled takes `solid(focus)`, a default-foreground chip, with a `contrast` bold label; tinted takes `faint(focus)` with a bold `focus` label; plain underlines its label in `focus`.
3. r2  Pressed -- filled takes the tinted look and tinted takes the filled look; plain turns its label bold.
4. r3  Hovered -- every label is underlined; fills and caps do not change.
5. r4  Disabled -- caps and fill in `disabled.fill`; labels in `disabled.label`; unfilled glyphs in `disabled`.
```

```text
── chars ──
▐Save▌ ▐Save▌  Save
▐Save▌ ▐Save▌  Save
▐Save▌ ▐Save▌  Save
▐Save▌ ▐Save▌  Save
▐Save▌ ▐Save▌  Save
── style ──
ABBBBA.CDDDDC..EEEE.
FGGGGF.HIIIIH..JJJJ.
CDDDDC.ABBBBA..KKKK.
ALLLLA.CMMMMC..NNNN.
OPPPPO.OPPPPO..QQQQ.
── legend ──
.  default
A  fg=accent
B  fg=contrast bold bg=accent
C  fg=faint(accent)
D  fg=accent bg=faint(accent)
E  fg=primary
F  fg=focus
G  fg=contrast bold bg=focus
H  fg=faint(focus)
I  fg=focus bold bg=faint(focus)
J  fg=focus underline
K  fg=primary bold
L  fg=contrast bold underline bg=accent
M  fg=accent underline bg=faint(accent)
N  fg=primary underline
O  fg=disabled.fill
P  fg=disabled.label bg=disabled.fill
Q  fg=disabled.label
```

- **Focused:** explicit `.focusable(id).focused(binding, equals: id)` injects
  `EnvironmentValues.isFocused` below the modifier. Every cell that carries the intent
  colour switches to `focus`. Filled takes `solid(focus)`, a default-foreground chip, with
  a `contrast` bold label. Tinted takes `faint(focus)` and a bold `focus` label (owner
  decision, 2026-10-10; focus colour owner decision, 2026-10-19). Plain underlines its
  label in `focus` (owner decision, 2026-10-10). Brackets and box borders switch to
  `focus` too; a focused box draws a heavy border. NO_COLOR focus is an underline; ASCII
  focus adds bold (focus rule 6).
- **Pressed:** for phased activation input, `isPressed` is set from down until the
  matching release, cancellation, focus loss, disablement, or node removal. Filled and
  tinted trade looks while pressed: a pressed filled button takes the tinted look, and a
  pressed tinted button takes the filled look. Plain turns its label bold (owner decision,
  2026-10-10). A focused and pressed button applies the trade to its focused look:
  filled-focused shows the `faint(focus)` fill, and tinted-focused shows the
  `solid(focus)` chip (owner decision, 2026-10-10). A legacy press-only `Enter` or `Space`
  invokes and clears it during that same dispatch, so it cannot remain pressed.
- **Hovered:** the label is underlined; fills, caps, and borders do not change (owner
  decision, 2026-10-10). Hover needs pointer-move input. Button requests it through its
  built-in hover style; a view with no hover consumer in its subtree does not request it.
- **Disabled:** every visible cell takes a disabled role. Fill cells and caps use
  `disabled.fill`; labels use `disabled.label`; unfilled glyphs (brackets, box border) use
  `disabled`. The fill is darker and the label lighter than the first lab draft, for
  readable contrast (owner decision, 2026-10-10). A disabled button is absent from the
  focusable list and never presses; see the Key and Mouse tables.
- **Destructive:** the `.destructive` role draws the `error` tone in every emphasis. It is
  one colour with `destructive`, the environment role name. It changes styling only, not
  event semantics, and carries no underline: `destructive` is the `error` Style with no
  underline (owner decision, 2026-10-19; [hue roles](../tokens.md#hue-roles)). Focus and
  pressed apply to it the same way they apply to any intent colour.
- **Overflow:** the label is chrome and stays on one row (owner decision, 2026-10-18). A
  default textual label is a `Text` with `.lineLimit(1)` applied by Button itself, so an
  app's inherited `lineLimit` never reaches it, and it tail-truncates in the slot assigned
  by the chosen shape. It never wraps, whatever the height proposal, because a second row
  would change the shape's one-row geometry. Custom labels may choose a layout that still
  fits their assigned rectangle.
- **Empty label:** valid. Squared, capsule, rectangle, brackets, and custom measure 2x1
  (ends or brackets only). Plain squared measures 2x1 with blank ends. Box measures 4x3.
- **Pointer and touch:** a primary contact is valid only if press and release hit the same
  `Button hit target` node. A touch contact receives the final allocated width, including
  a parent-forced width as in the 40x1 Sizing row.

### NO_COLOR

Filled and tinted both use reverse video, so emphasis levels look alike without colour
(owner decision, 2026-10-10). Plain is plain text. Focus is an underline. Disabled is dim.
Ends and brackets stay in the default foreground. Intents look alike under NO_COLOR; that
is the accepted cost of the mode.

```wireframe 13x3
▐Save▌ ▐Save▌
▐Save▌ ▐Save▌
 Save   Save
```

```text
Callouts (13x3, 0-based):
1. r0-r1 c0-c5   Filled and tinted, rest -- default-foreground half blocks around a reverse-video label.
2. r0-r1 c7-c12  Filled and tinted, focused -- the same, with an underline added to the label.
3. r2 c0-c5      Plain, rest -- unadorned label, no reverse video.
4. r2 c7-c12     Plain, focused -- underlined label.
```

```text
── chars ──
▐Save▌ ▐Save▌
▐Save▌ ▐Save▌
 Save   Save
── style ──
.BBBB...CCCC.
.BBBB...CCCC.
........DDDD.
── legend ──
.  default
B  reverse
C  reverse underline
D  underline
```

## State model

| State                     | Owner       | Type                                                                                            | Reset or clamp rule                                                                                                                                                                                                                                                                                                                                                                                                           |
| ------------------------- | ----------- | ----------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| is enabled                | Environment | `Bool`                                                                                          | Read on every reconciliation. A transition to `false` clears `isPressed`, removes the node from focusability, and prevents activation immediately; a disabled button renders as not hovered.                                                                                                                                                                                                                                  |
| current button style      | Environment | `ButtonStyle` (built-in `.filled`, `.tinted`, `.plain`)                                         | Read on every reconciliation; changing it recomposes from the same label, role, enabled, focus, and press inputs without retaining a previous style.                                                                                                                                                                                                                                                                          |
| current button shape      | Environment | `ButtonBorderShape` (`.squared`, `.capsule`, `.rectangle`, `.brackets`, `.box`, `.custom(...)`) | Read on every reconciliation; changing it recomposes from the same label and style inputs.                                                                                                                                                                                                                                                                                                                                    |
| semantic roles            | Environment | `primary`, `secondary`, `accent`, `focus`, `disabled`, and `destructive` full `Style` values    | Read on every render; nearest environment value wins under Slice 3 style inheritance. Key spellings land with the style environment in plan 032 step 9.1, where [tokens.md](../tokens.md) maps each token family onto one environment key.                                                                                                                                                                                    |
| is focused                | Environment | `Bool`                                                                                          | Injected below the explicit `.focusable` modifier from the FocusManager's live identity; Button reads it during rendering and checks `ResponderContext.isFocused` for events. Focus at paint is key E2: a focused button switches every cell that carries the intent colour to `focus` as described under States.                                                                                                             |
| is pressed                | NodeState   | `Bool`                                                                                          | Interaction in flight (key D7). Set for primary down or the down phase of enabled phased keyboard activation. Clear on its matching release, cancellation, focus loss, disablement, node removal, and every update where the node is not focused. A legacy press-only `Enter` or `Space` event invokes the action once and clears `isPressed` before its dispatch returns; it never represents app work or action completion. |
| is hovered                | derived     | `Bool`                                                                                          | Read at render from the graph-owned hover target (key F4): true while the last pointer move hit this node and the button is enabled. Never stored in NodeState or a binding. The graph clears it on focus loss, motion-tracking disable, and node removal. Requires pointer-move input, requested through the built-in hover style (owner decision, 2026-10-10).                                                              |
| label size and truncation | derived     | `TerminalSize` and rendered grapheme range                                                      | Recomputed from the proposed label slot on every layout; clamp to the allocated rectangle and use tail truncation (`.lineLimit(1)` pinned by Button) for default text.                                                                                                                                                                                                                                                        |

The role, label closure, and action closure are immutable widget configuration, not
retained business state. `isPressed` and `isHovered` are supplied to styles solely as
visual interaction feedback; custom styles cannot turn them into an alternate activation
mechanism. Hover is graph-owned, as focus is (key F4): Button derives `isHovered` at
render, as [List](list.md#state-model) derives its hovered row, and mirrors nothing into
`NodeState`. How rendering reads the hover target lands in plan 032 step 11.2 (see Open
questions).

## Key table

| Key                       | Precondition                                                                                                                                                    | Effect                                                                                                                                                                                                                                                                                       | Consumed |
| ------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- |
| Enter                     | focused and is enabled                                                                                                                                          | For a phased key stream, down sets `isPressed`; its matching release invokes the app action once only if focus and enabled state still hold, then clears `isPressed`. For a legacy press-only event, invoke the app action once on that press and clear `isPressed` before dispatch returns. | yes      |
| Space                     | focused and is enabled                                                                                                                                          | For a phased key stream, down sets `isPressed`; its matching release invokes the app action once only if focus and enabled state still hold, then clears `isPressed`. For a legacy press-only event, invoke the app action once on that press and clear `isPressed` before dispatch returns. | yes      |
| Enter                     | focused and is enabled is false                                                                                                                                 | Does not mutate `isPressed` or invoke the action; bubbles to ancestors.                                                                                                                                                                                                                      | no       |
| Space                     | focused and is enabled is false                                                                                                                                 | Does not mutate `isPressed` or invoke the action; bubbles to ancestors.                                                                                                                                                                                                                      | no       |
| printable characters      | focused                                                                                                                                                         | Does not mutate Button state; bubbles to ancestors.                                                                                                                                                                                                                                          | no       |
| Esc                       | is pressed is true                                                                                                                                              | Cancels the pending visual press by clearing `isPressed`; does not invoke the action.                                                                                                                                                                                                        | no       |
| Return (`.defaultAction`) | the button is enabled and bound with `.keyboardShortcut(.defaultAction)`; the focused responder in its focus section does not consume Return                    | Invokes the action once for the Return press.                                                                                                                                                                                                                                                | yes      |
| Esc (`.cancelAction`)     | the button is enabled, bound with `.keyboardShortcut(.cancelAction)`, and `isPressed` is false; the focused responder in its focus section does not consume Esc | Invokes the action once for the Esc press.                                                                                                                                                                                                                                                   | yes      |

Press/release pairing uses the normalized key-event phase supplied below the public key
name when that phase is available. A legacy keyboard event has only its press phase, so it
invokes exactly once during that dispatch and clears `isPressed` before returning. A
release after the button lost focus, became disabled, or was removed only clears its
ephemeral press state and cannot invoke the action.

## Mouse table

| Event        | Region            | Precondition        | Effect                                                                                                                                                                                                                                                              | Consumed |
| ------------ | ----------------- | ------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- |
| click        | Button hit target | is enabled          | Slice 5 first focuses the node when it is focusable; an internal primary down sets `isPressed`, and primary release invokes the app action once only when both points hit this same node, then clears `isPressed`.                                                  | yes      |
| click        | Button hit target | is enabled is false | Does not focus, press, or invoke; bubbles to an ancestor.                                                                                                                                                                                                           | no       |
| double-click | Button hit target | is enabled          | Has no distinct Button gesture; each constituent valid primary same-node click follows the `click` row and therefore invokes once.                                                                                                                                  | yes      |
| drag         | Button hit target | is pressed is true  | Clears visual `isPressed` when release is outside this node; never invokes the action for that release.                                                                                                                                                             | no       |
| move         | Button hit target | is enabled          | The graph makes this node its hover target on entry and clears it on exit; Button derives `isHovered` from that target at render and stores nothing (key F4). Requires pointer-move input, requested through the built-in hover style (owner decision, 2026-10-10). | no       |

The raw primary stream is internal so the built-in and custom style paths share the same
press feedback. The public pointer contract is Slice 5's same-node tap semantics, not a
drag threshold or label-glyph hit test.

## Sizing

Results name the shape and label. A parent `frame` may allocate a larger rectangle after
measurement; the Button node always keeps that final rectangle as its hit target. Filled
and tinted fills span a forced horizontal allocation with their ends at its edges, and the
label stays at the leading end. Plain keeps blank ends at the allocation edges.

| Proposal  | Result | Rule                                                                                                                                                                |
| --------- | ------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| nil x nil | 6x1    | `.squared`, `Text("Save")`: label plus one end cell on each side.                                                                                                   |
| nil x nil | 6x1    | `.plain`, `.squared`, `Text("Save")`: plain keeps the shape footprint with blank ends, so switching emphasis never changes layout.                                  |
| nil x nil | 6x1    | `.brackets`, `Text("Save")`: label plus two bracket cells.                                                                                                          |
| nil x nil | 8x3    | `.box`, `Text("Save")`: label plus one interior cell each side plus the one-cell border ring, three rows.                                                           |
| nil x nil | 8x1    | `.squared`, horizontal padding composed inside the label builder on `Text("Save")`: the padding adds two label-slot cells before the squared ends.                  |
| nil x nil | 4x1    | `.squared`, `Text("Go")`: the floor for a two-cell label.                                                                                                           |
| nil x nil | 6x3    | `.box`, `Text("Go")`: the floor for a two-cell label.                                                                                                               |
| nil x nil | 8x2    | `.box`, `Text("Save")` below three rows: falls back to `.squared`; one-row geometry and label kept, so the label-hugging rule gives 6x1.                            |
| 6x1       | 6x1    | `.squared`, `Text("Save")`: tight fit at natural size.                                                                                                              |
| 5x1       | 5x1    | `.squared`, `Text("Save")`: label slot constrained to three cells; tail truncation gives `Sa…` and the one-row geometry is kept.                                    |
| 3x1       | 3x1    | `.squared`, `Text("Save")`: under the natural width; label slot constrained to one cell, so only the truncation mark remains.                                       |
| 80x24     | 6x1    | `.squared`, `Text("Save")`: extra available space does not make a label-hugging button grow.                                                                        |
| 40x1      | 40x1   | `.squared` filled, forced allocation with `Text("Touch target fills available width")`: the ends and fill span the full allocation.                                 |
| 13x1      | 13x1   | `.squared`, `Text("Long label continues")`: label slot is eleven cells; tail truncation with `…`.                                                                   |
| 13xnil    | 13x1   | `.squared`, `Text("Long label continues")`: a nil height does not make the label wrap; chrome stays one row, tail truncation with `…` (owner decision, 2026-10-18). |

## Environment

`Button` consumes the planned `isEnabled`, `buttonStyle`, `buttonBorderShape`, and role
environment values. The role values are exactly `primary`, `secondary`, `accent`, `focus`,
`disabled`, and `destructive`. Each is a complete `Style`, not a foreground-colour alias,
so it can carry foreground, background, and emphasis coherently. `contrast` is `on(R)`
inside `solid(R)`, `faint(R)` is the tinted fill, and `disabled.fill` and `disabled.label`
are the disabled fills ([composite styles](../tokens.md#composite-styles),
[fill roles](../tokens.md#fill-roles)). The visual glyph vocabulary comes from
[tokens](../tokens.md): `light`, `heavy`, `ascii`, and `truncation.mark`. Exact
environment-key and type-erasure signatures are deferred to plan 032 steps 9.1 and 13.1
(see Open questions).

There is no Button-specific padding property. To produce `[ Save ]`, compose the shared
layout `padding` modifier inside the label builder; to add space around a Button in a row
or stack, compose that modifier outside the Button. This keeps content insets in the
shared layout vocabulary and lets every shape and emphasis receive the same supplied
label.

## Primitive dependencies

- [`Text` and its truncation policy](../primitives/text.md#progressive-slice-sequence) —
  needed for default textual labels, composed label padding, and grapheme-safe overflow
  behavior; Text itself arrives in Slice 1 and its wrapping/truncation features in
  Slice 3.
- [`Border` decoration and `Style`](../../docs/Spec.md#slice-3-styling-text-wrapping-and-decoration)
  — needed for `.box`, the focus border treatment, and the semantic Styles; available with
  Slice 3.
- [Focus manager and responder context](../../docs/Spec.md#slice-4-focus-and-key-routing-the-responder-system)
  — needed for explicit focus and Enter/Space routing; available with Slice 4.
- [Mouse hit testing](../../docs/Spec.md#slice-5-mouse-and-hit-testing) — needed for
  primary same-node activation, click-to-focus, hover, and touch-width hit geometry;
  available with Slice 5.

`Form` and `Outline` are not Button dependencies. Source browsing or source-mapping
affordances are explicitly post-1.0 and are not implied by a Button label or action.

## Progressive slice sequence

1. **After Slice 3:** Button may render an arbitrary label through `.filled`, `.tinted`,
   and `.plain`, with every shape it supports; resolve intent and semantic roles; measure
   its default textual label; and show the idle, intent, shape, NO_COLOR, and ASCII
   fixtures and the forced-width Sizing row (40x1). It does not claim focus or activate
   yet.
2. **After Slice 4:** an explicitly identified enabled Button joins the focus list. It
   receives `Enter` and `Space` through responder routing. For a phased key stream, down
   supplies pressed feedback and the matching release invokes once; for a legacy
   press-only event, that press invokes once and clears `isPressed` before returning.
   Unfocused or disabled input keeps bubbling. `.defaultAction` and `.cancelAction` fire
   on Return and Esc when the focused responder in the same focus section does not consume
   them (owner decision, 2026-10-10).
3. **After Slice 5:** Button requests pointer input, gains click-to-focus and valid
   primary same-node activation, and uses its final allocated frame as the touch-wide
   horizontal hit target. Forced-width buttons (Sizing 40x1) become interactive at this
   point. Hover becomes live through the pointer-move input its built-in hover style
   requests (owner decision, 2026-10-10).
4. **At the Phase 4 demo:** filled and tinted header and action rows, a plain menu
   specimen, a boxed standalone action, a `.custom` shape, and enabled, disabled, cancel,
   and destructive states are demonstrated together. No custom activation semantics, Form,
   Outline, or source browsing/mapping is required for this demo.

## Requirements

- `button renders its label with the squared shape by default` (anatomy fixture; Shape
  table)
- `button with the default action and no style modifier renders filled` (Emphasis:
  default)
- `button without a style modifier or default action renders tinted` (Emphasis: default)
- `explicit button style on an ancestor overrides the default emphasis` (Emphasis:
  default)
- `filled button fills its label with the intent colour and a bold contrast label`
  (Intents and emphasis, filled row)
- `tinted button draws a faint intent fill with an intent-coloured label` (Intents and
  emphasis, tinted row)
- `plain button keeps its shape footprint with blank ends` (Intents and emphasis, plain
  row; Sizing)
- `plain normal and default-action labels use primary while cancel and destructive keep their intent colour`
  (Intents and emphasis, plain row)
- `brackets fill only the label and draw unfilled brackets in the intent colour` (Brackets
  fixture)
- `capsule ends draw Powerline caps in the fill colour with a Nerd Font` (Filled shapes
  fixture; Shape table)
- `capsule falls back to squared half blocks without a Nerd Font` (Shape table, Unicode
  column)
- `squared and capsule fall back to rectangle ends in ASCII` (ASCII fixture; Shape table)
- `box draws a light three-row border around the label in the intent colour` (Box fixture,
  rest)
- `focused box draws its border heavy in focus` (Box fixture, focused)
- `box renders plus, hyphen, and vertical-bar glyphs in ASCII` (ASCII box fixture)
- `custom shape draws its fallback pair unfilled in the intent colour` (Custom fixture;
  Shape table)
- `custom shape without a fallback pair for the charset draws rectangle ends` (Custom
  fixture; Shape table)
- `focused filled button takes the focus fill with a bold contrast label` (States fixture,
  focused row)
- `focused filled button draws a default-foreground chip` (States fixture, focused row;
  [tokens.md#composite-styles](../tokens.md#composite-styles); owner decision, 2026-10-19)
- `focused tinted button takes a faint focus fill with a bold focus label` (States
  fixture, focused row)
- `focused plain button underlines its label in focus` (States fixture, focused row)
- `pressed filled button takes the tinted look and pressed tinted takes the filled look`
  (States fixture, pressed row)
- `pressed plain button renders its label bold` (States fixture, pressed row)
- `hovered button underlines its label` (States fixture, hovered row; state model: is
  hovered)
- `disabled button renders every visible cell in disabled roles` (States fixture, disabled
  row)
- `NO_COLOR filled and tinted buttons use reverse video` (NO_COLOR fixture)
- `NO_COLOR focus underlines the label` (NO_COLOR fixture)
- `ASCII focus adds bold to the label` (ASCII fixture, focused cells)
- `button applies destructive styling without changing activation behavior` (Intents and
  emphasis, destructive column)
- `squared minimum is four cells wide for a two-cell label` (Sizing: 4x1 row)
- `box minimum is six by three for a two-cell label` (Sizing: 6x3 row)
- `default textual button tail-truncates long label without changing its one-row height or wrapping`
  (Sizing: 13x1 row; state model: label size and truncation)
- `filled button uses its full forced width as its touch-wide hit target` (Sizing: 40x1)
- `button invokes its action exactly once for a phased enabled enter press and matching release`
  (Key table: Enter; state model: is pressed)
- `button invokes its action exactly once for a legacy enabled enter press-only event`
  (Key table: Enter; state model: is pressed)
- `button invokes its action exactly once for a phased enabled space press and matching release`
  (Key table: Space; state model: is pressed)
- `button invokes its action exactly once for a legacy enabled space press-only event`
  (Key table: Space; state model: is pressed)
- `legacy keyboard activation clears isPressed before dispatch returns` (Key table: Enter
  and Space; state model: is pressed)
- `button cancels a pending press when focus or enabled state changes before release`
  (state model: is pressed)
- `disabled button neither joins focus nor invokes or consumes activation input` (States
  fixture, disabled row; Key and Mouse tables: disabled click)
- `button activates a primary pointer only when press and release hit the same button node`
  (Mouse table: click)
- `button shows focus only for its explicit matching focus identity` (state model: is
  focused)
- `button exposes transient isPressed and isHovered only to style rendering` (state model:
  is pressed, is hovered)
- `button requests pointer-move input only through a hover consumer in its subtree` (Mouse
  table: move)
- `button hover underline clears when the graph clears its hover target on focus loss`
  (state model: is hovered; Mouse table: move)
- `default action fires on Return when the focused responder does not consume it` (Key
  table: Return)
- `cancel action fires on Esc when no press is pending and the focused responder does not consume it`
  (Key table: Esc)
- `focused and pressed button applies the pressed trade to its focused look` (States text,
  Pressed; state model: is pressed)
- `button style set is closed to filled, tinted, and plain in 1.0` (Emphasis)
- `box below three rows falls back to squared with one-row geometry` (Box; Degradation)

## Degradation

| Capability or space            | Button behavior                                                                                                                                                                                                                                                                                                                                                    |
| ------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Full capability (Nerd Font)    | Squared ends are half blocks; capsule ends are Powerline caps U+E0B6 and U+E0B4, both in the fill colour; box is light in the intent colour and heavy in `focus`; brackets and custom glyphs draw; filled, tinted, and plain use semantic roles; truncation is `…`.                                                                                                |
| Unicode without a Nerd Font    | Capsule falls back to squared half blocks; `.custom` uses its `unicode:` pair when given, else `.rectangle`; box and brackets are unchanged; roles are unchanged.                                                                                                                                                                                                  |
| `NO_COLOR`                     | Filled and tinted both use reverse video; plain is plain text; focus adds an underline; pressed plain is bold; hovered adds an underline; disabled is dim; ends and brackets stay in the default foreground. Intents look alike; this is the accepted cost of the mode.                                                                                            |
| 16-colour                      | All roles resolve to their slots columns in [roles](../tokens.md#roles): solid fills are reverse video; tinted fills take an ANSI 8 background on dark and none on light; focus is the default foreground in bold; destructive keeps the indexed `error` Style with no underline; disabled fill is ANSI 8 on dark and none on light (owner decisions, 2026-10-19). |
| ASCII-only                     | Squared and capsule fall back to `.rectangle`; brackets are unchanged; box uses `+`, `-`, and `\|`; `.custom` uses its `ascii:` pair when given, else `.rectangle`; truncation changes from `…` to `~`; focus adds bold, and a focused plain label is bold without underline.                                                                                      |
| Below a selected shape's floor | Squared, capsule, rectangle, brackets, and custom keep their one-row geometry and constrain the label slot. Box below three rows falls back to `.squared`, keeping one-row geometry and the label (owner decision, 2026-10-10). Interaction and enabled semantics do not degrade.                                                                                  |

## Open questions

No decision from the 2026-10-10 review lab remains open; those are recorded inline as
owner decisions. The items below are what the spec still leaves open, each deferred to an
exact place.

- **Touch normalization (deferred to
  [Phase 5](../../docs/Spec.md#phase-5--runtime--polish), owner decision, 2026-10-10):**
  the final platform input adapter may expose touch as a primary click or as a distinct
  contact event. The Button invariant is already fixed: the whole allocated frame is
  hit-tested and activation requires press and release on this node. The adapter decision
  is unblocked by the Phase 5 runtime's first touch-capable backend.
- **Reading hover at render (key F4, deferred to plan 032 step 11.2):** the graph owns the
  hover target and Button derives `isHovered` from it.
  [Slice 5](../../docs/Spec.md#slice-5-mouse-and-hit-testing) gives `onHover` handlers
  enter and exit, but does not yet expose the hover target to rendering the way the
  environment exposes `isFocused`. Step 11.2, which lands hover state, chooses that read.
  Button's hover look and its motion request do not depend on the choice.
- **Environment key signatures (deferred to plan 032 steps 9.1 and 13.1):** the role keys
  land with the style environment in step 9.1, where [tokens.md](../tokens.md) maps each
  token family onto one key; the key and type-erasure signatures behind `.buttonStyle(_:)`
  and `.buttonBorderShape(_:)` land with Button in step 13.1. The public spellings above
  are fixed.

Reviewed against the
[Phase 4 theses](../../docs/Spec.md#phase-4--view-layer-the-tessera-module): a Button is a
value whose label, role, and action closure are immutable configuration; its only retained
state is the `isPressed` NodeState of its own node, and it reads focus and hover from the
graph; the app owns every effect of the action; and its pointer and motion needs reach the
session as `TerminalRequirements`, never as mode changes.

## Inspiration

The Phase 4 demo should use filled and tinted Buttons for header and action rows, a plain
menu specimen, a boxed standalone action, and one `.custom` shape. These are review
targets for interaction consistency, not commitments to a toolbar, source browser, or
source-mapping UI.
