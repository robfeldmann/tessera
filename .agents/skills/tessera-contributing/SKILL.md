---
name: tessera-contributing
description: Use Tessera's own demos, scenario corpus, and developer tools while working in this repository. Use when running `mise run dev:*`, launching, picturing, checking, tracing, or snapshot-testing a demo, adding a demo and its scenarios, running `Examples/Scenarios`, or fixing a library defect a demo shows. Read with the `tessera` skill, which it extends.
version: 0.3.0
---

# Contributing to Tessera with the developer tools

Everything in the [`tessera` skill](../tessera/SKILL.md) applies here: the `tessera` commands, the scenario grammar, goldens, checks, traces, the exit codes, and the pty recipe. This skill adds what only a Tessera contributor has: the `mise` tasks, the demos, the scenario corpus, and the demo snapshot tests. [Developer tooling](../../../docs/architecture/developer-tooling.md) is the design behind the tools.

## Commands

| mise | tessera | Does |
| --- | --- | --- |
| `mise run dev:apps` | `tessera apps` | List the registered demos: name, minimum size, viewports. |
| `mise run dev:launch NAME` | `tessera launch NAME` | Run one demo in this terminal until it quits. With `TESSERA_TRACE=FILE` it writes the session's trace. |
| `mise run dev:launch`, `dev:shot`, or `dev:tree` | `tessera help COMMAND`, then `tessera apps` | With no name, print the command's help and the demos, and exit 0. `dev:run` with no path prints its help. |
| `mise run dev:run PATH...` | `tessera run PATH...` | Run scenario files or directories of them, with `--record`, `--repeat N`, `--timing`, and `--trace DIR`. |
| `mise run dev:shot NAME [SIZE]` | `tessera shot NAME [SIZE]` | Print one demo's screen as text. |
| `mise run dev:tree NAME [SIZE]` | `tessera tree NAME [SIZE]` | Print one demo's node tree. |
| `mise run dev:check NAME [SIZE]` | `tessera check NAME [SIZE]` | Run every invariant rule over one demo at a size, with no input. |
| `mise run dev:replay FILE --app NAME` | `tessera replay FILE --app NAME` | Run a recorded trace again against a demo and report what differs. |
| `mise run dev:help [COMMAND]` | `tessera help [COMMAND]` | Print the commands, or one command's usage. |

`mise run dev:*` builds and runs the `tessera` executable (`swift run --package-path Examples tessera …`), and `--json` and `--pretty` go through to it. It is the product of `Examples/Sources/TesseraDev`, whose registry is `Demos.registry()` from `Examples/Sources/DemoSupport`, so the apps it lists are Tessera's demos.

With mise's shell completions enabled, `mise run dev:launch <Tab>` offers the demo names, `dev:shot` and `dev:tree` offer them too and then the sizes, and `dev:run` offers `.scn` files and directories. Completion never builds: `scripts/dev-app-names.sh` asks the `Examples/.build/debug/tessera` that an earlier `dev:*` run built, and offers nothing before there is one. Run `mise run dev:apps` once after a fresh checkout, or after registering a demo. To complete `tessera` itself in your shell, see the `tessera` skill.

## The loop

The `tessera` skill's loop, through `mise`: `dev:launch NAME` or `dev:shot NAME mobile` to see the demo; `dev:run Examples/Scenarios/NAME-desktop.scn` to read the report; `dev:tree NAME mobile` and a `dump` statement for the nodes and the projection; `dev:run … --trace DIR` for why a step redrew; `dev:check NAME` for the broken invariant. Step 6 is to fix the library, never the demo, and rerun. `dev:run Examples/Scenarios/NAME-desktop.scn --trace /tmp/traces` writes `/tmp/traces/Examples/Scenarios/NAME-desktop.trace.jsonl`, and a live trace is `TESSERA_TRACE=/tmp/live.jsonl mise run dev:launch NAME`, which `dev:replay /tmp/live.jsonl --app NAME` runs again headless.

## Run a demo

`mise run dev:launch counter` opens the counter in your terminal. Each demo quits on `q`, matched by `isQuitKey` in `Examples/Sources/DemoSupport`. An agent without a terminal uses the pty recipe from the `tessera` skill with `mise run dev:launch counter` in place of `swift run tessera launch counter`; `mise run dev:shot` or a scenario is the cheaper way to read a screen.

## The scenario corpus

`Examples/Scenarios` holds Tessera's scenarios, `NAME.scn` with its goldens (`NAME.txt` and `NAME.grid.txt` for each `shot`) in `NAME/` beside it. A demo has two scenarios, `NAME-desktop.scn` and `NAME-mobile.scn`, each taking a `shot` at its size. `mise run dev:run Examples/Scenarios --pretty` runs all of it, as CI does on macOS, Linux, and Windows, and `ScenarioCorpusTests` in `Examples/Tests/DemoSupportTests` runs the same files through `ScenarioRunner`. `Examples/Scenarios/README.md` is the grammar's source; the `tessera` skill carries the part an app author needs, so a change to the grammar updates both. A new `shot` needs one run with `--record`, and the goldens it writes are reviewed and committed with the scenario. Assert the numbers the catalog doc gives (its sizing tables and allocation fixtures), not the numbers you saw. The corpus is the examples to copy: `counter-basics.scn` drives input, `expect screen`, and a `shot`.

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

`withHeadlessHost` opens a terminal session over a headless device, steps the demo through the same driver as `launch`, and feeds every frame to one Ghostty virtual terminal, so `host.screenRows` is the screen a terminal would show. `host.projection` is the projection and `host.records` the trace. `@testable import TesseraHarness` reaches them; they are not API for app authors, who run their scenarios through the public `ScenarioRunner`. The viewport names are the ones the `tessera` skill lists.

## Add a demo

1. Write a `final class` conforming to `Demo` in `Examples/Sources/DemoSupport`: a kebab-case `name`, a `minimum` size, `viewports`, and `fixtures` (empty when there are none). None has a default. Name the class so it does not shadow a library view (`TextDemo`, not `Text`).
2. Handle the quit key in `apply(_:)` with `isQuitKey`, and report it through `isFinished`.
3. Register it with one line in `Demos.registry()`.
4. Add its two scenarios to `Examples/Scenarios` and a snapshot test beside the others.

A demo is interactive, shows every style or variant that can differ, and reads well at 40 columns: no row is wider than the `mobile` viewport. It uses only what the library provides. A root that returns one view from a `@ViewBuilder` body is dirty after every update (the builder wraps it in a non-equatable tuple view), so a demo's draw count says nothing about whether its state changed; a body that returns its root explicitly does skip clean steps.

## Rules

- When a demo shows a library defect, fix the library and add a regression test. Never bend the demo to hide it, and never loosen a scenario until it passes.
- A failing check rule is the library's finding: fix the library and add a regression test. Some rules fire by contract: a fixed `frame(width:)` wider than its parent offered, a `Flex` child wider than its segment, and `Text`, which does not wrap, wider than the width it is offered. A scenario that shows that on purpose names the rules that must hold, such as `check no-dirty-after-pass siblings-disjoint requirements-aggregate`.
- A name registered twice fails every command that reads the registry. Never rely on the later registration winning.
- `--record` writes goldens from what the demo does now; it is for a new `shot` and a reviewed, intended change, never for a failing run you do not understand.
- The projection, the tree text, the trace, and the `expect cost` counts are free to change between releases; the scenario grammar, the rule ids, the exit codes, the report's fields, and the two golden formats are not.
