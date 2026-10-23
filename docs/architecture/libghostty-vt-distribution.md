---
type: architecture
description: How Tessera ships libghostty-vt, so apps that depend on Tessera by version, and Tessera's own builds, never run Zig.
---

# libghostty-vt distribution

## Decision

Tessera ships Ghostty's `libghostty-vt` as a prebuilt SE-0482 static-library artifact bundle, built by Tessera's CI once per Ghostty pin and published from this repository as a release asset. `CGhosttyVT` is a source C target that holds Ghostty's headers for the pin (committed under `Sources/CGhosttyVT/include/ghostty/`), depends on the `GhosttyVTLibrary` binary target, and links `ntdll` on Windows. `GhosttyVTLibrary` points at the bundle by URL and checksum in one place in `Package.swift`. `Package.swift` has no `unsafeFlags`.

The bundle holds one static library per variant and nothing else besides `info.json` and Ghostty's `LICENSE`: a universal macOS archive, glibc and musl archives for Linux x86_64 and aarch64, and `ghostty-vt-static.lib` for Windows x86_64 and aarch64. The glibc archives target glibc 2.28 and need 2.27 at run time. The bundle carries no headers and no module map.

`.github/workflows/ghostty-vt.yml` is the only place libghostty-vt is built for a release. It runs the same build scripts a contributor runs (`scripts/build-libghostty-vt.sh` and `.ps1`), packs each variant with `scripts/package-libghostty-vt-bundle.sh` and `.ps1`, and publishes on a `ghostty-vt-<first 12 characters of the pin>` tag, as a prerelease never marked latest, beside Tessera's own `v<SemVer>` releases. A pin bump builds locally and selects the result with `TESSERA_GHOSTTY_VT_BUNDLE=local` until its release exists; [Updating Ghostty VT](../guides/updating-ghostty-vt.md) is the procedure. No test, docs, or VM job builds Zig, and the `version consumer` CI job proves on macOS, Linux, and Windows that a package depending on Tessera by version links the bundle and runs a Ghostty round trip.

## Why

An app that depends on Tessera by version and uses the Ghostty-backed harness needs libghostty-vt linked. Before this, `CGhosttyVT` linked a library that every machine built with Zig into `~/.cache/tessera` and passed it through `unsafeFlags`. `unsafeFlags` were not the obstacle, since SwiftPM stopped rejecting them for 6.2+ manifests; the gitignored headers and the per-consumer Zig build were. Upstream publishes no Linux or Windows library, and its only Apple artifact is a rolling XCFramework, so someone had to build it; Tessera's CI, once per pin, is the cheapest owner ([libghostty-vt distribution](../research/libghostty-vt-distribution.md)).

The library-only bundle under a source C target is the layout that built by version on every toolchain the spike tried. A bundle that also carried the headers and module map failed on Xcode 26.6 and Swift Build 6.3.3, whose module scan does not see a module map inside a transitive artifact bundle. Publishing from this repository keeps the producer workflow, the pin, and the manifest's URL in one change; GitHub tags and releases are independent of Tessera's `v<SemVer>` releases, so the two kinds coexist. Making the harness's Ghostty part optional was the runner-up; it would have left Linux and Windows consumers building Zig.

## Consequences

- A `ghostty-vt-*` tag and its release are permanent once a Tessera version references them; a fix re-runs the workflow for the same tag, which replaces the assets.
- SwiftPM needs `unzip` on Linux to unpack the bundle.
- The musl variants cannot be audited by `swift package experimental-audit-binary-artifact`, which only checks the host's triple; they were proven by building and running a static binary instead.

## Affected plans

- [Ship libghostty-vt as a prebuilt binary](../plans/libghostty-vt-binary-distribution.md), which implemented it.
- [Build the Phase 4 view layer with the tooling that proves it](../plans/phase-4-view-layer-and-developer-tooling.md), Decision 9 (ii).
