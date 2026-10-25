---
type: plan
stage: done
created: 2026-10-25
completed: 2026-10-25
order: 39
description: Replace the hand-written changed-file and pre-commit quality scripts with hk steps that the hook, `hk check`, and the full gate in CI share, so commits work from any shell.
---

# Run the file-level quality checks as hk steps

Goal: each file-level check (swift-format, SwiftLint, Prettier, rumdl, codespell, DocC) is declared once, as an hk step with a file glob, and the pre-commit hook, `hk check` during iteration, and the full gate (`hk check --all`, in CI too) all run those steps. A commit made from a shell where mise is not activated (an agent harness such as T3 Code, a GUI Git client) passes the same checks as one made from an activated shell, because the checks run in the checkout against its trusted `mise.toml`. `scripts/pre-commit-lint-staged.sh`, `scripts/lint-changed.sh`, `scripts/quality-files.sh`, and `mise run quality:changed` are gone.

## Progress

- [x] 1 hk steps for the file-level checks, and the pre-commit hook runs them - `7a07779`; `mise run setup:hooks` sets `PATH="$HOME/.local/bin:$PATH" git-ita-lift mise x -- hk run pre-commit --from-hook`; `hk check --all --skip-step docc` passes on the tree (2 s). Scratch commits made with `env -i HOME=$HOME PATH=/usr/bin:/bin:/opt/homebrew/bin:$HOME/.local/bin:$HOME/.local/share/mise/shims git commit` and dropped with `git reset`: a staged Markdown and YAML file ran rumdl, prettier, and codespell and passed, and the same three ran from `fish -c 'mise activate fish | source; git commit'`; a staged Swift file with spacing findings failed on swift-format (`[Spacing] remove 1 space`, exit 1); a file staged clean under an unstaged violating edit committed, and the edit was back in the working tree after; an intent-to-add file beside another file's unstaged edit committed (stash of 2 files ran) and was still intent-to-add after; a staged `.docc` file ran `docs:lint` once and passed (44 s warm).
- [x] 2 The full gate and local iteration run the same steps; the old scripts and `quality:changed` go - `3f57b5d`; the five scratch violations (spacing for swift-format, a force unwrap for SwiftLint, an extra blank line in Markdown, a mis-indented YAML file, a misspelling), created as untracked files: `hk check --no-fail-fast` reported all five on the 9 changed files, `hk check --staged --no-fail-fast` reported all five once staged, and `mise run quality:lint` reported all five in one run (exit 1; `docc` passed beside them); `mise run quality:format` then fixed the four fixable ones in 2.6 s without a DocC build (SwiftLint's force-unwrap finding has no correction); with the scratch files removed `mise run quality:lint` passed (28 s, DocC included).
- [x] 3 Docs and conventions follow - `02116cb`; `rg 'lint-changed|quality-files|pre-commit-lint-staged|quality:changed'` lists only this plan and the two older plans above; `iwe schema validate` exits 0; `mise run quality:format` changed nothing, `mise run core:test` (850 tests) passed with no `Package.resolved` change, and `mise run quality:lint` passed.

Next: none: the plan is done. Reviewing and merging the pull request is the owner's.

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

- [x] A commit made with mise not activated (shim-only `PATH`) runs and passes the same file-level checks as one made from an activated Fish shell. Slice 1: the same staged Markdown and YAML files ran rumdl, prettier, and codespell and passed from `env -i … PATH=/usr/bin:/bin:/opt/homebrew/bin:$HOME/.local/bin:$HOME/.local/share/mise/shims git commit` and from `fish -c 'mise activate fish | source; git commit'`.
- [x] Each file-level check is declared once, in `hk.pkl`, and the pre-commit hook, `hk check`, and the full gate in CI run it from there. `hk.pkl` has the only declaration; `quality:lint` calls `hk check --all`, `quality:format` calls `hk fix --all`, and `rg` finds no other call of rumdl, Prettier, codespell, SwiftLint, or swift-format outside `hk.pkl`, `scripts/swift-format.sh` (the wrapper the steps call), and the pages that describe them.
- [x] No check enforces less than before: a scratch violation of each kind still fails the hook and the full gate. In shim-only commits, a swift-format finding, a SwiftLint force unwrap, an extra blank line in Markdown, a mis-indented YAML file, and a misspelling each exited 1 on `swift-format`, `swiftlint`, `rumdl`, `prettier`, and `codespell`; `mise run quality:lint` reported all five in one run.
- [x] `scripts/pre-commit-lint-staged.sh`, `scripts/lint-changed.sh`, `scripts/quality-files.sh`, and `quality:changed` are deleted. `3f57b5d` and `7a07779`; the `rg` sweep of slice 3 finds them only in this plan, `docs/plans/toolchain-conventions-and-plan-consolidation.md`, and `docs/plans/tooling-orchestration-and-lefthook.md`.

## Decisions

- 2026-10-25 Run the full gate's file-level checks through `hk check --all`, in CI as well (through `mise run quality:lint`), so `hk.pkl` is the only declaration of them. (owner)
- 2026-10-25 Remove `quality:changed`; docs and agent instructions name `hk check` and `hk check --staged` directly. (owner)
- 2026-10-25 `mise run setup:hooks` sets the pre-commit hook to `mise x -- hk run pre-commit --from-hook` (keeping `git-ita-lift`), as Ternbook's bootstrap does, so tools resolve from the checkout's `mise.toml` in any shell. (owner)
- 2026-10-25 The Swift steps cover what the Swift gates covered, not every `**/*.swift`: `Sources/**`, `Tests/**`, `Examples/Sources/**`, `Package.swift`, and `Examples/Package.swift`, so `hk check --all` passes on the tree and the hook enforces what the gate does (strict swift-format, as the gate was).
- 2026-10-25 The `prettier` step covers `.yaml`, `.yml`, `.json`, `.cjs`, `.js`, and `.css`, and excludes `package-lock.json`: everything `prettier --check .` formatted, so the full gate loses nothing.
- 2026-10-25 The `rumdl` step includes DocC Markdown, where the plan's End state excludes it: the full gate checked it and it passes, and Acceptance says no check enforces less.
- 2026-10-25 The `codespell` step globs every file (binary files are dropped by hk) except `package-lock.json`, the union of what `quality:spelling` and the classifier covered.
- 2026-10-25 `swift-format` depends on `swiftlint`, so a fix applies SwiftLint's corrections before swift-format settles the layout, as `quality:format` ordered them; checks run in sequence for the same reason.
- 2026-10-25 The `fix` hook runs every step but `docc`, and `codespell` has a `fix` (`--write-changes`), so `hk fix --all` also applies spelling corrections that `quality:spelling-fix` applied.
- 2026-10-25 The `docc` step runs `env -u SDKROOT mise run docs:lint`, so the SDK is the one `DEVELOPER_DIR` selects whichever Git launched the hook.
- 2026-10-25 `mise run quality:lint` runs `hk check --all --no-fail-fast`, so one run lists every failing step; the hook and `hk check` keep hk's stop-at-first-failure default.
- 2026-10-25 `scripts/check-markup.sh`, `scripts/format-markup.sh`, `scripts/rumdl.sh`, the `package.json` scripts that ran them, and `quality:spelling-fix` are deleted with the other tasks: with `quality:markdown` down to taplo, `quality:format` on `hk fix --all`, and codespell's fix in the step, nothing calls them, and keeping them would declare rumdl, Prettier, and codespell a second time. `docs/design.md`'s `npm run check:markup` became `hk check`.
- 2026-10-25 `hk check --all`, and so `quality:lint`, runs the `docc` step, as the Goal lists DocC among the checks the full gate runs; the cost is in the Outcome.

## Discoveries

- A commit from a T3 Code thread (Claude Code, `/bin/zsh` without mise activated) failed in `staged-quality` with `Config files in …/tessera-pre-commit.XXXXXX/mise.toml are not trusted`; `mise exec -- git commit` passed. The failing call is the `rumdl` mise shim run from the temporary copy; with the tools of the trusted checkout first on `PATH`, the same script passed — owner's inbox capture `tessera-pre-commit-rumdl-untrusted-temp-checkout`, reproduced with a shim-only `PATH`, 2026-10-25.
- Ternbook's hook (`mise x -- hk run pre-commit`, steps run in the checkout) passed its `rumdl` step with the same shim-only `PATH` — `hk check --step rumdl README.md`, 2026-10-25.
- The plan's Verify says a staged Markdown file runs prettier. It does not under the step globs: `.prettierignore` hands Markdown to rumdl, so the `prettier` step matches YAML, JSON, and script files only, and runs for a staged YAML file. The old hook never ran Prettier on anything but Markdown (the classifier passed `check-markup.sh` only `*.md` files, which Prettier skips), so a staged YAML or JSON file was only spell-checked; the new hook enforces more there, 2026-10-25.
- `**/*.swift` is wider than the Swift gates. `quality:swift-format` and `quality:swiftlint` cover `Sources`, `Tests`, `Package.swift`, `Examples/Sources`, and `Examples/Package.swift` (`.swiftlint.yml` `included`, which SwiftLint ignores for explicit file arguments). Strict swift-format and SwiftLint on the other 86 tracked Swift files report 133 and 201 findings in `spikes/` and 2 swift-format findings in `Examples/Tests`; `DevTools/` is clean. The old hook linted any staged Swift file, but with non-strict swift-format, which fails only on errors, so it checked less than the gate, 2026-10-25.
- `prettier --check .`, the full gate's Prettier call, also formats `.github/scripts/*.cjs`, `DevTools/gallery/gallery.js`, and `DevTools/gallery/gallery.css`, not only YAML and JSON, 2026-10-25.
- The full gate's `rumdl check .` covers the 37 DocC Markdown files, and they pass; the classifier left them out of the Markdown list, so the old hook never checked them with rumdl, 2026-10-25.
- `quality:spelling` covered every text file under `Sources`, `Tests`, `Examples`, `docs`, and `.github` (`.h`, `.svg`, `.txt`, `.scn`, `.cjs`, `.toml`, `.td`, and others), while the classifier named Swift, Markdown, JSON, YAML, and Python anywhere. Neither is the other's subset; codespell passes on every tracked file except `package-lock.json`, 2026-10-25.
- `hk fix` runs a step that has only a `check` as a check: a throwaway step with no `fix` ran its command under `hk fix --all`. The DocC step would have run `docs:lint` inside every `quality:format`, 2026-10-25.
- Apple's `/usr/bin/git`, first on the shim-only `PATH`, exports `SDKROOT` for the system-selected Xcode (27.1) to its hooks, while `mise.toml` selects 26.6 through `DEVELOPER_DIR`. A `.docc` file staged in a commit made that way failed `docs:lint` in the hook with `this SDK is not supported by the compiler`; the same step passed under `hk check --step docc --all`. Homebrew's git (first on `PATH` in an interactive shell) does not set it, 2026-10-25.
- Failing `hk check --all` stops at the first failing step by default (`fail_fast`), and the other steps report `aborted`; a gate that should list every failure needs `--no-fail-fast`, 2026-10-25.
- `vm:macos-check` runs `ci:check` and then `docs:lint` (`scripts/vm.py`), so with the `docc` step in `quality:lint` the macOS guest builds the DocC archives twice, 2026-10-25.
- `mise run docs:lint` takes 1 m 45 s on a worktree with no `.build` (Xcode 26.6, warm SwiftPM caches) and 44 s inside a commit on a warm one; `mise run quality:lint` takes 28 s on a warm tree, DocC included, 2026-10-25.

## Outcome

`hk.pkl` now declares the six file-level checks once, as `swiftlint`, `swift-format`, `prettier`, `rumdl`, `codespell`, and `docc` steps, and four things run them from there: the pre-commit hook on the staged files, `hk check` on the changed files, `hk check --staged` on the staged ones, and `mise run quality:lint` (`hk check --all --no-fail-fast`, beside the wireframe, architecture, plans hub, release notes, vouch, and TOML tasks) in CI. `mise run setup:hooks` sets the hook to `PATH="<mise dir>:$PATH" git-ita-lift mise x -- hk run pre-commit --from-hook`, so a commit from a shell without mise activated runs and passes the same steps in the checkout. `scripts/pre-commit-lint-staged.sh`, `scripts/lint-changed.sh`, `scripts/quality-files.sh`, `quality:changed`, `quality:swift-format`, `quality:swiftlint`, `quality:spelling`, `quality:spelling-fix`, `scripts/check-markup.sh`, `scripts/format-markup.sh`, `scripts/rumdl.sh`, and the `package.json` scripts that called them are gone; `quality:markdown` is taplo alone, and `quality:format` is `hk fix --all`.

Where this departs from the plan's text, by the Decisions above: the Swift steps cover the Swift gates' paths rather than every `**/*.swift`, the Prettier glob adds `.cjs`, `.js`, and `.css`, `rumdl` includes DocC Markdown, `codespell` takes every text file, and `docc` drops `SDKROOT`. Each keeps a check at least as strict as the one before it. For the owner to weigh: `quality:lint` now builds the DocC archives (the Goal lists DocC among the checks the full gate runs), so the `lint` job in CI and the guest in `vm:macos-check` each build them beside the Documentation workflow's and the task's own `docs:lint`; `--skip-step docc` on the `hk check --all` call in `mise-tasks/quality/lint` would take it out; and `quality:format` now applies spelling corrections, which `quality:spelling-fix` used to do on its own.
