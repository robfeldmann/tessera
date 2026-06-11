// swift-tools-version: 6.3

// swift-format-ignore-file: AlwaysUseLowerCamelCase

import Foundation
import PackageDescription

// MARK: - 📦 Manifest

let package = Package(
  name: "tessera",
  platforms: [
    .macOS(.v26)
  ],
  products: [],  // see Products & Targets below
  dependencies: [],  // see Dependencies below
  targets: [],  // see Products & Targets below
  swiftLanguageModes: [.v6]
)

// MARK: - ⤵️ Dependencies

// MARK: Dependencies

package.dependencies.append(
  .package(
    url: "https://github.com/pointfreeco/swift-dependencies",
    from: "1.13.0"
  )
)

let Dependencies: Target.Dependency = .product(
  name: "Dependencies",
  package: "swift-dependencies"
)

let DependenciesTestSupport: Target.Dependency = .product(
  name: "DependenciesTestSupport",
  package: "swift-dependencies"
)

// MARK: IssueReporting

package.dependencies.append(
  .package(
    url: "https://github.com/pointfreeco/xctest-dynamic-overlay",
    from: "1.4.0"
  )
)

let IssueReporting: Target.Dependency = .product(
  name: "IssueReporting",
  package: "xctest-dynamic-overlay"
)

// MARK: DisplayWidth

package.dependencies.append(
  .package(
    url: "https://github.com/ainame/swift-displaywidth",
    from: "0.1.0"
  )
)

let DisplayWidth: Target.Dependency = .product(
  name: "DisplayWidth",
  package: "swift-displaywidth"
)

// MARK: CustomDump

package.dependencies.append(
  .package(
    url: "https://github.com/pointfreeco/swift-custom-dump",
    from: "1.0.0"
  )
)

let CustomDump: Target.Dependency = .product(
  name: "CustomDump",
  package: "swift-custom-dump"
)

// MARK: DocC

package.dependencies.append(
  .package(
    url: "https://github.com/apple/swift-docc-plugin",
    from: "1.0.0"
  )
)

// MARK: SnapshotTesting

package.dependencies.append(
  .package(
    url: "https://github.com/pointfreeco/swift-snapshot-testing",
    exact: "1.18.9"
  )
)

let InlineSnapshotTesting: Target.Dependency = .product(
  name: "InlineSnapshotTesting",
  package: "swift-snapshot-testing"
)

let SnapshotTesting: Target.Dependency = .product(
  name: "SnapshotTesting",
  package: "swift-snapshot-testing"
)

let SnapshotTestingCustomDump: Target.Dependency = .product(
  name: "SnapshotTestingCustomDump",
  package: "swift-snapshot-testing"
)

// MARK: SystemPackage

package.dependencies.append(
  .package(
    url: "https://github.com/apple/swift-system",
    from: "1.0.0"
  )
)

let SystemPackage: Target.Dependency = .product(
  name: "SystemPackage",
  package: "swift-system"
)

// MARK: - 🚛 Forward Module Declarations

let CGhosttyVT: Target.Dependency = .byName(name: "CGhosttyVT")
let CTesseraTerminalPlatform: Target.Dependency = .byName(
  name: "CTesseraTerminalPlatform"
)
let Tessera: Target.Dependency = .byName(name: "Tessera")
let TesseraCore: Target.Dependency = .byName(name: "TesseraCore")
let TesseraTerminal: Target.Dependency = .byName(name: "TesseraTerminal")
let TesseraTerminalANSI: Target.Dependency = .byName(name: "TesseraTerminalANSI")
let TesseraTerminalBuffer: Target.Dependency = .byName(name: "TesseraTerminalBuffer")
let TesseraTerminalCore: Target.Dependency = .byName(name: "TesseraTerminalCore")
let TesseraTerminalInput: Target.Dependency = .byName(name: "TesseraTerminalInput")
let TesseraTerminalIO: Target.Dependency = .byName(name: "TesseraTerminalIO")
let TesseraTerminalRendering: Target.Dependency = .byName(
  name: "TesseraTerminalRendering"
)
let TesseraTerminalSnapshotSupport: Target.Dependency = .byName(
  name: "TesseraTerminalSnapshotSupport"
)
let TesseraTerminalTestSupport: Target.Dependency = .byName(
  name: "TesseraTerminalTestSupport"
)

