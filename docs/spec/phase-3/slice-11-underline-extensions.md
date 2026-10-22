---
type: spec
description: "Slice 11: Underline extensions"
---

# Slice 11: Underline extensions

Slice 11 equips Tessera with modern underline SGR: underline style variants and underline
colors. The style model represents underline explicitly, and the renderer emits SGR `4`,
`24`, and the extension forms below. Modern terminal UIs use richer underline semantics
for diagnostics, spellcheck, links, search matches, and accessibility-friendly status
decoration: double underline, curly undercurl, dotted underline, dashed underline, and an
underline color that is independent of the foreground color.

This slice is pure text styling. Underline metadata does not consume layout space, does
not change grapheme width, and does not affect raw payload occupancy. There is no standard
active probe for underline extensions. Unsupported terminals are not uniformly safe,
however: Terminal.app 2.15 misparses `4:2` through `4:5` as background colors and SGR `58`
can trigger blink or conceal behavior. Tessera therefore resolves semantic underline state
through an output-safety policy before rendering.

Tessera models the following SGR forms:

```text
CSI 4 m          single underline
CSI 24 m         underline off
CSI 4:2 m        double underline
CSI 4:3 m        curly underline / undercurl
CSI 4:4 m        dotted underline
CSI 4:5 m        dashed underline
CSI 58:5:<n> m   underline color from the 256-color palette
CSI 58:2::<r>:<g>:<b> m
                 underline truecolor
CSI 59 m         reset underline color to the terminal default
```

Underline colors use colon subparameters on the wire. Parsers that predate SGR 58 skip an
unrecognized colon group wholesale, while the semicolon forms split into separate
parameters and can misapply blink (5) or dim (2); mintty additionally parses only the
colon form. The double colon in the RGB form is the empty colorspace subparameter.

The low-level `ControlSequence` API always preserves these exact bytes. Session rendering
uses `UnderlineRenderingPolicy`, which separates two output decisions:

- `UnderlineStyleRendering.preserveVariants` preserves the requested style, while
  `.singleOnly` maps every non-`.none` style to `.single`.
- `UnderlineColorRendering.emit` emits semantic underline color, while `.omit` projects it
  to `.default` without writing SGR `58` or `59`.

The `.extended` preset combines `.preserveVariants` and `.emit`; the `.baseline` preset
combines `.singleOnly` and `.omit`. Applications can also construct mixed policies.
`TerminalApplicationConfiguration.underlineRendering` defaults to `.extended`.

`UnderlineCompatibilityMode.off` is the default and uses that requested policy unchanged.
`.terminfoDatabase` is an explicit startup-only compatibility opt-in: a valid entry that
does not declare `Smulx` projects the style axis to `.singleOnly`, and one that does not
declare `Setulc` projects the color axis to `.omit`. A declared axis preserves the
requested axis; an unknown declaration leaves it unchanged; and the projection never
upgrades a requested baseline or omitted axis. Terminal identity and passive capability
detection never select this mode or prove underline support.

`TerminalSession` owns the active concrete policy as actor-isolated state. Applications
can call `setUnderlineRendering(_:)` while a session is running; this explicit runtime
setter wins over the startup compatibility projection. A changed policy invalidates cached
renderer state so the next draw erases and repaints under the new projection. Setting the
already-active policy is a no-op and does not force a repaint. The Phase 3 demo exposes
independent runtime controls for the style and color axes.

Prefer `24` for disabling underline rather than `4:0`. Prefer `4` for single underline
rather than `4:1`, because `4` is the widest-compatible spelling and matches Tessera's
existing encoder. Do not use SGR `21` for double underline: many modern terminals and
libraries treat `21` as bold/intensity off. Tessera's double underline spelling should be
the unambiguous subparameter form `4:2`.

Ratatui has an optional `underline_color` field on `Style` behind its `underline-color`
feature, and crossterm exposes `DoubleUnderlined`, `Undercurled`, `Underdotted`,
`Underdashed`, and `NoUnderline`. Tessera preserves the variant rather than collapsing it
to a boolean.

Tessera exposes a first-class underline style value in the terminal style model:

```swift
public enum UnderlineStyle: Equatable, Sendable {
  case none
  case single
  case double
  case curly
  case dotted
  case dashed
}
```

