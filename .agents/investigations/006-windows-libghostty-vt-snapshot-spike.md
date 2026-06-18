---
name: Windows libghostty-vt Snapshot Build Spike
date: 2026-06-14
status: open
---

# Windows libghostty-vt Snapshot Build Spike

## Question

Can the Ghostty-backed snapshot testing harness (`CGhosttyVT` +
`TesseraTerminalSnapshotSupport`) be made to build and run on Windows (ARM64), so Windows
gets the same snapshot coverage as macOS/Linux? If not easily, is there a better headless
VT engine to use on Windows, and what is the fallback?

This investigation backs the Phase 2 Slice 6 plan
(`.agents/plans/012-phase-2-slice-6-windows-terminal-io.md`). The plan's default is to
skip Windows snapshot coverage; this spike decides whether we can do better.

## Findings

### Ghostty the app vs. libghostty-vt the library

- The **Ghostty GUI app** is not supported on Windows and is not committed for the 1.0
  milestone. This is the widely-known "Ghostty has no Windows support."
- **libghostty-vt** — the headless VT parser our harness actually links — is explicitly
  designed to be portable: a _"zero-dependency library… that doesn't even require libc,"_
  with Windows/WASM/embedded called out as targets because _"libghostty will have broader
  support than Ghostty the GUI, due to its tighter scope."_
  ([Libghostty Is Coming — Mitchell Hashimoto](https://mitchellh.com/writing/libghostty-is-coming))
- A Sept-2025 writeup states libghostty-vt **"Windows support is available at the library
  level"** — suggesting Windows may have landed upstream since the original "planned"
  article. Treat as promising but unverified against our pinned revision.
  ([heise](https://www.heise.de/en/news/Ghostling-makes-terminal-emulation-a-C-library-11222728.html),
  [BigGo](https://biggo.com/news/202509240113_Ghostty_libghostty-vt_Library_Terminal_Emulation))

### The actual blocker is our build path, not the library

- `scripts/build-libghostty-vt.sh` clones the **full `ghostty-org/ghostty` repo** at the
  pinned revision (currently `ae52f97dcac558735cfa916ea3965f247e5c6e9e`) and builds the
  `zig_build_lib_vt` CMake target through the app's build graph (CMake + Ninja + Zig, with
  GTK/adwaita/blueprint/libxml2 on Linux).
- On Windows that graph pulls in **libxml2**, whose tarball fails to unpack because
  symlink creation needs admin rights: `unable to create symlink … AccessDenied`.
  ([ghostty discussion #11697](https://github.com/ghostty-org/ghostty/discussions/11697))
- Upstream **resolved** this by not pulling fontconfig/libxml2 when targeting Windows, and
  a contributor built the VT module standalone via a custom `buildwindows.zig` —
  confirming the vt module itself compiles on Windows when the app dependencies are
  bypassed.

### Alternatives considered (and why rejected as the oracle)

| Library                 | Lang       | Screen model | Windows ease                  | Fidelity                              | Verdict                                  |
| ----------------------- | ---------- | ------------ | ----------------------------- | ------------------------------------- | ---------------------------------------- |
| libghostty-vt (current) | Zig/C API  | ✅           | ⚠️ build-path blocker         | modern (kitty kbd, OSC 8, wide chars) | **keep**                                 |
| libvterm (Neovim/Emacs) | C99        | ✅ full      | ✅ proven on Windows          | VT220/xterm-era                       | reject                                   |
| SwiftTerm (de Icaza)    | pure Swift | ✅ full      | ✅✅ SwiftPM, no native build | xterm/VT100                           | reject                                   |
| Kitty                   | C/Python   | ✅           | n/a                           | modern                                | reject — no standalone lib               |
| Windows Terminal parser | C++        | ✅           | n/a                           | modern                                | reject — not a consumable standalone lib |

- **Kitty** ships no standalone parser; it is welded into the app.
- **Microsoft / Windows Terminal** has a capable C++ VT parser
  (`Microsoft::Console::VirtualTerminal`, MIT) but it is entangled in the Terminal
  codebase, not a reusable library; extraction would exceed the cost of fixing Ghostty.
- **libvterm** and **SwiftTerm** are real, easy-on-Windows options, but both are
  VT220/xterm-era and would not faithfully model the Phase 3 protocols (bracketed paste,
  SGR mouse, kitty keyboard, OSC 8) the snapshot harness exists to verify. SwiftTerm is
  the easiest possible integration (pure Swift, builds on Windows with zero native
  machinery), worth remembering if priorities change.

### Why not switch the oracle

1. The oracle is load-bearing for **later phases**, not just Windows — fidelity for Phase
   3 modern protocols depends on it.
2. Switching re-baselines all snapshots from slices 1–5 (shipped code), far outside this
   slice's scope.
3. A hybrid (Ghostty on macOS/Linux, other engine on Windows) is the worst option: two
   oracles → divergent baselines → cross-platform snapshot parity becomes meaningless.

## Conclusion

There is no fidelity-preserving drop-in replacement, so the right lever is **making
libghostty-vt build on Windows** rather than swapping engines. This is now feasible to
attempt locally because Phase 0 of the plan provides a Windows 11 ARM64 VM, and the known
blocker has an upstream fix. Bumping the pinned revision is acceptable (owner approved).

Recommended spike, time-boxed, run **after** the core Windows I/O work (so the slice's
real deliverable is not blocked by R&D, and the documented snapshot skip is already in
place as the fallback):

1. In the Phase 0 Windows VM, try building only the vt target — prefer a direct
   `zig build` of `lib_vt` (or the documented Windows path) that bypasses the full-app
   CMake/libxml2 graph. Bump `scripts/ghostty-vt-version.txt` to a revision containing the
   libxml2-on-Windows fix if needed.
2. If it builds: extend `scripts/build-libghostty-vt.sh` for Windows (platform/arch path,
   `.dll`/`.lib` artifact glob), add the Windows `GhosttyVTPlatform`/artifact path and
   linker settings in `Package.swift`, generate Windows snapshot baselines, and flip the
   Phase 1 Windows snapshot skips to enabled.
3. Update `docs/UpdatingGhosttyVT.md` to document the Windows build/artifact path and the
   rev-bump re-validation steps for Windows (it currently covers macOS/Linux only).
4. If the toolchain fights back within the time box: keep the documented snapshot skip on
   Windows, record exactly where it failed here, and set this investigation to `resolved`
   with that outcome.

Either way, byte-stream encoder/parser/renderer correctness is covered on Windows by the
platform-independent unit tests, so a temporary snapshot gap is acceptable.
