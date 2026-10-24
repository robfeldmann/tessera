---
name: tessera-devtools
description: Drive Tessera's own demos and check them. Use when listing, launching, picturing, or snapshot-testing a demo app, writing or running a scenario, adding a demo, running the `tessera` CLI or `mise run dev:*`, or reading what the harness reports about an app: its tree, its projection, its checks, its cost, or its trace.
version: 0.3.0
---

# Tessera developer tools

The tools run Tessera apps live in a terminal and headlessly in tests and scenarios, through one driver, so what a test renders is what a terminal shows. [Developer tooling](../../../docs/architecture/developer-tooling.md) is the design and says which tools exist yet. `Examples/Scenarios/README.md` is the scenario grammar. This skill is how to use the tools that exist, and it grows with them. Use only the commands below; a command that is not listed does not exist yet.

## What exists

| Command | Does |
| --- | --- |
| `mise run dev:apps` | List the registered apps (`tessera apps`): name, minimum size, viewports. |
| `mise run dev:launch NAME` | Run one app in this terminal (`tessera launch NAME`) until the app quits. With `TESSERA_TRACE=FILE` it writes the session's trace. |
| `mise run dev:run PATH...` | Run scenario files or directories of them (`tessera run`), with `--record`, `--repeat N`, `--timing`, and `--trace DIR`. |
| `mise run dev:shot NAME [SIZE]` | Print one app's screen as text (`tessera shot`). SIZE is `desktop`, `mobile`, `mobileScreen`, or `WxH`. |
| `mise run dev:tree NAME [SIZE]` | Print one app's node tree, one line per node (`tessera tree`). |
| `mise run dev:check NAME [SIZE]` | Run every invariant rule over one app at a size, with no input (`tessera check`). |
| `mise run dev:replay FILE --app NAME` | Run a recorded trace again against an app and report what differs (`tessera replay`). |
| `mise run dev:help [COMMAND]` | Print real help for a command. |

Every command takes `--json` or `--pretty` to force the JSON object or the text form. `tessera` is the executable of `Examples/Sources/TesseraDev`; `mise run dev:*` builds and runs it (`swift run --package-path Examples tessera …`). Standard output is one JSON object when it is not a terminal, and text when it is. Exit codes: 0 success, 1 an expectation or check failed, 2 a usage or parse error (an unknown command, app name, or flag, a bad path, a scenario that does not parse, a trace that is not one), 3 a harness error (a name registered twice, `launch` without a terminal, a golden that cannot be written).

## The loop

When an app looks wrong, work down this list and stop at the first step that names the cause:

1. `dev:launch NAME` to see it, or `dev:shot NAME mobile` to read the screen without a terminal.
2. `dev:run Examples/Scenarios/NAME-desktop.scn` and read the report: each failure's `line`, `statement`, `message`, and `expected` against `actual`.
3. `dev:tree NAME mobile` for the nodes and their frames, and a `dump` statement for everything the projection holds.
4. `dev:run … --trace DIR` and read the trace: which step redrew, and the `reasons` the library gave.
5. `dev:check NAME` (or a `check` statement) for the broken invariant, with the rule and the node.
6. Fix the library, never the demo, and rerun. Never `--record` to make a failing run pass.

## Run a scenario

```sh
mise run dev:run Examples/Scenarios --pretty
mise run dev:run Examples/Scenarios/counter-basics.scn
```

A directory runs every `.scn` under it in sorted order. With `--pretty`, or on a terminal, each scenario prints `PASS` or `FAIL` and each failure's line, statement, expected and actual values, and the screen. Without a terminal the output is one JSON object, `{"command": "run", "exitCode", "scenarios": [REPORT...]}`, and each report is `{"failures", "observations", "passed", "scenario"}`. Read a failure from its `line` and `statement` (the line of the scenario file), its `message`, and `expected` against `actual`; `screen` is the whole screen at that moment; a failed `check` adds `rule` and `node`. Two runs give the same bytes.

A failure's `verb` is the kind of failure. A statement's own verb (`expect text`, `expect screen`, `expect node`, `expect cost`, `check`, `shot`) means the app did not do what the scenario said; `size` means the app cannot take the size (`mobile` needs content with a natural height, so use `mobileScreen` for an app that fills the screen); `parse` means the scenario file is wrong at that line, and the message names what is accepted; `repeat` means a run differed from the first under `--repeat N`.

`mise run dev:shot counter mobile --pretty` and `mise run dev:tree counter mobile --pretty` picture one app without writing a scenario, which is the quickest way to see a failing state before writing the expectation that pins it.

## Write a scenario

A scenario is `Examples/Scenarios/NAME.scn`: an `app`, a `size`, an optional `term`, then input and assertions. Read `Examples/Scenarios/README.md` for the grammar; the corpus beside it is the examples to copy. A demo has two scenarios, `NAME-desktop.scn` and `NAME-mobile.scn`, each taking a `shot` at its size.

1. Picture the state with `dev:shot` or `dev:tree`.
2. Write the statements: `key`, `type`, `paste`, `bytes`, `resize` to drive; `expect text`, `expect screen <<EOF`, `expect node SEL frame`, `expect cost`, and `check` to assert; `shot NAME`, `tree`, and `dump` to observe.
3. Address nodes by meaning: `type=Text`, `layout=_FrameLayout` (what `frame` and `padding` are), `id=a` (a `ForEach` key or an `.id`), `text="…"` (a substring of what the leaf shows; an empty value is a parse error), and `nth=N`. A selector that matches nothing fails and names the types and layouts present.
4. Run it. A scenario that uses a statement the harness cannot honour yet (`wait`, `mouse`, `focus`, `expect cell`, …) fails at that line with "not yet expressible"; do not work around it with a different statement.
5. The first run of a new `shot` fails for lack of goldens. Run once with `--record`, open the two files it wrote (`shot reset` in `counter-basics.scn` writes `counter-basics/reset.txt` and `reset.grid.txt`, beside the scenario), and confirm they show what you meant.

