// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "ghostty-vt-binary",
  products: [.library(name: "GhosttyVTLibrary", targets: ["GhosttyVTLibrary"])],
  targets: [
    .binaryTarget(name: "GhosttyVTLibrary", path: "GhosttyVTLibrary.artifactbundle")
  ]
)
