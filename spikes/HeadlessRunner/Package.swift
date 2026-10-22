// swift-tools-version: 6.3

import PackageDescription

let package = Package(
  name: "HeadlessRunner",
  platforms: [
    .macOS(.v26)
  ],
  products: [
    .executable(name: "headless", targets: ["headless"])
  ],
  dependencies: [
    .package(name: "tessera", path: "../..")
  ],
  targets: [
    .target(
      name: "HeadlessKit",
      dependencies: [
        .product(name: "Tessera", package: "tessera"),
        .product(name: "TesseraTerminalSnapshotSupport", package: "tessera"),
      ]
    ),
    .executableTarget(
      name: "headless",
      dependencies: ["HeadlessKit"]
    ),
    .testTarget(
      name: "HeadlessKitTests",
      dependencies: [
        "HeadlessKit",
        .product(name: "Tessera", package: "tessera"),
      ]
    ),
  ],
  swiftLanguageModes: [.v6]
)
