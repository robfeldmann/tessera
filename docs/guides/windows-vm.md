---
type: guide
description: "Windows VM with UTM: create or import the Windows 11 ARM64 guest, provision it, snapshot it, push the working tree, and run the tests"
---

# Windows VM with UTM

Metadata:

- Last verified: 2026-10-22
- Host macOS: 27.0.1
- UTM: 5.0.8
- Guest OS: Windows 11 ARM64 (aarch64)
- Swift: follows `.swift-version`, target `aarch64-unknown-windows-msvc`
- Default VM name: `tessera-windows-11`
- Guest user: `tester`

Tessera's Windows lane is a [UTM](https://mac.getutm.app/) guest driven by `scripts/vm.py` through the `vm:windows-*` mise tasks, the same way the macOS (Tart) and Linux (Lima) guests are driven ([Tessera VMs](vms.md)). The path through this guide runs from an ISO or an existing UTM bundle to a passing test run:

```sh
mise run vm:windows-create --import <bundle.utm>    # or --disk <image.qcow2>, or UTM's wizard
mise run vm:windows-provision                       # toolchain, OpenSSH, key, guest tools
mise run vm:windows-stop
mise run vm:windows-snapshot provisioned            # a known-good state to return to
mise run vm:windows-push                            # deliver the working tree
mise run vm:windows-test                            # swift test --no-parallel in the guest
mise run vm:windows-stop --quit                     # nothing runs between sessions
```

