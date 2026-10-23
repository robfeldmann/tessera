---
type: architecture
description: The baseline toolchain every lane must pass, the second lane beside it, and how each is selected.
---

# Toolchain lanes

## Decision

Two toolchains are supported, and both must pass. The baseline is Swift 6.3.3, which `.swift-version` names: Xcode 26.6 on macOS and the swift.org 6.3.3 release on Linux and Windows. It runs the required CI checks, DocC, GitHub Pages, and the Lima and Windows VMs. The second lane is Swift 6.4: Xcode 27.1 on macOS (the `xcode-27` CI leg, non-required while GitHub's image is a preview) and swift.org 6.4.1 on Linux (a required leg). There is no Windows 6.4 leg yet. The floor for consumers stays `swift-tools-version: 6.3` and macOS 26: code must compile on both lanes without raising either, and an API that needs the macOS 27 SDK goes behind `#available` at a leaf seam.

Selection is explicit in one place per lane: `.github/actions/setup-swift` takes an `xcode` version on macOS (so a runner-image change is a one-line edit) and a `swift-version` elsewhere; locally, `DEVELOPER_DIR` picks the Xcode, `TESSERA_LINUX_SWIFT_VERSION` picks the swiftly toolchain for one Lima run, and the Static Linux SDK follows the active compiler through `scripts/linux-sdk-version.sh`. The SwiftPM cache key in CI carries the toolchain label so the lanes never share a build directory.

`Package.resolved`, `Examples/Package.resolved`, and `Tessera.xcworkspace/xcshareddata/swiftpm/Package.resolved` are owned by the Swift 6.4 lane: regenerate them with Xcode 27.1 (`DEVELOPER_DIR=/Applications/Xcode-27.1.0.app/Contents/Developer swift package resolve`, and `xcodebuild -resolvePackageDependencies -workspace Tessera.xcworkspace -scheme TesseraTerminalSnapshotSupport` for the workspace). The two lanes resolve genuinely different graphs: xctest-dynamic-overlay ships a Swift 6.4 `Package.swift` that depends on swift-issue-reporting and a `Package@swift-6.0.swift` that does not, so no single root file survives a plain resolve on both. Swift 6.4 needs the swift-issue-reporting pin, and SwiftPM 6.3.3 prunes it on any plain `swift build`, `swift test`, `swift run`, or `swift package` command, as does Xcode 26.6 building the bare package (the workspace's file survives Xcode 26.6). With `--only-use-versions-from-resolved-file`, Swift 6.3.3 uses the file as written and leaves it untouched, so every repository entry point passes it: the `core:`, `ci:`, `docs:`, and `quality:architecture` tasks, the Lima and Windows test scripts, the Static Linux SDK build, and each CI `test` leg, which also fails when a resolved file is out of date for its lane and when a run changes one. A plain Swift 6.3 command's change to a resolved file is drift: discard it (`git checkout -- Package.resolved`) and never commit it.

## Why

The project has always been built with the current Xcode 26, lately 26.6, while `.swift-version` lagged at 6.3.2 and the host moved to Xcode 27.1; the three lanes had quietly become three different compilers. Making 26.6 the baseline matches what the owner builds with every day and what the published swift.org release provides on the other platforms, so every lane runs the same compiler release. Keeping 6.4 as a second lane rather than the baseline lets the floor stay where consumers are, catches 6.4 diagnostics early, and makes the eventual move a flip of two inputs rather than a migration (plan 035, Phase 2, 2026-10-21).

## Affected plans

- [Toolchain, repository conventions, and plan consolidation](../plans/toolchain-conventions-and-plan-consolidation.md)
- [Terminal I/O concurrency review fixes](../plans/terminal-io-concurrency-review-fixes.md), whose compiler-dependent steps were checked on both lanes.
