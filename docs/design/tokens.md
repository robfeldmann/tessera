---
kind: tokens
status: ready
---

# Design tokens

Cross-cutting visual vocabulary. Every wireframe and every widget doc references these by
name instead of relitigating glyphs and styles per component. Each token family maps onto
a future `EnvironmentValues` key, so this doc is also the environment-key design doc for
[Slice 3](../spec.md#slice-3-styling-text-wrapping-and-decoration) and beyond.

The owner set the colour policy on 2026-10-18 and closed the remaining token questions of
plan 032 step 5.3 on 2026-10-19. The [Migration map](#migration-map) maps the catalog's
older role and token names onto this doc.

## Viewports

Named sizes for wireframes and, later, snapshot fixtures.

| Viewport  | Size          | Rationale                                                                                                                                                                                                                                                                                                              |
| --------- | ------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `desktop` | 80x24         | The classic baseline; default for CI fixtures.                                                                                                                                                                                                                                                                         |
| `mobile`  | 40 columns    | Deliberately tighter than a real phone terminal (Termius/Blink portrait is typically 45-55 cols). If a component works at 40 columns, phones are comfortable. Components are wireframed at their natural height; screen-filling compositions use 40x16. Measure the real device with `stty size` and adjust here once. |
| `min`     | per-component | Each component declares its own floor and its degradation below it.                                                                                                                                                                                                                                                    |

Wider fixtures are component-specific. A component may declare a wider natural fixture
when width changes its anatomy, but the catalog does not assign that size a global
viewport name until device testing establishes a reusable breakpoint.

## Colour model

Owner decision, 2026-10-18: Tessera is terminal-native by default, derives its shades, and
treats themes as optional.

1. Hues come only from the terminal's 16 ANSI slots, never from fixed RGB values.
2. Subtle shades (surfaces, selection, hover, stripes, tinted fills, secondary text,
   borders) are derived from the terminal's own colours, queried at startup, and emitted
   as truecolor where the terminal supports it.
3. Light or dark is decided from the background's luminance. Derived shades, the contrast
   guard and Image's density ramp adapt to it.
4. When the terminal does not answer, roles fall back to ANSI slots plus the attributes
   dim, reverse and bold.
5. Apps may override any role for a subtree through the environment, the way SwiftUI's
   `.tint(_:)` works. No app is ever required to ship a theme.

### Inputs

| Input        | Source                                                                                                      | Unknown when                                    |
| ------------ | ----------------------------------------------------------------------------------------------------------- | ----------------------------------------------- |
| `fg`         | OSC 10 reply (terminal default foreground)                                                                  | no reply before the round's sentinel or timeout |
| `bg`         | OSC 11 reply (terminal default background)                                                                  | as `fg`                                         |
| `slot[0-15]` | one OSC 4 reply per index                                                                                   | per slot, as `fg`                               |
| depth        | `ColorCapability` (Slice 6): `truecolor`, `indexed256`, `ansi16`, `noColor`; `unknown` resolves as `ansi16` | never; detection always yields a case           |
| scheme       | from `bg` ([Colour scheme](#colour-scheme)); else `COLORFGBG`; else `dark`                                  | never; it falls back to `dark`                  |
| charset      | [`\.charset`](#charset)                                                                                     | never; it falls back to `.unicode`              |

### Tiers

| Tier         | Selected when                                                          | Roles use                                                            | Emitted as                                                                                                                                                                |
| ------------ | ---------------------------------------------------------------------- | -------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `derived`    | depth is `truecolor` or `indexed256`, and `fg` and `bg` are known      | blends of `fg`, `bg` and measured slot colours, with contrast guards | `.rgb`; a slot used unchanged is emitted as `.ansi(n)`. At `indexed256` the Slice 8 downsampler quantises each `.rgb` with `nearestXterm256Index` to an index from 16-255 |
| `slots`      | depth is `ansi16`, or `fg` or `bg` is unknown                          | ANSI slot indices plus attributes, from the scheme's column          | `.ansi(n)`, `.default`, attributes                                                                                                                                        |
| `monochrome` | `NO_COLOR` is set or `TERM=dumb` (the Spec's hard `.noColor` override) | attributes only                                                      | `.default` plus attributes                                                                                                                                                |

Derived shades at `indexed256` are quantised rather than dropped (owner decision,
2026-10-19). The tier is decided per role. A role resolves in `derived` only when every
colour it reads is known; otherwise it resolves in `slots`, using the session's scheme
column. Neutral roles read `fg` and `bg`. A hue role reads `fg`, `bg` and its slot pair.
`faint(R)`, `solid(R)` and `selection.fill` read whatever `R` reads. A terminal that
answers OSC 10 and 11 but not OSC 4 therefore still gets derived surfaces, with hue roles
on slot indices. tmux 3.4 is expected to behave this way when the pane palette is unset
(inferred from its changelog, not observed).

`ansi16` depth never uses `derived`. The Slice 8 downsampler maps `.rgb` against xterm's
default 16-colour table, which is not the user's palette, so a derived shade would land on
an arbitrary slot.

At `indexed256`, `selection.fill` resolves in `slots` (reverse video). Quantisation maps
the accent tint onto the same index as `selection.inactive` (237 on Miniwinter Dark, 238
on Catppuccin Mocha), and a stepped tint only lands on another grey on dark themes, so
focused and unfocused selection would look alike (owner decision, 2026-10-19).

### Charset

`\.charset` is one environment value read by every glyph family: `.nerdFont`, `.unicode`
or `.ascii` (owner decision, 2026-10-19). It replaces the `\.iconCharset` Label sketched
and absorbs the inbox's "symbol presets" idea (2026-08-17). The application states an
intent: `.automatic` by default, or one of the three charsets. The resolved charset is the
first rule below that applies:

1. **Locale.** A locale whose codeset is not UTF-8 resolves `.ascii`, and nothing
   overrides it. The locale is the first non-empty value of `LC_ALL`, `LC_CTYPE` and
   `LANG`. Its codeset is the text after `.`, up to an optional `@` modifier; `UTF-8` and
   `utf8`, in any letter case, are UTF-8. No locale variable, `C` and `POSIX` count as
   UTF-8. Any other locale, including one without a codeset, is not UTF-8.
2. **User veto.** `NERDFONT` set to an off value caps the charset at `.unicode` over the
   application's intent, the way `NO_COLOR` vetoes colour. An intent of `.ascii` stays
   `.ascii`.
3. **Application.** An explicit intent of `.nerdFont`, `.unicode` or `.ascii` applies.
4. **User opt-in.** With the intent `.automatic`, `NERDFONT` set to an on value resolves
   `.nerdFont`.
5. **Reserved after 1.0.** A protocol-native coverage query may upgrade `.automatic` only.
6. **Default.** `.unicode`.

`NERDFONT` grammar: the off values are `0`, `false`, `no` and `off`; the on values are
`1`, `true`, `yes` and `on`; both compare without regard to ASCII letter case. `auto`, an
empty value, any other value and an unset variable select nothing, and Tessera never
probes the font. Tessera reads no `TESSERA_CHARSET` and no `NERD_FONTS`, and terminal
identity never selects a charset. `TerminalCapabilities` reports Nerd Font coverage as
`.notDetectable`.

The Glyph Protocol is deferred: Ghostty's `q` coverage query reports registered glyphs
only, so it answers no for the symbols Ghostty bundles; kitty and WezTerm do not implement
it; and the specification is still moving. The Spec's
[protocol enablement policy](../spec.md#protocol-enablement-policy) carries the matching
sentence.

Each glyph row falls back from Nerd Font to Unicode to ASCII (owner decision, 2026-10-10):
a row with no glyph for the active charset uses the next charset's glyph. A cell that
reads "none" is a deliberate blank, not a gap: the row draws nothing in that charset.

Charset and colour tier are independent axes: `NO_COLOR` never changes glyphs, and
`.ascii` never changes colours.

### Colour scheme

`\.colorScheme` is `.light` or `.dark`, SwiftUI's name and cases (owner decision,
2026-10-19). The scheme is `light` when black text would out-contrast white text on the
background:

```text
light  if  (Y(bg) + 0.05)^2 > 1.05 * 0.05      (that is, Y(bg) > 0.1791)
dark   otherwise
```

`Y` is WCAG relative luminance ([Arithmetic](#arithmetic)). With `bg` unknown the scheme
comes from `COLORFGBG` when it parses as `fg;bg` or `fg;x;bg` with a numeric last field:
background slot 7 or 15 is light, any other number is dark. Otherwise the scheme is `dark`
(owner decision, 2026-10-19): terminals that stay silent are overwhelmingly dark. The
capability still records `bg` as unknown, so a later reply can replace the assumption.

What adapts to the scheme:

- Derived neutrals, by construction: they are blends of the real `fg` and `bg`.
- The hue guard's direction: toward black on light, toward white on dark.
- The `slots` column: bright slots and an ANSI 8 fill on dark, normal slots and no neutral
  fill on light.
- Image's density ramp, which inverts on light ([Bars and ramps](#bars-and-ramps)).

### Probe

A design contract, not code, distilled from the step 5.3 OSC colour-query research and the
Spec's [startup rules](../spec.md#startup-behavior): prefer a sentinel to wall-clock
timeouts, a DA1 reply first means unsupported, a timeout means `.unknown`, not failure.
Every rule below is an owner decision of 2026-10-19.

1. **When.** Once at startup in `.active` capability detection, inside the existing
   active-probe flush (`ActiveCapabilityProbeCoordinator`), again on each colour-scheme
   notification, and again on resume after suspend. `.passive` and `.disabled` detection
   skip it: every colour input stays unknown. Under `NO_COLOR` the round sends OSC 11
   only, because Image's ramp still needs the scheme.
2. **Query.** One write: `OSC 10 ; ? ST`, `OSC 11 ; ? ST`, then `OSC 4 ; n ; ? ST` for `n`
   = 0 to 15 as sixteen separate sequences, then the round's single DA1 (`CSI c`). The ST
   terminator is used; a reply's terminator may be BEL or ST.
3. **Parse.** Accept `rgb:` and `rgba:` bodies (alpha ignored) with 1 to 4 hex digits per
   channel, and scale each channel to 8 bits as `round(v * 255 / (16^d - 1))`. OSC 4
   replies may arrive in any order. Replies are consumed by the input parser and never
   reach the app as key events.
4. **Round end.** The round ends at the DA1 reply or at `activeProbeTimeout`, whichever
   comes first. An input with no reply by then is unknown. The timeout defaults to 1000 ms
   for this round, up from 250 ms, because SSH links need it, and apps may configure it;
   the DA1 reply still ends the round after one round trip on any terminal that answers
   DA1. The first frame waits for the round, so it paints in its final tier.
5. **Late replies.** A colour reply that arrives after the round ended is still consumed,
   and is applied as an update: roles re-resolve and the screen repaints.
6. **Multiplexers.** tmux 3.4+ answers OSC 10 and 11 itself with the first attached
   client's colours; tmux 3.3+ answers OSC 4 itself, probably leaving unset entries
   unanswered (inferred), and newer releases forward those to the client. zellij and GNU
   screen are unverified; screen is not expected to answer. A multiplexer can answer DA1
   before a forwarded OSC reply, which reads as unsupported. That failure is safe (the
   role falls to `slots`), and rule 5 upgrades it when the reply lands. Tessera never
   wraps queries in DCS passthrough and never decides by terminal identity
   ([Information sources](../spec.md#information-sources)).
7. **Live updates.** Startup enables colour-scheme notifications with `CSI ? 2031 h` and
   registers `CSI ? 2031 l` with cleanup. Each `CSI ? 997 ; 1 n` (dark) or
   `CSI ? 997 ; 2 n` (light) re-runs the colour round of rule 2, re-resolves every role
   and repaints. A terminal that does not know mode 2031 ignores it.
8. **Fixtures.** The application configuration may supply fixed `fg`, `bg` and slot
   colours, which skip the round. Snapshot tests and the review page use the five
   [review themes](#review-themes).

Integration touchpoints (non-normative): the OSC bytes join
`ActiveCapabilityProbeCoordinator`'s DA1 round; `InputEvent` and `InputParser` gain a
colour-report event (no OSC parsing exists today); `TerminalCapabilities` gains the
optional `fg`, `bg` and 16 slots; `TerminalApplicationConfiguration.activeProbeTimeout`
changes default. Adopting this doc also moves "palette querying, theme detection, contrast
correction" out of [Slice 8](../spec.md#slice-8-color-degradation-baseline)'s out-of-scope
list and extends the semantic role list in
[System and custom style plumbing](../spec.md#system-and-custom-style-plumbing).

### Overrides

Every role is an environment value. `.tint(_:)` overrides `accent`, which also moves
`selection.fill`, `faint(accent)` and `solid(accent)`. Any other role takes a complete
`Style` for a subtree; `focus` may take an explicit colour (owner decision, 2026-10-19).
An override is taken verbatim: Tessera applies no pair choice and no guard to an app's
colours, and explicit colours are the developer's way past the guard (owner decision,
2026-10-19). The functions `faint`, `solid` and `on` still compute from an override
whenever its RGB is known: an `.rgb` value, or an `.ansi(n)` slot the probe measured.

## Blend and contrast rules

These rules are normative. A script given `fg`, `bg` and the 16 slots computes every
derived value below with no further input; [Reference values](#reference-values) lists the
results for the five review themes, and an implementation must reproduce them exactly.

### Arithmetic

Colours are 8-bit sRGB triples. Blending is a per-channel opacity mix in gamma-encoded
sRGB, the same arithmetic as drawing `b` at `p` percent opacity over `a`. Percentages are
integers, so the result is exact in any language (owner decision, 2026-10-19):

```text
mix(a, b, p)   = per channel  floor((a * (100 - p) + b * p + 50) / 100),  p integer 0..100
lin(v)         = s / 12.92                       if s <= 0.04045,  s = v / 255
               = ((s + 0.055) / 1.055) ^ 2.4     otherwise
Y(c)           = 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
contrast(a, b) = (max(Y(a), Y(b)) + 0.05) / (min(Y(a), Y(b)) + 0.05)
```

`Y` and `contrast` are WCAG 2 definitions, computed in double precision and compared
unrounded. The 0.04045 and 0.03928 thresholds agree for every 8-bit value.

### Neutral ladder

Three background shades and two foreground inks, all blends of `bg` toward `fg`:

| Level    | Rule                                                                     | Roles that use it                                                      |
| -------- | ------------------------------------------------------------------------ | ---------------------------------------------------------------------- |
| `fill8`  | `mix(bg, fg, 8)`                                                         | `surface` (table stripes, keycaps, inline code), `disabled.fill`       |
| `fill12` | `mix(bg, fg, 12)`                                                        | `hover`                                                                |
| `fill16` | `mix(bg, fg, 16)`                                                        | `selection.inactive`, `faint(focus)`; the hue guard's second reference |
| `ink2`   | first `p` in 60, 65, ..., 100 with `contrast(mix(bg, fg, p), bg) >= 4.5` | `secondary`, `syntax.comment`, `syntax.punctuation`                    |
| `ink3`   | first `p` in 45, 50, ..., 100 with `contrast(mix(bg, fg, p), bg) >= 3.0` | `border`, `disabled`, `disabled.label`                                 |

The three fill levels are owner decisions of 2026-10-19: a hovered row stands out from a
keycap, and the unfocused selection stands out from both. The starting ink percentages
give the hierarchy on high-contrast themes; the contrast floors take over on low-contrast
ones. 4.5:1 is WCAG AA for text; 3:1 is WCAG 1.4.11 for component boundaries such as a
text field's frame. If `fg` itself misses a floor, the level is `fg` (`p` = 100).
`secondary`, `border` and `disabled` share the two inks (owner decision, 2026-10-19).

### Hue guard

A hue role names a slot pair: normal `n` (1-6) and bright `n + 8`.

1. **Pair choice.** Take the slot with the higher `contrast` against `bg`. On a tie take
   `n + 8` when dark and `n` when light (owner decision, 2026-10-19). This picks the
   bright slots on dark themes and the normal slots on light ones, and also handles themes
   such as Miniwinter Light, whose bright slots are darker than its normal ones. In
   `slots`, the same measurement applies when `bg` and both slots were measured; without
   measurement, `slots` takes the bright slot on dark and the normal slot on light.
2. **Guard.** The pole is `#000000` when light and `#ffffff` when dark. The role colour is
   `mix(c, pole, q)` for the first `q` in 0, 5, ..., 100 whose result reaches 4.5:1
   against both `bg` and `fill16` (owner decisions, 2026-10-19). Mixing with black or
   white keeps the HSV hue of `c` (up to 8-bit rounding): mixing toward black also keeps
   its saturation, mixing toward white lowers it. No hue is invented. If nothing passes,
   `q` = 100. The guard is correctness, not a preference: it is always on, and Tessera
   offers no accessibility switch for it.
3. **Emission.** With `q` = 0 the role is emitted as `.ansi(slot)`, which keeps the
   terminal's own colour, its bold-is-bright setting, and live palette edits. Otherwise it
   is emitted as `.rgb`. The `slots` tier has no guard: a slot can only be emitted as
   itself.

Guarding against `fill16` as well as `bg` keeps coloured text readable on the selected row
and on tinted fills. It costs a little fidelity on light themes: xterm's red `#cd0000`
passes on white but becomes `#b90000` to pass on `fill16`.

### Fills and labels

| Function   | Rule                                                    | Notes                                                                          |
| ---------- | ------------------------------------------------------- | ------------------------------------------------------------------------------ |
| `faint(R)` | `mix(bg, R, 16)`, with `R` the role's resolved colour   | tinted fill; its label stays `R`, and caps are drawn in `faint(R)`             |
| `on(F)`    | `bg` if `contrast(bg, F) >= contrast(fg, F)`, else `fg` | the `contrast` label colour on a solid fill `F`; `fg` is emitted as `.default` |
| `solid(R)` | background `R`, foreground `on(R)`, bold; caps in `R`   | filled buttons, badges, active chips, pills and segments                       |

`solid(primary)` is reverse video plus bold in every tier. Reversing the default colours
paints exactly an `fg` fill under a `bg` label, which is `on(fg)`, and it keeps live
palette edits. `solid(focus)` is `solid(primary)` while `focus` keeps its default value
([Focus](#focus)).

### Reference algorithm

```text
scheme      = light if (Y(bg) + 0.05)^2 > 0.0525 else dark
pole        = #000000 if scheme == light else #ffffff
fill8       = mix(bg, fg, 8)
fill12      = mix(bg, fg, 12)
fill16      = mix(bg, fg, 16)
ink(p0, t)  = mix(bg, fg, p) for the first p in p0, p0+5, ..., 100
              with contrast(mix(bg, fg, p), bg) >= t; p = 100 if none passes
ink2        = ink(60, 4.5)
ink3        = ink(45, 3.0)
pick(n)     = n    if contrast(slot[n], bg) > contrast(slot[n+8], bg)
              n+8  if contrast(slot[n], bg) < contrast(slot[n+8], bg)
              n+8 if scheme == dark else n,   on a tie
hue(n)      = mix(c, pole, q), c = slot[pick(n)], for the first q in 0, 5, ..., 100
              with min(contrast(x, bg), contrast(x, fill16)) >= 4.5, x = mix(c, pole, q);
              q = 100 if none passes
faint(X)    = mix(bg, X, 16)
on(F)       = bg if contrast(bg, F) >= contrast(fg, F) else fg
syntax16(n) = pick(n) if contrast(slot[pick(n)], bg) >= 3.0 else syntax.plain
```

### Reference values

Computed with the algorithm above from the [review themes](#review-themes). Hue rows give
the chosen slot and the guard step `q`; `q=0` rows are emitted as `.ansi(slot)`. The
`contrast on` rows give which of `bg` or `fg` was chosen and its ratio against the fill.
The last row applies `syntax16` at `ansi16` depth with every slot measured.

| Value                                          | Miniwinter Dark          | Miniwinter Light         | Catppuccin Mocha         | Catppuccin Latte                                  | xterm (default)                                  |
| ---------------------------------------------- | ------------------------ | ------------------------ | ------------------------ | ------------------------------------------------- | ------------------------------------------------ |
| scheme                                         | dark (Y=0.017)           | light (Y=0.765)          | dark (Y=0.014)           | light (Y=0.879)                                   | light (Y=1.000)                                  |
| `fill8`, `surface`                             | `#21343a`                | `#ced5d9`                | `#2c2d3e`                | `#e2e4ea`                                         | `#ebebeb`                                        |
| `fill12`, `hover`                              | `#293b40`                | `#c7ced1`                | `#333446`                | `#dbdee4`                                         | `#e0e0e0`                                        |
| `fill16`, `selection.inactive`, `faint(focus)` | `#314247`                | `#c1c7c9`                | `#3a3b4e`                | `#d5d7df`                                         | `#d6d6d6`                                        |
| `ink2`, `secondary`                            | `#888e8d` (p=60)         | `#646562` (p=70)         | `#878ca5` (p=60)         | `#64677e` (p=85)                                  | `#666666` (p=60)                                 |
| `ink3`, `border`                               | `#6b7475` (p=45)         | `#7e807f` (p=55)         | `#6d7187` (p=45)         | `#85889a` (p=65)                                  | `#8c8c8c` (p=45)                                 |
| `focus` = `fg`, emitted `.default`             | `#d8d4cd`                | `#312e29`                | `#cdd6f4`                | `#4c4f69`                                         | `#000000`                                        |
| `accent` = `hue(6)`                            | `#a6e1e2` (slot 14, q=0) | `#005657` (slot 14, q=0) | `#b1eae1` (slot 14, q=0) | `#10666b` (slot 6, q=30)                          | `#006767` (slot 6, q=50)                         |
| `info` = `hue(4)`                              | `#b3daf9` (slot 12, q=0) | `#004f7a` (slot 12, q=0) | `#aeccfc` (slot 12, q=0) | `#1852c4` (slot 4, q=20)                          | `#0000ee` (slot 4, q=0)                          |
| `success` = `hue(2)`                           | `#b8e1c1` (slot 10, q=0) | `#005a2b` (slot 10, q=0) | `#c2ecbf` (slot 10, q=0) | `#2a681c` (slot 2, q=35)                          | `#006700` (slot 2, q=50)                         |
| `warning` = `hue(3)`                           | `#d9d8aa` (slot 11, q=0) | `#504d00` (slot 11, q=0) | `#f9e2af` (slot 3, q=0)  | `#7b4e10` (slot 3, q=45)                          | `#5c5c00` (slot 3, q=55)                         |
| `error` = `hue(1)`                             | `#fac5c7` (slot 9, q=0)  | `#5c1b24` (slot 9, q=0)  | `#f7aec2` (slot 9, q=0)  | `#b30d30` (slot 1, q=15)                          | `#b90000` (slot 1, q=10)                         |
| `syntax.constant` = `hue(5)`                   | `#edc7e7` (slot 13, q=0) | `#442459` (slot 13, q=0) | `#f5c2e7` (slot 5, q=0)  | `#814170` (slot 5, q=45)                          | `#a400a4` (slot 5, q=20)                         |
| `faint(accent)`, `selection.fill`              | `#29444a`                | `#b9cdd1`                | `#363f4b`                | `#cbdbdf`                                         | `#d6e7e7`                                        |
| `faint(error)`                                 | `#363f46`                | `#c8c4c9`                | `#413546`                | `#e5cdd5`                                         | `#f4d6d6`                                        |
| `faint(secondary)`                             | `#24373c`                | `#c9d0d3`                | `#2f3041`                | `#d9dbe2`                                         | `#e7e7e7`                                        |
| `contrast on accent`                           | `#11262d` (bg, 10.8)     | `#dce4e8` (bg, 6.6)      | `#1e1e2e` (bg, 12.3)     | `#eff1f5` (bg, 5.9)                               | `#ffffff` (bg, 6.7)                              |
| `contrast on focus`                            | `#11262d` (bg, 10.6)     | `#dce4e8` (bg, 10.5)     | `#1e1e2e` (bg, 11.3)     | `#eff1f5` (bg, 7.1)                               | `#ffffff` (bg, 21.0)                             |
| `contrast on error`                            | `#11262d` (bg, 10.4)     | `#dce4e8` (bg, 10.0)     | `#1e1e2e` (bg, 9.2)      | `#eff1f5` (bg, 6.2)                               | `#ffffff` (bg, 6.9)                              |
| `contrast on secondary`                        | `#11262d` (bg, 4.7)      | `#dce4e8` (bg, 4.6)      | `#1e1e2e` (bg, 4.9)      | `#eff1f5` (bg, 4.9)                               | `#ffffff` (bg, 5.7)                              |
| `syntax16`: hues that fall to `syntax.plain`   | none                     | none                     | none                     | `string` (2.96), `constant` (2.34), `type` (2.31) | `keyword` (1.98), `string` (2.16), `type` (1.70) |

The other syntax hue roles use the same pairs and guard as the tones, so in `derived`
`syntax.keyword` equals `accent`, `syntax.string` equals `success`, `syntax.type` equals
`warning` and `syntax.function` equals `info` in every theme.

Measured outcomes on the five themes: every hue role reaches at least 5.9:1 on `bg`, 4.9:1
on `hover`, 4.6:1 on `fill16`, and 4.6:1 on `selection.fill` and on its own `faint` fill;
`fg` reaches 7.1:1 on `bg`, 6.2:1 on `surface`, 5.9:1 on `hover` and 5.6:1 on
`selection.fill`; `ink2` reaches 3.9:1 on `surface` and 3.5:1 on `hover`. Catppuccin Latte
has only 7.1:1 between `fg` and `bg`, so its `ink2` sits at p=85, close to `primary`. That
is the theme's own range, not a rule failure.

### Review themes

| Theme            | fg        | bg        | Slots 0-7                                                                       | Slots 8-15                                                                      |
| ---------------- | --------- | --------- | ------------------------------------------------------------------------------- | ------------------------------------------------------------------------------- |
| Miniwinter Dark  | `#d8d4cd` | `#11262d` | `#000f15` `#f1b1b4` `#a0d3ac` `#c9c88f` `#99cbf1` `#dfb3dd` `#88d4d5` `#98948e` | `#485f67` `#fac5c7` `#b8e1c1` `#d9d8aa` `#b3daf9` `#edc7e7` `#a6e1e2` `#f4f0e9` |
| Miniwinter Light | `#312e29` | `#dce4e8` | `#0f0d09` `#7d2934` `#007439` `#686400` `#00669c` `#603476` `#006f71` `#312e29` | `#4c4944` `#5c1b24` `#005a2b` `#504d00` `#004f7a` `#442459` `#005657` `#211e1a` |
| Catppuccin Mocha | `#cdd6f4` | `#1e1e2e` | `#45475a` `#f38ba8` `#a6e3a1` `#f9e2af` `#89b4fa` `#f5c2e7` `#94e2d5` `#bac2de` | `#585b70` `#f7aec2` `#c2ecbf` `#fcd682` `#aeccfc` `#f398da` `#b1eae1` `#a6adc8` |
| Catppuccin Latte | `#4c4f69` | `#eff1f5` | `#bcc0cc` `#d20f39` `#40a02b` `#df8e1d` `#1e66f5` `#ea76cb` `#179299` `#5c5f77` | `#acb0be` `#e7103f` `#46b02f` `#e49931` `#3878f6` `#ef95d7` `#19a1a8` `#6c6f85` |
| xterm (default)  | `#000000` | `#ffffff` | `#000000` `#cd0000` `#00cd00` `#cdcd00` `#0000ee` `#cd00cd` `#00cdcd` `#e5e5e5` | `#7f7f7f` `#ff0000` `#00ff00` `#ffff00` `#5c5cff` `#ff00ff` `#00ffff` `#ffffff` |

Sources: the owner's Ghostty themes, Ghostty's bundled Catppuccin themes, and xterm's
`XTerm-col.ad` with the VT100 default black on white.

## Roles

Roles resolve to complete `Style` values through the environment, not to bare colours
([System and custom style plumbing](../spec.md#system-and-custom-style-plumbing)). System
component styles consume them; apps may replace any role for a subtree. Roles are named
bare in every doc and legend (`primary`, not `semantic.primary`) (owner decision,
2026-10-19). Whether a control is enabled, selected, focused or destructive stays semantic
component state; roles only describe presentation.

Columns: **Derived** uses the [neutral ladder](#neutral-ladder) and the
[hue guard](#hue-guard). **Slots dark** also serves a terminal whose background is
unknown, unless `COLORFGBG` names a light slot. A slots cell such as `ansi 14` gives the
unmeasured pair choice; with the pair measured, rule 1 of the hue guard picks the slot.
`ansi N` is `.ansi(n)`; `bg ansi 8` is an ANSI 8 background; "none" means no colour and no
attribute.

### Text roles

| Role        | Definition                                                                                                                                                                                                                                                                  | Consumers                                                                                                                                                                                                                                    | Derived          | Slots dark       | Slots light      | `NO_COLOR` |
| ----------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------- | ---------------- | ---------------- | ---------- |
| `primary`   | Ordinary content: labels, values, body text, titles                                                                                                                                                                                                                         | every component                                                                                                                                                                                                                              | `.default`       | `.default`       | `.default`       | none       |
| `secondary` | Receding text: descriptions, captions, prompts, LabeledContent labels, KeyLegend keys (bold) and descriptions, percent and value labels, line numbers, unchecked marks, disclosure glyphs, in-range arrows, `false`, quoted text, the `pending`, `image` and `secret` icons | badge, box, button (cancel intent), code-view, content-unavailable-view, form, image, key-legend, label, labeled-content, markdown, multi-picker, outline, picker, progress-view, section, split-view, stepper, tab-view, text-field, toggle | `ink2`           | dim              | dim              | dim        |
| `border`    | Structural lines: frames, rules, separators, junctions, scroll and progress tracks, outline guides, quote rails, fence rows, Image's placeholder fill                                                                                                                       | border, box, code-view, content-unavailable-view, divider, form, image, key-legend, leading-rail, markdown, outline, progress-view, scroll-indicator, scroll-view, split-view, table, tab-view                                               | `ink3`           | dim              | dim              | dim        |
| `disabled`  | Disabled labels and glyphs, Stepper arrows at a limit, unfilled glyphs of a disabled Button, a non-resizable split handle                                                                                                                                                   | button, split-view, stepper, text-field, toggle                                                                                                                                                                                              | `ink3`           | dim              | dim              | dim        |
| `focus`     | The focus owner: the terminal's default foreground in bold, foreground only, never a background ([Focus](#focus))                                                                                                                                                           | border, box, button, form, picker, split-view, stepper, tab-view, table, text-field, toggle                                                                                                                                                  | `.default`, bold | `.default`, bold | `.default`, bold | bold       |

`secondary` absorbs the catalog's `muted`, `output`, `semantic.secondary` and
`semantic.muted`. `border` and `disabled` share a quieter ink and stay separately
overridable; all three are dim in `slots` and `NO_COLOR` (owner decision, 2026-10-19).
`border` is the dim default foreground there (owner decision, 2026-10-10).

### Hue roles

| Role          | Definition                                                                                                                                                                       | Consumers                                                                                                                                                                                                                | Derived    | Slots dark | Slots light | `NO_COLOR` |
| ------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ---------- | ---------- | ----------- | ---------- |
| `accent`      | The application accent: checked and picked marks, scroll thumbs, progress fill, spinners, default Label icons, Markdown headings and links, the normal and default Button intent | badge, button, code-view, content-unavailable-view, form, label, labeled-content, markdown, multi-picker, outline, picker, progress-view, scroll-indicator, scroll-view, split-view, tab-view, table, text-field, toggle | `hue(6)`   | ansi 14    | ansi 6      | bold       |
| `info`        | Neutral information and entered values: Callout `info`, enum, select and multi values, typed drafts, Markdown list markers                                                       | badge, callout, form, markdown, multi-picker, picker                                                                                                                                                                     | `hue(4)`   | ansi 12    | ansi 4      | none       |
| `success`     | Success and true states                                                                                                                                                          | badge, callout, form, label, labeled-content, outline, split-view, toggle                                                                                                                                                | `hue(2)`   | ansi 10    | ansi 2      | none       |
| `warning`     | Warnings; Markdown inline code                                                                                                                                                   | badge, callout, content-unavailable-view, label, labeled-content, markdown, outline                                                                                                                                      | `hue(3)`   | ansi 11    | ansi 3      | none       |
| `error`       | Errors, failing fields, overflow counts                                                                                                                                          | badge, callout, form, label, labeled-content, outline, text-field                                                                                                                                                        | `hue(1)`   | ansi 9     | ansi 1      | none       |
| `destructive` | Button's `.destructive` intent. The `error` `Style` with no underline (owner decision, 2026-10-10); separately overridable                                                       | button                                                                                                                                                                                                                   | as `error` | as `error` | as `error`  | none       |

The tones `info` (blue 4/12), `success` (green 2/10), `warning` (yellow 3/11) and `error`
(red 1/9) enter 1.0, overturning the old "no success, warning or information roles" rule:
nine specified components already depend on them (owner decision, 2026-10-19). `accent`
stays cyan 6/14 and carries no bold in colour tiers; legends add bold where they want it.
Tessera adds no `pending` or `user` tone: `pending` is an icon name in `secondary`, and no
component consumes `user`. The magenta pair 5/13 serves only `syntax.constant`.

### Fill roles

| Role                 | Definition                                                                                                        | Consumers                           | Derived                                     | Slots dark                 | Slots light                | `NO_COLOR`                 |
| -------------------- | ----------------------------------------------------------------------------------------------------------------- | ----------------------------------- | ------------------------------------------- | -------------------------- | -------------------------- | -------------------------- |
| `surface`            | A quiet raised background: KeyLegend keycaps, Picker's inactive-segment band, table stripes, Markdown inline code | key-legend, markdown, picker, table | bg `fill8`                                  | bg ansi 8                  | none                       | none                       |
| `hover`              | Background of the pointer-hovered row                                                                             | form, list, table                   | bg `fill12`                                 | underline on the row label | underline on the row label | underline on the row label |
| `selection.fill`     | Selected rows of a focused List, Table, Outline or SplitView pane; cell text keeps its own role                   | list, outline, split-view, table    | bg `faint(accent)`; reverse at `indexed256` | reverse                    | reverse                    | reverse                    |
| `selection.inactive` | Selected rows of an unfocused widget, and Table's header-mode row                                                 | list, table                         | bg `fill16`                                 | dim                        | dim                        | dim                        |
| `disabled.fill`      | Fill and caps of a disabled filled or tinted Button                                                               | button                              | bg `fill8`                                  | bg ansi 8                  | none                       | none                       |
| `disabled.label`     | Label on `disabled.fill`                                                                                          | button                              | `ink3`                                      | ansi 7                     | dim                        | dim                        |

Stripes use `surface` (owner decision, 2026-10-10) and are dropped wherever `surface` has
no fill. Markdown inline code sits on `surface` (owner decision, 2026-10-19).

Row hover (owner decisions, 2026-10-19): Table and List rows show `hover` by default, and
request pointer motion (`wantsMouseMotion`, Spec Phase 4 Slice 5) while they are live in
the graph, scrolled into view or not
([terminal requirements](../spec.md#terminal-requirements-aggregation)); apps opt out with
a modifier whose placeholder name is `.rowHover(.disabled)`, and table.md and list.md
settle the final name. Hover and stripes coexist: a hovered stripe row shows `hover` in
place of the stripe. A selected row keeps its selection fill under the pointer. Where no
fill can stand apart (`slots` and `NO_COLOR`; in 16 colours a hover fill could only repeat
the ANSI 8 stripe), hover is an underline on the row label.

### Composite styles

Functions of a role `R`. Legends keep their spelling: `fg=contrast bg=R bold` is
`solid(R)`, `fg=R bg=faint(R)` is `faint(R)`.

| Style      | Definition                                                            | Consumers                                                                                                     | Derived                                                                                  | Slots dark                                                                                                                                                                  | Slots light                                                                                                  | `NO_COLOR`                                |
| ---------- | --------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------ | ----------------------------------------- |
| `solid(R)` | A solid fill in `R` with a readable bold label; caps in `R`           | badge, button (`.filled`), content-unavailable-view, picker (active pill and segment), tab-view (active chip) | bg `R`, fg `on(R)` (`contrast`), bold; caps fg `R`. `primary` and `focus`: reverse, bold | hue `R`: fg `R`, reverse, bold; caps fg `R`. `primary` and `focus`: reverse, bold; caps `.default`. `secondary` and `disabled`: bg ansi 8, `.default`, bold; caps fg ansi 8 | hue `R`: as dark. `primary` and `focus`: as dark. `secondary` and `disabled`: reverse, bold; caps `.default` | reverse, bold; caps `.default`            |
| `faint(R)` | A tinted fill derived from `R`; label in `R`; caps in the fill colour | border, box, button (`.tinted`), content-unavailable-view                                                     | bg `faint(R)`, fg `R`; caps fg `faint(R)`                                                | bg ansi 8, fg `R`'s slots value; caps fg ansi 8                                                                                                                             | fg `R`'s slots value, no fill; caps blank                                                                    | reverse (owner decision); caps `.default` |
| `contrast` | The label colour inside `solid(R)`: `on(R)`. Not a free-standing role | badge, box, button, callout, content-unavailable-view, picker, tab-view                                       | `on(R)`                                                                                  | the reverse-video label of `solid(R)`                                                                                                                                       | as dark                                                                                                      | reverse                                   |

In `slots`, `fg R` plus reverse paints the cell in `R` with the terminal's own background
colour as the label: "default background as foreground" without knowing the background
(badge.md: 16-colour labels are reverse video, owner decision, 2026-10-10). Solid fills
are reverse video in 16 colours on both schemes (owner decision, 2026-10-19). `secondary`
and `disabled` have no slot colour to reverse, so they take the ANSI 8 fill on dark and
plain reverse video on light. `faint(focus)` is the `fill16` grey under a bold
default-foreground label.

Composite uses in the catalog:

- **Badge tones:** `neutral` is `solid(secondary)`; `accent`, `info`, `success`, `warning`
  and `error` are `solid` of the same-named role.
- **Button:** the intent colour `C` is `accent` (normal and default action), `secondary`
  (cancel) or `destructive`. `.filled` is `solid(C)`, `.tinted` is `faint(C)`, `.plain`
  draws its label in `primary` (normal) or `C`. Focused, `C` becomes `focus`: filled is
  `solid(focus)`, a chip in the default foreground (owner decision, 2026-10-19); tinted is
  `faint(focus)` with a bold label; plain underlines its label in `focus`. Disabled:
  `disabled.fill` and `disabled.label`, unfilled glyphs in `disabled`. Hovered: underline
  only. `destructive` never underlines.
- **Callout:** rail, icon and body in the kind's role; the header badge is `solid(kind)`;
  without a kind the rail is `info` and the body `primary`.
- **KeyLegend keycaps:** `primary` on `surface`, padded one cell each side. Where
  `surface` has no fill (`NO_COLOR`, slots light) the legend falls back to the plain look
  (owner decisions, 2026-10-10 for `NO_COLOR` and 2026-10-19 for slots light).
- **Picker radio group:** the selected chip is `solid(accent)` between pill caps, and
  underlines while the group is focused.
- **Segmented control** (Picker's `.segmented` style; owner decision, 2026-10-19): every
  segment has one padding cell on each side. The selected segment is `solid(accent)`,
  focused or not, and colour tiers draw no underline. Unselected segments are `secondary`
  on `surface`; while the control is focused they brighten to `primary`. Under `NO_COLOR`
  the selected segment is reverse and bold, and underlines while the control is focused.
  Segment icons are monochrome [icon catalog](#icon-catalog) glyphs.
- **TabView:** the active chip is `solid(focus)` while the tab view is focused, a chip in
  the default foreground, and `solid(accent)` otherwise; inactive titles are `secondary`
  with no fill.

### Syntax roles

A small fixed set for CodeView highlighters and Markdown code blocks. A highlighter
returns these roles; no grammar ships in 1.0 (owner decision, 2026-10-10). Each hue role
uses the same pair and guard as a tone, but is a separate role, so `.tint(_:)` never
recolours code (owner decision, 2026-10-19).

| Role                 | Tokens                                            | Derived        | Slots dark  | Slots light | `NO_COLOR`  |
| -------------------- | ------------------------------------------------- | -------------- | ----------- | ----------- | ----------- |
| `syntax.plain`       | identifiers, plain text, the body of a code block | `.default`     | `.default`  | `.default`  | none        |
| `syntax.keyword`     | keywords, storage modifiers, control flow         | `hue(6)`       | ansi 14     | ansi 6      | none        |
| `syntax.string`      | string, character and regex literals              | `hue(2)`       | ansi 10     | ansi 2      | none        |
| `syntax.constant`    | numbers, booleans, named constants                | `hue(5)`       | ansi 13     | ansi 5      | none        |
| `syntax.type`        | types, protocols, builtins                        | `hue(3)`       | ansi 11     | ansi 3      | none        |
| `syntax.function`    | function, method and macro names                  | `hue(4)`       | ansi 12     | ansi 4      | none        |
| `syntax.comment`     | comments and doc comments                         | `ink2`, italic | dim, italic | dim, italic | dim, italic |
| `syntax.punctuation` | punctuation, operators, delimiters                | `ink2`         | dim         | dim         | dim         |

Syntax colours render in `slots` too, which replaces code-view.md's "syntax colours drop
at 16-colour". Readability floor (owner decision, 2026-10-19): at `ansi16` depth with `bg`
and the chosen slot measured, a syntax hue whose slot reaches less than 3:1 against `bg`
resolves as `syntax.plain` (`syntax16` in the
[reference algorithm](#reference-algorithm)). A slot the probe did not measure keeps its
colour. CodeView's line-number gutter is `secondary`; its `│` separator and Markdown's
fence rows are `border`.

### Focus

How a focused view announces itself, decided once. Owner decision, 2026-10-19: `focus` has
no hue. It is the terminal's default foreground in bold, foreground only, and it looks the
same in `derived`, `slots` and `NO_COLOR`. Focus is carried by weight: the heavy ring, the
bold label, the `❯` cursor and, on filled controls, `solid(focus)`, a chip in the default
foreground. Apps may give `focus` an explicit colour ([Overrides](#overrides)). This
retires the black-on-yellow `semantic.focus` pair and the provisional violet of
2026-10-10: violet was the hue closest to `error` on Miniwinter Dark (ΔE 4.6) and
Catppuccin Mocha (ΔE 5.8), and on pastel themes no hue is distinct enough to mean focus
alone. The owner revisits the choice once live widgets exist.

The look follows the six rules in [Focus border](primitives/border.md#focus-border), which
replace the old `focus.border` and `focus.content` rows:

| Rule                    | Look                                                                                   | `NO_COLOR`            | ASCII                         |
| ----------------------- | -------------------------------------------------------------------------------------- | --------------------- | ----------------------------- |
| 1. Self focus           | the view's ring switches to the `heavy` set in `focus`; geometry unchanged             | heavy set, bold       | `ascii` set, bold             |
| 2. Focus within         | the nearest bordered ancestor's ring changes from `border` to `focus` at normal weight | bold ring             | bold                          |
| 3. Cursor rows          | Form, Stepper host, Picker menu and TabView rows: `❯` cursor and bold `focus` label    | cursor and bold label | `>` cursor and bold label     |
| 4. Split dividers       | heavy line in `focus`; joints use the heavy junctions                                  | heavy line, bold      | `\|` or `-`, bold; `+` joints |
| 5. Tables               | a bordered table takes rule 1 or 2 on its outer ring                                   | as rules 1 and 2      | as rules 1 and 2              |
| 6. Heavy, double, ASCII | heavy and double rings keep their set and change from `border` to `focus`              | bold                  | bold                          |

Borderless controls take the `focus` role on their own content. Controls may add a cue of
their own: a standalone Toggle and a plain Button underline the label, `NO_COLOR` Button
focus is an underline, and a segmented control brightens its unselected labels.

### Selection

| Token                | Value                                                                                                                                    | Used by                         |
| -------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------- |
| `selection.bar`      | `▌` in the leading gutter, in `accent` while the widget is focused and `secondary` when inactive (owner decision, 2026-10-19); ASCII `>` | List, Table, Outline            |
| `selection.fill`     | the [fill role](#fill-roles): `faint(accent)` when derived, reverse video at `indexed256` and in every other tier                        | List, Table, Outline, SplitView |
| `selection.inactive` | the fill role: `fill16` when derived, dim otherwise                                                                                      | List, Table                     |
| `selection.member`   | `●` before each member of a multi-selection; ASCII `*`                                                                                   | Table                           |

The bar's cell never takes a reverse-video fill (owner decision, 2026-10-19). Wherever
`selection.fill` is reverse video (`slots`, `indexed256`, `NO_COLOR`), the bar draws on
the terminal background and the fill starts at the next cell: a bar inside a reverse cell
would sit on its own colour (1.0:1 for cyan on Miniwinter Dark's foreground). In `derived`
the faint fill covers the bar cell too.

Multi-select paints `selection.fill` on every member row and `selection.bar` on the cursor
row only. A table whose left border occupies the gutter draws no bar.

## Glyph tokens

### Icon catalog

One row per semantic name, read by [Label](primitives/label.md) and every component that
shows an icon. Unknown names draw their raw name text. "—" falls back to the next charset;
"none" draws no icon in that charset.

The Unicode column holds text-presentation symbols only; Tessera never draws colour emoji
and never emits the emoji variation selector U+FE0F. A name without a good monochrome
symbol draws no icon under `.unicode` (owner decision, 2026-10-19).

| Name          | Nerd Font | Unicode | ASCII   | Default role | Consumers                                |
| ------------- | --------- | ------- | ------- | ------------ | ---------------------------------------- |
| `error`       | U+F00D    | ✘       | `[!!]`  | `error`      | label, callout, form                     |
| `success`     | U+F00C    | ✔       | `[ok]`  | `success`    | label, callout                           |
| `warning`     | U+F071    | ⚠       | `[!]`   | `warning`    | label, callout, content-unavailable-view |
| `info`        | U+F05A    | ℹ       | `(i)`   | `info`       | callout                                  |
| `done`        | —         | •       | `*`     | `success`    | label                                    |
| `pending`     | U+F254    | none    | `[*]`   | `secondary`  | label                                    |
| `running`     | U+F110    | ⟳       | `[~]`   | `accent`     | label                                    |
| `idle`        | U+F10C    | ○       | `[-]`   | `accent`     | label                                    |
| `parked`      | U+F04C    | ⏸       | `[\|]`  | `accent`     | label                                    |
| `stopped`     | U+F28D    | ⏹       | `[#]`   | `accent`     | label                                    |
| `enabled`     | U+F111    | ●       | `[x]`   | `accent`     | label                                    |
| `cursor`      | U+F054    | ❯       | `>`     | `accent`     | label                                    |
| `folder`      | U+F07B    | none    | `[D]`   | `accent`     | label, outline, picker                   |
| `folder-open` | U+F07C    | none    | `[O]`   | `accent`     | label, outline                           |
| `file`        | U+F15B    | none    | `[F]`   | `accent`     | label, outline, picker                   |
| `file-diff`   | U+EAE9    | ▤       | `[F]`   | `accent`     | picker                                   |
| `git`         | U+F1D3    | ⎇       | `git:`  | `accent`     | label                                    |
| `image`       | U+F03E    | `[img]` | `[img]` | `secondary`  | image                                    |
| `mail`        | U+F0E0    | ✉       | `[@]`   | `accent`     | content-unavailable-view                 |
| `search`      | U+F002    | none    | `[/]`   | `accent`     | content-unavailable-view                 |
| `secret`      | U+F023    | none    | `[**]`  | `secondary`  | form                                     |
| `grid`        | U+F00A    | ▦       | `grid`  | `accent`     | picker                                   |
| `list`        | U+F03A    | ≡       | `list`  | `accent`     | picker                                   |
| `gear`        | U+F013    | ⚙       | `gear`  | `accent`     | picker, tab-view                         |
| `home`        | U+F015    | none    | `home`  | `accent`     | tab-view                                 |
| `terminal`    | U+F120    | none    | `term`  | `accent`     | tab-view                                 |

Corrections and additions (owner decision, 2026-10-19): `folder` is U+F07B, the closed
folder (U+F115 is Font Awesome's open-folder outline); `idle` is U+F10C, the empty circle,
so it no longer shares `enabled`'s filled U+F111; `info`, `mail`, `search` and `secret`
are new rows. `file-diff`, `grid`, `list`, `gear`, `home` and `terminal` are the names
Picker's segments and TabView's tabs use; their ASCII forms are omp2's (`file-diff` shares
`file`'s `[F]`, as in omp2).

Default roles follow omp2's rule: `error` takes `error`; `done` and `success` take
`success`; `warning` takes `warning` (owner decision, 2026-10-10); `info` takes `info`;
`pending`, `image` and `secret` take `secondary`; any other name takes `accent`. Callers
may replace the icon's role (`.labelIconRole(_:)`); the title stays `primary`.
ContentUnavailableView is such a caller: it draws `mail`, `search` and its other non-tone
icons in `secondary`, and a tone icon (`warning`, `error`, `success`, `info`) keeps its
default role ([ContentUnavailableView](widgets/content-unavailable-view.md)). Icons
written inside running text take the surrounding text role (owner decision, 2026-10-10).

### Nerd Font cells

A Nerd Font glyph draws about one and a half cells of ink in one cell of advance (Maple
Mono NF at 15 px: 9 px advance, 13.9 px ink). Owner decision, 2026-10-19: a Nerd Font icon
or spinner frame occupies two cells in layout, the glyph and one blank cell it may draw
into.

- The blank cell is a real U+0020 written to the buffer, never an untouched cell: kitty
  widens a private-use glyph only when a space or U+2002 follows it. Ghostty behaves
  similarly (unverified).
- Icon and title: `icon(2) + title`. The blank cell is also the icon-title gap, so the
  title starts at the same column as after a one-cell Unicode icon and its one-cell gap.
- Icon-only segment: `pad + icon(2) + pad`, four cells.
- Spinner: the frame's blank cell is the spinner-label gap ([Spinners](#spinners)).
- Unicode and ASCII icons keep their measured display width.
- Powerline caps (U+E0B6, U+E0B4) stay one cell: they abut the fill they cap.

### Marks

| Token                                | Nerd Font | Unicode   | ASCII     | Used by                                  |
| ------------------------------------ | --------- | --------- | --------- | ---------------------------------------- |
| `cursor`                             | U+F054    | `❯`       | `>`       | Form, Stepper host, Picker, TabView rows |
| `selection.bar`                      | `▌`       | `▌`       | `>`       | List, Table, Outline                     |
| `selection.member`                   | `●`       | `●`       | `*`       | Table                                    |
| `disclosure.expanded` / `.collapsed` | `▾` / `▸` | `▾` / `▸` | `-` / `+` | Section, Outline                         |
| `dropdown`                           | `▾`       | `▾`       | `v`       | Form, Picker, MultiPicker                |
| `sort.ascending` / `.descending`     | `↑` / `↓` | `↑` / `↓` | `^` / `v` | Table                                    |
| `truncation.mark`                    | `…`       | `…`       | `~`       | every truncating text                    |

`dropdown` is the open marker after a collapsed value in a host row. It is a separate
token from `disclosure.*`: it marks a value that opens a menu, not a section that expands,
so its ASCII is `v` and it draws in `secondary`.

Disclosure glyphs draw in `secondary`. Every ASCII expander is `-` or `+`: Outline drops
its `v` and `>`, because `>` is already the cursor and selection mark (owner decision,
2026-10-19). The cursor is followed by one space in every charset, so under `.nerdFont`
its glyph and that space form the two-cell slot of [Nerd Font cells](#nerd-font-cells).

### Caps

The ends of Button and Badge shapes ([Button shape](widgets/button.md#shape)).

| Token          | Nerd Font                                                      | Unicode                      | ASCII                                                                                |
| -------------- | -------------------------------------------------------------- | ---------------------------- | ------------------------------------------------------------------------------------ |
| `caps.squared` | `▐` label `▌`, in the fill colour                              | same                         | Button: falls back to `.rectangle`; Badge: `[` label `]` in the tone colour, no fill |
| `caps.capsule` | U+E0B6 label U+E0B4 (Powerline round caps), in the fill colour | falls back to `caps.squared` | as `caps.squared`                                                                    |

The Powerline caps are the "Nerd Font capability" Button's open question asks for: they
draw exactly when `\.charset` is `.nerdFont`.

### Border sets

Glyph tables for `Border` and frame drawing. Names follow the style, not the codepoints.
The junction column is `├ ┤ ┬ ┴ ┼` in that order.

| Set       | Corners | H   | V   | Junctions | Notes                                                |
| --------- | ------- | --- | --- | --------- | ---------------------------------------------------- |
| `light`   | ┌┐└┘    | ─   | │   | ├┤┬┴┼     | default; `BorderStyle.single` renders this set       |
| `rounded` | ╭╮╰╯    | ─   | │   | ├┤┬┴┼     | Box's default; shares `light` junctions              |
| `heavy`   | ┏┓┗┛    | ━   | ┃   | ┣┫┳┻╋     | self focus (rule 1); a focused split handle's joints |
| `double`  | ╔╗╚╝    | ═   | ║   | ╠╣╦╩╬     | rarely; retro chrome                                 |
| `ascii`   | ++++    | -   | \|  | +++++     | degradation target                                   |

A focused heavy line takes its own set's junctions where it meets a light line, so the
joint is heavy rather than mixed-weight (owner decision, 2026-10-10). Blended junctions
(`divider.blending`) cover `light` and `ascii` only. Junctions draw in `border`, or in
`focus` where a focused line meets them.

### Divider glyphs

| Style    | Horizontal | Vertical |
| -------- | ---------- | -------- |
| `light`  | ─          | │        |
| `heavy`  | ━          | ┃        |
| `double` | ═          | ║        |
| `dashed` | ╌          | ╎        |
| `dotted` | ┈          | ┊        |
| `ascii`  | -          | \|       |

`dotted` joins the table because the `dotted` scroll preset already draws it. Leading
rails use `light`, `heavy` and `ascii` verticals. Callouts cite a row as
`divider.<style>`, for example `divider.light`.

### Scroll indicators

[ScrollIndicator](primitives/scroll-indicator.md) presets replace the old
`scrollbar.weight` and `scrollbar.track` axes. One closed list; each preset fixes its
thumb and track together (owner decisions, 2026-10-10 and 2026-10-11). The thumb paints in
`accent`, the track in `border`.

| Preset               | Vertical thumb | Vertical track | Horizontal thumb, Nerd Font | Horizontal thumb, Unicode | Horizontal track       |
| -------------------- | -------------- | -------------- | --------------------------- | ------------------------- | ---------------------- |
| `standard` (default) | `█`            | `│`            | `🬋` (U+1FB0B)               | `━`                       | `─`                    |
| `thin`               | `┃`            | `│`            | `━`                         | `━`                       | `─`                    |
| `inner`              | `▌`            | `│`            | `🮂` (U+1FB82)               | `▔`                       | `─`                    |
| `outer`              | `▐`            | `│`            | `▂`                         | `▂`                       | `─`                    |
| `dashed`             | `█`            | `╎`            | `🬋`                         | `━`                       | `╌`                    |
| `dotted`             | `█`            | `┊`            | `🬋`                         | `━`                       | `┈`                    |
| `heavy`              | `█`            | `┃`            | `🬋`                         | `━`                       | `━`; `─` under Unicode |
| `thumbOnly`          | `█`            | none           | `🬋`                         | `━`                       | none                   |

The Legacy Computing thumbs `🬋` and `🮂` draw only under `.nerdFont`; `.unicode` uses `━`
and `▔` (owner decision, 2026-10-11). Under `.unicode` the `heavy` horizontal thumb `━`
would sit on a `━` track, which breaks the rule that no thumb shares its track's glyph, so
that track becomes `─` (owner decision, 2026-10-19). `scrollIndicator.ascii`: every thumb
is `#`, every track `|` or `-`, and `thumbOnly` keeps a blank track.

| Placement            | Reserves                          | Track                                                  | Used by                 |
| -------------------- | --------------------------------- | ------------------------------------------------------ | ----------------------- |
| `reserved` (default) | one trailing column or bottom row | the preset's track                                     | ScrollView, List, Table |
| `.border`            | nothing                           | the nearest bordered Box's edge; only the thumb paints | Box                     |

`.border` falls back to `reserved` without a bordered Box ancestor (owner decision,
2026-10-10). Thumb length is `max(1, floor(track x viewport / content))` for every
combination. Indicators appear only when content overflows.

### Bars and ramps

| Token               | Unicode and Nerd Font   | ASCII | Role                                             |
| ------------------- | ----------------------- | ----- | ------------------------------------------------ |
| `bar.fill`          | `█`                     | `#`   | `accent`                                         |
| `bar.track`         | `░`                     | `.`   | `border`                                         |
| `image.placeholder` | `░`                     | `.`   | `border`                                         |
| `image.ramp`        | space, then `.:-=+*#%@` | same  | none; ink density stands in for pixel brightness |

The density ramp is ten steps, a space then `.:-=+*#%@`. With `L` the cell's brightness
from 0 to 1, as Image defines it, a dark scheme takes step `round(L * 9)`, so bright cells
get dense glyphs (owner decision, 2026-10-18). A light scheme takes step
`round((1 - L) * 9)`, so dark cells get dense glyphs (owner decision, 2026-10-19, amending
the dark-only ramp). Transparent cells stay blank in both. The ramp is already ASCII, so
`.ascii` leaves it unchanged; it only replaces Image's colour half-block cells with `#`
(image.md).

### Spinners

Frame sets for ProgressView's indeterminate style (owner decision, 2026-10-19). A spinner
frame is followed by one space, then the label. A one-cell frame adds that space as the
gap; a Nerd Font frame is two cells, and its blank cell is the gap
([Nerd Font cells](#nerd-font-cells)). Either way the label starts two cells in and never
shifts.

| Set                 | Frames                                            | Interval     | Without its charset                 |
| ------------------- | ------------------------------------------------- | ------------ | ----------------------------------- |
| `braille` (default) | ⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏                               | 80 ms        | ASCII: `line`                       |
| `orbit`             | ⣾ ⣽ ⣻ ⢿ ⡿ ⣟ ⣯ ⣷                                   | 80 ms        | ASCII: `line`                       |
| `clock`             | Nerd Font U+F1456, U+F144B to U+F1455 (12 frames) | 80 ms        | `orbit`; ASCII: `line`              |
| `arc`               | Nerd Font U+EE06 to U+EE0B                        | 100 ms       | `orbit`; ASCII: `line`              |
| `slices`            | Nerd Font U+F0A9E to U+F0AA5                      | 125 ms       | `orbit`; ASCII: `line`              |
| `halves`            | ◐ ◓ ◑ ◒                                           | 120 ms       | ASCII: `line`                       |
| `line`              | `\|` `/` `-` `\`                                  | 120 ms       | already ASCII                       |
| custom              | app frames and interval                           | app interval | the app's ASCII frames, else `line` |

A fallback set runs at its own interval. `quarters` and the trial `quadrant` set are
dropped: Maple Mono NF carries only `◶` of the quarters, so the frames jump between fonts.
`halves` stays at the owner's request, although Geometric Shapes glyphs are absent from
many coding fonts (Maple Mono NF included) and render from a fallback font; an
app-supplied custom set such as `◢ ◣ ◤ ◥` has the same font dependence.

The spinner glyph is `accent`. Frames derive from the injected clock; a spinner stores no
state. Tessera has no reduced-motion setting in 1.0: terminals report no such preference,
and the spinner is the only animation in the catalog. Whether shimmer and elapsed time
join it in 1.0 is an [open question](widgets/progress-view.md#open-questions).

### Truncation

| Token             | Value                    | Notes                                    |
| ----------------- | ------------------------ | ---------------------------------------- |
| `truncation.mark` | `…` (width 1)            | `~` in ASCII                             |
| policies          | `tail`, `head`, `middle` | `tail` default; grapheme-safe boundaries |

## Degradation ladder

What each family becomes as capabilities shrink, decided once here. Capability detection
is advisory ([Slice 6](../spec.md#slice-6-terminal-capability-detection)); the ladder is
what "reduce feature use, do not break" looks like. Colour and charset are separate axes.

Colour:

| Family                                              | `derived`                                                   | `slots`, dark                            | `slots`, light                           | `monochrome` (`NO_COLOR`)                       |
| --------------------------------------------------- | ----------------------------------------------------------- | ---------------------------------------- | ---------------------------------------- | ----------------------------------------------- |
| text roles                                          | `ink2`, `ink3`                                              | dim                                      | dim                                      | dim                                             |
| focus                                               | default foreground, bold                                    | default foreground, bold                 | default foreground, bold                 | bold                                            |
| hue roles                                           | measured slot, guarded                                      | measured slot, else bright               | measured slot, else normal               | `accent` bold; tones none                       |
| neutral fills (surface, stripes, keycaps, disabled) | `fill8`                                                     | bg ansi 8                                | none                                     | none                                            |
| hover                                               | `fill12`                                                    | underline on the row label               | underline on the row label               | underline on the row label                      |
| selection                                           | `faint(accent)`, reverse at `indexed256`; inactive `fill16` | reverse, bar cell unfilled; inactive dim | reverse, bar cell unfilled; inactive dim | reverse, bar cell unfilled; inactive dim        |
| solid fills                                         | `R` with `on(R)`, bold; `primary` reverse                   | reverse, bold                            | reverse, bold                            | reverse, bold                                   |
| tinted fills                                        | `faint(R)`                                                  | bg ansi 8                                | none                                     | reverse                                         |
| syntax                                              | guarded hues                                                | slots; below 3:1 plain                   | slots; below 3:1 plain                   | comments dim italic, punctuation dim; rest none |
| Image                                               | pixel colours                                               | nearest slot                             | nearest slot                             | density ramp, inverted on light                 |

Charset:

| Family        | `.nerdFont`                          | `.unicode`                               | `.ascii`         |
| ------------- | ------------------------------------ | ---------------------------------------- | ---------------- |
| icons         | Nerd Font column, two cells          | Unicode column; "none" rows draw no icon | ASCII column     |
| caps          | half blocks; Powerline capsule       | half blocks; capsule is squared          | `.rectangle`     |
| borders       | any set                              | any set                                  | `ascii` set      |
| junctions     | per set                              | per set                                  | `+`              |
| dividers      | per style                            | per style                                | `-` and `\|`     |
| scroll thumbs | Legacy Computing                     | `━` and `▔`; `heavy` track `─`           | `#`              |
| cursor        | U+F054                               | `❯`                                      | `>`              |
| selection bar | `▌`                                  | `▌`                                      | `>`              |
| disclosure    | `▾` / `▸`                            | `▾` / `▸`                                | `-` / `+`        |
| spinners      | every set, two-cell Nerd Font frames | Nerd Font sets become `orbit`            | `line` at 120 ms |
| bars          | `█` and `░`                          | `█` and `░`                              | `#` and `.`      |
| truncation    | `…`                                  | `…`                                      | `~`              |

ASCII substitutes only these shared glyph families; layout geometry never changes.

## Requirements

- `scheme is light when black text out-contrasts white text on the background` (colour
  scheme)
- `unknown background resolves the dark scheme unless COLORFGBG names a light slot`
  (colour scheme)
- `mix rounds each channel in integer percent` (arithmetic)
- `neutral fills blend eight twelve and sixteen percent of the foreground` (neutral
  ladder: `fill8`, `fill12`, `fill16`)
- `secondary steps toward the foreground until it reaches four point five to one` (neutral
  ladder: `ink2`)
- `border and disabled share the tertiary ink` (neutral ladder: `ink3`)
- `hue role picks the higher-contrast slot of its normal and bright pair` (hue guard: pair
  choice)
- `slots tier uses bright slots on dark and normal slots on light without measurement`
  (hue guard: pair choice; roles: slots columns)
- `hue role guard mixes toward the scheme pole until it passes against background and fill16`
  (hue guard: guard)
- `unadjusted hue role is emitted as its ANSI slot` (hue guard: emission)
- `contrast label is the background or foreground with the higher contrast` (fills and
  labels: `on`)
- `solid primary is reverse video and bold in every tier` (fills and labels:
  `solid(primary)`)
- `derived values match the reference table for the five review themes` (reference values)
- `role with an unknown input resolves in the slots tier` (tiers)
- `ansi16 depth never emits derived colours` (tiers)
- `indexed256 quantises derived shades except the selection fill` (tiers)
- `light slots tier paints no neutral fill` (fill roles; composite styles)
- `solid fill in the slots tier is the role colour in reverse video` (composite styles:
  `solid`)
- `NO_COLOR resolves every role to attributes only` (roles: `NO_COLOR` columns)
- `destructive resolves to the error style without underline` (hue roles: `destructive`)
- `focus is the bold default foreground in every tier and never paints a background` (text
  roles: `focus`; focus)
- `focused filled control draws a default foreground chip` (composite styles: Button;
  focus)
- `app focus colour override replaces the default foreground` (overrides; focus)
- `selection fill is the faint accent when derived and reverse video otherwise` (fill
  roles: `selection.fill`)
- `selection bar is accent when focused and secondary when inactive` (selection:
  `selection.bar`)
- `selection bar cell never takes a reverse video fill` (selection)
- `hover fill is distinct from the stripe and the inactive selection` (fill roles:
  `hover`; neutral ladder)
- `hover is an underline on the row label where no fill exists` (fill roles: `hover`)
- `selected row keeps its selection fill under the pointer` (fill roles: row hover)
- `segmented control brightens unselected labels while focused` (composite styles:
  segmented control)
- `segmented control underlines the selected segment only under NO_COLOR` (composite
  styles: segmented control)
- `tint overrides accent and the styles derived from it` (overrides)
- `app colour overrides skip the pair choice and the guard` (overrides)
- `tint never recolours syntax roles` (syntax roles)
- `syntax roles stay coloured in the slots tier` (syntax roles)
- `sixteen colour syntax hue below three to one resolves as plain` (syntax roles:
  readability floor)
- `colour probe asks only for the background under NO_COLOR` (probe: rule 1)
- `colour probe re-runs on resume from suspend` (probe: rule 1)
- `colour probe reply after the sentinel is applied as an update` (probe: rule 5)
- `colour probe timeout leaves inputs unknown, not failed` (probe: rule 4)
- `colour scheme notification re-runs the colour round and repaints` (probe: rule 7)
- `non UTF-8 locale resolves the ascii charset over every other input` (charset: rule 1)
- `unset C and POSIX locales count as UTF-8` (charset: rule 1)
- `NERDFONT off value caps the charset at unicode over the app intent` (charset: rule 2)
- `app charset intent applies below the user veto` (charset: rule 3)
- `NERDFONT on value selects nerd font only for the automatic intent` (charset: rule 4)
- `charset defaults to unicode and never reads the terminal identity` (charset: rule 6)
- `charset falls back per glyph row from nerd font to unicode to ascii` (charset; icon
  catalog)
- `unicode charset draws no icon for names without a text symbol` (icon catalog)
- `unicode icons never draw colour emoji` (icon catalog)
- `nerd font icon occupies two cells with a real space after the glyph` (nerd font cells)
- `nerd font icon blank cell is the icon title gap` (nerd font cells)
- `ascii degradation substitutes only the shared glyph families` (degradation ladder:
  charset)
- `disclosure glyphs degrade to minus and plus in ascii` (marks: `disclosure`)
- `focused bordered controls retain their title geometry` (focus: rules 1 and 6)
- `scroll indicator preset resolves one glyph pair per axis and charset` (scroll
  indicators: presets)
- `heavy preset draws a light horizontal track under unicode` (scroll indicators: `heavy`)
- `legacy computing thumbs draw only in the nerd font charset` (scroll indicators)
- `on-border placement reserves no cell and rides the edge` (scroll indicators: placement)
- `image density ramp inverts on a light scheme` (bars and ramps)
- `spinner label starts two cells in for every frame set` (spinners; nerd font cells)
- `nerd font spinner sets fall back to orbit at its own interval` (spinners)
- `ascii spinner draws line at one hundred twenty milliseconds` (spinners)

## Migration map

Old catalog names and their replacements, for docs to cite when they drop a "token pending
plan 032 step 5.3" marker or a starred legend role (`muted*`, `contrast*`, `surface*`,
`faint(accent)*`): rename the role, then delete the marker phrase or the `*`.

### Legend roles

| Old                                                                      | New                                                                                                                                                                                                                          | Notes                                                                                                                           |
| ------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| `muted`                                                                  | `secondary`                                                                                                                                                                                                                  | `border` for scroll and progress tracks, outline guides, tab-view's rule row, Markdown quote rails and Image's placeholder fill |
| `muted dim`, `muted dim italic`                                          | `secondary`, `secondary italic`                                                                                                                                                                                              | Markdown quotes: `secondary` already recedes, so the extra dim goes                                                             |
| `output`                                                                 | `secondary`                                                                                                                                                                                                                  | CodeView and Markdown code grids use `syntax.punctuation` and `syntax.plain` instead                                            |
| `semantic.primary`, `.secondary`, `.accent`, `.disabled`, `.destructive` | the bare name                                                                                                                                                                                                                | in legends and prose                                                                                                            |
| `semantic.muted`                                                         | `secondary`                                                                                                                                                                                                                  |                                                                                                                                 |
| `semantic.focus`, `focus`                                                | `focus`                                                                                                                                                                                                                      | now the bold default foreground; `fg=focus bold` stays valid, and `bg=focus` reads as `solid(focus)`                            |
| `contrast`, `contrast*`                                                  | `contrast`                                                                                                                                                                                                                   | `on(R)` inside `solid(R)`                                                                                                       |
| `faint-focus`, `focus-faint`                                             | `faint(focus)`                                                                                                                                                                                                               |                                                                                                                                 |
| `disabled-fill`, `disabled-label`                                        | `disabled.fill`, `disabled.label`                                                                                                                                                                                            |                                                                                                                                 |
| `selection`                                                              | `selection.fill`                                                                                                                                                                                                             | table and split-view legends write `bg=selection`; outline.md's "(reverse video)" gloss becomes "faint accent"                  |
| `hover` (Markdown inline code)                                           | `surface`                                                                                                                                                                                                                    | Form's and Table's row `hover` stays `hover`                                                                                    |
| `blue` (explicit)                                                        | `info`                                                                                                                                                                                                                       | label.md's override example; `.labelIconRole(.blue)` becomes `.labelIconRole(.info)`                                            |
| `active-chip`                                                            | not a role                                                                                                                                                                                                                   | TabView's word for the active tab; its Styles are `solid(focus)` and `solid(accent)`                                            |
| `role`                                                                   | unchanged                                                                                                                                                                                                                    | Leading rail's placeholder for the caller's role, not a token                                                                   |
| CodeView syntax grid `A` to `G`                                          | gutter `secondary`; `use`, `pub`, `fn`, `let` `syntax.keyword`; `header` `syntax.function`; `String` `syntax.type`; the string literal `syntax.string`; `(`, `)`, `;`, `->` `syntax.punctuation`; identifiers `syntax.plain` | recapture the grid with these roles                                                                                             |

Unchanged and now defined: `primary`, `secondary`, `accent`, `border`, `disabled`,
`destructive`, `info`, `success`, `warning`, `error`, `surface`, `selection.fill`,
`selection.inactive`, `faint(accent)`, `faint(secondary)`, `faint(destructive)`.

### Retired tokens and names

| Old                                                        | New                                                   |
| ---------------------------------------------------------- | ----------------------------------------------------- |
| `semantic.focus`, black on dark yellow; provisional violet | `focus`, the bold default foreground                  |
| `semantic.destructive` with underline                      | `destructive`, the `error` Style, no underline        |
| `semantic.accent`, bright cyan and bold                    | `accent`, `hue(6)`, no bold                           |
| `focus.border`                                             | [Focus](#focus) rules 1, 2 and 6                      |
| `focus.content`                                            | the `focus` role on the control's own content         |
| `scrollbar.weight`, `scrollbar.track`                      | [scroll indicator](#scroll-indicators) presets        |
| `scrollbar.ascii`                                          | `scrollIndicator.ascii`                               |
| `onBorder` placement                                       | `.border` placement                                   |
| `selection.ascii`                                          | the ASCII column of `selection.bar`                   |
| `disclosure.ascii`                                         | the ASCII column of `disclosure.*` in [Marks](#marks) |
| `\.iconCharset`, `IconCharset`                             | [`\.charset`](#charset)                               |
| `TESSERA_CHARSET`                                          | not adopted; the generic `NERDFONT` variable          |
| `quarters` spinner                                         | dropped                                               |
| "no success, warning or information roles in 1.0"          | the tones `info`, `success`, `warning` and `error`    |

### Anchors

| Old anchor                  | New anchor                                                                                         |
| --------------------------- | -------------------------------------------------------------------------------------------------- |
| `tokens.md#semantic-styles` | [`#roles`](#roles), or the subsection: [text](#text-roles), [hue](#hue-roles), [fill](#fill-roles) |
| `tokens.md#disclosure`      | [`#marks`](#marks)                                                                                 |
| `tokens.md#selection`       | unchanged                                                                                          |
| `tokens.md#focus`           | unchanged                                                                                          |
