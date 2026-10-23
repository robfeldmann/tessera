// swift-tools-version: 6.3
import PackageDescription

let package = Package(
  name: "consumer-url",
  dependencies: [.package(url: "file:///tmp/ghostty-dist-spike/url-bin", from: "1.0.0")],
  targets: [
    .executableTarget(
      name: "App", dependencies: [.product(name: "GhosttyVTLibrary", package: "url-bin")])
  ])
