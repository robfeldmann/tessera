---
name: Toolchain, repository conventions, and plan consolidation
description:
  Baseline every local check, make Xcode 26.6 and Swift 6.3.3 the baseline on every lane
  while adding Swift 6.4 and Xcode 27 support, port plan 033 and its spikes to main, run
  plan 034, adopt the owner's newer repository conventions (unwrapped prose with rumdl, an
  IWE docs workspace with slug-named plans and a split spec, mise and hk in place of just
  and Lefthook, Tessera-owned Tart and Lima VMs, and a current Zig and libghostty-vt),
  then merge plans 032 and 033 into one plan.
status: in-review
created: 2026-10-21
updated: 2026-10-21
---

<!-- Allowed status values: planning, in-review, pending, in-progress, complete, superseded. -->

## Progress

- [ ] **Phase 1 — Baseline**
  - [x] 1.1 Run every local check at HEAD and record the results (`982779d`; results table
        in the step)
- [ ] **Phase 2 — Xcode 26.6 baseline, plus Swift 6.4 and Xcode 27**
  - [ ] 2.1 Move every lane to the Xcode 26.6 and Swift 6.3.3 baseline
  - [ ] 2.2 Build and test on Xcode 27 and Swift 6.4
  - [ ] 2.3 Add the Swift 6.4 lanes
  - [ ] 2.4 Toolchain documentation
- [ ] **Phase 3 — Port plan 033 and its spikes to main**
  - [ ] 3.1 Bring the `devtools-plan` commits onto main
  - [ ] 3.2 Build and test each spike on the Phase 2 lanes
  - [ ] 3.3 Save the seams spike as a patch (branch deletion waits for the owner)
- [ ] **Phase 4 — Plan 034 bug punchlist**
  - [ ] 4.1 Run plan 034 to completion
- [ ] **Phase 5 — Repository conventions**
  - [ ] 5.1 Set the Swift line width to 90
  - [ ] 5.2 Move project docs into an IWE workspace with slug-named plans
  - [ ] 5.3 Split the spec into workspace pages
  - [ ] 5.4 Unwrap prose and lint Markdown with rumdl
  - [ ] 5.5 Replace `just` with mise and Lefthook with hk
  - [ ] 5.6 Give Tessera its own Tart and Lima VM tasks
  - [ ] 5.7 Update libghostty-vt and Zig
- [ ] **Phase 6 — Merge plans 032 and 033**
  - [ ] 6.1 Write the merged plan
  - [ ] 6.2 Owner decision: the `mobile` viewport rule, then apply it
  - [ ] 6.3 Retire plans 032 and 033

Next: Step 2.1 (`.swift-version` 6.3.3, CI setup action, SDK entry, Lima and Frost
provisioning).

## Overview

Tessera's toolchain, conventions, and plans have drifted from the owner's other
repositories. The project has always been built with Xcode 26, lately 26.6 (Swift 6.3.3),
but `.swift-version` pins 6.3.2, which is what CI, the Lima VM, and the Frost VM install,
and the host's active Xcode is now 27.1 (Swift 6.4). Xcode 26.6 becomes the baseline every
lane must pass for the foreseeable future, and Swift 6.4 and Xcode 27 become a second
supported lane. The floor stays `swift-tools-version: 6.3` (`Package.swift:1`) and macOS
26 (`Package.swift:13`).

The order is deliberate. Phase 1 records what passes before anything changes. Phase 2
settles the toolchain before plan 034, a concurrency plan whose compiler checks were made
on 6.4 (plan 034, Not covered). Phase 3 brings plan 033's research onto main once it can
be built on the new lanes, which also retires the `devtools-plan` branch so the
repository-wide rewrites in Phase 5 conflict with nothing. Phase 4 runs plan 034. Phase 5
changes conventions in one pass: the docs move, the spec split, and prose unwrapping each
touch most Markdown files, mise comes before the VM tasks because those tasks are mise
tasks, and the Zig update comes last because it touches every build lane. Phase 6 merges
plans 032 and 033 last, so the merged plan is written once, in the new format, and gates
the return to feature work.

Work happens on one integration branch, `plan-035` (owner decision, 2026-10-21); see
[Overnight execution](#overnight-execution). `main` accepts only squash-merged pull
requests that the owner approves (`CONTRIBUTING.md`, Repository governance), so nothing
reaches `main` without the owner. In the morning the owner reads the branch commit by
commit and opens pull requests to `main` in phase order, starting with the 25 commits
`main` already carries locally (including the commits that add plans 034 and 035).

## Owner decisions (2026-10-21)

- Baseline toolchain: Xcode 26.6 and Swift 6.3.3, on every lane (macOS, Linux, Windows,
  CI, and the VMs), maintained for a while. Swift 6.4 and Xcode 27 are added, not
  substituted.
- Markdown: rumdl, as in `~/.dotfiles` and Lattice.
- Git hooks: hk, as in `~/.dotfiles`.
- Other tools: the latest versions mise can provide, locked in `mise.lock`, except where a
  version must match something else (Step 5.5).
- Plans: slug filenames, no numbers, so branches cannot collide on a number. The
  `docs/plans.md` hub records the order, stage, and which plan is active.
- Docs layout: the directory names of the owner's other projects where they apply, new
  ones where needed; a `research/` directory; the design catalog moves into `docs/`.
- Agent commands: `.pi/prompts/` moves to the most generic location omp supports that
  other harnesses can share (Step 5.2).
- VMs: Tessera owns its VM tasks, so anyone can contribute or test without the owner's
  dotfiles. macOS guests start from a Cirrus Labs vanilla image with a scripted Xcode
  install.
- Swift line width: 90.
- macOS CI compiler: Xcode 26.6's own compiler; `setup-swift` stays for Linux and Windows
  only.
- Seams spike: saved as a patch, and the branch deleted once everything else is on main.
- Spikes stay out of CI.
- Zig and libghostty-vt: update to a current Zig once libghostty-vt builds on it (Step
  5.7).
- Branching: one integration branch, `plan-035`, cut from local `main`; the owner opens
  the pull requests to `main`.
- Plan 034's open decisions (Steps 3.2 (e), 4.1, 6.4, 6.5, 7.1, 8.2, 8.4, 9.8, 10.1, and
  10.3) are made and recorded in each step of plan 034; none of them waits on the owner.

