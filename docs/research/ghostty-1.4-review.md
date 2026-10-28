---
type: research
observed: 2026-10-27
status: resolved
description: What Ghostty 1.4.0 and the libghostty roadmap mean for Tessera's libghostty-vt pin, artifact bundle, and Swift bindings.
---

# Ghostty 1.4 and libghostty: what it means for Tessera

## Question

Ghostty 1.4.0 shipped on 2026-10-27 with a "Libghostty" section in its release notes. Is Tessera's use of libghostty-vt still the right one, what changed between Tessera's pin and `v1.4.0`, is there now a tagged or published libghostty-vt that could replace Tessera's own artifact bundle, should Tessera adopt a Swift binding, and which local docs does the release make stale?

Reviewed 2026-10-27, the day Ghostty 1.4.0 shipped. Nothing in the repo was edited; scratch work is under `/tmp/ghostty14/` (upstream clone, diffs, downloaded tarball).

Conventions: `file:line` is the Tessera checkout; `upstream@v1.4.0` means the `ghostty-org/ghostty` tag `v1.4.0` (commit `83fb95624b0439ee660c2679b43b38c8b63769cd`, tagger date 2026-10-27), read from a local blobless clone. `[INFERENCE]` is my reasoning, not an observation. `[UNVERIFIED]` is not checked.

## Findings

### Q1. libghostty vs libghostty-vt vs GhosttyKit

