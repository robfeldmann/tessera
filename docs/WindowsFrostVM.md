# Windows Frost VM Prototype

Metadata:

- Last updated: 2026-06-16
- Status: prototype plan in progress
- Frost checkout: `/Users/rob/Developer/solcreek/frost/main`

This guide is for the experimental Frost-based Windows 11 ARM64 workflow. The known-good
UTM workflow remains documented in `docs/WindowsVM.md`; use this guide only while working
through `.agents/plans/013-frost-windows-vm-prototype.md`.

## Frost checkout strategy

Keep Frost outside this repository while the prototype is exploratory. Do not vendor Frost
or add it as a submodule until we know whether Tessera needs wrapper-only integration,
local Frost patches, or an upstream Frost pull request.

Recommended local checkout:

```fish
mkdir -p /Users/rob/Developer/solcreek
git clone https://github.com/solcreek/frost /Users/rob/Developer/solcreek/frost/main
```

For this prototype, Tessera scripts should default to:

```text
/Users/rob/Developer/solcreek/frost/main
```

That keeps Rob's local workflow zero-config. Scripts should still allow overriding the
path with `TESSERA_FROST_ROOT` for other machines or alternate Frost branches.

## Optional Frost path override

A global shell variable is not required. If needed, use one of these temporary forms.

For a single command:

```fish
env TESSERA_FROST_ROOT=/Users/rob/Developer/solcreek/frost/main just windows-frost-doctor
```

For the current fish session:

```fish
set -x TESSERA_FROST_ROOT /Users/rob/Developer/solcreek/frost/main
```

Only use a universal fish variable if you intentionally want the setting to persist across
all future shells:

```fish
set -Ux TESSERA_FROST_ROOT /Users/rob/Developer/solcreek/frost/main
```

## Required ISO inputs

Frost does not redistribute Windows or VirtIO drivers. You must provide these files
locally before building the base golden image:

1. **Windows 11 ARM64 ISO**
   - Use the same Microsoft Windows 11 ARM64 ISO flow documented in `docs/WindowsVM.md`.
   - The Phase 0 walkthrough used: `~/Downloads/Win11_25H2_English_Arm64_v2.iso`.
2. **VirtIO driver ISO**
   - This is a new Frost-only prerequisite; the original UTM Phase 0 setup did not
     download or leave behind a VirtIO ISO.
   - Frost needs a VirtIO driver ISO so Windows can use virtio networking during
     provisioning.
   - The ISO must be downloaded separately and must include ARM64 `NetKVM` drivers.

Keep the Windows and VirtIO paths as separate values because they are separate downloads
and the VirtIO ISO will not already exist from the UTM setup.

A global shell variable is not required. For a single command, pass paths with `env`:

```fish
env \
  TESSERA_FROST_WINDOWS_ISO=~/Downloads/Win11_25H2_English_Arm64_v2.iso \
  TESSERA_FROST_VIRTIO_ISO=/path/to/virtio-win.iso \
  just windows-frost-env
```

Future build recipes should read these optional variables:

- `TESSERA_FROST_WINDOWS_ISO`
- `TESSERA_FROST_VIRTIO_ISO`

## Planned local artifacts

Frost-generated disks and VM runtime state should stay out of Git. The prototype defaults
to a local work directory under `.build/windows-frost`, which is ignored with other Swift
build output.

Expected artifact paths from `just windows-frost-env`:

- `TESSERA_FROST_BASE_GOLDEN`: base Frost Windows golden qcow2.
- `TESSERA_FROST_BASE_VARS`: base UEFI vars file.
- `TESSERA_FROST_TOOLCHAIN_GOLDEN`: Tessera toolchain golden qcow2.
- `TESSERA_FROST_TOOLCHAIN_VARS`: Tessera toolchain UEFI vars file.

Later phases will also create either per-run disposable overlays or one persistent
development overlay.

## Host prerequisite check

Run the non-destructive doctor before building any VM images:

```fish
just windows-frost-doctor
```

The check verifies:

- Frost CLI at the default or overridden checkout path.
- `qemu-img`.
- `qemu-system-aarch64`.
- `swtpm`.
- `sshpass`.
- macOS `swift`, used by Frost to build its `vmkit` helper.

If tools are missing, install the host dependencies with:

```fish
brew install qemu swtpm hudochenkov/sshpass/sshpass
```

## Non-destructive wrapper recipes

These recipes exercise the local Frost checkout without creating or booting a VM:

```fish
just windows-frost-env
just windows-frost-help
just windows-frost-dry-run
```

After the base golden exists, verify it with:

```fish
just windows-frost-check-base
```

This boots a disposable overlay from `TESSERA_FROST_BASE_GOLDEN`, waits for SSH on
`TESSERA_FROST_SSH_PORT`, runs `whoami`, prints guest output, and exits with Frost's guest
command status.

