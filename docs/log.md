# Log

## 2026-10-22

- Moved the project documentation into this IWE workspace (plan 035 Step 5.2): plans and research records took slug names under `plans/` and `research/`, the design catalog moved under `design/`, the contributor guides under `guides/`, and the spec was split into `spec/` pages. `docs/plans.md` is rendered from plan frontmatter by `scripts/plans.py`, and `docs/architecture/` opened with the toolchain-lanes decision from plan 035 Phase 2.
- Added [Tessera VMs](guides/vms.md) (plan 035 Step 5.6): `scripts/vm.py` and the `vm:` tasks build macOS bases from Cirrus Labs vanilla images with a scripted Xcode install, clone `tessera-macos-26` and `tessera-macos-27` from them, deliver the working tree and run the check matrix in the guest, and drive the Lima VM, whose tasks moved from `linux:` to `vm:linux-*` (the old names remain aliases). VM disks live under `~/.local/share/vms/<manager>/`.
- Moved the Windows lane to a UTM guest driven by `scripts/vm.py` (`mise run vm:windows-*`) and retired the Frost workflow: [Windows VM with UTM](guides/windows-vm.md) now covers the path from an ISO or an existing bundle to `vm:windows-test`, with snapshots, the generated SSH config, and troubleshooting; the Frost scripts, tasks, guide, and the QEMU, swtpm, and sshpass Homebrew dependencies are gone.
