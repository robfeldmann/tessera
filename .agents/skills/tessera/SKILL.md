---
name: tessera
description: Drive and check an app built on Tessera with the `tessera` command line. Use when writing a Tessera `Application`, registering it in an `ApplicationRegistry`, wiring the executable that calls `HarnessCLI.main(registry:)`, listing or launching the app with `tessera apps` and `tessera launch`, or reading what the harness reports about it.
version: 0.1.0
---

# Tessera for app authors

`TesseraHarness` runs a Tessera app live in a terminal and headlessly through one driver, so what a check renders is what a terminal shows. The `tessera` command line is how you and an agent reach it: you register your apps, wire one executable, and run commands against it. Use only the commands listed here.

## Wire the executable

1. Conform your app to `Application` where the type is declared: a `final class` with a `body`, an `apply(_:)` that receives each input event the views left unhandled (and every resize), and an `isFinished` that tells the harness to stop. The harness has no quit key of its own; the app decides which key quits.
2. Register it in an `ApplicationRegistry` under a kebab-case name, with its minimum size and the viewports it is checked at. A viewport is `.desktop` (80x24), `.mobile` (40 columns at the height the app's content needs), `.mobileScreen` (40x16), or `.custom(TerminalSize)`. There is no default viewport list. An app whose content grows to any height it is offered has no natural height, so `.mobile` fails and names `.mobileScreen`.
3. Make an executable whose body is `HarnessCLI.main(registry:)`, and name its product `tessera` so every command below runs as `swift run tessera COMMAND`.

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
    .target(name: "MyApp", dependencies: [.product(name: "Tessera", package: "tessera")]),
    .executableTarget(
      name: "MyAppDev",
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
// Sources/MyAppDev/main.swift
import MyApp
import Tessera
import TesseraHarness

var registry = ApplicationRegistry()
registry.register(
  "counter",
  minimum: TerminalSize(columns: 20, rows: 3),
  viewports: [.desktop, .mobile]
) { Counter() }
await HarnessCLI.main(registry: registry)
```

The factory closure runs on the main actor once per run, so every run starts from a fresh app. A further registration of the same app in another starting state is one more `register` call under another name.

## Commands

| tessera | Does |
| --- | --- |
| `tessera apps` | List the registered apps: name, minimum size, viewports. |
| `tessera apps --json` or `--pretty` | Force the JSON object or the text table. |
| `tessera launch NAME` | Run one app in this terminal until the app quits. |
| `tessera help [COMMAND]` | Print the commands, or one command's usage. |

Standard output is one JSON object when it is not a terminal, and a text table when it is. `apps` prints `{"apps": [{"minimum", "name", "viewports"}], "command": "apps"}`, sorted by name, where `minimum` is `null` for an app that declares none. A failed command prints `{"command", "exitCode", "message"}` instead.

Exit codes: 0 success, 2 a usage error (an unknown command or app name, with the accepted names listed), 3 a harness error (a name registered twice, or `launch` without a terminal).

## Run the app

`swift run tessera launch counter` opens the app in your terminal. It needs a real terminal on standard input and output. An agent without one runs it under a pty, after building so compiler output stays out of the capture:

```sh
swift build --product tessera
expect -c 'set timeout 20; spawn sh -c "stty rows 24 cols 80; exec swift run tessera launch counter"; expect "Count"; send "+"; send "q"; expect eof'
```

Read the screen from the bytes the run wrote: cursor addressing, then text.

## Rules

- When Tessera itself misbehaves (a crash, a wrong render, an input it drops), report a Tessera bug with the command, its output, and the smallest app that shows it. Do not work around it in the app.
- A name registered twice fails every command that reads the registry. Never rely on the later registration winning.
