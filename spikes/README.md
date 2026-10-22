# Developer tooling spikes

Time-boxed spikes for plan 033 (`.agents/plans/033-developer-tooling.md`). Each is a
standalone SwiftPM package that depends on the root package by path (`../..`) and uses
public API only, so anything it could not reach is itself a finding. Nothing in the root
package imports these; plan 033 step A.3 migrates the useful code by copy.

| Spike                             | Question                                                                               | Verdict |
| --------------------------------- | -------------------------------------------------------------------------------------- | ------- |
| [HeadlessRunner](HeadlessRunner/) | Can a scenario file drive a demo headlessly with a stable JSON and exit-code contract? | pass    |
| [GraphQuery](GraphQuery/)         | Can locators, diffs, and invariants run over `GraphDiagnostics` and the screen?        | pass    |
| [SvgShot](SvgShot/)               | Can a `ScreenSnapshot` become a byte-stable, legible SVG?                              | partial |
| [LiveSocket](LiveSocket/)         | Can a running app answer `text`, `tree`, `key`, and `quit` over a local socket?        | pass    |
| [Seams](Seams/README.md)          | Are live resize, an injected clock, and a probe ID small `package` seams?              | pass    |

The Seams spike edits root sources, so its code is saved as a patch,
[`Seams/30e4bbf.patch`](Seams/30e4bbf.patch), beside its README.

## Status

The spikes are frozen evidence for plan 033: they are built by hand and stay out of CI
(owner decision, 2026-10-21), so nothing guards them against drift in the root package.
They were last built and tested on 2026-10-22 against the root package at that date, on
both toolchain lanes (Xcode 26.6 and Xcode 27.1).

## Running

```sh
cd spikes/<Name>
swift build && swift test
```

Each manifest declares the root package as `.package(name: "tessera", path: "../..")`, so
the dependency's identity is `tessera` whatever the checkout directory is called.
