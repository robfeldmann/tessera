---
kind: primitive
status: specified
---

# Label

`Label` draws a semantic icon and a title on one row. The icon is a name, not a glyph: the
name resolves to a glyph and default role for the active icon charset. `Label` is
stateless. It has no focus, keys or pointer behaviour, and no style of its own beyond the
roles below.

Owner decision, omp2 review, 2026-10: adopt the omp2 icon behaviour. Names resolve per
charset (Unicode, ASCII, Nerd Font) from the environment. Unknown names draw as their raw
text. The icon catalog is [tokens.md](../tokens.md#icon-catalog).

## Prior art

- omp2 Icon,
  [icon.rs](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/icon.rs#L12-L16),
  stores a semantic name and resolves it through the charset. The glyph lookup is at
  [#L40-L42](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/icon.rs#L40-L42).
  The default colour by name is at
  [#L79-L86](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/icon.rs#L79-L86).
  Copy the name-to-glyph lookup, the raw-name fallback, and the default colour by name.
  Reject the `<icon>` markup tag and the string-only `Str` props.
- SwiftUI's `Label` pairs a title with an image. Tessera's `Label` pairs a title with a
  semantic icon name.

## API direction

```swift
public struct IconName: ExpressibleByStringLiteral, Sendable {
    public init(stringLiteral value: String)
}

public struct Label: View {
    public init(_ title: String, icon: IconName)
}
```

```swift
Label("Build passed", icon: "success")
Label("Cache cold", icon: "pending")
```

```swift
extension Label {
    public func labelIconRole(_ color: Color) -> Label
}

Label("Build passed", icon: "success")
    .labelIconRole(.info)
```

- The charset is the shared environment value `\.charset`
  ([tokens.md#charset](../tokens.md#charset)), read by every `Label`: `.unicode` by
  default, `.nerdFont`, or `.ascii`. The app states an intent, `.automatic` by default;
  the locale, `NERDFONT` and the intent resolve the charset. Terminal identity never
  selects it (owner decision, 2026-10-19).
- `icon` names one row of the semantic icon catalog. Unknown names draw the raw name text
  in the title's place of the icon.
- The icon and title are separated by one column (owner decision, 2026-10-10). A Nerd Font
  icon's blank second cell is that gap ([Nerd Font cells](../tokens.md#nerd-font-cells);
  owner decision, 2026-10-19). A name with no glyph in the active charset (a `none` cell
  in the [icon catalog](../tokens.md#icon-catalog)) draws no icon and no gap: the title
  starts at c0.

## Icon catalog

Glyphs, ASCII forms and default roles for every name are the
[icon catalog](../tokens.md#icon-catalog) (owner decision, 2026-10-19). The captures below
use `error`, `success`, `done`, `pending`, `running`, `idle`, `parked`, `stopped`,
`enabled`, `cursor`, `folder`, `git` and `warning`.

Default roles follow [tokens.md#icon-catalog](../tokens.md#icon-catalog): omp2's rule
(`icon.rs` L79-L86) with the owner's changes. `error` takes `error`; `done` and `success`
take `success`; `warning` takes `warning` (owner decision, 2026-10-10); `info` takes
`info`; `pending` takes `secondary` (owner decision, 2026-10-19); any other name takes
`accent`. A caller may replace the icon's role with `.labelIconRole(_:)`.

## Anatomy

Three names from the Unicode catalog, 40 columns:

```wireframe 40x3
✘ error
✔ success
• done
```

```text
Callouts (40x3, 0-based):
1. r0 c0       Icon -- `error` glyph, error role
2. r0 c1       Gap -- one column between icon and title (owner decision, 2026-10-10)
3. r0 c2-6     Title -- the name's title text, primary role; one row, tail-truncates (exception below)
4. r1 c0       Icon -- `success` glyph, success role
5. r2 c0       Icon -- `done` glyph, success role
```

> Wrap exception (rule 1): icon and title share one row; the title tail-truncates after
> the icon. A wrapped title would leave the icon column. (owner decision, 2026-10-18)

The component applies `.lineLimit(1)` and `.truncationMode(.tail)` directly on the title
Text, so an app's inherited `lineLimit` and `truncationMode` do not reach it.

```text
── chars ──
✘ error
✔ success
• done
── style ──
A
B
B
── legend ──
.  default
A  fg=error
B  fg=success
```

## States

### Unicode catalog (40 columns)

Every name in the capture, drawn with its default role. The title is `primary`, the glyph
takes the role. Under `.unicode`, `pending` and `folder` draw no icon and no gap, so their
titles start at c0 (owner decision, 2026-10-19).

```wireframe 40x13
✘ error
✔ success
• done
pending
⟳ running
○ idle
⏸ parked
⏹ stopped
● enabled
❯ cursor
folder
⎇ git
⚠ warning
```

```text
Callouts (40x13, 0-based):
1. r0, r1, r2 c0       Icon -- `error`, `success`, `done`; error, success, success roles
2. r3, r10 c0          Title only -- `pending` and `folder` draw no Unicode icon (tokens.md#icon-catalog); the title starts at c0 with no gap
3. r4-r9, r11 c0       Icon -- `running`, `idle`, `parked`, `stopped`, `enabled`, `cursor`, `git`; accent role
4. r12 c0              Icon -- `warning`, warning role
5. title columns       Title -- primary role, after a one-column gap
```

```text
── chars ──
✘ error
✔ success
• done
pending
⟳ running
○ idle
⏸ parked
⏹ stopped
● enabled
❯ cursor
folder
⎇ git
⚠ warning
── style ──
A
B
B

D
D
D
D
D
D

D
E
── legend ──
.  default
A  fg=error
B  fg=success
D  fg=accent
E  fg=warning
```

### ASCII catalog (40 columns)

The ASCII charset draws bracketed words and symbols in place of the glyphs.

```wireframe 40x13
[!!] error
[ok] success
* done
[*] pending
[~] running
[-] idle
[|] parked
[#] stopped
[x] enabled
> cursor
[D] folder
git: git
[!] warning
```

```text
Callouts (40x13, 0-based):
1. r0 c0-3    Icon -- `error`, error role
2. r1 c0-3    Icon -- `success`, success role
3. r2 c0      Icon -- `done`, success role
4. r3 c0-2    Icon -- `pending`, secondary role
5. r4-r11     Icon -- accent role, one per name; `git` draws `git:`, `folder` draws `[D]`
6. r12 c0-2   Icon -- `warning`, warning role
```

```text
── chars ──
[!!] error
[ok] success
* done
[*] pending
[~] running
[-] idle
[|] parked
[#] stopped
[x] enabled
> cursor
[D] folder
git: git
[!] warning
── style ──
AAAA
BBBB
B
CCC
DDD
DDD
DDD
DDD
DDD
D
DDD
DDDD
EEE
── legend ──
.  default
A  fg=error
B  fg=success
C  fg=secondary
D  fg=accent
E  fg=warning
```

### Nerd Font catalog (40 columns)

Each Nerd Font icon is a private-use glyph followed by a real U+0020: two cells in layout,
and the space is the icon-title gap ([Nerd Font cells](../tokens.md#nerd-font-cells);
owner decision, 2026-10-19). The name's role colours the glyph as in Unicode.

```wireframe 40x13
 error
 success
• done
 pending
 running
 idle
 parked
 stopped
 enabled
 cursor
 folder
 git
 warning
```

```text
Callouts (40x13, 0-based):
1. r0 c0-c1    Icon -- `error` glyph U+F00D and its blank cell, error role
2. r1 c0-c1    Icon -- `success` glyph U+F00C and its blank cell, success role
3. r2 c0       Icon -- `done`, a Unicode bullet kept in Nerd Font (the ladder's fallback), success role
4. r3-r11 c0-c1  Icon -- Nerd Font glyphs and blank cells, role by name (pending secondary, others accent)
5. r12 c0-c1   Icon -- `warning` glyph U+F071 and its blank cell, warning role
```

```text
── chars ──
 error
 success
• done
 pending
 running
 idle
 parked
 stopped
 enabled
 cursor
 folder
 git
 warning
── style ──
AA
BB
B
CC
DD
DD
DD
DD
DD
DD
DD
DD
EE
── legend ──
.  default
A  fg=error
B  fg=success
C  fg=secondary
D  fg=accent
E  fg=warning
```

### In running text (40 columns)

Icons written inside a line of text stand beside the words. The callout's kind colour
draws the title and body. Inline icons take the surrounding text role (owner decision,
2026-10-10): here the body role, not each name's default role.

```wireframe 40x4
ℹ Branch ⎇ main
│ The working tree is clean, ✔ all 312
│ tests passed, and ⚠ one file is still
│ untracked.
```

```text
Callouts (40x4, 0-based):
1. r0 c0       Icon -- `info` kind icon from the callout, info role
2. r0 c2-12    Title -- text with an inline `git` icon at c9, info bold
3. r1-r3 c0    Rail -- light vertical from the callout, info role
4. r1 c29      Inline icon -- `success` name, drawn in the body role
5. r2 c20      Inline icon -- `warning` name, drawn in the body role
```

```text
── chars ──
ℹ Branch ⎇ main
│ The working tree is clean, ✔ all 312
│ tests passed, and ⚠ one file is still
│ untracked.
── style ──
ABCCCCCCCCCCCCC
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAA
── legend ──
.  default
A  fg=info
B  fg=primary
C  fg=info bold
```

### Override colour (40 columns)

`.labelIconRole(_:)` sets an explicit icon colour: it replaces the icon's semantic role
and leaves the title `primary` (owner decision, 2026-10-10).

```wireframe 40x3
✘ error, recoloured info
✔ success, recoloured info
✘ error, default red
```

```text
Callouts (40x3, 0-based):
1. r0-r1 c0    Icon -- explicit info, replacing the `error` and `success` roles
2. r0-r1 c2-   Title -- primary role
3. r2 c0       Icon -- `error` default role, error
```

```text
── chars ──
✘ error, recoloured info
✔ success, recoloured info
✘ error, default red
── style ──
A
A
B
── legend ──
.  default
A  fg=info (explicit)
B  fg=error
```

## Variants

| Charset  | Icon form         | Column width | Source                   |
| -------- | ----------------- | ------------ | ------------------------ |
| unicode  | one glyph         | one or two   | catalog Unicode column   |
| ascii    | bracketed text    | one to four  | catalog ASCII column     |
| nerdFont | PUA glyph + blank | two          | catalog Nerd Font column |

## Sizing

Schema: [README](../README.md#sizing-table). Mandatory rows: nil x nil, tight,
under-minimum, over-maximum.

| Proposal      | Result                                                  | Rule                                                     |
| ------------- | ------------------------------------------------------- | -------------------------------------------------------- |
| nil x nil     | Icon width, gap, then the title on one row              | Height is one row                                        |
| tight         | Title tail-truncates with `…` after the icon; icon kept | Wrap exception (rule 1): the title never wraps           |
| under-minimum | Icon only; nothing below one cell                       | Title dropped; icon kept                                 |
| over-maximum  | Title takes the remaining width                         | No maximum                                               |
| any x 2+ rows | Height stays one row; the extra rows are unused         | Wrap exception (rule 1): a taller proposal does not wrap |

## Environment

- `\.charset` ([tokens.md#charset](../tokens.md#charset)): the shared charset, `.unicode`
  by default, `.nerdFont`, or `.ascii`. The app's intent sets it; the locale and
  `NERDFONT` cap it.
- Role `primary` for titles: [text roles](../tokens.md#text-roles).
- Role `accent` for default names: [hue roles](../tokens.md#hue-roles).
- Roles `error`, `success` and `warning`: [hue roles](../tokens.md#hue-roles); `pending`
  takes `secondary`.
- Icon catalog: [tokens.md](../tokens.md#icon-catalog).

## Primitive dependencies

- [Text](../primitives/text.md): title and inline icon composition. Status `ready`.

## Requirements

- `label draws the glyph for its semantic name in the active charset` (Unicode catalog,
  ASCII catalog, Nerd Font catalog)
- `label draws unknown names as their raw text` (API direction)
- `label falls back per catalog row from Nerd Font to Unicode to ASCII` (Degradation)
- `label draws only the icon under the minimum width, and nothing below one cell` (Sizing,
  Degradation)
- `label colours the glyph by its name's default role` (Unicode catalog)
- `label draws the pending icon in the secondary role` (ASCII catalog)
- `label separates the icon from the title by one column` (Anatomy)
- `label draws the warning name in the warning role` (Unicode catalog, ASCII catalog, Nerd
  Font catalog)
- `label keeps the title in the primary role` (Anatomy, Override colour)
- `label icon role override replaces the glyph's default role and leaves the title primary`
  (Override colour)
- `label keeps icon and title on one row and tail-truncates the title at a narrow width`
  (Anatomy: Wrap exception; Sizing: tight)
- `label draws icons in running text in the surrounding role` (In running text)
- `label draws no icon for a name whose Unicode cell is none` (Unicode catalog; icon
  catalog)
- `label draws a Nerd Font icon in two cells with a real space after the glyph` (Nerd Font
  catalog; Nerd Font cells)
- `unicode icons never draw colour emoji` (icon catalog)

## Degradation

- ASCII charset: the bracketed ASCII column is used. Names draw as the ASCII column.
- Each catalog row falls back in this order: Nerd Font, then Unicode, then ASCII (owner
  decision, 2026-10-10). A `none` cell in the catalog is a deliberate blank: the row draws
  nothing in that charset and does not fall back
  ([tokens.md#icon-catalog](../tokens.md#icon-catalog)).
- `NO_COLOR`: role colours are lost. Glyphs still identify the name in every charset.
- Under the minimum width: the icon only. Below one cell: nothing (owner decision,
  2026-10-10).
- Narrow width: the title tail-truncates with `…` (`~` in ASCII) after the icon; it never
  wraps (Wrap exception, rule 1).

## Open questions

- None.

## Inspiration

- None yet.
