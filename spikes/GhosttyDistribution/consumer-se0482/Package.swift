// swift-tools-version: 6.3
import PackageDescription

let package = Package(
  name: "consumer-se0482",
  platforms: [.macOS(.v26)],
  dependencies: [
    .package(url: "file:///tmp/ghostty-dist-spike/tessera", from: "0.2.0")
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
