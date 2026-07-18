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

#if !os(Windows)
  package.dependencies.append(
    .package(
      url: "https://github.com/apple/swift-docc-plugin",
      from: "1.0.0"
    )
  )
#endif

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

// MARK: - 👻 Ghostty VT Gate

// Ghostty-backed snapshot support is always available on macOS/Linux. On Windows it is
// opt-in until the hosted CI path is approved: set TESSERA_GHOSTTY_WINDOWS=1 (and build
// the artifact with scripts/build-libghostty-vt.ps1) to compile CGhosttyVT in. Sources
// gate on `#if canImport(CGhosttyVT)`, so both configurations build from one tree.
#if os(Windows)
  let GhosttyVTEnabled =
    ProcessInfo.processInfo.environment["TESSERA_GHOSTTY_WINDOWS"] == "1"
#else
  let GhosttyVTEnabled = true
#endif

// MARK: - 🚛 Forward Module Declarations

let CGhosttyVT: Target.Dependency = .byName(name: "CGhosttyVT")
let CTesseraTerminalPlatform: Target.Dependency = .byName(
  name: "CTesseraTerminalPlatform"
)
let Tessera: Target.Dependency = .byName(name: "Tessera")
let TesseraCore: Target.Dependency = .byName(name: "TesseraCore")
let TesseraLayout: Target.Dependency = .byName(name: "TesseraLayout")
let TesseraWidgets: Target.Dependency = .byName(name: "TesseraWidgets")
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
  "TesseraLayout",
  "TesseraWidgets",
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

if GhosttyVTEnabled {
  package.targets.append(
    .target(
      name: "CGhosttyVT",
      path: "Sources/CGhosttyVT",
      publicHeadersPath: "include"
    )
  )
}

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
      TesseraLayout,
      TesseraWidgets,
      TesseraTerminal,
    ]
  )
)

// MARK: TesseraArchitectureTests

package.targets.append(
  .testTarget(name: "TesseraArchitectureTests")
)

// MARK: TesseraCore

package.targets.append(contentsOf: [
  .target(
    name: "TesseraCore",
    dependencies: [
      TesseraTerminalBuffer,
      TesseraTerminalCore,
      TesseraTerminalInput,
    ]
  ),
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

// MARK: TesseraLayout

package.targets.append(contentsOf: [
  .target(
    name: "TesseraLayout",
    dependencies: [
      TesseraCore
    ]
  ),
  .testTarget(
    name: "TesseraLayoutTests",
    dependencies: [
      TesseraLayout
    ]
  ),
])

// MARK: TesseraWidgets

package.targets.append(contentsOf: [
  .target(
    name: "TesseraWidgets",
    dependencies: [
      TesseraCore,
      TesseraLayout,
    ]
  ),
  .testTarget(
    name: "TesseraWidgetsTests",
    dependencies: [
      TesseraWidgets
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

let TesseraTerminalANSITestDependencies: [Target.Dependency] = [
  CustomDump,
  InlineSnapshotTesting,
  SnapshotTesting,
  SnapshotTestingCustomDump,
  TesseraTerminalANSI,
  TesseraTerminalSnapshotSupport,
]

package.targets.append(contentsOf: [
  .target(
    name: "TesseraTerminalANSI",
    dependencies: [
      TesseraTerminalCore
    ]
  ),
  .testTarget(
    name: "TesseraTerminalANSITests",
    dependencies: TesseraTerminalANSITestDependencies
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
      TesseraTerminalSnapshotSupport,
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
package.products.append(
  .library(
    name: "TesseraTerminalSnapshotSupport",
    targets: ["TesseraTerminalSnapshotSupport"]
  )
)

let TesseraTerminalSnapshotSupportPlatformDependencies: [Target.Dependency] =
  GhosttyVTEnabled ? [CGhosttyVT] : []

package.targets.append(contentsOf: [
  .target(
    name: "TesseraTerminalSnapshotSupport",
    dependencies: TesseraTerminalSnapshotSupportPlatformDependencies + [
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
      TesseraTerminal,
      TesseraTerminalCore,
      TesseraTerminalSnapshotSupport,
      TesseraTerminalTestSupport,
    ]
  ),
])

// MARK: TesseraTerminalTestSupport
package.products.append(
  .library(
    name: "TesseraTerminalTestSupport",
    targets: ["TesseraTerminalTestSupport"]
  )
)

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
let GhosttyVTEnvironment = ProcessInfo.processInfo.environment

func defaultGhosttyVTOutputRoot(
  packageDirectory: String,
  environment: [String: String]
) -> String {
  let outputDirectory = environment["GHOSTTY_VT_OUTPUT_DIR"] ?? ""
  if !outputDirectory.isEmpty {
    return outputDirectory
  }
  #if os(Windows)
    if let localAppData = environment["LOCALAPPDATA"], !localAppData.isEmpty {
      return "\(localAppData)/tessera/libghostty-vt"
    }
  #else
    if let cacheHome = environment["XDG_CACHE_HOME"], !cacheHome.isEmpty {
      return "\(cacheHome)/tessera/libghostty-vt"
    }
    if let home = environment["HOME"], !home.isEmpty {
      return "\(home)/.cache/tessera/libghostty-vt"
    }
  #endif
  return "\(packageDirectory)/.build/libghostty-vt"
}

let GhosttyVTRevisionFile = "\(PackageDirectory)/scripts/ghostty-vt-version.txt"
let GhosttyVTRevision =
  (try? String(contentsOfFile: GhosttyVTRevisionFile, encoding: .utf8))?
  .trimmingCharacters(in: .whitespacesAndNewlines) ?? "unknown"
#if os(macOS)
  let GhosttyVTPlatform = "macos"
#elseif os(Linux)
  let GhosttyVTPlatform = "linux"
#elseif os(Windows)
  let GhosttyVTPlatform = "windows"
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
let GhosttyVTOutputRoot = defaultGhosttyVTOutputRoot(
  packageDirectory: PackageDirectory,
  environment: GhosttyVTEnvironment
)
let GhosttyVTInstallPath =
  "\(GhosttyVTOutputRoot)/\(GhosttyVTRevision)/\(GhosttyVTPlatform)-\(GhosttyVTArch)"
let GhosttyVTLibraryPath = "\(GhosttyVTInstallPath)/lib"
#if os(Windows)
  // Static: linking ghostty-vt-static.lib avoids runtime ghostty-vt.dll
  // discovery. Zig's std library calls ntdll syscalls (NtAllocateVirtualMemory,
  // DeviceIoControl, ...) directly, so static consumers must link ntdll too.
  // No rpath on Windows.
  let GhosttyVTUnsafeLinkerFlags = [
    "-L\(GhosttyVTLibraryPath)",
    "-lghostty-vt-static",
    "-lntdll",
  ]
#else
  let GhosttyVTUnsafeLinkerFlags = [
    "-L\(GhosttyVTLibraryPath)",
    "-lghostty-vt",
    "-Xlinker",
    "-rpath",
    "-Xlinker",
    GhosttyVTLibraryPath,
  ]
#endif
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
    .enableExperimentalFeature("Lifetimes"),
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("ForwardFromBuilder"),
    .enableUpcomingFeature("InferIsolatedConformances"),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
  ])
  target.swiftSettings = settings
}