## Overnight execution

Rules for an agent running this plan unattended.

- Branch: create `plan-035` from local `main` (which carries 25 commits not on
  `origin/main`) and do all work there. One commit per step, or a few for a large step,
  with Conventional Commit messages; commits are signed by the repository's Git
  configuration. Push `plan-035` after each phase and keep one draft pull request from
  `plan-035` to `main` open, with a Conventional Commit title, so CI runs. Never push to
  `main`, merge a pull request, force-push, or delete a branch or worktree.
- Checks: the repository's pre-commit hooks do not run in this worktree (`core.hooksPath`
  in `../.bare/config` is `.githooks`, which does not exist, and Lefthook is not
  installed); only the owner's Git config hook validates Conventional Commit subjects. So
  run the `AGENTS.md` gate by hand before every commit: `just quality format`, the full
  `swift test` on the baseline toolchain (`DEVELOPER_DIR` set to Xcode 26.6), and
  `just quality lint`; add `just docs lint` when DocC or public API changes.
- Tools: mise is installed but not activated in a plain shell; run mise-managed tools (hk,
  rumdl, and later the Tessera tasks) through `mise exec --` or an activated shell.
- Handoff: after each step, check its box only with evidence on the line (a commit SHA, a
  command and its result) and update the `Next:` line under Progress. The run will outlast
  one context; the plan is the handoff.
- Blocked steps: record what was tried and the first error in the step, leave the box
  unchecked, and continue with the next step that does not depend on it. Step 2.1 gates
  every later build step; Steps 3.1 and 3.3's patch, and plan 034's test-only steps, do
  not depend on each other.
- Step 5.7 (Zig and libghostty-vt) runs on its own branch, `plan-035-zig`, cut from the
  tip of `plan-035`, so an unfinished port never breaks the integration branch.
- Left for the owner: merging pull requests, deleting the devtools branches and worktrees
  (Step 3.3), the `mobile` viewport decision (Step 6.2), reviewing the merged plan (Step
  6.1, written as `proposed`), and retiring plans 032 and 033 (Step 6.3).

## Phase 1 — Baseline

**Goal**: a recorded result for every check the repository has, before anything changes.

### Step 1.1 — Run every local check at HEAD and record the results

