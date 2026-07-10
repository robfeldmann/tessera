---
name: Apple Terminal Underline Extension Corruption
date: 2026-07-09
status: resolved
---

# Apple Terminal Underline Extension Corruption

## Question

Why do semantic underline variants and underline colors corrupt text in Apple's
Terminal.app, and where should Tessera degrade them safely?

## Findings

- Terminal.app 2.15 (build 470.2) renders Tessera's `CSI 4:2 m` through `CSI 4:5 m` output
  as solid ANSI backgrounds matching SGR 42 through 45. The observed result is consistent
  with Terminal.app dropping the colon and interpreting `4:2` as `42`, `4:3` as `43`, and
  so on. The visual behavior is confirmed; the parser implementation is an inference
  because Terminal.app is closed source.
- SGR 58 underline-color output can additionally trigger blinking or concealed/illegible
  text in Terminal.app. Therefore the Slice 11 assumption that unsupported terminals
  harmlessly ignore underline extensions is false.
- Ordinary underline SGR 4 and underline-off SGR 24 render safely in Terminal.app.
- Tessera currently emits underline extensions in `StyleEncoding`: semantic styles reach
  `ControlSequence.setUnderlineStyle`, while underline colors reach
  `ControlSequence.setUnderlineColor`. Existing color-depth degradation does not suppress
  the extended underline grammar.
- There is no standard active underline-support probe in Tessera. Existing active probes
  cover Kitty keyboard/graphics and DEC private modes, not SGR underline variants or SGR
  58/59.
- `TERM_PROGRAM=Apple_Terminal` already maps to `TerminalIdentityKind.appleTerminal`.
  Identity is advisory and may be inherited or spoofed, but it is the available hint for a
  narrow known-bad output workaround.
- Local `Apple_Terminal` and `xterm-256color` terminfo entries advertise only ordinary
  `smul`/`rmul`; the local Ghostty entry advertises `Smulx` and `Setulc`. Newer ncurses
  sources can advertise `Smulx` for Apple Terminal despite the observed corruption, so
  terminfo alone is not reliable evidence for this bug.
- Raw semantic `ControlSequence` encoding must remain exact. The compatibility seam
  belongs in renderer style resolution, where both old and new styles can be projected
  before diffing.

## Ratatui comparison

- Ratatui's core renderer and Crossterm backend do not maintain a terminal-emulator quirk
  table. `CrosstermBackend::draw` emits `SetUnderlineColor` whenever the requested cell
  color changes; it does not inspect `TERM_PROGRAM` or the emulator identity.
- Underline color is a compile-time feature rather than a runtime capability decision. It
  is enabled by default in both the top-level `ratatui` crate and `ratatui-crossterm`.
- Ratatui's `Modifier` model represents underline as a boolean. Imports of double, curly,
  dotted, or dashed underline collapse to `Modifier::UNDERLINED`, so Ratatui itself does
  not emit `4:2` through `4:5` through the Crossterm backend.
- Crossterm does expose those variants directly and encodes them as `4:<n>` without a
  terminal-specific check. Applications using Crossterm attributes directly therefore
  retain the same compatibility risk.
- Ratatui's Termwiz backend delegates to `Capabilities::new_from_env`; Ratatui documents
  that Termwiz can fall back when a color is unsupported while Crossterm and Termion may
  produce unpredictable Terminal.app output.
- Ratatui does use emulator-specific handling at the application/example layer. Its flex
  example checks `TERM_PROGRAM=Apple_Terminal` and the terminal version to avoid truecolor
  on older Terminal.app releases. Ratatui therefore avoids a core emulator quirk table,
  but does not prohibit narrow known-terminal workarounds.

## Runtime probe proposal

- The reported Terminal.app failure was produced by the semicolon underline-color forms
  `58;5;n` and `58;2;r;g;b` that Tessera originally emitted, so the choice of SGR 58
  delimiter is part of this bug, not incidental to it.
- Vim issue 6687 documents the same failure mode on unsupported parsers: semicolon SGR
  `58;5` can be interpreted as separate SGR `58` and SGR `5`, enabling blink, while `58;2`
  can apply dim. That issue recommends the colon form because unsupported parsers are more
  likely to ignore the grouped subparameters safely.
- DECRQSS can query current SGR state, but the request is `DCS $ q m ST`; it does not take
  an arbitrary SGR value as its request body. A probe would first set a candidate SGR,
  request `m`, reset immediately, and inspect the `DCS 1 $ r ... m ST` response.
- Such a probe can reveal parser state where DECRQSS is implemented, but support is not
  widespread and multiplexers may swallow it. Terminfo.dev reports that Terminal.app does
  not support DECRQSS or XTVERSION, so neither can be the primary detection mechanism for
  the terminal exhibiting this bug.
- Terminfo.dev claims Terminal.app supports semicolon SGR 58 and `4:3` through `4:5`, but
  does not identify the tested Terminal.app version or build. Those results conflict with
  the directly observed Terminal.app 2.15 build 470.2 behavior.
- An isolated manual test on Terminal.app 2.15 build 470.2 used ordinary SGR `4` for every
  row and varied only the SGR 58 grammar. All text remained visible, but indexed semicolon
  `58;5` blinked and RGB semicolon `58;2` changed the foreground to purple. Neither colon
  form produced an independently colored underline; the underline always matched the text.
  The colon forms therefore degraded safely on this build but did not provide underline
  color, while both semicolon forms were unsafe.

- Style variants and underline color are independent output-policy fields. Tessera now
  exposes `.extended` (preserve variants and emit color) and `.baseline` (single-only and
  omit color) presets plus custom combinations. The application owns this policy, extended
  output is the default, and terminal identity does not change it. DECRQSS remains a
  possible future signal rather than part of the current policy.
- Following the manual test and the Vim issue, Tessera switched its emitted underline
  color grammar to the colon subparameter forms `58:5:n` and `58:2::r:g:b` (the double
  colon is the empty colorspace subparameter). Ghostty's own terminfo `Setulc`, herdr's
  XTGETTCAP reply, and mintty use or require the colon form, and parsers that predate SGR
  58 skip an unrecognized colon group wholesale instead of misapplying blink or dim. The
  worst case for the colon form is a missing underline color; the worst case for the
  semicolon form is visible corruption. SGR `59` remains the reset.

## Conclusion

Keep the renderer policy seam and exact low-level semantic encoders. The implemented
`UnderlineRenderingPolicy` splits style handling from color emission, defaults application
sessions to `.extended`, and provides `.baseline` for output paths limited to ordinary
underline. Underline colors are emitted with colon subparameters so parsers without SGR 58
support degrade by ignoring the sequence rather than corrupting text; the `4:x` style
variants have no safer spelling, which is what `.baseline` is for. Terminal identity is
diagnostic only; there is no Apple-specific rendering branch. DECRQSS may be considered
later as an optional signal, but it is not required for the explicit application policy.
