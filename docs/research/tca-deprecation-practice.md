---
type: research
observed: 2026-10-25
status: resolved
description: How the Composable Architecture deprecates, removes, and documents public API, and its SwiftPM-trait staging for 2.0.
---

# Composable Architecture deprecation practice

## Question

How does the Composable Architecture (TCA) retire public API, and which parts suit Tessera, which builds on Linux and Windows as well as Apple platforms?

## Findings

Citations are to a local clone at `swift-composable-architecture` 1.26.0 (`05ec494be5`).

- **Soft deprecation.** Platform-specific `@available(iOS, deprecated: 9999, message: …)` (repeated for macOS, tvOS, and watchOS) marks an API deprecated in documentation and autocomplete without a compiler warning: `Sources/ComposableArchitecture/Effect.swift:288-311`. Commit `dcecad3fe2` ("Soft-deprecate `Store.ifLet`") is an early use.
- **Trait-gated deprecation.** `Package.swift:20-36` declares two traits. `ComposableArchitecture2Deprecations` is meant to stay on and upgrades soft deprecations to hard ones; `ComposableArchitecture2DeprecationOverloads` holds deprecations that need overloads which "can tax the compiler", for temporary use while migrating. Declarations switch with `#if ComposableArchitecture2Deprecations` / `@available(*, deprecated, …)` / `#else` / the soft form (`Effect.swift:288-311`); 29 sites use the first trait. Commit `2fc6ed2713` added the soft form to the `#else` branches "so these APIs still surface as deprecated more visibly".
- **Point-Free's rationale** ([Hard deprecations and soft landings with SwiftPM traits](https://www.pointfree.co/blog/posts/203-hard-deprecations-and-soft-landings-with-swiftpm-traits)): the library stays source compatible by default, APIs are "silently marked deprecated in documentation and in the type system", and users who want to prepare early opt in, then migrate gradually by enabling and disabling the trait. Xcode 26.4 exposes package traits in project settings.
- **Hard deprecation.** `@available(*, deprecated, renamed: …)` for direct substitutions and `message:` otherwise; messages link to an anchored migration-guide section, e.g. `Internal/Deprecations.swift:15-21` linking `migratingto1.7#BindingState`. Commits follow a fixed vocabulary: "Soft-deprecate", "Trait-deprecate", "Hard-deprecate", "Fully-deprecate" (`git log --grep=deprecat`).
- **One file for old API.** `Sources/ComposableArchitecture/Internal/Deprecations.swift` (3,941 lines) is grouped under banners naming the release, newest first: `// NB: Deprecated with 1.25.0:` at line 13, then 1.24.0, 1.13.0, 1.10.0, 1.7.0, and 1.0.0.
- **Unavailable stubs.** After removal, declarations stay as `@available(*, unavailable, renamed: …)` so callers get a fix-it: `ReducerProtocol` → `Reducer` and `EffectTask` → `Effect` (`Internal/Deprecations.swift:3934-3941`) have survived from 1.0 through 1.26.
- **Removal at a major release.** The 1.0 commit (`195284b94b`) deleted 1,086 lines from `Deprecations.swift` and 8,474 lines across 130 files, so 0.x had been deprecating rather than breaking.
- **Documentation.** Deprecated symbols move out of the main Topics lists into per-type extension articles, e.g. `Documentation.docc/Extensions/Deprecations/StoreDeprecations.md` ("Review unsupported store APIs and their replacements"). `Documentation.docc/Articles/MigrationGuides.md` lists one `MigratingTo1.x` article per release that deprecated API, newest first, and tells readers to follow every preceding guide first. `MigratingTo1.25.md` documents the traits and shows each change as a diff.
- **Platform reach (inference from the attribute's semantics).** Platform-specific `deprecated: 9999` names only Apple platforms, so on Linux and Windows a soft-deprecated API carries no marker at all; only `@available(*, …)` reaches every platform.

## Conclusion

TCA's mechanics transfer almost unchanged: replacement first, hard deprecation with `renamed:` or a linked message, one banner-grouped `Deprecations.swift`, `unavailable` stubs after removal, per-type DocC deprecation articles, and cumulative migration guides. Soft deprecation does not transfer, because Tessera's Linux and Windows users would never see it. Trait-gated deprecation transfers as an option for staging a major release, using `@available(*, deprecated)` under the trait and nothing otherwise. [API deprecation](../architecture/api-deprecation.md) records the policy Tessera adopted.