let AllTesseraTargetNames: Set<String> = [
  "Tessera",
  "TesseraCore",
  "TesseraTerminal",
  "TesseraTerminalANSI",
  "TesseraTerminalBuffer",
  "TesseraTerminalCore",
  "TesseraTerminalInput",
  "TesseraTerminalIO",
  "TesseraTerminalRendering",
  "TesseraTerminalSnapshotSupport",
  "TesseraTerminalTestSupport",
]

// MARK: - 🎯 Products & Targets

// MARK: CGhosttyVT

package.targets.append(
  .target(
    name: "CGhosttyVT",
    path: "Sources/CGhosttyVT",
    publicHeadersPath: "include"
  )
)

// MARK: CTesseraTerminalPlatform

package.targets.append(
  .target(
    name: "CTesseraTerminalPlatform",
    path: "Sources/CTesseraTerminalPlatform",
    publicHeadersPath: "include"
  )
)

// MARK: Tessera

package.products.append(.library(name: "Tessera", targets: ["Tessera"]))

package.targets.append(
  .target(
    name: "Tessera",
    dependencies: [
      TesseraCore,
      TesseraTerminal,
    ]
  )
)

// MARK: TesseraCore

package.targets.append(contentsOf: [
  .target(name: "TesseraCore"),
  .testTarget(
    name: "TesseraCoreTests",
    dependencies: [
      CustomDump,
      InlineSnapshotTesting,
      SnapshotTesting,
      SnapshotTestingCustomDump,
      TesseraCore,
    ]
  ),
])

// MARK: TesseraTerminal

package.products.append(.library(name: "TesseraTerminal", targets: ["TesseraTerminal"]))

package.targets.append(contentsOf: [
  .target(
    name: "TesseraTerminal",
    dependencies: [
      TesseraTerminalANSI,
      TesseraTerminalBuffer,
      TesseraTerminalCore,
      TesseraTerminalInput,
      TesseraTerminalIO,
      TesseraTerminalRendering,
    ]
  ),
  .testTarget(
    name: "TesseraTerminalTests",
    dependencies: [
      CustomDump,
      TesseraTerminal,
      TesseraTerminalIO,
      TesseraTerminalTestSupport,
    ]
  ),
])

// MARK: TesseraTerminalANSI

package.targets.append(contentsOf: [
  .target(
    name: "TesseraTerminalANSI",
    dependencies: [
      TesseraTerminalCore
    ]
  ),
  .testTarget(
    name: "TesseraTerminalANSITests",
    dependencies: [
      CustomDump,
      DependenciesTestSupport,
      InlineSnapshotTesting,
      SnapshotTesting,
      SnapshotTestingCustomDump,
      TesseraTerminalANSI,
      TesseraTerminalSnapshotSupport,
    ]
  ),
])

// MARK: TesseraTerminalBuffer

package.targets.append(contentsOf: [
  .target(
    name: "TesseraTerminalBuffer",
    dependencies: [
      DisplayWidth,
      TesseraTerminalANSI,
      TesseraTerminalCore,
    ]
  ),
  .testTarget(
    name: "TesseraTerminalBufferTests",
    dependencies: [
      CustomDump,
      InlineSnapshotTesting,
      SnapshotTesting,
      SnapshotTestingCustomDump,
      TesseraTerminalBuffer,
      TesseraTerminalTestSupport,
    ]
  ),
])

// MARK: TesseraTerminalCore

package.targets.append(contentsOf: [
  .target(
    name: "TesseraTerminalCore"
  ),
  .testTarget(
    name: "TesseraTerminalCoreTests",
    dependencies: [
      CustomDump,
      InlineSnapshotTesting,
      SnapshotTesting,
      SnapshotTestingCustomDump,
      TesseraTerminalCore,
    ]
  ),
])

// MARK: TesseraTerminalInput

package.targets.append(contentsOf: [
  .target(
    name: "TesseraTerminalInput",
    dependencies: [
      TesseraTerminalCore
    ]
  ),
  .testTarget(
    name: "TesseraTerminalInputTests",
    dependencies: [
      CustomDump,
      InlineSnapshotTesting,
      SnapshotTesting,
      SnapshotTestingCustomDump,
      TesseraTerminalInput,
    ]
  ),
])

// MARK: TesseraTerminalIO

