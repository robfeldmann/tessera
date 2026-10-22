---
type: spec
description: "Slice 8: Color degradation baseline"
---

# Slice 8: Color degradation baseline

Slice 8 gives Tessera one consistent color policy across modern and conservative
terminals. The public style model continues to let callers describe the color they mean —
default terminal colors, named ANSI 16 colors, 256-color palette indexes, or 24-bit RGB —
while the renderer decides what is safe to emit for the active terminal capability.

This is renderer policy, not a new terminal mode. There is no enable sequence, no active
probe, and no lifecycle cleanup. `TerminalCapabilities.color` is the only input: passive
detection maps environment hints such as `COLORTERM=truecolor`, `TERM=xterm-256color`,
`TERM=dumb`, and `NO_COLOR` into a capability, and `TerminalSession.draw` passes that
capability into the damage renderer.

The fallback ladder is:

1. **Truecolor (`.truecolor`)** — render semantic RGB colors as 24-bit SGR (`38;2;r;g;b` /
   `48;2;r;g;b`). Existing indexed and named ANSI colors may stay in their narrower wire
   form because a truecolor terminal accepts them.
2. **256-color (`.indexed256`)** — render semantic RGB colors as the nearest xterm
   256-color palette index (`38;5;n` / `48;5;n`). Existing indexed colors stay indexed;
   named ANSI colors stay named ANSI SGR.
3. **ANSI 16 (`.ansi16`)** — render semantic RGB colors and high indexed colors as the
   nearest named `ANSIColor`. Indexed values `0...15` map directly to their 16-color ANSI
   equivalents. Existing named ANSI colors stay named.
4. **Unknown (`.unknown`)** — render as ANSI 16, not as no-color. Unknown means Tessera
   lacks a reliable local hint; it does not mean the terminal is incapable of basic ANSI
   color. This keeps warning/status/demo output readable on ordinary terminals while
   avoiding truecolor and 256-color sequences that are more likely to misrender.
5. **No color (`.noColor`)** — suppress foreground and background color sequences by
   resolving every non-default color to terminal default. This is selected for `NO_COLOR`
   and `TERM=dumb` style inputs. It does not disable non-color SGR attributes, hyperlinks,
   cursor movement, synchronized output, raw payloads, graphics cleanup, or the renderer's
   final reset.

Color capability precedence honors the `NO_COLOR` informal standard: a `NO_COLOR` or
`TERM=dumb` environment selects `.noColor` as a hard override that cannot be re-enabled;
otherwise an explicit application color override wins; otherwise passive detection
decides. Applications may set an explicit level because many truecolor terminals never
advertise `COLORTERM` and would otherwise land on the `.unknown` → ANSI 16 fallback.

Color degradation must happen at the SGR emission boundary, not when writing cells.
`Style` and `Buffer` continue to store the semantic color the caller requested.
`BufferDiff` should still treat a semantic color change as damage, even if the active
capability causes both old and new colors to resolve to the same fallback. The style
encoder then avoids redundant color SGR when the resolved foreground/background state is
unchanged.

The resolver should be pure and deterministic. RGB-to-256 conversion uses the xterm
256-color palette: the 6×6×6 cube (`16...231`) and grayscale ramp (`232...255`), with
nearest color chosen by squared distance in sRGB byte space and ties broken by the lower
palette index. RGB-to-ANSI 16 and indexed-to-ANSI 16 use canonical ANSI palette
approximations and the same deterministic nearest-color rule. Indexed `0...15` maps
directly to Tessera's named ANSI colors.

The ANSI 16 fallback approximates against the pinned xterm default 16-color palette
(`red cd0000`, `brightRed ff0000`, `blue 0000ee`, `brightBlue 5c5cff`, and so on). Because
real terminals theme these slots, the fallback is a deterministic best-effort hue match
against that reference table rather than a guarantee about on-screen pixels; it also
yields deliberate asymmetries such as `rgb(0,0,255)` resolving to `blue` rather than
`brightBlue`.

The implementation should reuse existing Tessera color surfaces rather than adding a
parallel style model:

- `Sources/TesseraTerminalANSI/Color.swift` and `ANSIColor.swift` own semantic color and
  SGR parameter generation.
- `TerminalCapabilities.color` remains the session-level advisory capability.
- `StyleEncoding.sgrDelta` and full-style encoding become capability-aware.
- `Renderer.encodeFrame` accepts a color capability and `TerminalSession.draw` supplies
  the resolved session color capability.

Ratatui and crossterm are useful references but not templates to copy verbatim. Ratatui
keeps semantic `Rgb`/`Indexed` colors and converts them at backend emission time;
crossterm honors `NO_COLOR` by suppressing color output and uses environment hints for
available color count. Tessera should borrow that posture while preserving its own
`TerminalCapabilities` model and existing ECMA-48 named-color SGR encoding.

Tests for this slice should cover:

- `NO_COLOR` winning over truecolor and 256-color environment hints.
- `TERM=dumb` producing `.noColor`.
- missing or unknown environment producing `.unknown`, and `.unknown` rendering through
  the ANSI 16 fallback.
- RGB foreground/background under `.truecolor`, `.indexed256`, `.ansi16`, `.unknown`, and
  `.noColor`.
- exact xterm 256-color mappings for representative RGB cube and grayscale values.
- exact ANSI 16 mappings for RGB primaries, grayscale samples, and indexed `0...15`.
- no-color rendering suppressing foreground/background SGR while preserving visible text
  and non-color attributes.
- adjacent cells whose semantic colors degrade to the same resolved color not emitting
  redundant color SGR.
- full repaint and damage repaint using the same resolver.
- composition with existing renderer features: hyperlinks can still open/close when color
  is disabled, raw payloads are not rewritten, synchronized output wrappers are unchanged,
  and final SGR reset remains.

Sixel, iTerm2 image escape sequences, and dithering are explicitly out of scope for this
slice. Palette querying, theme detection, and active color probes belong to Slice 6's
[terminal color reports](slice-06-terminal-capability-detection.md#terminal-color-reports),
and contrast correction to the view layer's role resolution
([docs/design/tokens.md](../../design/tokens.md#hue-guard)); this slice's downsampler
stays the emission-boundary policy.

## End of Slice 8

`TesseraTerminal` degrades color at render time from semantic app intent to the active
terminal capability, preserving readable text on conservative terminals while still using
truecolor when it is safe.