The shared defaults are:

- `TESSERA_FROST_ROOT`: Frost checkout path.
- `TESSERA_FROST_WORK`: local VM artifact directory, defaulting to `.build/windows-frost`.
- `TESSERA_FROST_SSH_PORT`: forwarded SSH port, defaulting to `2222`.
- `TESSERA_FROST_USER`: Windows SSH user, defaulting to `tester`.
- `TESSERA_FROST_WINDOWS_ISO`: optional Windows ISO path for future build recipes.
- `TESSERA_FROST_VIRTIO_ISO`: optional VirtIO ISO path for future build recipes.

## Tessera toolchain provisioning script

The Frost base golden only contains Windows, VirtIO networking, OpenSSH, and the default
`tester` administrator account. Tessera-specific tools are installed by:

```text
scripts/setup-windows-frost-vm.ps1
```

The script is intended to run inside a writable Frost clone over SSH. It installs or
verifies Git, the Visual Studio C++ workload, the Windows 11 SDK, Swift, OpenSSH, and an
optional SSH authorized key.

The script is idempotent. If Visual Studio or another installer leaves a reboot pending,
it writes a marker under `C:\ProgramData\Tessera\FrostProvision` and exits with code
`100`. The host-side provisioning wrapper should reboot the guest, wait for SSH, and rerun
the script until it writes `complete.txt`.

The first provisioning attempt tried WinGet over OpenSSH and hit WinGet error `0x8a15000f`
(`Data required by the source is missing`) even after `winget source reset/update`,
matching known WinGet-over-OpenSSH behavior. The provisioner now avoids WinGet for the
heavy toolchain installs and downloads the Git, Visual Studio, and Swift installers
directly.

Swift maintainability note: the host wrapper reads `.swift-version` and passes that value
as `-ExpectedSwiftVersion`. Unless `TESSERA_FROST_SWIFT_INSTALLER_URL` is set, the Windows
provisioning script derives the official Swift ARM64 installer URL from that version. When
Tessera bumps Swift, `.swift-version` should usually be the only Swift version change
needed. The direct Git and Visual Studio installer URLs are parameters too, and can be
overridden for one run with:

```fish
env \
  TESSERA_FROST_GIT_INSTALLER_URL=https://example.invalid/Git-arm64.exe \
  TESSERA_FROST_VS_BOOTSTRAPPER_URL=https://example.invalid/vs_community.exe \
  TESSERA_FROST_SWIFT_INSTALLER_URL=https://example.invalid/swift-arm64.exe \
  just windows-frost-provision-toolchain --force
```

This provisioning script intentionally does not configure GUI clipboard integration. For
headless Frost runs, copy/paste is handled by the host terminal and SSH. If a Frost-built
image is imported into UTM later, Phase 6 must verify GUI integration separately,
including display resize, input, host ↔ guest clipboard copy/paste, and whether Frost's
VirtIO guest tools are sufficient or UTM/SPICE guest tools need another install step.

To build the Tessera toolchain golden overlay from the base golden, run:

```fish
just windows-frost-provision-toolchain
```

If an old toolchain overlay already exists and should be rebuilt:

```fish
just windows-frost-provision-toolchain --force
```

The toolchain artifact is currently a qcow2 overlay backed by the base Frost golden. Keep
both files together until a later phase decides whether to compact/convert it into a
standalone qcow2.

Verify the Tessera toolchain golden with:

```fish
just windows-frost-check-toolchain
```

This boots a disposable overlay, runs password SSH checks for Git, Swift, Visual Studio,
and the Windows SDK, then verifies key-based SSH auth with `~/.ssh/tessera_windows`.

Phase 3.2 built the Tessera toolchain overlay successfully. Provisioning required one
reboot after Visual Studio installation, then completed on the second attempt. The created
artifacts were:

- `.build/windows-frost/disks/tessera-win11.qcow2` — 21 GB qcow2 overlay backed by
  `base-win11.qcow2`.
- `.build/windows-frost/disks/tessera-win11-vars.fd` — 64 MB UEFI vars file.

Phase 3.3 verified the toolchain golden with `just windows-frost-check-toolchain`:

- `git version 2.54.0.windows.1`.
- `Swift version 6.3.2`, target `aarch64-unknown-windows-msvc`.
- Visual Studio Native Desktop workload at
  `C:\Program Files\Microsoft Visual Studio\2022\Community`.
- Windows SDK `10.0.26100.0`.
- SSH key auth for `desktop-hdia40e\\tester`.

## Source sync and test execution

`test-windows-frost` is the default Phase 4 validation loop:

```fish
just test-windows-frost
```

It creates a disposable qcow2 overlay from the Tessera toolchain golden, boots it,
packages the current macOS working tree, syncs the source archive into
`C:\Users\tester\tessera`, runs `swift test --no-parallel`, shuts down the guest, and
returns the guest test command's exit code.