package.targets.append(contentsOf: [
  .target(
    name: "TesseraTerminalIO",
    dependencies: [
      CTesseraTerminalPlatform,
      SystemPackage,
      TesseraTerminalANSI,
      TesseraTerminalCore,
      TesseraTerminalInput,
    ]
  ),
  .testTarget(
    name: "TesseraTerminalIOTests",
    dependencies: [
      CustomDump,
      InlineSnapshotTesting,
      SnapshotTesting,
      SnapshotTestingCustomDump,
      SystemPackage,
      TesseraTerminalIO,
      TesseraTerminalSnapshotSupport,
      TesseraTerminalTestSupport,
    ]
  ),
])

// MARK: TesseraTerminalRendering

package.targets.append(contentsOf: [
  .target(
    name: "TesseraTerminalRendering",
    dependencies: [
      TesseraTerminalANSI,
      TesseraTerminalBuffer,
      TesseraTerminalCore,
    ]
  ),
  .testTarget(
    name: "TesseraTerminalRenderingTests",
    dependencies: [
      CustomDump,
      InlineSnapshotTesting,
      SnapshotTesting,
      SnapshotTestingCustomDump,
      TesseraTerminalRendering,
      TesseraTerminalSnapshotSupport,
      TesseraTerminalTestSupport,
    ]
  ),
])

// MARK: TesseraTerminalSnapshotSupport

package.targets.append(contentsOf: [
  .target(
    name: "TesseraTerminalSnapshotSupport",
    dependencies: [
      CGhosttyVT,
      Dependencies,
      IssueReporting,
      TesseraTerminalANSI,
      TesseraTerminalBuffer,
      TesseraTerminalCore,
      TesseraTerminalRendering,
    ]
  ),
  .testTarget(
    name: "TesseraTerminalSnapshotSupportTests",
    dependencies: [
      Dependencies,
      DependenciesTestSupport,
      TesseraTerminalCore,
      TesseraTerminalSnapshotSupport,
    ]
  ),
])

// MARK: TesseraTerminalTestSupport

package.targets.append(
  .target(
    name: "TesseraTerminalTestSupport",
    dependencies: [
      CustomDump,
      SnapshotTesting,
      TesseraTerminalBuffer,
      TesseraTerminalInput,
      TesseraTerminalIO,
      TesseraTerminalSnapshotSupport,
    ]
  )
)

// MARK: - 👻 Ghostty VT Build Output

let PackageDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent().path
let GhosttyVTRevisionFile = "\(PackageDirectory)/scripts/ghostty-vt-version.txt"
let GhosttyVTRevision =
  (try? String(contentsOfFile: GhosttyVTRevisionFile, encoding: .utf8))?
  .trimmingCharacters(in: .whitespacesAndNewlines) ?? "unknown"
#if os(macOS)
  let GhosttyVTPlatform = "macos"
#elseif os(Linux)
  let GhosttyVTPlatform = "linux"
#else
  let GhosttyVTPlatform = "unsupported"
#endif
#if arch(arm64)
  let GhosttyVTArch = "arm64"
#elseif arch(x86_64)
  let GhosttyVTArch = "x86_64"
#else
  let GhosttyVTArch = "unsupported"
#endif
let GhosttyVTInstallPath =
  "\(PackageDirectory)/.build/libghostty-vt/\(GhosttyVTRevision)/\(GhosttyVTPlatform)-\(GhosttyVTArch)"
let GhosttyVTIncludePath = "\(GhosttyVTInstallPath)/include"
let GhosttyVTLibraryPath = "\(GhosttyVTInstallPath)/lib"
let GhosttyVTUnsafeLinkerFlags = [
  "-L\(GhosttyVTLibraryPath)",
  "-lghostty-vt",
  "-Xlinker",
  "-rpath",
  "-Xlinker",
  GhosttyVTLibraryPath,
]
if let GhosttyVTTarget = package.targets.first(where: { $0.name == "CGhosttyVT" }) {
  GhosttyVTTarget.linkerSettings = [
    .unsafeFlags(GhosttyVTUnsafeLinkerFlags)
  ]
}

// MARK: - ⚙️ Shared Swift Settings

for target in package.targets {
  guard AllTesseraTargetNames.contains(target.name) else {
    continue
  }
  var settings = target.swiftSettings ?? []
  settings.append(contentsOf: [
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("ForwardFromBuilder"),
    .enableUpcomingFeature("InferIsolatedConformances"),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
  ])
  target.swiftSettings = settings
}
