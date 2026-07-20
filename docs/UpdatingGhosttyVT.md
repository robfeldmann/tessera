# Updating Ghostty VT

Tessera pins Ghostty's `libghostty-vt` source revision in
`scripts/ghostty-vt-version.txt`. Use an exact commit hash, not a branch name, so local
and CI builds stay reproducible.

## When to update

Update the pinned revision when Tessera needs a Ghostty VT bug fix, API change, or release
validation. Prefer a released tag commit once the `libghostty-vt` APIs Tessera uses are
stable in a Ghostty release. Until then, use a known-good commit from
`ghostty-org/ghostty` `main`.

## Update process

1. Choose a candidate Ghostty commit.
2. Write the 40-character commit SHA to the version file:

   ```sh
   echo <commit-sha> > scripts/ghostty-vt-version.txt
   ```

3. Rebuild from source:

   ```sh
   scripts/build-libghostty-vt.sh --force
   ```

   Or, for the default non-forced build used by CI:

   ```sh
   just core build-libghostty-vt
   ```

   The build installs the pinned artifact under
   `${XDG_CACHE_HOME:-~/.cache}/tessera/libghostty-vt/<revision>/<platform>-<arch>/` by
   default, updates the diagnostic `current` symlink in that cache, and materializes the
   generated headers into the gitignored `Sources/CGhosttyVT/include/ghostty/` directory
   that the `CGhosttyVT` module map umbrellas. Set `GHOSTTY_VT_OUTPUT_DIR` if you need a
   one-off cache location.

4. Validate the package wiring:

   ```sh
   swift package describe
   swift build --target TesseraTerminalSnapshotSupport
   ```

5. Run the narrowest relevant tests, then lint changed files:

   ```sh
   swift test --filter <relevant-snapshot-support-tests>
   just quality changed
   ```

6. Rebuild the Windows Frost artifact so local Windows snapshot runs keep working:

   ```sh
   just windows-frost start
   just windows-frost build-ghostty --force
   just windows-frost stop
   ```

7. If the Ghostty C API changed, update the `CGhosttyVT`/`VirtualTerminal` boundary only.
   Keep Ghostty-specific details out of public Tessera products.

## Windows

`scripts/build-libghostty-vt.ps1` is the Windows counterpart of the bash build script. It
installs the pinned artifact under `%GHOSTTY_VT_OUTPUT_DIR%` (default
`%LOCALAPPDATA%\tessera\libghostty-vt`) `\<revision>\windows-<arch>\` and materializes the
same gitignored header directory.

Zig's Windows package fetcher cannot reach `https://deps.files.ghostty.org`
(`TlsInitializationFailed`), so the script prefetches every dependency in the pinned
checkout's `build.zig.zon.json` with `curl.exe` and hands the local archives to
`zig fetch`, verifying each resulting cache key against the manifest. It installs Zig
0.15.x from `ziglang.org` when missing (`winget` is unreliable in the Frost guest).

On Windows, `CGhosttyVT` is part of the package graph as on every other platform, and it
links the static `ghostty-vt-static.lib` plus `ntdll` (no runtime DLL discovery). Sources
gate on `#if canImport(CGhosttyVT)`. Both hosted Windows CI and local Frost test runs
(`just windows-frost test`) build the Ghostty-backed suites; Frost provisions the artifact
from the host cache populated by `just windows-frost build-ghostty`, while hosted CI
builds it with `scripts/build-libghostty-vt.ps1` behind an Actions cache.

## Just and CI behavior

The `core build`, `core test`, `core test-coverage`, `docs targets`, and `ci build-test`
Just recipes all run `core build-libghostty-vt` first. If the pinned artifact already
exists, the script only refreshes the cache's `current` symlink and exits quickly.

The GitHub Actions cache key includes `scripts/ghostty-vt-version.txt` and both build
scripts (`scripts/build-libghostty-vt.sh`, `scripts/build-libghostty-vt.ps1`). Changing
the pinned SHA automatically creates a new `libghostty-vt` cache entry. The CI test job
restores the cache, builds libghostty-vt as its own step, and saves the cache immediately
afterward — before `swift build`/`swift test` — so a later failure cannot lose the
artifact. Only installed artifacts are cached; source checkouts and intermediate build
trees are excluded.

## Avoid

- Do not pin to `main` or another moving branch.
- Do not commit generated `libghostty-vt` artifacts from `.build` or the shared cache.
- Do not expose Ghostty types from public Tessera modules.
