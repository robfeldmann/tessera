---
name: Tooling orchestration and Lefthook migration
description:
  Unify formatter ownership, deterministic quality gates, hook management, and CI around
  repository-managed commands.
status: pending
created: 2026-07-17
updated: 2026-07-17
---

<!-- Allowed status values: planning, in-review, pending, in-progress, complete. -->

## Progress

- [x] **Phase 1 — Establish policy and reproducible dependencies**
  - [x] 1.1 Add repository-managed JavaScript tooling
  - [x] 1.2 Add repository-managed spelling checks
  - [x] 1.3 Resolve formatter and linter ownership
- [x] **Phase 2 — Consolidate quality orchestration**
  - [x] 2.1 Make full-repository checks deterministic
  - [x] 2.2 Harden changed-file validation
- [x] **Phase 3 — Replace hook management with Lefthook**
  - [x] 3.1 Make repository commit policy canonical
  - [x] 3.2 Install and document Lefthook hooks
- [x] **Phase 4 — Align CI and documentation**
  - [x] 4.1 Make workflows call canonical quality gates
  - [x] 4.2 Publish the contributor workflow
- [ ] **Phase 5 — Normalize and verify the migration**
  - [x] 5.1 Apply one isolated formatting baseline
  - [ ] 5.2 Exercise all local and CI-equivalent gates

## Overview

Keep `swift-format` as the sole Swift layout formatter and retain SwiftLint for
non-overlapping semantic policy. Make Prettier the formatter for ordinary Markdown and
JSON/YAML configuration, and make markdownlint a structural Markdown check configured not
to fight Prettier; DocC remains excluded from prose formatting and is validated by the
macOS DocC compiler with warnings treated as errors.

Adopt Lefthook. The current `pre-commit` setup already has a correct non-mutating staged
snapshot check, but it duplicates commit-message policy with the repository's CI validator
and adds a separate hook framework plus Python environment. Lefthook provides one
committed configuration for both hook stages, while the repository's
`scripts/conventional_commits.py` becomes the single Conventional Commit authority. This
is a hook-manager simplification, not a claim of Windows-native SwiftLint support: the
hook's shell, Swift, and Node prerequisites remain explicit.

The target contract is: pinned project-local npm and Python tooling own JavaScript and
spelling checks; `just quality format` fixes; `just quality lint` checks portable policy
and fails closed; `just docs lint` checks DocC separately on macOS; Lefthook checks the
staged index without modifying it; and CI invokes those same repository commands after
provisioning dependencies.

## Decision record

| Area               | Decision                                                                              | Rationale                                                                                                                                                                            |
| ------------------ | ------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Swift layout       | Keep `swift-format`                                                                   | It is already configured in `.swift-format` and the SwiftLint configuration explicitly defers brace, comma, and multiline layout to it.                                              |
| SwiftLint          | Keep semantic rules only; run autocorrection before `swift-format`                    | The current `quality format` order leaves SwiftLint as the final mutator, and several active rules are layout-adjacent. The formatter must make the final layout decision.           |
| Markdown           | Prettier formats; markdownlint checks structure using its Prettier-compatible style   | `.markdownlint.json` exists but is omitted from the full gate, while the current rules can overlap Prettier's 90-column wrapping policy.                                             |
| DocC prose         | Do not run Prettier or markdownlint inside `.docc` bundles                            | `.prettierignore` already excludes it; DocC markup/reference validation belongs to the existing `just docs lint` macOS job.                                                          |
| JSON               | Remove broad `jq --sort-keys` mutation; let scoped Prettier format ordinary JSON/YAML | Recursively sorting every JSON file is a second formatter and can alter generated or lock-file semantics.                                                                            |
| JavaScript tooling | Use local npm development dependencies and committed `package-lock.json`              | npm ships with Node, so it asks less of Swift contributors than pnpm/Corepack while retaining reproducible project-local formatter and linter versions.                              |
| Spelling           | Add repository-pinned `codespell` as a check-only quality tool                        | It catches prose and identifier misspellings without allowing an automatic hook edit to silently alter source.                                                                       |
| Hooks              | Replace `pre-commit` with Lefthook                                                    | A committed `lefthook.yml` can manage both existing stages without the external commit-message policy. Retain the staged-index snapshot strategy and do not use auto-stage behavior. |
| CI                 | Separate portable quality from macOS-only DocC generation                             | `just quality lint` currently reaches a Ghostty build, network/cache state, and `xcrun docc`; that is unsuitable as a generic fast quality gate.                                     |

