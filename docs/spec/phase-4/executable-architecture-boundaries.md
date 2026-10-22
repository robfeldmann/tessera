---
type: spec
description: "Executable architecture boundaries"
---

# Executable architecture boundaries

The import boundary is an executable requirement, not a comment.

1. **Source import boundary test.** A Swift Testing architecture test scans every declared
   view-layer source root: `Sources/TesseraCore`, `Sources/TesseraLayout`,
   `Sources/TesseraWidgets`, and `Sources/Tessera`. It rejects imports of
   `TesseraTerminalIO`, `CTesseraTerminalPlatform`, `SwiftUI`, `AppKit`, and `UIKit`,
   reports every offending file and line, imports only `Foundation` and `Testing`, and
   lives with the unit tests so `swift test --filter ImportBoundary` can run it directly.
2. **Package graph boundary check.** The separately unit-tested Python script
   `scripts/check-package-boundaries.py` receives `swift package describe --type json` on
   standard input and rejects view-layer direct dependency edges outside the frozen graph.
   `just quality lint` runs it; `swift test` does not invoke SwiftPM recursively. The
   source test catches actual leaks, while the graph check catches a manifest being
   broadened before the leak is used.

Both checks enforce the same ownership rule: views declare terminal requirements, but only
the session owns terminal capabilities.

The source test shape should stay close to this, with helper details kept small enough to
audit in one screen:

```swift
import Foundation
import Testing

private struct ImportBoundary {
    var name: String
    var sourcePath: String
    var forbiddenModules: Set<String>
}

@Test
func `view layer sources do not import forbidden modules`() throws {
    let forbiddenModules: Set<String> = [
        "AppKit", "CTesseraTerminalPlatform", "SwiftUI", "TesseraTerminalIO", "UIKit",
    ]
    let boundaries = [
        ImportBoundary(
            name: "TesseraCore",
            sourcePath: "Sources/TesseraCore",
            forbiddenModules: forbiddenModules
        ),
        ImportBoundary(
            name: "TesseraLayout",
            sourcePath: "Sources/TesseraLayout",
            forbiddenModules: forbiddenModules
        ),
        ImportBoundary(
            name: "TesseraWidgets",
            sourcePath: "Sources/TesseraWidgets",
            forbiddenModules: forbiddenModules
        ),
        ImportBoundary(
            name: "Tessera",
            sourcePath: "Sources/Tessera",
            forbiddenModules: forbiddenModules
        ),
    ]

    let packageRoot = URL(filePath: #filePath)
        .deletingLastPathComponent()  // TesseraArchitectureTests
        .deletingLastPathComponent()  // Tests
        .deletingLastPathComponent()  // package root

    var offenders: [String] = []

    for boundary in boundaries {
        let sourceRoot = packageRoot.appending(path: boundary.sourcePath)
        let enumerator = try #require(
            FileManager.default.enumerator(
                at: sourceRoot,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            ),
            "Expected source root to exist for \(boundary.name): \(sourceRoot.path)"
        )

        for case let fileURL as URL in enumerator where fileURL.pathExtension == "swift" {
            let source = try String(contentsOf: fileURL, encoding: .utf8)

            for (lineIndex, line) in source.split(
                separator: "\n",
                omittingEmptySubsequences: false
            ).enumerated() {
                guard let module = importedModule(from: line),
                    boundary.forbiddenModules.contains(module)
                else { continue }

                offenders.append("\(fileURL.path):\(lineIndex + 1): \(module)")
            }
        }
    }

    #expect(
        offenders.isEmpty,
        "View-layer import boundaries were violated:\n\(offenders.joined(separator: "\n"))"
    )
}

private func importedModule(from rawLine: Substring) -> String? {
    var line = rawLine.trimmingCharacters(in: .whitespaces)
    guard !line.hasPrefix("//") else { return nil }

    if let commentStart = line.range(of: "//") {
        line = String(line[..<commentStart.lowerBound])
            .trimmingCharacters(in: .whitespaces)
    }

    var tokens = line.split { $0 == " " || $0 == "\t" }.map(String.init)

    while let first = tokens.first,
        first.hasPrefix("@") || importAccessModifiers.contains(first)
    {
        tokens.removeFirst()
    }

    guard tokens.first == "import" else { return nil }
    tokens.removeFirst()

    if let first = tokens.first, importKinds.contains(first) {
        tokens.removeFirst()
    }

    return tokens.first?.split(separator: ".").first.map(String.init)
}

private let importAccessModifiers: Set<String> = [
    "fileprivate", "internal", "package", "private", "public",
]

private let importKinds: Set<String> = [
    "class", "enum", "func", "let", "protocol", "struct", "typealias", "var",
]
```

The package graph checker is the separately unit-tested Python script
`scripts/check-package-boundaries.py`. It reads the `swift package describe --type json`
document from standard input, validates the declared view targets, and permits only these
direct edges:

```text
TesseraCore    -> TesseraTerminalCore, TesseraTerminalBuffer, TesseraTerminalInput
TesseraLayout  -> TesseraCore
TesseraWidgets -> TesseraCore, TesseraLayout
Tessera        -> TesseraCore, TesseraLayout, TesseraWidgets, TesseraTerminal
```

It fails for every other direct dependency from those targets, including terminal IO,
platform shims, rendering/ANSI implementation targets, or reverse view-layer edges. Its
unit tests use JSON fixtures and call the checker directly; they never invoke SwiftPM.

`just quality lint` runs the unit tests and then the live manifest check:

```just
architecture:
    python3 -m unittest scripts/test_check_package_boundaries.py
    swift package describe --type json | python3 scripts/check-package-boundaries.py
```
