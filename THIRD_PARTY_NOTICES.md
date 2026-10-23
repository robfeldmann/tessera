# Third-Party Notices

This source distribution includes no third-party source code apart from Ghostty's C headers (see [Ghostty VT](#ghostty-vt)). Swift Package Manager resolves the following components when building Tessera or its documentation and test targets. Their versions and revisions are pinned in [`Package.resolved`](Package.resolved) and, for examples, in [`Examples/Package.resolved`](Examples/Package.resolved).

## Apache License 2.0 Components

- [swift-docc-plugin](https://github.com/apple/swift-docc-plugin)
- [swift-docc-symbolkit](https://github.com/swiftlang/swift-docc-symbolkit)
- [swift-syntax](https://github.com/swiftlang/swift-syntax)
- [swift-system](https://github.com/apple/swift-system)

## MIT License Components

- [swift-custom-dump](https://github.com/pointfreeco/swift-custom-dump)
- [swift-displaywidth](https://github.com/ainame/swift-displaywidth)
- [swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing)
- [xctest-dynamic-overlay](https://github.com/pointfreeco/xctest-dynamic-overlay)

## Ghostty VT

Tessera includes the C headers of [Ghostty](https://github.com/ghostty-org/ghostty)'s `libghostty-vt` for the revision in [`scripts/ghostty-vt-version.txt`](scripts/ghostty-vt-version.txt), under [`Sources/CGhosttyVT/include/ghostty/`](Sources/CGhosttyVT/include/ghostty/). The `GhosttyVTLibrary` binary target downloads `libghostty-vt`, built from that revision, from this repository's `ghostty-vt-<revision>` release; that artifact bundle carries Ghostty's `LICENSE`. A Tessera distribution that includes any Ghostty-derived artifact must retain this attribution and the MIT license text below.

Copyright (c) 2024 Mitchell Hashimoto, Ghostty contributors

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

### Components linked into libghostty-vt

The `libghostty-vt` static archives also contain code from the components below, compiled in by Ghostty's build. Their license texts are in [`scripts/ghostty-vt-licenses/`](scripts/ghostty-vt-licenses/README.md), which the producer workflow ships in the artifact bundle as `THIRD_PARTY_LICENSES/`; a distribution of an app that links `libghostty-vt` must retain them too.

- [Highway](https://github.com/google/highway) 1.2.0: BSD-3-Clause (offered as Apache-2.0 OR BSD-3-Clause).
- [simdutf](https://github.com/simdutf/simdutf) 9.0.0: MIT (offered as Apache-2.0 OR MIT).
- [Wuffs](https://github.com/google/wuffs) 0.4.0-alpha.10: MIT (offered as Apache-2.0 OR MIT).
- [uucode](https://github.com/jacobsandlund/uucode) 0.2.0: MIT; with Unicode Character Database tables under the Unicode License V3 and Björn Höhrmann's UTF-8 decoder under MIT.
- [Zig](https://ziglang.org) 0.17.0 standard library and compiler-rt: MIT.

The first published bundle, `ghostty-vt-f54340ad7781`, predates `THIRD_PARTY_LICENSES/` and carries only Ghostty's `LICENSE`; this file and `scripts/ghostty-vt-licenses/` cover it. Bundles for later pins include the directory.
