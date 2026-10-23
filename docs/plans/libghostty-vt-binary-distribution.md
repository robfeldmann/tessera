---
type: plan
stage: active
created: 2026-10-22
order: 38
description: Ship libghostty-vt as a prebuilt SE-0482 static-library artifact bundle that Tessera's CI builds once per Ghostty pin, so apps can depend on Tessera by version and no build or test job runs Zig.
---

# Ship libghostty-vt as a prebuilt binary

Goal: an app that depends on Tessera by version links libghostty-vt on macOS, Linux, and Windows without Zig, CMake, or a local build, and Tessera's own test, docs, and VM jobs stop building Zig. Tessera's CI builds the pinned revision once into an SE-0482 static-library artifact bundle, publishes it as a prerelease asset, and `Package.swift` references it by URL and checksum. You see it when a CI job consumes Tessera by version from a clean machine and runs a Ghostty round trip, and when no test job's log mentions Zig.

## Progress

- [x] 1 Commit the headers and add a local bundle mode — `1febb03`. `TESSERA_GHOSTTY_VT_BUNDLE=local swift test --filter TesseraTerminalSnapshotSupportTests`: 15 tests passed on macOS (Xcode 26.6), in the Lima guest on 6.3.3 and 6.4.1, and in the UTM Windows guest (6.3.3, `windows-arm64`). `swift package dump-package | grep -c unsafeFlags` is 0 in local mode on macOS and Windows and 1 in the default mode (`swift package describe` omits linker settings in both modes, so it cannot show the difference). The default mode's full `swift test` (Xcode 26.6): 662 tests passed.
- [ ] 2 Producer workflow and the first published bundle
- [ ] 3 Switch the package to the published bundle
- [ ] 4 Stop building Zig in test, docs, and VM jobs
- [ ] 5 Consume Tessera by version in CI
- [ ] 6 Docs, decision record, and closure

Next: Slice 2. Validate `.github/workflows/ghostty-vt.yml` through its `pull_request` trigger on the draft pull request before pushing the one authorized tag, `ghostty-vt-f54340ad7781`.

## Approach

Current state. `CGhosttyVT` (`Sources/CGhosttyVT/`: `CGhosttyVT.h`, `module.modulemap`, `shim.c`) links a libghostty-vt that each machine builds with Zig 0.17.0 from the pin in `scripts/ghostty-vt-version.txt` (`f54340ad`) through `scripts/build-libghostty-vt.sh` and `.ps1`, into `~/.cache/tessera/libghostty-vt/<rev>/<platform>-<arch>/` (Windows `%LOCALAPPDATA%\tessera\libghostty-vt`). `Package.swift:520-593` computes that path and passes it in `.unsafeFlags` with an absolute rpath; the build scripts copy Ghostty's headers into `Sources/CGhosttyVT/include/ghostty/`, which `.gitignore` excludes. Every consumer of the build runs the Zig step first: the `core:build`, `core:test`, `core:test-coverage`, `docs:targets`, and `ci:build-test` mise tasks, the `test` and `test-parallel` jobs in `.github/workflows/ci.yml`, `docs.yml`, `pages.yml`, the Lima tasks (`scripts/vm.py:653`), and the Windows guest (`scripts/run-windows-tests.ps1`).

End state. The headers are committed. `CGhosttyVT` stays a source C target and depends on a `binaryTarget(name: "GhosttyVTLibrary", url:, checksum:)` whose artifact bundle carries only `libghostty-vt.a` (or `ghostty-vt-static.lib`) per triple, plus `.linkedLibrary("ntdll", .when(platforms: [.windows]))`. No `.unsafeFlags` remain. A workflow, `.github/workflows/ghostty-vt.yml`, builds every variant on hosted runners when a `ghostty-vt-<short-sha>` tag is pushed and publishes the zip and its checksum to a prerelease of that tag. Contributors who bump the pin build a bundle locally with one script and select it with an environment variable until the new release exists. A CI job consumes Tessera by version through a `file://` git tag and runs a Ghostty round trip on all three platforms.

Patterns to follow. The spike in `spikes/GhosttyDistribution/` (tag `0.3.x` patches) and its research record, [libghostty-vt distribution](../research/libghostty-vt-distribution.md), are the reference layout; Findings §5 there lists the build flags each platform needs (`-Dsimd=false` on Windows, `-Dcpu=baseline` on Linux). Reuse the existing build scripts as the one way to compile libghostty-vt; the new packaging script only arranges their output. Workflow steps pin actions by SHA, as the existing workflows do. The bundle's `info.json` follows SE-0482's `staticLibrary` artifact type, with Ghostty's `LICENSE` beside the libraries.

