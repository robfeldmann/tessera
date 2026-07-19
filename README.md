# Tessera

A Swift TUI library for macOS, Linux, and Windows that provides a view/rendering layer
designed to render apps the same way SwiftUI, UIKit, or AppKit do for graphical apps.

## Features

- **Tessera**: Core library.
- **TesseraTerminal**: Terminal-specific utilities and helpers.

## Requirements

- macOS 26.0+
- Swift 6.3+

For contributor tooling, setup, and validation commands, see
[CONTRIBUTING.md](CONTRIBUTING.md).

## Installation

### Swift Package Manager

Add the following to your `Package.swift`:

```swift
dependencies: [
    // During development, use branch reference:
    .package(url: "https://github.com/robfeldmann/tessera.git", branch: "main")

    // Or specify a release, switch to:
    .package(url: "https://github.com/robfeldmann/tessera.git", from: "0.1.0")
]
```

Then add the desired products to your target dependencies:

```swift
.target(
    name: "YourTarget",
    dependencies: [
        .product(name: "Tessera", package: "tessera"),
    ]
)
```

## Usage

### Tessera

```swift
import Tessera

// Your code here
```

### TesseraTerminal

```swift
import TesseraTerminal

// Your code here
```

## Terminal recovery

Tessera applications install in-process cleanup handlers for normal exits, thrown errors,
and supported termination signals. If a development build ever leaves your terminal in a
bad state, type the recovery command for your platform even if input is not visible, then
press Enter.

On macOS and Linux:

```sh
reset
```

If `reset` does not restore normal input echo, try:

```sh
stty sane
```

On Windows PowerShell, emit terminal reset and visibility sequences directly because
Windows has no native `reset` or `stty sane` command:

```powershell
[Console]::Write([char]27 + '[?1049l' + [char]27 + '[?25h' + [char]27 + 'c')
```

## Documentation

- [Local development state](docs/LocalDevelopmentState.md): explains Ghostty VT, Linux,
  and Windows VM artifacts for branch/worktree use.
- [Updating Ghostty VT](docs/UpdatingGhosttyVT.md): update the pinned terminal parser
  revision.
- [Windows VM with Frost](docs/WindowsFrostVM.md): recommended repeatable Windows test
  workflow.
- [Manual Windows VM with UTM](docs/WindowsVM.md): hand-managed Windows desktop workflow.

## Contributing

Please see [CONTRIBUTING.md](CONTRIBUTING.md) for details on how to contribute to this
project.

## Code of Conduct

Please see [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) for details on our code of conduct.

## License

Tessera is licensed under the [Apache License 2.0](LICENSE). See
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for third-party component notices.
