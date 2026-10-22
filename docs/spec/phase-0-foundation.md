---
type: spec
description: "Phase 0: Foundation"
---

# Phase 0: Foundation

Phase 0 has exactly one job: **prove your development loop works before you write anything interesting.** That's it. Every minute you spend in Phase 0 is a minute you're not learning about terminals, so the goal is to get _out_ of Phase 0 as fast as possible while still having a foundation you won't have to rebuild.

A useful test: when you finish Phase 0, you should be able to say "I can edit a Swift file, run `swift test`, see it pass locally, push to GitHub, see CI pass on three OSes, and generate DocC — all without thinking about it." If any of those friction-causes you, Phase 0 isn't done. If all of them are smooth, Phase 0 _is_ done, even if your library does literally nothing yet.

## Repo and package structure

- [x] Git repo initialized
- [x] `Package.swift` with two library products declared: `TesseraTerminal` and `Tessera` plus associated test targets.
- [x] A Phase 0-only bootstrap public symbol in each module so each product exports _something_ and DocC has something to render. This is the explicit bootstrap exception: delete these as soon as a target has real API.
- [x] A trivial test per target that imports the module and asserts on the bootstrap symbol, proving the test target is wired correctly
- [x] Swift 6 strict concurrency settings
- [x] Formatting (swift-format?) and linting (SwiftLint?) configured
- [x] DocC generation configured
- [x] `README.md` with the pitch
- [x] A `CONTRIBUTING.md` or equivalent if you want one, though this can wait
- [x] GitHub Actions matrix running `swift build` and `swift test` on macOS, Ubuntu, and Windows

## Setup Github CI

For Phase 0 done, the matrix needs `swift build` and `swift test` passing on:

- **macOS** — latest runner, Swift 6.x toolchain (whatever ships with current Xcode)
- **Ubuntu** — latest LTS, official Swift toolchain
- **Windows** — Server 2022 runner, official Swift toolchain

The Windows one is the one most likely to bite you. Swift on Windows has matured a lot but SwiftPM behavior, path handling, and toolchain installation still have rough edges compared to Apple platforms. Worth getting it working _now_ with an empty package, because debugging "why doesn't my termios shim compile on Windows" is much harder when CI itself is also broken.

### Concrete workflow shape

A minimal `.github/workflows/ci.yml` that I'd suggest for Phase 0:

```yaml
name: CI
on:
  push:
    branches: [main]
  pull_request:

jobs:
  test:
    strategy:
      fail-fast: false
      matrix:
        os: [macos-latest, ubuntu-latest, windows-latest]
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4
      - uses: SwiftyLab/setup-swift@latest
        with:
          swift-version: "6.1" # or whatever your Package.swift requires
      - run: swift build
      - run: swift test

  lint:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - run: swift format lint --recursive --strict Sources Tests
      # plus SwiftLint if you're using it

  docs:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - run: swift package generate-documentation --target Tessera
      - run: swift package generate-documentation --target TesseraTerminal
```

`fail-fast: false` is important — when Windows breaks, you want to see whether Linux and macOS still pass, not have the whole matrix abort.

### A note on `SwiftyLab/setup-swift`

It's the de facto community action for installing Swift toolchains across all three OSes. Apple doesn't ship an official one. There's also `swift-actions/setup-swift` which is older and less maintained. Either works; `SwiftyLab` is the safer current choice as of 2026.

### Things to consciously _not_ do in Phase 0 CI

- **No release builds.** `swift build -c release` is slower and you don't need it yet.
- **No code coverage.** Adds setup time, irrelevant when you have one bootstrap wiring test.
- **No DocC _publishing_.** Generating in CI is fine (it catches broken doc comments early); deploying to Pages can wait until you have something worth documenting.
- **No caching.** Tempting, but premature. The build is empty; there's nothing to cache. Add it in Phase 2 when builds get slow.
- **No branch protection rules requiring green CI.** Set those up _after_ you've seen the matrix go green at least once organically.

## What "Phase 0 done" looks like, concretely

When you can do all of the following without thinking, Phase 0 is done:

1. `git push` to main, CI runs and goes green on macOS + Linux + Windows within ~5 minutes.
2. `swift test` locally produces a passing test (the bootstrap wiring test).
3. `swift package generate-documentation` produces DocC output without warnings.
4. `swift format lint` exits 0.
5. A new contributor (or future-you on a new machine) can clone, run `swift test`, and have it work.

If any of these are not yet smooth, that's the work. If all of them are smooth, **stop and move to Phase 1.** Don't gild Phase 0.

## A heads-up about a likely Windows snag

When you do push and Windows CI runs for the first time, the most common failure is one of:

- **Toolchain install timing out** — sometimes the Swift Windows installer is slow. Usually fixes itself on retry; not a real problem.
- **Path separator issues in `Package.swift`** — unlikely with a fresh package, but if you've hand-written any paths with `/` they may misbehave. SwiftPM mostly handles this, but watch for it.
- **Line ending issues** — if your repo doesn't have a `.gitattributes` enforcing LF for `.swift` files, Windows may check out CRLF and confuse the toolchain. Worth adding:

  ```ini
  # .gitattributes
  * text=auto eol=lf
  *.swift text eol=lf
  ini
  ```

None of these are blocking; they're just the usual "first time on Windows CI" papercuts. If something else weird shows up, paste me the error and we'll work through it.

## Explicitly NOT in Phase 0

- ❌ No Ghostty / libghostty-vt integration
- ❌ No snapshot test harness
- ❌ No termios code
- ❌ No ANSI encoder
- ❌ No buffer type
- ❌ No view protocol
- ❌ Nothing that touches a terminal

---
