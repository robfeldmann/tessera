// swift-tools-version: 6.3
import PackageDescription

// Upstream's tip ghostty-vt.xcframework, unmodified, as a path binary target.
let package = Package(
  name: "ghostty-vt-xcf",
  products: [.library(name: "GhosttyVt", targets: ["GhosttyVt"])],
  targets: [.binaryTarget(name: "GhosttyVt", path: "ghostty-vt.xcframework")]
)
