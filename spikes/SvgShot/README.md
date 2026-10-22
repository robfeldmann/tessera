# Spike 3 — SvgShot

Plan 033, Spike 3. Standalone SwiftPM package depending on the root package by path (`.package(path: "../..")`), public Tessera API only.

## Hypothesis

A `ScreenSnapshot` renders to SVG: background rectangles merged per run, text runs with one explicit `x` per cell, fixed light and dark palettes mapped from `RenderedColor`, attributes bold, dim, italic, underline, strikethrough, and reverse. The output is byte-stable, under 100 KB at 80×24, and legible when rasterised.

## How to run

```sh
cd spikes/SvgShot
swift build
swift run svgshot --theme light --cursor --out out/demo-light.svg
swift run svgshot --theme dark  --cursor --out out/demo-dark.svg
swift run svgshot --input FILE --columns 80 --rows 24 --theme dark   # any ANSI byte stream
swift test
rsvg-convert -w 1536 out/demo-light.svg -o out/demo-light.png
```

Without `--out` the SVG goes to stdout. `--cursor` draws a 2-unit bar at the cursor cell.

## Layout

- `Sources/SVGShot/` — the renderer (`SVGRenderer`), palettes (`SVGPalette`, `SVGColor`), cell-width estimate (`CellWidth`), fixed-point number formatting (`FixedPoint`), and the scripted demo (`DemoScreen`, fed through `VirtualTerminal.ghostty(cols:rows:)`).
- `Sources/SVGShotCLI/main.swift` — hand-rolled argument parsing; product `svgshot`.
- `Tests/SVGShotTests/` — Swift Testing, 10 tests.
- `out/` — `demo-light.svg`, `demo-dark.svg` (from the command above), the rasterised `demo-light.png` / `demo-dark.png` (1536 px wide, rsvg-convert), and `zoom-boxes-light.png` (4× crop of the box-drawing region).

## Geometry

Units are hundredths of an SVG user unit, formatted by integer arithmetic (`960` → `9.6`).

| Quantity     | Value     | Why                                                    |
| ------------ | --------- | ------------------------------------------------------ |
| Cell advance | 9.6 units | 0.6 em at 16 px, the advance of common monospace faces |
| Row height   | 20 units  | Row pitch; baseline at 15 units                        |
| Canvas       | 768 × 480 | 80 × 24 cells                                          |

Every glyph carries its own `x` (a per-character list on `<text>`), and backgrounds, underlines, and strikethroughs are rectangles. Glyph advance therefore never moves a character off its cell. Only glyph shapes come from the font.

## Mapping

- Colors: default fg/bg from the palette; ANSI 0–15 from `SVGPalette.ansi`; 16–231 the xterm 6×6×6 cube and 232–255 the grayscale ramp, both theme-independent; truecolor as-is.
- Reverse: ink becomes the cell's background, paper becomes its foreground. A reversed cell always gets a rectangle, even with default colors.
- Dim: ink is the midpoint of ink and paper (integer channels).
- Bold → `font-weight`, italic → `font-style`.
- Underline `single`/`curly`/`dashed`/`dotted` → one 1-unit line at 17 units; `double` → two lines at 16 and 18. Underline color honours SGR 58 when set.
- Strikethrough → one line at 9 units in the ink color.
- Wide graphemes: text is `textLength` = 2 cells with `lengthAdjust="spacingAndGlyphs"`; the spacer cell is skipped.
- Text: XML-escaped (`& < > " '`); control characters become spaces; `xml:space="preserve"` so per-character positions are never collapsed.

## Proves / Does not prove

### Proves

- Same screen → identical bytes across processes: two `swift run` renders hash to the same SHA-256 (`4ceaa0c6…2683`).
- Light and dark differ only in palette values: `diff` after replacing every `#rrggbb` with `#?` is empty, and `differs between light and dark only in palette values` checks the same thing in code.
- Per-cell `x` positions align text and box drawing to the grid without any font metric. The 4× zoom shows the `|漢|a|字|b|` line and box edges landing on the grid.
- A wide grapheme occupies two cells; its spacer is not drawn; a narrow neighbour survives when the wide-width guess is wrong (regression test).
- The demo at 80×24 is 17,500 bytes per theme, well under 100 KB.
- The SVG is well-formed (`xmllint --noout`) and rasterises in rsvg-convert 2.63.3 (cairo 1.18.6, pango 1.58.2) with Menlo from `/System/Library/Fonts`.

### Does not prove

