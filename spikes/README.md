# Developer tooling spikes

Time-boxed spikes for plan 033 (`docs/plans/developer-tooling.md`). Each is a standalone SwiftPM package that depends on the root package by path (`../..`) and uses public API only, so anything it could not reach is itself a finding. Nothing in the root package imports these; plan 033 step A.3 migrates the useful code by copy, and nothing new goes into `spikes/`.

| Spike | Question | Verdict |
| --- | --- | --- |
| [HeadlessRunner](HeadlessRunner/) | Can a scenario file drive a demo headlessly with a stable JSON and exit-code contract? | pass |
| [GraphQuery](GraphQuery/) | Can locators, diffs, and invariants run over `GraphDiagnostics` and the screen? | pass |
| [SvgShot](SvgShot/) | Can a `ScreenSnapshot` become a byte-stable, legible SVG? | partial |
| [LiveSocket](LiveSocket/) | Can a running app answer `text`, `tree`, `key`, and `quit` over a local socket? | pass |
| [Seams](Seams/README.md) | Are live resize, an injected clock, and a probe ID small `package` seams? | pass |
| [GhosttyDistribution](GhosttyDistribution/README.md) | Can an app that depends on Tessera by version link libghostty-vt on macOS, Linux, and Windows? | pass |

The Seams spike edits root sources, so its code is saved as a patch, [`Seams/30e4bbf.patch`](Seams/30e4bbf.patch), beside its README.

GhosttyDistribution is not a path-dependent package: it is the saved sources of a spike that consumed tagged copies of Tessera through `file://` URLs, for [libghostty-vt distribution](../docs/research/libghostty-vt-distribution.md). Its README says how to rerun it.

## Status

The spikes are frozen evidence for plan 033: they are built by hand and stay out of CI (owner decision, 2026-10-21), so nothing guards them against drift in the root package. They were last built and tested on 2026-10-22 against the root package at that date, on both toolchain lanes (Xcode 26.6 and Xcode 27.1).

HeadlessRunner's library code has been copied into the root package (`Sources/TesseraHarness` and `Tests/TesseraHarnessTests`; see [developer tooling](../docs/architecture/developer-tooling.md)), where it is maintained; its command line (`headless`, `CLI.swift`) was not copied, because the `tessera` command line is written fresh in the harness. The copy here stays as the record of what the spike proved and is no longer updated.

## Running

```sh
cd spikes/<Name>
swift build && swift test
```

Each manifest declares the root package as `.package(name: "tessera", path: "../..")`, so the dependency's identity is `tessera` whatever the checkout directory is called.
