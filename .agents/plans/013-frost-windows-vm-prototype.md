---
name: Frost Windows VM Prototype
description:
  Prototype a Frost-based Windows 11 ARM64 VM workflow as an alternative to the UTM Phase
  0 setup.
status: in-progress
created: 2026-06-16
updated: 2026-06-16
---

## Progress

- [x] **Phase 0 — Frost checkout and host prerequisites**
  - [x] 0.1 Choose the Frost checkout strategy and document local paths
  - [x] 0.2 Add a host prerequisite check for Frost tooling
- [x] **Phase 1 — Base Frost integration wrappers**
  - [x] 1.1 Add non-destructive Frost `just` plumbing
  - [x] 1.2 Document required ISO inputs and expected artifacts
- [x] **Phase 2 — Base Windows golden image**
  - [x] 2.1 Build the Frost base golden image
  - [x] 2.2 Verify base image boot, SSH, and exit-code propagation
- [x] **Phase 3 — Tessera toolchain golden image**
  - [x] 3.1 Create a Frost-oriented Windows provisioning script
  - [x] 3.2 Build/promote a Tessera toolchain golden image
  - [x] 3.3 Verify Swift, Git, Visual Studio, Windows SDK, and SSH key auth
- [x] **Phase 4 — Tessera source sync and test execution**
  - [x] 4.1 Add source sync for a Frost guest checkout
  - [x] 4.2 Add `test-windows-frost` and run Swift tests in the guest
  - [x] 4.3 Decide disposable vs persistent overlay default
- [ ] **Phase 5 — Interactive terminal validation**
  - [ ] 5.1 Add persistent start/stop/ssh recipes for Frost overlays
  - [ ] 5.2 Validate an interactive Tessera terminal demo over SSH/ConPTY
- [ ] **Phase 6 — UTM manual GUI path**
  - [ ] 6.1 Test importing a Frost qcow2 into UTM
  - [ ] 6.2 Document PowerShell/Windows Terminal manual validation steps
- [ ] **Phase 7 — Frost upstreaming decision**
  - [ ] 7.1 Record local Frost changes needed by the prototype
  - [ ] 7.2 Decide whether to upstream, vendor, or keep wrapper-only integration

## Overview

This plan prototypes Frost as a scriptable Windows 11 ARM64 VM workflow for Tessera,
parallel to the known-good UTM Phase 0 path. Frost already solves the hard QEMU setup,
headless boot, SSH forwarding, qcow2 overlay, and exit-code propagation pieces; Tessera
still needs project-specific toolchain provisioning, source sync, interactive recipes, and
possibly a UTM/manual GUI path. The prototype should avoid vendoring Frost until we know
which changes are actually needed. The expected end state is enough evidence to decide
whether Frost should replace, supplement, or remain separate from the UTM workflow.

## Phase 0 — Frost checkout and host prerequisites

**Goal**: Establish a stable local Frost checkout and verify host tools without changing
Tessera behavior.

### Step 0.1 — Choose the Frost checkout strategy and document local paths

- Files: `docs/WindowsVM.md` or new `docs/WindowsFrostVM.md`.
- Prefer an external checkout, e.g. `~/Developer/solcreek/frost`, referenced by
  `TESSERA_FROST_ROOT`, rather than cloning Frost inside this repository.
- Do not vendor Frost or add it as a submodule in this step.
- Acceptance: documentation states where Frost should live, how to clone it, and how to
  set `TESSERA_FROST_ROOT` in fish.

### Step 0.2 — Add a host prerequisite check for Frost tooling

- Files: `Justfile`, optionally `scripts/windows-frost-doctor.sh`.
- Check for `qemu-img`, `qemu-system-aarch64`, `swtpm`, `sshpass`, `swift`, and
  `$TESSERA_FROST_ROOT/bin/frost`.
- Print install hints using Homebrew:
  `brew install qemu swtpm hudochenkov/sshpass/sshpass`.
- Acceptance: the check succeeds on a prepared host and fails with clear actionable output
  when Frost or required tools are missing.

## Phase 1 — Base Frost integration wrappers

**Goal**: Add thin, non-destructive wrappers that let Tessera call a local Frost checkout.

### Step 1.1 — Add non-destructive Frost `just` plumbing

- Files: `Justfile`, optionally `scripts/windows-frost-env.sh`.
- Add recipes such as:
  - `windows-frost-doctor`
  - `windows-frost-help`
  - `windows-frost-dry-run`
- Use environment variables for local-only paths:
  - `TESSERA_FROST_ROOT`
  - `TESSERA_FROST_WORK`
  - `TESSERA_FROST_SSH_PORT`
  - `TESSERA_FROST_USER`
- Acceptance: `just --list` shows the recipes, and dry-run recipes do not create or boot a
  VM.

