---
kind: primitive
status: wireframed
---

# Label

`Label` draws a semantic icon and a title on one row. The icon is a name, not a glyph: the
name resolves to a glyph and default role for the active icon charset. `Label` is
stateless. It has no focus, keys or pointer behaviour, and no style of its own beyond the
roles below.

Owner decision, omp2 review, 2026-10: adopt the omp2 icon behaviour. Names resolve per
charset (Unicode, ASCII, Nerd Font) from the environment. Unknown names draw as their raw
text. The catalog's token rows are pending plan 032 step 5.3.

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
public enum IconCharset: Sendable {
    case unicode, ascii, nerdFont
}

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
    .labelIconRole(.blue)
```

- The charset is a shared environment value, `\.iconCharset` (proposed), read by every
  `Label`: `.unicode` by default, `.nerdFont`, or `.ascii`. The app or the terminal
  capability sets it (owner decision, 2026-10-10). The charset's token row lands in plan
  032 step 5.3.
- `icon` names one row of the semantic icon catalog. Unknown names draw the raw name text
  in the title's place of the icon.
- The icon and title are separated by one column (owner decision, 2026-10-10).

## Icon catalog

Each semantic name has a glyph in each charset and a default role. The catalog is the omp2
icon table, with one row per name and columns for Unicode, ASCII and Nerd Font. The rows
in this doc are the names the captures use.

| Name          | Unicode | ASCII  | Nerd Font | Default role                                |
| ------------- | ------- | ------ | --------- | ------------------------------------------- |
| `error`       | ✘       | `[!!]` | U+F00D    | `error`                                     |
| `success`     | ✔       | `[ok]` | U+F00C    | `success`                                   |
| `done`        | •       | `*`    | •         | `success`                                   |
| `pending`     | ⏳      | `[*]`  | U+F254    | `output` (token pending plan 032 step 5.3)  |
| `running`     | ⟳       | `[~]`  | U+F110    | `accent`                                    |
| `idle`        | ○       | `[-]`  | U+F111    | `accent`                                    |
| `parked`      | ⏸       | `[\|]` | U+F04C    | `accent`                                    |
| `stopped`     | ⏹       | `[#]`  | U+F28D    | `accent`                                    |
| `enabled`     | ●       | `[x]`  | U+F111    | `accent`                                    |
| `cursor`      | ❯       | `>`    | U+F054    | `accent`                                    |
| `folder`      | 📁      | `[D]`  | U+F115    | `accent`                                    |
| `folder-open` | 📂      | `[O]`  | U+F07C    | `accent`                                    |
| `file`        | 📄      | `[F]`  | U+F15B    | `accent`                                    |
| `git`         | ⎇       | `git:` | U+F1D3    | `accent`                                    |
| `warning`     | ⚠       | `[!]`  | U+F071    | `warning` (token pending plan 032 step 5.3) |

Default roles follow omp2's rule (`icon.rs` L79-L86): `error` takes `error`; `done` and
`success` take `success`; `pending` takes `output`; any other name takes `accent`, except
`warning`. Owner decision, 2026-10-10: `warning` takes the `warning` role (token pending
plan 032 step 5.3), the warning tone, not `accent` as omp2 gives it. Callout and
ContentUnavailableView already assume that tone.

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
3. r0 c2-6     Title -- the name's title text, primary role
4. r1 c0       Icon -- `success` glyph, success role
5. r2 c0       Icon -- `done` glyph, success role
```

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
takes the role. The `pending` and `folder` glyphs are two columns wide.

```wireframe 40x13
✘ error
✔ success
• done
⏳ pending
⟳ running
○ idle
⏸ parked
⏹ stopped
● enabled
❯ cursor
📁 folder
⎇ git
⚠ warning
```

```text
Callouts (40x13, 0-based):
1. r0, r1, r2 c0       Icon -- `error`, `success`, `done`; error, success, success roles
2. r3 c0-1             Icon -- `pending`, wide glyph; output role (pending 5.3)
3. r4-r11 c0           Icon -- `running`, `idle`, `parked`, `stopped`, `enabled`, `cursor`,
                       `folder`, `git`, accent role; `folder` is wide
4. r12 c0              Icon -- `warning`, warning role (token pending plan 032 step 5.3)
5. title columns       Title -- primary role, after a one-column gap
```

```text
── chars ──
✘ error
✔ success
• done
⏳ pending
⟳ running
○ idle
⏸ parked
⏹ stopped
● enabled
❯ cursor
📁 folder
⎇ git
⚠ warning
── style ──
A
B
B
CC
D
D
D
D
D
D
DD
D
E
── legend ──
.  default
A  fg=error
B  fg=success
C  fg=output
D  fg=accent
E  fg=warning (token pending plan 032 step 5.3)
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
4. r3 c0-2    Icon -- `pending`, output role (token pending plan 032 step 5.3)
5. r4-r11     Icon -- accent role, one per name; `git` draws `git:`, `folder` draws `[D]`
6. r12 c0-2   Icon -- `warning`, warning role (token pending plan 032 step 5.3)
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
C  fg=output
D  fg=accent
E  fg=warning (token pending plan 032 step 5.3)
```

### Nerd Font catalog (40 columns)

Each Nerd Font glyph is one private-use character, drawn as one column. The name's role
colours it the same way as in Unicode.

```wireframe 40x13
 error
 success
• done
 pending
 running
 idle
 parked
 stopped
 enabled
 cursor
 folder
 git
 warning
```

```text
Callouts (40x13, 0-based):
1. r0 c0       Icon -- `error` glyph U+F00D, error role
2. r1 c0       Icon -- `success` glyph U+F00C, success role
3. r2 c0       Icon -- `done`, a Unicode bullet kept in Nerd Font, success role
4. r3-r11 c0   Icon -- Nerd Font glyphs, role by name (pending output, others accent)
5. r12 c0      Icon -- `warning` glyph U+F071, warning role (token pending plan 032 step 5.3)
```

```text
── chars ──
 error
 success
• done
 pending
 running
 idle
 parked
 stopped
 enabled
 cursor
 folder
 git
 warning
── style ──
A
B
B
C
D
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
C  fg=output
D  fg=accent
E  fg=warning (token pending plan 032 step 5.3)
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
✘ error, recoloured blue
✔ success, recoloured blue
✘ error, default red
```

```text
Callouts (40x3, 0-based):
1. r0-r1 c0    Icon -- explicit blue, replacing the `error` and `success` roles
2. r0-r1 c2-   Title -- primary role
3. r2 c0       Icon -- `error` default role, error
```

```text
── chars ──
✘ error, recoloured blue
✔ success, recoloured blue
✘ error, default red
── style ──
A
A
B
── legend ──
.  default
A  fg=blue (explicit)
B  fg=error
```

## Variants

| Charset  | Icon form      | Column width | Source                   |
| -------- | -------------- | ------------ | ------------------------ |
| unicode  | one glyph      | one or two   | catalog Unicode column   |
| ascii    | bracketed text | one to four  | catalog ASCII column     |
| nerdFont | one PUA glyph  | one          | catalog Nerd Font column |

## Sizing

Schema: [README](../README.md#sizing-table). Mandatory rows: nil x nil, tight,
under-minimum, over-maximum.

| Proposal      | Result                                     | Rule                                     |
| ------------- | ------------------------------------------ | ---------------------------------------- |
| nil x nil     | Icon width, gap, then the title on one row | Height is one row                        |
| tight         | Title clipped at the row edge; icon kept   | Icon is never clipped; title clips first |
| under-minimum | Icon only; nothing below one cell          | Title dropped; icon kept                 |
| over-maximum  | Title takes the remaining width            | No maximum                               |

## Environment

- `\.iconCharset` (proposed): the shared charset, `.unicode` by default, `.nerdFont`, or
  `.ascii`. The app or terminal capability sets it. Token row pending plan 032 step 5.3.
- Role `primary` for titles: `semantic.primary`, see
  [tokens.md](../tokens.md#semantic-styles).
- Role `accent` for default names: `semantic.accent`.
- Roles `error`, `success`, `output`, and `warning`: token pending plan 032 step 5.3. The
  Tokens catalog defines no such rows.
- Icon catalog: one row per semantic name, per charset. Token rows pending plan 032 step
  5.3.

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
- `label draws the pending glyph in the output role` (Unicode catalog, ASCII catalog)
- `label separates the icon from the title by one column` (Anatomy)
- `label draws the warning name in the warning role` (Unicode catalog, ASCII catalog, Nerd
  Font catalog)
- `label keeps the title in the primary role` (Anatomy, Override colour)
- `label icon role override replaces the glyph's default role and leaves the title primary`
  (Override colour)
- `label draws icons in running text in the surrounding role` (In running text)

## Degradation

- ASCII charset: the bracketed ASCII column is used. Names draw as the ASCII column.
- Each catalog row falls back in this order: Nerd Font, then Unicode, then ASCII (owner
  decision, 2026-10-10).
- `NO_COLOR`: role colours are lost. Glyphs still identify the name in every charset.
- Under the minimum width: the icon only. Below one cell: nothing (owner decision,
  2026-10-10).

## Open questions

- Catalog token rows: the `error`, `success`, `output`, and `warning` roles and the
  catalog's glyph rows are token pending plan 032 step 5.3.

## Inspiration

- None yet.
