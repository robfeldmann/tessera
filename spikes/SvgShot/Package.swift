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
    .package(path: "../..")
  ],
  targets: [
    .target(
      name: "SVGShot",
      dependencies: [
        .product(name: "TesseraTerminal", package: "devtools"),
        .product(name: "TesseraTerminalSnapshotSupport", package: "devtools"),
      ],
      swiftSettings: upcomingFeatures
    ),
    .executableTarget(
      name: "SVGShotCLI",
      dependencies: [
        "SVGShot",
        .product(name: "TesseraTerminalSnapshotSupport", package: "devtools"),
      ],
      swiftSettings: upcomingFeatures
    ),
    .testTarget(
      name: "SVGShotTests",
      dependencies: [
        "SVGShot",
        .product(name: "TesseraTerminal", package: "devtools"),
        .product(name: "TesseraTerminalSnapshotSupport", package: "devtools"),
      ],
      swiftSettings: upcomingFeatures
    ),
  ],
  swiftLanguageModes: [.v6]
)