Patterns to avoid. Headers or a module map inside the bundle (fails on Xcode 26.6 and Swift Build 6.3.3, research §4). Committing binaries to the repository. A second way to compile libghostty-vt. Keeping `.unsafeFlags` as a fallback path.

Files that orient a newcomer. `Package.swift` (the `CGhosttyVT` and `GhosttyVT*` blocks), `scripts/build-libghostty-vt.sh`, `scripts/build-libghostty-vt.ps1`, `scripts/ghostty-vt-version.txt`, `.github/workflows/ci.yml` (the `test` job's Ghostty steps), [Updating Ghostty VT](../guides/updating-ghostty-vt.md), and the research record.

Non-goals. Making the Ghostty-backed harness optional (the research's runner-up). Upstreaming anything to Ghostty. Changing the Ghostty pin. Releasing a Tessera version.

## Slices

### 1 Commit the headers and add a local bundle mode

Commit Ghostty's headers for the pin under `Sources/CGhosttyVT/include/ghostty/` and drop that `.gitignore` entry; the build scripts stop copying headers and instead fail when the committed headers differ from the pinned checkout's, naming the files. Add `scripts/package-libghostty-vt-bundle.sh` (and a `.ps1` for Windows variants) that turns the build scripts' installed library into a `GhosttyVTLibrary.artifactbundle` variant directory and writes or merges its `info.json`. Add a manifest mode selected by `TESSERA_GHOSTTY_VT_BUNDLE=local`: `binaryTarget(path: ".build/ghostty-vt/GhosttyVTLibrary.artifactbundle")` (the path must lie inside the package), with `CGhosttyVT` depending on it and the `ntdll` linked library; the default mode stays today's `.unsafeFlags` path until Slice 3.

Delivers: the package builds and tests from a locally packaged bundle with no `.unsafeFlags` on macOS, in the Lima guest, and in the UTM Windows guest. Verify: on each, build the library with the existing script, package it, then `TESSERA_GHOSTTY_VT_BUNDLE=local swift test --filter TesseraTerminalSnapshotSupportTests` passes; `swift package describe` in that mode shows no unsafe flags; the default mode's full `swift test` still passes.

### 2 Producer workflow and the first published bundle

`.github/workflows/ghostty-vt.yml`, triggered by pushing a tag matching `ghostty-vt-*` and by `workflow_dispatch`. It checks that the tag names the first 12 characters of `scripts/ghostty-vt-version.txt` at the tagged commit, then builds each variant with the existing scripts and Slice 1's packaging script:

| Triple | Runner | Notes |
| --- | --- | --- |
| `arm64-apple-macosx`, `x86_64-apple-macosx` | `macos-26` | one universal `.a` through `lipo`, or two variants |
| `x86_64-unknown-linux-gnu`, `aarch64-unknown-linux-gnu` | `ubuntu-latest`, `ubuntu-24.04-arm` | target an older glibc through Zig (for example `-Dtarget=<arch>-linux-gnu.2.31`); record the floor reached |
| `x86_64-swift-linux-musl`, `aarch64-swift-linux-musl` | `ubuntu-latest` | for the Static Linux SDK (`mise run linux:build`) |
| `x86_64-unknown-windows-msvc`, `aarch64-unknown-windows-msvc` | `windows-latest`, `windows-11-arm` | `ghostty-vt-static.lib` |

A final job assembles one bundle with Ghostty's `LICENSE`, runs `swift package experimental-audit-binary-artifact` on Linux for each Linux variant, zips it, computes `swift package compute-checksum`, and creates a prerelease named for the tag with the zip and a `checksum.txt`, marked not latest (`make_latest: false`) so it never becomes the repository's latest release; Tessera's own releases stay `v<SemVer>` tags, which `.github/workflows/release.yml` already requires. Pushing the tag for the current pin publishes the first bundle.

Delivers: a public prerelease `ghostty-vt-f54340ad7781` with `GhosttyVTLibrary.artifactbundle.zip` and its checksum. Verify: the workflow run is green on every leg; `curl -L` of the asset URL from a clean shell downloads a zip whose checksum matches `checksum.txt`; the record of each variant's glibc floor (`objdump -T … | grep GLIBC_` maximum) is in Discoveries. A variant that cannot be built is recorded in Discoveries with its first error and left out of the bundle, and Slice 5 tests only what shipped.

### 3 Switch the package to the published bundle

The default manifest mode becomes `binaryTarget(url:checksum:)` pointing at Slice 2's asset; the URL and checksum live in one place in `Package.swift`, next to a comment naming the workflow that produces them. Delete the `.unsafeFlags`, output-root, platform, and arch logic (`Package.swift:520-593`). `TESSERA_GHOSTTY_VT_BUNDLE=local` stays as the pin-bump path.

Delivers: a clean clone with no Ghostty cache builds and tests. Verify: with `~/.cache/tessera/libghostty-vt` moved aside and `mise` Zig unavailable on `PATH`, `swift test` passes on macOS (Xcode 26.6 and 27.1), in the Lima guest (6.3.3 and 6.4.1), and in the UTM Windows guest; `rg unsafeFlags Package.swift` finds nothing; `mise run linux:build` passes (or the musl gap is recorded per Slice 2).

### 4 Stop building Zig in test, docs, and VM jobs

Remove the Ghostty build, cache restore, and cache save steps from the `test` and `test-parallel` jobs in `ci.yml`, from `docs.yml`, and from `pages.yml`; drop the Zig prerequisites (`mise-action` stays if other tools need it; the Linux apt list loses what only the Ghostty build used). Remove `core:build-libghostty-vt` from the `depends` and bodies of `core:build`, `core:test`, `core:test-coverage`, `docs:targets`, and `ci:build-test`; it stays as the producer and pin-bump task. The Lima tasks and `scripts/run-windows-tests.ps1` stop building Ghostty and setting `GHOSTTY_VT_OUTPUT_DIR`; Zig stays in `mise.toml` and the guests' provisioning for pin bumps only.

Delivers: no test, docs, or VM run builds Zig. Verify: CI on the branch is green on every leg and `gh run view --log` for the `test` jobs contains no `zig build`; Windows test wall time drops (record before and after); `mise run vm:linux-test` and `mise run vm:windows-test` pass without building Ghostty.

### 5 Consume Tessera by version in CI

A fixture package under `Tests/Fixtures/VersionConsumer/` (outside the root package's targets) depends on Tessera through `.package(url: "file://<tmp clone>", from: "0.0.0-ci")` and uses `TesseraTerminalSnapshotSupport` in an executable and a Swift Testing test that feed `hello\r\n\e[31mred\e[0m` to `VirtualTerminal.ghostty(cols: 20, rows: 3)` and assert the rows, `cell(1,0)`, and the cursor, as the spike's consumers did. A `version-consumer` CI job on macOS, Linux, and Windows clones the checkout to a temporary directory, tags it `0.0.0-ci`, builds and tests the fixture, and asserts Zig is not on `PATH`. Required on all three platforms, like the `test` matrix.

Delivers: proof that an app depending on Tessera by version links libghostty-vt from the published bundle. Verify: the job is green on all three platforms; a probe commit that breaks the checksum makes it fail, then is reverted.

### 6 Docs, decision record, and closure

Rewrite [Updating Ghostty VT](../guides/updating-ghostty-vt.md) around the new flow: bump the pin, re-vendor the headers, build locally and test with `TESSERA_GHOSTTY_VT_BUNDLE=local`, push the `ghostty-vt-*` tag, then update the URL and checksum. Update `CONTRIBUTING.md`, `README.md`, `DevTools/README.md`, [Local development state](../guides/local-development-state.md), and [Windows VM](../guides/windows-vm.md) where they say a build needs Zig. Write `docs/architecture/libghostty-vt-distribution.md` (the rule and why) and list it in `docs/architecture.md`. Record in [plan 036](phase-4-view-layer-and-developer-tooling.md) that Decision 9 (ii) is taken and implemented by this plan. Add the changelog's unreleased note.

Delivers: a contributor can bump the pin from the guide alone. Verify: `mise run quality:format`, the full `swift test`, `mise run quality:lint`, and `mise run docs:lint` pass; CI is green on every job.

## Overnight execution

Rules for an agent running this plan unattended.

- Branch: the plan, its research record, and the spike live on the docs branch `docs/phase-4-tooling-architecture` (its pull request targets `main`). Create `ghostty-vt-binary` from that branch in a new worktree (`git worktree add ../ghostty-vt-binary -b ghostty-vt-binary origin/docs/phase-4-tooling-architecture`), and do all work there; the `main` worktree is not touched. Commit at least once per slice with Conventional Commit messages. Push after each slice and keep one draft pull request from `ghostty-vt-binary` open, titled `build(ghostty-vt): ship libghostty-vt as a prebuilt binary`, targeting `docs/phase-4-tooling-architecture` until that pull request merges and `main` afterwards, so CI runs.
- Never: push to `main`, merge a pull request, force-push, delete a branch, worktree, tag, or release, change repository settings or rulesets, or change the Ghostty pin.
- Publishing: the owner authorized (2026-10-22) exactly one tag push and one prerelease, `ghostty-vt-f54340ad7781`, created by the Slice 2 workflow and marked not latest. If that release needs fixing, re-run the workflow for the same tag (the workflow may replace its own assets); do not create other tags or releases.
- Checks before each commit: the `AGENTS.md` gate, `mise run quality:format`, the full `swift test` on the baseline toolchain (`DEVELOPER_DIR=/Applications/Xcode-26.6.0.app/Contents/Developer`), and `mise run quality:lint`; add `mise run docs:lint` when DocC or public API changes. mise is not activated in a plain shell; use `mise exec --` or `mise run`.
- VMs: the Lima guest `tessera-linux` and the UTM guest `tessera-windows-11` are available; start them with `mise run vm:linux-start` and `mise run vm:windows-start`, deliver the worktree with the `*-push` tasks, and leave them running at the end.
- CI waits: watch runs with `gh run watch` or `gh run view`; a hosted-runner flake (a cancelled leg, a runner that never starts) is retried once with `gh run rerun --failed` and recorded in Discoveries.
- Handoff: after each slice, check its box only with evidence on the line (a SHA, a run ID, a command and its result) and update `Next:`. The run will outlast one context; the plan is the handoff.
- Stuck: before recording a slice or a bundle variant as blocked, spawn an `architect` agent at medium effort with the slice, what was tried, and the first error, and try what it proposes. Record its advice and the result in Discoveries either way.
- Blocked slices: record what was tried, the architect's advice, and the first error in the slice, leave the box unchecked, and continue with the next slice that does not depend on it. A bundle variant that still fails is left out of the bundle and recorded, and the slice continues. Slice 3 depends on Slice 2's release; Slice 4 depends on Slice 3; Slices 5 and 6 depend on Slice 3.
- Left for the owner: reviewing and merging the pull request.

## Acceptance

- [ ] A clean machine with no Zig builds Tessera and runs a Ghostty round trip from a package that depends on Tessera by version, on macOS, Linux, and Windows, in CI.
- [ ] `Package.swift` contains no `.unsafeFlags`, and the Ghostty headers are committed.
- [ ] No test, docs, or VM job builds Zig; only the producer workflow and the local pin-bump path do.
- [ ] The published bundle covers macOS (arm64 and x86_64), Linux gnu and musl (x86_64 and aarch64), and Windows (x86_64 and aarch64), or each missing variant is recorded with its first error.
- [ ] A contributor can bump the pin from [Updating Ghostty VT](../guides/updating-ghostty-vt.md) alone.

## Decisions

- 2026-10-22 Ship libghostty-vt as an SE-0482 static-library artifact bundle with the headers committed in a source `CGhosttyVT`, built by Tessera's CI once per pin and published as a release asset, because no upstream artifact covers Linux and Windows and the spike proved this layout by version on all three platforms. (owner, from [libghostty-vt distribution](../research/libghostty-vt-distribution.md); plan 036 Decision 9 (ii))
- 2026-10-22 The bundle is published from this repository as `ghostty-vt-<short-sha>` prereleases marked not latest, beside Tessera's own `v<SemVer>` releases, rather than from a separate repository, because tags and releases are independent on GitHub and one repository keeps the producer workflow, the pin, and the manifest's URL in one change. The owner authorized the first tag and prerelease for an unattended run. (owner)
- 2026-10-22 The build scripts re-vendor the committed headers with `--update-headers` (`-UpdateHeaders` on Windows), and `build-libghostty-vt.sh` takes `--target <zig-target>` for the cross-built variants (macOS x86_64, a glibc floor, musl), because the plan keeps the build scripts the one way to compile libghostty-vt and its Slice 6 flow needs a re-vendor step. Variant directories are named by the build scripts' install labels (`macos-universal`, `linux-arm64`, `linux-musl-x86_64`, `windows-arm64`, …), and the packaging scripts regenerate `info.json` from the directories a bundle holds, so merging needs no JSON parser. (agent)
- 2026-10-22 `ghostty-vt.yml` also runs on pull requests that touch the producer (build, package, and audit, never publish), because `workflow_dispatch` only works once the workflow is on `main` and the one authorized tag cannot be moved, so the workflow had to be proven before the tag was pushed. (agent)

## Discoveries

None yet.

## Outcome

Not started.

## References

- [libghostty-vt distribution](../research/libghostty-vt-distribution.md) and `spikes/GhosttyDistribution/`.
- [Updating Ghostty VT](../guides/updating-ghostty-vt.md), [Windows libghostty-vt snapshot build spike](../research/windows-libghostty-vt-snapshot-spike.md), and [Ghostty VT snapshot harness closeout](../research/ghostty-vt-snapshot-harness-closeout.md).
- [Build the Phase 4 view layer with the tooling that proves it](phase-4-view-layer-and-developer-tooling.md), Decision 9.
- SE-0482, [swift-package-manager#8657](https://github.com/swiftlang/swift-package-manager/issues/8657).
