---
type: spec
description: "Slice 3: Styling, text wrapping, and decoration"
---

# Slice 3: Styling, text wrapping, and decoration

## What this slice proves

The Lip Gloss-flavored ergonomics: styled text, borders, backgrounds, overlays — as
modifier chains that lower to ordinary wrapper nodes with zero new machinery. Plan 032
Phase 9 delivers this slice: the style environment, roles, tones, and styled runs (step
9.1), wrapping and truncation (9.2), borders, `Box`, `background`, `overlay`, and the
focus border (9.3), and `ScrollIndicator` (9.4).

## Catalog text boundary decisions

`Text` normalizes each `\r\n` sequence to one source newline at its public initializer; a
lone `\r` remains literal source text. Slice 3 exposes `TruncationMode.tail` (the
default), `.head`, `.middle`, and `.clip`; every marker replaces only whole extended
grapheme clusters. Plan 032 step 9.1 lands styled runs (`Text + Text`, measured once as
one leaf), which Markdown needs. [Text](../../design/primitives/text.md#styled-runs)
defines them; step 9.1 settles only that doc's open questions, the `+` spelling and inline
icon runs. Localized interpolation and formatted values are out of Phase 4 1.0 and require
a separate post-1.0 text-composition proposal; `Text` stays an immutable value and never
becomes a mutable document model.

## Style chains and inheritance

Phase 2 Slice 4's `Style` (in `TesseraTerminalBuffer`) gains the fluent value API —
coordinate there; it is one type, not two:

```swift
let emphasis = Style().bold().foreground(.red)
let subtle = Style().foreground(.indexed(245)).italic()
```

The view layer adds **environment-driven inheritance**: a `defaultStyle` environment value
that text-producing leaves merge under their own attributes.

```swift
extension View {
    public func foreground(_ color: Color) -> some View   // environment override
    public func background(_ color: Color) -> some View   // fills region + environment
    public func bold(_ on: Bool = true) -> some View
    public func italic(_ on: Bool = true) -> some View
    public func underline(_ on: Bool = true) -> some View
    public func style(_ style: Style) -> some View        // merge wholesale
}
```

Merging rule (normative): per-attribute, nearest-ancestor-wins, view's own explicit style
wins over inherited. No `sub_modifier`-style negation in v1; `.bold(false)` explicitly
sets the attribute off, which is sufficient and simpler.

## System and custom style plumbing

System styles and custom styles are both public. The environment selects a complete
`Style` value through the same merge path; it does not introduce a parallel widget-style
type. Every role in the [catalog tokens](../../design/tokens.md#roles) — the text roles
(`primary`, `secondary`, `border`, `disabled`, `focus`), the hue roles (`accent`, `info`,
`success`, `warning`, `error`, `destructive`), and the fill and syntax roles — is a
complete `Style` value, never a color alias. Their token semantics, color tiers, and
derivation from the terminal's reported colors belong to the catalog tokens; controls
consume those resolved values rather than reconstructing colors or attributes. Apps
override any role for a subtree through the environment, and `.tint(_:)` overrides
`accent`. Two more environment values select presentation, `\.colorScheme` and
`\.charset`; both resolve under the Phase 3
[protocol enablement policy](../phase-3/slice-06-terminal-capability-detection.md#protocol-enablement-policy).

## Text grows up

```swift
public struct Text: View /* LeafView */ {
    public init(_ content: String)
}

public enum TruncationMode: Sendable, Equatable {
    case tail     // default
    case head
    case middle
    case clip     // Tessera-only: no mark
}

extension View {
    /// Row budget; writes `EnvironmentValues.lineLimit` (default `nil`).
    public func lineLimit(_ limit: Int?) -> some View
    /// Last-row cut; writes `EnvironmentValues.truncationMode` (default `.tail`).
    public func truncationMode(_ mode: TruncationMode) -> some View
}
```

Text wraps whenever its width is finite (owner decision, 2026-10-18): each source line
breaks at Unicode word boundaries, measured in grapheme clusters with the Phase 2 width
tables, and a word wider than the width breaks between grapheme clusters instead of being
clipped. A nil width keeps each source line as one row. A finite height proposal and
`lineLimit(n)` are row budgets, and the smaller wins; when the wrapped rows exceed the
budget, Text fills it and only the last visible row, which carries the rest of its source
line, ends in `truncation.mark` according to the truncation mode. `n` below 1 traps before
layout. Both modifiers flow through the environment to content; chrome pins its own
`.lineLimit(1)`. There is no wrapping-mode API: `.lineLimit(1)` replaces the old no-wrap
mode, and character wrapping is dropped. Text owns the cut: given a rectangle smaller than
it measured, it lays out again at that size, so overflow ends in the mark instead of a
silent clip. [Text](../../design/primitives/text.md#wrapping) owns the full rules, and the
catalog's [wrap and truncation rules](../../design.md#wrap-and-truncation) apply them to
every component.

`sizeThatFits` and `render` must agree exactly — property-test this (measure, then render
into exactly that size, assert no clipping occurred).

## Decoration

```swift
public enum BorderStyle: Sendable, Equatable {
    case single, rounded, double, heavy, ascii
    case custom(BorderGlyphs)
}

extension View {
    public func border(_ style: BorderStyle = .single, _ lineStyle: Style = Style())
        -> some View
    public func overlay<O: View>(alignment: Alignment = .topLeading,
                                 @ViewBuilder _ overlay: () -> O) -> some View
    public func background<BackgroundLayer: View>(
        alignment: Alignment = .topLeading,
        @ViewBuilder background: () -> BackgroundLayer
    ) -> some View
}

// Border, one column of padding left and right (none above or below), and a title slot.
public struct Box<Title: View, Content: View>: View {
    public init(border: BorderStyle = .rounded,
                @ViewBuilder content: () -> Content,
                @ViewBuilder title: () -> Title)
}

extension Box where Title == Text {
    public init(title: String, border: BorderStyle = .rounded,
                @ViewBuilder content: () -> Content)
}

extension Box where Title == EmptyView {
    public init(border: BorderStyle = .rounded, @ViewBuilder content: () -> Content)
}
```

`border` adds 1 to each inset and draws box-drawing glyphs in the inset ring — it is a
unary layout wrapper plus a render decoration, the model case for "modifiers are just
nodes." `overlay`/`background` are ZStack-equivalent wrappers sized by the primary child;
the background layer is proposed the primary's final bounds and painted first
([Background](../../design/primitives/background.md)), while `.background(_:)` with a
`Color` stays the style fill of [Style chains](#style-chains-and-inheritance). Box's title
is an ordinary child view with its own identity, so it can carry styled runs, a badge, or
a motion view ([Box](../../design/primitives/box.md)). The Slice 2
[`Divider`](../../design/primitives/divider.md) receives this same style and decoration
plumbing without changing its stack-derived geometry.

`.link(URL)` (OSC 8, Phase 3 Slice 5) joins the chain here if that slice has landed — it
is an environment-merged `Style` attribute like any other.

The focus border is a border style, not a new mechanism: the rules of
[Border](../../design/primitives/border.md#focus-border) switch a focused view's ring to
the heavy set in the `focus` role, and the nearest bordered ancestor of the focused view
tints its ring at normal weight. Plan 032 step 9.3 lands the style; focus-appearance hosts
apply it once focus exists (step 10.2).

## `ScrollIndicator`

[`ScrollIndicator`](../../design/primitives/scroll-indicator.md) is shared output-only
overflow geometry: it derives an indicator track and thumb from a viewport, content size,
and clamped offset, but owns neither input nor scrolling state. `ScrollView` consumes it
now; `List` and `Table` consume the same representation when they land. It reserves a
trailing or bottom edge only for an overflowing axis.

Two environment values select its look and placement. Each has its own modifier, and the
nearest ancestor wins, as with Text's `lineLimit` and `truncationMode`:

```swift
extension EnvironmentValues {
    /// One of eight closed presets; default `.standard`.
    public var scrollIndicatorStyle: ScrollIndicatorStyle { get set }
    /// `.reserved` (default) or `.border`.
    public var scrollIndicatorPlacement: ScrollIndicatorPlacement { get set }
}

extension View {
    public func scrollIndicatorStyle(_ style: ScrollIndicatorStyle) -> some View
    public func scrollIndicatorPlacement(
        _ placement: ScrollIndicatorPlacement
    ) -> some View
}
```

Under `.reserved` the parent reserves the trailing column or bottom row. Under `.border`
it reserves nothing: the ring of the nearest bordered
[`Box`](../../design/primitives/box.md) is the track, and Box paints the thumb cells after
its descendants, as it paints delegated focus, because no view writes outside its own
region. Without a bordered Box ancestor, `.border` falls back to `.reserved`. Plan 032
step 9.4 settles the channel that carries the parent's resolved indicator geometry up to
that Box, without giving the indicator any input
([ScrollIndicator](../../design/primitives/scroll-indicator.md#decisions)).

## Tests

- Styled-grid snapshots (the Phase 2 harness's char+style aligned format) for inheritance,
  override, and merge rules.
- Border glyph snapshots per `BorderStyle`, including 1×1 and degenerate (zero-area)
  regions — borders must clamp, not crash.
- Wrap/truncate property tests: for random strings (ASCII + CJK + emoji + combining
  marks), `render(into: sizeThatFits(p))` never clips and never writes outside bounds.

## Definition of done for slice 3

1. `Style` fluent API lives on the buffer's `Style` type; environment inheritance,
   system/custom plumbing, and the complete role `Style` values of the catalog tokens
   ship, with `\.colorScheme` and `\.charset` in the environment.
2. Wrapping/truncation measurement and rendering agree, property-tested with wide and
   combining graphemes.
3. Borders, `Box`, [`Divider`](../../design/primitives/divider.md), `overlay`, and
   `background` snapshot-test including degenerate sizes.
4. [`ScrollIndicator`](../../design/primitives/scroll-indicator.md) produces output-only
   overflow geometry reused by ScrollView and ready for List/Table parity.

## Things to flag

1. **One `Style` type.** If slice ordering pressure tempts a second view-layer style type
   "temporarily," stop and do the buffer work first. Two style types never merge back.
2. **Emoji/ZWJ width will produce the first ugly bugs.** They are substrate (Phase 2
   Slice 4) bugs surfacing through `Text`; fix them there, with view-layer regression
   tests pinning the symptom.

---
