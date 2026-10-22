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

- omp2 has no style component; its counterpart is the text attributes `fg`, `bg`, `on`,
  `bold`, `dim`, `italic`, `underline`, `undercurl`, `reverse`, `strike`, and `color`
  ([vocab/lib.rs#L73-L101](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/vocab/src/lib.rs#L73-L101)),
  applied over the inherited style. Key B6 maps them onto these modifiers: `fg` and
  `color` are `.foreground(_:)`, `bg` and `on` are `.background(_:)`, `bold`, `italic`,
  and `underline` keep their names, and `.style(_:)` carries the rest. A colour token is a
  role, never a fixed colour: `fg=accent` is the `accent` role, which `.tint(_:)`
  overrides, and the CSS colour forms
  ([markup.rs#L35-L38](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/markup.rs#L35-L38))
  are rejected (key J4). omp2's `Theme` struct of colours becomes the semantic
  [roles](../tokens.md#roles), each a complete `Style` (key J1).
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
before and after a modifier; the styled grids show the inherited cell attributes. Each
grid is `standalone`: a minimal illustration of one inheritance rule, so its glyphs differ
from the wireframe above.

```wireframe 4x1
Text
```

```text
Callouts (4x1, 0-based):
1. r0 c0-3  descendant text glyphs; wrapper changes their resolved Style, not their cells
```

### Nested inheritance

An ancestor `.bold()` wraps two cells. The second cell's own wrapper adds the `accent`
foreground and inherits the bold. Both cells retain their source glyphs.

```text standalone
── chars ──
AB
── style ──
BA
── legend ──
B  bold -- bold from the ancestor `.bold()`
A  fg=accent bold -- foreground from `accent` added by the child, bold inherited
```

### Sibling isolation

A sibling wrapper never alters its peer.

```text standalone
── chars ──
LR
── style ──
A.
── legend ──
.  default -- inherited `primary` on the right sibling
A  fg=accent -- foreground from `accent` on the left sibling
```

### Explicit attribute override

The child's `.bold(false)` records bold as off, so the second cell resolves to the default
style; both cells otherwise inherit `primary`.

```text standalone
── chars ──
NO
── style ──
B.
── legend ──
.  default -- bold explicitly off by the child `.bold(false)`, otherwise `primary`
B  bold -- bold from the ancestor `.bold()`
```

### Whole-style merge

The child's complete `destructive` Style, merged by `.style(_)`, replaces every attribute
it supplies in the inherited `secondary` Style.

```text standalone
── chars ──
MN
── style ──
SD
── legend ──
S  fg=secondary -- inherited complete `secondary` Style
D  fg=destructive -- child complete `destructive` Style merged by `.style(_)`
```

### Foreground and region fill

`.background(Color)` fills the final allocated child region; descendant glyphs take the
`accent` foreground over that fill. The `·` is an otherwise empty cell, drawn visibly so
the aligned grid can show the fill. The fill is an arbitrary `Color`; the legend draws it
as `surface`.

```text standalone
── chars ──
INK·
── style ──
AAAB
── legend ──
A  fg=accent bg=surface -- `accent` foreground on a descendant glyph over the fill
B  bg=surface -- region fill alone, in a cell no descendant draws
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

On a `Text`, the attribute modifiers return `Text` and set the attributes of styled runs;
`.background(_:)` has no `Text` overload, so it stays the region fill
([Text styled runs](text.md#styled-runs)). `.link(URL)` is the Spec's OSC 8 attribute
([Decoration](../../docs/Spec.md#decoration); key I7) and merges like any other attribute.

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

| Value          | Source                                | Default                             | Effect                                              |
| -------------- | ------------------------------------- | ----------------------------------- | --------------------------------------------------- |
| `defaultStyle` | `EnvironmentValues`                   | resolved `primary` complete `Style` | supplies inherited attributes to the subtree        |
| `primary`      | [text roles](../tokens.md#text-roles) | token-defined complete `Style`      | ordinary inherited presentation                     |
| `secondary`    | [text roles](../tokens.md#text-roles) | token-defined complete `Style`      | supporting presentation when selected by a control  |
| `accent`       | [hue roles](../tokens.md#hue-roles)   | token-defined complete `Style`      | emphasized presentation when selected by a control  |
| `disabled`     | [text roles](../tokens.md#text-roles) | token-defined complete `Style`      | disabled presentation when selected by a control    |
| `destructive`  | [hue roles](../tokens.md#hue-roles)   | token-defined complete `Style`      | destructive presentation when selected by a control |

Every [role](../tokens.md#roles) is a complete `Style` value resolved through the
environment (key J1); the rows above are the ones this doc's examples and controls name.
An app overrides a role for a subtree, and `.tint(_:)` overrides `accent`
([overrides](../tokens.md#overrides)). Controls consume the resolved role; they never
reconstruct its colors or attributes.

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
- `controls consume resolved complete semantic role Styles` (environment: `primary`,
  `secondary`, `accent`, `disabled`, and `destructive` rows)

## Degradation

Style wrappers preserve their merge and paint order at every capability tier. Color and
attribute reduction follows the shared
[degradation ladder](../tokens.md#degradation-ladder), including the 16-colour slots
columns of [roles](../tokens.md#roles); no modifier-specific fallback is introduced.

## Open questions

- Resolved: `defaultStyle` is the single environment key, and the fluent API remains on
  the buffer `Style` value.
- Resolved: `.background(Color)` is the style wrapper's region fill, preserving the Slice
  3 overload; view-builder [background](background.md) remains the layering primitive.
- Resolved: reviewed against the
  [Phase 4 theses](../../docs/Spec.md#phase-4--view-layer-the-tessera-module). Style
  modifiers are value wrappers that lower to ordinary nodes, styles resolve from the
  environment with a written merge rule, and they add no state, geometry, or terminal
  authority.
- Deferred to plan 032 step 9.1, which lands roles and tones: the spelling that names a
  role for a subtree (`fg=accent`, key J4). Roles are environment values holding complete
  `Style`s and `.style(_:)` merges one, but no doc spells the environment key path or a
  shorthand for reading a role.

## Inspiration

- Fluent terminal styling should compose as ordinary immutable wrapper values.
- Nested presentation should be inspectable with aligned character and attribute grids.
