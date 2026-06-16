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

## Planned local artifacts

Frost-generated disks and VM runtime state should stay out of Git. The prototype will use
Frost's own ignored `work/` directory or a local Tessera work directory selected by future
recipes.

Expected artifact classes:

- Base Frost Windows golden qcow2.
- Base UEFI vars file.
- Tessera toolchain golden qcow2.
- Per-run disposable overlays or one persistent development overlay.

## Current next step

Run the Phase 0 host prerequisite check once it is added to the `Justfile`.
