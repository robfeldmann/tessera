// swift-tools-version: 6.3
import PackageDescription

let package = Package(
  name: "consumer-unsafe",
  platforms: [.macOS(.v26)],
  dependencies: [
    .package(url: "file:///tmp/ghostty-dist-spike/tessera", from: "0.1.0")
  ],
  targets: [
    .executableTarget(
      name: "App",
      dependencies: [
        .product(name: "TesseraTerminalSnapshotSupport", package: "tessera")
      ]
    )
  ]
)