- Toolchain: on macOS, run with
  `DEVELOPER_DIR=/Applications/Xcode-26.6.0.app/Contents/Developer` (Swift 6.3.3, the
  project's baseline). Linux and Windows still install 6.3.2 from `.swift-version`; record
  that, and do not change it here. Record `swift --version` for each platform,
  `xcode-select -p`, and `.swift-version`.
- macOS core: `just core build`, `just core test`.
- Quality: `just quality lint` (swift-format, SwiftLint, Markdown, spelling, wireframes,
  architecture, release notes, vouch). `just ci check` runs the core tests and this gate
  together.
- DocC: `just docs lint` and `just docs build`.
- Examples: `just core examples` (`swift build --package-path Examples`).
- Linux: `just linux start`, `just linux test`, `just linux stop`. Skip `just linux build`
  here and record why: `scripts/install-linux-sdk.sh:5,18` selects the Static Linux SDK
  from `.swift-version` (6.3.2, the only SDK installed), and the SDK must match the
  compiler (Xcode 26.6 is 6.3.3), so it would fail for a reason unrelated to the code.
  Step 2.1 runs it once the 6.3.3 SDK is installed.
- Windows (Frost, the recommended workflow in `CONTRIBUTING.md`):
  `just windows-frost doctor`, `start`, `check-toolchain`, `build-ghostty` if the pin
  moved, `test`, `conpty-smoke`, `stop`. The persistent overlay was last booted
  2026-07-28; if the first SSH hangs (a pending Windows update or a stale guest clock),
  retry once with `just windows-frost start --reset`, and record the guest's
  `swift --version` before trusting the run. Fall back to `just windows-utm check` and
  `test` only if Frost is unavailable, and say so.
- Then repeat macOS core, Examples, and `just docs lint` with Xcode 27.1 selected, as
  information for Step 2.2. Do not fix anything in this step.
- Acceptance: a table in this step gives, per check and toolchain, pass or fail, wall
  time, and any pre-existing failure with its first error. This also satisfies plan 034
  Step 1.1 on the old toolchain.

#### Results (2026-10-21, HEAD `78616a2` on `plan-035`)

Toolchains: `xcode-select -p` is `/Applications/Xcode-27.1.0.app/Contents/Developer`
(Xcode 27.1, build 27A9275, `swiftlang-6.4.0.34.1`); the baseline run used
`DEVELOPER_DIR=/Applications/Xcode-26.6.0.app/Contents/Developer` (Xcode 26.6, build
17F113, `swiftlang-6.3.3.1.3`); `.swift-version` is `6.3.2`. Lima guest: Ubuntu 24.04.5,
Swift 6.3.2 (`swift-6.3.2-RELEASE`, the only swiftly toolchain), Zig 0.15.2. Windows guest
(UTM `tessera-frost-import`): Swift 6.3.2 (`aarch64-unknown-windows-msvc`), with the
pinned `libghostty-vt` artifact already provisioned. macOS wall times are warm-cache
(`.build` existed); the host also ran the VMs during the macOS runs.

| Check                        | Xcode 26.6 (6.3.3) | Xcode 27.1 (6.4) | Linux 6.3.2                               | Windows 6.3.2                                     |
| ---------------------------- | ------------------ | ---------------- | ----------------------------------------- | ------------------------------------------------- |
| `just core build`            | pass, 5s           | pass, 9s         | skipped (see below)                       | —                                                 |
| `just core test` (634 tests) | pass, 3s           | pass, 13s        | pass, 317s (627 tests, `just linux test`) | pass, 117s (629 tests, Ghostty-backed, UTM guest) |
| `just quality lint`          | pass, 9s           | pass, 13s        | —                                         | —                                                 |
| `just docs lint`             | **fail**, 58s      | **fail**, 41s    | —                                         | —                                                 |
| `just docs build`            | **fail**, 19s      | not run          | —                                         | —                                                 |
| `just core examples`         | pass, 30s          | pass, 14s        | —                                         | —                                                 |

Pre-existing failures and recipe defects, none fixed here:

- `just docs lint` and `just docs build` fail on both Xcodes with the same first error:
  `Extensions/VirtualTerminal.md:10:5: error: 'init(feed:text:cell:cursor:kittyImages:kittyPlacements:snapshot:)' doesn't exist at '/TesseraTerminalSnapshotSupport/VirtualTerminal'`
  (DocC suggests
  `init(feed:resize:text:cell:cursor:kittyImages:kittyPlacements:snapshot:)`).
- `just linux build` skipped as the step says: `scripts/install-linux-sdk.sh` selects the
  6.3.2 Static Linux SDK from `.swift-version`, which cannot match Xcode 26.6's 6.3.3
  compiler. Step 2.1 runs it.
- `just linux start` fails when the instance already exists
  (`limactl --yes start --name=tessera-linux … tessera-linux.yaml` →
  `instance "tessera-linux" already exists`); `scripts/linux-test.sh` starts and stops a
  stopped instance itself, so `just linux test` passed, and then `just linux stop` failed
  (`expected status "Running", got "Stopped"`). Both recipes assume a VM that `test` does
  not leave behind; Step 5.6 replaces them.
- Windows Frost is unavailable on this host: QEMU 11.1.2 under macOS 27.0.1 aborts at VM
  creation with
  `qemu-system-aarch64: -device tpm-tis-device,tpmdev=tpm0: Error: ret = HV_BAD_ARGUMENT (0xfae94003, at ../accel/hvf/hvf-all.c:123)`,
  for `just windows-frost start` (the persistent VM; `stop` then reported a stale pid),
  `check-toolchain` (244s, "SSH did not come up"), and `test` (242s, same), so
  `conpty-smoke` found nothing on port 2222. `doctor` passed. Also `check-toolchain` and
  `test` boot disposable overlays on the same SSH port as the persistent VM, so the order
  in this step (`start` then `check-toolchain`) cannot work even on a healthy host; the
  `CONTRIBUTING.md` order (`start`, `build-ghostty`, `stop`, then `test`) is right.
- Windows fallback, as the step allows: the UTM-imported Frost VM (`tessera-frost-import`,
  already holding Swift 6.3.2 and the pinned `libghostty-vt` artifact). `utmctl` fails
  with `OSStatus error -10004` (Apple Events automation permission; the agent runs under a
  launchd-started `herdr`, which macOS cannot prompt for), so the VM was started from the
  UTM window. The guest's DHCP address was `192.168.64.3`; the owner's
  `~/.ssh/config.d/tessera-windows.conf` still points at `192.168.64.2` and user `tess`,
  so a `tessera-utm` alias (user `tester`, key `~/.ssh/tessera_windows`) was added as
  `~/.ssh/config.d/zz-plan035-tessera-utm.conf` for the run.
  `just windows-frost sync-utm 192.168.64.3` and `just windows-utm check` passed. Plain
  `just windows-utm test` fails at
  `Sources\CGhosttyVT\shim.c:1:10: fatal error: 'ghostty/vt.h' file not found`, because
  that recipe never provisions the Ghostty headers or sets `GHOSTTY_VT_OUTPUT_DIR`; the
  Ghostty-backed suite was run with the guest script Frost uses
  (`scripts/run-windows-frost-tests.ps1 -GhosttyOutputDir …`): pass, 117s, 629 tests,
  `==> Ghostty VT enabled`.
- `just windows-frost conpty-smoke` was not rerun against the UTM guest; it is written for
  the Frost SSH port and needs a Frost host fix first (recorded as unverified).

## Phase 2 — Xcode 26.6 baseline, plus Swift 6.4 and Xcode 27

**Goal**: every lane passes on the Xcode 26.6 and Swift 6.3.3 baseline, Swift 6.4 and
Xcode 27 pass too, and CI guards both, without raising the floor.

### Step 2.1 — Move every lane to the Xcode 26.6 and Swift 6.3.3 baseline

- `.swift-version`: 6.3.2 → 6.3.3. It means the baseline toolchain every lane must pass.
- Availability (checked 2026-10-21): swift.org publishes 6.3.3 (2026-06-29) for Ubuntu
  24.04 (x86_64, aarch64), Windows (x86_64, arm64, so Frost's arm64 guest is covered), and
  the Static Linux SDK (x86_64, arm64), and `swiftly list-available` offers it. Xcode
  26.6's compiler is `swiftlang-6.3.3.1.3`, so every platform runs the same release.
- CI macOS (checked 2026-10-21, image `20261013.0424.1`): the `macos-26` label is macOS
  26.6.2 on arm64, with Xcode 26.6 (17F113) as the default at
  `/Applications/Xcode_26.6.app`, beside 26.0.1 through 26.5. The image policy replaces a
  patch version when the next one ships, so a hard-coded `Xcode_26.6.app` path can vanish;
  select it in one place (an env var in the setup action) so the change is one line.
- macOS jobs use Xcode 26.6's own compiler, as local development does (owner decision):
  the setup action selects Xcode on macOS and runs `setup-swift` only on Linux and
  Windows. The SwiftPM cache key on macOS includes the Xcode version, since
  `.swift-version` no longer describes that lane exactly.
- Consumers to update: the CI install (`.github/actions/setup-swift/action.yml`) and the
  SwiftPM cache keys (`.github/workflows/ci.yml:167`, `:266`), which follow the file; the
  Xcode selection in `ci.yml`, `docs.yml`, and `pages.yml`; the Linux SDK entry in
  `scripts/config/swift-sdks.json` (add the 6.3.3 entry, then `just linux install-sdk` and
  `just linux build`, deferred from Step 1.1); Lima provisioning
  (`scripts/config/lima/tessera-linux.yaml:42-55` reinstalls from `.swift-version` on
  every start, so the next `just linux start` re-provisions); the Frost toolchain image
  (`just windows-frost provision-toolchain`, then `check-toolchain`); and
  `just core install-swift`.
- `scripts/install-linux-sdk.sh` keys the SDK on `.swift-version`. That matches the
  baseline compiler, but the 6.4 lane (Step 2.3) needs the SDK for the active compiler's
  version, so key it on `swift --version` instead, falling back to `.swift-version`.
- Local macOS: document selecting Xcode 26.6 with `DEVELOPER_DIR` while the active Xcode
  is 27.1. Step 5.5 moves this into mise's `[env]`.
- Acceptance: the Phase 1 check matrix passes on 6.3.3 on macOS, in the Lima VM, and in
  the Frost VM, and a CI run is green on all three platforms, with Xcode 26.6's
  `swiftlang-6.3.3` in the macOS logs and swift.org 6.3.3 in the Linux and Windows logs.

#### Done (2026-10-21)

- `.swift-version` is `6.3.3`. `.github/actions/setup-swift/action.yml` now takes `xcode`
  (default `26.6`, selected with `xcode-select` from `/Applications/Xcode_<version>.app`,
  one place to change when the image drops a patch version) and `swift-version` (Linux and
  Windows only; default `.swift-version`), and outputs `toolchain` (`xcode-26.6` or
  `swift-6.3.3`), which `ci.yml` puts in the SwiftPM cache keys (`swiftpm-v3-…`).
  `docs.yml` and `pages.yml` use the action unchanged, so they select Xcode 26.6 too.
- `scripts/config/swift-sdks.json` has the 6.3.3 entry (checksum `87c3eaf9…6b607b`,
  computed from the downloaded bundle); the new `scripts/linux-sdk-version.sh` keys the
  SDK on `swift --version` with a `.swift-version` fallback, and `install-linux-sdk.sh`
  and `linux-sdk-id.sh` use it (verified: 6.3.3 under Xcode 26.6, warning plus 6.3.3
  fallback under Xcode 27.1). `just linux install-sdk` installed
  `swift-6.3.3-RELEASE_static-linux-0.1.0` (46s).
- `just linux build` fails on the 6.3.3 SDK and, rechecked with Xcode 26.5's 6.3.2
  compiler on the 6.3.2 SDK, failed before too:
  `swift-snapshot-testing/Sources/SnapshotTesting/AssertSnapshot.swift:1:8: error: no such module 'XCTest'`.
  The `TesseraTestSupport` and `TesseraTerminalTestSupport` library products depend on
  SnapshotTesting, and the Static Linux SDK ships no XCTest, so a plain `swift build` of
  the package cannot cross-compile. Pre-existing and unrelated to the toolchain; left for
  the Step 5.5 inventory (drop the recipe or build only the non-test products).
- Lima: `limactl start` re-provisioned the guest from `.swift-version` (swiftly now lists
  `Swift 6.3.3 (in use) (default)` beside 6.3.2); `just linux test` passes, 627 tests
  (59s, warm). `scripts/linux-test.sh` had a latent SIGPIPE: its
  `limactl list --json | python3 … break` pipeline exited 141 under `pipefail` twice in a
  row; it now reads the whole list before printing.
- Windows: Frost's `provision-toolchain` cannot run on this host (Step 1.1), so Swift
  6.3.3 was installed in the UTM guest with the same swift.org installer Frost uses
  (`swift-6.3.3-RELEASE-windows10-arm64.exe /quiet /norestart`, exit 0);
  `check-windows-frost-toolchain.ps1 -ExpectedSwiftVersion 6.3.3` passes, and the
  Ghostty-backed suite passes, 629 tests (180s). The `ExpectedSwiftVersion` defaults in
  `check-windows-frost-toolchain.ps1` and `setup-windows-frost-vm.ps1` are 6.3.3. The
  Frost golden image itself still holds 6.3.2 until the owner can run
  `just windows-frost provision-toolchain` on a working QEMU.
- macOS: `just quality format`, `swift test --no-parallel` (634 tests), and
  `just quality lint` pass under Xcode 26.6. The `DEVELOPER_DIR` note for local macOS is
  written in Step 2.4 with the rest of the toolchain docs; `docs/LocalDevelopmentState.md`
  already describes the SDK resolution.
- CI: see the Progress line for the run on the draft pull request.

### Step 2.2 — Build and test on Xcode 27 and Swift 6.4

- Fix new compiler diagnostics without raising `swift-tools-version` or the macOS 26
  floor, and without breaking the baseline. APIs that need the macOS 27 SDK (for example
  `withTaskCancellationShield`, which plan 034 mentions) go behind `#available` at a leaf
  seam, per `AGENTS.md`.
- Confirm the experimental and upcoming features (`Package.swift:603-607`, including
  `NonisolatedNonsendingByDefault`) behave the same on both compilers.
- Acceptance: macOS core, quality, DocC, and Examples pass on Xcode 27.1 and still pass on
  Xcode 26.6.

### Step 2.3 — Add the Swift 6.4 lanes

- CI: add a Swift 6.4 leg on Linux (6.4.1 is published, 2026-10-12, for the same platforms
  as 6.3.3), and a macOS leg on the `xcode-27` label. Checked 2026-10-21: that label is a
  public preview (`actions/runner-images#14404`, open), on macOS 27.0.1 with Xcode 27.0 as
  the default plus 27.1 and a 27.2 beta, and GitHub warns of possible instability and
  queueing; run it as a non-required leg until the image reaches general availability.
  Cache keys include the lane. DocC and Pages stay on the baseline only. No Windows 6.4
  leg in this plan; the owner decides on one later, and nothing here waits for it.
- Local VMs: a second Swift toolchain in the Lima VM (swiftly can hold both), selectable
  per test run. Frost stays on the baseline only.
- Acceptance: a pull request runs green on every lane, and a deliberate 6.4-only construct
  fails the baseline leg, then is reverted.

### Step 2.4 — Toolchain documentation

- Files: `CONTRIBUTING.md`, `README.md`, `docs/ProjectStatus.md` (its tested-configuration
  table still says macOS 26.5.2), `docs/LocalDevelopmentState.md`, `CHANGELOG.md`, and the
  "pinned toolchain" wording in plan 034 (its Overview, Step 1.1, Step 8.1, and Not
  covered).
- Acceptance: the docs name the baseline and the 6.4 lane, and how to select each locally
  and in the VMs.

## Phase 3 — Port plan 033 and its spikes to main

**Goal**: plan 033, its investigations, and its spikes live on main and build on the Phase
2 lanes.

### Step 3.1 — Bring the `devtools-plan` commits onto main

- Source: branch `devtools-plan` (worktree `tessera/devtools`), nine commits from
  `fdd4732` to `8ee4c59`. They only add files: investigations 037-041,
  `.agents/plans/033-developer-tooling.md`, and `spikes/` (GraphQuery, HeadlessRunner,
  LiveSocket, SvgShot, and `Seams/README.md`), 77 files in all. Main has investigations up
  to 036 and no plan 033, so nothing collides.
- Change: cherry-pick the nine commits onto `plan-035` now
  (`git cherry-pick fdd4732^..8ee4c59`). Nothing collides, and waiting for the first pull
  request to merge is unnecessary; the owner's squash merges make any later rebase moot.
- Acceptance: the files are on `plan-035`, and `just quality lint` passes with them.

### Step 3.2 — Build and test each spike on the Phase 2 lanes

- Each spike is its own package. Run `swift build` and `swift test` with
  `--package-path spikes/<Name>` for GraphQuery, HeadlessRunner, LiveSocket, and SvgShot,
  and fix drift from main's API since the spikes were written.
- Spikes stay out of CI (owner decision). Say so in `spikes/README.md`: they are frozen
  evidence, built by hand.
- Acceptance: every spike builds and its tests pass on the baseline and the 6.4 lane.

### Step 3.3 — Save the seams spike as a patch and retire the devtools branches

- Branch `devtools-seams-spike` (worktree `tessera/devtools-seams`, commit `30e4bbf`) adds
  resize, clock, and probe-ID seams to `Sources/`; `spikes/Seams/README.md` describes it.
  Porting it would make the seams real code, which is plan work for the merged plan (Phase
  6), not a port.
- Change: save it with `git format-patch -1 30e4bbf` as `spikes/Seams/30e4bbf.patch`, and
  point `spikes/Seams/README.md` and plan 033's references at the patch file. Removing
  both worktrees and deleting `devtools-plan` and `devtools-seams-spike` waits for the
  owner, once their contents are on `main`.
- Acceptance: `git apply --check spikes/Seams/30e4bbf.patch` succeeds against `30e4bbf^`,
  and the README names that base.

## Phase 4 — Plan 034 bug punchlist

**Goal**: plan 034 is complete.

### Step 4.1 — Run plan 034 to completion

- Plan: `.agents/plans/034-terminal-io-concurrency-review-fixes.md`, all ten phases, with
  every owner decision already recorded in its steps (2026-10-21). Its Step 1.1 is
  satisfied by Step 1.1 here plus the Phase 2 lanes; run its focused filters on each lane.
  Its compiler-dependent steps (8.1 in particular) are checked on the baseline and the 6.4
  lane. Steps it marks "unverified" (Windows and the C shim) are verified in the Frost VM
  where they can be, or recorded as still unverified.
- Its Step 10.1 (nested view lists in layout containers) must land before the merged
  plan's first demo step (Phase 6), and its Step 10.3 (Examples in CI) before demos move
  into `Examples/`.
- Acceptance: plan 034 has status `complete`, and the Phase 1 check matrix passes on every
  lane.

## Phase 5 — Repository conventions

**Goal**: Tessera follows the conventions the owner uses in `~/.dotfiles`, Lattice, and
Ternbook: unwrapped prose, project memory in an IWE workspace, mise and hk for tools,
tasks, and hooks, self-contained VM tasks, and current build dependencies. Do the steps in
order; Steps 5.2 to 5.4 belong in one pass because each touches most Markdown files.

### Step 5.1 — Set the Swift line width to 90

- `CONTRIBUTING.md:189` says a 90-character soft limit and a 150-character hard limit;
  `.swift-format:3` sets 91 and has since the file was added in `33399be`, with no
  recorded reason; SwiftLint's `line_length` is disabled (`.swiftlint.yml:26`), so nothing
  enforces 150. Lattice uses 90.
- Change: 90 in `.swift-format`, and drop the unenforced hard limit from
  `CONTRIBUTING.md`. Apply with `just quality format` as its own commit.
- Unwrapped prose (Step 5.4) does not apply to Swift code, which keeps a formatter width.
- Acceptance: the docs and `.swift-format` agree, and `just quality lint` passes.

### Step 5.2 — Move project docs into an IWE workspace with slug-named plans

- Models: `~/.dotfiles/docs` (hubs `architecture`, `plans`, `backlog`, `someday`, `bugs`,
  plus `index.md` and `log.md`, with a schema per kind in `docs/.iwe/schemas/`) and
  Lattice's `docs/` (`research/`, `design/`, `decisions/`, `plans/`). The planning
  philosophy is `~/.dotfiles/docs/architecture/planning.md`: a plan is a living document
  with Progress (evidence on every checked box), a `Next:` handoff line, Approach,
  vertical Slices, Acceptance, and append-only Decisions, Discoveries, and Outcome; stages
  `proposed`, `planned`, `active`, `done` (with `completed`), `cancelled`; plans stay
  under about 300 lines; a commissioned question is a plan whose Outcome is the answer.
- Layout:
  - `docs/plans/` from `.agents/plans/`, slug filenames (for example
    `terminal-io-concurrency-review-fixes.md`).
  - `docs/research/` from `.agents/investigations/`, slug filenames. It holds research
    records and surveys; new commissioned questions become plans.
  - `docs/design/` from `design/` (the catalog, tokens, templates, and translation key).
  - `docs/architecture/` for durable decisions, as in the dotfiles, where plans promote
    their decisions when they close.
  - `docs/spec/` for the split spec (Step 5.3).
  - `docs/guides/` (new) for contributor how-tos: `WindowsFrostVM.md`, `WindowsVM.md`,
    `LocalDevelopmentState.md`, and `UpdatingGhosttyVT.md`.
  - `docs/ProjectStatus.md` stays a public page linked from `README.md`, under a slug
    name.
  - Hub pages for each directory, plus `index.md` and `log.md`. `docs/plans.md` carries
    the order, stage, and the active plan, rendered from plan frontmatter as in the
    dotfiles (`scripts/plans.py`, checked by hk). It also keeps a one-time table from each
    old plan number to its slug, so "plan 032" in commit messages and older notes still
    resolves.
- Plan frontmatter: map `status` to `stage` (planning and in-review → proposed, pending →
  planned, in-progress → active, complete → done, superseded → cancelled with a link to
  its successor). Completed plans move as they are, apart from frontmatter and links; plan
  034 is complete by then (Phase 4) and moves as a completed plan. This plan and the
  merged plan (Phase 6) take the dotfiles template.
- Agent files:
  - `.pi/prompts/` → `.agents/commands/`, and delete `.agents/prompts/`, which holds only
    a `.gitkeep`. omp reads non-recursive `.agents/commands/*.md` and
    `.agent/commands/*.md` from the working directory up to the repository root, the
    harness-neutral location among its providers (omp's slash-command docs); Claude Code
    reads `.claude/commands/`, which can be a symlink to it if wanted. Convert each prompt
    to frontmatter `description` and `argument-hint`, with `$ARGUMENTS` or `$1`, `$2`
    replacing the hand-filled `<kind>/<name>` placeholders.
  - Update the repository's own `planning`, `investigations`, and `design-catalog` skills
    in `.agents/skills/` to the new layout and workflow; contributors' agents rely on
    them.
  - `.omp/rules/` stays.
- Change: move and rename with `git mv` in a commit of pure renames, then a second commit
  that adds the workspace files and fixes every reference: links,
  `scripts/check-wireframes.py` and `just quality wireframes` (both read `design`), the
  codespell paths in `justfiles/quality.just:39`, and the skills and commands above.
  `iwe normalize` deletes HTML blocks, so replace the `<!-- Allowed status values -->`
  comments with schema fields first.
- Update `AGENTS.md` (project memory, search, and recording rules, as in the owner's
  global `AGENTS.md`) and `CONTRIBUTING.md`.
- Acceptance: `iwe find` and `iwe retrieve` work from `docs/`, `docs/plans.md` lists every
  plan in order with its stage, the wireframe check passes on `docs/design`, the commands
  appear in omp's slash menu, and no link points at an old path.

### Step 5.3 — Split the spec into workspace pages

- `docs/Spec.md` is 9,133 lines under twelve `##` sections; Phase 2 (lines 714-3650),
  Phase 3 (3651-6822), and Phase 4 (6823-8699) are each about 1,900 to 3,200 lines, and 89
  files mention `Spec.md`.
- Recommended: a `docs/spec.md` hub that keeps the framing, "How to use this spec", and
  the ordered table of contents, with one page per section under `docs/spec/` (the two
  theses, each phase, the risk register, and the module layout), and the three large
  phases split again by their `###` sections into `docs/spec/phase-2/` and so on. IWE can
  then retrieve one section by key, and links point at headings instead of line numbers.
- Living documents (open plans, skills, `AGENTS.md`, `CONTRIBUTING.md`, DocC) convert
  `docs/Spec.md:NNNN` citations to page links. Completed plans and research keep their
  line citations, which stay valid at the commit they cite; the hub says so.
- "Open question for Phase N" entries stay in the spec until decided, then move to
  `docs/architecture/` like other decisions.
- Acceptance: the hub lists every page in the original order; concatenating the pages in
  hub order reproduces the original text apart from headings and links; no living document
  cites `Spec.md` by line.

### Step 5.4 — Unwrap prose and lint Markdown with rumdl

- Rule, from `~/.dotfiles/AGENTS.md:41`, `~/.dotfiles/.rumdl.toml`, and Lattice's
  `.rumdl.toml`: one paragraph per line; line length is not a gate.
- Tooling: rumdl replaces markdownlint-cli2 and Prettier for Markdown, starting from
  Lattice's `.rumdl.toml` (it disables MD003, MD013, MD025, MD049, and MD052, and explains
  why). Prettier also formats other files today (`package.json`, `format:markup` is
  `prettier --write .`); cover YAML, JSON, and TOML the way the dotfiles do (`hk.pkl` uses
  yamllint, for example), and keep Prettier only for a file type nothing else covers, with
  the reason recorded.
- Unwrapping: the first commit of this step runs the repository's pinned Prettier with
  prose wrapping off over every Markdown file
  (`node_modules/.bin/prettier --prose-wrap never --write "**/*.md"`; `.prettierrc` sets
  `proseWrap: "always"` today), including DocC catalogs and the spec pages. A second
  commit removes Prettier's Markdown role and adds rumdl. `CHANGELOG.md` is already one
  physical line per entry. Swift doc comments keep the Swift width. After both commits,
  `just quality wireframes` (the fenced wireframes in `docs/design/`), the release-notes
  tests (`scripts/test_release_notes.py`), and codespell must still pass.
- Update `AGENTS.md` (its "validate with `pnpx markdownlint-cli`" instruction becomes the
  rumdl command), `CONTRIBUTING.md`, and `scripts/check-markup.sh`.
- Acceptance: rumdl passes on the whole tree, and a spot check of a spec page, one design
  doc, and one DocC article shows no hard-wrapped paragraphs.

### Step 5.5 — Replace `just` with mise and Lefthook with hk

- Rule, from `~/.dotfiles/docs/architecture/mise-management.md`: mise tasks only; do not
  carry `just` forward unless a mise task cannot express a required operation.
- Inventory to port: the `ci`, `core`, `docs`, `linux`, `quality`, `setup`,
  `windows-frost`, and `windows-utm` modules in `justfiles/`; CI's `just` installs and
  calls (`.github/workflows/ci.yml:117-129`, `:222-230`; `docs.yml:91-99`;
  `pages.yml:47-53`); `lefthook.yml`; the `Brewfile`; the project-local Python environment
  for quality tools; the pinned npm markup tools; swiftly for `just core install-swift`;
  and zig, cmake, and ninja for `libghostty-vt`.
- Completion: mise completes tasks in fish, which `just` users rely on. Checked 2026-10-21
  with mise 2026.10.13 in `~/.dotfiles`: `mise run vm:<Tab>` lists task names with their
  descriptions; `mise run completions <Tab>` offers the `refresh` and `status` choices and
  `--<Tab>` the flags, both declared with `#USAGE` lines in the task file. So every
  Tessera task declares a description and `#USAGE` arguments, and arguments with dynamic
  values (for example the example names `just core example` prompts for) use a usage
  `complete` directive that runs a command (to verify when written).
- Tool versions: latest, locked in `mise.lock` and upgraded with `mise upgrade`, for
  rumdl, hk, Node (still needed for `node --test` in `just quality vouch`), Python and uv,
  codespell, cmake, ninja, SwiftLint, and the linters Step 5.4 adds. Exceptions, each with
  its reason in `mise.toml`: zig matches what the pinned `libghostty-vt` requires (Step
  5.7); swift-format matches the baseline toolchain (or comes from it), so CI and local
  runs format alike; Swift itself stays with Xcode on macOS (`DEVELOPER_DIR` for Xcode
  26.6 in mise `[env]`) and swiftly on Linux and Windows, reading `.swift-version`.
- Hooks: an `hk.pkl` replaces `lefthook.yml`, keeping the Conventional Commit validation
  and the changed-file quality gate, modeled on the dotfiles `hk.pkl`. Set
  `core.hooksPath` in `../.bare/config` back to the default (it points at a missing
  `.githooks` today) so hk's hooks run, and keep the owner's commit-msg config hook
  working.
- CI: install mise with `jdx/mise-action`, pinned to a full commit SHA as the repository
  requires (`CONTRIBUTING.md:291-293`). The owner added `jdx/mise-action@*` to the allowed
  actions on 2026-10-21; the latest release then was `v5.2.2`, commit
  `8418fedb1110381a0d3ba51a7a415d7c1b884550` (re-check for a newer release when the step
  runs). Add it to the reviewed-actions list in `CONTRIBUTING.md`, and once `just` is
  gone, drop the `taiki-e/install-action` steps and tell the owner that pattern can leave
  the allow-list.
- Contributors: `mise install` then one setup task is the whole bootstrap; nothing depends
  on the owner's dotfiles.
- Acceptance: every recipe has a mise task or a recorded reason for removal; `Justfile`,
  `justfiles/`, and `lefthook.yml` are gone; CI uses mise; fish completes every task and
  its arguments; `CONTRIBUTING.md`, `AGENTS.md`, and the docs name the new commands; the
  Phase 1 check matrix passes through them.

### Step 5.6 — Give Tessera its own Tart and Lima VM tasks

- Tessera ships its own VM tasks and scripts; nothing calls the owner's dotfiles. Port the
  useful shape of `~/.dotfiles/scripts/vm.py` and its `vm:*` tasks (create, clone, start,
  stop, ssh, status, delete; persistent guest checkouts), using its defaults so the
  owner's disks line up: `~/.local/share/vms/<manager>/`, `TART_HOME` and command-local
  `LIMA_HOME`, bases named `base-<os>-<version>`, and instances named
  `<project>-<os>[-<arch>][-<role>]`, each overridable by environment variable
  (`~/.dotfiles/docs/architecture/vm-storage.md`).
- macOS (new): a macOS 26 guest with Xcode 26.6 runs the baseline on a real macOS 26
  system, and a macOS 27 guest with Xcode 27 serves the 6.4 lane. Base source (owner
  decision): Cirrus Labs vanilla images plus a scripted Xcode install, one code path for
  both guests: `ghcr.io/cirruslabs/macos-tahoe-vanilla:26.6.2` with Xcode 26.6, and
  `ghcr.io/cirruslabs/macos-golden-gate-vanilla:27.0` with Xcode 27.1.
  - Contributor path: `xcodes`, which needs the contributor's Apple Account to download
    Xcode; document the Apple Account step.
  - Host-sourced path, used by the overnight run and by anyone with Xcode already
    installed: copy the host's `/Applications/Xcode-26.6.0.app` (or `Xcode-27.1.0.app`)
    into the guest over a `tart run --dir` share, so no Apple Account sign-in is needed.
  - Both paths script license acceptance (`xcodebuild -license accept`) and first launch
    (`xcodebuild -runFirstLaunch`).
  - Rejected (checked 2026-10-21): `macos-tahoe-xcode` has no `26.6` tag (its newest Xcode
    26 is `26.5`, about 69 GB compressed), and `macos-runner:tahoe` carries Xcode 26.6
    among eleven Xcodes at about 225 GB compressed.
- Linux: Tessera already has its own Lima config
  (`scripts/config/lima/tessera-linux.yaml`, `scripts/linux-test.sh`); move it to the same
  layout and naming. The dotfiles log records that the owner's Tessera Lima instances were
  already moved to `~/.local/share/vms/lima`, so confirm the new tasks find them.
- Windows: Frost and UTM are already self-contained; only their recipes move to mise tasks
  (Step 5.5).
- Acceptance: on a machine without the owner's dotfiles (a fresh macOS guest is enough),
  the documented tasks create the VMs and run the Phase 1 check matrix, including macOS
  core tests inside the macOS 26 guest.

### Step 5.7 — Update libghostty-vt and Zig

- Today (checked 2026-10-21): `scripts/ghostty-vt-version.txt` pins Ghostty `ae52f97`
  (2026-05-25), whose `build.zig.zon` sets `minimum_zig_version` to 0.15.2, matching the
  Zig 0.15.2 in `scripts/config/lima/tessera-linux.yaml:57` and the `zig@0.15` Homebrew
  installs in CI. Ghostty moved to Zig 0.16.0 in `e8525c0fd` (2026-07-21) and ported its
  build to Zig 0.17 in `aa57f1f41` (2026-10-20); its `main` now requires 0.17.0, and Zig
  0.17.0 is released.
- Target: the newest Ghostty commit whose `libghostty-vt` builds and passes on all three
  platforms with the newest Zig it supports. Try 0.17 first; fall back to the last 0.16
  commit if the day-old 0.17 port is not stable, and record why. Five months of C API
  drift since `ae52f97` will likely need source changes in
  `Sources/TesseraTerminalSnapshotSupport/VirtualTerminal+Ghostty.swift` and
  `GhosttyKeyEncoder.swift`, not only snapshot updates. Work on `plan-035-zig` (see
  Overnight execution).
- Follow `docs/guides/` `UpdatingGhosttyVT` (moved in Step 5.2). Consumers: the version
  file, the mise zig pin, the Lima provisioning, CI's Zig installs in `ci.yml`,
  `docs.yml`, and `pages.yml`, and the Frost artifact (`build-ghostty`).
- Acceptance: the Phase 1 check matrix passes on every lane with the new pin;
  Ghostty-backed snapshot tests are unchanged, or each changed snapshot is explained by a
  Ghostty change.

## Phase 6 — Merge plans 032 and 033

**Goal**: one plan for the Phase 4 view layer and its developer tooling, written in the
Phase 5 format with a slug name, ready for the return to feature work.

### Step 6.1 — Write the merged plan

- Inputs: plan 032 (Phases 1-7 complete; Phases 8-17 open) and plan 033 (developer
  tooling, with its decisions, owner feedback, and spike evidence).
- Fold in the amendments plan 033 needs from plan 032, from the 2026-10-20 review note
  (finding R-10 in plan 034): the headless driver lives in the harness library
  (`TesseraHarness`, root-package test support) and each demo declares its viewports (032
  Step 8.2); each acceptance in 032 Phases 10-14 gains "and its scenario corpus passes
  under `tessera-dev run`"; 032 Step 10.1 wires the dead `focusChanges` counter
  (`Sources/TesseraCore/Diagnostics/GraphStatistics.swift:51`); the role and label hook
  (033 G.1) lands before the first control (032 Step 13.1); the environment clock is a
  `Clock` the harness can advance, so `wait`, `settle`, and motion are testable (032 Step
  16.1; the spec's Phase 5 open question on injected clocks, `docs/Spec.md:8759-8762`
  today, leaves the mechanism open, and the clock seam in spike commit `30e4bbf` only
  feeds pass durations).
- Dependencies to carry: plan 034 Step 10.1 before the first demo on stacks; plan 034 Step
  10.3 before demos live in `Examples/`; the seams patch from Step 3.3.
- Acceptance: one plan, in `docs/plans/` and listed in `docs/plans.md`, following the
  dotfiles template, with a single slice order that covers every open step of both plans;
  the owner reviews it before work resumes.

### Step 6.2 — Owner decision: the `mobile` viewport rule, then apply it

- The rule: `design/tokens.md:24` and `design/README.md:62-66` (under `docs/design/` after
  Step 5.2) wireframe components at 40 columns and their natural height, with 40x16 only
  for screen-filling compositions (owner decision, 2026-10-10). Still contradicting it:
  `design/templates/widget.md:38` (`mobile (40x16)` required for `wireframed`), plan 032
  Step 8.2 (lines 609-610, acceptance line 623), and `design/widgets/stepper.md:138`.
  `design/widgets/list.md:186` uses 40x16, which holds if List counts as screen-filling.
- Plan 033 decision 1 recommends natural height with sizes declared per demo, a
  package-level nil-height probe, and an error that points height-greedy demos
  (`ScrollView`, `SplitView`) at a `mobileScreen` (40x16) viewport.
- Acceptance: the decision is recorded in the merged plan, and the template, the merged
  plan's demo slice, and the widget docs agree with it; the wireframe check passes.

### Step 6.3 — Retire plans 032 and 033

- Set both to `cancelled` with a link to the merged plan (the `superseded` status before
  Step 5.2), and update `docs/plans.md` and the links to them.
- Acceptance: no open step remains only in a retired plan.

## References

- Plan 034, `.agents/plans/034-terminal-io-concurrency-review-fixes.md`, including its
  Repository review findings (R-01 to R-12).
- Plan 032, `.agents/plans/032-omp2-reference-gallery-and-phase-4-redesign.md`.
- Plan 033 and spikes: branch `devtools-plan` (`8ee4c59`); seams branch
  `devtools-seams-spike` (`30e4bbf`).
- `CONTRIBUTING.md`: Cross-platform testing (lines 223-271) and Repository governance.
- `.swift-version` (6.3.2 today), `Package.swift:1` (tools version 6.3),
  `Package.swift:13` (macOS 26 floor).
- Owner conventions: `~/.dotfiles/AGENTS.md`, `~/.dotfiles/.rumdl.toml`,
  `~/.dotfiles/hk.pkl`, `~/.dotfiles/scripts/vm.py`, and in
  `~/.dotfiles/docs/architecture/`: `planning.md`, `mise-management.md`, `vm-storage.md`;
  `~/Developer/robfeldmann/lattice/main/docs/.iwe/` and its `.rumdl.toml` and
  `.swift-format`.
- omp slash-command discovery: the `agents` provider (`.agent/` and `.agents/commands/`),
  in omp's `slash-command-internals` documentation.
