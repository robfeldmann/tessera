---
name: Frost Windows VM workflow
date: 2026-06-16
status: resolved
---

# Frost Windows VM workflow

## Question

Can [solcreek/frost](https://github.com/solcreek/frost) provide a simpler, Lima-like
alternative to the Phase 0 UTM Windows VM workflow for building, testing, and
interactively running Tessera on Windows 11 ARM64?

## Sources checked

- Frost repository cloned at `dafc5a6`
  (`refactor(bin): honor FROST_QEMU_* env vars instead of hardcoding Homebrew paths`).
- Frost files inspected: `README.md`, `bin/frost`, `bin/build-golden.sh`,
  `bin/test-run.sh`, `bin/_vmkit.sh`,
  `packages/vmkit/Sources/VMKit/QEMUArgumentBuilder.swift`,
  `share/provision/vmkit-setup.ps1`, `docs/WINDOWS-CONFIG.md`.
- Frost `packages/vmkit` tests were run locally with
  `swift test --package-path packages/vmkit`; all 7 Swift Testing tests passed.
- Swift SDK generator repository `README.md` was checked for supported host/target
  platforms.
- Swift Forums thread checked:
  <https://forums.swift.org/t/upcoming-changes-to-windows-swift-sdks/81313>.
- Windows OpenSSH PTY reference checked:
  <https://github.com/PowerShell/Win32-OpenSSH/wiki/TTY-PTY-support-in-Windows-OpenSSH>.
- Project context checked: `.agents/plans/012-phase-2-slice-6-windows-terminal-io.md`,
  `docs/WindowsVM.md`, `.agents/investigations/007-windows-utm-setup-walkthrough.md`,
  `Justfile`, and `scripts/setup-windows-vm.ps1`.
- Local UTM VM config inspected at
  `~/Library/Containers/com.utmapp.UTM/Data/Documents/tessera-windows.utm/config.plist` to
  compare its QEMU architecture, disk bus, TPM, and firmware setup with Frost.

## Findings

### Assessment of the research assistant response

| Claim                                                                                                                                                            | Assessment                     | Notes                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| ---------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| macOS cannot currently build an official Swift Windows `.exe` with `swift-sdk-generator`.                                                                        | Correct, with wording caveat.  | `swift-sdk-generator` currently lists Linux/FreeBSD as target platforms and macOS only as a host. Windows is not listed as a supported target. The assistant's "hard blocker, not about to be filled" wording is stronger than the evidence I found; the practical conclusion for Tessera is still correct: use a Windows environment to build/test Windows Swift today.                                                                                                                                                |
| Frost uses raw QEMU, not UTM.                                                                                                                                    | Correct.                       | Frost uses shell scripts plus a Swift `vmkit` package to generate QEMU argv. It runs `qemu-system-aarch64` directly, with `-accel hvf` for the normal Windows ARM path, `swtpm` for TPM, `ramfb`, and QEMU user networking.                                                                                                                                                                                                                                                                                             |
| Frost clones a golden `qcow2`, boots headless, forwards SSH on `localhost:2222`, copies a binary, runs it, streams output, propagates exit code, and tears down. | Correct for `bin/test-run.sh`. | The script creates a qcow2 overlay, copies UEFI vars, starts `swtpm`, boots QEMU, waits for SSH, optionally `scp`s one local file, runs `ssh "$RUNCMD"`, stores `$?`, shuts down best-effort, and exits with the guest command status.                                                                                                                                                                                                                                                                                  |
| Interactive terminal UI can be viewed with `ssh -t -p 2222 ...`.                                                                                                 | Partly correct.                | Windows OpenSSH uses ConPTY on Windows 10+/Server 2019+, and `ssh -t` is the right shape for an interactive PTY. However, Frost has no persistent `start`/`shell` command equivalent to Lima. `test-run.sh` is designed to boot, run one command, shut down, and kill QEMU. Also, "exactly as a Windows user would" is too strong: the app runs behind Windows OpenSSH/ConPTY and renders into the macOS terminal, not into Windows Terminal/conhost locally. It is still very useful for Tessera terminal I/O testing. |
| Example workflow: `ssh -p 2222 user@localhost "swift build"`.                                                                                                    | Incomplete.                    | That only works while a Frost VM is already running and only after the golden image has Git, Visual Studio C++ tools, Swift, and a Tessera checkout. Frost's default provisioning installs networking/OpenSSH and hardens the VM; it does not install Tessera's Swift toolchain prerequisites.                                                                                                                                                                                                                          |

### What Frost actually gives us

Frost is closer to a reproducible Windows-ARM VM image builder and disposable test runner
than to a full Lima replacement out of the box.

Useful pieces:

- A documented QEMU configuration for Windows 11 ARM64 on Apple Silicon.
- Unattended golden-image creation from a user-provided Windows ISO and VirtIO ISO.
- Headless QEMU launch with HVF acceleration, TPM, VNC, and SSH port forwarding.
- Disposable qcow2 overlay clones for clean test runs.
- A simple SSH-based harness with host-visible stdout/stderr and exit-code propagation.
- A Swift `vmkit` package that centralizes QEMU argument generation and has tests.

Missing for Tessera Phase 0 parity:

- No installation of Git, Visual Studio C++ workload, Windows SDK, Swift, or `just`.
- No source tree sync equivalent to our `windows-vm-sync` recipe.
- No persistent incremental development VM command comparable to `limactl shell` or the
  current UTM VM.
- `test-run.sh` copies one binary/file, not a whole Swift package checkout.
- Disposable overlays delete `.build` and SwiftPM dependency/build cache every run unless
  we deliberately bake caches into the golden image or keep/promote an overlay.
- Password auth via `sshpass` is the default. That is fine for a local throwaway VM, but
  we should prefer key auth for project recipes if possible.

### Fit for Tessera workflows

There are two distinct workflows to prototype:

1. **Clean, reproducible Windows test run.** Frost is a strong fit. Build a Tessera-ready
   golden once, then for each test create a disposable overlay, sync/checkout source, run
   `swift test --no-parallel`, return the exit code, and discard the VM state.

2. **Interactive/incremental Windows development.** Frost needs a small wrapper layer. A
   persistent overlay would let us keep SwiftPM build artifacts and run
   `ssh -tt -p <port> tester@localhost` for an interactive session. This would behave more
   like Lima/UTM for day-to-day work, while still using Frost's QEMU config and
   image-building lessons.

For terminal UI validation, SSH/ConPTY is probably acceptable and may be better than a GUI
VM for scripted TUI work. It should not be treated as identical to launching in Windows
Terminal until we verify the specific Windows Console APIs Tessera uses under OpenSSH.

### Addressing the missing Tessera toolchain

The limitation that Frost's default golden lacks Git, Visual Studio C++ tools, Swift,
`just`, and a Tessera checkout should be addressed with a layered image model:

```text
Windows ISO + VirtIO ISO
        ↓
frost base golden
  Windows 11 ARM64
  VirtIO networking
  OpenSSH
        ↓
tessera toolchain golden
  Git
  Visual Studio C++ workload
  Windows SDK
  Swift toolchain
  SSH key auth
  optional: just
        ↓
per-run overlay
  current Tessera checkout
  .build cache if persistent
```

Bake the heavy, slow-moving prerequisites into a Tessera-specific golden image:

- Git.
- Visual Studio C++ workload.
- Windows SDK.
- Swift toolchain matching `.swift-version`.
- SSH key auth for unattended host recipes.
- Optionally `just`, though host-side `just` recipes can also run `swift test` directly
  over SSH and avoid requiring `just` in the guest.

Do not bake the active Tessera checkout into the main golden unless we deliberately want a
fixed snapshot. Instead, sync source into a per-run or persistent overlay:

1. **Disposable clean run:** boot a throwaway overlay, copy/clone the current source, run
   `swift test --no-parallel`, propagate the exit code, and discard the overlay.
2. **Persistent dev overlay:** keep one writable overlay, sync source with Git over SSH
   like the current `windows-vm-sync`, preserve `.build`, and use
   `ssh -tt -p <port> tester@localhost` for interactive sessions.

For initial developer ergonomics, the persistent overlay is closer to the current UTM/Lima
workflow because it preserves SwiftPM dependency and build caches.

### Frost modification strategy

Because Frost is small, young, and already has a Swift `vmkit` core, it is reasonable to
clone it locally and modify it during the prototype. Two implementation levels are
available:

1. **Repo-local wrapper scripts:** keep Frost as an external checkout or submodule and add
   Tessera scripts/recipes around it:
   - `windows-frost-build-base`
   - `windows-frost-provision-tessera`
   - `windows-frost-run`
   - `windows-frost-ssh`
2. **Upstreamable Frost feature:** add a generic customization command, for example:

   ```sh
   frost customize \
     --golden base-win11.qcow2 \
     --run scripts/tessera-provision.ps1 \
     --out tessera-win11.qcow2
   ```

   Or extend `frost build` with a `--provision <script.ps1>` hook.

A generic `customize` command is likely the best PR shape if the prototype works: Frost
users beyond Tessera will need a way to turn the base Windows image into a
project-specific build/test image.

The main technical issue is reboot handling. Visual Studio installation may leave a reboot
pending, so the headless provisioner should either use a scheduled task to resume after
reboot, keep autologon for the provisioning phase, or perform a controlled reboot followed
by verification. The existing `scripts/setup-windows-vm.ps1` already contains useful
reboot-resume logic, but it should be adapted for Frost's headless/non-interactive flow.

### UTM interoperability

A Frost-created VM should be usable from UTM in principle, because both workflows use QEMU
for a Windows 11 ARM64 guest. The current UTM VM config is also QEMU-backed and uses an
`aarch64` `virt` machine, NVMe disk interface, TPM, UEFI boot, and a qcow2 disk image —
all broadly aligned with Frost's normal Windows ARM configuration.

The safest UTM import path is probably:

1. Create a new UTM Windows ARM VM with similar settings.
2. Stop it before first use or after creating its VM bundle.
3. Replace its disk with a standalone copy/convert of the Frost golden:

   ```fish
   qemu-img convert -O qcow2 frost-golden.qcow2 utm-disk.qcow2
   ```

4. Keep the disk interface as NVMe.
5. Prefer copying Frost's UEFI vars into UTM's `efi_vars.fd`, or be prepared to repair the
   Windows Boot Manager entry if UTM's fresh vars do not discover it.
6. Avoid depending on a Frost overlay's backing path from inside UTM; use a standalone
   qcow2 copy for manual GUI validation.
7. Avoid or disable BitLocker unless the TPM state and UEFI vars are migrated together.

This would make Frost the reproducible image builder/test harness while UTM remains an
optional manual GUI viewer for checking how PowerShell, Windows Terminal, or conhost
render Tessera example apps. The alternative is to add a Frost persistent GUI/VNC/cocoa
start mode, but UTM import may be faster for manual validation.

## Recommended prototype direction

Prototype Frost as an **alternative Phase 0 implementation**, not an immediate replacement
for the UTM docs.

Suggested prototype scope:

1. Add local-only Frost prerequisites documentation:
   - `brew install qemu swtpm hudochenkov/sshpass/sshpass`
   - user-provided Windows 11 ARM64 ISO
   - user-provided VirtIO driver ISO
2. Build a base Frost golden with `bin/build-golden.sh`.
3. Add a Tessera customization step that boots the base image and runs/adapts
   `scripts/setup-windows-vm.ps1` to install Git, Visual Studio C++ tools, Swift, and SSH
   key auth. Capture/promote the resulting image or overlay as `tessera-frost-golden`.
4. Add narrow `just` recipes around a local Frost checkout or vendored scripts:
   - `windows-frost-build-golden`
   - `windows-frost-check`
   - `windows-frost-ssh`
   - `test-windows-frost`
5. Decide early whether the prototype optimizes for:
   - disposable clean runs, or
   - a persistent overlay with incremental `.build` cache.

Acceptance criteria for the prototype:

- From a fresh host with the documented ISOs, build a Frost golden without UTM.
- `just windows-frost-check` proves `swift --version` over `localhost:<port>`.
- `just test-windows-frost` runs `swift test --no-parallel` in a Windows ARM64 guest and
  propagates the remote exit code.
- `just windows-frost-ssh` opens an interactive PTY capable of running a minimal Tessera
  terminal demo with cursor movement/colors.

## Conclusion

Frost materially improves the hard part we just solved manually with UTM: reproducible,
scriptable Windows 11 ARM64 VM creation and headless SSH-driven runs on Apple Silicon. The
assistant's main claims are directionally correct, but the response understates the work
needed to turn Frost into a Tessera developer workflow.

The best next step is a small prototype plan that layers Tessera-specific provisioning,
source sync, and persistent/interactive recipes on top of Frost. Keep the current UTM
Phase 0 path as the known-good fallback until the Frost prototype can build the golden
image and run Tessera tests end-to-end.
