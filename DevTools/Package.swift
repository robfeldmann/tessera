// swift-tools-version: 6.3

import PackageDescription

let package = Package(
  name: "tessera-dev-tools",
  platforms: [
    .macOS(.v26)
  ],
  products: [
    .executable(name: "Linux VM Tests", targets: ["LinuxVMTests"])
  ],
  targets: [
    .executableTarget(name: "LinuxVMTests")
  ],
  swiftLanguageModes: [.v6]
)
