# Local Development State

Tessera uses three different kinds of local state. Keeping them separate makes multiple
branches and worktrees predictable.

## Quick diagnosis

Run:

```sh
just core doctor
```

This prints the active checkout, the pinned Ghostty VT revision, the Ghostty VT cache
path, the Lima VM name and mount, and the Windows Frost image paths.

## Ghostty VT

`TesseraTerminalSnapshotSupport` links against Ghostty's `libghostty-vt` on macOS and
Linux. Windows currently skips this target dependency until the Windows `libghostty-vt`
build path is proven.

The pin lives in:

```text
scripts/ghostty-vt-version.txt
```

`just core build`, `just core test`, `just docs`, and `just ci` all run
`just core build-libghostty-vt` first. Direct `swift build` does not build the C library
for you; run `just core build-libghostty-vt` once first if the cache is missing.

By default, the Ghostty VT build is shared by every Tessera checkout on the machine:

```text
${XDG_CACHE_HOME:-~/.cache}/tessera/libghostty-vt/<revision>/<platform>-<arch>/
```

That location is deliberate:

- `just core clean` removes only this checkout's `.build` directory.
- switching branches keeps using the same Ghostty VT artifact when the pinned revision did
  not change.
- different branches can keep different pinned revisions side by side.
- different worktrees do not each clone and rebuild Ghostty.

Override the cache when needed:

```sh
env GHOSTTY_VT_OUTPUT_DIR=/tmp/tessera-libghostty-vt just core build-libghostty-vt
```

Remove the shared cache explicitly:

```sh
just core clean-libghostty-vt
```

## Linux

There are two Linux paths:

1. `just linux build` uses Swift's Static Linux SDK from macOS. The SDK is installed into
   the active Swift toolchain, not into this repository.
2. `just linux test` uses a Lima VM so tests run on an actual Linux userspace.

The Static Linux SDK metadata lives in `scripts/config/swift-sdks.json` and is keyed by
`.swift-version`. Updating Swift means updating both files together.

The default Lima VM name is:

```text
tessera-linux
```

A Lima VM mounts one checkout path. If you want multiple worktrees active at the same
time, give each worktree its own VM name:

```sh
env TESSERA_LINUX_VM_NAME=tessera-linux-slice6 just linux test
```

If the VM is stopped and points at a different checkout, `just linux test` recreates it
for the current path. If it is running for another checkout, the recipe stops instead of
silently testing the wrong tree.

You usually do not need to rebuild the Linux VM after switching branches. Rebuild or
delete it when `.swift-version`, `scripts/config/lima/tessera-linux.yaml`, or the Linux
package prerequisites change.

## Windows Frost

Frost is the recommended Windows workflow. Tessera keeps the generated VM images outside
the repository:

```text
${XDG_STATE_HOME:-~/.local/state}/tessera/windows-frost/
```

That directory contains VM artifacts, not a Git clone:

- `disks/base-win11.qcow2` and `disks/base-win11-vars.fd`: the base Windows image.
- `disks/tessera-win11.qcow2` and `disks/tessera-win11-vars.fd`: the Swift/toolchain
  image.
- `run/`: disposable overlays and runtime files.
- `persistent/`: the optional interactive VM overlay.
- `source/tessera-source.tar.gz`: the latest Mac-to-Windows source snapshot.

`just windows-frost test` creates a disposable overlay, archives the current macOS working
tree, copies that archive into the guest, extracts it to `C:\Users\tester\tessera`, runs
`swift test --no-parallel`, then deletes the disposable overlay. The guest source tree is
a snapshot, not a clone, and `.git` is not copied.

You usually do not need to rebuild the Windows images after switching branches. Rebuild
the base image when the Windows/VirtIO inputs change. Rebuild the toolchain image when
Swift, Visual Studio, the Windows SDK, or the provisioning scripts change.

## Manual Windows UTM

The manual UTM workflow is different: the Windows VM owns a normal Git checkout and its
own `.build`. Use:

```sh
just windows-utm sync
just windows-utm test
```

`just windows-utm sync` force-pushes your current branch into the guest checkout with
`receive.denyCurrentBranch=updateInstead`. The guest tree must be clean.
