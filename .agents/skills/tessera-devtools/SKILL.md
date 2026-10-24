---
name: tessera-devtools
description: Drive Tessera's own demos and check them. Use when listing, launching, picturing, or snapshot-testing a demo app, writing or running a scenario, adding a demo, running the `tessera` CLI or `mise run dev:*`, or reading what the harness reports about an app.
version: 0.2.0
---

# Tessera developer tools

The tools run Tessera apps live in a terminal and headlessly in tests and scenarios, through one driver, so what a test renders is what a terminal shows. [Developer tooling](../../../docs/architecture/developer-tooling.md) is the design and says which tools exist yet. `Examples/Scenarios/README.md` is the scenario grammar. This skill is how to use the tools that exist, and it grows with them. Use only the commands below; a command that is not listed does not exist yet.

## What exists

| Command | Does |
| --- | --- |
| `mise run dev:apps` | List the registered apps (`tessera apps`): name, minimum size, viewports. |
| `mise run dev:launch NAME` | Run one app in this terminal (`tessera launch NAME`) until the app quits. |
| `mise run dev:run PATH...` | Run scenario files or directories of them (`tessera run`), with `--record`, `--repeat N`, and `--timing`. |
| `mise run dev:shot NAME [SIZE]` | Print one app's screen as text (`tessera shot`). SIZE is `desktop`, `mobile`, `mobileScreen`, or `WxH`. |
| `mise run dev:tree NAME [SIZE]` | Print one app's node tree, one line per node (`tessera tree`). |
| `mise run dev:help [COMMAND]` | Print real help for a command. |

Every command takes `--json` or `--pretty` to force the JSON object or the text form. `tessera` is the executable of `Examples/Sources/TesseraDev`; `mise run dev:*` builds and runs it (`swift run --package-path Examples tessera …`). Standard output is one JSON object when it is not a terminal, and text when it is. Exit codes: 0 success, 1 an expectation failed, 2 a usage or parse error (an unknown command, app name, or flag, a bad path, a scenario that does not parse), 3 a harness error (a name registered twice, `launch` without a terminal, a golden that cannot be written).

`mise run dev:check` and `mise run dev:replay` exist and exit 2 with "not yet available": there are no invariant rules and no recorded traces yet. Do not read their refusal as a pass, and do not write a `check` statement in a scenario; the parser refuses it by name.

## Run a scenario

```sh
mise run dev:run Examples/Scenarios --pretty
mise run dev:run Examples/Scenarios/counter-basics.scn
```

A directory runs every `.scn` under it in sorted order. With `--pretty`, or on a terminal, each scenario prints `PASS` or `FAIL` and each failure's line, statement, expected and actual values, and the screen. Without a terminal the output is one JSON object, `{"command": "run", "exitCode", "scenarios": [REPORT...]}`, and each report is `{"failures", "observations", "passed", "scenario"}`. Read a failure from its `line` and `statement` (the line of the scenario file), its `message`, and `expected` against `actual`; `screen` is the whole screen at that moment. Two runs give the same bytes.

A failure's `verb` is the kind of failure. A statement's own verb (`expect text`, `expect screen`, `expect node`, `shot`) means the app did not do what the scenario said; `size` means the app cannot take the size (`mobile` needs content with a natural height, so use `mobileScreen` for an app that fills the screen); `parse` means the scenario file is wrong at that line, and the message names what is accepted; `repeat` means a run differed from the first under `--repeat N`.

`mise run dev:shot counter mobile --pretty` and `mise run dev:tree counter mobile --pretty` picture one app without writing a scenario, which is the quickest way to see a failing state before writing the expectation that pins it.

## Write a scenario

A scenario is `Examples/Scenarios/NAME.scn`: an `app`, a `size`, an optional `term`, then input and assertions. Read `Examples/Scenarios/README.md` for the grammar; the corpus beside it is the examples to copy.

1. Picture the state with `dev:shot` or `dev:tree`.
2. Write the statements: `key`, `type`, `paste`, `bytes`, `resize` to drive; `expect text`, `expect screen <<EOF`, `expect node SEL frame` to assert; `shot NAME` for a golden.
3. Run it. A scenario that uses a statement the harness cannot honour yet (`wait`, `mouse`, `focus`, `expect cell`, …) fails at that line with "not yet expressible"; do not work around it with a different statement.
4. The first run of a new `shot` fails for lack of a golden. Run once with `--record`, open the file it wrote (`shot reset` in `counter-basics.scn` writes `counter-basics/reset.txt`, beside the scenario), and confirm it shows what you meant.

Goldens are text and are the only artefacts a scenario commits. When a golden drifts, the app changed: decide whether the change is intended. If it is, rerun with `--record` and review the diff. **Never use `--record` to make a failing run pass**, and never edit a golden by hand to match a run.

An app that finishes ends the scenario, as it ends a live run: `key q` is the last statement that runs against the counter, and the next statement fails with "the application finished at line N". Assert what the app shows before the statement that quits it, and give each `shot` a name that differs from the others by more than case.

## Run a demo

`mise run dev:launch counter` opens the counter in your terminal. The harness has no quit key: each demo quits on `q`, matched by `isQuitKey` in `Examples/Sources/DemoSupport`. A run needs a real terminal on standard input and output. An agent without one runs it under a pty:

```sh
expect -c 'set timeout 20; spawn sh -c "stty rows 24 cols 80; exec mise run dev:launch counter"; expect "Count"; send "+"; send "q"; expect eof'
```

Read the screen from the bytes the run wrote (cursor addressing, then text); `dev:shot` or a scenario is the cheaper way to read a screen.

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

`withHeadlessHost` opens a terminal session over a headless device, steps the demo through the same driver as `launch`, and feeds every frame to one Ghostty virtual terminal, so `host.screenRows` is the screen a terminal would show. `@testable import TesseraHarness` reaches it; app authors do not get this API, and run their scenarios through the public `ScenarioRunner(registry:record:)` instead (`await ScenarioRunner(registry: registry).run("Scenarios")` returns one `ScenarioReport` per scenario, with `passed`, `failures`, `description`, and `json`). `ScenarioCorpusTests` runs `Examples/Scenarios` that way. The viewports are `desktop` (80x24), `mobile` (40 columns at the demo's natural height), `mobileScreen` (40x16), and `custom`. A demo whose content grows to any height it is offered has no natural height, so `mobile` fails and names `mobileScreen`.

## Add a demo

1. Write a `final class` conforming to `Demo` in `Examples/Sources/DemoSupport`: a kebab-case `name`, a `minimum` size, `viewports`, and `fixtures` (empty when there are none). None has a default.
2. Handle the quit key in `apply(_:)` with `isQuitKey`, and report it through `isFinished`.
3. Register it with one line in `Demos.registry()`.
4. Add its scenario to `Examples/Scenarios` and a snapshot test beside the counter's.

A demo is interactive and shows every style or variant that can differ. It uses only what the library provides.

## Rules

- When a demo shows a library defect, fix the library and add a regression test. Never bend the demo to hide it.
- A name registered twice fails every command that reads the registry. Never rely on the later registration winning.
- `--record` writes goldens from what the app does now; it is for a new `shot` and a reviewed, intended change, never for a failing run you do not understand.
