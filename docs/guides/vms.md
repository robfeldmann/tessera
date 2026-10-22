---
type: guide
description: "Tessera's macOS (Tart), Linux (Lima), and Windows (UTM) VMs: storage, names, Xcode in macOS bases, and the vm: tasks"
---

# Tessera VMs

Tessera tests on clean systems from a Mac. `scripts/vm.py` drives three guests through the `vm:` tasks:

| Guest | Manager | Tasks | Runs |
| --- | --- | --- | --- |
| macOS | [Tart](https://tart.run/) | `vm:macos-*` | the whole check matrix with only the lane's Xcode installed |
| Linux | [Lima](https://lima-vm.io/) | `vm:linux-*` | the Linux suite |
| Windows 11 ARM64 | [UTM](https://mac.getutm.app/) | `vm:windows-*` | the Windows suite ([Windows VM with UTM](windows-vm.md)) |

Requirements: an Apple silicon Mac, `mise install` (it provides Tart, with the rest of the tools in `mise.toml`), and `brew bundle install` (it provides Lima and UTM).

## Storage

VM disks live outside the repository and outside the managers' defaults, one directory per manager:

| Manager | Directory | Override |
| --- | --- | --- |
| Tart | `~/.local/share/vms/tart/` | `TART_HOME` |
| Lima | `~/.local/share/vms/lima/` | `LIMA_HOME` |

The tasks set `TART_HOME` and `LIMA_HOME` for their own commands only, so running `tart` or `limactl` by hand still uses your own setting (`~/.tart` and `~/.lima` unless you export these variables). Export the variable in your shell to keep the disks somewhere else, and use the same value when you call the manager directly, for example `TART_HOME=~/.local/share/vms/tart tart list`. The disks are reproducible from these tasks, so the directory is a good candidate for excluding from backups.

A macOS base is the vanilla image (about 25 GB on disk) plus Xcode; work instances are APFS clones of it and only claim what they change. `mise run vm:status` lists the Tart, Lima, and UTM guests. UTM keeps the Windows guest's bundle in its own documents folder; see the [Windows guide](windows-vm.md).

## Names

Bases are named `base-<os>-<version>` and are never started after they are built; work instances are cloned from them and named `<project>-<os>[-<arch>][-<role>]`. Tessera's macOS bases include the Xcode version, so they never collide with plain `base-macos-<version>` bases built for other purposes.

| Lane | Base | Instance | Toolchain |
| --- | --- | --- | --- |
| Baseline | `base-macos-26.6.2-xcode-26.6` | `tessera-macos-26` | Xcode 26.6 (`swiftlang-6.3.3`) |
| Swift 6.4 | `base-macos-27.0-xcode-27.1` | `tessera-macos-27` | Xcode 27.1 |
| Linux | none (provisioned from `scripts/config/lima/tessera-linux.yaml`) | `tessera-linux` | swiftly, both lanes |

Environment variables override the names: `TESSERA_MACOS_BASE` (the base that `vm:macos-base` builds and `vm:macos-clone` copies), `TESSERA_MACOS_VM_NAME` (the instance `vm:macos-clone` creates), and `TESSERA_LINUX_VM_NAME` (the Lima instance, for example one per worktree).

## macOS bases

A base starts from a Cirrus Labs vanilla image, which has user `admin` with password `admin`, SSH on, and passwordless sudo, and gets Xcode installed by script:

```sh
mise run vm:macos-base 26 --xcode host     # macOS 26.6.2 with Xcode 26.6
mise run vm:macos-base 27 --xcode host     # macOS 27.0 with Xcode 27.1
```

The task clones `ghcr.io/cirruslabs/macos-tahoe-vanilla:26.6.2` (26) or `ghcr.io/cirruslabs/macos-golden-gate-vanilla:27.0` (27); the first pull is tens of GB. It starts the clone headless, authorizes the VM key with the default password on first contact, installs mise, installs Xcode, selects it, accepts the license, runs `xcodebuild -runFirstLaunch`, and shuts the base down. If any step fails, the partial base is deleted; the pulled image stays in Tart's cache, so a retry starts quickly.

Xcode comes from one of two places:

- `--xcode host` (the default) copies this Mac's Xcode into the guest over a read-only Tart directory share: `/Applications/Xcode-26.6.0.app` or `/Applications/Xcode_26.6.app` for 26, `/Applications/Xcode-27.1.0.app` or `/Applications/Xcode_27.1.app` for 27. No Apple Account is involved. An Xcode that has been used can hold files its own builds left inside the bundle (`*.dependency-scan.dia` next to `SWBBuildService`), which its signature does not cover; the task removes them from the copy, because Gatekeeper would otherwise hold the first launch at a prompt nobody can answer in a headless guest. Any other signature difference stops the task.
- `--xcode xcodes` runs [`xcodes`](https://github.com/XcodesOrg/xcodes) in the guest to download Xcode from Apple. Apple only serves Xcode to a signed-in Apple Account, so the task runs interactively and `xcodes` asks for your Apple Account email, password, and two-factor code (or reads `XCODES_USERNAME` and `XCODES_PASSWORD` from the guest environment). The task signs `xcodes` out afterwards, so the base and its clones keep no credentials.

Either way the guest's Xcode is `/Applications/Xcode-<version>.0.app`, which is where `mise.toml` looks for the baseline.

## Work instances

```sh
mise run vm:macos-clone 26                 # clone tessera-macos-26 from its base (stopped)
mise run vm:macos-start tessera-macos-26   # headless; waits for SSH
mise run vm:macos-push tessera-macos-26    # deliver the working tree to ~/tessera
mise run vm:macos-check tessera-macos-26   # run the check matrix in the guest
mise run vm:macos-ssh tessera-macos-26     # a shell; or append a command to run it
mise run vm:macos-stop tessera-macos-26
mise run vm:macos-delete tessera-macos-26  # bases are refused
```

`vm:macos-push`, `vm:macos-check`, and `vm:macos-ssh` start the instance when it is stopped and leave it running; stop it with `vm:macos-stop`.

`vm:macos-push` sends what `git ls-files --cached --others --exclude-standard` lists (tracked files plus untracked files that are not ignored) and extracts it into `~/tessera`, the guest's persistent checkout. That checkout is a Git repository whose index records the last delivery: the next push removes paths the host no longer has, and the repository's scripts that call `git rev-parse` work. Ignored paths such as `.build` and `node_modules` stay in the guest between pushes, so builds there are incremental. Edits made in the guest are overwritten by the next push. `vm:windows-push` works the same way for the Windows guest.

`vm:macos-check` runs, in the guest's checkout, `mise install`, `npm ci`, `swift --version`, then `mise run ci:check` (the full suite and the portable quality gate), `mise run docs:lint`, and `mise run core:examples`. Output streams to your terminal, and the task exits with the guest's status.

## SSH

The tasks reach guests with a dedicated key, `~/.ssh/tessera-vm`, generated on first use; your own identity keys are never offered to a VM. Each Tessera instance has a host alias in a generated config, `~/.config/tessera/vm-ssh.config`, that resolves the VM's address with `tart ip`. Host keys are recorded per VM name in `~/.config/tessera/vm-known-hosts` and forgotten when an instance is cloned or deleted. Nothing edits `~/.ssh/config`; to use the aliases with plain `ssh` or `scp`, pass the config, or add an `Include` line for it to `~/.ssh/config` yourself:

```sh
ssh -F ~/.config/tessera/vm-ssh.config tessera-macos-26
```

The `admin` password stays `admin`, which is acceptable for a VM on the host's private NAT network and not for anything reachable from elsewhere.

## Linux (Lima)

```sh
mise run vm:linux-start                    # create or start tessera-linux for this checkout
mise run vm:linux-test                     # full Linux suite; stops the VM again if it started it
mise run vm:linux-test -- --filter PlatformHandlesTests
mise run vm:linux-ssh                      # a shell; or append a command to run it
mise run vm:linux-stop
mise run vm:linux-delete
```

`linux:start`, `linux:test`, `linux:stop`, `linux:shell`, and `linux:delete` remain as aliases. The Linux VM mounts the host checkout instead of holding a copy: when it is stopped and mounts another checkout, `vm:linux-test` re-points it at the current one with `limactl edit`, which keeps its toolchains and caches; when it is running for another checkout, the task stops. `TESSERA_LINUX_SWIFT_VERSION` picks the Swift release for one run ([Toolchain lanes](../../CONTRIBUTING.md#toolchain-lanes)).

Lima instances created before these tasks live in `~/.lima`. Either delete the old one (`LIMA_HOME=~/.lima limactl delete tessera-linux`) and let `vm:linux-test` create a new one under `~/.local/share/vms/lima/`, or keep using it by exporting `LIMA_HOME=~/.lima`.

## Windows (UTM)

```sh
mise run vm:windows-push                   # deliver the working tree to the guest
mise run vm:windows-test                   # full Windows suite
mise run vm:windows-test -- --filter WindowsInputLoopTests
mise run vm:windows-stop --quit            # shut the guest down and quit UTM
```

The guest is a UTM VM named `tessera-windows-11` (or the one `tessera-*` bundle UTM has), with its bundle in UTM's documents folder and its snapshots under `~/.local/share/vms/utm/`. Creating it from an ISO or an existing bundle, provisioning it, snapshots, SSH, and troubleshooting are in [Windows VM with UTM](windows-vm.md).
