---
name: Local Development State and Worktrees
date: 2026-06-29
status: resolved
---

# Local Development State and Worktrees

## Question

Why does Tessera feel fragile across multiple branches or worktrees, especially around
Ghostty VT, Linux, and Windows VM builds?

## Findings

- Ghostty VT was pinned by `scripts/ghostty-vt-version.txt` and built by
  `scripts/build-libghostty-vt.sh`, but the default output was this checkout's
  `.build/libghostty-vt`. `just core clean` removed that artifact, forcing a rebuild even
  when the pinned revision did not change.
- `Package.swift` linked `CGhosttyVT` to a revision/platform/architecture path derived
  from the same pinned revision. This is correct for branch isolation, but it needed the
  same shared cache default as the build script.
- Linux has two separate mechanisms: host-side Static Linux SDK installation, which
  belongs to the active Swift toolchain, and a Lima VM, which mounts one checkout path.
  The single default VM name (`tessera-linux`) is fine for normal use but conflicts when
  multiple worktrees need running VMs at the same time.
- Windows Frost already stores heavy image artifacts outside the repository under
  `${XDG_STATE_HOME:-~/.local/state}/tessera/windows-frost`. The directory can look like a
  clone because it contains `source/tessera-source.tar.gz`, but Frost test runs copy a
  source snapshot into the guest; `.git` is not copied.
- Manual Windows UTM is intentionally different: the guest owns a real Git checkout and
  local `.build`; `just windows-utm sync` pushes the current branch into that checkout.

## Conclusion

Move Ghostty VT's default build output to a shared machine cache, keep Windows Frost under
machine state, make the Lima VM name configurable for simultaneous worktrees, and document
all three scopes in one place. The resulting model is:

- `.build`: per-checkout SwiftPM output, safe for `just core clean`.
- `${XDG_CACHE_HOME:-~/.cache}/tessera/libghostty-vt`: shared Ghostty VT cache keyed by
  revision/platform/architecture.
- `${XDG_STATE_HOME:-~/.local/state}/tessera/windows-frost`: shared Windows Frost VM
  state.
- `TESSERA_LINUX_VM_NAME`: optional per-worktree Lima VM split when needed.