### Step 1.2 — Document required ISO inputs and expected artifacts

- Files: `docs/WindowsFrostVM.md` or `docs/WindowsVM.md`.
- Document the required user-provided inputs:
  - Windows 11 ARM64 ISO.
  - VirtIO driver ISO.
- Document expected generated artifacts:
  - base Frost golden qcow2.
  - base UEFI vars file.
  - Tessera toolchain golden qcow2.
  - persistent or disposable overlays.
- Acceptance: a contributor can identify what must be downloaded manually and what files
  the prototype creates locally.

## Phase 2 — Base Windows golden image

**Goal**: Prove Frost can build and boot a base Windows image on this machine without UTM.

### Step 2.1 — Build the Frost base golden image

- Files: no required repository code changes beyond Phase 1 wrappers/docs.
- Run Frost's `build`/`build-golden.sh` path with the user-provided Windows and VirtIO
  ISOs.
- Keep generated VM artifacts outside Git, under `TESSERA_FROST_WORK` or Frost's own
  ignored `work/` directory.
- Acceptance: a base Windows golden qcow2 and UEFI vars file exist and Frost reports a
  successful build.

### Step 2.2 — Verify base image boot, SSH, and exit-code propagation

- Files: `Justfile`, docs if command details change.
- Run a trivial guest command through Frost, such as `cmd /c ver` or
  `powershell -NoProfile -Command "$PSVersionTable.PSVersion"`.
- Confirm stdout/stderr appear on macOS and the host command exits with the guest
  command's exit code.
- Acceptance: `just windows-frost-check-base` or equivalent proves the base image is
  reachable over `localhost:<port>`.

## Phase 3 — Tessera toolchain golden image

**Goal**: Turn the base Frost image into a Tessera-ready Windows build/test image.

### Step 3.1 — Create a Frost-oriented Windows provisioning script

- Files: new `scripts/setup-windows-frost-vm.ps1`, possibly refactor shared logic from
  `scripts/setup-windows-vm.ps1`.
- Install or verify:
  - Git.
  - Visual Studio 2022 C++ workload.
  - Windows 11 SDK.
  - Swift toolchain matching `.swift-version`.
  - OpenSSH server and firewall configuration.
  - SSH public key auth for unattended host recipes.
- Adapt reboot handling for headless execution. Visual Studio may require a reboot, so use
  a marker file, scheduled task, or controlled reboot-and-resume loop.
- Acceptance: the script is idempotent and can be run over SSH in the Frost guest until it
  reports completion.

### Step 3.2 — Build/promote a Tessera toolchain golden image

- Files: `Justfile`, optionally `scripts/windows-frost-provision.sh`.
- Boot a writable clone of the base golden, copy/run `scripts/setup-windows-frost-vm.ps1`,
  shut down cleanly, and promote the resulting disk as the Tessera toolchain golden.
- If Frost lacks the right primitive, prototype with wrapper scripts first; capture any
  required Frost changes for Phase 7.
- Acceptance: a reusable Tessera toolchain golden exists and can be booted by Frost
  without reinstalling the heavy toolchain each run.

### Step 3.3 — Verify Swift, Git, Visual Studio, Windows SDK, and SSH key auth

- Files: `Justfile`, docs.
- Add a verification recipe that runs remote checks over SSH:
  - `git --version`.
  - `swift --version`.
  - `vswhere` or equivalent Visual Studio workload check.
  - Windows SDK presence.
  - passwordless SSH command from macOS.
- Acceptance: `just windows-frost-check` succeeds using key auth and shows the expected
  Swift version/target.

## Phase 4 — Tessera source sync and test execution

**Goal**: Run Tessera Swift tests inside the Frost Windows guest from macOS.

### Step 4.1 — Add source sync for a Frost guest checkout

- Files: `Justfile`, optionally `scripts/windows-frost-sync.sh`.
- Reuse the current `windows-vm-sync` idea where practical:
  - configure `receive.denyCurrentBranch=updateInstead` in the guest checkout.
  - push the current local branch to `tester@localhost:<port>:tessera`.
- If Git push over SSH is awkward with localhost port forwarding, fall back to
  archive/copy sync for the prototype.
- Acceptance: the guest checkout reflects the current host commit and is clean enough to
  run tests.

### Step 4.2 — Add `test-windows-frost` and run Swift tests in the guest

- Files: `Justfile`, docs.
- Add a recipe that boots the Tessera toolchain image/overlay, syncs source if needed, and
  runs `swift test --no-parallel` in the guest.
- Ensure the host recipe returns the guest test command's exit code.
- Acceptance: `just test-windows-frost` reaches the same current Windows compile/test
  state as `just test-windows-vm`, or passes once Slice 6 Windows fixes are implemented.

### Step 4.3 — Decide disposable vs persistent overlay default

