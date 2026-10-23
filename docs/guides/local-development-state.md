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

This prints the active checkout, the pinned Ghostty VT revision, the Ghostty VT cache path, the Lima VM name and mount, and the UTM Windows guest. `mise run vm:status` lists the Tart, Lima, and UTM guests.

## Toolchains

`.swift-version` (6.3.3) is the baseline every lane must pass; Swift 6.4 is a second lane. On macOS the baseline is Xcode 26.6, selected with `DEVELOPER_DIR` when another Xcode is active; the Lima VM keeps both toolchains under swiftly and `TESSERA_LINUX_SWIFT_VERSION` picks one per run; the Windows guest carries the baseline only. See [Toolchain lanes](../../CONTRIBUTING.md#toolchain-lanes).

## Ghostty VT

`TesseraTerminalSnapshotSupport` links Ghostty's `libghostty-vt` on macOS, Linux, and Windows from a prebuilt artifact bundle: `Package.swift`'s `GhosttyVTLibrary` binary target downloads it from the `ghostty-vt-<revision prefix>` release into `.build/artifacts` (SwiftPM keeps a copy in its own cache), and the headers are committed under `Sources/CGhosttyVT/include/ghostty/`. A plain `swift build` or `swift test` needs no Zig, CMake, or Ninja. On Linux, SwiftPM needs `unzip` to unpack the bundle.

The pin lives in:

```text
scripts/ghostty-vt-version.txt
```

Only a pin bump builds Ghostty locally ([Updating Ghostty VT](updating-ghostty-vt.md)). `mise run core:build-libghostty-vt` installs that build in a cache shared by every Tessera checkout on the machine, so worktrees do not each clone and rebuild Ghostty, and different branches can keep different pins side by side:

```text
${XDG_CACHE_HOME:-~/.cache}/tessera/libghostty-vt/<revision>/<variant>/
```

`scripts/package-libghostty-vt-bundle.sh` copies the build into `.build/ghostty-vt/GhosttyVTLibrary.artifactbundle`, and `TESSERA_GHOSTTY_VT_BUNDLE=local` makes `Package.swift` link that bundle instead of the release. Override the cache with `GHOSTTY_VT_OUTPUT_DIR`, and remove it with:

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

A macOS work instance (`tessera-macos-26`, `tessera-macos-27`) does not mount the host checkout. `mise run vm:macos-push` delivers the working tree to `~/tessera` in the guest, which keeps its own `.build` between runs, so that state is VM-local. The disks live under `~/.local/share/vms/tart/`; see [Tessera VMs](vms.md).

## Windows (UTM)

The Windows guest is a UTM VM, so its state lives with UTM rather than in the repository:

- `/Applications/UTM.app` (installed by `brew bundle install`).
- `~/Library/Containers/com.utmapp.UTM/Data/Documents/tessera-*.utm`: the guest's bundles, disk included.
- `~/.local/share/vms/utm/<vm>/snapshots/<name>/`: APFS-clone snapshots of the stopped guest's `Data/` (`mise run vm:windows-snapshot <name>`).

`mise run core:doctor` prints UTM.app's presence, each `tessera-*` bundle, and its snapshots, and says how to create a guest when there is none. The guest owns a Git checkout at `C:\Users\tester\tessera` and its own `.build`, so that state is VM-local; `mise run vm:windows-push` delivers the working tree into it. Forward focused SwiftPM test arguments after `--`:

```sh
mise run vm:windows-push
mise run vm:windows-test -- --filter WindowsConsoleModeTests
```

Restore a snapshot (`mise run vm:windows-restore <name>`) to get a clean guest back, and rerun `mise run vm:windows-provision` when `.swift-version`, the pinned Zig, or `scripts/provision-windows-vm.ps1` change. [Windows VM with UTM](windows-vm.md) has the details.
