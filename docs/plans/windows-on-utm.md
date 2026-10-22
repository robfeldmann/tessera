---
type: plan
stage: proposed
created: 2026-10-22
order: 37
description: Retire the Frost QEMU workflow and make the UTM guest the one scripted, rebuildable Windows lane, driven by scripts/vm.py like the macOS and Linux guests.
---

# Make UTM the one Windows lane and retire Frost

Goal: Tessera has one Windows path, a UTM guest named `tessera-windows-11` that `scripts/vm.py` can provision from a fresh Windows install, start, stop, sync, and test with the same task shapes as the macOS and Linux guests, so a contributor (or an agent) runs `mise run vm:windows-test` and gets the Ghostty-backed suite from a known guest state. The Frost scripts, their guide, and their Homebrew dependencies are gone, and the three guests show up together in `mise run vm:status`.

## Progress

- [ ] 1 Drive UTM from `vm.py` without the two known traps
- [ ] 2 One provisioning script for a Windows guest
- [ ] 3 Sync, build libghostty-vt in the guest, test, and a known state
- [ ] 4 Retire Frost
- [ ] 5 Docs and the guide

Next: the owner reads this plan; then Slice 1.

## Approach

Current state. Two Windows workflows share the repository. Frost (`scripts/windows-frost-*.sh`, `setup-windows-frost-vm.ps1`, `run-windows-frost-provision-task.ps1`, `windows-frost:*` tasks, `docs/guides/windows-frost-vm.md`) builds a golden image with Homebrew QEMU, provisions a toolchain image, and runs tests in disposable overlays; it cannot start on macOS 27 because QEMU 11.1.2's HVF backend aborts on the TPM device (`hv_vm_unmap` of the 20 KiB TPM TIS window returns `HV_BAD_ARGUMENT`; unchanged in QEMU master as of 2026-10-22). The UTM guest `tessera-frost-import` (Windows 11 ARM64, user `tester`, key `~/.ssh/tessera_windows`, Swift 6.3.3 and Zig 0.17.0 installed by hand during plan 035) ran every Windows check of plans 034 and 035 through the `windows-utm:*` tasks and Frost's guest-side PowerShell (`run-windows-frost-tests.ps1`, `build-libghostty-vt.ps1`), but `windows-utm:test` does not set `GHOSTTY_VT_OUTPUT_DIR`, nothing can rebuild the guest, and `vm.py` (plan 035 Step 5.6) knows only Tart and Lima. Hosted CI covers Windows x86_64 (`test (windows-latest)`, Ghostty built on the runner, the Examples build); the local guest is for ARM64, ConPTY in a real console, and iteration without a push.

