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

   ```fish
   echo <commit-sha> > scripts/ghostty-vt-version.txt
   ```

3. Rebuild from source:

   ```fish
   scripts/build-libghostty-vt.sh --force
   ```

   Or, for the default non-forced build used by CI:

   ```fish
   just build-libghostty-vt
   ```

   The build installs the pinned artifact under
   `.build/libghostty-vt/<revision>/<platform>-<arch>/` and updates the SwiftPM-facing
   `.build/libghostty-vt/current` symlink.

4. Validate the package wiring:

   ```fish
   swift package describe
   swift build --target TesseraTerminalSnapshotSupport
   ```

5. Run the narrowest relevant tests, then lint changed files:

   ```fish
   swift test --filter <relevant-snapshot-support-tests>
   just lint-changed
   ```

6. If the Ghostty C API changed, update the `CGhosttyVT`/`VirtualTerminal` boundary only.
   Keep Ghostty-specific details out of public Tessera products.

## Just and CI behavior

The `build`, `test`, `test-coverage`, `docs-targets`, and `ci-build-test` Just recipes all
run `build-libghostty-vt` first. If the pinned artifact already exists, the script only
refreshes the `.build/libghostty-vt/current` symlink and exits quickly.

The GitHub Actions cache key includes `scripts/ghostty-vt-version.txt` and
`scripts/build-libghostty-vt.sh`. Changing the pinned SHA automatically creates a new
`libghostty-vt` cache entry. CI restores the `.build/libghostty-vt` cache before running
`just ci`, and `just ci` builds or validates `libghostty-vt` before invoking SwiftPM.

## Avoid

- Do not pin to `main` or another moving branch.
- Do not commit generated `.build/libghostty-vt` artifacts.
- Do not expose Ghostty types from public Tessera modules.
