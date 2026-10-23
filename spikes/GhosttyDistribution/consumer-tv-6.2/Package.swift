// swift-tools-version: 6.3
import PackageDescription

let package = Package(
  name: "c",
  dependencies: [
    .package(url: "file:///tmp/ghostty-dist-spike/unsafe-lib-6.2", from: "1.0.0")
  ],
  targets: [
    .executableTarget(
      name: "App", dependencies: [.product(name: "Lib", package: "unsafe-lib-6.2")])
  ])
