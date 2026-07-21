import Foundation
import Testing

private struct ImportBoundary {
  let name: String
  let sourcePath: String
  let forbiddenModules: Set<String>
}

@Test
func `view layer sources do not import forbidden modules`() throws {
  let forbiddenModules: Set<String> = [
    "AppKit",
    "CTesseraTerminalPlatform",
    "SwiftUI",
    "TesseraTerminalIO",
    "UIKit",
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
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()

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
    "View-layer import boundaries were violated:\n\(offenders.sorted().joined(separator: "\n"))"
  )
}

private func importedModule(from rawLine: Substring) -> String? {
  var line = rawLine.trimmingCharacters(in: .whitespaces)
  guard !line.hasPrefix("//") else {
    return nil
  }

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

  guard tokens.first == "import" else {
    return nil
  }
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
