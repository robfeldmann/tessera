// swift-tools-version: 6.3
import PackageDescription

let package = Package(
  name: "consumer-direct",
  platforms: [.macOS(.v26)],
  dependencies: [
    .package(url: "file:///tmp/ghostty-dist-spike/tessera", exact: "0.1.2")
  ],
  targets: [
    .executableTarget(
      name: "App",
      dependencies: [
        .product(name: "CGhosttyVTDirect", package: "tessera")
      ]
    )
  ]
)