## Phase 1 — Establish policy and reproducible dependencies

**Goal**: give each file class exactly one layout formatter and make every mandatory tool
versioned, installable, and available to all commands that need it.

### Step 1.1 — Add repository-managed JavaScript tooling

- Files: create `package.json` and `package-lock.json`; update `Brewfile`, relevant GitHub
  workflow setup, and `CONTRIBUTING.md`.
- Add pinned development dependencies for Prettier and `markdownlint-cli2`. Define npm
  scripts for scoped markup formatting and checks so Just and staged-file scripts resolve
  `node_modules/.bin` rather than global binaries. Commit the lockfile; use `npm ci` in CI
  and remove `pnpx` downloads and global-Prettier assumptions.
- Declare the supported Node version in repository metadata and provision Node where the
  portable quality gate runs. Make `Brewfile` install Node for macOS bootstrap, remove its
  global Prettier formula, and keep VM provisioning optional rather than making it a
  prerequisite for formatting and linting.
- Acceptance: a clean checkout can install the same JavaScript tool versions locally and
  in CI; missing required tools fail with an actionable nonzero error instead of a warning
  and successful exit.

### Step 1.2 — Add repository-managed spelling checks

- Files: create a pinned Python quality-tool requirements file and `.codespellrc`; update
  `.gitignore`, `justfiles/setup.just`, `justfiles/quality.just`, relevant staged-file
  scripts, GitHub workflow setup, and `CONTRIBUTING.md`.
- Pin `codespell` in the repository's Python quality requirements. Add one setup recipe
  that creates an ignored local virtual environment from the existing Python 3
  prerequisite and installs those requirements; all recipes and hooks must invoke the
  virtual environment's `python -m codespell_lib`, never a global executable. Keep
  `Brewfile` responsible only for bootstrapping Python, not for selecting the `codespell`
  version.
- Configure codespell to scan maintained Swift, Markdown, DocC, and configuration content
  while excluding `.git`, `.build`, `node_modules`, vendored `Packages`, generated
  artifacts, and binary fixtures. Add ignored words only after confirming an intentional
  project term; never suppress broad typo classes.
- Provide an explicit `just quality spelling-fix` helper for reviewed manual correction,
  but make `just quality spelling`, CI, and hooks check-only.
- Acceptance: a deliberate typo in a maintained source or documentation file fails the
  spelling check; known project terms pass through a minimal reviewed allowlist; no
  standard hook or quality check modifies a file.

### Step 1.3 — Resolve formatter and linter ownership

- Files: `.swift-format`, `.swiftlint.yml`, `.prettierrc.json`, `.markdownlint.json`,
  `.prettierignore`.
- Preserve the existing 91-column/two-space `swift-format` policy unless an explicit style
  decision changes it. Audit enabled/default SwiftLint rules and disable every rule whose
  output is purely whitespace, indentation, wrapping, punctuation placement, or line
  length; retain semantic and project-specific rules. Keep comments explaining any
  deliberate formatter/Linter incompatibilities.
- Configure markdownlint's documented Prettier-compatible style, then retain only project
  content/structure exceptions such as duplicate-heading and allowed-HTML policy. Remove
  the independent Markdown line-length layout rule. Scope Prettier and markdownlint to
  normal repository Markdown; retain `.docc` exclusions so Swift code fences and DocC
  directives are not reformatted by a second tool.
- Expand Prettier's explicit scoped file set to ordinary Markdown, JSON, and YAML
  configuration. Do not format generated output, build directories, package-resolution
  files, or DocC bundles without a separately reviewed decision.
- Acceptance: intentionally wrapped Swift and Markdown fixtures produce no
  formatter/linter oscillation; each file type has one documented layout owner; run
  `swiftlint --fix` before `swift-format` and verify the pair is idempotent.

## Phase 2 — Consolidate quality orchestration

**Goal**: make Just the reproducible entry point for full-tree and staged checks while
keeping slow, platform-specific DocC generation out of portable formatting policy.

### Step 2.1 — Make full-repository checks deterministic

- Files: `justfiles/quality.just`, `justfiles/docs.just`, and a new small helper script
  only if Just cannot safely express a shared file-set contract.
- Replace `_format-json`'s recursive `jq --sort-keys` pass with the scoped Prettier
  command. Remove all `command -v …; warning; success` branches for required quality
  tools.
- Define clear mutating/check pairs: `quality format` runs SwiftLint autocorrection first,
  then `swift-format` last, then scoped Prettier; `quality lint` runs strict
  `swift-format`, strict SwiftLint where supported, Prettier, markdownlint, codespell, and
  wireframe checks. All checks must use the tracked configurations.
