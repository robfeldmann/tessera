---
kind: widget
status: specified
---

# Image

`Image` draws a raster image in a box of terminal cells. It decodes its source asynchronously, fits the image to the requested box with its aspect ratio kept, and draws half-block text cells where the terminal has no image protocol. Where the terminal supports the graphics protocol, the image is sent as pixels instead; that path builds on the [Kitty graphics substrate](../../spec/phase-3/slice-07-kitty-graphics-protocol.md).

This widget follows the controlled-widget rule in [Slice 7](../../spec/phase-4/slice-07-catalog-integration.md). The application owns the source path. Image owns the decoded bitmap and its load phase.

Owner decision, omp2 review, 2026-10: Image moves to 1.0 and is adopted as omp2 draws it, so the wireframes below redraw omp2's output with Tessera's role names. Sub-cell rasters beyond the half-block path (braille, charts, sparklines, QR) are post-1.0, as plan 032 step 4.1 classified them.

## Prior art

- omp2 `Img` component: [img.rs#L94-L119](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/img.rs#L94-L119). Copy the props: `src`, `w` (cells, or a percentage of the available columns), `h`, `max-rows` and `trim`. Reject the markup form: Tessera takes a path, not `src=` strings. Key translations: `src` is display data, a plain parameter redeclared on every update rather than refreshed with `set_prop` (keys D2, A8); `w` and `h` are `.frame` (key B2; a percentage width is key G8); `max-rows` is `.maxRows(_:)` (key B8); and `trim` and the graphics tiers are Image's (key M5).
- Graphics tiers: [context.rs#L735-L749](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/context.rs#L735-L749). omp2 picks `Cells`, `Sixel`, `KittyDirect`, `KittyPlaceholders` or `Iterm2` from its context. Graphics capability is terminal state, never a view attribute (key M5); see Open questions for Tessera's tiers.
- Fit and aspect ratio: [img.rs#L40-L65](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/img.rs#L40-L65). Copy the fit rule: `max-rows` caps the derived height and narrows the drawn width to keep the aspect ratio; `h` fixes the rows and stretches the source.
- Load phases: [img.rs#L67-L74](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/img.rs#L67-L74). Copy the `Unloaded` default and the rule that the placeholder draws while the phase is not `Ready`.
- Half-block fallback: [img.rs#L428-L444](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/img.rs#L428-L444). Copy the rule that one cell carries two image pixels as an upper half block, with the top pixel as foreground and the bottom as background, and that a cell with both pixels transparent is skipped. Copy the ASCII fallback `#` for ink cells.
- Placeholder: [img.rs#L354-L409](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/img.rs#L354-L409). Copy the rule that the placeholder draws while the phase is not `Ready`. The square border, rails and `[img: <name>]` label are not copied: the loading placeholder is a `░` box (see Placeholder).
- Decode path: [img.rs#L535-L545](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/img.rs#L535-L545) and [img.rs#L604-L610](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/img.rs#L604-L610). Copy the asynchronous decode: the loader decodes off the UI thread and delivers the bitmap back, which installs it only while the phase is `Loading`.

## API direction

```swift
Image(path: "assets/login/anthropic.png", label: "Anthropic logo")
    .frame(width: 32, height: 16)
    .maxRows(8)
    .trim()
```

`path` names the source. `label` is optional text the app supplies to describe the image (owner decision, 2026-10-18); it mirrors SwiftUI's `Image(_:label:)`, and the `Boxed` phase draws it (see Boxed). `frame` sets the requested box in cells. `maxRows` caps the drawn height and narrows the drawn width to keep the aspect ratio. `trim()` crops fully transparent margins before sampling. The modifier names are a proposal, and plan 032 step 16.3 settles them.

## Anatomy

Default image at 80 columns: the Anthropic logo, a 64-pixel source drawn in a 32-cell by 16-row box. Each cell stacks two image pixels as a half block (`▀`, `▄`). Transparent margins stay in the box as blank cells. The pixel colours are the image's own data, a foreground and a background colour per cell. Those values are not Tessera roles, so no styled grid is drawn here; see Environment.

```wireframe 80x16
          ▄▄
         ▀▀▀▄    ▀▀
          ▀▀▀▄   ▀▀   ▄▀▀
     ▀▀▀▄  ▀▀▀▄  ▀▀ ▄▀▀▀▀
      ▀▀▀▀▄▄▀▀▀▄▄▀ ▄▀▀▀
         ▀▀▀▀▀▀▀▀▀▀▀▀▀     ▄
   ▄▄▄▄▄▄▄  ▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀
    ▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▄▄▄▄▄▄▄
          ▄▀▀▀▀▀▀▀▀▀▄ ▀▀▀▀▀▀▀
       ▄▀▀▀ ▄▀▀ ▀▀▀▀▀▀▄▄
      ▀▀   ▄▀▀ ▄▀  ▀▀▄ ▀▀▄
         ▄▀▀   ▀▀   ▀▀▄  ▀
         ▀     ▀▀     ▀
               ▀


```

```text
Callouts (80x16, 0-based):
1. r0-r15 c0-c31   Image box, 32 x 16 cells -- Image, pixel colours from the source
2. r0-r13 c3-c28   Logo ink -- half-block cells `▀`, `▄`, two pixel rows per cell
3. r14-r15         Bottom transparent margin -- blank cells
4. c0-c2, c29-c31  Left and right transparent margins -- blank cells
```

## States

### Mobile

The same default image at 40 columns. The 32-cell box fits the 40-column design unchanged.

```wireframe 40x16
          ▄▄
         ▀▀▀▄    ▀▀
          ▀▀▀▄   ▀▀   ▄▀▀
     ▀▀▀▄  ▀▀▀▄  ▀▀ ▄▀▀▀▀
      ▀▀▀▀▄▄▀▀▀▄▄▀ ▄▀▀▀
         ▀▀▀▀▀▀▀▀▀▀▀▀▀     ▄
   ▄▄▄▄▄▄▄  ▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀
    ▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▄▄▄▄▄▄▄
          ▄▀▀▀▀▀▀▀▀▀▄ ▀▀▀▀▀▀▀
       ▄▀▀▀ ▄▀▀ ▀▀▀▀▀▀▄▄
      ▀▀   ▄▀▀ ▄▀  ▀▀▄ ▀▀▄
         ▄▀▀   ▀▀   ▀▀▄  ▀
         ▀     ▀▀     ▀
               ▀


```

```text
Callouts (40x16, 0-based):
1. r0-r15 c0-c31   Image box, 32 x 16 cells -- Image
2. r0-r13 c3-c28   Logo ink -- half-block cells
3. r14-r15         Bottom transparent margin -- blank cells
```

### Minimum

The renderer's floor is one cell: omp2 clamps the drawn width to at least one cell. The minimum state is drawn at 8 columns by 4 rows, with the logo as half-block cells. It is a Tessera drawing, not an omp2 capture (owner decision, 2026-10-10).

```wireframe 8x4
  ▄▀▄
 ▄▀▀▀▄
▀▀▀▀▀▀▄▄
  ▀▀▀▀▀▀
```

```text
Callouts (8x4, 0-based):
1. r0 c2-c4; r1 c1-c5; r2 c0-c7; r3 c2-c7   Logo ink, half-block cells -- Image, pixel colours
2. r0 c0-c1, c5-c7; r1 c0, c6-c7; r3 c0-c1   Transparent margin -- blank cells
```

### Placeholder

While the load phase is `Unloaded` or `Loading`, Image draws a box of `░` cells in `border`, filling the requested box, with `Loading…` in `secondary` centred on the middle row. The wireframe shows the default 32 by 16 box. This is a Tessera drawing, not an omp2 capture, so no capture is needed (owner decision, 2026-10-10). The placeholder draws whenever the phase is not `Ready`; the `Boxed` phase draws the label instead (see Boxed).

```wireframe 32x16
░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
░░░░░░░░░░░░Loading…░░░░░░░░░░░░
░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
```

```text
Callouts (32x16, 0-based):
1. r0-r15 c0-c31   Placeholder box, `░` fill -- Image, `border`
2. r8 c12-c19      `Loading…` centred -- Image, `secondary`; chrome, one row
```

```text
── chars ──
░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
░░░░░░░░░░░░Loading…░░░░░░░░░░░░
░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
── style ──
BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB
BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB
BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB
BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB
BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB
BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB
BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB
BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB
BBBBBBBBBBBBDDDDDDDDBBBBBBBBBBBB
BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB
BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB
BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB
BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB
BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB
BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB
BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB
── legend ──
B  fg=border
D  fg=secondary
```

### Boxed

The `Boxed` phase settles with no pixels: a failed read or decode, or a probe-only format. It keeps the same `border` `░` box at the same size and replaces `Loading…` with the app's `label`, or the file name when the app gave none (owner decision, 2026-10-18). The text is `secondary` and is content: it wraps within the box, at the box width less two cells so a `░` cell always shows at each edge, and is centred as a block on the middle rows. Under a fixed box height the last visible row ends in `…` (see [Text](../primitives/text.md#row-budget)). The wireframe shows the label `Anthropic logo: an orange spark mark on a transparent background` after the optional icon in its Unicode text form.

An optional `image` icon may precede the text (owner decision, 2026-10-18). It is a row of the [icon catalog](../tokens.md#icon-catalog): `[img]` in Unicode and ASCII, U+F03E in Nerd Font, role `secondary` (owner decision, 2026-10-18).

```wireframe 32x16
░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
░░░░[img] Anthropic logo: an░░░░
░░░░░orange spark mark on a░░░░░
░░░░░transparent background░░░░░
░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
```

```text
Callouts (32x16, 0-based):
1. r0-r15 c0-c31   Placeholder box, `░` fill -- Image, `border`; same box as Loading
2. r6 c4-c8        Icon `[img]` -- `image` icon, Unicode text form, `secondary`; chrome, one row
3. r6-r8 c4-c27    Label -- Text, `secondary`; content, wraps within c1-c30, each row centred
```

Styled grid: the Loading grid above, with the box cells `B` (`border`), and the icon and label cells `D` (`secondary`): row 6 cols 4-8 and 10-27; rows 7-8 cols 5-26.

### Sized

Two images on one row, gap 3. The left image asks for 32 cells wide with `max-rows=8`, which narrows its drawn width to fit eight rows. The right image is a fixed 16 by 8 box. Each keeps its transparent margins inside its box.

```wireframe 80x8
     ▀▄ ▄▀ ▄▄                           ▀▄ ▄▀ ▄▄
   ▀▄ ▀▄▀ ▀▀                          ▀▄ ▀▄▀ ▀▀
     ▀▀▀▀▀▀▄▄▄                          ▀▀▀▀▀▀▄▄▄
     ▄▀▀▀▀▀ ▄▄                          ▄▀▀▀▀▀ ▄▄
    ▀ ▀ ▀▀▀                            ▀ ▀ ▀▀▀
     ▀ ▄  ▀                             ▀ ▄  ▀


```

```text
Callouts (80x8, 0-based):
1. r0-r5 c3-c13    Left logo ink, drawn 16 x 8 after max-rows 8 -- Image, pixel colours
2. r0-r5 c38-c48   Right logo ink, fixed 16 x 8 box at c35-c50 -- Image, pixel colours
3. r6-r7           Bottom transparent rows -- blank cells
```

At 40 columns the same two images sit closer together:

```wireframe 40x8
     ▀▄ ▄▀ ▄▄                ▀▄ ▄▀ ▄▄
   ▀▄ ▀▄▀ ▀▀               ▀▄ ▀▄▀ ▀▀
     ▀▀▀▀▀▀▄▄▄               ▀▀▀▀▀▀▄▄▄
     ▄▀▀▀▀▀ ▄▄               ▄▀▀▀▀▀ ▄▄
    ▀ ▀ ▀▀▀                 ▀ ▀ ▀▀▀
     ▀ ▄  ▀                  ▀ ▄  ▀


```

```text
Callouts (40x8, 0-based):
1. r0-r5 c3-c13    Left logo ink, drawn 16 x 8 after max-rows 8 -- Image, pixel colours
2. r0-r5 c27-c37   Right logo ink, as drawn at 40 columns -- Image, pixel colours
3. r6-r7           Bottom transparent rows -- blank cells
```

### Trim

The same logo at 32 cells wide with `trim`. Trim crops fully transparent margins before sampling, so the mark fills the 32 by 16 box edge to edge.

```wireframe 80x16
       ▄▀▀▀▄      ▄▄
       ▀▀▀▀▀▄    ▀▀▀▀
        ▀▀▀▀▀    ▀▀▀   ▄▀▀▀▀
   ▀▀▀▄  ▀▀▀▀▀▄  ▀▀▀  ▄▀▀▀▀▀
   ▀▀▀▀▀▄▄ ▀▀▀▀▄ ▀▀▀▄▀▀▀▀▀▀
     ▀▀▀▀▀▀▄▀▀▀▀▀▀▀▀▀▀▀▀▀
        ▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀  ▄▄▄▄▀▄
▄▄▄▄▄▄▄▄▄▄▄▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀
 ▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▄▄▄▄▄
          ▄▄▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀
      ▄▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▄   ▀▀▀▀▀
    ▄▀▀▀▀▀▀▄▀▀▀▀▀▀▀▀▀▀▀▀▀▀▄
    ▀▀▀  ▄▀▀▀  ▀▀▀ ▀▀▀▀▄▀▀▀▀▄
        ▄▀▀▀   ▀▀▀  ▀▀▀▀▄  ▀▀
       ▀▀▀    ▀▀▀▀    ▀▀▀
              ▀▀▀
```

```text
Callouts (80x16, 0-based):
1. r0-r15 c0-c31   Trimmed logo fills the box -- Image, pixel colours
2. r0 c7-c20, r15 c14-c16  Top and bottom rows carry logo ink, not margin
3. r6 c0, c31      Left and right edges carry logo ink, not margin
```

### ASCII fallback

The default image in the ASCII degradation set. Each ink cell draws `#`, so the mark keeps its shape without half-block glyphs. Transparent cells stay blank.

Rows as drawn:

```text
          ##
         ####    ##
          ####   ##   ###
     ####  ####  ## #####
      ############ ####
         #############     #
   #######  #################
    ########################
          ########### #######
       #### ### ########
      ##   ### ##  ### ###
         ###   ##   ###  #
         #     ##     #
               #
```

```text
Callouts (80x16, 0-based):
1. r0-r15 c0-c31   Image box, 32 x 16 cells -- Image, ASCII degradation
2. r0-r13 c3-c28   Logo ink -- `#` cells in place of half blocks
3. r14-r15         Bottom transparent margin -- blank cells
```

## State model

Schema: [README](../../design.md#state-model-table).

| State | Owner | Type | Reset or clamp rule |
| --- | --- | --- | --- |
| Source path | Binding | `String` | app-owned display data, redeclared on every update (key D2); a new path starts a new load and drops the old bitmap |
| Label | Binding | `String?` | app-owned (key D2); drawn by `Boxed`; the file name when nil |
| Load phase | NodeState | `Unloaded`, `Loading`, `Ready`, `Boxed` | `Unloaded` by default and on a path change; placeholder while not `Ready`; see Open questions for how the loader writes it |
| Bitmap | NodeState | decoded pixels | decoded from the path; dropped and decoded again when the path changes; losing it loses no data |
| Drawn cells | derived | cells | recomputed each render from the bitmap, the frame, `maxRows` and `trim`; never stored (key D10) |

The load phase has the four variants of omp2's `Load` enum (owner decision, 2026-10-10): `Unloaded` (default), `Loading` (the request is with the loader), `Ready` (the bitmap is installed), and `Boxed` (settled with no pixels: a failed read or decode, or a probe-only format). omp2 has no separate failure variant, so no `Failed` phase is added (owner decision, 2026-10-10).

## Key table

Schema: [README](../../design.md#key-table). None. Image is a leaf in 1.0, like [ScrollIndicator](../primitives/scroll-indicator.md): it takes no focus and consumes no keys (owner decision, 2026-10-10). An app that needs a focus target wraps it in a [Button](button.md).

## Mouse table

Schema: [README](../../design.md#mouse-table). None. Image is a leaf in 1.0 and takes no pointer input (owner decision, 2026-10-10). Wrap it in a [Button](button.md) for a click target.

## Sizing

Schema: [README](../../design.md#sizing-table). The drawn box keeps the image's aspect ratio. The requested box comes from `frame` in cells; `maxRows` narrows the drawn width, as the Sized state shows.

Layout reserves the requested frame, and the drawn image sits inside it. omp2 measures a Cells-mode Image at the requested width, even when `max-rows` draws it narrower; Tessera follows the reservation rule instead (owner decision, 2026-10-10). Rows use the 64 by 64 pixel logo of the Anatomy.

| Proposal | Result | Rule |
| --- | --- | --- |
| nil x nil | 64x32 | Natural size: one cell per pixel column and two pixel rows per cell |
| nil x nil, `maxRows` 8 | 16x8 | `maxRows` caps the height at 8 rows (16 pixel rows), and the width narrows to 16 to keep the aspect ratio |
| 32x16 (tight) | 32x16 | The Anatomy box: the source scales to 32 by 32 pixels and fills the box exactly |
| 0x0 (under-minimum) | 0x0 | Layout reserves the proposed box; the drawn width floors at one cell, as in Minimum, and the empty region clips it |
| 80x16 (over-maximum) | 80x16 | Layout reserves the proposed box; the image fits by height to 32x16, and the spare 48 columns stay blank |
| 32 x nil, `maxRows` 8 | 32x8 | Sized, left image at 80 columns: the 32-cell width is reserved, and the drawn image narrows to 16x8 (owner decision, 2026-10-10) |
| 21 x nil, `maxRows` 8 | 21x8 | Sized, left image at 40 columns, where the row leaves it 21 cells: the drawn image stays 16x8 |
| 16x8 | 16x8 | Sized, right image: the source scales to 16 by 16 pixels and fills the box |
| 32x16 (`Boxed`) | 32x16 | The same box as the placeholder; the label wraps within it at 30 cells, rows past the box height are cut, and the last visible row ends in `…` (owner decision, 2026-10-18) |

## Environment

Tokens consumed, each defined in [tokens.md](../tokens.md).

- `disabled`: not used. Image has no disabled state.

Roles: `border` for the placeholder fill (`image.placeholder`, [bars and ramps](../tokens.md#bars-and-ramps)); `secondary` for the `Loading…` text, the `Boxed` label and the `image` icon ([text roles](../tokens.md#text-roles)).

Pixel colours are the image's own data, not Tessera roles, and take no token, so the pixel cells have no styled grid.

The placeholder is a `░` fill drawn by Image, not a border, so it takes no entry in the [border](../primitives/border.md) glyph table. Under the ASCII charset the fill is `.` (owner decision, 2026-10-18).

## Primitive dependencies

- [Text](../primitives/text.md): half-block and ASCII cells, and the `Loading…` placeholder text and the wrapping `Boxed` label.
- [Label](../primitives/label.md#icon-catalog): the optional `image` icon.
- Kitty graphics substrate: [Slice 7](../../spec/phase-3/slice-07-kitty-graphics-protocol.md). The protocol path sends pixels instead of half-block cells when the terminal supports it.

## Requirements

Schema: [README](../../design.md#requirements-list). Each entry traces to a callout or state above.

- `image draws two pixel rows per cell with half-block glyphs` (Anatomy callout 3)
- `image leaves transparent margins as blank cells inside its box` (Anatomy callouts 2 and 4)
- `image keeps the aspect ratio when it fits the requested box` (Sized; Sizing 32x16, 80x16, 16x8)
- `image narrows its drawn width to fit max-rows` (Sized callout 1)
- `image trim crops fully transparent margins before sampling` (Trim)
- `image draws a ░ placeholder box in border with secondary Loading… text centred until the load phase is Ready` (Placeholder)
- `image draws ink cells as # in the ASCII degradation set` (ASCII fallback)
- `image boxed phase draws the border ░ box at the same size as the loading placeholder` (Boxed; owner decision, 2026-10-18)
- `image boxed phase draws the app's label, wrapped within the box, or the file name when there is no label` (Boxed; State model; owner decision, 2026-10-18)
- `image boxed phase ends the last visible label row in an ellipsis when the box height cuts it` (Sizing; owner decision, 2026-10-18)
- `image draws the optional image icon before the boxed label, as [img] in Unicode and ASCII` (Boxed callout 2; owner decision, 2026-10-18)
- `image draws its minimum state at 8 by 4 cells, with a one-cell floor` (Minimum)
- `image takes no focus, keys or pointer input in 1.0; apps wrap it in a Button` (Key table; Mouse table)
- `image reserves the proposed box for tight, under-minimum and over-maximum proposals` (Sizing 32x16, 0x0, 80x16)
- `image nil x nil size is pixel width by half pixel height, capped by maxRows` (Sizing nil x nil, nil x nil with `maxRows` 8)
- `image keeps its reserved width when maxRows narrows the drawn image` (Sizing 32 x nil and 21 x nil with `maxRows` 8; owner decision, 2026-10-10)
- `image draws 16-colour cells as the nearest indexed colour per pixel` (Degradation)
- `image draws density art from the ten-step ramp under NO_COLOR` (Degradation)
- `image draws the placeholder fill as . under the ASCII charset` (Degradation)
- `image density ramp inverts on a light scheme` (Degradation; bars and ramps)

## Degradation

Follows the [degradation ladder](../tokens.md#degradation-ladder). Without an image protocol the logo is drawn as half-block cells. In the ASCII-only set ink cells draw `#`, and the placeholder fill draws `.` in place of `░`, the lightest glyph, so `Loading…` or the label stands out (owner decision, 2026-10-18).

- 16-colour: each pixel takes the nearest indexed colour, and each half-block cell keeps its top pixel as foreground and bottom pixel as background (owner decision, 2026-10-10).
- `NO_COLOR`: Image draws density art in its box instead of the pixels (owner decision, 2026-10-10). Each cell takes the glyph from a ten-step ramp, a space followed by `.:-=+*#%@`, whose ink matches the cell's brightness: blank for background or transparent pixels, `@` for full ink, on a dark scheme (owner decision, 2026-10-18). On a light scheme the ramp inverts, so dark cells take dense glyphs (owner decision, 2026-10-19; [bars and ramps](../tokens.md#bars-and-ramps)). A bright disc at 14x6 reads as:

  ```text
     .:-==-:.
   .=*#%%%%#*=.
   -#%@@@@@@%#-
   -#%@@@@@@%#-
   .=*#%%%%#*=.
     .:-==-:.
  ```

Below 8 by 4 the drawn width floors at one cell, per Sizing.

## Open questions

- **Protocol tiers (key M5).** omp2 has `Cells`, `Sixel`, `KittyDirect`, `KittyPlaceholders` and `Iterm2`. The Spec's [Kitty graphics slice](../../spec/phase-3/slice-07-kitty-graphics-protocol.md) now settles which protocols exist: the Kitty graphics protocol with direct transmission is the only first-class one, and Sixel, iTerm2 inline images and Kitty Unicode placeholders are its non-goals. So Tessera's tiers can only be Kitty placement or half-block cells. Still undecided: how the Kitty tier sizes its box from the cell pixel size, how a placement clips inside a ScrollView, how the tier appears in snapshot tests, and what opts into emission (the Spec's risk register makes blind emission an app opt-in). Blocks `ready`.
- **Loading inside a view.** Image reads and decodes its path off the UI thread and installs the bitmap when the decode returns. That puts file input and a background loader inside a view, and the load phase would change outside event handling, which the README's runtime ownership invariant forbids ([state model table](../../design.md#state-model-table)); the Spec puts async work in the app's own machinery ([handler modifiers](../../spec/phase-4/slice-04-focus-and-key-routing.md#handler-modifiers-and-respondercontext)). Should Image keep its loader, or should the app supply decoded pixels or encoded image data as a plain parameter (key D2) with the load phase in the app's model? Blocks `ready`.

## Inspiration

None yet.
