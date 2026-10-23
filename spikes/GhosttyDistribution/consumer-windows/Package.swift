// swift-tools-version: 6.3
import PackageDescription

let package = Package(
  name: "consumer-windows",
  platforms: [.macOS(.v26)],
  dependencies: [
    .package(url: "file:///C:/tmp/ghostty-dist-spike/tessera", from: "0.3.1")
  ],
  targets: [
    .executableTarget(
      name: "App",
      dependencies: [
        .product(name: "TesseraTerminalSnapshotSupport", package: "tessera")
      ]
    ),
    .testTarget(
      name: "AppTests",
      dependencies: [
        .product(name: "TesseraTerminalSnapshotSupport", package: "tessera")
      ]
    ),
  ]
)
