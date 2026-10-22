---
name: Coding Harness Colored Underline Usage
date: 2026-07-09
status: resolved
---

# Coding Harness Colored Underline Usage

## Question

Do current OpenCode, OpenAI Codex CLI, or Claude Code terminal UIs render independently
colored underlines using SGR 58/59 or an equivalent underline-color API?

## Findings

### OpenCode

- Upstream `anomalyco/opencode` revision `a0b90640761aa89a303c6b5b0d74ef3e6b945652`,
  package version `1.17.18`, uses ordinary underline styling in
  `packages/tui/src/theme/index.ts` for level-one headings, links and URLs, special URLs,
  and `markup.underline`.
- Those rules pair `underline: true` with a foreground color; they do not assign an
  independent underline color.
- OpenCode's OpenTUI dependency, revision `13b9e55c`, defines ordinary SGR 4 in
  `packages/core/src/zig/ansi.zig` and emits it for the `UNDERLINE` attribute. Its color
  emitters cover foreground/background SGR 38/48 and resets 39/49. No SGR 58/59 or
  underline-color API was found.

### OpenAI Codex CLI

- Upstream `openai/codex` revision `ac3da4fb1a2ad0ee2f0c867bfa81a5a3a3737f9c` uses
  ordinary `.underlined()` and `Modifier::UNDERLINED` styling in markdown headings and
  links, onboarding and update links, notices, status cards, the pull-request status-line
  item, MCP and plugin views, feedback views, and other link-like UI.
- `codex-rs/tui/src/terminal_hyperlinks.rs` identifies some links by the combination of
  cyan foreground and `Modifier::UNDERLINED`. That can produce a cyan-looking underline
  because ordinary underline normally follows the text foreground; it is not independent
  underline color.
- No Codex TUI call site for `Style::underline_color`, `SetUnderlineColor`, or raw SGR
  58/59 was found. The sole `underline_color` search result is a snapshot assertion that a
  style field is reset, not a colored-underline feature.
- Codex uses Ratatui `0.29.0` and Crossterm `0.28.1`. Ratatui's default feature set
  includes `underline-color`, and its style/backend layer supports SGR 58/59. The
  dependency stack is capable even though current Codex UI code does not use the
  capability.

### Claude Code

- Installed Claude Code is `2.1.204`, a closed native arm64 binary at
  `/opt/homebrew/Caskroom/claude-code@latest/2.1.204/claude`.
- Printable strings contain a weak ordinary-underline signal (`[4m`) in a long
  minified/concatenated record, but it cannot be attributed confidently to a live Claude
  Code view.
- Targeted printable-string searches found no `underline`, `undercurl`, `guisp`,
  `SetUnderlineColor`, `underline_color`, or explicit SGR 58/59 evidence.
- Because the binary is closed, minified, and may construct escape bytes numerically, this
  establishes no evidence of independently colored underline rather than proving absence.

## Conclusion

No current, source-verifiable independently colored underline use was found in these three
harnesses. OpenCode and Codex definitely use ordinary underlines, often with colored
foreground text; Codex's dependency stack can represent and emit independent underline
color but Codex does not currently invoke it. Claude Code remains uncertain, with only
weak ordinary-underline evidence.

A herdr issue should not claim that these harnesses currently depend on SGR 58/59. The
stronger honest impact is compatibility with terminal editors and diagnostics such as
Neovim, plus preservation of harmless terminal state already parsed by herdr's embedded
Ghostty core. Harness-adjacent context can accurately note that Codex's Ratatui/Crossterm
stack already exposes the capability, so future use would require no new renderer
primitive on Codex's side.
