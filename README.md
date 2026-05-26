# Tessera

A Swift TUI library for macOS, Linux, and Windows that provides a view/rendering layer
designed to render apps the same way SwiftUI, UIKit, or AppKit do for graphical apps.

## Features

- **Tessera**: Core library.
- **TesseraTerminal**: Terminal-specific utilities and helpers.

## Requirements

- macOS 26.0+
- Swift 6.3+
- [Prettier](https://prettier.io/) (for Markdown formatting)
- [SwiftLint](https://github.com/realm/SwiftLint) (for Swift linting)
- [swift-format](https://github.com/apple/swift-format) (for Swift formatting)

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

## Documentation

Full documentation will be available soon.

## Contributing

Please see [CONTRIBUTING.md](CONTRIBUTING.md) for details on how to contribute to this
project.

## Code of Conduct

Please see [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) for details on our code of conduct.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for
details.
