// swift-tools-version: 6.3

// swift-format-ignore-file: AlwaysUseLowerCamelCase

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

// MARK: DocC

package.dependencies.append(
  .package(
    url: "https://github.com/apple/swift-docc-plugin",
    from: "1.0.0"
  )
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
      TesseraCore
    ]
  ),
])

// MARK: TesseraTerminal

package.products.append(.library(name: "TesseraTerminal", targets: ["TesseraTerminal"]))

package.targets.append(
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
  )
)

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
      TesseraTerminalANSI
    ]
  ),
])

// MARK: TesseraTerminalBuffer

package.targets.append(contentsOf: [
  .target(
    name: "TesseraTerminalBuffer",
    dependencies: [
      DisplayWidth,
      TesseraTerminalCore,
    ]
  ),
  .testTarget(
    name: "TesseraTerminalBufferTests",
    dependencies: [
      TesseraTerminalBuffer
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
      TesseraTerminalCore
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
      TesseraTerminalInput
    ]
  ),
])

// MARK: TesseraTerminalIO

package.targets.append(contentsOf: [
  .target(
    name: "TesseraTerminalIO",
    dependencies: [
      SystemPackage,
      TesseraTerminalANSI,
      TesseraTerminalCore,
      TesseraTerminalInput,
    ]
  ),
  .testTarget(
    name: "TesseraTerminalIOTests",
    dependencies: [
      TesseraTerminalIO
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
      TesseraTerminalRendering,
      TesseraTerminalSnapshotSupport,
    ]
  ),
])

// MARK: TesseraTerminalSnapshotSupport

package.targets.append(
  .target(
    name: "TesseraTerminalSnapshotSupport",
    dependencies: [
      TesseraTerminalANSI,
      TesseraTerminalBuffer,
      TesseraTerminalRendering,
    ]
  )
)

// MARK: TesseraTerminalTestSupport

package.targets.append(
  .target(
    name: "TesseraTerminalTestSupport",
    dependencies: [
      TesseraTerminalInput,
      TesseraTerminalIO,
      TesseraTerminalSnapshotSupport,
    ]
  )
)

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
