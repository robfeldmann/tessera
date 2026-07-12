# AGENTS.md

- Be concise; load only the context needed for the task.
- Prefer local project files and tool help before web searches.
- Use `pnpm`/`pnpx` for Node tooling.
- Local references before web searches:
  - Ratatui: `~/Developer/ratatui/ratatui/main/`
  - Ratatui crossterm backend: `~/Developer/ratatui/ratatui/main/ratatui-crossterm/`
  - Crossterm sources:
    `~/.local/share/cargo/registry/src/index.crates.io-1949cf8c6b5b557f/crossterm-0.29.0/`
- Swift Testing tests should use backticked, sentence-style function names.
- Prefer snapshots for structured state humans inspect as a whole; prefer direct
  assertions for small scalar/API-shape behavior.
- Sort protocol conformances alphabetically, e.g. `Equatable, Sendable`.
- Confine platform divergence (`#if os(...)`) to leaf seams: a single syscall/import shim,
  small typed platform values, or whole-file `sources:` splits in `Package.swift`. Keep
  shared logic and call sites platform-free instead of wrapping file bodies in `#if`.
- After code changes, run the narrowest relevant validation first, e.g.
  `swift test --filter <TargetOrTestName>` or `swift build`.
- During iteration, run focused checks (`swift test --filter ...`,
  `just quality changed`).
- Before handing work off for review or committing, run this gate in order and make every
  step pass. It is required, not optional — never hand off or commit on the strength of
  focused checks alone:
  1. `just quality format` to auto-apply formatting fixes (swift-format, SwiftLint
     `--fix`, Prettier, JSON key sort). Prefer this over hand-fixing individual lint
     findings. It is repo-wide and mutating; committing everything it touches is fine,
     including formatter-only changes unrelated to your work.
  2. The complete `swift test` suite.
  3. `just quality lint` (strict formatting and linting, including Markdown).
- Pull request titles must use conventional commit style.
- After editing Markdown, validate with:

  ```fish
  pnpx markdownlint-cli <path>
  ```

- Commit only after validation passes, unless explicitly asked otherwise.
