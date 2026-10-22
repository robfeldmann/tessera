# AGENTS.md

- Be concise; load only the context needed for the task.
- Prefer local project files and tool help before web searches.
- Node tooling is the repository's pinned npm setup (`npm ci`); tools come from `mise install` (`mise.toml`).
- Local references before web searches:
  - Ratatui: `~/Developer/ratatui/ratatui/main/`
  - Ratatui crossterm backend: `~/Developer/ratatui/ratatui/main/ratatui-crossterm/`
  - Crossterm sources: `~/.local/share/cargo/registry/src/index.crates.io-1949cf8c6b5b557f/crossterm-0.29.0/`
- Project memory is the IWE workspace in `docs/` (`docs/index.md` maps it): `plans/` (one plan per piece of work; `docs/plans.md` is rendered from their frontmatter by `scripts/plans.py`), `research/` (research records), `architecture/` (durable decisions), `design/` (the component catalog), `spec/` (the spec, one page per section, hub `docs/spec.md`), and `guides/` (contributor how-tos). Search it at the start of a task and whenever unsure, from `docs/`: `iwe find --fuzzy <terms> --lexical <terms>`, then `iwe retrieve -k <key>` (`iwe` comes from `mise install`; run it as `mise exec -- iwe` when mise is not activated, and without it fall back to `docs/index.md`, the hub pages, and `grep` over `docs/`, which hold the same content as plain Markdown). Record what you learn where it belongs as part of the change (a plan's Progress, Decisions, or Discoveries; a research record; an architecture page), and fix stale entries you find.
- Plans and research records follow the `planning` and `investigations` skills in `.agents/skills/`; the design catalog follows `design-catalog`. Slash commands for the recurring workflows live in `.agents/commands/`.
- Markdown prose is one paragraph per line (no hard wrapping); relative `.md` links; no raw HTML. Swift code keeps the formatter's 90-column width.
- Swift Testing tests should use backticked, sentence-style function names.
- Prefer snapshots for structured state humans inspect as a whole; prefer direct assertions for small scalar/API-shape behavior.
- Sort protocol conformances alphabetically, e.g. `Equatable, Sendable`.
- Confine platform divergence (`#if os(...)`) to leaf seams: a single syscall/import shim, small typed platform values, or whole-file `sources:` splits in `Package.swift`. Keep shared logic and call sites platform-free instead of wrapping file bodies in `#if`.
- After code changes, run the narrowest relevant validation first, e.g. `swift test --filter <TargetOrTestName>` or `swift build`.
- During iteration, run focused checks (`swift test --filter ...`, `mise run quality:changed`).
- Before handing work off for review or committing, run this gate in order and make every step pass. It is required, not optional — never hand off or commit on the strength of focused checks alone:
  1. `mise run quality:format` to auto-apply formatting fixes (swift-format, SwiftLint `--fix`, Prettier for YAML and JSON, `rumdl check --fix` for Markdown). Prefer this over hand-fixing individual lint findings. It is repo-wide and mutating; committing everything it touches is fine, including formatter-only changes unrelated to your work.
  2. The complete `swift test` suite.
  3. `mise run quality:lint` (strict formatting and linting, including Markdown).
- Pull request titles must use conventional commit style.
- After editing Markdown, validate with rumdl (pinned in `mise.toml`):

  ```fish
  mise exec -- rumdl check <path>
  ```

- Commit only after validation passes, unless explicitly asked otherwise.