`curly` is Tessera's API spelling for SGR `4:3` undercurl. Documentation can mention
“undercurl” because that is the term many editors and terminals use, but the case name
should describe the visual style rather than the implementation detail.

`Style` exposes underline-specific fields whose semantic defaults are no underline and
default underline color. The clean model has no boolean underline bit in `TextAttributes`;
callers use `underlineStyle: .single`, and `UnderlineStyle` is the only representation of
whether text is underlined.

Underline color is independent state. `underlineColor != .default` does not turn underline
on by itself; it only chooses the underline's color when the effective underline style is
not `.none`. Underline colors reuse Tessera's existing `Color` type and use
underline-specific SGR parameters. `Color.default` means SGR `59` in underline-color
context, not foreground reset `39` or background reset `49`.

There is no 16-color underline shorthand equivalent to foreground `30...37`/`90...97` or
background `40...47`/`100...107`. Named ANSI colors should therefore map to their
conventional 256-color palette indexes `0...15`.

Tessera exposes semantic control sequence support:

```swift
case setUnderlineStyle(UnderlineStyle)
case setUnderlineColor(Color)
```

`setUnderline(Bool)` was replaced rather than kept as an alias: single underline is
`setUnderlineStyle(.single)` and underline off is `setUnderlineStyle(.none)`, so a
parallel boolean spelling of the same two SGR bytes (`4`/`24`) would be redundant surface.
The other boolean SGR toggles (`setBold`, `setItalic`, …) remain `Bool` because they are
genuinely two-state; underline is the one attribute represented by a value type.
`UnderlineStyle` is a wire-level type that lives alongside `Color` in the ANSI encoder
layer so the encoder can reference it, and the buffer style layer reuses it.

Renderer diffing treats underline style and underline color as real SGR state. A cell
whose only change is `.curly` to `.dashed`, or `indexed(196)` underline color to
`rgb(1,2,3)`, is damaged and repainted just like a foreground color change.

Reset behavior matters:

- SGR `0` resets all graphic rendition state, including underline style and underline
  color.
- SGR `24` resets underline style only.
- SGR `59` resets underline color only.
- changing from one non-`.none` underline style to another should emit the target style
  directly, without a broad reset unless another attribute transition already requires
  one.
- changing from any underline style to `.none` emits `24`.
- changing from a custom underline color to `.default` emits `59`, even if the new style
  also disables underline, so a terminal does not leak the old underline color into a
  later default-colored underline.
- under `.singleOnly`, the renderer projects both old and new underline styles before
  diffing, so variant changes that collapse to single underline emit no redundant SGR.
- under `.omit`, underline color changes project to `.default` and emit no SGR `58` or
  `59`.

Buffer snapshots include non-default underline metadata in a compact, readable form that
distinguishes all variants and underline color forms. Ghostty-backed virtual-terminal
snapshots report underline variants and underline color from Ghostty's C API; exact byte
tests remain the authority for variant/color correctness.

Tessera does not actively probe for underline extension support and does not fail startup
when support is absent. The terminfo reader reports independent advisory declarations for
the style (`Smulx`) and color (`Setulc`) axes; `.unknown` does not dumb down the default
extended output, and `.declared` is not proof of active support. Raw extension bytes are
not universally harmless, so an application that targets ordinary underline can select
`.baseline` directly or opt into the startup-only `.terminfoDatabase` projection. A later
`setUnderlineRendering(_:)` is an explicit runtime choice and is not reprojected through
terminfo. Tessera does not infer any of these choices from emulator identity. Applications
must not use underline style or underline color as the only carrier of critical
information; text content, symbols, labels, and accessible wording remain the source of
truth.

Coverage exercises exact encoder bytes for all underline styles, underline color reset,
indexed/RGB/named underline colors, the API migration away from boolean underline, style
equality/damage tracking, renderer transitions, hyperlink composition, snapshot metadata
where available, and precise `24`/`59` reset behavior.

## End of Slice 11

`TesseraTerminal` exposes underline variants and colored underlines as ordinary semantic
style state. Callers express single underline, undercurl, and underline color through the
same `UnderlineStyle`/underline-color model without raw ANSI bytes. Extended rendering
preserves the requested variants and colors with precise `24`/`59` resets; baseline
rendering emits ordinary underline only.