Two `utmctl` traps, both reproduced on 2026-10-22 (macOS 27.0.1, UTM 5): `utmctl start` and `stop` hang for two minutes and fail with `OSStatus -1712` unless UTM.app has been activated at least once since it launched (a Dock or `open -a UTM` launch, or one later activation; hidden or windowless afterwards is fine), while a launch that was never activated (by the Apple Event itself, `open -g`, `open -gj`, or the `utm://` URL scheme) hangs and `list` and `status` always answer; and `--hide` prints `OSStatus -10004` twice on every command and is otherwise harmless (UTM issue #5509). Neither is TCC: tccd attributes requests from an omp session to `com.robfeldmann.herdr`, which is already allowed for UTM. `utmctl ip-address` works once the guest tools are installed; `/var/db/dhcpd_leases` (by the MAC in the VM's `config.plist`) is the fallback that needs no Apple Events.

End state. `vm.py` gains a `windows` family beside `macos` and `linux`: `windows-create` (a new UTM VM from a Windows ISO, or `--import` of an existing `.utm` bundle), `windows-provision` (idempotent: SSH, Git, Swift from `.swift-version`, Zig from the pinned Ghostty, UTM guest tools), `windows-start`, `windows-stop`, `windows-ssh`, `windows-ip`, `windows-push`, `windows-test` (builds and caches libghostty-vt in the guest, sets `GHOSTTY_VT_OUTPUT_DIR`, runs `swift test --no-parallel` with pass-through arguments), `windows-snapshot` and `windows-restore` (a named qcow2 snapshot of the stopped guest as the known state), and `windows-delete`. The old `windows-utm:*` names stay as aliases for one release. Frost's scripts, tasks, guide, Brewfile lines (`qemu`, `swtpm`, `sshpass`, the `hudochenkov/sshpass` tap), and state directory are removed; `docs/guides/windows-vm.md` becomes the one Windows guide, rewritten around the tasks.

Patterns to follow. `scripts/vm.py` conventions from plan 035 Step 5.6: storage under `~/.local/share/vms/<manager>/` with an environment override, instance names `tessera-<os>-<version>`, a generated SSH config (`~/.config/tessera/vm-ssh.config`) and the dedicated key `~/.ssh/tessera-vm` rather than edits to the user's `~/.ssh/config`, tasks as thin `mise-tasks/vm/<name>` wrappers with `#USAGE`. Guest-side PowerShell stays in `scripts/` with the `windows-` prefix and one job each (`setup-windows-vm.ps1` already installs Swift from `.swift-version` and enables sshd; `setup-windows-frost-vm.ps1` has the reboot-resume and Zig parts worth keeping). Markdown is one paragraph per line; `mise run quality:lint` and the hooks apply.

Patterns to avoid. Apple Events for anything that has a file-based answer (IP from the DHCP lease, state from `utmctl status` only); `--hide`; a second copy of the provisioning logic; keeping Frost "just in case" (its value was disposability, which the snapshot restores more cheaply); hand-installed tools in the guest that `windows-provision` does not know about.

Files that orient a newcomer. `scripts/vm.py`, `mise-tasks/vm/`, `docs/guides/vms.md`, `docs/guides/windows-vm.md`, `scripts/setup-windows-vm.ps1`, `scripts/setup-windows-frost-vm.ps1`, `scripts/run-windows-frost-tests.ps1`, `scripts/build-libghostty-vt.ps1`, `scripts/windows-frost-sync-utm.sh`, `docs/architecture/toolchain-lanes.md`.

Non-goals. A Windows 6.4 lane (the merged Phase 4 plan's Decision 7 owns Windows in CI); ARM64 Windows on hosted runners; GUI automation of the guest; fixing QEMU upstream (an issue with the two-command reproduction from plan 035's outcome is worth filing, but nothing here depends on it).

Open questions while proposed: whether `windows-create` must script the Windows installer (unattended `autounattend.xml` through UTM is possible but fiddly) or may stop at "import this `.utm` bundle or click through the installer once, then `windows-provision` does the rest"; the recommendation below is the latter.

## Slices

### 1 Drive UTM from `vm.py` without the two known traps

Add the `windows` family to `scripts/vm.py` with the UTM plumbing: `utm_ensure_running()` (if `utmctl list` does not answer: note the frontmost app with `lsappinfo front`, `open -a UTM`, poll `utmctl list` until it answers, then `open -b <that app>` so focus returns within a second; the activation is what makes `start` work, so never `open -g` or `-gj`), `utm_state(name)`, `windows-start` (no `--hide`; refuse with the plan's explanation if `utmctl start` fails with `-1712`), `windows-stop` (`utmctl stop`, then wait for `stopped`, with `--force` as the escape hatch, and `--quit` to quit UTM.app afterwards so nothing runs between sessions; the guide recommends it), `windows-ip` (`utmctl ip-address` first, the `dhcpd_leases` lookup by the MAC from `~/Library/Containers/com.utmapp.UTM/Data/Documents/<name>.utm/config.plist` second), `windows-ssh` (through the generated SSH config, user `tester`, key `~/.ssh/tessera-vm`, falling back to `~/.ssh/tessera_windows` for the existing guest), and `status` extended with a UTM row. The guest is still `tessera-frost-import` for this slice; a `--name` flag and `TESSERA_WINDOWS_VM_NAME` select it.

Delivers: `mise run vm:windows-start`, `vm:windows-ip`, `vm:windows-ssh -- swift --version`, `vm:windows-stop --quit` work from a shell where UTM.app is not running, hand focus back to the caller's app, and leave UTM quit at the end; `vm:status` lists the guest. Verify: run the four in that order with UTM quit beforehand (`osascript -e 'quit app "UTM"'`); `windows-start` returns within 10 s, the guest reaches `started`, and `lsappinfo front` names the same app before and after; `windows-stop --quit` leaves no `UTM` process; `windows-ip` with UTM guest tools stopped still prints the address from the lease file.

### 2 One provisioning script for a Windows guest

Merge `setup-windows-frost-vm.ps1` and `setup-windows-vm.ps1` into one `scripts/provision-windows-vm.ps1`: elevated, idempotent, reboot-resuming (keep the scheduled-task resume), installs Git, the Swift toolchain named by `.swift-version` (the swift.org installer, `/quiet /norestart`), Zig at the version `scripts/build-libghostty-vt.ps1` expects (read from one place: give the ps1 a `-PrintZigVersion` or move the pin into `scripts/config/`), CMake and Ninja if the Ghostty build needs them, OpenSSH Server with `administrators_authorized_keys` seeded from a key passed in, and the UTM guest tools (from the ISO URL `windows-frost-install-utm-tools.sh` uses). `vm.py windows-provision` pushes the script with `utmctl file push` or SCP, runs it over SSH when SSH already works, and prints the one manual step when it does not (first boot: run the script from an elevated PowerShell to enable SSH). `windows-create` documents and automates what it can: `--import <bundle.utm>` copies a bundle into UTM's documents folder and names it; a fresh install stays a documented click-through from the ISO (the open question above) that ends by running `windows-provision`.

Delivers: a guest at any state converges on the toolchain the repository names. Verify: run `vm:windows-provision` against `tessera-frost-import` twice; the second run makes no changes and `vm:windows-ssh -- swift --version` prints `6.3.3`; then on a throwaway clone of the bundle (`--import`), run it from the first-boot state and reach the same result (record the wall time).

### 3 Sync, build libghostty-vt in the guest, test, and a known state

`windows-push` (the tar-over-SSH sync from `windows-frost-sync-utm.sh`, moved into `vm.py` beside `macos-push`, into `C:/Users/tester/tessera`), `windows-test` (in the guest: `scripts/build-libghostty-vt.ps1` with the host cache path `C:/Users/tester/AppData/Local/tessera/libghostty-vt/<revision>/windows-arm64`, skipped when present; then `swift test --no-parallel` with `GHOSTTY_VT_OUTPUT_DIR` set and pass-through arguments, exiting with the guest's status), `windows-conpty-smoke` (the ANSI smoke from `windows-frost-conpty-smoke.sh` over the generated SSH config), and `windows-snapshot <name>` and `windows-restore <name>` using `qemu-img snapshot -c|-a` on the stopped guest's qcow2 (`/Applications/UTM.app/Contents/Frameworks/qemu-img.framework/qemu-img`, so Homebrew QEMU is not a dependency). The `run-windows-frost-tests.ps1` guest script is renamed `run-windows-tests.ps1` and loses its Frost naming.

Delivers: `mise run vm:windows-test` gives the Ghostty-backed suite; `vm:windows-test -- --filter PlatformHandlesTests` works; a snapshot taken after provisioning restores a clean state in seconds. Verify: `windows-push` then `windows-test` passes 651 tests with `==> Ghostty VT enabled` in the output; take `provisioned`, install something stray in the guest, restore, and show it gone; `windows-conpty-smoke` prints the colored lines.

### 4 Retire Frost

Delete `scripts/windows-frost*.sh`, `scripts/windows-frost.sh`, `setup-windows-frost-vm.ps1`, `run-windows-frost-provision-task.ps1`, `configure-windows-frost-gui-vm.ps1`, `check-windows-frost-toolchain.ps1` (fold its version check into `windows-provision`'s verify step), `sync-windows-frost-source.ps1`, `mise-tasks/windows-frost/`, `mise-tasks/windows-utm/` (after adding the alias lines to the `vm/windows-*` tasks), `docs/guides/windows-frost-vm.md`, and the Brewfile lines for `qemu`, `swtpm`, `sshpass`, and the `hudochenkov/sshpass` tap. `scripts/dev-state.sh` stops reporting Frost paths and reports the UTM guest instead. `~/.local/state/tessera/windows-frost/` is the owner's to delete; the guide says so. The `.agents/skills/windows-smoke-testing` skill and `docs/research/windows-libghostty-vt-snapshot-spike.md` are checked for Frost references: the skill is updated, the research record stays as history.

Delivers: `git grep -i frost` finds only history (plans, research, CHANGELOG). Verify: that grep; `mise run quality:lint` and `mise tasks` clean; `brew bundle check` passes without the removed formulae.

### 5 Docs and the guide

Rewrite `docs/guides/windows-vm.md` around the tasks (create or import, provision, snapshot, push, test, smoke, troubleshooting with the two `utmctl` traps and the TCC attribution note for agents running under herdr), update `docs/guides/vms.md` (the three guests, one table), `CONTRIBUTING.md` (Cross-platform testing), `README.md`, `docs/project-status.md` (the tested-configuration table's Windows row), `docs/guides/local-development-state.md`, the `windows-smoke-testing` skill, `CHANGELOG.md` (Removed: Frost; Changed: the Windows lane), and `docs/log.md`. Promote the "UTM must be launched in the foreground for `utmctl start`" finding to `docs/architecture/` only if it ends up shaping a decision; otherwise it stays in the guide's troubleshooting.

Delivers: a contributor with UTM and a Windows ISO reaches `vm:windows-test` from the guide alone. Verify: `mise run quality:lint`, `mise run docs:lint` unaffected (no DocC change), `iwe schema validate` from `docs/`; a read-through by the owner.

## Acceptance

- [ ] `mise run vm:status` lists the macOS, Linux, and Windows guests; `vm:windows-start` works with UTM.app not running, without `--hide`, within 10 s.
- [ ] `vm:windows-provision` is idempotent and converges a fresh Windows install on the repository's Swift and Zig versions; `vm:windows-test` passes the Ghostty-backed suite (651 tests at `6d180f0`), and a snapshot restores the provisioned state.
- [ ] No Frost script, task, guide, or Homebrew dependency remains; `git grep -i frost` finds only history.
- [ ] `docs/guides/windows-vm.md` is the one Windows guide and names the two `utmctl` traps.

## Decisions

- 2026-10-22 Retire Frost instead of patching QEMU: its distinctive value was disposability, which a qcow2 snapshot of the UTM guest restores more cheaply, and its QEMU dependency is what broke on macOS 27 while UTM's bundled QEMU boots the same Windows-with-TPM configuration. (owner, after plan 035's outcome)
- 2026-10-22 `windows-create` may stop at an imported bundle or a documented click-through install; unattended installation is not required for this plan. (proposed; the owner confirms on review)

## Discoveries

- `utmctl start` and `stop` need UTM.app to have been activated once since launch; a never-activated launch (by the Apple Event, `open -g`, `open -gj`, the URL scheme) hangs for two minutes with `-1712` while `list` and `status` work, and hidden or windowless UTM works once it was active — reproduced seven ways on 2026-10-22. `open -a UTM` followed by `open -b <previous frontmost bundle id>` (from `lsappinfo front`) launches and activates it with a one-second focus flash and no Apple Events; quitting UTM after `windows-stop` keeps it from running between sessions.
- `--hide` emits `-10004` twice per command and does nothing harmful (UTM #5509); plan 035 misread it as a permission failure.
- TCC attributes an omp session's requests to `com.robfeldmann.herdr` (the `dev.mise.herdr-server` LaunchAgent's binary), not to Ghostty or omp; Automation grants are per responsible app, so herdr needs its own grant for each target app, made once.
- Frost's failure is `qemu-system-aarch64 -accel hvf … -device tpm-tis-device`: `hv_vm_unmap` of the 20 KiB (not 16 KiB-aligned) TPM TIS MMIO window returns `HV_BAD_ARGUMENT` on macOS 27.0.1 with QEMU 11.1.2; the same VM without the TPM starts. The path is unchanged in QEMU master.

## Outcome

Not started.

## References

- Plan 035, [Toolchain, repository conventions, and plan consolidation](toolchain-conventions-and-plan-consolidation.md): Step 1.1 (the Frost failure), Step 5.6 (`vm.py` and the Tart and Lima tasks), the Outcome's loose ends.
- [VMs guide](../guides/vms.md), [Manual Windows VM with UTM](../guides/windows-vm.md), [Windows VM with Frost](../guides/windows-frost-vm.md) (to be retired).
- [Toolchain lanes](../architecture/toolchain-lanes.md).
- UTM issue 5509 (`--hide` and `-10004`); QEMU `accel/hvf/hvf-all.c` (`hvf_set_phys_mem`, the unmap path).
