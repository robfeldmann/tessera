# AGENTS.md

- Be concise; load only the context needed for the task.
- Prefer local project files and tool help before web searches.
- Node tooling is the repository's pinned npm setup (`npm ci`); tools come from `mise install` (`mise.toml`).
- Local references before web searches:
  - Ratatui: `~/Developer/ratatui/ratatui/main/`
  - Ratatui crossterm backend: `~/Developer/ratatui/ratatui/main/ratatui-crossterm/`
  - Crossterm sources: `~/.local/share/cargo/registry/src/index.crates.io-1949cf8c6b5b557f/crossterm-0.29.0/`
- Project memory is the IWE workspace in `docs/` (`docs/index.md` maps it): `plans/` (one plan per piece of work; `docs/plans.md` is rendered from their frontmatter by `scripts/plans.py`), `research/` (research records), `architecture/` (durable decisions), `design/` (the component catalog), `spec/` (the spec, one page per section, hub `docs/spec.md`), and `guides/` (contributor how-tos). Search it at the start of a task and whenever unsure, from `docs/`: `iwe find --fuzzy <terms> --lexical <terms>`, then `iwe retrieve -k <key>` (`iwe` comes from `mise install`; run it as `mise exec -- iwe` when mise is not activated, and without it fall back to `docs/index.md`, the hub pages, and `grep` over `docs/`, which hold the same content as plain Markdown). Record what you learn where it belongs as part of the change (a plan's Progress, Decisions, or Discoveries; a research record; an architecture page), and fix stale entries you find.
- Plans and research records follow the `planning` and `investigations` skills in `.agents/skills/`; the design catalog follows `design-catalog`; driving and checking a Tessera app with the `tessera` command line follows the `tessera` skill, and running, launching, and snapshot-testing Tessera's own demos follows `tessera-contributing`, which extends it. Slash commands for the recurring workflows live in `.agents/commands/`.
- Markdown prose is one paragraph per line (no hard wrapping); relative `.md` links; no raw HTML. Swift code keeps the formatter's 90-column width.
- Swift Testing tests should use backticked, sentence-style function names.
- Prefer snapshots for structured state humans inspect as a whole; prefer direct assertions for small scalar/API-shape behavior.
- Sort protocol conformances alphabetically, e.g. `Equatable, Sendable`.
- Confine platform divergence (`#if os(...)`) to leaf seams: a single syscall/import shim, small typed platform values, or whole-file `sources:` splits in `Package.swift`. Keep shared logic and call sites platform-free instead of wrapping file bodies in `#if`.
- After code changes, run the narrowest relevant validation first, e.g. `swift test --filter <TargetOrTestName>` or `swift build`.
- During iteration, run focused checks (`swift test --filter ...`; `hk check` for the file-level checks on changed files and `hk check --staged` on staged ones, as `mise exec -- hk check` when mise is not activated). The checks are hk steps declared in `hk.pkl`, which the pre-commit hook and `mise run quality:lint` run too.
- Before handing work off for review or committing, run this gate in order and make every step pass. It is required, not optional — never hand off or commit on the strength of focused checks alone:
  1. `mise run quality:format` to auto-apply fixes (`hk fix --all`: SwiftLint `--fix`, swift-format, Prettier for YAML and JSON, `rumdl check --fix` for Markdown, codespell's corrections). Prefer this over hand-fixing individual lint findings. It is repo-wide and mutating; committing everything it touches is fine, including formatter-only changes unrelated to your work.
  2. The complete `swift test` suite, through `mise run core:test` (or `swift test --only-use-versions-from-resolved-file`), so Swift 6.3 does not rewrite the Swift 6.4 `Package.resolved`; discard any `Package.resolved` change a plain SwiftPM command makes.
  3. `mise run quality:lint` (`hk check --all` without its DocC step, plus the repository-wide checks: strict formatting and linting, including Markdown and spelling).
  4. `mise run docs:lint` (macOS only) when the change touches `.docc` files or public API doc comments; `quality:lint` does not build DocC, and CI's Documentation workflow does.
- Pull request titles must use conventional commit style.
- After editing Markdown, validate with the hk `rumdl` step (rumdl is pinned in `mise.toml`):

  ```fish
  mise exec -- hk check <path>
  ```

- Commit only after validation passes, unless explicitly asked otherwise.
