// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "url-bin",
  products: [.library(name: "GhosttyVTLibrary", targets: ["GhosttyVTLibrary"])],
  targets: [
    .binaryTarget(
      name: "GhosttyVTLibrary",
      url: "file:///tmp/ghostty-dist-spike/GhosttyVTLibrary.artifactbundle.zip",
      checksum: "a4d5439d1a8c499c980144ee1b4205e493597a01e63e21f8fcee0f99ce94b252")
  ])
