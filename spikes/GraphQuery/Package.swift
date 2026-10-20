// swift-tools-version: 6.3

import PackageDescription

// The executable target is `GraphQueryCLI` because `Sources/graphquery` and
// `Sources/GraphQuery` collide on a case-insensitive filesystem.
let package = Package(
  name: "GraphQuery",
  platforms: [
    .macOS(.v26)
  ],
  products: [
    .executable(name: "graphquery", targets: ["GraphQueryCLI"])
  ],
  dependencies: [
    .package(path: "../..")
  ],
  targets: [
    .target(
      name: "GraphQuery",
      dependencies: [
        .product(name: "Tessera", package: "devtools"),
        .product(name: "TesseraTerminalSnapshotSupport", package: "devtools"),
      ]
    ),
    .executableTarget(
      name: "GraphQueryCLI",
      dependencies: ["GraphQuery"]
    ),
    .testTarget(
      name: "GraphQueryTests",
      dependencies: [
        "GraphQuery",
        .product(name: "Tessera", package: "devtools"),
        .product(name: "TesseraTerminalSnapshotSupport", package: "devtools"),
      ]
    ),
  ],
  swiftLanguageModes: [.v6]
)
