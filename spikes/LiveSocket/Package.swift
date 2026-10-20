// swift-tools-version: 6.3

import Foundation
import PackageDescription

// A path dependency's identity is its directory name, not the manifest's `name`, so the
// product reference must follow the checkout's folder (`devtools` here, `main` elsewhere).
let tesseraIdentity = URL(fileURLWithPath: #filePath)
  .deletingLastPathComponent()
  .deletingLastPathComponent()
  .deletingLastPathComponent()
  .lastPathComponent

let package = Package(
  name: "LiveSocket",
  platforms: [
    .macOS(.v26)
  ],
  products: [
    .executable(name: "livesocket", targets: ["livesocket"])
  ],
  dependencies: [
    .package(path: "../..")
  ],
  targets: [
    .target(
      name: "LiveSocketKit",
      dependencies: [
        .product(name: "Tessera", package: tesseraIdentity),
        .product(name: "TesseraTerminalSnapshotSupport", package: tesseraIdentity),
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
        .product(name: "TesseraTerminalTestSupport", package: tesseraIdentity),
      ]
    ),
  ],
  swiftLanguageModes: [.v6]
)