The source archive is created from `git ls-files --cached --others --exclude-standard`, so
it includes tracked files, local modifications to tracked files, and untracked files that
are not ignored. Deleted tracked files are treated as an error because they cannot be
represented safely by the archive list.

`windows-frost-sync-source` exists as a lower-level helper for an already-running Frost
guest:

```fish
just windows-frost-sync-source
```

Phase 4 currently defaults to disposable overlays for validation because they prove a
clean repeatable Windows run and avoid contaminating the toolchain golden. Persistent
overlays remain deferred to Phase 5, where the goal shifts to faster interactive iteration
and TUI manual validation.

Phase 4 test result: `just test-windows-frost` successfully synced source, booted Windows,
ran SwiftPM, propagated the guest exit code, and reached the expected current Slice 6
Windows compile failure:

```text
Sources\CTesseraTerminalPlatform\include\CTesseraTerminalPlatform.h:5:10: fatal error: 'termios.h' file not found
```

## Persistent interactive Frost VM

For interactive Windows/ConPTY work, use a persistent overlay instead of the disposable
`test-windows-frost` flow:

```fish
just windows-frost-start
just windows-frost-ssh
just windows-frost-stop
```

Reset the persistent overlay back to the Tessera toolchain golden with:

```fish
just windows-frost-start --reset
```

The persistent overlay lives at `.build/windows-frost/persistent/dev.qcow2`, backed by the
Tessera toolchain golden. It preserves guest state and SwiftPM build caches between
starts, so it is intended for local iteration rather than clean validation.

For non-interactive smoke testing of the Windows OpenSSH/ConPTY path, run:

```fish
just windows-frost-start
just windows-frost-conpty-smoke
just windows-frost-stop
```

The smoke check forces a Windows ConPTY, prints ANSI colors, and exercises cursor
save/restore. In this agent harness, `script(1)` is used to provide a local
pseudo-terminal so `ssh -tt` behaves like an interactive terminal.

Phase 5 validation result:

- `just windows-frost-start` created and booted the persistent overlay.
- `just windows-frost-ssh whoami` reached the guest over a forced PTY and printed
  `desktop-hdia40e\\tester`.
- `just windows-frost-conpty-smoke` showed Windows ConPTY control sequences plus ANSI
  color output and cursor save/restore output.
- `just windows-frost-stop` shut the VM down cleanly.

A real Tessera example app could not be validated yet because the current Windows build
still stops at the known `termios.h` compile failure. SSH/ConPTY is adequate for the Slice
6 manual validation loop once the Windows terminal platform compile issue is fixed, but it
is not a substitute for Phase 6 GUI validation in PowerShell/Windows Terminal.

## UTM manual GUI import attempt

Phase 6 attempted a best-effort unattended UTM import for manual GUI validation:

1. Converted the Tessera toolchain qcow2 overlay into a standalone qcow2.
2. Copied the Tessera toolchain UEFI vars file.
3. Cloned the existing `tessera-windows` UTM VM as `tessera-frost-import`.
4. Replaced the clone's NVMe qcow2 and `efi_vars.fd` with the Frost-built artifacts.

The imported VM bundle now exists at:

```text
~/Library/Containers/com.utmapp.UTM/Data/Documents/tessera-frost-import.utm
```

The imported disk inside that bundle is about 36 GB. Temporary intermediate conversion
files and the clone's original Phase 0 disk backup were removed to avoid wasting disk
space.

Manual GUI validation confirmed that the imported Frost image boots in UTM. The VM reached
the Windows login screen, accepted the Frost default credentials (`tester` / `Test1234!`),
and logged in to the desktop.

Observed GUI validation results:

- Windows boots to desktop in UTM.
- Keyboard and mouse input work well enough to log in and run commands.
- PowerShell can run `git --version` and `swift --version`; both report the expected
  versions.
- Display resize/dynamic resolution does **not** appear to work.
- Host ↔ guest clipboard copy/paste does **not** work in either direction.
- `utmctl ip-address tessera-frost-import` fails because the QEMU guest agent is not
  running or not installed in the imported Frost image.
- Tessera examples cannot be validated yet because Windows compilation still stops at the
  known `termios.h` failure.

Conclusion: the Frost-built image is usable in UTM for manual GUI boot/toolchain checks,
but UTM guest integration was initially incomplete. Installing UTM Windows Guest Tools in
the imported image added the expected guest services (`QEMU-GA`, `vdservice`,
`spice-webdavd`, and `BalloonService`), and `utmctl ip-address tessera-frost-import` now
works.

To install or repair UTM Windows Guest Tools in the imported VM:

```fish
just windows-frost-install-utm-tools <vm-ip>
```

