// swift-tools-version: 6.3

// swift-format-ignore-file: AlwaysUseLowerCamelCase

import PackageDescription

// MARK: - 📦 Manifest

let package = Package(
  name: "tessera-examples",
  platforms: [
    .macOS(.v26)
  ],
  products: [],  // see Products & Targets below
  dependencies: [],  // see Dependencies below
  targets: [],  // see Products & Targets below
  swiftLanguageModes: [.v6]
)

// MARK: - ⤵️ Dependencies

// MARK: Tessera

package.dependencies.append(
  .package(name: "tessera", path: "..")
)

let Tessera: Target.Dependency = .product(
  name: "Tessera",
  package: "tessera"
)

let TesseraTerminal: Target.Dependency = .product(
  name: "TesseraTerminal",
  package: "tessera"
)

// MARK: - 🚛 Forward Module Declarations

let ANSIEncoderDemo: Target.Dependency = .byName(name: "ANSIEncoderDemo")
let ExampleSupport: Target.Dependency = .byName(name: "ExampleSupport")
let HelloTessera: Target.Dependency = .byName(name: "HelloTessera")
let InputInspector: Target.Dependency = .byName(name: "InputInspector")
let LifecycleModesDemo: Target.Dependency = .byName(name: "LifecycleModesDemo")
let RendererDemo: Target.Dependency = .byName(name: "RendererDemo")

let AllTesseraExampleTargetNames: Set<String> = [
  "ANSIEncoderDemo",
  "ExampleSupport",
  "HelloTessera",
  "InputInspector",
  "LifecycleModesDemo",
  "RendererDemo",
]

// MARK: - 🎯 Products & Targets

// MARK: ANSIEncoderDemo

package.products.append(.executable(name: "ANSIEncoderDemo", targets: ["ANSIEncoderDemo"]))

package.targets.append(
  .executableTarget(
    name: "ANSIEncoderDemo",
    dependencies: [
      TesseraTerminal
    ]
  )
)

// MARK: ExampleSupport

package.targets.append(
  .target(name: "ExampleSupport")
)

// MARK: HelloTessera

package.products.append(.executable(name: "HelloTessera", targets: ["HelloTessera"]))

package.targets.append(
  .executableTarget(
    name: "HelloTessera",
    dependencies: [
      ExampleSupport,
      TesseraTerminal,
    ]
  )
)

// MARK: InputInspector

package.products.append(.executable(name: "InputInspector", targets: ["InputInspector"]))

package.targets.append(
  .executableTarget(
    name: "InputInspector",
    dependencies: [
      ExampleSupport,
      TesseraTerminal,
    ]
  )
)

// MARK: LifecycleModesDemo

package.products.append(
  .executable(name: "LifecycleModesDemo", targets: ["LifecycleModesDemo"])
)

package.targets.append(
  .executableTarget(
    name: "LifecycleModesDemo",
    dependencies: [
      ExampleSupport,
      TesseraTerminal,
    ]
  )
)

// MARK: RendererDemo

package.products.append(.executable(name: "RendererDemo", targets: ["RendererDemo"]))

package.targets.append(
  .executableTarget(
    name: "RendererDemo",
    dependencies: [
      ExampleSupport,
      TesseraTerminal,
    ]
  )
)

// MARK: - ⚙️ Shared Swift Settings

for target in package.targets {
  guard AllTesseraExampleTargetNames.contains(target.name) else {
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