Assert the numbers the catalog doc gives (its sizing tables and allocation fixtures), not the numbers you saw. Goldens are text and are the only artefacts a scenario commits. When a golden drifts, the app changed: decide whether the change is intended. If it is, rerun with `--record` and review the diff. **Never use `--record` to make a failing run pass**, and never edit a golden by hand to match a run.

An app that finishes ends the scenario, as it ends a live run: `key q` is the last statement that runs against the counter, and the next statement fails with "the application finished at line N". Assert what the app shows before the statement that quits it, and give each `shot` a name that differs from the others by more than case.

## Check an app

`check` runs invariant rules over the projection; it never passes by checking nothing, because every `check` names the rules it ran. `check` alone runs all five, `check RULE...` the ones named.

| Rule | Severity | Catches |
| --- | --- | --- |
| `no-dirty-after-pass` | error | a node still marked dirty after the pass that drew the screen |
| `frame-inside-clip` | warning | a leaf whose frame reaches past its clip |
| `measured-within-proposal` | error | a node that measured more than it was offered |
| `siblings-disjoint` | error | two children that show the same cell (every `ForEach` item on one frame); `ZStack` is exempt, also for the layers a `ForEach` or an `if` builds under it |
| `requirements-aggregate` | error | a terminal requirement that does not roll up to the graph, or the reverse |

An error fails the statement (exit 1); a warning is listed and does not fail a bare `check`, and a rule you name must hold. Some rules fire by contract: a fixed `frame(width:)` wider than its parent offered, a `Flex` child wider than its segment, and `Text` (which does not wrap yet) wider than the width it is offered all measure more than they were offered. When a scenario shows that on purpose, name the rules that must hold: `check no-dirty-after-pass siblings-disjoint requirements-aggregate`. A failing rule is the library's finding: fix the library and add a regression test, never the demo.

`expect cost bodies<=5 bytes<=40` bounds the last step's work (`bodies`, `bytes`, `measures`, `placements`, `renders`). Only `<=` is accepted: the counts are the library's work, so bound them loosely and never assert an exact number.

## Read a trace

`dev:run Examples/Scenarios/NAME-desktop.scn --trace /tmp/traces` writes `/tmp/traces/Examples/Scenarios/NAME-desktop.trace.jsonl`, one JSON line per step. Read each line's `event` and `reasons` first: they say why the frame was drawn (`layoutViewportChanged` for a resize, `layoutViewChanged` for a changed view). Stacks hand each child a rebuilt environment on every update, so `layoutEnvironmentChanged` and `renderEnvironmentChanged` appear on every step of an app that has a stack; read the other reasons. Then `drew` (a step that leaves the graph clean draws nothing), `nodes` (identity paths added, changed, removed), `rows` (screen rows whose text changed), and `cost`. A live session writes the same with `TESSERA_TRACE=/tmp/live.jsonl mise run dev:launch NAME`, and `dev:replay /tmp/live.jsonl --app NAME` runs it again headless and fails the first step that differs. Keys, pastes, resizes, and the terminal's focus changes (`focusGained`, `focusLost`) replay; a trace that holds a mouse event or a terminal reply is refused by name (exit 2). The trace is not promised to stay as it is; each record has a `version`.

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

`withHeadlessHost` opens a terminal session over a headless device, steps the demo through the same driver as `launch`, and feeds every frame to one Ghostty virtual terminal, so `host.screenRows` is the screen a terminal would show; `host.projection` is the projection and `host.records` the trace. `@testable import TesseraHarness` reaches it; app authors do not get this API, and run their scenarios through the public `ScenarioRunner(registry:record:)` instead (`await ScenarioRunner(registry: registry).run("Scenarios")` returns one `ScenarioReport` per scenario, with `passed`, `failures`, `description`, and `json`). `ScenarioCorpusTests` runs `Examples/Scenarios` that way. The viewports are `desktop` (80x24), `mobile` (40 columns at the demo's natural height), `mobileScreen` (40x16), and `custom`. A demo whose content grows to any height it is offered has no natural height, so `mobile` fails and names `mobileScreen`.

## Add a demo

1. Write a `final class` conforming to `Demo` in `Examples/Sources/DemoSupport`: a kebab-case `name`, a `minimum` size, `viewports`, and `fixtures` (empty when there are none). None has a default. Name the class so it does not shadow a library view (`TextDemo`, not `Text`).
2. Handle the quit key in `apply(_:)` with `isQuitKey`, and report it through `isFinished`.
3. Register it with one line in `Demos.registry()`.
4. Add its two scenarios to `Examples/Scenarios` and a snapshot test beside the others.

A demo is interactive, shows every style or variant that can differ, and reads well at 40 columns: no row is wider than the `mobile` viewport. It uses only what the library provides. A root that returns one view from a `@ViewBuilder` body is dirty after every update (the builder wraps it in a non-equatable tuple view), so a demo's draw count says nothing about whether its state changed; a body that returns its root explicitly does skip clean steps.

## Rules

- When a demo shows a library defect, fix the library and add a regression test. Never bend the demo to hide it, and never loosen a scenario until it passes.
- A name registered twice fails every command that reads the registry. Never rely on the later registration winning.
- `--record` writes goldens from what the app does now; it is for a new `shot` and a reviewed, intended change, never for a failing run you do not understand.
- The projection, the tree text, the trace, and the `expect cost` counts are free to change between releases; the scenario grammar, the rule ids, the exit codes, the report's fields, and the two golden formats are not.
