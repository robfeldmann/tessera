---
kind: primitive
status: ready
---

# Style modifiers

Style modifiers are stateless wrapper nodes that establish or override inherited terminal
`Style` attributes for a subtree. They are presentation-only: they add neither geometry,
state, focus, bindings, nor input handling. Their contract is the Slice 3
[styling contract](../../docs/Spec.md#slice-3-styling-text-wrapping-and-decoration).

## Prior art

- Ratatui `Stylize`: `~/Developer/ratatui/ratatui/main/ratatui-core/src/style/stylize.rs`
  provides fluent foreground, background, and modifier composition on styled values.
  Tessera adopts fluent value composition, not per-widget mutable style state.
- Ratatui `Color`: `~/Developer/ratatui/ratatui/main/ratatui-core/src/style/color.rs`
  distinguishes foreground and background color channels. Tessera resolves terminal
  capability changes through its token ladder.
- Tessera [Slice 3](../../docs/Spec.md#slice-3-styling-text-wrapping-and-decoration) owns
  the API and inheritance precedence.

## Anatomy

Style wrappers have no visible box geometry. The text glyphs below are therefore the same
before and after a modifier; the adjacent styled grids show the inherited cell attributes.

```wireframe 4x1
Text
```

```text
Callouts (4x1, 0-based):
1. r0 c0-3  descendant text glyphs; wrapper changes their resolved Style, not their cells
```

### Nested inheritance

```text
── chars ──
AB
── attributes ──
BA
Legend: B = bold from the ancestor `.bold()`; A = foreground from
`semantic.accent` added by the child. Both cells retain their source glyphs.
```

### Sibling isolation

```text
── chars ──
LR
── attributes ──
A.
Legend: A = foreground from `semantic.accent` on the left sibling; . = inherited
`semantic.primary` on the right sibling. A sibling wrapper never alters its peer.
```

### Explicit attribute override

```text
── chars ──
NO
── attributes ──
B-
Legend: B = bold from the ancestor `.bold()`; - = bold explicitly off from the child
`.bold(false)`. Both cells otherwise inherit `semantic.primary`.
```

### Whole-style merge

```text
── chars ──
MN
── attributes ──
SD
Legend: S = inherited complete `semantic.secondary` Style; D = child complete
`semantic.destructive` Style merged by `.style(_)`, replacing every attribute it supplies.
```

### Foreground and region fill

```text
── chars ──
INK·
── attributes ──
AABB
Legend: A = foreground from `semantic.accent` on descendant glyphs; B = background
from `.background(Color)` across the final allocated child region; · = an otherwise
empty cell represented visibly so the aligned grid can show the fill.
```

The region fill paints first, then descendant content paints over it. It is clipped to the
child's final allocated bounds and does not create a separate layout wrapper.

## Public API

Candidate spelling:

```swift
extension EnvironmentValues {
  public var defaultStyle: Style { get set }
}

extension View {
  public func foreground(_ color: Color) -> some View
  public func background(_ color: Color) -> some View
  public func bold(_ on: Bool = true) -> some View
  public func italic(_ on: Bool = true) -> some View
  public func underline(_ on: Bool = true) -> some View
  public func style(_ style: Style) -> some View
}
```

`defaultStyle` is the sole style environment key and contains a complete buffer `Style`
value. The buffer's `Style` is the only `Style` type; its fluent value API is coordinated
there, not in the view layer. The Slice 3
[merge rule](../../docs/Spec.md#slice-3-styling-text-wrapping-and-decoration) resolves per
attribute: the nearest ancestor's explicit value wins until a view supplies that attribute
itself. `.bold(false)` records bold as off; v1 has no sub-modifier negation. `.style(_:)`
merges every explicit attribute supplied by its argument under that same rule.

`.background(Color)` is the style wrapper's region fill and inherited background
attribute; it fills before descendants render. It is distinct from view-builder
[background](background.md), which is the primary-child-sized layering primitive. The
style wrapper has no hit-testing behavior; any later decorative view layer must explicitly
set `.allowsHitTesting(false)`, with routing deferred to
[Slice 5](../../docs/Spec.md#slice-5-mouse-and-hit-testing).

## Sizing

Style modifiers are layout-transparent. The examples use a child with a 4x1 ideal and
minimum, so each modifier reports the child's result unchanged.

| Proposal  | Result | Rule                                                                   |
| --------- | ------ | ---------------------------------------------------------------------- |
| nil x nil | 4x1    | Reports the child's unconstrained ideal without wrapper contribution.  |
| 4x1       | 4x1    | Tight fit passes the proposal and the child result through unchanged.  |
| 2x1       | 4x1    | Under-minimum reports the child's minimum unchanged; the parent clips. |
| 8x1       | 4x1    | Over-maximum preserves the child's ideal; wrapper leaves slack alone.  |

`.background(Color)` fills only the child result's final allocated region after layout. It
is clipped to those bounds and never changes the reported size.

## Environment

| Value                  | Source                                          | Default                                      | Effect                                              |
| ---------------------- | ----------------------------------------------- | -------------------------------------------- | --------------------------------------------------- |
| `defaultStyle`         | `EnvironmentValues`                             | resolved `semantic.primary` complete `Style` | supplies inherited attributes to the subtree        |
| `semantic.primary`     | [semantic styles](../tokens.md#semantic-styles) | token-defined complete `Style`               | ordinary inherited presentation                     |
| `semantic.secondary`   | [semantic styles](../tokens.md#semantic-styles) | token-defined complete `Style`               | supporting presentation when selected by a control  |
| `semantic.accent`      | [semantic styles](../tokens.md#semantic-styles) | token-defined complete `Style`               | emphasized presentation when selected by a control  |
| `semantic.disabled`    | [semantic styles](../tokens.md#semantic-styles) | token-defined complete `Style`               | disabled presentation when selected by a control    |
| `semantic.destructive` | [semantic styles](../tokens.md#semantic-styles) | token-defined complete `Style`               | destructive presentation when selected by a control |

The five semantic roles are complete `Style` values resolved from
[semantic styles](../tokens.md#semantic-styles). Controls consume the resolved role; they
never reconstruct its colors or attributes.

## Requirements

- `style modifiers inherit an ancestor bold attribute while a child adds foreground`
  (anatomy: nested inheritance styled grid)
- `style modifier on one sibling does not change the other sibling` (anatomy: sibling
  isolation styled grid)
- `style modifier explicitly turns bold off beneath a bold ancestor` (anatomy: explicit
  attribute override styled grid)
- `style modifier merges every explicit attribute from whole Style` (anatomy: whole-style
  merge styled grid)
- `style foreground colors descendant glyphs while background fills child bounds first`
  (anatomy: foreground and region fill styled grid)
- `style modifiers preserve the child ideal under an unconstrained proposal` (sizing: nil
  x nil)
- `style modifiers stay layout transparent at every proposal` (sizing: 4x1, 2x1, and 8x1)
- `controls consume resolved complete semantic role Styles` (environment:
  `semantic.primary`, `semantic.secondary`, `semantic.accent`, `semantic.disabled`, and
  `semantic.destructive` rows)

## Degradation

Style wrappers preserve their merge and paint order at every capability tier. Color and
attribute reduction follows the shared
[degradation ladder](../tokens.md#degradation-ladder), including its semantic-style row;
no modifier-specific fallback is introduced.

## Open questions

- Resolved: `defaultStyle` is the single environment key, and the fluent API remains on
  the buffer `Style` value.
- Resolved: `.background(Color)` is the style wrapper's region fill, preserving the Slice
  3 overload; view-builder [background](background.md) remains the layering primitive.

## Inspiration

- Fluent terminal styling should compose as ordinary immutable wrapper values.
- Nested presentation should be inspectable with aligned character and attribute grids.
