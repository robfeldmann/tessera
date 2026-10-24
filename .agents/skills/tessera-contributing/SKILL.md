---
name: tessera-contributing
description: Use Tessera's own demos and developer tools while working in this repository. Use when running `mise run dev:*`, launching or snapshot-testing a demo, adding a demo, or fixing a library defect a demo shows. Read with the `tessera` skill, which it extends.
version: 0.1.0
---

# Contributing to Tessera with the developer tools

Everything in the [`tessera` skill](../tessera/SKILL.md) applies here: the `tessera` commands, the exit codes, and the pty recipe. This skill adds what only a Tessera contributor has: the `mise` tasks, the demos, and the demo snapshot tests. [Developer tooling](../../../docs/architecture/developer-tooling.md) is the design behind the tools.

## Commands

| mise | tessera | Does |
| --- | --- | --- |
| `mise run dev:apps` | `tessera apps` | List the registered demos: name, minimum size, viewports. |
| `mise run dev:apps --json` or `--pretty` | `tessera apps --json` or `--pretty` | Force the JSON object or the text table. |
| `mise run dev:launch NAME` | `tessera launch NAME` | Run one demo in this terminal until it quits. |
| `mise run dev:launch` | `tessera help launch`, then `tessera apps` | With no name, print the command's help and the demos, and exit 0. |

`mise run dev:*` builds and runs the `tessera` executable (`swift run --package-path Examples tessera …`). It is the product of `Examples/Sources/TesseraDev`, whose registry is `Demos.registry()` from `Examples/Sources/DemoSupport`, so the apps it lists are Tessera's demos.

With mise's shell completions enabled, `mise run dev:launch <Tab>` offers the demo names. Completion never builds: `scripts/dev-app-names.sh` asks the `Examples/.build/debug/tessera` that an earlier `dev:*` run built, and offers nothing before there is one. Run `mise run dev:apps` once after a fresh checkout, or after registering a demo. To complete `tessera` itself in your shell, see the `tessera` skill.

## Run a demo

`mise run dev:launch counter` opens the counter in your terminal. Each demo quits on `q`, matched by `isQuitKey` in `Examples/Sources/DemoSupport`. An agent without a terminal uses the pty recipe from the `tessera` skill with `mise run dev:launch counter` in place of `swift run tessera launch counter`; a headless snapshot test is the cheaper way to read a screen.

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

`withHeadlessHost` opens a terminal session over a headless device, steps the demo through the same driver as `launch`, and feeds every frame to one Ghostty virtual terminal, so `host.screenRows` is the screen a terminal would show. `@testable import TesseraHarness` reaches it; it is not API for app authors. The viewport names are the ones the `tessera` skill lists.

## Add a demo

1. Write a `final class` conforming to `Demo` in `Examples/Sources/DemoSupport`: a kebab-case `name`, a `minimum` size, `viewports`, and `fixtures` (empty when there are none). None has a default.
2. Handle the quit key in `apply(_:)` with `isQuitKey`, and report it through `isFinished`.
3. Register it with one line in `Demos.registry()`.
4. Add its snapshot test beside the counter's.

A demo is interactive and shows every style or variant that can differ. It uses only what the library provides.

## Rules

- When a demo shows a library defect, fix the library and add a regression test. Never bend the demo to hide it.
- A name registered twice fails every command that reads the registry. Never rely on the later registration winning.
