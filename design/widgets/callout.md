---
kind: widget
status: wireframed
---

# Callout

`Callout` is Tessera's highlighted notice. It draws an optional header (kind icon, bold
title, badge) over a body in a leading rail that takes the kind's colour. Without a kind
it draws the rail in `info` and the body in `primary`. The body is `@ViewBuilder` content.
The header is a [Label](../primitives/label.md) followed by a
[Badge](../primitives/badge.md) in the kind's tone.

Callout is read-only: it has no focus, keys or pointer behaviour.

The rail is the [leading rail](../primitives/leading-rail.md) primitive in the kind's
role. Owner decision, omp2 review, 2026-10: the rail sits centred under the header icon,
not on the left edge as a `▎`. Owner decision, 2026-10-10: the heavy `┃` rail ships in
1.0. ASCII keeps `|` at column 0.

## Prior art

- omp2 Callout,
  [callout.rs](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/callout.rs#L15-L20),
  defines the four kinds, their default icons and colours
  ([#L22-L50](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/callout.rs#L22-L50)).
  It paints the header and railed body at
  [#L153-L166](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/callout.rs#L153-L166)
  and
  [#L292-L330](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/callout.rs#L292-L330).
  Copy the kind set, the kind name as default title, the header/body split, and the
  kind-coloured rail. Reject the left-edge `▎` rail, the `<callout>` markup tag, and
  Markdown rendering inside the widget: the body is a View.
- SwiftUI has no callout. The header reuses `Label`, which follows SwiftUI's `Label`
  pairing of title and icon (see [Label](../primitives/label.md)).

## API direction

```swift
public enum CalloutKind: Sendable {
    case info, success, warning, error
}

public struct Callout<Body: View>: View {
    public init(
        _ title: String? = nil,
        kind: CalloutKind? = nil,
        badge: String? = nil,
        @ViewBuilder content: () -> Body
    )
}
```

```swift
Callout("Build warning", kind: .warning, badge: "1 note") {
    Text("The cache is stale, so the next build will be slower than usual.")
}
```

- With `kind`, the title defaults to the kind's name (`Info`, `Success`, `Warning`,
  `Error`) and the header icon is the kind's catalog name, resolved by `Label`.
- With `kind`, the badge is a `Badge` in the kind's tone (owner decision, 2026-10-10).
  Without `kind`, the badge is a `Badge` in the `neutral` tone.
- Without `kind`, there is no icon, the title shows only when given, and the rail is
  `info`.
- The heavy rail is selected through the `.leadingRail(style:role:)` primitive's heavy
  style; it ships in 1.0 (owner decision, 2026-10-10). See
  [Leading rail](../primitives/leading-rail.md).
- The body is `@ViewBuilder` only (owner decision, 2026-10-10). Markdown content is
  composed as `Callout { Markdown(src) }`; the body takes no Markdown source string. See
  [Markdown](markdown.md).

## Anatomy

Header with a body, 40 columns:

```wireframe 40x4
⚠ Build warning ▐1 note▌
│ The cache is stale, so the next build
│ will be slower than usual. Run just
│ warm to rebuild it ahead of time.
```

```text
Callouts (40x4, 0-based):
1. r0 c0       Icon -- Label icon `warning`, warning role
2. r0 c2-14    Title -- Label title, warning bold; never wraps
3. r0 c16-23   Badge -- `Badge` in the `warning` tone, one column after the title
4. r1-r3 c0    Rail -- leading rail, light vertical centred under the icon, warning role
5. r1-r3 c2-39 Body -- Text wrapping to width minus 2, warning role
```

```text
── chars ──
⚠ Build warning ▐1 note▌
│ The cache is stale, so the next build
│ will be slower than usual. Run just
│ warm to rebuild it ahead of time.
── style ──
ABCCCCCCCCCCCCCBEFFFFFFE
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
── legend ──
.  default
A  fg=warning
B  fg=primary
C  fg=warning bold
E  fg=warning (badge caps, in the fill colour)
F  fg=contrast bg=warning bold (badge label)
```

## States

### Mobile (40 columns): kinds

Mobile is 40 columns wide. The four kinds share one body treatment: the icon, title and
rail take the kind's role.

```wireframe 40x11
ℹ Info
│ Tessera renders into a borrowed
│ region.
✔ Success
│ All 312 tests passed.
⚠ Warning
│ The terminal did not answer the
│ capability probe.
✘ Error
│ The session lost its controlling
│ terminal.
```

```text
Callouts (40x11, 0-based):
1. r0, r3, r5, r8 c0     Icon -- Label icon for the kind, kind role
2. r0, r3, r5, r8 c2     Title -- kind name by default, bold kind role
3. r1-r2, r4, r6-r7, r9-r10 c0   Rail -- light vertical centred under the icon, kind role
4. body rows c2-39       Body -- Text wrapping to width minus 2, kind role
```

```text
── chars ──
ℹ Info
│ Tessera renders into a borrowed
│ region.
✔ Success
│ All 312 tests passed.
⚠ Warning
│ The terminal did not answer the
│ capability probe.
✘ Error
│ The session lost its controlling
│ terminal.
── style ──
ABCCCC
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAA
DBEEEEEEE
DDDDDDDDDDDDDDDDDDDDDDD
FBGGGGGGG
FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
FFFFFFFFFFFFFFFFFFF
HBIIIII
HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH
HHHHHHHHHHH
── legend ──
.  default
A  fg=info
B  fg=primary
C  fg=info bold
D  fg=success
E  fg=success bold
F  fg=warning
G  fg=warning bold
H  fg=error
I  fg=error bold
```

### Heavy rail (40 columns)

The heavy rail ships in 1.0 (owner decision, 2026-10-10). It changes only the rail glyph.
Its colours and layout are the same as the light rail.

```wireframe 40x11
ℹ Info
┃ Tessera renders into a borrowed
┃ region.
✔ Success
┃ All 312 tests passed.
⚠ Warning
┃ The terminal did not answer the
┃ capability probe.
✘ Error
┃ The session lost its controlling
┃ terminal.
```

```text
Callouts (40x11, 0-based):
1. r0, r3, r5, r8 c0     Icon -- Label icon for the kind, kind role
2. r0, r3, r5, r8 c2     Title -- kind name by default, bold kind role
3. rail rows c0          Rail -- heavy vertical `┃` centred under the icon, kind role
4. body rows c2-39       Body -- Text wrapping to width minus 2, kind role
```

```text
── chars ──
ℹ Info
┃ Tessera renders into a borrowed
┃ region.
✔ Success
┃ All 312 tests passed.
⚠ Warning
┃ The terminal did not answer the
┃ capability probe.
✘ Error
┃ The session lost its controlling
┃ terminal.
── style ──
ABCCCC
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAA
DBEEEEEEE
DDDDDDDDDDDDDDDDDDDDDDD
FBGGGGGGG
FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
FFFFFFFFFFFFFFFFFFF
HBIIIII
HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH
HHHHHHHHHHH
── legend ──
.  default
A  fg=info
B  fg=primary
C  fg=info bold
D  fg=success
E  fg=success bold
F  fg=warning
G  fg=warning bold
H  fg=error
I  fg=error bold
```

### ASCII (40 columns)

The ASCII charset replaces each kind icon with a bracketed glyph (`(i)` for info, the
bracketed words for the others) and the rail with `|`. The rail stays at column 0:
bracketed icons cannot be centred under it (owner decision, 2026-10-10).

```wireframe 40x11
(i) Info
| Tessera renders into a borrowed
| region.
[ok] Success
| All 312 tests passed.
[!] Warning
| The terminal did not answer the
| capability probe.
[!!] Error
| The session lost its controlling
| terminal.
```

```text
── chars ──
(i) Info
| Tessera renders into a borrowed
| region.
[ok] Success
| All 312 tests passed.
[!] Warning
| The terminal did not answer the
| capability probe.
[!!] Error
| The session lost its controlling
| terminal.
── style ──
AAABCCCC
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAA
DDDDBEEEEEEE
DDDDDDDDDDDDDDDDDDDDDDD
FFFBGGGGGGG
FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
FFFFFFFFFFFFFFFFFFF
HHHHBIIIII
HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH
HHHHHHHHHHH
── legend ──
.  default
A  fg=info
B  fg=primary
C  fg=info bold
D  fg=success
E  fg=success bold
F  fg=warning
G  fg=warning bold
H  fg=error
I  fg=error bold
```

### Plain (no kind, 40 columns)

With no kind, title, badge or icon, the callout draws only the rail and the body.

```wireframe 40x4
│ A callout with no kind, title, badge,
│ or icon draws only the rail and the
│ body text, which wraps to the
│ available width.
```

```text
Callouts (40x4, 0-based):
1. r0-r3 c0     Rail -- light vertical, info role, space after it also info
2. r0-r3 c2-39  Body -- Text, primary, wraps to width minus 2
```

```text
── chars ──
│ A callout with no kind, title, badge,
│ or icon draws only the rail and the
│ body text, which wraps to the
│ available width.
── style ──
AABBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB
AABBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB
AABBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB
AABBBBBBBBBBBBBBBB
── legend ──
.  default
A  fg=info
B  fg=primary
```

### Minimum (14 columns)

At 14 columns the badge is dropped and the title tail-truncates to the row edge with the
truncation mark (`…`, [tokens.md](../tokens.md#truncation)). The title never wraps the
header (owner decision, 2026-10-10). The body wraps at 12 columns.

```wireframe 14x12
⚠ Build warni…
│ The cache is
│ stale, so
│ the next
│ build will
│ be slower
│ than usual.
│ Run just
│ warm to
│ rebuild it
│ ahead of
│ time.
```

```text
Callouts (14x12, 0-based):
1. r0 c0      Icon -- Label icon `warning`, warning role
2. r0 c2-13   Title -- tail-truncated with `truncation.mark` at the row edge, warning bold
3. r0 c14     Badge -- dropped at this width
4. r1-r11 c0  Rail -- leading rail, light vertical under the icon, warning role
5. r1-r11 c2  Body -- Text wrapping at 12 columns, warning role
```

```text
── chars ──
⚠ Build warni…
│ The cache is
│ stale, so
│ the next
│ build will
│ be slower
│ than usual.
│ Run just
│ warm to
│ rebuild it
│ ahead of
│ time.
── style ──
ABCCCCCCCCCCCC
AAAAAAAAAAAAAA
AAAAAAAAAAA
AAAAAAAAAA
AAAAAAAAAAAA
AAAAAAAAAAA
AAAAAAAAAAAAA
AAAAAAAAAA
AAAAAAAAA
AAAAAAAAAAAA
AAAAAAAAAA
AAAAAAA
── legend ──
.  default
A  fg=warning
B  fg=primary
C  fg=warning bold
```

Below 14 columns the same rules continue: the badge stays dropped, the title keeps
tail-truncating, and the body wraps at width minus two. The floor is 4 columns: rail,
space, two cells (see [Sizing](#sizing)).

## Variants

| Kind      | Icon (Unicode / ASCII) | Default title | Role                        | Token                           |
| --------- | ---------------------- | ------------- | --------------------------- | ------------------------------- |
| `info`    | ℹ / `(i)`              | Info          | `info`                      | token pending plan 032 step 5.3 |
| `success` | ✔ / `[ok]`             | Success       | `success`                   | token pending plan 032 step 5.3 |
| `warning` | ⚠ / `[!]`              | Warning       | `warning`                   | token pending plan 032 step 5.3 |
| `error`   | ✘ / `[!!]`             | Error         | `error`                     | token pending plan 032 step 5.3 |
| none      | none                   | none          | rail `info`, body `primary` | `semantic.primary`              |

Kind icons are catalog names resolved by [Label](../primitives/label.md). The Unicode and
ASCII glyphs match that catalog's columns. The info ASCII glyph is `(i)`, not `[i]` (owner
decision, 2026-10-10).

## State model

Not focusable: no state model.

## Key table

Not focusable: no key table.

## Mouse table

Not focusable: no mouse table.

## Sizing

Schema: [README](../README.md#sizing-table). Mandatory rows: nil x nil, tight,
under-minimum, over-maximum.

| Proposal     | Result                                                                                    | Rule                                                              |
| ------------ | ----------------------------------------------------------------------------------------- | ----------------------------------------------------------------- |
| nil x nil    | Header row when a kind, title or badge is set, then body rows wrapped at width minus 2    | Height is header rows plus wrapped body rows                      |
| 14 x any     | Minimum state: title tail-truncated with `…`, badge dropped, body wraps at 12             | Floor for the 1.0 layout; see Minimum                             |
| 4 to 13      | Badge dropped; title tail-truncated with `…` to the row edge; body wraps at width minus 2 | Owner decision, 2026-10-10: the header never wraps                |
| under 4      | Not a supported floor: the parent clips the rendered rows                                 | Floor is 4 (rail, space, two cells); no layout is specified below |
| over-maximum | Body wraps at the proposed width; no maximum                                              | Body takes the proposed width                                     |

## Environment

- Kind roles `info`, `success`, `warning`, `error`: token pending plan 032 step 5.3.
  [tokens.md](../tokens.md#semantic-styles) defines no such roles.
- Header badge: a [Badge](../primitives/badge.md) in the kind's tone; its tone roles are
  token pending plan 032 step 5.3. The no-kind badge is `neutral`.
- No-kind body `semantic.primary` and no-kind rail `info` (pending as above).
- Rail glyphs and centring: see [Leading rail](../primitives/leading-rail.md) and
  [Divider glyphs](../tokens.md#divider-glyphs).
- Truncation: `truncation.mark` from [tokens.md](../tokens.md#truncation).

## Primitive dependencies

- [Label](../primitives/label.md): header icon and title (anatomy and minimum states).
  Status `wireframed`.
- [Badge](../primitives/badge.md): header badge in the kind's tone. Status `wireframed`.
- [Markdown](markdown.md): Markdown body content, composed as `Callout { Markdown(src) }`.
  Status `wireframed`.
- [Text](../primitives/text.md): body wrapping and title clipping. Status `ready`.
- [Leading rail](../primitives/leading-rail.md): the rail glyph, role and centring. Status
  `sketch`. Callout cannot reach `ready` until it does.

## Requirements

- `callout with a kind draws the kind icon and rail in the kind role` (States: Mobile,
  kinds)
- `callout title defaults to the kind name when a kind is set` (States: Mobile, kinds)
- `callout rail is a light vertical centred under the header icon` (Anatomy, Mobile)
- `callout heavy rail uses the heavy vertical in the same position` (States: Heavy rail)
- `callout body takes the kind role, including the space after the rail` (States: Mobile,
  kinds)
- `callout header badge draws as a badge in the kind's tone` (Anatomy)
- `callout without a kind draws the rail in info and the body in primary` (States: Plain)
- `callout ASCII charset uses bracketed kind icons, (i) for info, and a pipe rail at column 0`
  (States: ASCII)
- `callout at 14 columns drops the badge and tail-truncates the title with the truncation mark`
  (States: Minimum)
- `callout title never wraps the header` (Anatomy, Minimum)
- `callout body wraps at width minus two columns` (States: Minimum, Mobile)
- `callout below 14 columns keeps the body at width minus two down to a floor of 4`
  (Sizing)
- `callout body accepts @ViewBuilder content only, so Markdown composes as a view` (API
  direction)

## Degradation

- `NO_COLOR`: kind colour is lost. The icon and title text still identify the kind, and
  bold stays per the [degradation ladder](../tokens.md#degradation-ladder).
- 16-colour: roles follow their token rows once pending plan 032 step 5.3 defines them.
- ASCII-only: the ASCII states above. The rail is `|` at column 0, kind icons are
  bracketed (`(i)` for info), and the title truncation mark is `~`.
- Below 14 columns: the badge drops and the title tail-truncates; the body wraps at width
  minus two down to a floor of 4 columns (see Sizing).

## Open questions

- Kind roles `info`, `success`, `warning`, `error`: no token rows exist yet. Unblocks:
  plan 032 step 5.3.

## Inspiration

- None yet.
