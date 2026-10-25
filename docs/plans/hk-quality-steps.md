---
type: plan
stage: planned
created: 2026-10-25
order: 39
description: Replace the hand-written changed-file and pre-commit quality scripts with hk steps that the hook, `hk check`, and the full gate in CI share, so commits work from any shell.
---

# Run the file-level quality checks as hk steps

Goal: each file-level check (swift-format, SwiftLint, Prettier, rumdl, codespell, DocC) is declared once, as an hk step with a file glob, and the pre-commit hook, `hk check` during iteration, and the full gate (`hk check --all`, in CI too) all run those steps. A commit made from a shell where mise is not activated (an agent harness such as T3 Code, a GUI Git client) passes the same checks as one made from an activated shell, because the checks run in the checkout against its trusted `mise.toml`. `scripts/pre-commit-lint-staged.sh`, `scripts/lint-changed.sh`, `scripts/quality-files.sh`, and `mise run quality:changed` are gone.

## Progress

- [ ] 1 hk steps for the file-level checks, and the pre-commit hook runs them
- [ ] 2 The full gate and local iteration run the same steps; the old scripts and `quality:changed` go
- [ ] 3 Docs and conventions follow

Next: start slice 1.

## Approach

**Today.** Three paths pick files and run the checks, sharing the bash classifier in `scripts/quality-files.sh`:

| Path | Entry | Files |
| --- | --- | --- |
| Pre-commit | `hk.pkl` `staged-quality` → `scripts/pre-commit-lint-staged.sh` | staged, in a temporary copy of the index |
| Local iteration | `mise run quality:changed` → `scripts/lint-changed.sh` | working tree changes and untracked files, or `--staged` |
| Full gate (CI and on demand) | `mise run quality:lint` → the `quality:*` tasks | every file |

The pre-commit script copies the index to `mktemp -d` and runs there. That copy predates hk: Lefthook did not stash, so the copy was how a check saw only staged content. hk's `pre-commit` hook already has `stash = "git"`, so the copy is now redundant, and it is what breaks commits from a shell without mise activated. hk's hook appends mise's shims to `PATH`; a shim run from the copy loads the copy's `mise.toml`, which mise has never trusted, and fails (`Config files in …/tessera-pre-commit.XXXXXX/mise.toml are not trusted`). Reproduced on 2026-10-25 with a shim-only `PATH`; `mise exec` does not fail the same way because it trusts its active config automatically.

**End state.** `hk.pkl` declares one step per check, each with a glob, `check`, and where the tool has one `fix`, built from the classifier's rules:

