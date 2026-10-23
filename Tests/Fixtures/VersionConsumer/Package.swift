// swift-tools-version: 6.3

// The version-consumer CI job clones the Tessera checkout to a temporary directory named
// `tessera`, tags the clone 0.0.0-ci, and points TESSERA_VERSION_CONSUMER_URL at it, so
// this package depends on Tessera by version, as an app would, and links libghostty-vt
// from the published artifact bundle.

import Foundation
import PackageDescription

let tesseraURL =
  ProcessInfo.processInfo.environment["TESSERA_VERSION_CONSUMER_URL"]
  ?? "file:///tmp/version-consumer/tessera"

let package = Package(
  name: "VersionConsumer",
  platforms: [
    .macOS(.v26)
  ],
  dependencies: [
    .package(url: tesseraURL, from: "0.0.0-ci")
  ],
  targets: [
    .executableTarget(
      name: "VersionConsumer",
      dependencies: [
        .product(name: "TesseraTerminalSnapshotSupport", package: "tessera")
      ]
    ),
    .testTarget(
      name: "VersionConsumerTests",
      dependencies: [
        .product(name: "TesseraTerminalSnapshotSupport", package: "tessera")
      ]
    ),
  ],
  swiftLanguageModes: [.v6]
)
