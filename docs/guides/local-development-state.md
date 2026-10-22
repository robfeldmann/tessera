---
type: guide
description: "Local Development State"
---

# Local Development State

Tessera uses three different kinds of local state. Keeping them separate makes multiple branches and worktrees predictable.

## Quick diagnosis

Run:

```sh
mise run core:doctor
```

This prints the active checkout, the pinned Ghostty VT revision, the Ghostty VT cache path, the Lima VM name and mount, and the Windows Frost image paths. `mise run vm:status` lists the Tart and Lima VMs.

## Toolchains

`.swift-version` (6.3.3) is the baseline every lane must pass; Swift 6.4 is a second lane. On macOS the baseline is Xcode 26.6, selected with `DEVELOPER_DIR` when another Xcode is active; the Lima VM keeps both toolchains under swiftly and `TESSERA_LINUX_SWIFT_VERSION` picks one per run; the Windows VMs carry the baseline only. See [Toolchain lanes](../../CONTRIBUTING.md#toolchain-lanes).

## Ghostty VT

`TesseraTerminalSnapshotSupport` links against Ghostty's `libghostty-vt` on macOS and Linux. Windows currently skips this target dependency until the Windows `libghostty-vt` build path is proven.

The pin lives in:

```text
scripts/ghostty-vt-version.txt
```

`mise run core:build`, `mise run core:test`, the `docs:` tasks, and the `ci:` tasks all run `mise run core:build-libghostty-vt` first. Direct `swift build` does not build the C library for you; run `mise run core:build-libghostty-vt` once first if the cache is missing.

By default, the Ghostty VT build is shared by every Tessera checkout on the machine:

```text
${XDG_CACHE_HOME:-~/.cache}/tessera/libghostty-vt/<revision>/<platform>-<arch>/
```

That location is deliberate:

- `mise run core:clean` removes only this checkout's `.build` directory.
- switching branches keeps using the same Ghostty VT artifact when the pinned revision did not change.
- different branches can keep different pinned revisions side by side.
- different worktrees do not each clone and rebuild Ghostty.

Override the cache when needed:

```sh
env GHOSTTY_VT_OUTPUT_DIR=/tmp/tessera-libghostty-vt mise run core:build-libghostty-vt
```

Remove the shared cache explicitly:

```sh
mise run core:clean-libghostty-vt
```

## Linux

There are two Linux paths:

1. `mise run linux:build` uses Swift's Static Linux SDK from macOS. The SDK is installed into the active Swift toolchain, not into this repository.
2. `mise run vm:linux-test` uses a Lima VM so tests run on an actual Linux userspace.

The Static Linux SDK metadata lives in `scripts/config/swift-sdks.json`, keyed by Swift version. `scripts/linux-sdk-version.sh` picks the entry that matches the active compiler (`swift --version`), because the SDK must match the compiler that uses it, and falls back to `.swift-version` when the active compiler has no entry. Updating the baseline Swift means adding an entry here and updating `.swift-version` together.

The default Lima VM name is `tessera-linux`, and its disk lives under `~/.local/share/vms/lima/`: the VM tasks set `LIMA_HOME` for their own commands only, so other Lima users keep their default. [Tessera VMs](vms.md) has the storage, naming, and move details.

A Lima VM mounts one checkout path. If you want multiple worktrees active at the same time, give each worktree its own VM name:

```sh
env TESSERA_LINUX_VM_NAME=tessera-linux-slice6 mise run vm:linux-test
```

Forward focused SwiftPM test arguments after `--` when you do not need the full Linux suite:

```sh
mise run vm:linux-test -- --filter PlatformHandlesTests
```

If the VM is stopped and mounts a different checkout, `mise run vm:linux-test` re-points it at the current one (`limactl edit`), keeping its toolchains and caches. If it is running for another checkout, the task stops instead of silently testing the wrong tree.

You usually do not need to rebuild the Linux VM after switching branches. Rebuild or delete it when `.swift-version`, `scripts/config/lima/tessera-linux.yaml`, or the Linux package prerequisites change.

## macOS VMs

A macOS work instance (`tessera-macos-26`, `tessera-macos-27`) does not mount the host checkout. `mise run vm:macos-push` delivers the working tree to `~/tessera` in the guest, which keeps its own `.build` and libghostty-vt cache between runs, so that state is VM-local. The disks live under `~/.local/share/vms/tart/`; see [Tessera VMs](vms.md).

## Windows Frost

Frost is the recommended Windows workflow. Tessera keeps the generated VM images outside the repository:

```text
${XDG_STATE_HOME:-~/.local/state}/tessera/windows-frost/
```

That directory contains VM artifacts, not a Git clone:

- `disks/base-win11.qcow2` and `disks/base-win11-vars.fd`: the base Windows image.
- `disks/tessera-win11.qcow2` and `disks/tessera-win11-vars.fd`: the Swift/toolchain image.
- `run/`: disposable overlays and runtime files.
- `persistent/`: the optional interactive VM overlay.
- `source/tessera-source.tar.gz`: the latest Mac-to-Windows source snapshot.

`mise run windows-frost:test` creates a disposable overlay, archives the current macOS working tree, copies that archive into the guest, extracts it to `C:\Users\tester\tessera`, runs `swift test --no-parallel` plus any forwarded SwiftPM test args, then deletes the disposable overlay. The guest source tree is a snapshot, not a clone, and `.git` is not copied.

Forward focused SwiftPM test arguments after `--` when you do not need the full Frost suite:

```sh
mise run windows-frost:test -- --filter WindowsInputLoopTests
```

You usually do not need to rebuild the Windows images after switching branches. Rebuild the base image when the Windows/VirtIO inputs change. Rebuild the toolchain image when Swift, Visual Studio, the Windows SDK, or the provisioning scripts change.

## Manual Windows UTM

The manual UTM workflow is different: the Windows VM owns a normal Git checkout and its own `.build`. Use:

```sh
mise run windows-utm:sync
mise run windows-utm:test
```

Forward focused SwiftPM test arguments after `--` when you do not need the full UTM suite:

```sh
mise run windows-utm:test -- --filter WindowsConsoleModeTests
```

`mise run windows-utm:sync` force-pushes your current branch into the guest checkout with `receive.denyCurrentBranch=updateInstead`. The guest tree must be clean.
