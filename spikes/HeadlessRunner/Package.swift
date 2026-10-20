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
    .package(path: "../..")
  ],
  targets: [
    .target(
      name: "HeadlessKit",
      dependencies: [
        .product(name: "Tessera", package: "devtools"),
        .product(name: "TesseraTerminalSnapshotSupport", package: "devtools"),
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
        .product(name: "Tessera", package: "devtools"),
      ]
    ),
  ],
  swiftLanguageModes: [.v6]
)