- Files: `.agents/investigations/008-frost-windows-vm-workflow.md`, docs, `Justfile`.
- Compare:
  - disposable overlays for clean repeatability.
  - persistent dev overlay for faster iteration via retained `.build` cache.
- Default to the persistent overlay if it substantially improves local iteration, but keep
  a disposable clean-run recipe for validation.
- Acceptance: the selected default is documented with tradeoffs and recipe names make the
  mode clear.

## Phase 5 — Interactive terminal validation

**Goal**: Support hands-on terminal app runs through Windows OpenSSH/ConPTY.

### Step 5.1 — Add persistent start/stop/ssh recipes for Frost overlays

- Files: `Justfile`, optionally `scripts/windows-frost-start.sh` and
  `scripts/windows-frost-stop.sh`.
- Add recipes such as:
  - `windows-frost-start`
  - `windows-frost-stop`
  - `windows-frost-ssh`
- `windows-frost-ssh` should allocate a PTY, e.g. `ssh -tt -p <port> tester@localhost`.
- Acceptance: a developer can start a persistent Frost VM, open an interactive shell, and
  stop it without using UTM.

### Step 5.2 — Validate an interactive Tessera terminal demo over SSH/ConPTY

- Files: docs; tests only if a suitable demo harness already exists.
- Run a minimal Tessera example/demo app that exercises cursor movement and colors.
- Record any differences between SSH/ConPTY rendering and expected Windows Terminal or
  PowerShell behavior.
- Acceptance: the docs state whether SSH/ConPTY is adequate for the Phase 2 Slice 6 manual
  validation loop.

## Phase 6 — UTM manual GUI path

**Goal**: Determine whether Frost-built images can be used for manual GUI validation in
UTM.

### Step 6.1 — Test importing a Frost qcow2 into UTM

- Files: docs only unless helper scripts are useful.
- Use a standalone qcow2 copy/convert rather than a backing overlay:

  ```fish
  qemu-img convert -O qcow2 frost-golden.qcow2 utm-disk.qcow2
  ```

- Create a UTM Windows ARM VM with matching high-level settings: QEMU backend, `aarch64`
  `virt`, NVMe disk, TPM, UEFI boot, and similar memory/CPU.
- Prefer copying Frost's UEFI vars into UTM's `efi_vars.fd`; if that fails, document any
  Windows Boot Manager repair steps.
- Acceptance: the Frost-built image boots to Windows in UTM or the blocker is clearly
  recorded.

### Step 6.2 — Document PowerShell/Windows Terminal manual validation steps

- Files: `docs/WindowsFrostVM.md` or `docs/WindowsVM.md`.
- Document when to use:
  - Frost headless SSH for automated tests and quick TUI checks.
  - UTM-imported Frost image for visual PowerShell/Windows Terminal/conhost validation.
- Verify GUI guest integration details that are irrelevant to the SSH workflow but matter
  for manual UTM validation:
  - display resize/resolution.
  - keyboard and mouse input.
  - host ↔ guest clipboard copy/paste.
  - whether Frost's VirtIO guest tools install is sufficient, or whether UTM/SPICE guest
    tools need a separate install step.
- Acceptance: a contributor can run Tessera example apps in a GUI Windows session using
  the Frost-built image, including copy/paste where possible, or knows to fall back to the
  original UTM Phase 0 VM.

## Phase 7 — Frost upstreaming decision

**Goal**: Decide what, if anything, should be contributed upstream to Frost.

### Step 7.1 — Record local Frost changes needed by the prototype

- Files: `.agents/investigations/008-frost-windows-vm-workflow.md`, optionally a new
  investigation if the changes are substantial.
- Categorize changes as:
  - Tessera-specific wrapper only.
  - generic Frost feature candidate.
  - local workaround not worth upstreaming.
- Acceptance: every local Frost change has a disposition before we rely on it long-term.

### Step 7.2 — Decide whether to upstream, vendor, or keep wrapper-only integration

- Files: docs, maybe future plan.
- If a generic feature is needed, prefer an upstream PR shape such as:

  ```sh
  frost customize \
    --golden base-win11.qcow2 \
    --run scripts/provision.ps1 \
    --out project-win11.qcow2
  ```

  or a `frost build --provision <script.ps1>` hook.

- Avoid vendoring Frost into Tessera unless upstreaming/wrapper-only integration is not
  viable.
- Acceptance: the project has a documented integration decision and any follow-up PR/plan
  is scoped.

## References

- `.agents/investigations/008-frost-windows-vm-workflow.md`
- `.agents/investigations/007-windows-utm-setup-walkthrough.md`
- `.agents/plans/012-phase-2-slice-6-windows-terminal-io.md`
- `docs/WindowsVM.md`
- `scripts/setup-windows-vm.ps1`
- <https://github.com/solcreek/frost>
