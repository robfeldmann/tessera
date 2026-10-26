---
name: tessera
description: Drive and check an app built on Tessera with the `tessera` command line. Use when writing a Tessera `Application`, registering it in an `ApplicationRegistry`, wiring the executable that calls `HarnessCLI.main(registry:)`, launching it, picturing its screen or node tree, writing or running a scenario with `tessera run`, running invariant checks, or reading what the harness reports about it: its failures, its checks, its cost, or its trace.
version: 0.3.0
---

# Tessera for app authors

`TesseraHarness` runs a Tessera app live in a terminal and headlessly in tests and scenarios, through one driver, so what a check renders is what a terminal shows. The `tessera` command line is how you and an agent reach it: you register your apps, wire one executable, and run commands against it. Use only the commands listed here.

## Wire the executable

1. Conform your app to `Application` where the type is declared: a `final class` with a `body`, an `apply(_:)` that receives each input event the views left unhandled (and every resize), and an `isFinished` that tells the harness to stop. The harness has no quit key of its own; the app decides which key quits.
2. Register it in an `ApplicationRegistry` under a kebab-case name, with its minimum size and the viewports it is checked at. A viewport is `.desktop` (80x24), `.mobile` (40 columns at the height the app's content needs), `.mobileScreen` (40x16), or `.custom(TerminalSize)`. There is no default viewport list. An app whose content grows to any height it is offered has no natural height, so `.mobile` fails and names `.mobileScreen`.
3. Build the registry in one function, so the executable and your tests register the same apps.
4. Make an executable whose body is `HarnessCLI.main(registry:)`, and name its product `tessera` so every command below runs as `swift run tessera COMMAND`.

```swift
// Package.swift
let package = Package(
  name: "MyApplication",
  platforms: [.macOS(.v26)],
  products: [.executable(name: "tessera", targets: ["MyAppDev"])],
  dependencies: [
    .package(url: "https://github.com/robfeldmann/tessera.git", branch: "main")
  ],
  targets: [
    .target(
      name: "MyApp",
      dependencies: [
        .product(name: "Tessera", package: "tessera"),
        .product(name: "TesseraHarness", package: "tessera"),
      ]
    ),
    .executableTarget(
      name: "MyAppDev",
      dependencies: ["MyApp", .product(name: "TesseraHarness", package: "tessera")]
    ),
    .testTarget(
      name: "MyAppTests",
      dependencies: ["MyApp", .product(name: "TesseraHarness", package: "tessera")]
    ),
  ]
)
```

```swift
// Sources/MyApp/Counter.swift
import Tessera

public final class Counter: Application {
  public private(set) var count = 0
  public private(set) var isFinished = false

  public init() {}

  public var body: some View {
    VStack {
      Text("Count: \(count)")
      Text("+ up   q quit")
    }
  }

  public func apply(_ event: InputEvent) {
    guard case .key(let key) = event, key.kind == .press else { return }
    switch key.code {
    case .character("+"): count += 1
    case .character("q"): isFinished = true
    default: break
    }
  }
}
```

```swift
// Sources/MyApp/Registry.swift
import Tessera
import TesseraHarness

public func makeRegistry() -> ApplicationRegistry {
  var registry = ApplicationRegistry()
  registry.register(
    "counter",
    minimum: TerminalSize(columns: 20, rows: 3),
    viewports: [.desktop, .mobile]
  ) { Counter() }
  return registry
}
```

```swift
// Sources/MyAppDev/main.swift
import MyApp
import TesseraHarness

await HarnessCLI.main(registry: makeRegistry())
```

The factory closure runs on the main actor once per run, so every run starts from a fresh app. A further registration of the same app in another starting state is one more `register` call under another name.

## Commands

| tessera | Does |
| --- | --- |
| `tessera apps` | List the registered apps: name, minimum size, viewports. |
| `tessera launch NAME` | Run one app in this terminal until the app quits. With `TESSERA_TRACE=FILE` it writes the session's trace. |
| `tessera run PATH...` | Run scenario files (`.scn`) or directories of them, with `--record`, `--repeat N`, `--timing`, and `--trace DIR`. |
| `tessera shot NAME [SIZE]` | Print one app's screen as text. SIZE is `desktop` (the default), `mobile`, `mobileScreen`, or `WxH`. |
| `tessera tree NAME [SIZE]` | Print one app's node tree, one line per node: identity, type, layout, frame, clip. |
| `tessera check NAME [SIZE]` | Run every invariant rule over one app at a size, with no input. |
| `tessera replay FILE --app NAME` | Run a recorded trace again against an app and report what differs. |
| `tessera help [COMMAND]` | Print the commands, or one command's usage. `tessera COMMAND --help` prints the same. |
| `tessera --generate-completion-script SHELL` | Print a completion script for `fish`, `zsh`, or `bash`. |

Every command takes `--json` or `--pretty` to force the JSON object or the text form. Standard output is one JSON object when it is not a terminal, and text when it is. `apps` prints `{"apps": [{"minimum", "name", "viewports"}], "command": "apps"}`, sorted by name, where `minimum` is `null` for an app that declares none. A failed command prints `{"command", "exitCode", "message"}`.

Exit codes: 0 success, 1 an expectation or check failed, 2 a usage or parse error (an unknown command, app name, or flag, a missing or extra argument, a flag that takes a value given twice, `--json` with `--pretty`, a bad path, a scenario that does not parse, a trace that is not one; the message lists the accepted commands or app names, or the command's usage), 3 a harness error (a name registered twice, `launch` without a terminal, a golden that cannot be written). `--json` and `--pretty` go after the command or before it.

## Complete commands and app names

The executable prints a completion script that completes the commands, their flags, and the registered app names, so `tessera launch <Tab>` offers your apps. Install it once per shell, with `tessera` on your `PATH` (the script runs it to ask for the names):

```sh
# fish
tessera --generate-completion-script fish > ~/.config/fish/completions/tessera.fish
# zsh: a directory on $fpath, then restart the shell
tessera --generate-completion-script zsh > ~/.zfunc/_tessera
# bash: with bash-completion's per-command directory
tessera --generate-completion-script bash > ~/.local/share/bash-completion/completions/tessera
```

The script names the executable as it was invoked, so a product that is not called `tessera` generates a script for its own name. The names come from the executable you built, so rebuild after registering an app.

## Run the app

`swift run tessera launch counter` opens the app in your terminal. It needs a real terminal on standard input and output. An agent without one runs it under a pty, after building so compiler output stays out of the capture:

```sh
swift build --product tessera
expect -c 'set timeout 20; spawn sh -c "stty rows 24 cols 80; exec swift run tessera launch counter"; expect "Count"; send "+"; send "q"; expect eof'
```

Read the screen from the bytes the run wrote: cursor addressing, then text. `tessera shot` and a scenario are the cheaper way to read a screen.

## The loop

When an app looks wrong, work down this list and stop at the first step that names the cause:

1. `tessera launch NAME` to see it, or `tessera shot NAME mobile` to read the screen without a terminal.
2. `tessera run Scenarios/NAME.scn` and read the report: each failure's `line`, `statement`, `message`, and `expected` against `actual`.
3. `tessera tree NAME mobile` for the nodes and their frames, and a `dump` statement for everything the projection holds.
4. `tessera run … --trace DIR` and read the trace: which step redrew, and the `reasons` the library gave.
5. `tessera check NAME` (or a `check` statement) for the broken invariant, with the rule and the node.
6. Fix the app and rerun, or, when the fault is Tessera's, report a Tessera bug. Never `--record` to make a failing run pass.

## Picture a state

`tessera shot counter mobile --pretty` prints the screen the way a golden holds it, and `tessera tree counter mobile --pretty` prints the nodes with their identities and frames. Both start a fresh app at that size and need no scenario, so they are the quickest way to see a failing state before writing the expectation that pins it. The JSON forms are `{"app", "command": "shot", "exitCode", "rows", "size"}` and `{"app", "command": "tree", "exitCode", "lines", "size"}`. An unknown app is a usage error that lists the registered names, and so is a size the app cannot take. The text `tree` prints is for reading; do not parse it.

## Write a scenario

A scenario is a text file, `Scenarios/NAME.scn`, that drives one app and says what the screen should show. One statement per line; blank lines are ignored; a `#` at the start of a word begins a comment. The header (`app`, `size`, `term`) comes first, then the body runs in order.

```text
# Scenarios/counter.scn
app counter
size desktop

expect text 0 "Count: 0"
type "++"
expect text 0 "Count: 2"
shot after-steps
key q
```

| Statement | Does |
| --- | --- |
| `app NAME` | Select the registered app. Required. |
| `size desktop\|mobile\|mobileScreen\|WxH` | The size the app starts at. `desktop` when omitted. |
| `term colors=none\|16\|256\|true theme=light\|dark` | The terminal the app runs on; both options optional. `theme` is what the harness reports when the app asks the terminal for its colours. |
| `resize WxH` | Resize the terminal. |
| `key NAME` | One key press: `key Tab`, `key Shift+Tab`, `key Ctrl+C`. |
| `type "text"` | One key press per character. |
| `paste "text"` | One paste event holding the whole text. |
| `bytes "\x1b[A"` | Raw terminal input, parsed as a terminal's input would be. |
| `expect text [ROW] "text"` | With a ROW (from 0), that row without its trailing spaces is exactly the text. Without one, some row contains it. |
| `expect screen <<WORD` | The screen is the lines that follow, up to a line holding only WORD. Trailing spaces and trailing empty rows are not compared. |
| `expect node SEL frame X,Y,WxH` | The one node `SEL` selects has this frame, in screen cells. |
| `expect cost NAME<=N...` | The last step took no more than each bound; see [Check an app](#check-an-app). |
| `check [RULE...]` | The named invariant rules hold, or every rule when none is named. |
| `shot NAME` | Compare the screen with the goldens `NAME.txt` and `NAME.grid.txt`. |
| `tree` | Add the node tree to the report's observations. |
| `dump` | Add the whole projection, as a JSON object, to the report's observations. |

Key names are case sensitive: `Enter`, `Escape`, `Tab`, `Space`, `Backspace`, `Delete`, `Home`, `End`, `PageUp`, `PageDown`, `ArrowUp`, `ArrowDown`, `ArrowLeft`, `ArrowRight`, `F1` to `F12`, or one character; modifiers `Ctrl`, `Alt`, `Meta`, `Shift`, and `Super` join with `+`. Inside `"…"`, `\n`, `\t`, `\"`, `\\`, and `\xHH` (00 to 7f) are escapes; `'…'` is literal. Lines between `expect screen <<WORD` and the closing line are not tokenized, so pick a WORD no row equals.

A selector `SEL` is `key=value` words that narrow the nodes: `type=Text` (the short type name), `layout=_FrameLayout` (the short name of the layout of a container, which `tree` prints in parentheses; `frame` and `padding` are layout containers), `id=a` (the id the app gave the node with `.id(X)` or a `ForEach` key, or else the full identity path `tree` prints, `id=root/index(2)/id(catalog)`), `text="Submit"` (the text the node itself shows on screen contains `Submit`; a container shows none, and text that a later layer paints over does not match), and `nth=2` (the zero-based pick among the matches). An empty value is a parse error. A selector that matches nothing, or several without `nth`, is a failure that names what is present.

Statements outside this table are parse errors (exit 2) that name what is accepted. Do not work around one with a different statement.

1. Picture the state with `tessera shot` or `tessera tree`.
2. Write the statements: input to drive, `expect` and `check` to assert, `shot` for a golden.
3. Run it with `tessera run Scenarios/counter.scn --pretty`. A failed `expect` or `shot` is recorded with the screen as it was, and the run continues, so one run reports every failure.
4. The first run of a new `shot` fails for lack of goldens. Run once with `--record`, open the two files it wrote (`shot after-steps` in `Scenarios/counter.scn` writes `Scenarios/counter/after-steps.txt` and `after-steps.grid.txt`), and confirm they show what you meant.

An app that finishes ends the scenario, as it ends a live run: `key q` is the last statement that runs against the counter, and the next statement fails with a message naming the line that finished the app. Assert what the app shows before the statement that quits it. Assert the numbers your design gives, not the numbers you saw. A shot name is letters, digits, `.`, `_`, and `-`, and differs from the others in its scenario by more than case.

## Goldens

A shot has two goldens. `NAME.txt` is the screen as text: every row without its trailing spaces, trailing empty rows dropped, one `\n` at the end, no colours or styles. `NAME.grid.txt` is the same screen with its styles: `── chars ──` (the rows), `── style ──` (one letter under each cell, `.` for the default style), and `── legend ──` (what each letter means, such as `A  fg=#ff0000 bold`). Goldens are the only artefacts a scenario commits, in a directory named like the scenario file, beside it. When a golden drifts, the app changed: decide whether the change is intended. If it is, rerun with `--record` and review the diff. **Never use `--record` to make a failing run pass**, and never edit a golden by hand to match a run. Goldens are compared byte for byte, so a repository checks them out with LF line endings: `*.scn text eol=lf` and `*.txt text eol=lf` for the golden directories in `.gitattributes`.

## Read a run

```sh
swift run tessera run Scenarios --pretty
swift run tessera run Scenarios/counter.scn
```

A directory runs every `.scn` under it in sorted order. With `--pretty`, or on a terminal, each scenario prints `PASS` or `FAIL` and each failure's line, statement, expected and actual values, and the screen. Without a terminal the output is one JSON object, `{"command": "run", "exitCode", "scenarios": [REPORT...]}`, and each report is `{"failures", "observations", "passed", "scenario"}`, plus `recorded` under `--record` and `seconds` under `--timing`. A failure is `{"line", "statement", "verb", "message"}` and, when the statement compares values, `expected`, `actual`, and `screen` (the whole screen at that moment); a failed `check` adds `rule` and `node`. Read a failure from its `line` and `statement`, its `message`, and `expected` against `actual`. Two runs give the same bytes; `--repeat N` runs each scenario N times and fails a run that differs from the first.

A failure's `verb` is the kind of failure. A statement's own verb (`expect text`, `expect screen`, `expect node`, `expect cost`, `check`, `shot`) means the app did not do what the scenario said; `size` means the app cannot take the size (use `mobileScreen` for an app that fills the screen); `parse` means the scenario file is wrong at that line, and the message names what is accepted; `repeat` means a run differed from the first; `replay` means a replayed step differed from the recording. A scenario that does not parse is not run, and the first error ends its parse. When several failures apply, the command exits with the highest code: 1 for an expectation, 2 for `parse` or `usage`, 3 for `harness`.

## Check an app

`check` runs invariant rules over the projection: the app's view graph as of the last completed step, joined to the screen that step drew. It never passes by checking nothing, because every `check` names the rules it ran. `check` alone runs all five, `check RULE...` the ones named, and `tessera check NAME [SIZE]` runs all five over an app at a size with no input.

| Rule | Severity | Catches |
| --- | --- | --- |
| `no-dirty-after-pass` | error | a node still marked for layout or rendering after the pass that drew the screen |
| `frame-inside-clip` | warning | a leaf whose frame reaches past its clip, so some of its content is not drawn (leaves under a `ScrollView` are skipped) |
| `measured-within-proposal` | error | a node that measured more than the size it was offered on a constrained axis |
| `siblings-disjoint` | error | two children of one container that show a cell in common, such as every `ForEach` item on one frame; a `ZStack` is exempt, and so are the layers a `ForEach`, an `if`, or a group of views builds under one |
| `requirements-aggregate` | error | a terminal requirement that a node asks for and the graph does not request, or one the graph requests that no node asks for |

An error fails the statement (exit 1) and names the rule and the node. A warning is listed and does not fail a bare `check`, because the content it flags can be clipped on purpose; naming a rule asks for it to hold, so `check frame-inside-clip` fails on a warning. A rule can fire by contract: a fixed `frame(width:)` wider than the width its parent offered and a `Flex` child wider than its segment both measure more than they were offered. A scenario that shows such a thing on purpose names the rules that must hold (`check no-dirty-after-pass siblings-disjoint requirements-aggregate`). A body of several views with no container around them is placed on one frame, so `siblings-disjoint` reports it, and that is a true positive: put the views in a stack. A failing rule is a finding about your app, or about Tessera when the node it names is a Tessera view: in that case report a Tessera bug.

`expect cost bodies<=5 bytes<=40` bounds the last step's work: `bodies` (view bodies evaluated), `bytes` (bytes written to the terminal; 0 when nothing was drawn), `measures`, `placements`, and `renders` (leaves painted). The step is the last event the scenario delivered, or the first frame before any. Only `<=` is accepted, written without spaces: the counts are the library's work, so bound them loosely and never assert an exact number. A failure prints every count, so the next bound can be written from what the step took. `dump` puts the projection in the step's observation: sorted-key JSON with a `version`, per node its `path`, `parent`, `children`, `type`, `layout`, `proposal`, `measured`, `frame`, `clip`, dirty flags, and, for a leaf, the `text` it shows.

## Read a trace

`tessera run Scenarios/counter.scn --trace /tmp/traces` writes `/tmp/traces/Scenarios/counter.trace.jsonl`, one JSON line per step; a live session writes the same with `TESSERA_TRACE=/tmp/live.jsonl swift run tessera launch NAME`. Read each line's `event` and `reasons` first: they say why the frame was drawn (`layoutViewportChanged` for a resize, `layoutViewChanged` for a changed view). Stacks hand each child a rebuilt environment on every update, so `layoutEnvironmentChanged` and `renderEnvironmentChanged` appear on every step of an app that has a stack; read the other reasons. Then `drew` (a step that leaves the graph clean draws nothing), `nodes` (identity paths added, changed, removed), `rows` (screen rows whose text changed), and `cost`. `tessera replay /tmp/live.jsonl --app NAME` runs a trace again headless and fails the first step whose reasons, nodes, rows, or cost differ; the bytes a frame wrote are not compared, because they depend on the terminal. Keys, pastes, resizes, and the terminal's focus changes replay; a trace that holds a mouse event or a terminal reply is refused by name (exit 2).

## Run scenarios from `swift test`

`ScenarioRunner` is what `tessera run` calls, so a test and the command line run the same scenarios the same way. The path is relative to the directory `swift test` runs in, the package root:

```swift
// Tests/MyAppTests/ScenarioTests.swift
import MyApp
import TesseraHarness
import Testing

@Test @MainActor
func `the scenarios pass`() async {
  let reports = await ScenarioRunner(registry: makeRegistry()).run("Scenarios")
  #expect(reports.filter { !$0.passed }.isEmpty, "\(reports)")
}
```

A `ScenarioReport` has `scenario`, `passed`, `failures`, `description` (the text form), and `json`.

## Rules

- When Tessera itself misbehaves (a crash, a wrong render, an input it drops), report a Tessera bug with the command, its output, and the smallest app or scenario that shows it. Do not work around it in the app or the scenario.
- A name registered twice fails every command that reads the registry. Never rely on the later registration winning.
- `--record` writes goldens from what the app does now; it is for a new `shot` and a reviewed, intended change, never for a failing run you do not understand.
- Never loosen a scenario until it passes.
- The node tree text, the projection, the trace, and the `expect cost` counts are for reading and change between releases; do not parse them.
