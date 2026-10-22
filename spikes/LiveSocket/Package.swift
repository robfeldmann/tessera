// swift-tools-version: 6.3

import PackageDescription

let package = Package(
  name: "LiveSocket",
  platforms: [
    .macOS(.v26)
  ],
  products: [
    .executable(name: "livesocket", targets: ["livesocket"])
  ],
  dependencies: [
    // `name:` fixes the path dependency's identity, which would otherwise be the checkout's
    // directory name (`main`, `devtools`, …).
    .package(name: "tessera", path: "../..")
  ],
  targets: [
    .target(
      name: "LiveSocketKit",
      dependencies: [
        .product(name: "Tessera", package: "tessera"),
        .product(name: "TesseraTerminalSnapshotSupport", package: "tessera"),
      ]
    ),
    .executableTarget(
      name: "livesocket",
      dependencies: ["LiveSocketKit"]
    ),
    .testTarget(
      name: "LiveSocketKitTests",
      dependencies: [
        "LiveSocketKit",
        .product(name: "TesseraTerminalTestSupport", package: "tessera"),
      ]
    ),
  ],
  swiftLanguageModes: [.v6]
)