- `swift-format` and `swiftlint` on `**/*.swift`, through `scripts/swift-format.sh` (the selected Xcode's swift-format) and the pinned SwiftLint with `--strict`.
- `prettier` on YAML and JSON through `node_modules/.bin/prettier`, excluding `package-lock.json`.
- `rumdl` on `**/*.md` excluding `**/*.docc/**`.
- `codespell` on Swift, Markdown (including DocC), JSON, YAML, and Python, excluding `package-lock.json`.
- `docc` on `**/*.docc/**`, macOS only, running `mise run docs:lint` once rather than per file.

The `pre-commit` hook keeps `fix = false` and `stash = "git"` and runs these steps on staged files; `mise run setup:hooks` sets its command to `mise x -- hk run pre-commit --from-hook`, as Ternbook's bootstrap does, keeping the `git-ita-lift` wrapper. During iteration, `hk check` checks changed files and `hk check --staged` the staged ones; `quality:changed` is removed. The full gate runs the file-level steps with `hk check --all` in place of `quality:swift-format`, `quality:swiftlint`, `quality:spelling`, and the rumdl and Prettier half of `quality:markdown`, and `quality:format` becomes `hk fix --all`. `mise run quality:lint`, which CI runs, keeps the repository-wide checks (wireframes, architecture, plans hub, release notes, vouch, taplo) as `quality:*` tasks and runs `hk check --all` beside them.

**Patterns to follow.** Ternbook's `hk.pkl`: one `local` Step per tool, a `repositorySteps` mapping shared by the `check`, `fix`, and `pre-commit` hooks, and a hook command that runs `mise x -- hk run pre-commit` so tools resolve from the checkout. The owner's `git-ita-lift` wrapper for intent-to-add files (the uncommitted `mise-tasks/setup/hooks` change) stays.

**Patterns to avoid.** Temporary copies of the tree; per-file DocC builds; a second list of globs in bash; changing what any check enforces (this plan moves checks, it does not loosen or add rules).

**Files that orient a newcomer.** `hk.pkl`, `scripts/pre-commit-lint-staged.sh`, `scripts/lint-changed.sh`, `scripts/quality-files.sh`, `scripts/check-markup.sh`, `scripts/swift-format.sh`, `mise-tasks/quality/`, `mise-tasks/setup/hooks`, `.github/workflows/ci.yml` (the `quality:lint` step), `CONTRIBUTING.md`, `AGENTS.md`. Ternbook's `hk.pkl` and `bootstrap` for the target shape.

**Non-goals.** Changing the rules any tool enforces; the repository-wide gates; the commit-msg hook; Xcode or toolchain selection.

## Slices

### 1 hk steps for the file-level checks, and the pre-commit hook runs them

Delivers: `hk.pkl` declares the steps in End state, and the `pre-commit` hook runs them on staged files in the checkout; `staged-quality` and `scripts/pre-commit-lint-staged.sh` are removed. Verify: with a staged Markdown file and a `PATH` that reaches tools only through mise's shims (`env -i HOME=$HOME PATH=/usr/bin:/bin:/opt/homebrew/bin:$HOME/.local/bin:$HOME/.local/share/mise/shims git commit`), the commit runs prettier, rumdl, and codespell and passes; a staged Swift file with a swift-format violation fails the commit; a file staged with an unstaged edit on top is checked as staged (the unstaged edit introduces a violation that does not fail the commit); an intent-to-add file does not break the stash.

### 2 The full gate and local iteration run the same steps; the old scripts and `quality:changed` go

Delivers: `mise run quality:lint` (and so CI) runs `hk check --all` plus the repository-wide tasks; `quality:format` runs `hk fix --all`; `quality:swift-format`, `quality:swiftlint`, `quality:spelling`, and `quality:changed` are removed and `quality:markdown` keeps only taplo; `scripts/lint-changed.sh` and `scripts/quality-files.sh` are deleted with no remaining references. Verify: a scratch violation of each kind (Swift format, SwiftLint, Markdown, YAML, spelling) is reported by `hk check` on the changed file, by `hk check --staged` once staged, and by `mise run quality:lint`; `mise run quality:lint` passes on a clean tree; CI's quality job is green on the pull request.

### 3 Docs and conventions follow

Delivers: `CONTRIBUTING.md`, `AGENTS.md`, `.agents/commands/phase-slice-workflow.md`, and `.agents/skills/windows-smoke-testing/SKILL.md` name `hk check` and `hk check --staged` where they named `quality:changed`, and describe the hk steps; `docs/architecture/developer-tooling.md` records where file-level checks are declared and why the hook runs in the checkout; `docs/log.md` has a dated line. Verify: `rg 'lint-changed|quality-files|pre-commit-lint-staged|quality:changed'` finds nothing outside this plan and older plans; `mise run quality:lint` passes.

## Acceptance

- [ ] A commit made with mise not activated (shim-only `PATH`) runs and passes the same file-level checks as one made from an activated Fish shell.
- [ ] Each file-level check is declared once, in `hk.pkl`, and the pre-commit hook, `hk check`, and the full gate in CI run it from there.
- [ ] No check enforces less than before: a scratch violation of each kind still fails the hook and the full gate.
- [ ] `scripts/pre-commit-lint-staged.sh`, `scripts/lint-changed.sh`, `scripts/quality-files.sh`, and `quality:changed` are deleted.

## Decisions

- 2026-10-25 Run the full gate's file-level checks through `hk check --all`, in CI as well (through `mise run quality:lint`), so `hk.pkl` is the only declaration of them. (owner)
- 2026-10-25 Remove `quality:changed`; docs and agent instructions name `hk check` and `hk check --staged` directly. (owner)
- 2026-10-25 `mise run setup:hooks` sets the pre-commit hook to `mise x -- hk run pre-commit --from-hook` (keeping `git-ita-lift`), as Ternbook's bootstrap does, so tools resolve from the checkout's `mise.toml` in any shell. (owner)

## Discoveries

- A commit from a T3 Code thread (Claude Code, `/bin/zsh` without mise activated) failed in `staged-quality` with `Config files in …/tessera-pre-commit.XXXXXX/mise.toml are not trusted`; `mise exec -- git commit` passed. The failing call is the `rumdl` mise shim run from the temporary copy; with the tools of the trusted checkout first on `PATH`, the same script passed — owner's inbox capture `tessera-pre-commit-rumdl-untrusted-temp-checkout`, reproduced with a shim-only `PATH`, 2026-10-25.
- Ternbook's hook (`mise x -- hk run pre-commit`, steps run in the checkout) passed its `rumdl` step with the same shim-only `PATH` — `hk check --step rumdl README.md`, 2026-10-25.

## Outcome

Written at close.
