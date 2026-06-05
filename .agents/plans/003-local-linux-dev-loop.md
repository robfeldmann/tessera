---
name: Local Linux Dev Loop
description:
  Establish a Docker-free local loop for macOS builds, Linux cross-builds, and optional
  Linux test execution.
status: completed
created: 2026-06-03
updated: 2026-06-03
---

## Progress

- [x] **Phase 1 — Document the local loop**
  - [x] 1.1 Add recommended macOS and Linux commands
  - [x] 1.2 Add optional Linux VM workflow
- [x] **Phase 2 — Add versioned Linux tooling**
  - [x] 2.1 Add Swift version and SDK metadata
  - [x] 2.2 Add Linux SDK helper scripts
  - [x] 2.3 Add Just recipes
  - [x] 2.4 Update contributing docs to use Just recipes
  - [x] 2.5 Add provisioned Lima config
- [x] **Phase 3 — Validate**
  - [x] 3.1 Verify native build/test/docs still work
  - [x] 3.2 Verify Linux cross-build works
  - [x] 3.3 Verify Linux test command works in VM, if configured

## Overview

Phase 0 needs a development loop that is fast locally and representative enough before
GitHub Actions. The lightest Docker-free path is to keep normal development native on
macOS, add a Swift SDK based Linux cross-build for quick compatibility checks, and use an
on-demand lightweight Linux VM only when Linux test execution is needed. This avoids
committing to a heavier virtualization workflow while leaving room to add one later.

## Phase 1 — Document the local loop

**Goal**: Make the expected local commands clear before adding automation.

### Step 1.1 — Add recommended macOS and Linux commands

- File: `CONTRIBUTING.md` or `README.md`
- Document native `just build`, `just test`, `just lint`, and DocC commands.
- Document Linux cross-build setup using an installed Swift SDK bundle and
  `swift build --swift-sdk ...`.
- Acceptance: A contributor can tell which commands to run for macOS and Linux build
  checks.

### Step 1.2 — Add optional Linux VM workflow

- File: `CONTRIBUTING.md` or `README.md`
- Document the optional VM path for running `swift test` on Linux without Docker.
- Prefer a just-in-time VM tool such as Lima/UTM over manually maintained machines.
- Acceptance: A contributor can bring up Linux, install Swift, run tests, and tear the
  environment down.

## Phase 2 — Add versioned Linux tooling

**Goal**: Make the loop command-driven and easy to reuse locally and in CI.

### Step 2.1 — Add Swift version and SDK metadata

- Files: `.swift-version`, `scripts/config/swift-sdks.json`
- Add the supported Swift toolchain version and matching Static Linux SDK metadata.
- Acceptance: The Swift version and SDK URL/checksum/id live in one obvious place.

### Step 2.2 — Add Linux SDK helper scripts

- Files: `scripts/install-linux-sdk.sh`, `scripts/linux-sdk-id.sh`
- Add bash scripts that read `.swift-version` and `scripts/config/swift-sdks.json` with
  `jq`.
- Acceptance: Scripts fail clearly when metadata is missing or `jq` is unavailable.

### Step 2.3 — Add Just recipes

- File: `Justfile`
- Add recipes for installing the Swift toolchain, installing the Linux SDK, printing the
  configured SDK id, Linux cross-builds, and optional Lima test runs.
- Acceptance: Recipes delegate version-specific details to the scripts/config.

### Step 2.4 — Update contributing docs to use Just recipes

- File: `CONTRIBUTING.md`
- Replace scattered SDK commands with the new `just` recipes.
- Acceptance: Contributors can follow docs without copying SDK URLs/checksums manually.

### Step 2.5 — Add provisioned Lima config

- Files: `scripts/config/lima/tessera-linux.yaml`, `Justfile`, `CONTRIBUTING.md`
- Add a Lima config that mounts the repository and installs Swift from `.swift-version`
  using Swiftly.
- Acceptance: `just linux-vm-start` creates a VM ready to run `swift test` without manual
  setup.

## Phase 3 — Validate

**Goal**: Prove the workflow before adding GitHub Actions.

### Step 3.1 — Verify native build/test/docs still work

- Files: none
- Run existing native checks.
- Acceptance: `just build`, `just test`, and DocC generation pass on macOS.

### Step 3.2 — Verify Linux cross-build works

- Files: none
- Install/select the Linux Swift SDK and run the cross-build recipe.
- Acceptance: Linux build succeeds from macOS without Docker.

### Step 3.3 — Verify Linux test command works in VM, if configured

- Files: none
- Bring up the optional Linux VM and run tests inside it.
- Acceptance: `swift test` passes inside Linux, or this remains explicitly documented as
  deferred.

## References

- `docs/Spec.md` Phase 0
- `Justfile`
- `Package.swift`
