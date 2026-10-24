---
name: tessera-devtools
description: Drive Tessera's own demos and check them. Use when listing, launching, or snapshot-testing a demo app, adding a demo, running the `tessera` CLI or `mise run dev:*`, or reading what the harness reports about an app.
version: 0.1.0
---

# Tessera developer tools

The tools run Tessera apps live in a terminal and headlessly in tests, through one driver, so what a test renders is what a terminal shows. [Developer tooling](../../../docs/architecture/developer-tooling.md) is the design and says which tools exist yet. This skill is how to use the ones that do, and it grows with them. Use only the commands below; a command that is not listed does not exist yet.

## What exists

| Command | Does |
| --- | --- |
| `mise run dev:apps` | List the registered apps (`tessera apps`): name, minimum size, viewports. |
| `mise run dev:launch NAME` | Run one app in this terminal (`tessera launch NAME`) until the app quits. |
| `mise run dev:apps --json` or `--pretty` | Force the JSON object or the text table. |

`tessera` is the executable of `Examples/Sources/TesseraDev`; `mise run dev:*` builds and runs it (`swift run --package-path Examples tessera …`). Standard output is one JSON object when it is not a terminal, and a text table when it is. Exit codes: 0 success, 2 a usage error (an unknown command or app name, with the accepted names listed), 3 a harness error (a name registered twice, or `launch` without a terminal). `tessera help [COMMAND]` prints real text.

## Run a demo

`mise run dev:launch counter` opens the counter in your terminal. The harness has no quit key: each demo quits on `q`, matched by `isQuitKey` in `Examples/Sources/DemoSupport`. A run needs a real terminal on standard input and output. An agent without one runs it under a pty:

```sh
expect -c 'set timeout 20; spawn sh -c "stty rows 24 cols 80; exec mise run dev:launch counter"; expect "Count"; send "+"; send "q"; expect eof'
```

Read the screen from the bytes the run wrote (cursor addressing, then text); a headless snapshot test is the cheaper way to read a screen.

## Snapshot-test a demo

A demo's snapshot test is a few lines in `Examples/Tests/DemoSupportTests`, run by `swift test --package-path Examples`:

```swift
@Test @MainActor
func `the counter counts`() async throws {
  try await Demos.registry().withHeadlessHost("counter", at: .mobile) { host in
    try await host.send(.key(Key(code: .character("+"))))
    #expect(host.screenRows[2].hasSuffix("1"))
  }
}
```

`withHeadlessHost` opens a terminal session over a headless device, steps the demo through the same driver as `launch`, and feeds every frame to one Ghostty virtual terminal, so `host.screenRows` is the screen a terminal would show. `@testable import TesseraHarness` reaches it; app authors do not get this API. The viewports are `desktop` (80x24), `mobile` (40 columns at the demo's natural height), `mobileScreen` (40x16), and `custom`. A demo whose content grows to any height it is offered has no natural height, so `mobile` fails and names `mobileScreen`.

## Add a demo

1. Write a `final class` conforming to `Demo` in `Examples/Sources/DemoSupport`: a kebab-case `name`, a `minimum` size, `viewports`, and `fixtures` (empty when there are none). None has a default.
2. Handle the quit key in `apply(_:)` with `isQuitKey`, and report it through `isFinished`.
3. Register it with one line in `Demos.registry()`.
4. Add its snapshot test beside the counter's.

A demo is interactive and shows every style or variant that can differ. It uses only what the library provides.

## Rules

- When a demo shows a library defect, fix the library and add a regression test. Never bend the demo to hide it.
- A name registered twice fails every command that reads the registry. Never rely on the later registration winning.
