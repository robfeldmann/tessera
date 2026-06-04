---
name: GitHub Actions Phase 0
description: Add minimal GitHub Actions workflows for Swift build/test matrix and DocC validation.
status: pending
created: 2026-06-03
updated: 2026-06-03
---

## Progress

- [ ] **Phase 1 — Confirm constraints and repo settings**
  - [ ] 1.1 Confirm private repo runner budget and branch name
  - [ ] 1.2 Confirm Swift availability on GitHub-hosted runners
- [ ] **Phase 2 — Add minimal CI workflow**
  - [ ] 2.1 Add OS matrix build/test workflow
  - [ ] 2.2 Add dependency/tool caching if useful
  - [ ] 2.3 Add workflow ergonomics and safety settings
- [ ] **Phase 3 — Add documentation workflow**
  - [ ] 3.1 Add DocC validation job
  - [ ] 3.2 Optionally add DocC archive generation artifact
- [ ] **Phase 4 — Validate and update Phase 0 checklist**
  - [ ] 4.1 Push to private GitHub repo and inspect failures
  - [ ] 4.2 Fix Windows/Linux/macOS portability issues
  - [ ] 4.3 Update `docs/Spec.md` Phase 0 checklist

## Overview

Phase 0 needs GitHub Actions proving `swift build` and `swift test` pass on macOS,
Ubuntu, and Windows. The first workflow should be deliberately small to keep private-repo
minutes and debugging cost low. Use Herdr's CI structure as inspiration: read-only
permissions, concurrency cancellation, `fail-fast: false`, explicit checkout settings,
and a single project command where possible. Add documentation validation separately so
cross-platform build/test failures are easy to diagnose.

## Phase 1 — Confirm constraints and repo settings

**Goal**: Avoid designing a workflow that is too expensive or mismatched to the repo.

### Step 1.1 — Confirm private repo runner budget and branch name

- Files: none
- Check GitHub plan limits for private Actions minutes and runner multipliers.
- Confirm the default branch name, likely `main`.
- Acceptance: Workflow triggers are scoped to the expected branch and budget.

### Step 1.2 — Confirm Swift availability on GitHub-hosted runners

- Files: none
- Confirm which Swift version is available on `macos-latest`, `ubuntu-latest`, and
  `windows-latest`, or decide which setup action/toolchain installer to use.
- Acceptance: The workflow has a clear Swift 6.3.2 setup path for each OS or documents any
  temporary mismatch.

## Phase 2 — Add minimal CI workflow

**Goal**: Add the smallest useful build/test matrix.

### Step 2.1 — Add OS matrix build/test workflow

- File: `.github/workflows/ci.yml`
- Add triggers for `pull_request`, `push` to `main`, and `workflow_dispatch`.
- Add matrix jobs for `ubuntu-latest`, `macos-latest`, and `windows-latest`.
- Run `swift --version`, `swift build`, and `swift test`.
- Acceptance: Workflow is syntactically valid and attempts all three operating systems.

### Step 2.2 — Add dependency/tool caching if useful

- File: `.github/workflows/ci.yml`
- Consider caching `.build` or SwiftPM repositories only after the first baseline works.
- Avoid premature cache complexity if jobs are already fast.
- Acceptance: Either no cache is added by design, or cache keys are simple and safe.

### Step 2.3 — Add workflow ergonomics and safety settings

- File: `.github/workflows/ci.yml`
- Add `permissions: contents: read`, concurrency cancellation, `fail-fast: false`, job
  timeouts, and checkout with `persist-credentials: false`, inspired by Herdr.
- Acceptance: Repeated pushes cancel stale jobs and the workflow follows least-privilege
  defaults.

## Phase 3 — Add documentation workflow

**Goal**: Validate DocC without obscuring matrix build/test failures.

### Step 3.1 — Add DocC validation job

- File: `.github/workflows/docs.yml` or `.github/workflows/ci.yml`
- Run DocC warnings-as-errors checks for `Tessera` and `TesseraTerminal`, likely on macOS
  only unless Linux support is confirmed.
- Acceptance: DocC validation passes in GitHub Actions.

### Step 3.2 — Optionally add DocC archive generation artifact

- File: `.github/workflows/docs.yml` or `.github/workflows/ci.yml`
- Optionally run `just docs` and upload the generated DocC archive as an artifact.
- Acceptance: Artifact upload is available if useful, or explicitly deferred.

## Phase 4 — Validate and update Phase 0 checklist

**Goal**: Finish the GitHub Actions portion of Phase 0.

### Step 4.1 — Push to private GitHub repo and inspect failures

- Files: workflow files
- Push the workflow to the private repo and run it.
- Acceptance: Failures are understood and recorded before making fixes.

### Step 4.2 — Fix Windows/Linux/macOS portability issues

- Files: as needed
- Address issues exposed by the CI matrix, especially Windows availability and package
  dependency compatibility.
- Acceptance: `swift build` and `swift test` pass on macOS, Ubuntu, and Windows in CI.

### Step 4.3 — Update `docs/Spec.md` Phase 0 checklist

- File: `docs/Spec.md`
- Mark the GitHub Actions matrix item complete once CI passes.
- Leave `DESIGN.md` untouched unless that item is also addressed.
- Acceptance: Phase 0 checklist accurately reflects completed CI work.

## References

- `docs/Spec.md` Phase 0
- `.agents/plans/003-local-linux-dev-loop.md`
- Herdr CI inspiration:
  `https://github.com/ogulcancelik/herdr/blob/master/.github/workflows/ci.yml`