- Remove `docs` from the portable `quality lint` aggregate. Keep `just docs lint` as the
  explicit macOS-only DocC/reference gate, with its current warnings-as-errors behavior
  and Ghostty prerequisites documented rather than hidden behind a generic quality
  command.
- Add concise recipe help describing which commands mutate, which are portable, and which
  require macOS/DocC.
- Acceptance: `just quality format` reaches a stable tree on a second run;
  `just quality lint` evaluates every declared portable policy or fails; `just docs lint`
  remains the only command that cleans/builds DocC archives.

### Step 2.2 — Harden changed-file validation

- Files: `scripts/pre-commit-lint-staged.sh`, `scripts/lint-changed.sh`, and
  `justfiles/quality.just`.
- Make the staged snapshot runner recognize the same recursive Swift, Markdown, and DocC
  path classes as the changed-file runner; eliminate the current finite-depth Swift path
  patterns. Preserve its temporary index checkout so unstaged edits never affect hook
  results.
- Pass `--configuration .swift-format` on every Swift-format invocation, including changed
  checks. Invoke the parameterized local npm markup-check script and the local virtualenv
  codespell check for changed ordinary Markdown, DocC, and Swift files; do not silently
  skip any required tool.
- Decide and document DocC changed-file behavior: retain the explicit full
  `just docs lint` escalation only when a `.docc` bundle changes, and surface its
  macOS/toolchain requirement before invoking it. Do not pretend it is a fast portable
  hook check.
- Acceptance: nested staged Swift files, Markdown files, and unstaged modifications are
  correctly classified; the hook observes the index snapshot; missing configuration or a
  required tool produces a failing actionable result.

## Phase 3 — Replace hook management with Lefthook

**Goal**: commit one hook-manager configuration and run the same Conventional Commit
policy locally and in CI without hook-side mutations or framework-specific policy.

### Step 3.1 — Make repository commit policy canonical

- Files: `scripts/conventional_commits.py` and tests for that script if its existing
  coverage does not exercise message-file input.
- Extend the existing validator with a message-file mode suitable for Git's `commit-msg`
  lifecycle. Reuse its existing accepted types, scope/breaking-change grammar, and merge
  exception; do not create a second regex or shell copy of the policy.
- Preserve existing range and subject modes used by CI. Return nonzero with a concise
  correction example when the file's subject is invalid.
- Acceptance: the same valid/invalid subject set passes/fails in subject, range, and
  message-file modes.

### Step 3.2 — Install and document Lefthook hooks

- Files: create `lefthook.yml`; update `justfiles/setup.just`, `Brewfile`,
  `CONTRIBUTING.md`, and `.gitignore`; remove `.pre-commit-config.yaml` and the obsolete
  `.pre-commit/` ignore entry after the replacement works.
- Define a non-mutating `pre-commit` Lefthook command that invokes the hardened
  staged-index script. Define a `commit-msg` command that passes Git's message-file
  argument to `scripts/conventional_commits.py --message-file`. Do not enable
  `stage_fixed`, parallel writes, or auto-formatting in hooks.
- Replace the old `pre-commit` package/bootstrap instruction with a pinned or explicitly
  versioned Lefthook installation path and make `just setup hooks` run `lefthook install`.
  Keep the manager configuration committed; do not leave a compatibility hook or
  duplicated third-party Conventional Commit hook.
- Acceptance: `lefthook install` generates both Git hook stages; valid and invalid commit
  messages receive the same decision as CI; staged checks never modify the index or
  include unstaged changes.

## Phase 4 — Align CI and documentation

**Goal**: make every automated layer run a documented subset of the same repository
commands with platform-specific responsibilities visible and reproducible.

### Step 4.1 — Make workflows call canonical quality gates

- Files: `.github/workflows/ci.yml`, `.github/workflows/docs.yml`,
  `.github/actions/setup-swift/action.yml`, `justfiles/ci.just`, and workflow dependency
  setup files as needed.
- Change the lint workflow from direct private Swift-only recipes to the portable
  canonical `just quality lint` after installing Swift, Node, `npm ci` dependencies, the
  pinned Python spelling environment, and required quality binaries. Keep DocC in its
  dedicated macOS workflow.
- Make the documented local `just ci`/`just ci check` contract match the PR expectation:
  quality plus core test for the full local gate, while retaining explicit fast build/test
  recipes for iteration and platform jobs that first materialize Ghostty prerequisites.
