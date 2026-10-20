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

The Seams spike edits root sources, so its code lives on branch `devtools-seams-spike`
(one commit on top of this branch's base); only its README is here.

## Running

```sh
cd spikes/<Name>
swift build && swift test
```

SwiftPM names a path dependency after its directory, so these manifests refer to the root
package as `devtools`, the name of the worktree they were written in. `LiveSocket` derives
the name from `#filePath` instead; the others need the string changed when built from a
checkout with a different directory name.