| Name | What it is | Who it's for | Evidence |
| --- | --- | --- | --- |
| **libghostty** | The umbrella name for Ghostty's reusable core and, going forward, a *family* of libraries `libghostty-<x>`. Separately versioned from the app. | Architectural term. Not one shippable artifact. | [Libghostty Is Coming](https://mitchellh.com/writing/libghostty-is-coming) ("a family of libraries", "version libghostty separately"); [About Ghostty](https://ghostty.org/docs/about) (the older, broader sense: core "provides terminal emulation, font handling, and rendering"). |
| **libghostty-vt** | The first, and so far the only, public member: a C (and Zig) library for parsing VT sequences, maintaining screen state, Kitty graphics, render state, formatting, snapshots, search, and key/mouse/focus/paste encoding. Zero dependencies; no libc++ (removed in April, `43a05dc96`, already in our pin; announced in the 1.4 notes). Headers in `include/ghostty/vt.h` and `include/ghostty/vt/`. | External embedders. | [1.4 release notes, "Libghostty"](https://ghostty.org/docs/install/release-notes/1-4-0); [API docs](https://libghostty.tip.ghostty.org/); `upstream@v1.4.0:include/ghostty/vt.h`. |
| **GhosttyKit / `ghostty.h`** | The macOS app's *internal* embedder API, named "libghostty-internal" in its own header, shipped as `GhosttyKit.xcframework` (module `GhosttyKit` in `include/module.modulemap`). Surface, renderer, Metal. Not designed for external use. | Only the Ghostty macOS app. Third parties repackage it for Apple GUI apps (Lakr233/libghostty-spm, sethdeckard, termio-sh, …). | `upstream@v1.4.0:include/ghostty.h:1-11` ("The only consumer of this API is the macOS app… External embedders should instead use `libghostty-vt`"); `upstream@v1.4.0:include/module.modulemap`. |

**Which Tessera uses, and is it still right?** `libghostty-vt`, through `CGhosttyVT` (`Package.swift:187`, headers under `Sources/CGhosttyVT/include/ghostty/`). It is still the right one:

- Upstream's own header now tells external embedders to use libghostty-vt (above). That is the opposite of GhosttyKit.
- The harness needs headless feed → cells/styles/cursor. GhosttyKit's surface API cannot do that: the June spike found `ghostty_surface_new` returns nil without an AppKit view and segfaults with a detached one (`docs/research/ghostty-vt-harness-spike.md:24-26`).
- The 1.4 post says libghostty-vt is now "a complete terminal emulator API" and "builds for macOS, Linux, Windows (MSVC and GNU), FreeBSD, Android, iOS, and WebAssembly, and CI continuously verifies every one of these targets" ([release notes](https://ghostty.org/docs/install/release-notes/1-4-0)). `.github/workflows/test.yml@v1.4.0` jobs: `build-libghostty-vt` (aarch64/x86_64-macos, aarch64/x86_64-linux, x86_64-linux-musl, aarch64/x86_64-freebsd, x86_64-windows-gnu), `build-libghostty-vt-windows` (native Windows runner, `zig build test-lib-vt`), `-macos` (adds aarch64-ios and -ios-simulator), `-android`, `-wasm`, `-freestanding`, `-features`, `test-lib-vt`, `test-lib-vt-freebsd`.

Side facts worth knowing:

- The libghostty-vt version is separate from the app's: `lib_version = "0.1.0-dev"` (`upstream@v1.4.0:build.zig:11`), and the shared library is `libghostty-vt.so.0.1.0` (`.github/workflows/test.yml:421@v1.4.0`). The source tarball is still named after the *app* version: `libghostty-vt-1.3.2-main+f54340a/` with a `VERSION` file `1.3.2-main+f54340a` (downloaded and inspected).
- `upstream@v1.4.0` has no `visionOS` job in `build-libghostty-vt-macos`, although the maintainer's HN list says visionOS. [UNVERIFIED which job covers it.]

### Q2. What changed between our pin and v1.4.0

#### 2a. The delta is small and mostly invisible to us

Method: `git rev-list`, `git diff --stat`, `git log` and `git merge-base --is-ancestor` against `f54340ad…` and `v1.4.0`.

- `f54340ad…` (2026-10-21, "libghostty-vt: add `vt_write_until`", #14802) **is an ancestor** of `v1.4.0`; 73 commits (32 distinct PRs) separate them, 0 the other way. `origin/main` is 7 commits past the tag, none touching libghostty-vt (config/snap/flatpak fixes).
- **Public headers:** 3 commits touch `include/`; net diff is `osc.h` (a renamed function in a comment) and `terminal.h` (documentation of the new CAN/SUB/abort behaviour). 11 comment lines. Tessera's vendored headers are byte-identical to the pin's published headers (`diff -rq` against the pin's source tarball: 0 differences).
- **Unchanged between pin and v1.4.0** (empty `git diff --stat`): `src/terminal/c/` (the C binding), `src/terminal/render.zig`, `src/terminal/formatter.zig`, `src/input/` (key encoder), `CMakeLists.txt`, `example/`, `pkg/`, `LICENSE`, `src/build/GhosttyLibVt.zig`, `GhosttyZig.zig`, `SharedDeps.zig`.
- **Build:** `minimum_zig_version` is still `0.17.0` (`build.zig.zon:6` at both revisions), matching `mise.toml:32` (`zig = "0.17.0"`). The Zig 0.17 migration landed 2026-10-20, before our pin. So no Zig bump is needed. `build.zig.zon` changes are `version = "1.4.0"` and two GUI-only dependencies (z2d, iTerm2 themes). The `Changes for Package Maintainers` note "Ghostty now requires Zig 0.17" is already satisfied. `-Demit-lib-vt` now also splits out `-Demit-test-exe` (test-only) and adds `-Dinstalled-exe-path` (GUI Linux launcher files only).
- **Third-party licences:** `pkg/` and `LICENSE` unchanged since the pin, so `scripts/ghostty-vt-licenses/` and `THIRD_PARTY_NOTICES.md` stay valid (`docs/guides/updating-ghostty-vt.md:51`).

#### 2b. What is *already* in our pin (so "1.4" behaviour is not new to us)

Checked per PR with `git merge-base --is-ancestor`: Kitty animation (#13943), relative placements (#13939), transient hint (#13389), retransmit clears placements (#13723), scroll/clip inside margins (#13935), ID collisions (#13934), delete semantics (#13895), Kitty placeholders resolved in the render state (#14780), Unicode 18 (#14293), grapheme/2027 fixes (#14552, #12596, #12581), wide-char fixes (#14509, #13631), DECSTR (#14538), DECXCPR (#14673), `CSI 19 t` (#14633), ED 2 at a prompt (#14668), modifyOtherKeys and legacy key fixes (#14144-#14146, #14508), kitty key-release text (#13861), OSC/grapheme allocation bounds (#13633), OSC 7501 program status (#14560), scrollback compression (#13264), `vt_write_until` (#14802), esctest conformance work. The 1.4 post's "Terminal Capabilities" list is therefore almost entirely behaviour we already link.

#### 2c. What is *after* the pin (the actual delta that reaches libghostty-vt)

| Commit (PR) | Change | Touches what Tessera relies on? |
| --- | --- | --- |
| `75a7606c3`/`802665102` (#14812), `3079a4396` (#14811), `e07a6f0eb` | An APC (Kitty graphics command) cancelled by CAN/SUB, or aborted by another 8-bit control byte (e.g. 0x9B), is **discarded, not executed**. A non-chunk continuation ends a chunked Kitty transmission. | Kitty graphics, only for malformed or interrupted streams. Tessera sends base64 payloads (7-bit), so no impact expected. [INFERENCE] |
| `9cac2bd0c` (#14832) | ED 3 / scrollback erase now removes Kitty placements anchored in the erased rows. | Harness runs with 0 scrollback (`VirtualTerminal+Ghostty.swift:49-60`); n/a. |
| `a6a1a4664` (#14838), `e257bb45e` (#14857), `84983d060` (#14856) | Memory-safety fixes around erased history, `scrollClear` and cursor style/hyperlink, page `Capacity.adjust`. #14857 is [GHSA-w9q4-5jvv-mcv4](https://github.com/ghostty-org/ghostty/security/advisories/GHSA-w9q4-5jvv-mcv4): "clearing the screen into scrollback could corrupt memory… only with a small `scrollback-limit` such as `0`". | Our harness *is* a scrollback-0 terminal. But `scrollClear` runs only for `CSI 22 J` or for `ED 2` when the last non-empty row is an OSC 133 prompt (`src/terminal/Terminal.zig:3704,3761@v1.4.0`), and a grep of `Sources/` and `Tests/` finds no OSC 133 or `CSI 22 J` emitted by Tessera. Exposure is low but not zero for apps that echo shell output. [INFERENCE] |
| `1851e121b`/`bf14ea1fb` (#14858) | tmux control-mode layout hardening. | n/a. |
| `src/terminal/modes.zig` (`297ff5292`, "gtk: implement the Kitty clipboard protocol") | Mode 5522 (Kitty clipboard paste events) is no longer gated to macOS and the library artifact. | n/a; Tessera never enables it. |
| `68640f304` (#14867), `f13b52851`, `445e23496` | FreeBSD support and CI. | n/a. |
| `a743c4e53`/`22f100c63` | Doc fix. | n/a. |

Verdict: no API change, no behaviour change to cell/style/cursor reads, render state, modes, colour/OSC queries, key encoding, or Kitty keyboard. `docs/research/ghostty-all-keys-omitted-modifier.md` still holds: the omitted-modifier form `CSI 127;;65u` is still what the encoder tests expect at v1.4.0 (`src/input/key_encode.zig:1163,1217,1853@v1.4.0`, same strings at the older `160c3c69e`). `docs/research/ghostty-graphics-erase-ordering.md` also still holds, and is now explicit in code: "a terminal clear also reclaims images that were already unplaced" (`src/terminal/kitty/graphics_storage.zig:1367-1392@v1.4.0`).

#### 2d. Platforms

- **macOS:** `aarch64-macos` and `x86_64-macos` built in upstream CI; same toolchain as ours (Zig 0.17, `minos 13.0` per our research).
- **Linux:** gnu aarch64/x86_64 and `x86_64-linux-musl` in upstream CI; we additionally ship `aarch64` musl and glibc-2.28 floors, which upstream does not test (`docs/guides/updating-ghostty-vt.md:72-73`).
- **Windows:** upstream now treats it as first-class: native Windows job plus `x86_64-windows-gnu` cross build, MSVC ABI as the default on Windows hosts (`src/build/Config.zig:105-112@v1.4.0`), and the 1.4 roadmap says "we've decided to drop any roadmap for Windows support in the Ghostty GUI. libghostty fully supports Windows… downstream projects should use that." Upstream CI is not shown to cover `aarch64-windows`; our `windows-arm64` variant (`scripts/build-libghostty-vt.ps1`) is our own to validate. [UNVERIFIED: the runner architecture of `namespace-profile-ghostty-windows`.] This closes the "promising but unverified" caveat at `docs/research/windows-libghostty-vt-snapshot-spike.md:22`.
- **SIMD on Windows:** our script passes `-Dsimd=false` (`scripts/build-libghostty-vt.ps1:217`). Upstream CI's Windows job runs plain `zig build -Demit-lib-vt` (SIMD default on), and a July commit `84254a9d8` "avoid MSVC C++ runtime in no-libcxx builds" is in the pin. Dropping `-Dsimd=false` might now work; faster Windows harness, not required. [UNVERIFIED; not built.]
- **Build features:** `-Dvt-features=` (`snapshot formatter selection render_state input_encode color grid_introspection glyph_protocol kitty_graphics`) exists in the pin (`src/build/Config.zig:65-67`) and in upstream CI. Tessera uses render state, key encoding and Kitty graphics, so a trimmed build is possible. [UNVERIFIED: size or risk benefit.]

#### 2e. Is there a stable tag or a published binary we could pin instead of our bundle?

**No tag.** `v1.4.0` is a signed, annotated *Ghostty app* tag. libghostty-vt has no tag of its own: `README.md@v1.4.0:168-170` ("We haven't tagged libghostty with a version yet"), `include/ghostty/vt.h@v1.4.0:10-11` ("not yet stable and is definitely going to change"), `lib_version = "0.1.0-dev"`. Pin the *commit* `83fb95624b04…` (tag object is `ce787fc18…`), as the guide already says (`docs/guides/updating-ghostty-vt.md:8`).

**Binaries, as of today:**

| Source | What | Pinnable? | Covers Linux/Windows? |
| --- | --- | --- | --- |
| GitHub release [`tip`](https://github.com/ghostty-org/ghostty/releases/tag/tip) (prerelease, "Nightly") | `ghostty-vt.xcframework.zip`, `ghostty-vt.wasm`, `ghostty-vt-small.wasm`, `libghostty-vt-source.tar.gz`, each with `.minisig`; re-uploaded on every `main` push (assets dated 2026-10-27) | No (replaced in place) | No |
| **Commit-addressed blobs** `https://tip.files.ghostty.org/<40-char commit>/ghostty-vt.xcframework.zip` and `…/libghostty-vt-source.tar.gz` (uploaded by `release-tip.yml@v1.4.0:288-325,395-410`) | Same files per commit | **Yes in practice.** Observed HTTP 200 for the pin (`f54340ad…`: xcframework 16,025,993 B, source 4,241,877 B, both last-modified 2026-10-21), for the v1.4.0 commit (16,048,196 B / 4,275,514 B), and for `main` HEAD. Retention policy unknown. [UNVERIFIED] | No (Apple xcframework: macOS universal + iOS) |
| GitHub release for `v1.4.0` | none (API returns 404 for the tag) | n/a | n/a |
| `pkg-config` files, CMake, Nix flake | in the source tree, not published binaries | n/a | build-from-source |

This **corrects one claim** in `docs/research/libghostty-vt-distribution.md:44` ("assets are replaced in place… would break on the next nightly"): true for the GitHub `tip` release, but per-commit URLs exist. It does not change the decision: they are Apple-only, the xcframework would add a second binary-target mechanism next to our SE-0482 bundle, and the source tarball is trimmed sources whose `build.zig.zon` still points at `https://deps.files.ghostty.org/…` (uucode etc.), so Zig still fetches dependencies. **Keep building our own bundle.**

**When this changes:** the maintainer's schedule is "final pass over the C API, break ABI one more time, then likely tag a libghostty 1.0 release very soon" and "I'm confident we will [tag a libghostty release] before Ghostty 1.5" (release notes, "Libghostty" and "Roadmap"); Ghostty 1.5 is planned for March 2027 and libghostty "will have a separate release cycle". On HN he says "tagging libghostty 1.0 in the next few months and declaring ABI stability at that point" ([comment 50262760](https://news.ycombinator.com/item?id=50261998)). Even then I would expect source tags only, not Linux/Windows binaries. [INFERENCE]

### Q3. The Swift bindings

#### What the maintainer actually said

The HN comment lists "bindings in pretty much every popular programming language: C, Zig, Go, Swift, Python, Rust, .NET, etc." The release notes narrow it to "the Zig, C, C++, Swift, and WebAssembly **examples** (now over 30)". What exists, as far as I can find:

- **In ghostty-org:** `example/swift-vt-xcframework/` only: a SwiftPM executable (tools 5.9, `.macOS(.v13)`) with `.binaryTarget(path: "../../zig-out/lib/ghostty-vt.xcframework")` and a 40-line `main.swift` calling the C API (`ghostty_terminal_new`, `ghostty_terminal_vt_write`, the formatter). Not a library; Apple only. The org has 6 repos (`ghostty`, `ghostling`, `website`, `discord-bot`, `zig-gobject`, `.github`), none a Swift package. [GitHub org listing]
- **Mitchell's own:** only `go-libghostty` (now a mirror; source of truth on tangled.org).
- **[awesome-libghostty](https://github.com/Uzaaft/awesome-libghostty):** Swift entries are `GhosttyKit` (briannadoubt), `libghostty-spm` (Lakr233) (both GhosttyKit.xcframework, Apple GUI embedding), `Termini` (a SwiftUI terminal surface), and `shade` (a neovim-centric library). No VT-only Swift binding is listed.
- **Found beyond the list:** [`caelyreth/libghostty-vt-spm`](https://github.com/caelyreth/libghostty-vt-spm) ("Boring wrapper of `libghostty-vt`"). This is the only Swift-native libghostty-vt binding I found. `docs/research/libghostty-vt-distribution.md:71` ("None ships the VT-only library") is therefore out of date.

Which Swift binding Mitchell meant is [UNVERIFIED]; the evidence suggests the example plus community packages.

#### `caelyreth/libghostty-vt-spm` vs Tessera's `CGhosttyVT` + wrapper

Observed from README, `Package.swift`, `GhosttyVt.config`, tags, releases, commit log (not built or run here).

| Dimension | libghostty-vt-spm | Tessera today |
| --- | --- | --- |
| Maintainer / health | One individual ("Copyright © 2026 Yu"), MIT, 0 stars, 0 forks. First release 2026-07-08; last push 2026-07-25. Tags `0.1.0`-`0.2.1` only; `Package.swift` on `main` says `releaseVersion = "0.3.0"` but no `0.3.0` tag or release exists. | Us, with the update guide (`docs/guides/updating-ghostty-vt.md`) |
| Ghostty pin | `35e1a0160…` (2026-07-09, `GhosttyVt.config:3`); binary artifact `0.2.1`. **3.5 months and 122 header-touching commits behind our pin.** Its `terminal.h` has none of `GHOSTTY_TERMINAL_OPT_MODE`, `GHOSTTY_TERMINAL_OPT_MODE_DEFAULT` or `ghostty_terminal_vt_write_until` (grep at that commit), and the Kitty animation commit `a88ad03e6` (Aug) is not in its history. | `f54340ad…` (2026-10-21) |
| Platforms | `.iOS(.v17), .macOS(.v14), .macCatalyst(.v17)`. Binary target is an **XCFramework** (SE-0272: Apple only). **No Linux, no Windows.** | macOS 26 floor (`Package.swift:12-13`); SE-0482 bundle with 7 variants: macOS universal, glibc and musl for Linux x86_64/aarch64, Windows x86_64/aarch64 (`docs/architecture/libghostty-vt-distribution.md:12`) |
| Version pinning for consumers | By SwiftPM tag, but the tag controls the wrapper; the Ghostty pin lives in `GhosttyVt.config` and the XCFramework in release `0.2.1`. | Exact commit file + checksum-pinned bundle URL (`Package.swift:227-231`) |
| Coverage of what we use | On paper broad: frames with per-cell text/style/width, grapheme handling, Kitty graphics snapshot with placement `gridBounds` and optional PNG decoding (`GhosttyVtGraphics`), key/mouse/paste/focus input, ANSI/DEC mode read/write, query policy and `writeToPty` events, hyperlink lookup, selection, export. [UNVERIFIED in code; I did not read the implementation.] | Exactly what the harness needs: terminal new/resize/write, render-state cell and cursor reads, Kitty images and placements, Kitty key encoder (39 C functions and 68 constants across 3 files: `VirtualTerminal+Ghostty.swift`, `GhosttyKeyEncoder.swift`, `VirtualTerminalError.swift`) |
| API shape | Swift-native facade, `Terminal` is `Sendable`, returns copied frames; a `GhosttyVtRaw` product re-exports the C API. Policy decisions (query policy, APC limits) baked in. | `VirtualTerminal` dependency client; Ghostty stays private (guide: "Do not expose Ghostty types from public Tessera modules", `docs/guides/updating-ghostty-vt.md:89`) |
| Our artifact bundle | Not usable: it ships its own XCFramework for its own pin. We would still need the bundle for Linux and Windows, so we would run two distribution mechanisms. | The only mechanism |
| Swift toolchain | tools 6.0, Swift 6 mode: compatible. | tools 6.3 |

**Recommendation: do not adopt.** It fails the hard requirement (Linux and Windows harness, `docs/research/windows-libghostty-vt-snapshot-spike.md`), lags our pin, and has a bus factor of one. The `GhosttyKit` packages (Lakr233, sethdeckard, termio-sh, …) remain the wrong layer for the reasons in Q1: full surface API, Apple-only; the Lakr233 README says its `GhosttyKit` product "re-exports the libghostty C API (`ghostty.h`)".

**Revisit when:** (a) libghostty gets a 1.0 tag and an official Swift package or SE-0482-style multi-platform artifacts, or (b) a Swift binding ships Linux and Windows static libraries. Until then, borrow ideas (frame/width handling, the type-safe `GhosttyMode` wrappers) rather than depend on it.

### Q4. Everything else relevant

- **API stability.** The headers still say the API is "incomplete, work-in-progress… definitely going to change" (`include/ghostty/vt.h@v1.4.0:10-11`), and the 1.4 post says it "broke compatibility several times during this cycle, so expect more breaking changes before a tagged release." Churn is real: 122 commits touched `include/` between 2026-07-09 and our pin; 150 between our original pin (`ae52f97d…`, committed 2026-05-25) and today's. So **do not track `main`** before 1.0; our existing rule "pin an exact commit" (`docs/guides/updating-ghostty-vt.md:8,86`) is right. The next big move is the "final pass… break ABI one more time" before the 1.0 tag. Our blast radius for that is the 3 files and 39 functions above.
- **ABI manifest.** The pin exposes `ghostty_type_json()` (`include/ghostty/vt/types.h:418`), a versioned JSON manifest of every public struct layout/enum, plus upstream CI steps `test-lib-vt-schema`. Not needed today; it could back a cheap layout check on pin bumps. Note the header's own caveat: layouts "are not a cross-version stability promise".
- **Licensing.** Ghostty `LICENSE` is MIT (unchanged at v1.4.0). Embedded components are unchanged since the pin, so our notice table stands. The libghostty-vt build "no longer needs libc++" (release notes), which already matches our finding (`docs/research/libghostty-vt-distribution.md:104`).
- **Embedding guidance in the release notes.** CMake support, Nix packaging, an xcframework, a source tarball, and the pkg-config file; freestanding builds. Zig-example `build.zig` consumers can also depend on Ghostty as a Zig package (`is_dep` defaults to libghostty-vt-only, `Config.zig:86-93`). None of this replaces our CI-built bundle.
- **The linked HN sub-thread** ([comment 50263213](https://news.ycombinator.com/item?id=50261998)): a reader asked what "freestanding (no OS)" builds are for; Mitchell answered ("Yep, fun little demo") with an embedded-terminal demo link. Freestanding means no libc/OS dependency, which is consistent with our musl/Static-Linux-SDK variant; no action for Tessera. Other thread items: Mitchell's list of adopters (JetBrains terminals, Neovim "verbally accepted", Emacs Ghostel, KDE, Antithesis fuzzing finding "hundreds of bug fixes" in other terminals) is a maintainer claim [UNVERIFIED]; it is useful as a signal that libghostty-vt will get heavy outside testing before 1.0.
- **Kitty graphics context.** Ghostty 1.4 claims 100% of the Kitty graphics spec (animation, relative placements) and errors on invalid image data instead of staying silent. For Tessera apps this means `Frame.placeImage` behaves against a more conformant terminal; "retransmitting an image ID replaces the old image and removes its placements" (in our pin since #13723) means re-sending a still-placed image ID drops its placements. [INFERENCE: worth a glance at any Tessera flow that retransmits an ID while keeping the placement.]
- **OSC 7501 "program status"** (idle/working/done/blocked/failed) is parsed by libghostty-vt (`OPT_PROGRAM_STATUS` at `terminal.h:2766`; parser header cites `superlogical.com/rex/docs/build/program-status`). A candidate protocol for agent-style Tessera apps; no action now.
- **Ghostty GUI breaking changes in 1.4** (`copy-on-select`, macOS `cmd+↑/↓`, GTK keybinds, `scrollback-limit` rename) matter only to people using the app, not to our harness. The security advisories listed in the notes are GUI-side except #14857 (above).

### Local docs: what is now stale or wrong

The first, second, fourth, and last rows were corrected in the change that added this record: [libghostty-vt distribution](libghostty-vt-distribution.md) carries dated corrections at its `tip` and Swift-package findings, [Updating Ghostty VT](../guides/updating-ghostty-vt.md) says when the pin moves, and plan 036's Decision 9 entry names the `-r2` release. The Windows spike record is left as written.

| Where | Claim | Status |
| --- | --- | --- |
| `docs/research/libghostty-vt-distribution.md:71` | "None [of the Swift packages] ships the VT-only library" | Wrong: `caelyreth/libghostty-vt-spm` does (Apple-only). Conclusion unchanged. |
| same, `:44` | `tip` assets replaced in place, so not pinnable | Half-true: GitHub `tip` is; `tip.files.ghostty.org/<commit>/…` per-commit blobs exist. |
| same, `:47-50` | README says untagged and in flux | Re-verified at `v1.4.0` (`README.md:157-170`). |
| `docs/guides/updating-ghostty-vt.md:14` | "Prefer a released tag commit once the libghostty-vt APIs Tessera uses are stable in a Ghostty release" | Still the right rule, but its trigger is now concrete: `v1.4.0` is a *Ghostty* tag; the *libghostty* tag is promised before Ghostty 1.5. Worth a sentence. |
| `docs/research/windows-libghostty-vt-snapshot-spike.md:20-22` | Windows "promising but unverified"; GUI Windows "not committed" | Resolved upstream: libghostty "fully supports Windows… tested in CI"; GUI roadmap dropped. |
| `docs/research/ghostty-vt-harness-spike.md`, `…snapshot-harness-closeout.md` | Zig 0.15.2, pin `ae52f97d…`, `.build/libghostty-vt/current` | Historical records of superseded setup; fine as they are (status resolved). |
| Brief / `Package.swift:230` | Release `ghostty-vt-f54340ad7781` | The manifest points at `…-r2` (`Package.swift:230`). |

### Recommendations for Tessera

Ordered by value. None needs a pin change except #4, and #4 is optional.

1. **Slice 7 (Q19, mode 2027): enable the mode in the headless terminal with the existing API.**
   - *What:* in `GhosttyTerminalState.init` (`VirtualTerminal+Ghostty.swift:35-72`), after `ghostty_terminal_new`, call `ghostty_terminal_set(terminal, GHOSTTY_TERMINAL_OPT_MODE_DEFAULT, &GhosttyTerminalModeConfig(mode: ghostty_mode_new(2027, false), value: true))` (`terminal.h:2559,2170-2176`; `modes.h:93,118`). Use `_MODE_DEFAULT`, not `_MODE`, so a full reset (RIS) keeps it (`terminal.h:2546-2559`); an app's own `CSI ? 2027 l` still turns it off. Also add a read accessor with `GHOSTTY_TERMINAL_DATA_MODE` (`terminal.h:3146`) so session tests can assert "2027 enabled after a DECRQM reply, restored on exit and suspend" from terminal state rather than byte matching (the verify text at `docs/plans/phase-4-view-layer-and-developer-tooling.md:130`).
   - *Why:* the plan says "the headless virtual terminal enables mode 2027" (`:128`, `:313`, `:359`); upstream has first-class API for it, and mode 2027 is *off by default* (`src/terminal/modes.zig:403` sets no `.default`, and the field defaults to `false` at `:324`), which is why `👩🏽‍💻` measured 6 cells (`:359`).
   - *Gotcha:* `GHOSTTY_MODE_GRAPHEME_CLUSTER` is a macro that calls an inline function; Swift usually does not import such macros, so call `ghostty_mode_new(2027, false)` directly. [INFERENCE; confirm when implementing.]
   - *Cost:* about 30 lines plus one test. No pin bump.

2. **Slice 9 (`RenderedCell.width`): read the wide flag from the pinned API.**
   - *What:* fetch the raw cell with `GHOSTTY_RENDER_STATE_ROW_CELLS_DATA_RAW` (`render.h:1447`) and read `ghostty_cell_get(raw, GHOSTTY_CELL_DATA_WIDE, …)` (`screen.h:104-113,168,336`): `NARROW`=1, `WIDE`=2, `SPACER_TAIL`=continuation, `SPACER_HEAD`=soft-wrap spacer. Add `width` to `RenderedCell` (`RenderedCell.swift:19-29`) and drop the "blank after a width-2 grapheme is its continuation" rule (`docs/plans/…:302`).
   - *Why:* today `currentCellCharacter()` returns `" "` for any cell with no grapheme data (`VirtualTerminal+Ghostty.swift:608-610`), so spacers and blanks look identical; the plan already calls for Ghostty's flag (`:140`, `:302`).
   - *Same change, small extra:* `RenderedCell.hyperlinkURI` exists and the snapshot renderer prints `link=` (`VirtualTerminalSnapshotting.swift:79-111,249`), but the Ghostty wrapper never sets it (`VirtualTerminal+Ghostty.swift:583-596`). The pin offers `GHOSTTY_CELL_DATA_HAS_HYPERLINK` (`screen.h:196`) and `ghostty_grid_ref_hyperlink_uri` (`grid_ref.h:187`). Decide whether to wire it with the width work; only buffer-level tests use `link=` today (`Tests/TesseraTerminalBufferTests/BufferTests.swift:314`).
   - *Cost:* small to medium (two more FFI reads per cell on the snapshot path). No pin bump.

3. **Width-table oracle test (Slice 7 verify, optional).** Compare Tessera's width table with `ghostty_unicode_codepoint_width` / `ghostty_unicode_grapheme_width` (`unicode.h:69,144`), which "exactly match" the terminal's table with 2027 on and are Unicode 18 in our pin. A corpus of ZWJ, regional-indicator, VS15/VS16, CJK and combining sequences would catch width-table drift automatically. *Cost:* small; test-only; fits Q19's "`👩🏽‍💻` takes 2 cells" check.

4. **Move the pin to `83fb95624b0439ee660c2679b43b38c8b63769cd` (`v1.4.0`), optional chore.**
   - *Why:* a named, signed-tag pin instead of a mid-week `main` commit; picks up the APC-discard semantics and the #14857/#14856/#14838 memory-safety fixes; no Zig, licence or API change (2a). Do it before the next batch of harness work and **before** libghostty's own tag/ABI break, so the later bump is a clean one.
   - *Cost:* one pin-bump PR following `docs/guides/updating-ghostty-vt.md` steps 1-8: version file, `--update-headers` (two comment-only header diffs), local bundle tests on macOS, Lima and Windows, tag `ghostty-vt-83fb95624b04`, URL and checksum in `Package.swift:227-231`. Expected code change: none. Release the bundle only after the three local runs pass.
   - *Slice:* chore; best landed with Slice 7 since that slice already edits the wrapper and needs a bundle rebuild check.

5. **Docs-only corrections** (no slice; ride with the pin bump or Slice 20): the three rows above in `docs/research/libghostty-vt-distribution.md`, one sentence at `docs/guides/updating-ghostty-vt.md:14` ("`v1.4.0` is a Ghostty tag; take libghostty's own first tag when it exists, expected before Ghostty 1.5, March 2027"), and the `-r2` tag name. *Cost:* minutes.

6. **Do not adopt Swift bindings or GhosttyKit packages; do not chase `main`.** *Revisit* when libghostty 1.0 is tagged or a Swift binding ships Linux and Windows (see Q3). *Cost:* none.

7. **Not recommended now, noted for later.**
   - Replace the hand-written `TerminalAnswerer` (`Sources/TesseraHarness/TerminalAnswerer.swift:12-60`, parses OSC 4/10/11 and DA1 by hand) with libghostty-vt's own query replies (`GHOSTTY_TERMINAL_OPT_WRITE_PTY`, `…_COLOR_FOREGROUND/BACKGROUND/PALETTE`, `…_DEVICE_ATTRIBUTES`, `…_COLOR_SCHEME`; handlers at `src/terminal/stream_terminal.zig:780-782,2092-2251@v1.4.0`, which also answer DECRQM and the Kitty keyboard query `CSI ? u`). Better fidelity, but it needs C callbacks, userdata plumbing, and care with the rule that effect callbacks must not call `ghostty_terminal_vt_write` on the same terminal (`terminal.h:79-82`). Reconsider only if Slice 1's colour round or Slice 7's probe needs more queries answered than the hand parser handles.
   - Try dropping `-Dsimd=false` on Windows and trimming the build with `-Dvt-features=` (2d). Neither is needed for correctness.

### Evidence log

- HN thread and the maintainer comment: <https://news.ycombinator.com/item?id=50261998> (full tree via the Algolia API, saved at `/tmp/ghostty14/hn.txt`). Linked comment `50263213` replies to `50262760` (mitchellh).
- Release notes 1.4.0: <https://ghostty.org/docs/install/release-notes/1-4-0> (sections Security, Terminal Capabilities, Changes for Package Maintainers, Libghostty, Roadmap).
- libghostty API docs: <https://libghostty.tip.ghostty.org/>. Upstream clone at `/tmp/ghostty14/ghostty` (blobless; tags `v1.3.1`, `v1.4.0`; `origin/main` fetched).
- Commits are `https://github.com/ghostty-org/ghostty/commit/<sha>`: `f54340ad77814fe319d136e5e915d6a48de8dd23` (pin), `83fb95624b0439ee660c2679b43b38c8b63769cd` (v1.4.0), `e257bb45e`, `9cac2bd0c`, `a6a1a4664`, `802665102`, `3079a4396`, `68640f304`.
- Commit-addressed artifacts: `https://tip.files.ghostty.org/f54340ad77814fe319d136e5e915d6a48de8dd23/libghostty-vt-source.tar.gz` (downloaded to `/tmp/ghostty14/pin-vt-src.tar.gz`; `diff -rq` of its `include/ghostty` against `Sources/CGhosttyVT/include/ghostty`: 0 differences).
- Swift packages: <https://github.com/caelyreth/libghostty-vt-spm> (Package.swift, GhosttyVt.config, tags, releases, commits saved under `/tmp/ghostty14/vtspm/`), <https://github.com/Lakr233/libghostty-spm>, <https://github.com/Uzaaft/awesome-libghostty>, `example/swift-vt-xcframework` at `v1.4.0`.
- Not done: building or running any Swift binding, building v1.4.0 libghostty-vt on any platform, running Tessera's tests.

## Conclusion

1. **Tessera's use is current.** It uses `libghostty-vt`, which is the only part of the libghostty family that upstream documents for external embedders. The pin (`f54340ad7781…`, 2026-10-21, `scripts/ghostty-vt-version.txt:1`) is an ancestor of `v1.4.0`, 73 commits behind it, six days older. Between them the public C headers changed in two files, 11 comment lines. The C binding code, the render-state code, the build glue and the third-party packages did not change at all.
2. **Nothing in 1.4 forces a change.** Almost all of the 1.4 VT work (Kitty animation, relative placements, Unicode 18, mode 2027 fixes, DECSTR, key-encoding fixes, scrollback compression) was already in the pin. Moving the pin to the `v1.4.0` commit is a cheap, no-code-change chore that buys a named pin and three small post-pin fixes. It is optional.
3. **There is still no stable libghostty-vt tag and no Linux/Windows binary.** The maintainer says he will do a "final pass over the C API, break ABI one more time" and then "likely tag a libghostty 1.0 release very soon", and is "confident" a libghostty release lands before Ghostty 1.5 (planned March 2027). Our artifact bundle stays.
4. **Do not adopt a Swift binding.** The only VT-only Swift package I found (`caelyreth/libghostty-vt-spm`) is Apple-only, pinned to a July Ghostty commit, one maintainer, no Linux or Windows. Upstream's own "Swift" artifact is a 40-line example.
5. **Two plan items need no pin change at all.** Slice 7's mode 2027 and Slice 9's wide flag are both already in our vendored headers. Both are small wrapper changes (details in Recommendations).

The owner decided on 2026-10-27, after reading this review, not to move the Ghostty pin until libghostty-vt has its own 1.0 tag; the optional move to the `v1.4.0` commit (Recommendations, item 4) is therefore not taken.