- Pin the Swift setup action to an immutable reviewed revision (or a repository-owned
  action implementation) instead of `@latest`; continue reading `.swift-version` as the
  toolchain source of truth. Make each job's cache/save behavior deliberate and explain
  the macOS-only DocC requirement.
- Acceptance: CI workflow steps are recognizable invocations of documented Just recipes;
  the lint job checks Markdown/wireframes as well as Swift policy; the DocC job remains
  macOS-only and runs `just docs lint`; Swift setup does not depend on a floating action
  tag.

### Step 4.2 — Publish the contributor workflow

- Files: `CONTRIBUTING.md`, `README.md` only where setup guidance is duplicated, and
  recipe comments in `Justfile`/`justfiles/*.just` where command help needs correction.
- Replace stale direct formatter examples and pre-commit instructions with the short
  contract: bootstrap dependencies, `just setup hooks`, `just quality format`,
  `just ci check`, and `just docs lint` on macOS when DocC changes. State that format
  mutates while lint/checks only verify.
- Separate mandatory portable tool dependencies from optional Linux/Windows VM tooling and
  macOS-only documentation requirements. Explain that Lefthook manages hooks but does not
  remove platform support limits of SwiftLint or DocC, and that spelling correction is an
  explicit reviewed command rather than an automatic hook mutation.
- Acceptance: a new contributor can reproduce every CI quality result using only
  documented commands and sees no reference to removed `pre-commit` setup.

## Phase 5 — Normalize and verify the migration

**Goal**: land the policy without formatter churn and prove the complete behavior before
merging.

### Step 5.1 — Apply one isolated formatting baseline

- Files: all files selected by the finalized scoped formatter globs; create/update
  `.git-blame-ignore-revs` if this repository uses it.
- After the new commands are proven, run the mutating quality formatter once across the
  repository. Put the resulting mechanical changes in an isolated `style:` commit and
  record its hash in `.git-blame-ignore-revs` when applicable. Do not mix code changes
  with this baseline.
- Acceptance: a second `just quality format` produces no diff and review can distinguish
  the mechanical baseline from behavioral tooling changes.

### Step 5.2 — Exercise all local and CI-equivalent gates

- Files: no production changes expected; add focused script tests only where new
  message-file/staged-index behavior lacks executable coverage.
- Test Lefthook with a disposable commit or equivalent temporary Git repository: valid and
  invalid messages, nested staged Swift paths, ordinary staged Markdown, DocC escalation,
  spelling failures, and unstaged-edit isolation. Confirm neither hook stages or alters
  files.
- Run the local npm markup check and local virtualenv spelling check through the Just
  recipes, then run `just quality lint`, the focused Conventional Commit validator tests,
  and `just docs lint` on macOS. Execute the repository handoff gate in order:
  `just quality format`, complete `swift test`, then `just quality lint`.
- Validate workflow syntax and run the changed CI paths through the repository's normal PR
  checks; confirm macOS, Linux, and Windows test jobs preserve their existing Ghostty
  setup.
- Acceptance: all commands pass after normalization; deliberate malformed Swift/Markdown,
  misspelled text, and Conventional Commit fixtures fail in the expected layer; the PR
  workflows pass without skipped mandatory quality tooling.

### Verification note

Local and disposable-repository verification completed. Remote PR workflows remain pending
because this phase has no commit or push authorization; run the changed workflows after
the next authorized commit reaches GitHub.

### Review handback disposition

- Accepted F1: removed the Volta-specific fallback so Node resolution requires the
  manager-neutral `node` executable on `PATH`.
- Accepted F2: removed duplicate Node-path resolution from the staged hook; the markup
  checker is the single owner.

## References

- Conversation transcript: `~/Downloads/Swift Package Tooling Best Practices.md`
- Current orchestration: `Justfile`, `justfiles/quality.just`, `justfiles/ci.just`,
  `justfiles/docs.just`, `justfiles/setup.just`
- Current policies: `.swift-format`, `.swiftlint.yml`, `.prettierrc.json`,
  `.markdownlint.json`, `.prettierignore`
- Current hooks: `.pre-commit-config.yaml`, `scripts/pre-commit-lint-staged.sh`,
  `scripts/lint-changed.sh`, `scripts/conventional_commits.py`
- CI surfaces: `.github/workflows/ci.yml`, `.github/workflows/docs.yml`,
  `.github/actions/setup-swift/action.yml`
- Project requirements: `AGENTS.md`
