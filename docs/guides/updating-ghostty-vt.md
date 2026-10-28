---
type: guide
description: "Updating Ghostty VT"
---

# Updating Ghostty VT

Tessera pins Ghostty's `libghostty-vt` source revision in `scripts/ghostty-vt-version.txt`. Use an exact commit hash, not a branch name, so every build of the pin is reproducible.

Nobody builds `libghostty-vt` to build or test Tessera. `.github/workflows/ghostty-vt.yml` builds the pin once into an SE-0482 static-library artifact bundle and publishes it as the `ghostty-vt-<first 12 characters of the pin>` prerelease, and the `GhosttyVTLibrary` binary target in `Package.swift` downloads it by URL and checksum. Ghostty's headers for the pin are committed under `Sources/CGhosttyVT/include/ghostty/`. Zig is needed only to bump the pin; [libghostty-vt distribution](../architecture/libghostty-vt-distribution.md) records why.

## When to update

Update the pinned revision when Tessera needs a Ghostty VT bug fix, API change, or release validation. libghostty-vt is versioned apart from the Ghostty app: a Ghostty tag such as `v1.4.0` is an app release, and libghostty-vt has no tag of its own yet. Upstream plans one more C API pass with an ABI break and then a libghostty 1.0 tag before Ghostty 1.5 ([Ghostty 1.4 release notes](https://ghostty.org/docs/install/release-notes/1-4-0)). The pin stays where it is until that tag exists (owner decision, 2026-10-27, after the [Ghostty 1.4 review](../research/ghostty-1.4-review.md)); from then on prefer libghostty-vt release tags, and use a known-good commit from `ghostty-org/ghostty` `main` only for a fix Tessera needs before the next tag.

## Update process

1. Choose a candidate Ghostty commit and write its 40-character SHA to the version file:

   ```sh
   echo <commit-sha> > scripts/ghostty-vt-version.txt
   ```

   If the candidate's `build.zig.zon` sets a different `minimum_zig_version`, move every Zig consumer to it in the same change: `zig` in `mise.toml` (then `mise install` to update `mise.lock`), `zig_version` in `scripts/config/lima/tessera-linux.yaml`, and the `GHOSTTY_VT_ZIG_VERSION` defaults in `scripts/build-libghostty-vt.sh` and `scripts/build-libghostty-vt.ps1`. An existing Lima instance keeps the provisioning script it was created with, so update its copy too (`limactl edit --set '.provision[1].script |= sub("<old>"; "<new>")' tessera-linux`) or recreate it; the next `limactl start` installs the new Zig. Rerun `mise run vm:windows-provision` for the Windows guest.

2. Build the pin and re-vendor its headers:

   ```sh
   mise run core:build-libghostty-vt -- --update-headers
   ```

   This runs `scripts/build-libghostty-vt.sh`, which needs Zig, CMake, and Ninja (`mise install` provides them) and installs the build under `${XDG_CACHE_HOME:-~/.cache}/tessera/libghostty-vt/<revision>/<variant>/` (set `GHOSTTY_VT_OUTPUT_DIR` for another location). `--update-headers` copies the build's headers over `Sources/CGhosttyVT/include/ghostty/`; review that diff, because it is the C API Tessera compiles against. Without the flag, the script fails when the committed headers differ from the pin's and names the files.

3. Package the build as a local bundle and test against it:

   ```sh
   scripts/package-libghostty-vt-bundle.sh
   TESSERA_GHOSTTY_VT_BUNDLE=local swift test
   ```

   The packaging script writes `.build/ghostty-vt/GhosttyVTLibrary.artifactbundle`, and `TESSERA_GHOSTTY_VT_BUNDLE=local` makes `Package.swift` link that bundle instead of the published one. Repeat it on Linux in the Lima guest, which mounts the checkout and has Zig, CMake, and Ninja: in `limactl shell tessera-linux`, run `scripts/build-libghostty-vt.sh`, `scripts/package-libghostty-vt-bundle.sh` (it merges the Linux variant into the same bundle), and `TESSERA_GHOSTTY_VT_BUNDLE=local swift test`. On Windows, in the UTM guest after `mise run vm:windows-push`:

   ```powershell
   scripts\build-libghostty-vt.ps1
   scripts\package-libghostty-vt-bundle.ps1
   $env:TESSERA_GHOSTTY_VT_BUNDLE = "local"; swift test --no-parallel
   ```

4. If the Ghostty C API changed, update the `CGhosttyVT`/`VirtualTerminal` boundary only. Keep Ghostty-specific details out of public Tessera products.

5. Check the third-party licenses. `ar t` on the built archive lists the objects linked into it, and the pinned `build.zig.zon` and `pkg/*/build.zig.zon` name the dependencies' versions. Update the table and the license files in `scripts/ghostty-vt-licenses/` when a component, version, or license changed.

6. Open the pull request. The `test` jobs still link the previous release until step 8: they compile the new headers against the old library, so they fail when Tessera uses a symbol the old library lacks, and they never exercise the new pin. Your local runs from step 3 do. To build every variant on hosted runners before publishing anything, dispatch the producer on the branch: `gh workflow run ghostty-vt.yml --ref <branch>` builds, audits, and assembles the bundle, and publishes nothing.

7. Publish the bundle by pushing the tag for the new pin on the pull request's head commit:

   ```sh
   revision="$(tr -d '[:space:]' < scripts/ghostty-vt-version.txt)"
   git tag "ghostty-vt-${revision:0:12}"
   git push origin "ghostty-vt-${revision:0:12}"
   ```

   The workflow checks that the tag names the pin, then creates the prerelease with `GhosttyVTLibrary.artifactbundle.zip` and `checksum.txt`, never marked latest. It publishes only when all seven variants built: if a leg fails, fix the cause and run `gh run rerun --failed` on the tag's run. Once a release has its zip, the workflow refuses to replace it, because a rebuilt zip never has the same bytes and every `Package.swift` that pins its checksum would stop resolving. While no commit of `Package.swift` references the tag yet, `gh workflow run ghostty-vt.yml --ref <tag> -f replace-assets=true` rebuilds and replaces it; after that, never. To republish a pin's bundle later (for example, with a fixed workflow), push a new tag `ghostty-vt-<prefix>-r<N>` with N of 2 or more and point `Package.swift` at it; the new URL also keeps SwiftPM from refusing a changed checksum for a URL it has already downloaded. `-f allow-partial=true` publishes without a variant that cannot be built; record why in the pull request.

8. Point `Package.swift` at the new release: in the `GhosttyVTLibrary` block, replace the tag in the URL and set `checksum` to the contents of the release's `checksum.txt`. Push; the `test`, `version consumer`, and `static Linux SDK` jobs now link the new bundle on every platform and architecture.

## Variants

| Variant | Triples | Built on |
| --- | --- | --- |
| `macos-universal` | `arm64-apple-macosx`, `x86_64-apple-macosx` | `macos-26`, `--target aarch64-macos` and `--target x86_64-macos`, joined with `lipo` |
| `linux-x86_64`, `linux-arm64` | `x86_64-unknown-linux-gnu`, `aarch64-unknown-linux-gnu` | `ubuntu-latest` and `ubuntu-24.04-arm`, `--target <arch>-linux-gnu.2.28` (glibc 2.27 or later at run time) |
| `linux-musl-x86_64`, `linux-musl-arm64` | `x86_64-swift-linux-musl`, `aarch64-swift-linux-musl` | `ubuntu-latest`, `--target <arch>-linux-musl`, for the Static Linux SDK |
| `windows-x86_64`, `windows-arm64` | `x86_64-unknown-windows-msvc`, `aarch64-unknown-windows-msvc` | `windows-latest` and `windows-11-arm`, `build-libghostty-vt.ps1` |

Each variant directory holds only the static library (`libghostty-vt.a`, or `ghostty-vt-static.lib` on Windows). The bundle root holds `info.json`, Ghostty's `LICENSE`, and `THIRD_PARTY_LICENSES/`, a copy of `scripts/ghostty-vt-licenses/` with the licenses of the other components linked into the archives (Highway, simdutf, Wuffs, uucode and its Unicode data and UTF-8 decoder, and Zig's standard library and compiler-rt). Headers and a module map stay out of the bundle, because Xcode 26.6 and Swift Build 6.3.3 do not see a module map inside a transitive artifact bundle. `CGhosttyVT` links `ntdll` on Windows itself, because Zig's standard library calls it and a bundle cannot declare system libraries. SwiftPM needs `unzip` on Linux to unpack the bundle. The packaging scripts refuse a variant whose triples another variant in the bundle already claims, such as a local `macos-arm64` added to a CI bundle's `macos-universal`.

## Windows

`scripts/build-libghostty-vt.ps1` is the Windows counterpart of the bash build script. It installs the pinned build under `%GHOSTTY_VT_OUTPUT_DIR%` (default `%LOCALAPPDATA%\tessera\libghostty-vt`) `\<revision>\windows-<arch>\`, checks the committed headers the same way, and takes `-UpdateHeaders` to re-vendor them.

Zig fetches the pinned checkout's dependencies itself during `zig build`. On Windows that needs Zig 0.17 or later: Zig 0.15 could not reach `https://deps.files.ghostty.org` there (`TlsInitializationFailed`). Do not seed the cache with `zig fetch <archive>`: Zig 0.17.0 stores such an archive with its top-level directory unstripped, and `zig build` then rejects the package with a hash mismatch. The script installs the Zig named by `GHOSTTY_VT_ZIG_VERSION` (default: the same version `mise.toml` pins) from `ziglang.org` when no `zig` of that version is on `PATH`; `mise run vm:windows-provision` installs that Zig into the guest ahead of time.

## Avoid

- Do not pin to `main` or another moving branch.
- Do not commit `libghostty-vt` binaries; they ship only as release assets.
- Do not create a `ghostty-vt-*` tag for anything but the pinned revision, and do not move or delete a published one: released versions of Tessera point at it.
- Do not expose Ghostty types from public Tessera modules.
