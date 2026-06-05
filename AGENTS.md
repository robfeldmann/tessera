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
- Sort protocol conformances alphabetically, e.g. `Equatable, Sendable`.
- After code changes, run the narrowest relevant validation first, e.g.
  `swift test --filter <TargetOrTestName>` or `swift build`.
- Before committing, run `just lint`.
- After editing Markdown, validate with:

  ```fish
  pnpx markdownlint-cli <path>
  ```

- Commit only after validation passes, unless explicitly asked otherwise.
