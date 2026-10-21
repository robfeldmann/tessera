---
kind: widget
status: specified
---

# Stepper

`Stepper<Value>` is Tessera's controlled bounded numeric control for values where `Value`
is `Comparable & Strideable` and `Value.Stride` is `Comparable & SignedNumeric`. The
application owns its `Binding<Value>` and supplies immutable closed-range and stride
configuration; Stepper only derives its formatted display and a pending step, while
retaining at most transient press feedback in `NodeState`. It presents two obvious
affordances for bounded arithmetic without privately retaining or silently normalizing the
numeric value.

This widget follows the controlled-widget rule in
[Slice 7](../../docs/Spec.md#slice-7-catalog-integration--list-section-controlled-widgets-and-the-showcase).
Its explicit focus and key delivery come from
[Slice 4](../../docs/Spec.md#slice-4-focus-and-key-routing-the-responder-system), and its
pointer delivery from [Slice 5](../../docs/Spec.md#slice-5-mouse-and-hit-testing).

## Prior art

- Ratatui's widgets in `~/Developer/ratatui/ratatui/main/ratatui-widgets/src/` provide
  compact terminal-control and layout vocabulary, but no direct Stepper contract. Copy
  their compact, adjacent-control presentation; reject application-owned event dispatch
  and any private numeric state because a Tessera Stepper writes its binding through the
  responder chain.
- Apple SwiftUI [Stepper](https://developer.apple.com/documentation/swiftui/stepper)
  supplies the bounded-value and increment/decrement vocabulary. Copy its generic numeric
  surface and single focusable control with directional adjustment; reject custom labels
  and platform-specific presentation variants.
- omp2's Form number field
  ([number field](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/form.rs#L910-L922))
  shows `◂ 4 ▸` while focused and the bare number otherwise. Copy its arrow glyphs and
  in-place arrows; reject hiding the arrows when unfocused, which the owner decided
  against (owner decision, omp2 review, 2026-10).

## API direction

The implemented public API is `Stepper<Value>`:

```swift
public struct Stepper<Value>: View
where Value: Comparable & Strideable,
      Value.Stride: Comparable & SignedNumeric {
    public init(
        value: Binding<Value>,
        in range: ClosedRange<Value>,
        step: Value.Stride = 1
    )

    public init<Format>(
        value: Binding<Value>,
        in range: ClosedRange<Value>,
        step: Value.Stride = 1,
        format: Format
    ) where Format: FormatStyle,
            Format.FormatInput == Value,
            Format.FormatOutput == String
}
```

Focus stays explicit at the call site:

```swift
Stepper(value: value, in: 0...10)
    .focusable(stepperFocusID)
    .focused(focused, equals: stepperFocusID)
```

Stepper renders from `EnvironmentValues.isFocused` and handles keys only when
`ResponderContext.isFocused` is true.

`step` MUST be positive (`step > .zero`); invalid configuration is a programmer error
before a Stepper node is created. For an in-range binding, each enabled user action
advances or retreats by that signed stride and clamps the resulting write to the supplied
closed range, so a final partial stride lands exactly on its endpoint. For fixed-width
integers whose `Stride` is `Int`, Stepper instead uses reporting-overflow arithmetic: it
converts the positive `Int` stride exactly to `Value`, and an unrepresentable stride
writes the requested range endpoint directly. The presentation is `◂ 42 ▸`: a decrement
arrow `◂`, one separator space, the formatted binding value, one separator space, and an
increment arrow `▸`. The arrows stay visible whether or not the Stepper is focused. The
default display is `String(describing: value)`; the format overload instead renders with
the supplied `FormatStyle`. Formatting is not a second binding or an editing surface, and
it preserves any app-supplied out-of-range value until the user activates a step.

The per-component demo for Stepper uses a decimal specimen: one `Double` `ratio` binding
with range `0...1` and step `0.25`. Its ratio summary and Stepper display decimal text,
then map the selected quarter deterministically to the existing
`FlexConstraint.ratio(Int, Int)` representation.

> Deferred: `StepperStyle`, custom chrome, and the `.compact` presentation land in a later
> slice. They must preserve this stepping and focus contract.

## Anatomy

Natural fixture: an enabled, unfocused Stepper with an interior value of `42`, inside the
range, so both arrows use `secondary`.

```wireframe 6x1
◂ 42 ▸
```

```text
Callouts (6x1, 0-based):
1. r0 c0-c5 Stepper hit target -- the one allocated, focusable node; it contains both
   arrows and the value slot.
2. r0 c0    decrement arrow -- `◂`; `secondary` while the value is in range.
3. r0 c2-c3 value slot -- formatted binding value; the default presentation reserves its
   full formatted width rather than silently rewriting it. Rendered in `primary`, the value
   role on enabled rows (owner decision, 2026-10-10). Atomic value, one row: it never
   wraps or truncates.
4. r0 c5    increment arrow -- `▸`; `secondary` while the value is in range.
```

> Wrap exception (rules 1 and 2): the value is atomic: it never wraps or truncates. The
> neighbouring label gives way first (owner decision, 2026-10-18). The arrows are chrome
> and stay on the value's row. Breaking the value across rows, or marking it with `…`,
> would show the user a number that is not the bound number.

Stepper has no label of its own: the label belongs to the host row
([LabeledContent](labeled-content.md) or a [Form](form.md) row), where it is content and
wraps (see [Row label wrapping](#row-label-wrapping)).

## States

### Mobile

`mobile` is the canonical 40x16 viewport. The Stepper retains its natural one-row,
label-hugging size at the top-left; the remaining cells are unoccupied viewport, not
component padding.

```wireframe 40x16
◂ 42 ▸















```

```text
Callouts (40x16, 0-based):
1. r0 c0-c5 Stepper hit target -- the complete 6-cell focusable control; it does not
   stretch merely because the viewport is wider.
2. r0 c0    decrement arrow -- available decrement action.
3. r0 c2-c3 value slot -- formatted interior binding value.
4. r0 c5    increment arrow -- available increment action.
5. r1-r15   Unoccupied viewport -- not Stepper output; blank buffer cells remain blank.
```

### Minimum

The declared normal-rendering floor is `4 + formatted value width` by one row (owner
decision, 2026-10-18): both arrows, both separators, and the whole formatted value. The
value is atomic, so it counts whole and is never clipped to fit. The fixture value `0` is
one cell, which gives `5x1`. A two-digit value gives `6x1`. This fixture uses the minimum
value `0`, so the decrement arrow sits in the disabled role in place and is inert.

```wireframe 5x1
◂ 0 ▸
```

```text
Callouts (5x1, 0-based):
1. r0 c0-c4 Stepper hit target -- declared component floor and the one focusable node.
2. r0 c0    decrement arrow -- `disabled` because the binding equals its configured
   minimum; it stays in place and does not activate.
3. r0 c2    value slot -- one-cell formatted minimum value.
4. r0 c4    increment arrow -- available increment action in `secondary`.
```

### Interior value

An interior value leaves both arrows available, both in `secondary`. The control remains
one focusable node, not three separately focusable buttons.

```wireframe 6x1
◂ 42 ▸
```

```text
Callouts (6x1, 0-based):
1. r0 c0-c5 Stepper hit target -- one focusable node for keyboard and pointer routing.
2. r0 c0    decrement arrow -- available decrement action in `secondary`.
3. r0 c2-c3 value slot -- formatted binding value `42`.
4. r0 c5    increment arrow -- available increment action in `secondary`.
```

### Maximum

At the configured maximum, the increment arrow stays in place and renders in `disabled`.
The decrement arrow remains available in `secondary`.

```wireframe 6x1
◂ 99 ▸
```

```text
Callouts (6x1, 0-based):
1. r0 c0-c5 Stepper hit target -- one focusable node despite an inert arrow.
2. r0 c0    decrement arrow -- available decrement action in `secondary`.
3. r0 c2-c3 value slot -- formatted maximum binding value `99`.
4. r0 c5    increment arrow -- `disabled` because the binding equals its configured
   maximum; it stays visible in place and does not activate.
```

### Row states

Owner decision, omp2 review, 2026-10. The Stepper sits in a labelled row. The accepted row
states below show every state the control takes. Six rows, top to bottom: focused at
minimum; focused in range; focused at maximum; unfocused in range; unfocused at minimum;
disabled. The decisions they encode:

- Arrows stay visible when unfocused, so the row still reads as a stepper that can be
  changed.
- An arrow at its limit switches to the `disabled` role and keeps its place, so the value
  never shifts sideways; in range both arrows are `secondary`.
- Focus is marked by the `❯` cursor and the bold `focus` label, not by the arrows. The
  host row draws both; Stepper paints no focus style of its own (owner decision,
  2026-10-10).
- A standalone Stepper is arrows plus value. Its label comes from
  [LabeledContent](labeled-content.md), and the host row owns the cursor (owner decision,
  2026-10-10).
- A disabled row renders its label, value and both arrows in `disabled` and cannot take
  focus.

```wireframe 40x6
❯ At minimum  ◂ 1 ▸
❯ In range    ◂ 4 ▸
❯ At maximum  ◂ 12 ▸
  Unfocused   ◂ 4 ▸
  Unfocused   ◂ 1 ▸
  Disabled    ◂ 4 ▸
```

```text
Callouts (40x6, 0-based; each row uses the same columns):
1. c0-c1    focus cursor `❯` -- `focus` on the focused row; blank on other rows. It is
            row chrome drawn by the host row, not by the Stepper.
2. c2-c13   row label -- `focus` bold when focused; `primary` when unfocused; `disabled`
            on the disabled row; content, wraps (see Row label wrapping). Host row chrome,
            not a Stepper part.
3. c14      decrement arrow `◂` -- `secondary` in range; `disabled` at the minimum and on the
            disabled row. Visible when unfocused.
4. c16      value slot -- one cell for values 0-9, two cells (c16-c17) for 10-99. Rendered
            in `primary` on enabled rows and `disabled` on the disabled row (owner decision,
            2026-10-10).
5. c18      increment arrow `▸` -- one cell after a one-digit value, c19 after a two-digit
            value; `secondary` in range; `disabled` at the maximum and on the disabled row.
```

Styled grid (owner review, verbatim):

```text
── chars ──
❯ At minimum  ◂ 1 ▸
❯ In range    ◂ 4 ▸
❯ At maximum  ◂ 12 ▸
  Unfocused   ◂ 4 ▸
  Unfocused   ◂ 1 ▸
  Disabled    ◂ 4 ▸
── style ──
AAFFFFFFFFFFFFXELEE
AAFFFFFFFFFFFFEELEE
AAFFFFFFFFFFFFEELLEX
..LLLLLLLLLLLLEELEE
..LLLLLLLLLLLLXELEE
..XXXXXXXXXXXXXEXEX
── legend ──
.  default
A  fg=focus
L  fg=primary
F  fg=focus bold
E  fg=secondary
X  fg=disabled
```

### Row label wrapping

The row label is content (owner decision, 2026-10-18): where the host row may take rows, a
label wider than its column word-wraps within the column, and a word wider than the column
breaks between graphemes. The Stepper's arrows and value stay on the label's first row and
are never wrapped, truncated, or pushed off the row: the label gives way first. The focus
cursor `❯` stays on the first row and the continuation row indents under the label.

```wireframe 19x2
❯ Retry       ◂ 4 ▸
  attempts
```

```text
Callouts (19x2, 0-based):
1. r0 c0-c1    focus cursor `❯` -- host row chrome, first row only.
2. r0 c2-c6    row label first row -- `Retry`; content, wraps. `Retry attempts` does not fit the 12-cell label column.
3. r1 c2-c9    row label continuation -- `attempts`, indented under the label's first column.
4. r0 c14-c18  Stepper -- `◂ 4 ▸`, atomic value, one row; chrome and value never wrap.
```

### Disabled

A disabled Stepper is absent from the focusable list, never activates, and leaves every
key and click unconsumed so an ancestor may handle it. Every visible cell uses `disabled`.
The labelled disabled row is in [Row states](#row-states); the bare control looks like
this.

```wireframe 5x1
◂ 4 ▸
```

```text
Callouts (5x1, 0-based):
1. r0 c0-c4 Stepper hit target -- rendered but not focusable or interactive.
2. r0 c0    decrement arrow -- `disabled` presentation and inert pointer region.
3. r0 c2    value slot -- `disabled` presentation of the unchanged binding value.
4. r0 c4    increment arrow -- `disabled` presentation and inert pointer region.
```

### Out-of-range binding value

An application may supply an out-of-range binding value. Stepper displays that value
through its selected format and never rewrites the binding during reconciliation. The next
enabled user step clamps the supplied value to `minimum...maximum` and writes that
in-range result; for example, either enabled step from a displayed `101` with maximum `99`
writes `99` rather than preserving `101`.

```wireframe 7x1
◂ 101 ▸
```

```text
Callouts (7x1, 0-based):
1. r0 c0-c6 Stepper hit target -- natural width expands for the three-cell value slot.
2. r0 c0    decrement arrow -- `secondary`; available because the value is not exactly the
   configured minimum.
3. r0 c2-c4 value slot -- verbatim formatted rendering of the app-owned out-of-range
   value `101`; no display clamp occurs.
4. r0 c6    increment arrow -- `secondary`; available because the value is not exactly the
   configured maximum; its next step writes a clamped value.
```

### Degraded

Under ASCII-only capability the arrows degrade to `<` and `>`, the glyphs omp2's Form
number field uses in ASCII. The owner confirmed this pair for Stepper (owner decision,
2026-10-10). `NO_COLOR` keeps the glyphs and positions and resolves roles to their
attribute-only fallbacks; 16-colour resolves them to their slots columns in
[roles](../tokens.md#roles).

```wireframe 6x1
< 42 >
```

```text
Callouts (6x1, 0-based):
1. r0 c0-c5 Stepper hit target -- unchanged ASCII geometry under degradation.
2. r0 c0    decrement arrow -- literal ASCII `<` in the resolved role.
3. r0 c2-c3 value slot -- formatted text retains its measured width and value.
4. r0 c5    increment arrow -- literal ASCII `>` in the resolved role.
```

### Deferred compact style

> Post-1.0 (owner decision, 2026-10-10): the `.compact` presentation is not part of 1.0.
> The fixture below predates the accepted `◂ ▸` arrows and is kept only as deferred
> intent; it is re-decided when that style is scheduled.

The deferred `.compact` style renders bare `−` and `+` affordances around the value. It
keeps the one focusable node, endpoint inertness, clamping, and out-of-range rules; only
the chrome is lighter. Its ideal width is `4 + formatted value width`.

```wireframe 6x1
− 42 +
```

```text
Callouts (6x1, 0-based):
1. r0 c0-c5 Stepper hit target -- the one focusable node.
2. r0 c0    decrement affordance -- bare `−`; `disabled` when the value is at minimum.
3. r0 c2-c3 value slot -- formatted binding value.
4. r0 c5    increment affordance -- bare `+`; `disabled` when the value is at maximum.
```

Under ASCII-only capability the deferred compact decrement affordance would use `-`; the
value and `+` are already ASCII-safe.

## State model

| State                  | Owner       | Type                  | Reset or clamp rule                                                                                                                                                                                                                                                                                                                                                                                       |
| ---------------------- | ----------- | --------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| value                  | Binding     | `Binding<Value>`      | App-owned source of truth. Reconciliation displays any supplied `Value` through its selected format. An enabled user step alone writes a value clamped to `minimum...maximum` through this binding.                                                                                                                                                                                                       |
| is enabled             | Environment | `Bool`                | Read on every reconciliation. `false` removes the node from focusability, clears `pressed affordance`, prevents activation, and leaves input unconsumed.                                                                                                                                                                                                                                                  |
| semantic Styles        | Environment | arrow and value roles | Read on every render. An arrow is `secondary` when available in range and `disabled` at its limit or when disabled; the enabled value is `primary` ([Row states](#row-states)). The label and `❯` cursor belong to the host row, not to Stepper.                                                                                                                                                          |
| is focused             | Environment | `Bool`                | Injected below the explicit `.focusable` modifier from the FocusManager's live identity; Stepper reads it during rendering and checks `ResponderContext.isFocused` for events. Focus is shown by the host row's cursor and bold `focus` label, never by the arrows.                                                                                                                                       |
| formatted value        | derived     | `String`              | Recompute on every update with either `String(describing: value)` or the supplied `FormatStyle`. It preserves the app-supplied value in display and never mutates the binding.                                                                                                                                                                                                                            |
| stepped value          | derived     | `Value`               | For an in-range value, advance or retreat by positive `Value.Stride` and clamp the write to `minimum...maximum`; a non-divisible final stride lands exactly on its endpoint. Fixed-width integers whose `Stride` is `Int` use reporting-overflow arithmetic and write the requested endpoint directly when that `Int` cannot be represented as `Value`. For an out-of-range value, write its range clamp. |
| decrement is available | derived     | `Bool`                | Recompute on every update; false only when `value` equals `minimum`, otherwise true so an out-of-range value can be repaired by the next user step.                                                                                                                                                                                                                                                       |
| increment is available | derived     | `Bool`                | Recompute on every update; false only when `value` equals `maximum`, otherwise true so an out-of-range value can be repaired by the next user step.                                                                                                                                                                                                                                                       |
| pressed affordance     | NodeState   | `StepperDirection?`   | Set only during a valid primary down or phased key down; clear on matching release, cancellation, focus loss, disablement, node removal, or when its affordance becomes unavailable. It never represents numeric data.                                                                                                                                                                                    |

`minimum`, `maximum`, and `step` are immutable initializer configuration, not widget
state. The closed range must have `minimum <= maximum`, and `step` must satisfy
`step > .zero`; both are checked before node creation.

## Key table

| Key                   | Precondition                                                  | Effect                                                                                      | Consumed |
| --------------------- | ------------------------------------------------------------- | ------------------------------------------------------------------------------------------- | -------- |
| Up                    | is focused and is enabled and increment is available          | Writes `stepped value` for increment through value binding, clamped to `minimum...maximum`. | yes      |
| Right                 | is focused and is enabled and increment is available          | Writes `stepped value` for increment through value binding, clamped to `minimum...maximum`. | yes      |
| Down                  | is focused and is enabled and decrement is available          | Writes `stepped value` for decrement through value binding, clamped to `minimum...maximum`. | yes      |
| Left                  | is focused and is enabled and decrement is available          | Writes `stepped value` for decrement through value binding, clamped to `minimum...maximum`. | yes      |
| Up                    | is focused and is enabled and increment is available is false | Leaves value binding unchanged at the maximum endpoint so an ancestor may handle the key.   | no       |
| Right                 | is focused and is enabled and increment is available is false | Leaves value binding unchanged at the maximum endpoint so an ancestor may handle the key.   | no       |
| Down                  | is focused and is enabled and decrement is available is false | Leaves value binding unchanged at the minimum endpoint so an ancestor may handle the key.   | no       |
| Left                  | is focused and is enabled and decrement is available is false | Leaves value binding unchanged at the minimum endpoint so an ancestor may handle the key.   | no       |
| Up, Right, Down, Left | is enabled is false                                           | Leaves value binding and pressed affordance unchanged; disabled nodes do not consume keys.  | no       |

## Mouse table

| Event | Region               | Precondition                                   | Effect                                                                                                              | Consumed |
| ----- | -------------------- | ---------------------------------------------- | ------------------------------------------------------------------------------------------------------------------- | -------- |
| click | decrement affordance | is enabled and decrement is available          | Sets the Stepper's explicitly composed focus identity, then writes decremented stepped value through value binding. | yes      |
| click | increment affordance | is enabled and increment is available          | Sets the Stepper's explicitly composed focus identity, then writes incremented stepped value through value binding. | yes      |
| click | decrement affordance | is enabled and decrement is available is false | Leaves explicitly composed focus identity, value binding, and pressed affordance unchanged at the minimum endpoint. | no       |
| click | increment affordance | is enabled and increment is available is false | Leaves explicitly composed focus identity, value binding, and pressed affordance unchanged at the maximum endpoint. | no       |
| click | decrement affordance | is enabled is false                            | Leaves explicitly composed focus identity, value binding, and pressed affordance unchanged; disabled input bubbles. | no       |
| click | increment affordance | is enabled is false                            | Leaves explicitly composed focus identity, value binding, and pressed affordance unchanged; disabled input bubbles. | no       |

A click on the value slot or either separator has no Stepper activation handler and is
unconsumed. A valid affordance click establishes explicit focus before it writes the one
clamped step, as required by [Slice 5](../../docs/Spec.md#slice-5-mouse-and-hit-testing).

## Sizing

The default Stepper is one row high and label-hugging. Its ideal width is the decrement
arrow, two separator cells, the full formatted value, and the increment arrow:
`4 + formatted value width`. It does not grow to fill extra proposal width. The value is
atomic (owner decision, 2026-10-18): no proposal wraps or truncates it, so a narrower
proposal reports the floor instead.

| Proposal                                             | Result | Rule                                                                                                                  |
| ---------------------------------------------------- | ------ | --------------------------------------------------------------------------------------------------------------------- |
| nil x nil with value `7`                             | 5x1    | Unconstrained ideal uses the one-cell value width plus both arrows and separators.                                    |
| nil x nil with value `1234`                          | 8x1    | Unconstrained ideal expands by the full four-cell formatted value width.                                              |
| 6x1 with value `42`                                  | 6x1    | Tight proposal exactly fits both arrows, separators, and the two-cell value.                                          |
| 4x1 with value `7`                                   | 5x1    | Under-floor proposal reports the declared 5x1 floor rather than clipping either arrow or the one-cell value.          |
| 4x1 with value `42`                                  | 6x1    | The floor is value-wide: both arrows and the whole two-cell value; the value never truncates.                         |
| 19x nil, host row, label `Retry attempts`, value `4` | 19x2   | The label wraps to `Retry` and `attempts` in its column; the Stepper stays 5x1 on the first row (Row label wrapping). |
| 40x16 with value `42`                                | 6x1    | Over-maximum proposal keeps the content-hugging 6x1 result; extra cells remain parent-owned.                          |

## Environment

Stepper consumes `isEnabled` and resolves its arrows from semantic roles: an available
arrow in range takes `secondary`, and an arrow at its limit or any part of a disabled
Stepper takes `disabled`. The enabled value slot takes `primary` (owner decision,
2026-10-10). Focus is not painted by Stepper's own Style; the host row shows the `❯`
cursor and the bold `focus` label. The default presentation uses `◂` and `▸`, and reports
its content width instead of truncating or wrapping the value, which is atomic. The host
row's label is content and inherits `lineLimit` and `truncationMode` from the environment;
the Stepper pins its own value to one row.

> Deferred: endpoint-specific affordance styling is decided above; `StepperStyle`,
> `truncation.mark` customization, and `.compact` style-specific degradation land in a
> later slice. Focus follows [tokens.md](../tokens.md#focus).

## Primitive dependencies

- [Text](../primitives/text.md) renders the formatted value and the arrow glyphs with
  their resolved roles.

## Requirements

- `stepper increments its binding from an interior value` (key table: Up).
- `stepper decrements its binding from an interior value` (key table: Down).
- `stepper leaves an increment key unconsumed at maximum` (key table: Up with increment
  unavailable).
- `stepper leaves a decrement key unconsumed at minimum` (key table: Down with decrement
  unavailable).
- `stepper clamps a non-divisible final increment exactly to maximum` (state model:
  stepped value; key table: Up).
- `stepper clamps a non-divisible final decrement exactly to minimum` (state model:
  stepped value; key table: Down).
- `stepper displays an app-supplied out-of-range value verbatim until user activation`
  (Out-of-range binding value wireframe; state model: out-of-range binding value).
- `stepper clamps an out-of-range value through its binding on user activation` (state
  model: stepped value; key table: Up or Down).
- `stepper applies a positive non-unit stride through its binding` (state model: stepped
  value; key table: Up).
- `stepper renders a bound value with its supplied format style` (state model: formatted
  value).
- `stepper keeps both arrows visible while unfocused` (Row states wireframe: unfocused
  rows; Anatomy).
- `stepper draws an arrow at its limit in the disabled role and keeps its place` (Minimum
  wireframe; Maximum wireframe; Row states: focused at minimum, focused at maximum,
  unfocused at minimum).
- `stepper draws both in-range arrows in the secondary role` (Interior value wireframe;
  Row states: focused in range, unfocused in range).
- `stepper marks focus with the host row's cursor and focus-role label, not the arrows`
  (Row states: focused rows; state model: is focused).
- `stepper focuses before increment-affordance activation` (mouse table: click increment
  affordance).
- `stepper leaves endpoint-affordance clicks unconsumed` (mouse table: click increment or
  decrement affordance when unavailable).
- `disabled stepper renders every part in the disabled role and leaves keys and clicks unconsumed`
  (Disabled wireframe; Row states: disabled row; key and mouse tables).
- `stepper reports its 5x1 ideal and tight size` (sizing: nil x nil with value `7`;
  sizing: 6x1).
- `stepper retains both arrows and a value cell at its declared 5x1 floor` (Minimum
  wireframe; sizing: 4x1).
- `stepper value never wraps or truncates and the label gives way first` (Wrap exception;
  Row label wrapping wireframe; sizing: 19x nil host row).
- `stepper floor is four cells plus the whole formatted value width` (Minimum wireframe;
  sizing: 4x1 with value `42`).

> Deferred: Compact-style rendering and its ASCII degradation land in a later slice with
> their own decision.

## Degradation

The default presentation uses `◂` and `▸`. Under ASCII-only capability the arrows degrade
to `<` and `>` (owner decision, 2026-10-10), so the 5x1 floor and the formatted value text
are preserved. `NO_COLOR` keeps the glyphs and positions, and resolves roles to their
attribute-only fallbacks from the [roles](../tokens.md#roles) table; a disabled arrow is
dim. 16-colour resolves roles to their slots columns
([degradation ladder](../tokens.md#degradation-ladder)). Below the floor
(`4 + formatted value width`), default Stepper reports its floor result rather than hiding
an arrow, truncating or wrapping the value, or creating a second interaction mode; a host
row's label wraps or marks its last visible row first.

> Deferred: The `.compact` style's `−` glyph degradation lands in a later slice.

## Open questions

- Arrow-direction consumption is **RESOLVED**: Up and Right consume an available
  increment; Down and Left consume an available decrement. At their corresponding
  endpoints they are unconsumed and bubble.
- **Resolved (owner decision, 2026-10-10).** The enabled value role is `primary`. Focus is
  the `❯` cursor and bold `focus` label, drawn by the host row; Stepper paints no focus
  style of its own. A standalone Stepper's label comes from `LabeledContent`. The ASCII
  fallback is `<` and `>`. The `.compact` style is post-1.0.

## Inspiration

A Stepper should expose bounded app-owned arithmetic as two obvious actions and make
endpoint behavior visible rather than silently retaining private numeric state.
