---
kind: primitive
status: ready
---

# Badge

`Badge` is a short label, a count or a word, in a filled squared shape coloured by its
tone. It is a primitive: it draws its label and its caps and takes no focus, keys, or
pointer input. Its shapes are the two capped ends of
[Button's](../widgets/button.md#shape), chosen with `.badgeShape(_:)`: `.squared` by
default, and `.capsule` for round caps. Both draw the [caps](../tokens.md#caps) tokens
with the charset fallback. Apps use it standalone, through `.badge(_:)` on list rows and
tab items, and inside a Callout header.

## Prior art

omp2 has no badge component; key B11 maps its `badge` attribute to `.badge(_:tone:)`. Its
nearest counterparts are:

- Button's pill,
  [`paint_pill`](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/button.rs#L111-L133).
  It fills a rectangle and paints charset-selected end caps in the fill colour. Copy the
  cap logic: Badge draws the same [caps](../tokens.md#caps) tokens as Button's shapes, and
  omp2's `pill_caps`
  ([context.rs#L227-L234](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/context.rs#L227-L234))
  become `caps.squared`, with Powerline caps only under `.nerdFont` (key K10).
- The Callout header,
  [header row](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/callout.rs#L297-L311).
  It puts a badge after the bold title in muted text. Copy the slot after the title.
  Reject the muted-only colour: owner decision, omp2 review, 2026-10, makes the Callout
  badge a warning-toned badge.
- DiffStat's counts,
  [diffstat.rs#L144-L161](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/diffstat.rs#L144-L161).
  It colours each count by meaning and skips a count that does not fit rather than cutting
  it. Copy both: the tones are a `BadgeTone` meaning parameter (key B12) whose names
  follow the hue roles, omp2's `ok`, `err`, and `muted` becoming `success`, `error`, and
  `neutral`'s `secondary` (key J5), and a count is atomic. Reject the unfilled text: a
  badge is `solid(R)`.
- SwiftUI
  [`badge(_:)`](<https://developer.apple.com/documentation/swiftui/view/badge(_:)>) places
  a count or label at the trailing edge of list rows and tab items. Copy the modifier
  name, its count and text forms, and the trailing placement. Reject the platform-drawn
  badge and its lack of tone; Badge takes a tone.

## Anatomy

Six tones in the Unicode charset. Each badge is a label between two half-block caps, and
the caps take the fill colour. This is the default `.squared` shape.

```wireframe 40x6
neutral  ▐3▌  ▐new▌
accent   ▐3▌  ▐new▌
info     ▐3▌  ▐new▌
success  ▐3▌  ▐new▌
warning  ▐3▌  ▐new▌
error    ▐3▌  ▐new▌
```

```text
Callouts (40x6, 0-based):
1. r0-r5 c0-c8   Tone name -- plain row text in `secondary` bold; not part of the badge
2. r0-r5 c9-c11  Count badge -- half blocks `▐` and `▌` in the tone's fill colour; label
                 `3` in `contrast` bold on the fill; chrome, one row, atomic
3. r0-r5 c14-c18 Word badge -- the same squared shape with a word label; chrome, one row
4. r0-r5 c12-c13 Gap -- two cells between badges, outside every shape
```

Both badge kinds are chrome, one row (rule 3): a badge never wraps and is never taller
than one row. A word label keeps tail truncation with the `truncation.mark` at a narrow
width (see Sizing). A count is an atomic value: it never wraps or truncates, and the
neighbouring row content gives way first (owner decision, 2026-10-18). Badge applies
`.lineLimit(1)` directly on its label Text, so an app's inherited `lineLimit` never
reaches it.

> Wrap exception (rules 1 and 2): the count is atomic: it never wraps or truncates, and
> the neighbouring row content gives way first. If the parent still assigns fewer cells
> than the count's natural width, the parent clips the badge with no mark (owner decision,
> 2026-10-18). Cutting digits or marking them with `…` would show a number that is not the
> count.

```text
── chars ──
neutral  ▐3▌  ▐new▌
accent   ▐3▌  ▐new▌
info     ▐3▌  ▐new▌
success  ▐3▌  ▐new▌
warning  ▐3▌  ▐new▌
error    ▐3▌  ▐new▌
── style ──
HHHHHHHHHaba..abbba
HHHHHHHHHcdc..cdddc
HHHHHHHHHefe..efffe
HHHHHHHHHghg..ghhhg
HHHHHHHHHiji..ijjji
HHHHHHHHHklk..klllk
── legend ──
.  default
H  fg=secondary bold
a  fg=secondary
b  fg=contrast bg=secondary bold
c  fg=accent
d  fg=contrast bg=accent bold
e  fg=info
f  fg=contrast bg=info bold
g  fg=success
h  fg=contrast bg=success bold
i  fg=warning
j  fg=contrast bg=warning bold
k  fg=error
l  fg=contrast bg=error bold
```

### Tones

| Tone      | Caps and fill role | Label           | Token              |
| --------- | ------------------ | --------------- | ------------------ |
| `neutral` | `secondary`        | `contrast` bold | `solid(secondary)` |
| `accent`  | `accent`           | `contrast` bold | `solid(accent)`    |
| `info`    | `info`             | `contrast` bold | `solid(info)`      |
| `success` | `success`          | `contrast` bold | `solid(success)`   |
| `warning` | `warning`          | `contrast` bold | `solid(warning)`   |
| `error`   | `error`            | `contrast` bold | `solid(error)`     |

`neutral` is the default tone, and counts use it (owner decision, omp2 review, 2026-10;
confirmed 2026-10-10 for every count in context).

## Variants

Glyphs follow [Button's shape](../widgets/button.md#shape) and the
[caps](../tokens.md#caps) tokens. The default badge is `.squared`: half blocks in Nerd
Font and Unicode. `.capsule` gets round caps with a Nerd Font, and half blocks without
one. ASCII drops the caps (owner decision, 2026-10-10). The caps row's ASCII column names
Button's `.rectangle` fallback; Badge has no rectangle shape and draws brackets instead
([ASCII](#ascii)).

### Nerd Font

With a Nerd Font, a `.capsule` badge ends in Powerline round caps, U+E0B6 and U+E0B4,
coloured like the fill. The default `.squared` badge keeps its half blocks.

```wireframe 40x6
neutral  3  new
accent   3  new
info     3  new
success  3  new
warning  3  new
error    3  new
```

```text
Callouts (40x6, 0-based):
1. r0-r5 c9-c11  Count badge, `.capsule` -- round caps U+E0B6 and U+E0B4 in the tone's fill
                 colour replace the half blocks; label `contrast` bold on the fill
2. r0-r5 c14-c18 Word badge, `.capsule` -- same caps and fill
```

```text
── chars ──
neutral  3  new
accent   3  new
info     3  new
success  3  new
warning  3  new
error    3  new
── style ──
HHHHHHHHHaba..abbba
HHHHHHHHHcdc..cdddc
HHHHHHHHHefe..efffe
HHHHHHHHHghg..ghhhg
HHHHHHHHHiji..ijjji
HHHHHHHHHklk..klllk
── legend ──
.  default
H  fg=secondary bold
a  fg=secondary
b  fg=contrast bg=secondary bold
c  fg=accent
d  fg=contrast bg=accent bold
e  fg=info
f  fg=contrast bg=info bold
g  fg=success
h  fg=contrast bg=success bold
i  fg=warning
j  fg=contrast bg=warning bold
k  fg=error
l  fg=contrast bg=error bold
```

### ASCII

ASCII has no caps that read well as a fill, so a badge becomes its label in brackets,
drawn in the tone colour. It has no fill.

```wireframe 40x6
neutral  [3]  [new]
accent   [3]  [new]
info     [3]  [new]
success  [3]  [new]
warning  [3]  [new]
error    [3]  [new]
```

```text
Callouts (40x6, 0-based):
1. r0-r5 c9-c11  Count badge -- brackets `[` and `]` in the tone colour; no fill
2. r0-r5 c14-c18 Word badge -- same brackets and colour
```

```text
── chars ──
neutral  [3]  [new]
accent   [3]  [new]
info     [3]  [new]
success  [3]  [new]
warning  [3]  [new]
error    [3]  [new]
── style ──
HHHHHHHHHaaa..aaaaa
HHHHHHHHHccc..ccccc
HHHHHHHHHeee..eeeee
HHHHHHHHHggg..ggggg
HHHHHHHHHiii..iiiii
HHHHHHHHHkkk..kkkkk
── legend ──
.  default
H  fg=secondary bold
a  fg=secondary
c  fg=accent
e  fg=info
g  fg=success
i  fg=warning
k  fg=error
```

## In context

Two list rows and a Callout header, as apps use them. Both counts use the neutral default
(owner decision, 2026-10-10).

```wireframe 40x5
Inbox                               ▐12▌
Drafts                               ▐3▌

⚠ Build warning ▐1 note▌
│ The cache is stale, so the next build
```

```text
Callouts (40x5, 0-based):
1. r0 c36-c39  Count badge, neutral -- trailing row content from `.badge(_:)`; the default
               tone for a count; `secondary` fill
2. r1 c37-c39  Count badge, neutral -- the same tone at one digit
3. r3 c0       Callout icon -- warning icon in `warning`
4. r3 c2-c14   Callout title -- bold `warning`
5. r3 c16-c23  Warning badge -- `1 note` in the `warning` tone, in place of the secondary header
               text
6. r4          Callout body -- rail `│` in column 0 under the icon (owner decision, 2026-10-18) and text in `warning`
```

```text
── chars ──
Inbox                               ▐12▌
Drafts                               ▐3▌

⚠ Build warning ▐1 note▌
│ The cache is stale, so the next build
── style ──
PPPPP...............................abba
PPPPPP...............................aba

W.wwwwwwwwwwwww.ijjjjjji
WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW
── legend ──
.  default
P  fg=primary
W  fg=warning
w  fg=warning bold
a  fg=secondary
b  fg=contrast bg=secondary bold
i  fg=warning
j  fg=contrast bg=warning bold
```

## API direction

Owner decision, omp2 review, 2026-10: `.badge(_:)` on list rows and tab items, as in
SwiftUI, plus a standalone `Badge` view. The tone defaults to neutral for counts, and a
count of zero draws no badge, as SwiftUI's `badge(_:)` hides a zero count (owner decision,
2026-10-10). The tone parameter is a Tessera addition; SwiftUI's `badge(_:)` takes no
tone.

```swift
public enum BadgeTone: Sendable {
    case neutral, accent, info, success, warning, error
}

public struct Badge: View {
    public init(_ label: some StringProtocol, tone: BadgeTone = .neutral)
    public init(_ count: Int, tone: BadgeTone = .neutral)
}

extension View {
    public func badge(_ label: some StringProtocol, tone: BadgeTone = .neutral) -> some View
    public func badge(_ count: Int, tone: BadgeTone = .neutral) -> some View
}

public enum BadgeShape: Sendable {
    case squared, capsule
}

extension View {
    public func badgeShape(_ shape: BadgeShape) -> some View
}
```

```swift
// `selection` is a Binding from the app's model.
List(mailboxes, selection: selection) { mailbox in
    Text(mailbox.name)
        .badge(mailbox.unreadCount)
}

Badge("new", tone: .info)
```

A row badge trails the row content at the trailing edge, as on
[List](../widgets/list.md#row-badges). Tab items accept `.badge(_:)` the same way; tab
placement is in [TabView](../widgets/tab-view.md).

A badge's shape is a look, so it is a style modifier read from the environment (key B12),
as Button's `.buttonBorderShape(_:)` is. `.squared` is the default; `.capsule` takes
effect only with a Nerd Font ([Nerd Font](#nerd-font)).

## Sizing

Schema: [README](../../design.md#sizing-table). Mandatory rows: nil x nil, tight,
under-minimum, over-maximum. Badge mirrors Button's sizing rows (owner decision,
2026-10-10). The label is `new` (5 cells) in the rows below.

| Proposal          | Result | Rule                                                                                                                            |
| ----------------- | ------ | ------------------------------------------------------------------------------------------------------------------------------- |
| nil x nil         | 5x1    | `Badge("new")`: label width plus one cap on each side; the badge is never taller than one row.                                  |
| 5x1               | 5x1    | tight: the natural size fits exactly.                                                                                           |
| 4x1               | 4x1    | under-minimum: the label slot is two cells, so tail truncation gives `▐n…▌` and both caps stay.                                 |
| 3x1               | 3x1    | under-minimum: the label slot is one cell, so only the truncation mark remains: `▐…▌`.                                          |
| 2x1               | 3x1    | under-minimum: nothing is drawn below three cells, so the badge reports its three-cell floor and the parent clips it.           |
| 80x24             | 5x1    | over-maximum: extra space does not make a label-hugging badge grow.                                                             |
| 4x1 (`Badge(12)`) | 4x1    | count is atomic: `▐12▌` is its natural width; the count never truncates or wraps.                                               |
| 3x1 (`Badge(12)`) | 4x1    | count is atomic: the badge reports its natural 4 cells instead of cutting digits; the neighbouring row content gives way first. |

## Environment

- Tone fill and cap roles: `secondary` (neutral), `accent`, `info`, `success`, `warning`,
  `error`, each as `solid(R)` ([composite styles](../tokens.md#composite-styles)).
- Label role `contrast` bold: `on(R)` inside `solid(R)`
  ([composite styles](../tokens.md#composite-styles)).
- Caps: the [caps](../tokens.md#caps) tokens. `caps.capsule` (U+E0B6 and U+E0B4) with a
  Nerd Font when `.capsule` is chosen; `caps.squared` (`▐` and `▌`) otherwise; nothing in
  ASCII, which uses `[` and `]`. Glyphs as in [Button](../widgets/button.md#shape).
- Badge shape: the environment value `.badgeShape(_:)` writes, `.squared` by default.

## Primitive dependencies

- [Text](text.md) for the label. Status `ready`.
- [Style modifiers](style-modifiers.md) for the tone fill and label style. Status `ready`.
- Caps: Badge draws its caps itself from the [caps](../tokens.md#caps) tokens, as Button
  draws its shapes, so it needs no capsule background shape. No Spec slice defines one,
  and the tokens name the caps as the ends of Button and Badge shapes.

## Requirements

- `count badge defaults to the neutral tone` (API direction: default tone)
- `zero count draws no badge and takes no space` (API direction: zero count)
- `badge label is contrast bold on its tone fill` (anatomy: callout 2)
- `badge caps take the fill colour` (anatomy: callouts 2-3)
- `default badge ends with half blocks, squared as in Button` (anatomy; variants)
- `capsule badge ends with round caps with a Nerd Font` (variants: Nerd Font)
- `badge shape is read from the environment and defaults to squared` (API direction: badge
  shape; variants)
- `unicode badge ends with half blocks` (anatomy)
- `ascii badge draws its label in brackets in the tone colour` (variants: ASCII)
- `badge nil x nil and tight sizes are label plus two caps` (Sizing: nil x nil, tight)
- `under-minimum word badge tail-truncates the label and keeps both caps, nothing below three cells`
  (Sizing: 4x1, 3x1, 2x1; word labels only)
- `badge never grows past its natural width` (Sizing: 80x24)
- `count badge never truncates or wraps and reports its natural width` (Sizing: count
  rows; anatomy: callout 2; Wrap exception)
- `row badge trails the row content at the trailing edge` (in context: callout 1)
- `badge takes no focus and consumes no keys` (primitive: no key table)
- `neutral tone draws solid(secondary) and each hue tone draws solid(R) for its same-named role`
  (Tones table; [composite styles](../tokens.md#composite-styles))

## Degradation

- ASCII: the label is bracketed in its tone colour, with no caps and no fill (ASCII
  variant).
- Nerd Font and Unicode: caps and fill as above.
- `NO_COLOR`: the label is reverse video and the caps stay in the default foreground, as
  Button's `NO_COLOR` rule (owner decision, 2026-10-10). Tones look alike under
  `NO_COLOR`; this is the accepted cost of the mode.
- 16-colour: `solid(R)` per [composite styles](../tokens.md#composite-styles): the label
  is reverse video and the caps take the indexed tone (accent ansi 14 dark / 6 light; info
  12 / 4; success 10 / 2; warning 11 / 3; error 9 / 1). Neutral is an ANSI 8 fill on dark
  and reverse video on light (owner decision, 2026-10-19). See the
  [degradation ladder](../tokens.md#degradation-ladder).

## Open questions

- Resolved: the capsule shape. Badge draws its caps from the [caps](../tokens.md#caps)
  tokens, as Button does, so it needs no `.background(.capsule, style)`.
  [Slice 3](../../spec/phase-4/slice-03-styling-and-decoration.md) defines no such shape,
  and [the 1.0 surface](../../spec/phase-4/prerequisites-and-scheduling.md#the-10-surface)
  lists none.
- Resolved: the shape is chosen with `.badgeShape(_:)`, an environment style modifier,
  because key B12 makes a closed set of looks one, as Button's `.buttonBorderShape(_:)`
  is.
- Resolved: reviewed against the [Phase 4 theses](../../spec/phase-4.md). Badge is a
  stateless value composed from Text and style modifiers, its tone and shape resolve from
  roles, tokens, and the environment, and its geometry is deterministic integer-cell
  output.

## Inspiration

None yet.
