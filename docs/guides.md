---
type: hub
stage: living
description: Contributor how-tos for the local environments and recurring maintenance.
---

# Guides

How-tos for contributors. The [contributing guide](../CONTRIBUTING.md) covers the workflow and the gates; these pages cover one environment or recurring task each.

- [Local development state](guides/local-development-state.md): Where the Ghostty VT cache, Lima VM, UTM Windows guest, and other local state live, and how to diagnose them.
- [Tessera VMs](guides/vms.md): The macOS (Tart), Linux (Lima), and Windows (UTM) VMs: storage, names, building a macOS base with Xcode, and the `vm:` tasks.
- [Updating Ghostty VT](guides/updating-ghostty-vt.md): How to move the pinned libghostty-vt revision and rebuild it on every lane.
- [Windows VM with UTM](guides/windows-vm.md): The Windows 11 ARM64 test guest: create or import it, provision it, snapshot it, push the working tree, and run the tests.
