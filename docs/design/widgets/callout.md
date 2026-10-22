---
kind: widget
status: ready
---

# Callout

`Callout` is Tessera's highlighted notice. It draws an optional header (kind icon, bold
title, badge) over a body in a leading rail that takes the kind's colour. Without a kind
it draws the rail in `info` and the body in `primary`. The body is `@ViewBuilder` content.
The header is a [Label](../primitives/label.md) followed by a
[Badge](../primitives/badge.md) in the kind's tone.

Callout is read-only: it has no focus, keys or pointer behaviour.

The rail is the [leading rail](../primitives/leading-rail.md) primitive in the kind's
role. Owner decision, omp2 review, 2026-10: the rail is a light vertical in the header
icon's place, not the left-edge `▎`. Owner decision, 2026-10-18: the rail is always column
0: centred under a one-cell icon, under the left edge of a two-cell icon, and column 0 in
ASCII. Owner decision, 2026-10-10: the heavy `┃` rail ships in 1.0.

## Prior art

- omp2 `Callout`
  ([callout.rs#L52-L53](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/callout.rs#L52-L53))
  defines the four kinds at
  [#L15-L20](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/callout.rs#L15-L20)
  and their default icons and colours at
  [#L22-L50](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/callout.rs#L22-L50).
  It renders its text as Markdown at
  [#L153-L166](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/callout.rs#L153-L166)
  and paints the header and railed body at
  [#L292-L330](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/callout.rs#L292-L330).
  Copy the kind set, the kind name as default title, the header/body split, and the
  kind-coloured rail. Reject the left-edge `▎` rail, the `<callout>` markup tag, and
  Markdown rendering inside the widget: the body is a View (keys I6, M4).
- Key translations: `kind` is a meaning, so it is the `CalloutKind` parameter (key B12);
  omp2's tones `info`, `ok`, `warn` and `err` are the hue roles `info`, `success`,
  `warning` and `error` (key J5); the header icon is a catalog name drawn by `Label` (key
  K2); the rail is the leading rail (key K7); and omp2's `set_text` updates have no
  counterpart, because the app redeclares the callout on every update (key A8). omp2 draws
  its `badge` attribute as muted text
  ([#L306-L309](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/callout.rs#L306-L309));
  Tessera draws a `Badge` (see API direction).
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
- The badge is an initializer parameter, not the `.badge(_:tone:)` modifier that key B11
  names for omp2's `badge` attribute. The owner chose `.badge(_:)` for list rows and tab
  items, plus a standalone `Badge` view (owner decision, omp2 review, 2026-10, in
  [Badge](../primitives/badge.md#api-direction)). The header badge is neither, and it
  takes its tone from `kind`, so Callout draws a standalone `Badge`. Key B11 needs this
  exception.
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
1. r0 c0       Icon -- Label icon `warning`, warning role; chrome, one row
2. r0 c2-14    Title -- Label title, warning bold; chrome, one row (header exception)
3. r0 c16-23   Badge -- `Badge` in the `warning` tone, one column after the title; chrome, one row
4. r1-r3 c0    Rail -- leading rail, light vertical in column 0 (under the one-cell icon), warning role
5. r1-r3 c2-39 Body -- Text wrapping to width minus 2, warning role; content, wraps
```

> Wrap exception (rule 1): the header stays on one row and tail-truncates. A wrapped
> header would break the rail/row geometry under it. (owner decision, 2026-10-18) The body
> is content and wraps.

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
E  fg=warning -- badge caps, in the fill colour
F  fg=contrast bg=warning bold -- badge label
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
3. r1-r2, r4, r6-r7, r9-r10 c0   Rail -- light vertical in column 0, kind role
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
3. rail rows c0          Rail -- heavy vertical `┃` in column 0, kind role
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
bracketed words for the others) and the rail with `|`. The rail stays at column 0, as in
every charset: bracketed icons cannot be centred over it (owner decisions, 2026-10-10 and
2026-10-18).

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

### Minimum (9 columns)

The floor is 9 columns (owner decision, 2026-10-18; it replaces the 14-column minimum
state and the 4-column floor of 2026-10-10). It is derived under the wrap rules: the body
is the primary content, its widest word in the fixture, `rebuild`, is 7 cells, and the
rail and gap add 2, so every body word shows whole at 9. The header never wraps (the
exception above): the badge drops first, then the title tail-truncates with the truncation
mark (`…`, [tokens.md](../tokens.md#truncation)), so the header does not set the floor. At
9 columns the body wraps at 7 and takes 19 rows, so the floor is 9x20.

```wireframe 9x20
⚠ Build …
│ The
│ cache
│ is
│ stale,
│ so the
│ next
│ build
│ will be
│ slower
│ than
│ usual.
│ Run
│ just
│ warm to
│ rebuild
│ it
│ ahead
│ of
│ time.
```

```text
Callouts (9x20, 0-based):
1. r0 c0      Icon -- Label icon `warning`, warning role; chrome, one row
2. r0 c2-8    Title -- tail-truncated with `truncation.mark` at the row edge, warning bold; chrome, one row
3. r0 c9      Badge -- dropped at this width
4. r1-r19 c0  Rail -- leading rail, light vertical in column 0, warning role
5. r1-r19 c2-8  Body -- Text wrapping at 7 columns, warning role; content, wraps
```

```text
── chars ──
⚠ Build …
│ The
│ cache
│ is
│ stale,
│ so the
│ next
│ build
│ will be
│ slower
│ than
│ usual.
│ Run
│ just
│ warm to
│ rebuild
│ it
│ ahead
│ of
│ time.
── style ──
ABCCCCCCC
AAAAA
AAAAAAA
AAAA
AAAAAAAA
AAAAAAAA
AAAAAA
AAAAAAA
AAAAAAAAA
AAAAAAAA
AAAAAA
AAAAAAAA
AAAAA
AAAAAA
AAAAAAAAA
AAAAAAAAA
AAAA
AAAAAAA
AAAA
AAAAAAA
── legend ──
.  default
A  fg=warning
B  fg=primary
C  fg=warning bold
```

Below 9 columns nothing clips silently: the badge stays dropped, the title keeps
tail-truncating, and body words wider than width minus two break between grapheme
clusters. Under a fixed height the last visible body row ends in `…`.

## Variants

| Kind      | Icon (Unicode / ASCII) | Default title | Role                        | Token                               |
| --------- | ---------------------- | ------------- | --------------------------- | ----------------------------------- |
| `info`    | ℹ / `(i)`              | Info          | `info`                      | [hue roles](../tokens.md#hue-roles) |
| `success` | ✔ / `[ok]`             | Success       | `success`                   | [hue roles](../tokens.md#hue-roles) |
| `warning` | ⚠ / `[!]`              | Warning       | `warning`                   | [hue roles](../tokens.md#hue-roles) |
| `error`   | ✘ / `[!!]`             | Error         | `error`                     | [hue roles](../tokens.md#hue-roles) |
| none      | none                   | none          | rail `info`, body `primary` | `primary`                           |

Kind icons are catalog names resolved by [Label](../primitives/label.md). The Unicode and
ASCII glyphs match that catalog's columns. The info ASCII glyph is `(i)`, not `[i]` (owner
decision, 2026-10-10).

## State model

Schema: [README](../../design.md#state-model-table). Every row is app-owned display data,
a plain initializer parameter redeclared on every update (key D2). Callout stores no
state: it has no `NodeState` row and no responder.

| State   | Owner   | Type                | Reset or clamp rule                                                                                |
| ------- | ------- | ------------------- | -------------------------------------------------------------------------------------------------- |
| title   | Binding | `String?`           | app-owned display data, redeclared on every update (key D2); nil with a kind shows the kind's name |
| kind    | Binding | `CalloutKind?`      | app-owned (key D2); nil draws no icon, an `info` rail and a `primary` body                         |
| badge   | Binding | `String?`           | app-owned (key D2); nil draws no badge                                                             |
| content | Binding | `@ViewBuilder` body | app content, redeclared on every update; wraps at width minus 2                                    |

## Key table

Not focusable: no key table.

## Mouse table

Not focusable: no mouse table.

## Sizing

Schema: [README](../../design.md#sizing-table). Mandatory rows: nil x nil, tight,
under-minimum, over-maximum.

| Proposal                 | Result                  | Rule                                                                                                                             |
| ------------------------ | ----------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| nil x nil                | 109x2 (Anatomy fixture) | A nil width does not wrap: the body is unwrapped, so width is 2 plus the body's 107 cells; height is header plus body rows       |
| 109 x 2 (tight)          | 109x2                   | The proposal equals the ideal: the body's one source line fits one row beside the rail                                           |
| 40 x nil                 | 40x4                    | Body wraps at width minus 2 and gets every row (Anatomy)                                                                         |
| 40 x 3 (fixed height)    | 40x3                    | Header plus two body rows; the last visible body row is the rest of its source line and ends in `…` (owner decision, 2026-10-18) |
| 9 x nil (minimum)        | 9x20                    | Floor re-derived in Minimum: body words whole at width minus 2; badge dropped, title truncated (owner decision, 2026-10-18)      |
| 8 x 2 (under-minimum)    | 8x2                     | Badge dropped; the title tail-truncates to `Build…`; the one body row is its source line cut to five cells plus `…` (`The c…`)   |
| 120 x nil (over-maximum) | 120x2                   | The body takes the proposed width, so its one source line fits one row; Callout has no maximum                                   |

From 3 to 8 columns the badge drops, the title tail-truncates, and body words wider than
width minus 2 break between grapheme clusters. Below 3 columns the rail and its gap leave
no body cell; see Open questions.

## Environment

- Kind roles `info`, `success`, `warning`, `error`: the
  [hue roles](../tokens.md#hue-roles), defined in 1.0 (owner decision, 2026-10-19).
- Header badge: a [Badge](../primitives/badge.md) in the kind's tone, drawn as `solid(R)`
  of the kind's role ([composite styles](../tokens.md#composite-styles)); its tone roles
  are the hue roles above. The no-kind badge is `neutral`.
- No-kind body `primary` and no-kind rail `info`.
- Rail glyphs and centring: see [Leading rail](../primitives/leading-rail.md) and
  [Divider glyphs](../tokens.md#divider-glyphs).
- Truncation: `truncation.mark` from [tokens.md](../tokens.md#truncation).

## Primitive dependencies

- [Label](../primitives/label.md): header icon and title (anatomy and minimum states).
- [Badge](../primitives/badge.md): header badge in the kind's tone.
- [Text](../primitives/text.md): body wrapping and header truncation.
- [Leading rail](../primitives/leading-rail.md): the rail glyph, role and column.
- [Markdown](markdown.md) is not a dependency: an app composes `Callout { Markdown(src) }`
  (keys I6, M4).

## Requirements

- `callout with a kind draws the kind icon and rail in the kind role` (States: Mobile,
  kinds)
- `callout title defaults to the kind name when a kind is set` (States: Mobile, kinds)
- `callout rail is a light vertical in column 0, centred under a one-cell header icon`
  (Anatomy, Mobile; owner decision, 2026-10-18)
- `callout heavy rail uses the heavy vertical in the same position` (States: Heavy rail)
- `callout body takes the kind role, including the space after the rail` (States: Mobile,
  kinds)
- `callout header badge draws as a badge in the kind's tone` (Anatomy)
- `callout without a kind draws the rail in info and the body in primary` (States: Plain)
- `callout ASCII charset uses bracketed kind icons, (i) for info, and a pipe rail at column 0`
  (States: ASCII)
- `callout at 9 columns drops the badge, tail-truncates the title with the truncation mark and wraps the body at 7`
  (States: Minimum; owner decision, 2026-10-18)
- `callout header stays on one row and tail-truncates` (Anatomy wrap exception; Minimum;
  owner decision, 2026-10-18)
- `callout body wraps at width minus two columns` (States: Minimum, Mobile)
- `callout body breaks words wider than width minus two between grapheme clusters below the 9-column floor`
  (Sizing; Minimum; owner decision, 2026-10-18)
- `callout body ends its last visible row in an ellipsis under a fixed height` (Sizing 40
  x 3; owner decision, 2026-10-18)
- `callout body accepts @ViewBuilder content only, so Markdown composes as a view` (API
  direction)
- `callout under its floor drops the badge and cuts the one body row with the truncation mark`
  (Sizing 8 x 2)
- `callout body takes a proposal wider than its ideal width` (Sizing 120 x nil)

## Degradation

- `NO_COLOR`: kind colour is lost. The icon and title text still identify the kind, and
  bold stays per the [degradation ladder](../tokens.md#degradation-ladder).
- 16-colour: each role takes its `slots` column ([roles](../tokens.md#roles)): the tones
  take ansi 12, 10, 11 and 9 on a dark scheme, and ansi 4, 2, 3 and 1 on a light one
  ([degradation ladder](../tokens.md#degradation-ladder)).
- ASCII-only: the ASCII states above. The rail is `|` at column 0, kind icons are
  bracketed (`(i)` for info), and the title truncation mark is `~`.
- Below 9 columns: the badge drops, the title tail-truncates, and body words break between
  grapheme clusters at width minus two (see Sizing).

This design was reviewed against the
[Phase 4 theses](../../spec.md#phase-4--view-layer-the-tessera-module): Callout is a
composite of Label, Badge, the leading rail and app content, not a painter (key A1); its
title, kind, badge and body are app-owned values redeclared on every update; it stores no
state and takes no input; colour comes from the hue roles; and its layout is deterministic
integer-cell output.

## Open questions

- **Below 3 columns (deferred to plan 032 step 16.2).** The rail and its gap leave no body
  cell, and no layout is specified. Catalog precedents differ: Badge and Button report
  their floor and let the parent clip, while Text at zero width reports zero width and
  paints nothing.
- **Heavy rail selection (deferred to plan 032 step 16.2).** The heavy rail ships in 1.0,
  and Callout passes its kind role to `.leadingRail(style:role:)`, but neither Callout's
  initializer nor an environment value lets an app choose the heavy style for a callout.
  Step 16.2 settles the spelling.

## Inspiration

- None yet.
