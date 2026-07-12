---
name: Swift Inlining Attributes
date: 2026-07-03
status: resolved
---

# Swift Inlining Attributes

## Question

How should a Swift library author think about performance attributes such as `@inlinable`,
`@usableFromInline`, `@frozen`, `@inline(always)`, and `@specialized`? Are these part of
Swift library evolution?

## Findings

- The correct public spelling is `@inlinable`, not `@inlineable`. SE-0193 says the
  proposal originally used `@inlineable`, then changed to `@inlinable` for consistency
  with `Decodable` and `Encodable`. [swift-evolution://SE-0193](swift-evolution://SE-0193)
- `@inlinable` exposes an implementation in the module interface so optimizers in other
  modules can inline, specialize, or ignore it. It is a cross-module optimization knob,
  not a force-inline command. [swift-book://attributes](swift-book://attributes)
  [swift-evolution://SE-0193](swift-evolution://SE-0193)
- `@usableFromInline` lets internal declarations be referenced from inlinable code without
  making them source-public. It is ABI-public but not source-public.
  [swift-book://attributes](swift-book://attributes)
  [swift-evolution://SE-0193](swift-evolution://SE-0193)
- SE-0193 ties these attributes to ABI stability and resilience. It warns that inlinable
  bodies can leave old copied implementations in client binaries, so body changes must
  preserve observed behavior. [swift-evolution://SE-0193](swift-evolution://SE-0193)
- SE-0260 defines library evolution mode with `-enable-library-evolution` and Xcode's
  `BUILD_LIBRARY_FOR_DISTRIBUTION`. It preserves ABI flexibility but adds indirection that
  can cost performance. [swift-evolution://SE-0260](swift-evolution://SE-0260)
  [swift-book://attributes](swift-book://attributes)
- `@frozen` is the explicit opt-out from some library evolution flexibility for structs
  and enums. It enables optimizations but commits stored property or enum case layout
  against future ABI-compatible changes.
  [swift-book://attributes](swift-book://attributes)
  [swift-evolution://SE-0260](swift-evolution://SE-0260)
- SE-0192 introduced the frozen/non-frozen enum model and `@unknown default` for switches
  over enums that may gain future cases.
  [swift-evolution://SE-0192](swift-evolution://SE-0192)
- SE-0496 introduces `@inline(always)` as an explicit force-inlining control in Swift 6.3.
  Public/open/package uses inherit `@inlinable` rules. This is a sharper tool than
  `@inlinable` and should be measurement-driven.
  [swift-evolution://SE-0496](swift-evolution://SE-0496)
- SE-0460 introduces `@specialized` in Swift 6.3 for pre-specializing generic functions
  for selected concrete types. It targets cases where type erasure or a binary framework
  prevents ordinary caller-side specialization.
  [swift-evolution://SE-0460](swift-evolution://SE-0460)

## Conclusion

Yes: `@inlinable`, `@usableFromInline`, and `@frozen` sit squarely in Swift's library
evolution and ABI-resilience model. They are not general-purpose "make faster"
decorations. They trade future implementation freedom, ABI surface, binary size, and
semantic compatibility for more optimizer visibility.

For Tessera, use them only on tiny, stable, hot-path public APIs after profiling or
benchmarking shows a cross-module optimization gap. Prefer ordinary clear Swift first;
reach for `@inlinable` for small generic wrappers/algorithms, `@usableFromInline` for
helpers needed by those bodies, `@frozen` only for value types whose stored layout or
cases are intentionally permanent, and `@inline(always)`/`@specialized` only with strong
measurement evidence.