Every task takes `--name <vm>` to pick a guest; see [Selecting a guest](#selecting-a-guest).

## Prerequisites

- An Apple silicon Mac and `brew bundle install` from the repository root, which installs UTM (`/Applications/UTM.app`).
- A source for the guest, one of:
  - a Windows 11 ARM64 ISO (from <https://www.microsoft.com/software-download/windows11arm64>, **Windows 11 (multi-edition ISO for Arm64)**; verify it with `shasum -a 256`, because Microsoft's PowerShell instructions do not apply on macOS),
  - an existing UTM bundle (`*.utm`) of a Windows 11 ARM64 guest, or
  - a qcow2 disk image with Windows 11 ARM64 already installed.
- Tens of GB of free disk space. UTM keeps the guest in its documents folder, `~/Library/Containers/com.utmapp.UTM/Data/Documents/`.

## Create or import the guest

UTM discovers bundles only when it launches, so `windows-create` quits UTM first when no guest is running and refuses to continue when one is. Both import paths use APFS clones when the source is on the same volume, which makes them instant and shares blocks until the copies diverge.

### From an existing bundle

```sh
mise run vm:windows-create --import ~/path/to/existing.utm
```

This copies the bundle into UTM's documents folder as `tessera-windows-11.utm` with a fresh UUID and MAC address, so the copy and the original can run side by side. Pass `--name <vm>` to choose another name; start it with `tessera-` so that the single-bundle default and the generated SSH config find the guest.

### From a disk image

```sh
mise run vm:windows-create --disk ~/path/to/windows.qcow2
```

This wraps a qcow2 disk that already has Windows installed in the template `scripts/config/utm/windows-11-arm64.plist`: aarch64 `virt` machine, 4 CPUs, 8 GiB of memory, an NVMe disk, virtio network on the shared network, a TPM, UEFI, and virtio-ramfb display.

### From an ISO

A new install from a Windows ISO stays in UTM's own wizard, clicked through once:

1. Open UTM and choose **Create a New Virtual Machine**, then **Virtualize**, then **Windows**.
2. Memory **8192 MB**, CPU cores **4**, a boot ISO image pointing at the Windows ARM64 ISO, and **Install drivers and SPICE tools** enabled if UTM offers it.
3. Storage **80 GB**, no shared directory, and the name **tessera-windows-11**.
4. Save, start the VM, and install Windows (Windows 11 Pro if offered). During reboots, when `Press any key to boot...` appears again, press nothing so the VM boots from its disk.
5. Create a local user named **tester** with a real password. Windows OpenSSH rejects blank passwords.
6. Quit UTM so the new bundle is on disk in its final state, then continue with the first boot.

If the first boot lands in `UEFI Interactive Shell`, type `exit` at the `Shell>` prompt, pick the USB hard drive entry that carries the installer ISO in Boot Manager, and press Enter when `Press any key to boot...` appears.

## First boot: the one manual step

A freshly installed guest has no SSH server, so Windows needs one manual step. `mise run vm:windows-provision` starts the guest and, when SSH does not answer, stops and prints this command. Run it in the guest, in a PowerShell opened as Administrator:

```powershell
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0; Set-Service sshd -StartupType Automatic; Start-Service sshd
```

Enabling OpenSSH can look stuck for a few minutes; wait for it. A guest that already runs SSH skips this step.

## Provision

```sh
mise run vm:windows-provision
```

On the first run the task asks for `tester`'s password: the copy of the provisioning script and its first run each prompt until the host key `~/.ssh/tessera-vm` (generated on first use) is installed. After that, SSH uses the key.

The script, `scripts/provision-windows-vm.ps1`, converges the guest on the toolchain the checkout names:

- OpenSSH Server, with the firewall rule and the host key in `C:\ProgramData\ssh\administrators_authorized_keys`.
- `PasswordNeverExpires` for the account (see [Troubleshooting](#troubleshooting)).
- Developer Mode, so symlinks need no elevation.
- Git 2.54 (the arm64 installer).
- Visual Studio 2022 Community with the Desktop C++ workload and the Windows 11 SDK 26100.
- The Swift toolchain named by `.swift-version` (the swift.org ARM64 installer).
- Zig at the version `mise.toml` pins, under `%LOCALAPPDATA%\Programs\zig\zig-aarch64-windows-<version>\`, where `scripts/build-libghostty-vt.ps1` looks for it. Only a Ghostty pin bump uses it ([Updating Ghostty VT](updating-ghostty-vt.md)); builds and tests link the published libghostty-vt bundle.
- The UTM guest tools, from an ISO (downloaded from getutm.app) that the script mounts in the guest.

Every step checks before it installs, so provisioning is idempotent: rerun it after `.swift-version` or the pinned Zig changes, and a run with nothing to do makes no changes (about 9 seconds). Visual Studio usually leaves a reboot pending. Over SSH the script then exits with code 100 and `vm.py` reboots the guest and runs it again, up to five passes. Run from a console by hand, the script registers a one-time logon task and reboots itself instead.

The guest's log is `C:\ProgramData\Tessera\Provision\provision-windows-vm.log`. A successful run ends with `vm: <name> is provisioned (Swift <version>, Zig <version>)`.

## Snapshot after provisioning

Provisioning is the slow part (Visual Studio dominates it), so keep the result:

```sh
mise run vm:windows-stop
mise run vm:windows-snapshot provisioned     # no name lists the snapshots
```

A snapshot clones the stopped guest's `Data/` folder (disk, firmware variables, TPM state) to `~/.local/share/vms/utm/<vm>/snapshots/<name>/` with APFS clonefile, so it is instant and shares its blocks until the guest diverges. UTM's bundled `qemu-img` is a library, not a command, so qcow2-internal snapshots are not used.

To put the guest back to a snapshot:

```sh
mise run vm:windows-stop
mise run vm:windows-restore provisioned
```

Both tasks refuse to run while the guest is started. This is how the lane stays disposable: a run that leaves the guest in a bad state costs one `windows-restore`, not a reinstall. A snapshot is never overwritten, so after provisioning again with a new toolchain, take a new one under a new name.

## Push and test

```sh
mise run vm:windows-push
mise run vm:windows-test
mise run vm:windows-test -- --filter WindowsInputLoopTests
```

`vm:windows-push` starts the guest when it is stopped, then delivers what `git ls-files --cached --others --exclude-standard` lists as a tar.gz over `scp` into `C:\Users\tester\tessera`. That checkout is a Git index of the last delivery, so files you removed on the host disappear in the guest, while ignored paths such as `.build` stay and keep builds incremental. Edits made in the guest are overwritten by the next push.

`vm:windows-test` runs `scripts/run-windows-tests.ps1` in the guest, which runs `swift test --no-parallel` with the arguments after `--`; the package links libghostty-vt from the published artifact bundle, so nothing is built with Zig. The task exits with Swift's status. `vm:windows-test` does not push; run `vm:windows-push` first. `windows:test` and `windows-utm:test` remain as aliases, and `windows-utm:sync` for `vm:windows-push`.

## ConPTY smoke

```sh
mise run vm:windows-conpty-smoke
```

This prints ANSI-colored lines and a cursor save and restore through a real ConPTY (`ssh -tt`, wrapped in `script` when stdin is not a terminal), which shows whether escape sequences survive the round trip. For GUI validation, open the guest in UTM and run a demo in Windows Terminal, PowerShell in classic conhost, and `cmd.exe` ([CONTRIBUTING](../../CONTRIBUTING.md#windows)).

## SSH and IP

```sh
mise run vm:windows-ip                       # the guest's IPv4 address
mise run vm:windows-ssh                      # a shell
mise run vm:windows-ssh -- swift --version   # or one command
```

`vm:windows-ssh` starts the guest, waits for SSH, and opens a shell or runs the command. `vm:windows-ip` asks `utmctl ip-address` while UTM runs and the guest is started (this needs the guest tools), and otherwise reads the guest's lease from `/var/db/dhcpd_leases` by the MAC address in the bundle's `config.plist`, which also works while UTM is quit.

The tasks write `~/.config/tessera/vm-ssh.config` with a `Host <vm>` entry for each UTM guest (user `tester`, the key `~/.ssh/tessera-vm`, and `~/.ssh/tessera_windows` too when that file exists). The entry's `ProxyCommand` resolves the address through `vm.py windows-ip` on every connection, so plain `ssh` and `scp` work from any shell without knowing the address:

```sh
ssh -F ~/.config/tessera/vm-ssh.config tessera-windows-11
```

Nothing edits `~/.ssh/config`; add an `Include` line for the generated file yourself if you want the alias everywhere. Host keys are recorded per guest in `~/.config/tessera/vm-known-hosts`.

## Start and stop

```sh
mise run vm:windows-start
mise run vm:windows-stop                     # shutdown over SSH, else a UTM stop request
mise run vm:windows-stop --force             # power off
mise run vm:windows-stop --quit              # shut down, then quit UTM.app
```

`vm:windows-start` launches UTM.app when needed, activates it once and hands focus back to the app you were using (about a second), and returns when `utmctl status` says `started` (about 8 seconds). The push, test, ssh, and smoke tasks start the guest themselves and leave it running. End a session with `vm:windows-stop --quit` so nothing keeps running between sessions. `mise run vm:windows-delete` removes the stopped guest's bundle, and `mise run vm:status` lists the Tart, Lima, and UTM guests; with UTM quit it reads the bundles instead of launching it.

## Selecting a guest

A task picks its guest in this order:

1. `--name <vm>`, for example `mise run vm:windows-stop --name tessera-windows-11-fresh`. `vm:windows-ssh` and `vm:windows-test` pass everything after the task name to the guest, but a leading `--name <vm>` is still taken: `mise run vm:windows-test --name tessera-windows-11-fresh -- --filter WindowsInputLoopTests`.
2. `TESSERA_WINDOWS_VM_NAME`, for example `TESSERA_WINDOWS_VM_NAME=tessera-windows-11-fresh mise run vm:windows-test`.
3. `tessera-windows-11`, or when no bundle has that name and exactly one `tessera-*.utm` bundle exists in UTM's documents folder, that bundle, so a guest imported under another name needs no flag.

With several `tessera-*` bundles and none named `tessera-windows-11`, name the guest you mean.

## Leftover state from the previous workflow

Tessera's earlier Windows workflow kept disk images under `~/.local/state/tessera/windows-frost/`. Nothing reads that directory any more; delete it by hand when you no longer need those images.

## Troubleshooting

### `utmctl start` hangs for two minutes and fails with `OSStatus -1712`

UTM answers Apple Events only after it has been activated once since it launched. A launch nobody activated (the Apple Event from `utmctl` itself, `open -g`, `open -gj`, the `utm://` URL scheme) never is, so every `utmctl start` and `stop` afterwards hangs. `vm.py` activates UTM itself with `open -a UTM` and then returns focus to the previous app; do not launch UTM with `open -g` before the tasks. When it happens anyway, run `mise run vm:windows-stop --quit` and retry.

### `utmctl --hide` prints `OSStatus -10004` twice

It is harmless noise (UTM issue 5509), and the tasks never pass `--hide`.

### macOS asks whether to let the terminal control UTM

`utmctl` talks to UTM through Apple Events, which macOS gates with an Automation grant for the responsible app. Grants are per responsible app, not per terminal: when an agent runs under herdr, macOS attributes the request to `com.robfeldmann.herdr`, so herdr needs its own Automation grant for UTM. Approve it once under System Settings, Privacy and Security, Automation.

### SSH refuses the password after a few weeks

Windows expires local passwords after 42 days, after which sshd rejects the password and only a console sign-in can set a new one. `windows-provision` sets `PasswordNeverExpires`, but a guest provisioned before that, or a base image that ages while stored, needs one console sign-in in UTM to set a new password, then `mise run vm:windows-provision` once more.

### `windows-stop` does not stop the guest

Windows now and then ignores UTM's ACPI shutdown request, which is why `windows-stop` runs `shutdown /s /f /t 0` over SSH when SSH answers. If the guest is wedged, use `mise run vm:windows-stop --force`.

### UTM does not show the new bundle

UTM scans its documents folder only when it launches. `windows-create` quits UTM for that reason; if you copy a bundle there by hand, quit and reopen UTM.

### `no address for <vm>`

The guest has not booted on this host yet, or its DHCP lease expired and UTM is quit. Start it with `mise run vm:windows-start`; once the guest tools run in the guest, `utmctl ip-address` answers too.

### Port 22 is unreachable

From an administrator PowerShell in the guest:

```powershell
Get-NetConnectionProfile
Get-Service sshd
Get-NetTCPConnection -LocalPort 22 -State Listen
Get-NetFirewallRule -Name OpenSSH-Server-In-TCP | Format-List Name,Enabled,Direction,Action,Profile
```

When the network category is `Public`, make the rule apply to every profile with `Set-NetFirewallRule -Name OpenSSH-Server-In-TCP -Profile Any`. `windows-provision` does this already.