The recipe downloads UTM's Windows Guest Tools ISO, copies `utm-guest-tools-*.exe` into
the guest over SSH, and runs it silently with `/S`. Reboot the Windows guest afterward,
then re-test dynamic resolution and clipboard manually.

To sync the current macOS working tree into the running UTM GUI VM, first find the VM's
IPv4 address from inside Windows:

```powershell
Get-NetIPAddress -AddressFamily IPv4 |
  Where-Object { $_.IPAddress -notlike "169.254.*" -and $_.IPAddress -ne "127.0.0.1" } |
  Select-Object -ExpandProperty IPAddress
```

Then run from macOS:

```fish
just windows-frost-sync-utm <vm-ip>
```

This copies the current working tree into `C:\Users\tester\tessera` by default. The sync
is a one-way Mac → Windows snapshot, not a two-way or real-time sync. Rerunning the sync
replaces the Windows destination, so treat the macOS checkout as the source of truth and
do not make important edits inside the Windows copy unless you manually copy them back.
The sync uses an archive of tracked files, modified tracked files, and untracked
non-ignored files; it does not copy the `.git` directory, so the destination is a source
tree rather than a Git checkout. It uses `UserKnownHostsFile=/dev/null` for the sync so it
can tolerate the expected host-key collision when the imported Frost VM reuses an IP
previously used by another Windows VM. For normal manual SSH, remove stale host keys with:

```fish
ssh-keygen -R <vm-ip>
```

After syncing, open PowerShell in the UTM VM:

```powershell
cd C:\Users\tester\tessera
swift test --no-parallel
```

This still reaches the current known `termios.h` Windows compile failure until Slice 6's
Windows terminal-platform implementation is fixed.

Phase 8.1 verification: `just windows-frost-sync-utm 192.168.64.2` successfully synced the
current source tree into `C:\Users\tester\tessera` in the UTM-imported VM. `Package.swift`
was present and `swift --version` in the same VM still reported Swift 6.3.2.

Phase 8.2 verification: UTM Guest Tools 0.1.271 installed successfully via silent
installer. Services `QEMU-GA`, `vdservice`, `spice-webdavd`, and `BalloonService` were
running, and `utmctl ip-address tessera-frost-import` returned `192.168.64.2`. After
rebooting the Windows guest, dynamic resize worked, host ↔ guest clipboard sync worked,
and the guest CPU load settled down.

Additional GUI quality-of-life settings can be applied with:

```fish
just windows-frost-configure-gui <vm-ip>
```

This enables Windows Developer Mode for unprivileged symlink creation, sets Git's global
`core.symlinks=true`, and writes PowerShell profile files that start new PowerShell
sessions in `%USERPROFILE%` instead of `C:\Windows\System32`. This has been applied to the
current `tessera-frost-import` VM and verified with:

- `AllowDevelopmentWithoutDevLicense = 1`.
- `AllowAllTrustedApps = 1`.
- `git config --global --get core.symlinks` returns `true`.
- `C:\Users\tester\Documents\WindowsPowerShell\profile.ps1` exists.

## Frost integration disposition

No Frost checkout modifications were required for this prototype. Tessera currently layers
wrapper scripts around the external Frost checkout at
`/Users/rob/Developer/solcreek/frost/main`. Keep this wrapper-only integration for now; do
not vendor Frost or add it as a submodule.

Potential upstream Frost PRs identified during the prototype:

- Ensure Frost creates `work/disks` before `test-run.sh` creates throwaway overlays,
  especially when `--golden` points outside the Frost checkout.
- Add a configurable work directory, e.g. `FROST_WORK`, so downstream wrappers can keep
  all artifacts outside the Frost source checkout.
- Use short runtime socket paths, likely under `/tmp`, for `swtpm` and QEMU monitor
  sockets to avoid Unix socket path length failures under long repository paths.
- Add a generic project customization command, e.g.
  `frost customize --golden base.qcow2 --run provision.ps1 --out project.qcow2`, for
  building project-specific toolchain images.
- Consider persistent `start`/`stop`/`ssh` commands as a generic interactive-development
  companion to Frost's disposable `run` command.

Earlier Phase 2.2 verification: `just windows-frost-check-base` succeeded with guest
output `desktop-hdia40e\\tester`.

Notes from verification:

- Frost's `test-run.sh` currently creates throwaway overlays under the Frost checkout's
  `work/disks` directory, even when the golden image is outside the Frost checkout. The
  Tessera wrapper creates that directory before running Frost.
- A first attempt using `cmd /c ver` reached the guest and returned a non-zero exit code,
  which proved host-side exit-code propagation, but Windows OpenSSH/default-shell quoting
  caused the guest to see `ver"`. Use simple commands like `whoami` for the base smoke
  check until command quoting is handled deliberately in later phases.
