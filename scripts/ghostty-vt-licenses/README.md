# libghostty-vt third-party licenses

The static libghostty-vt archives that `.github/workflows/ghostty-vt.yml` publishes contain code from Ghostty and from the components below. `scripts/package-libghostty-vt-bundle.sh` and `.ps1` copy this directory into the artifact bundle as `THIRD_PARTY_LICENSES/`, beside Ghostty's own `LICENSE`, so the notices travel with the binaries. Where a component offers a choice of licenses, Tessera redistributes it under the one listed.

| Component | Version at pin `f54340ad` | In the archive as | License | File |
| --- | --- | --- | --- | --- |
| [Highway](https://github.com/google/highway) | 1.2.0 | `highway_zcu.o`, `targets.o`, `per_target.o` | BSD-3-Clause (of Apache-2.0 OR BSD-3-Clause) | `highway-LICENSE-BSD3` |
| [simdutf](https://github.com/simdutf/simdutf) | 9.0.0 | `simdutf.o` | MIT (of Apache-2.0 OR MIT) | `simdutf-LICENSE-MIT` |
| [Wuffs](https://github.com/google/wuffs) | 0.4.0-alpha.10 | `wuffs-v0.4.o` | MIT (of Apache-2.0 OR MIT) | `wuffs-LICENSE-MIT` |
| [uucode](https://github.com/jacobsandlund/uucode) | 0.2.0 | Unicode property code and tables in the Zig object | MIT | `uucode-LICENSE` |
| Unicode Character Database, through uucode | as vendored by uucode 0.2.0 | Unicode property tables | Unicode License V3 | `unicode-LICENSE` |
| Björn Höhrmann's UTF-8 decoder, through uucode | as vendored by uucode 0.2.0 | UTF-8 decoding in the Zig object | MIT | `hoehrmann-utf8-decoder-LICENSE` |
| [Zig](https://ziglang.org) standard library and compiler-rt | 0.17.0 | `ghostty-vt-static_zcu.o`, `compiler_rt.o` | MIT | `zig-LICENSE` |

A pin bump checks this table against the new revision: `ar t` on the built archive lists its objects, and the pinned `build.zig.zon` and `pkg/*/build.zig.zon` name the versions. [Updating Ghostty VT](../../docs/guides/updating-ghostty-vt.md) has the step.
