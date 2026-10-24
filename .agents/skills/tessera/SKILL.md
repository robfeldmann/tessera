---
name: tessera
description: Drive and check an app built on Tessera with the `tessera` command line. Use when writing a Tessera `Application`, registering it in an `ApplicationRegistry`, wiring the executable that calls `HarnessCLI.main(registry:)`, launching it, picturing its screen, writing or running a scenario with `tessera run`, or reading what the harness reports about it.
version: 0.2.0
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
| `tessera launch NAME` | Run one app in this terminal until the app quits. |
| `tessera run PATH...` | Run scenario files (`.scn`) or directories of them, with `--record`, `--repeat N`, and `--timing`. |
| `tessera shot NAME [SIZE]` | Print one app's screen as text. SIZE is `desktop` (the default), `mobile`, `mobileScreen`, or `WxH`. |
| `tessera tree NAME [SIZE]` | Print one app's node tree, one line per node: identity, type, frame, clip. |
| `tessera help [COMMAND]` | Print the commands, or one command's usage. |

Every command takes `--json` or `--pretty` to force the JSON object or the text form. Standard output is one JSON object when it is not a terminal, and text when it is. `apps` prints `{"apps": [{"minimum", "name", "viewports"}], "command": "apps"}`, sorted by name, where `minimum` is `null` for an app that declares none. A failed command prints `{"command", "exitCode", "message"}`.

Exit codes: 0 success, 1 an expectation failed, 2 a usage or parse error (an unknown command, app name, or flag, a bad path, a scenario that does not parse), 3 a harness error (a name registered twice, `launch` without a terminal, a golden that cannot be written).

## Run the app

`swift run tessera launch counter` opens the app in your terminal. It needs a real terminal on standard input and output. An agent without one runs it under a pty, after building so compiler output stays out of the capture:

```sh
swift build --product tessera
expect -c 'set timeout 20; spawn sh -c "stty rows 24 cols 80; exec swift run tessera launch counter"; expect "Count"; send "+"; send "q"; expect eof'
```

Read the screen from the bytes the run wrote: cursor addressing, then text. `tessera shot` and a scenario are the cheaper way to read a screen.

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
| `shot NAME` | Compare the screen with the golden `NAME.txt`. |
| `tree` | Add the node tree to the report's observations. |

Key names are case sensitive: `Enter`, `Escape`, `Tab`, `Space`, `Backspace`, `Delete`, `Home`, `End`, `PageUp`, `PageDown`, `ArrowUp`, `ArrowDown`, `ArrowLeft`, `ArrowRight`, `F1` to `F12`, or one character; modifiers `Ctrl`, `Alt`, `Meta`, `Shift`, and `Super` join with `+`. Inside `"…"`, `\n`, `\t`, `\"`, `\\`, and `\xHH` (00 to 7f) are escapes; `'…'` is literal. Lines between `expect screen <<WORD` and the closing line are not tokenized, so pick a WORD no row equals.

A selector `SEL` is `key=value` words that narrow the nodes: `type=Text` (the short type name), `id=root/index(2)/id(catalog)` (the identity path `tree` prints), `text="Submit"` (the node's frame holds this text), and `nth=2` (the zero-based pick among the matches). A selector that matches nothing, or several without `nth`, is a failure.

Statements outside this table are parse errors (exit 2) that name what is accepted. Do not work around one with a different statement.

1. Picture the state with `tessera shot` or `tessera tree`.
2. Write the statements: input to drive, `expect` to assert, `shot` for a golden.
3. Run it with `tessera run Scenarios/counter.scn --pretty`. A failed `expect` or `shot` is recorded with the screen as it was, and the run continues, so one run reports every failure.
4. The first run of a new `shot` fails for lack of a golden. Run once with `--record`, open the file it wrote (`shot after-steps` in `Scenarios/counter.scn` writes `Scenarios/counter/after-steps.txt`), and confirm it shows what you meant.

An app that finishes ends the scenario, as it ends a live run: `key q` is the last statement that runs against the counter, and the next statement fails with a message naming the line that finished the app. Assert what the app shows before the statement that quits it. A shot name is letters, digits, `.`, `_`, and `-`, and differs from the others in its scenario by more than case.

## Goldens

A golden is the screen as text: every row without its trailing spaces, trailing empty rows dropped, one `\n` at the end, no colours or styles. Goldens are the only artefacts a scenario commits, in a directory named like the scenario file, beside it. When a golden drifts, the app changed: decide whether the change is intended. If it is, rerun with `--record` and review the diff. **Never use `--record` to make a failing run pass**, and never edit a golden by hand to match a run. Goldens are compared byte for byte, so a repository checks them out with LF line endings: `*.scn text eol=lf` and `*.txt text eol=lf` for the golden directories in `.gitattributes`.

## Read a run

```sh
swift run tessera run Scenarios --pretty
swift run tessera run Scenarios/counter.scn
```

A directory runs every `.scn` under it in sorted order. With `--pretty`, or on a terminal, each scenario prints `PASS` or `FAIL` and each failure's line, statement, expected and actual values, and the screen. Without a terminal the output is one JSON object, `{"command": "run", "exitCode", "scenarios": [REPORT...]}`, and each report is `{"failures", "observations", "passed", "scenario"}`, plus `recorded` under `--record` and `seconds` under `--timing`. A failure is `{"line", "statement", "verb", "message"}` and, when the statement compares values, `expected`, `actual`, and `screen` (the whole screen at that moment). Read a failure from its `line` and `statement`, its `message`, and `expected` against `actual`. Two runs give the same bytes; `--repeat N` runs each scenario N times and fails a run that differs from the first.

A failure's `verb` is the kind of failure. A statement's own verb (`expect text`, `expect screen`, `expect node`, `shot`) means the app did not do what the scenario said; `size` means the app cannot take the size (use `mobileScreen` for an app that fills the screen); `parse` means the scenario file is wrong at that line, and the message names what is accepted; `repeat` means a run differed from the first. A scenario that does not parse is not run, and the first error ends its parse. When several failures apply, the command exits with the highest code: 1 for an expectation, 2 for `parse` or `usage`, 3 for `harness`.

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
