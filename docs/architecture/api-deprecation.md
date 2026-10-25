---
type: architecture
description: How a public API is deprecated, removed, and kept as an unavailable stub, before and after 1.0, and the package-trait option for staging a major release.
---

# API deprecation

## Decision

A public API leaves Tessera in three steps: it is deprecated, then removed with an `unavailable` stub left in its place, then the stub is deleted at the next major release. A replacement always ships no later than the deprecation, so every deprecation warning names something the caller can move to today.

| Step | Before 1.0 | From 1.0 | Spelling |
|---|---|---|---|
| Deprecated | `0.N` | `1.x` | `@available(*, deprecated, renamed: "…")`, or `message:` when there is no one-to-one replacement |
| Removed, stub kept | `0.N+1` | `2.0` | `@available(*, unavailable, renamed: "…")`, or `message:` |
| Stub deleted | `1.0` | `3.0` | none |

Before 1.0 a deprecation lasts one minor release: SemVer lets a `0.x` minor release break callers, and [CONTRIBUTING.md](../../CONTRIBUTING.md) bumps the minor version for breaking changes, so the following minor release removes the API. From 1.0, deprecations land in minor releases and removals only in major releases. In both eras the stub survives until the next major release, so a caller who skips releases still gets a compile error with a fix-it instead of "cannot find in scope", and each major release starts from a clean surface.

### Spelling

- Deprecations are hard: `@available(*, deprecated, …)`, which warns on every platform. Platform-specific soft deprecation (`@available(macOS, deprecated: 9999, …)`) is not used, because Tessera builds on Linux and Windows, where it is ignored.
- Prefer `renamed:` whenever the replacement is a direct substitution, since it drives Xcode's fix-it. Otherwise `message:` names the replacement in single quotes and links to the migration guide section that covers it.
- An `unavailable` stub keeps the old signature and forwards to the replacement (a `typealias` where possible), so the fix-it and the documentation stay correct. A deprecated or unavailable declaration that would collide with its replacement in overload resolution takes `@_disfavoredOverload`.

### Where old API lives

- Each module keeps its deprecated and unavailable declarations in one file, `Sources/<Module>/Internal/Deprecations.swift`, grouped newest first under a banner naming the release that deprecated them: `// NB: Deprecated in 0.4.0:`. Deleting stubs at a major release is deleting banner sections.
- The declaration keeps its doc comment, so the symbol still documents what it did.
- A deprecated symbol leaves its type's main Topics list and moves to a `Deprecations` extension article in that module's DocC catalog (`<Module>.docc/Extensions/Deprecations/<Type>Deprecations.md`), so the main reference shows only current API.

### Migration guides and the changelog

- A release that deprecates or removes API carries a `MigratingTo<version>` article in the `Tessera` umbrella catalog, listed newest first under a Migration guides article that asks readers to follow the guides in order. Each deprecated API gets an anchored section with a before-and-after diff; deprecation messages link to it.
- `CHANGELOG.md` lists each deprecation under `Deprecated` and each removal under `Removed`, with a link to the guide section. A removal is a breaking change, so the release section also carries the migration guidance [CONTRIBUTING.md](../../CONTRIBUTING.md) requires.

### Package traits for staging a major release

Tessera does not use package traits for deprecation. When a major release needs a long lead-in, a trait can let callers opt into its deprecations early, as the Composable Architecture does for 2.0 (see the research record below):

```swift
#if Tessera2Deprecations
  @available(*, deprecated, message: "Use 'NewThing' instead")
#endif
public func oldThing() { … }
```

Callers opt in with `traits: ["Tessera2Deprecations"]` on the package dependency (or in project settings from Xcode 26.4). The trait is meant to stay on, so new deprecations surface as they ship. A second trait can hold deprecations that need extra overloads, which slow type-checking, for callers to enable only while migrating. Without the trait the API is deprecated only in the documentation, so Tessera's version of the pattern drops the Composable Architecture's `deprecated: 9999` fallback: it would mark the API only on Apple platforms. Traits need `swift-tools-version: 6.1`, which the manifest already exceeds.

## Why

The ladder and its file layout follow the Composable Architecture, which has deprecated and removed API through more than twenty minor releases and one major release with a consistent set of mechanics; see [Composable Architecture deprecation practice](../research/tca-deprecation-practice.md). The departures are deliberate. Before 1.0, a single minor release of hard deprecation costs about as little as breaking callers outright while still handing them fix-its, and it exercises the same file, banners, guides, and changelog entries 1.0 will use. Stubs are cheap and help exactly the callers who upgrade rarely, so they stay until the next major release. Soft deprecation is dropped because it only reaches Apple platforms (decided with the owner, 2026-10-25).
