// swift-tools-version: 6.3
import PackageDescription

let package = Package(
  name: "consumer-xcf",
  platforms: [.macOS(.v26)],
  dependencies: [
    .package(url: "file:///tmp/ghostty-dist-spike/ghostty-vt-xcf", from: "0.1.0")
  ],
  targets: [
    .executableTarget(
      name: "App", dependencies: [.product(name: "GhosttyVt", package: "ghostty-vt-xcf")])
  ]
)
