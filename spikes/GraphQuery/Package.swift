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
    .package(name: "tessera", path: "../..")
  ],
  targets: [
    .target(
      name: "GraphQuery",
      dependencies: [
        .product(name: "Tessera", package: "tessera"),
        .product(name: "TesseraTerminalSnapshotSupport", package: "tessera"),
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
        .product(name: "Tessera", package: "tessera"),
        .product(name: "TesseraTerminalSnapshotSupport", package: "tessera"),
      ]
    ),
  ],
  swiftLanguageModes: [.v6]
)