- Cross-platform byte stability. The macOS vs Lima Linux check was not run, per the assignment. Output uses only integer formatting and no platform APIs, so it is expected to be stable, but that is `[INFERENCE]`.
- Rendering in browsers or Quick Look. Only rsvg-convert was used.
- Size under 100 KB for dense screens. A pathological 80×24 screen where every cell has a distinct truecolor fg/bg and a distinct glyph is 250,717 bytes (both themes). See Findings.
- Correct width for every grapheme. `CellWidth` is a range table, not Unicode width data.

## Verdict: **partial**

Pass: determinism, light/dark palette-only difference, grid alignment independent of font metrics, wide-grapheme placement, legibility of the demo, and the demo under 100 KB.

Partial: the 100 KB budget holds for realistic screens but fails for dense per-cell styling, and cross-platform byte identity is unverified. The cell-width heuristic is a seam, not a fix (see Findings 1).

## Measurements

| Artifact                                                         | Bytes   |
| ---------------------------------------------------------------- | ------- |
| `demo-light.svg` (with `--cursor`)                               | 17,500  |
| `demo-dark.svg` (with `--cursor`)                                | 17,500  |
| `demo-light.svg` without `--cursor`                              | 17,437  |
| Worst case: 80×24, every cell distinct truecolor fg/bg and glyph | 250,717 |

Hashes (`shasum -a 256`): `out/demo-light.svg` `4ceaa0c6d8b280003cf4642a3ac4475c6d5db4573e4cc6112499c244ae182683` (identical on re-render); `out/demo-dark.svg` `670a528d1e6588d2cc4ced6e466353dc97a85199911d5af318a3bca81e99aafe`.

## Findings

1. **Snapshots lose cell width.** `ScreenSnapshot` has no width or continuation marker. The Ghostty adapter writes a wide grapheme's spacer as `" "` (`currentCellCharacter` returns a space for zero-length graphemes), so a real space and a spacer look identical. The renderer therefore guesses width from code point ranges. Probing Ghostty directly showed that `❤️` (U+2764 U+FE0F) is one cell in this libghostty-vt build (`ae52f97`), so a VS16 rule would be wrong. **Recommendation:** add `RenderedCell.width` (or a continuation case) to the snapshot, filled from Ghostty's wide flag. `TesseraTerminalBuffer`'s `Cell.Content.continuation` already models this, but the snapshot drops it. `terminalCellWidth` (DisplayWidth-based, package-level) should not be made public as a shortcut: Ghostty, not DisplayWidth, is the golden.
2. **Spacer skipping is gated on a blank next cell.** A misclassified narrow grapheme then shifts its row by one cell rather than deleting a real character. Test coverage: `keeps a narrow neighbour when a grapheme is not followed by a blank`.
3. **Size scales with style changes, not cells.** Each style change starts a new `<text>`, and each cell costs one `x` list entry. Dense screens reach 250 KB. Not measured, but the likely fixes are theme colors as a `<style>` block with classes (so the body is the same in both themes, which also makes "palette values only" structural) and one `<text>` per row with `<tspan>` per style change. Either should be tried before the plan's 100 KB budget is applied to arbitrary screens.
4. **`RenderedColor` is in `TesseraTerminalSnapshotSupport/RenderedColor.swift`**, not `TesseraTerminalANSI`. `UnderlineStyle` and `Color` are in ANSI. The plan's read pointer should be corrected.
5. **`TesseraTerminal` re-exports `TesseraTerminalANSI`, `Core`, and the rest.** A spike needs only `TesseraTerminal` and `TesseraTerminalSnapshotSupport` products. Path dependencies take their identity from the directory name (`devtools` at the time) unless the manifest sets one; the port to main (plan 035 Step 3.2) uses `.package(name: "tessera", path: "../..")`.
6. **Plan 033 Spike 3 wording.** Pass criteria call for "rects + text runs". The spike shows that rectangles for backgrounds and decorations plus per-glyph `x` is enough. `textLength` is only used on standalone glyphs (wide or multi-scalar graphemes), to force their span.

## Caveats (rendering)

- **Font coverage.** Menlo lacks several box glyphs (heavy `┏━┓┗━┛`, mixed `╞═╡`, `╟─╢`), so rsvg falls back to other faces. Those shapes look off in the zoom while staying on the grid. Single and double box edges connect at the 20-unit row pitch, but 1-unit gaps show at some row seams in the rasteriser.
- **Emoji.** Emoji such as 🙂 and ✅ rasterise as monochrome fallback glyphs, and `❤️` overhangs its cell. Color emoji need a color font; no SVG-level fix is claimed.
- **Underline styles.** Curly, dashed, and dotted are drawn as single lines. Double is two lines.
- **Hyperlinks** (`hyperlinkURI`) are not emitted. **Kitty images** are not in `ScreenSnapshot` and are not drawn.
- **Not in the spike:** shot-file "write only when bytes differ" (plan 033 "Shots"), PNG output, and the Linux cross-check.
