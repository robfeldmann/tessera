// swift-tools-version: 6.3

import PackageDescription

let package = Package(
  name: "tessera",
  platforms: [
    .macOS(.v26)
  ],
  products: [
    .library(
      name: "Tessera",
      targets: ["Tessera"]
    ),
    .library(
      name: "TesseraTerminal",
      targets: ["TesseraTerminal"]
    ),
  ],
  dependencies: [
    .package(url: "https://github.com/ainame/swift-displaywidth", from: "0.1.0"),
    .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0"),
    .package(url: "https://github.com/apple/swift-system", from: "1.0.0"),
  ],
  targets: [
    .target(
      name: "Tessera",
      dependencies: [
        .byName(name: "TesseraTerminal")
      ],
    ),
    .testTarget(
      name: "TesseraTests",
      dependencies: ["Tessera"],
    ),
    .target(
      name: "TesseraTerminal",
      dependencies: [
        .product(name: "SystemPackage", package: "swift-system"),
        .product(name: "DisplayWidth", package: "swift-displaywidth"),
      ],
    ),
    .testTarget(
      name: "TesseraTerminalTests",
      dependencies: ["TesseraTerminal"],
    ),
  ],
  swiftLanguageModes: [.v6]
)

for target in package.targets {
  target.swiftSettings = target.swiftSettings ?? []
  target.swiftSettings?.append(contentsOf: [
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("ForwardFromBuilder"),
    .enableUpcomingFeature("InferIsolatedConformances"),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
  ])
}
