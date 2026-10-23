// swift-tools-version: 6.1
import PackageDescription

let package = Package(
  name: "unsafe-lib", products: [.library(name: "Lib", targets: ["Lib"])],
  targets: [.target(name: "Lib", linkerSettings: [.unsafeFlags(["-L/tmp/nonexistent"])])])
