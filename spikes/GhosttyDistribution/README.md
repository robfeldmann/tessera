# GhosttyDistribution spike

Question: can an app that depends on Tessera by version (`.package(url:…, from:)`) get libghostty-vt linked on macOS, Linux, and Windows, without building it with Zig itself? The findings, the prior art, and the recommendation are in [libghostty-vt distribution](../../docs/research/libghostty-vt-distribution.md); this directory keeps the spike's sources so it can be rerun.

Verdict: pass. A source `CGhosttyVT` target with the pinned headers committed, depending on an SE-0482 static-library artifact bundle that holds only the library, built, ran a libghostty-vt round trip, and passed a test when consumed by version on macOS (Swift 6.3.3 and 6.4), Linux aarch64 (6.3.3 and 6.4.1), and Windows aarch64 (6.3.3). `.unsafeFlags` do not block a version-based consumer at tools-version 6.2 or later.

## Layout

The spike ran in `/tmp/ghostty-dist-spike/`, and the manifests here still name that path in their `file://` URLs. Binaries, build directories, and the Ghostty headers are not kept.

| Path | What it is |
| --- | --- |
| `tessera-patches/TAG.patch` | Each spike tag of a Tessera clone, as a diff from `06233f7` (`main` on 2026-10-22), Ghostty headers excluded |
| `ghostty-vt-binary/` | The binary package's manifest and the artifact bundle's `info.json` |
| `unsafe-lib-6.1/`, `unsafe-lib-6.2/`, `consumer-tv-6.1/`, `consumer-tv-6.2/` | The tools-version gate on `.unsafeFlags`: refused at 6.1, accepted at 6.2 |
| `consumer-unsafe/`, `consumer-direct/`, `consumer-xcodeproj/` | Consumers of today's layout (tags `0.1.x`), including an XcodeGen app |
| `consumer-se0482/` | Consumer of the bundle that carries headers and module map (tags `0.2.x`); fails on Xcode 26.6 and Swift Build 6.3.3 |
| `consumer-se0482-split/` | Consumer of the recommended layout (tag `0.3.0`), with the macOS build logs |
| `consumer-linux/`, `consumer-windows/` | The recommended layout (tag `0.3.x`) with a Swift Testing test, run in the Lima and UTM guests |
| `ghostty-vt-xcf/`, `consumer-xcf/` | Upstream's `tip` `ghostty-vt.xcframework` as a binary target (Apple only) |
| `url-bin/`, `consumer-url/` | `binaryTarget(url: "file://…")` is rejected: SwiftPM accepts only https |
| `matrix.sh` | Reruns a consumer under Xcode 26.6 and 27.1 with `swift build` (native and Swift Build) and `xcodebuild` |
| `libghostty-rs-build.rs` | libghostty-rs's build script, kept as prior art for building with Zig at install time |

| Tessera tag | Change |
| --- | --- |
| `0.1.0` | `main` unchanged (`.unsafeFlags`, gitignored headers) |
| `0.1.1` | Headers committed under `Sources/CGhosttyVT/include/ghostty` |
| `0.1.2` | A `CGhosttyVTDirect` product exposing the `.unsafeFlags` target |
| `0.2.0` | `CGhosttyVT` replaced by the SE-0482 bundle with headers and module map |
| `0.2.1` | `0.2.0` plus `internal import CGhosttyVT` |
| `0.3.0` | Source `CGhosttyVT` with committed headers, depending on a library-only bundle; no `.unsafeFlags` |
| `0.3.1` | `0.3.0` plus `.linkedLibrary("ntdll", .when(platforms: [.windows]))` |

## Rerunning

1. Clone Tessera to `/tmp/ghostty-dist-spike/tessera` and check out `06233f7`.
2. For each tag, apply its patch to a fresh `06233f7` checkout, copy the pinned headers from `mise run core:build-libghostty-vt` into `Sources/CGhosttyVT/include/ghostty` for tags `0.1.1` and later, commit, and tag.
3. Build libghostty-vt per platform with `mise run core:build-libghostty-vt`, place each static library in `ghostty-vt-binary/GhosttyVTLibrary.artifactbundle` as its `info.json` names, commit, and tag.
4. Copy the consumer directories to `/tmp/ghostty-dist-spike/`, then `swift build`, `swift test`, or `./matrix.sh consumer-se0482-split App`.

Like the other spikes, this one is frozen evidence: it is built by hand and stays out of CI.
