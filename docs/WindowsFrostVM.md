# Windows VM with Frost

Metadata:

- Last updated: 2026-06-17
- Guest OS: Windows 11 ARM64
- Guest architecture: ARM64 / aarch64
- Swift: follows `.swift-version`
- Recommended Windows user: `tester`

This guide walks through the recommended scripted Windows VM workflow for Tessera on an
Apple Silicon Mac. It uses [Frost](https://github.com/solcreek/frost) to build a Windows
11 ARM64 image, boot throwaway test VMs, run commands over SSH, and optionally import the
same image into UTM for manual GUI checks.

If you prefer to create and manage a Windows VM by hand, use the manual UTM guide in
`docs/WindowsVM.md` instead.

## What this workflow gives you

Frost creates a repeatable Windows test environment from files you download locally:

1. A **base Windows golden image** with Windows, VirtIO networking, and OpenSSH.
2. A **Tessera toolchain golden image** with Git, Visual Studio C++ tools, Windows SDK,
   Swift, SSH key auth, Developer Mode, and PowerShell defaults.
3. A **disposable test VM** for clean `swift test` runs.
4. A **persistent SSH VM** for interactive terminal work and retained SwiftPM build cache.
5. An optional **UTM GUI VM** for PowerShell/Windows Terminal visual validation.

The VM images are local build artifacts under `.build/windows-frost/` and are not checked
into Git.

## Quick setup for experienced contributors

Install host tools:

```fish
brew bundle install
```

Clone Frost outside this repository:

```fish
mkdir -p ~/Developer/solcreek
git clone https://github.com/solcreek/frost ~/Developer/solcreek/frost/main
```

Download:

- Windows 11 ARM64 ISO from Microsoft.
- VirtIO Windows driver ISO, for example `virtio-win-*.iso`.

Then build and verify:

```fish
env \
  TESSERA_FROST_WINDOWS_ISO=~/Downloads/Win11_ARM64.iso \
  TESSERA_FROST_VIRTIO_ISO=~/Downloads/virtio-win.iso \
  just windows-frost-build-base

just windows-frost-check-base
just windows-frost-provision-toolchain
just windows-frost-check-toolchain
just test-windows-frost
```

Use the longer tutorial below if any of those terms or files are unfamiliar.

## 1. Install macOS prerequisites

Install the project Homebrew dependencies:

```fish
brew bundle install
```

This installs the VM tools used by this workflow, including QEMU, `swtpm`, `sshpass`, UTM,
and `just`.

Check that the host tools are available:

```fish
just windows-frost-doctor
```

If Frost has not been cloned yet, this check will report that separately.

## 2. Clone Frost

Keep Frost outside the Tessera repository while this integration uses wrapper scripts. The
default path expected by the scripts is:

```text
~/Developer/solcreek/frost/main
```

Clone it with:

```fish
mkdir -p ~/Developer/solcreek
git clone https://github.com/solcreek/frost ~/Developer/solcreek/frost/main
```

If you keep Frost somewhere else, pass the path per command:

```fish
env TESSERA_FROST_ROOT=/path/to/frost just windows-frost-doctor
```

You do not need to set a permanent shell variable unless you want to.

## 3. Download the required ISO files

Frost does not redistribute Windows or VirtIO drivers. You need two local ISO files.

### Windows 11 ARM64 ISO

1. Open <https://www.microsoft.com/software-download/windows11arm64>.
2. Select **Windows 11 (multi-edition ISO for Arm64)**.
3. Select your product language.
4. Download the ISO.

Save it somewhere easy to reference, for example:

```text
~/Downloads/Win11_ARM64.iso
```

### VirtIO Windows driver ISO

Frost needs VirtIO drivers so the Windows guest can use QEMU's virtual network device
during provisioning.

Download a `virtio-win-*.iso` that includes ARM64 `NetKVM` drivers. One source is Fedora's
VirtIO Windows driver downloads:

```text
https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/
```

Save it somewhere easy to reference, for example:

```text
~/Downloads/virtio-win.iso
```

## 4. Build the base Windows image

The first build creates a base Windows image. It can take a while because Windows is being
installed unattended.

Run:

```fish
env \
  TESSERA_FROST_WINDOWS_ISO=~/Downloads/Win11_ARM64.iso \
  TESSERA_FROST_VIRTIO_ISO=~/Downloads/virtio-win.iso \
  just windows-frost-build-base
```

If you need to rebuild the base image later:

```fish
env \
  TESSERA_FROST_WINDOWS_ISO=~/Downloads/Win11_ARM64.iso \
  TESSERA_FROST_VIRTIO_ISO=~/Downloads/virtio-win.iso \
  just windows-frost-build-base --force
```

Verify the base image boots and accepts SSH:

```fish
just windows-frost-check-base
```

This boots a disposable VM, runs `whoami`, prints guest output, and shuts the VM down.

## 5. Build the Tessera toolchain image

The base image only has Windows, networking, and OpenSSH. The next step creates a
Tessera-specific image with the build tools.

Run:

```fish
just windows-frost-provision-toolchain
```

This installs or configures:

- Git for Windows.
- Visual Studio C++ workload.
- Windows SDK.
- Swift matching `.swift-version`.
- OpenSSH key authentication.
- Windows Developer Mode for unprivileged symlinks.
- Git `core.symlinks=true`.
- PowerShell profiles that start in the user's home directory.

Visual Studio may require a reboot during provisioning. The host script handles this by
rebooting the guest, waiting for SSH, and continuing.

If you need to rebuild the toolchain image later:

```fish
just windows-frost-provision-toolchain --force
```

Verify the toolchain image:

```fish
just windows-frost-check-toolchain
```

This checks Git, Swift, Visual Studio, Windows SDK, password SSH, and key-based SSH.

## 6. Daily workflow: clean Windows test run

Use this when you want a repeatable Windows check from macOS:

```fish
just test-windows-frost
```

What happens:

1. A disposable overlay is created from the Tessera toolchain image.
2. The VM boots headlessly.
3. The current macOS working tree is copied into the Windows guest.
4. The guest runs `swift test --no-parallel`.
5. Guest output streams back to your macOS terminal.
6. The VM shuts down and the disposable overlay is deleted.

The sync is a one-way Mac → Windows snapshot. The macOS checkout is the source of truth.
Edits made inside the disposable Windows VM are not copied back.

## 7. Daily workflow: persistent interactive SSH VM

Use the persistent VM when you want an interactive Windows shell and retained build cache:

```fish
just windows-frost-start
just windows-frost-ssh
```

Inside the SSH session you can run normal Windows commands. When finished:

```fish
just windows-frost-stop
```

Reset the persistent overlay back to the Tessera toolchain image with:

```fish
just windows-frost-start --reset
```

The persistent overlay lives under:

```text
.build/windows-frost/persistent/dev.qcow2
```

For a quick ConPTY smoke check without opening an interactive shell:

```fish
just windows-frost-start
just windows-frost-conpty-smoke
just windows-frost-stop
```

## 8. Optional GUI workflow with UTM

Use UTM when you need to see Windows desktop behavior directly, such as PowerShell,
Windows Terminal, window resizing, or clipboard behavior.

### Create or update the UTM GUI VM

The current workflow creates a UTM VM named:

```text
tessera-frost-import
```

It is a normal UTM VM whose disk was created from the Frost toolchain image. If you need
to recreate it manually:

1. Convert the Frost toolchain image into a standalone qcow2.
2. Clone an existing Windows ARM UTM VM or create one with similar settings.
3. Replace the clone's NVMe qcow2 with the standalone Frost qcow2.
4. Copy the Frost UEFI vars file into the UTM bundle as `efi_vars.fd`.
5. Start the VM in UTM.

The default login is:

```text
user: tester
password: Test1234!
```

### Install or repair UTM guest tools

UTM guest tools are needed for dynamic resolution, clipboard sync, WebDAV sharing, and
QEMU guest-agent operations.

With the GUI VM running and reachable over SSH, install or repair the tools:

```fish
just windows-frost-install-utm-tools <vm-ip>
```

Then reboot the Windows guest from inside Windows. After reboot, verify:

- resizing the UTM window changes the Windows resolution.
- clipboard works from macOS → Windows.
- clipboard works from Windows → macOS.
- `utmctl ip-address tessera-frost-import` returns an IP address.

### Sync source into the GUI VM

The GUI VM is a toolchain image. It does not automatically contain your current source
changes. To copy your macOS working tree into it, first find the VM's IPv4 address inside
Windows:

```powershell
Get-NetIPAddress -AddressFamily IPv4 |
  Where-Object { $_.IPAddress -notlike "169.254.*" -and $_.IPAddress -ne "127.0.0.1" } |
  Select-Object -ExpandProperty IPAddress
```

Then run from macOS:

```fish
just windows-frost-sync-utm <vm-ip>
```

This copies the current working tree into:

```text
C:\Users\tester\tessera
```

This is a one-way Mac → Windows snapshot, not a two-way or real-time sync. Running the
sync again replaces the Windows copy. Do not make important edits inside the Windows copy
unless you manually copy them back.

The sync does not copy `.git`, so the destination is a source tree rather than a Git
checkout. That is expected.

If SSH reports that the host key changed, the VM probably reused an IP address from a
previous Windows VM. Remove the stale key and retry:

```fish
ssh-keygen -R <vm-ip>
```

After syncing, open PowerShell in the UTM VM:

```powershell
cd C:\Users\tester\tessera
swift test --no-parallel
```

## Troubleshooting

### `just windows-frost-doctor` cannot find Frost

Clone Frost to the default location:

```fish
mkdir -p ~/Developer/solcreek
git clone https://github.com/solcreek/frost ~/Developer/solcreek/frost/main
```

Or pass your custom path:

```fish
env TESSERA_FROST_ROOT=/path/to/frost just windows-frost-doctor
```

### Base image already exists

Rebuild with `--force`:

```fish
just windows-frost-build-base --force
```

### Toolchain image already exists

Rebuild with `--force`:

```fish
just windows-frost-provision-toolchain --force
```

### SSH says the remote host key changed

If the Windows VM reused an IP address from an older VM, clear the old key:

```fish
ssh-keygen -R <vm-ip>
```

The sync helpers use a temporary known-hosts file so they can tolerate this case.

### PowerShell starts in `C:\Windows\System32`

Run the GUI configuration helper:

```fish
just windows-frost-configure-gui <vm-ip>
```

Then close and reopen PowerShell.

### SwiftPM cannot create symlinks

Run the GUI configuration helper:

```fish
just windows-frost-configure-gui <vm-ip>
```

This enables Developer Mode and Git symlink support. You may need to delete `.build` and
rerun the build if a previous checkout failed halfway through.

## Integration notes

Tessera currently uses wrapper scripts around an external Frost checkout. Frost is not
vendored and is not a Git submodule.

Potential upstream Frost improvements identified while building this workflow:

- Create `work/disks` before disposable overlays are created.
- Add a configurable `FROST_WORK` directory.
- Use short runtime socket paths for `swtpm` and QEMU monitor sockets.
- Add a generic project customization command for creating project-specific toolchain
  images.
- Add persistent `start` / `stop` / `ssh` commands alongside Frost's disposable `run`
  command.
