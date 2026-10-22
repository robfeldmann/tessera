// swift-tools-version: 6.3

import PackageDescription

let upcomingFeatures: [SwiftSetting] = [
  .enableUpcomingFeature("ExistentialAny"),
  .enableUpcomingFeature("ForwardFromBuilder"),
  .enableUpcomingFeature("InferIsolatedConformances"),
  .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
]

let package = Package(
  name: "SvgShot",
  platforms: [
    .macOS(.v26)
  ],
  products: [
    .executable(name: "svgshot", targets: ["SVGShotCLI"]),
    .library(name: "SVGShot", targets: ["SVGShot"]),
  ],
  dependencies: [
    .package(name: "tessera", path: "../..")
  ],
  targets: [
    .target(
      name: "SVGShot",
      dependencies: [
        .product(name: "TesseraTerminal", package: "tessera"),
        .product(name: "TesseraTerminalSnapshotSupport", package: "tessera"),
      ],
      swiftSettings: upcomingFeatures
    ),
    .executableTarget(
      name: "SVGShotCLI",
      dependencies: [
        "SVGShot",
        .product(name: "TesseraTerminalSnapshotSupport", package: "tessera"),
      ],
      swiftSettings: upcomingFeatures
    ),
    .testTarget(
      name: "SVGShotTests",
      dependencies: [
        "SVGShot",
        .product(name: "TesseraTerminal", package: "tessera"),
        .product(name: "TesseraTerminalSnapshotSupport", package: "tessera"),
      ],
      swiftSettings: upcomingFeatures
    ),
  ],
  swiftLanguageModes: [.v6]
)
