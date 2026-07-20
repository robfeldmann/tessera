# Contributing to Tessera

Thanks for your interest in Tessera. This guide covers how to talk to the project, set up
a development environment, and land a change that passes the quality gate.

Tessera is pre-1.0 and not ready for production use. The view and application-programming
layer has no stable public API yet. Read [Project status](docs/ProjectStatus.md) for
supported platforms, the roadmap, and documentation boundaries before proposing work.

By participating you agree to the [Code of Conduct](CODE_OF_CONDUCT.md).

## Talk first

Tessera is early and maintainer-led, so alignment before code saves everyone time.

- **Questions, ideas, and proposals** →
  [start a Discussion](https://github.com/robfeldmann/tessera/discussions). Include the
  motivation, alternatives considered, expected benefit, and any examples or mockups.
- **Reproducible bugs** → confirm the behavior in a Discussion first when practical, then
  [open an Issue](https://github.com/robfeldmann/tessera/issues) with a clear title, exact
  reproduction steps, expected vs. actual behavior, environment (Swift version, platform,
  Tessera revision), and logs or snapshots if relevant.
- **Pull requests** → only after a Discussion reaches agreement on the problem and
  direction. Unsolicited PRs will be asked to start with a Discussion.
- **Security-sensitive reports** → do not post them publicly. A private reporting path
  will be established before public launch.

## Prerequisites

- Swift 6.3 or later
- Xcode 26 or later (macOS development and DocC validation)
- [`just`](https://github.com/casey/just),
  [swift-format](https://github.com/apple/swift-format), and
  [SwiftLint](https://github.com/realm/SwiftLint) for the quality gate
- Node.js 24.14.0 (repository-local Markdown and configuration tooling)
- Python 3 (repository-local spelling tool and local documentation previews)

SwiftLint and DocC validation are macOS/Linux-native; run quality checks and `xcrun docc`
there or in CI, not on Windows.

## Setup

[Homebrew](https://brew.sh/) is the recommended way to install the macOS tool set. A
`Brewfile` installs everything at once:

```sh
brew bundle install        # or install the tools above individually and put them on PATH
```

Then bootstrap the repository-local tooling and git hooks:

```sh
npm ci                     # pinned Prettier + markdownlint
just setup quality-tools   # pinned codespell environment
just setup hooks           # Lefthook: non-mutating staged + Conventional Commit checks
```

Optional platform tooling for cross-platform testing:

- [Lima](https://lima-vm.io/) — Docker-free Linux test runs.
- [UTM](https://mac.getutm.app/) — Windows GUI VM on Apple silicon.
- [QEMU](https://www.qemu.org/), swtpm, and sshpass — scripted Windows VM runs with Frost.

## The development loop

Recipes are grouped by area; run `just` to list every module and command. The fastest
inner-loop commands while editing:

```sh
just core build            # build the package (prepares libghostty-vt first)
just core test             # full Swift test suite (non-parallel)
just core showcase         # run the Tessera Showcase example
```

Run the narrowest relevant check first, then widen:

```sh
swift test --filter TesseraTerminalTests   # focused tests
just quality changed                        # strict checks on changed files only
```

### The quality gate

Before opening a PR or handing work off, run this gate in order and make every step pass —
focused checks alone are not sufficient:

```sh
just quality format        # 1. auto-apply SwiftLint --fix, swift-format, and markup formatting (mutates)
just core test             # 2. the complete Swift test suite
just quality lint          # 3. strict format, lint, Markdown, spelling, wireframe, and architecture checks
```

Steps 2 and 3 are bundled as `just ci check` if you prefer one command. On macOS, also run
`just docs lint` when DocC or reference documentation changes (DocC validation is
macOS-only). After editing Markdown, validate it with `npm run check:markup <path>`.

Only `just quality format` (and `just quality spelling-fix`) mutate files — review their
diffs. Committing everything the formatter touches is fine, including formatter-only
changes. Hooks run non-mutating checks only and never autoformat.

If a checkout or worktree behaves unexpectedly, run `just core doctor` and see
[Local development state](docs/LocalDevelopmentState.md), which explains which artifacts
are per-checkout, machine-global, or VM-local.

## Pull request workflow

1. Reach agreement in a Discussion.
2. Fork and branch (`git checkout -b feat/short-description`).
3. Make the change with tests and documentation.
4. Pass the [quality gate](#the-quality-gate).
5. Commit using [Conventional Commits](https://www.conventionalcommits.org/) — the same
   policy is enforced locally and in CI (`feat: add focus routing`,
   `fix: restore modes on SIGHUP`).
6. Push and open a PR describing intent, user-visible behavior, validation performed, and
   any compatibility or breaking-change notes. Do not include secrets.

PR titles must use Conventional Commit style.

## Changelog and commit tools

[`CHANGELOG.md`](CHANGELOG.md) is the canonical release history. Add one entry for each
notable user- or contributor-visible change under `Unreleased`. Use only these headings:
`Breaking Changes`, `Added`, `Changed`, `Deprecated`, `Removed`, `Fixed`, and `Security`.
Choose the heading by effect rather than commit type; documentation and tooling changes
belong under the standard heading whose behavior they affect. Omit internal planning and
mechanical changes.

Each entry must be a concise, self-contained bullet on one physical line. Prettier
deliberately ignores the changelog because the supported commit tools rebuild `Unreleased`
with different valid blank-line layouts. A file-level Markdownlint directive allows either
layout while all other Markdown rules remain enforced.

`omp commit` and [`lgit`](https://github.com/can1357/llm-git) can generate a Conventional
Commit message and update the changelog. The `Brewfile` installs `lgit`; it is optional,
and neither changelog formatting nor linting requires an API credential. For Tessera, set
the following non-secret option in the configuration passed to `lgit`:

```toml
changelog_revise = false
```

This prevents an unrelated commit from revising established release-note wording. Use
`omp commit --no-changelog` or `lgit --no-changelog` when a change is not notable or when
you have already staged its entry. A dry run previews only the commit message in the
supported `lgit` version; it does not exercise changelog updates.

Release-note labels are `breaking-change`, `enhancement`, `bug`, `documentation`,
`dependencies`, and `maintenance`. Apply `skip-release-notes` only to changes that should
not appear in GitHub-generated notes. These labels control the generated GitHub release
presentation; they do not add headings to the canonical changelog.

## Coding standards

Match the surrounding code and the repository conventions:

- **Formatting**: 2-space indentation, no tabs; 90-character soft limit, 150-character
  hard limit; trailing commas in multi-line arrays and dictionaries. `just quality format`
  is authoritative — prefer it over hand-fixing individual findings.
- **Ordering**: imports sorted alphabetically; properties sorted alphabetically within
  their visibility group; protocol conformances sorted alphabetically (e.g.
  `Equatable, Sendable`).
- **Naming**: follow the Swift API Design Guidelines — camelCase for values and functions,
  PascalCase for types.
- **Comments and docs**: document public APIs. Comments and DocC describe enduring
  behavior, ownership, and invariants — never plan/phase/slice/step numbers, temporary
  delivery status, or future timing. Roadmap sequencing belongs in planning and spec
  documents only.
- **Platform divergence**: confine `#if os(...)` to leaf seams — a single syscall/import
  shim, small typed platform values, or whole-file source splits in `Package.swift`. Keep
  shared logic and call sites platform-free.
- **Concurrency**: Swift 6 language mode with strict concurrency. Prefer structured
  concurrency and actors for shared mutable state. Do not blanket-apply `Sendable` to
  silence warnings — non-sendability is a feature when it prevents invalid cross-domain
  use.

## Testing

- Write tests with [Swift Testing](https://developer.apple.com/documentation/testing),
  using backticked, sentence-style function names, e.g.
  ``@Test func `restores modes on SIGHUP`()``.
- Prefer snapshots for structured state a human inspects as a whole (graph dumps, layout
  trees, buffers, styles, rendered output). Prefer direct `#expect`/`#require` assertions
  for small scalar values, API-shape checks, and identity/lifetime relationships.
- Keep tests deterministic and isolated: explicit input scripts, injected clocks, and
  bounded drains — never `Task.yield()` or wall-clock sleeps to "let the UI catch up."
  Tests must be safe under the full parallel suite.
- Cover edge cases and error conditions, and test behavior and invariants rather than
  incidental defaults or plumbing.

## Cross-platform testing

CI runs the full suite on macOS, Linux, and Windows with Ghostty-backed snapshot coverage.
Locally you can validate other platforms from macOS.

### Linux

Compile-check against the Static Linux SDK without a VM (does not run tests):

```sh
just linux install-sdk     # SDK metadata is pinned in scripts/config/swift-sdks.json
just linux build
```

Run the Linux test suite in a [Lima](https://lima-vm.io/) VM (Ubuntu 24.04, no Docker):

```sh
just linux start           # create/start the VM; set TESSERA_LINUX_VM_NAME for parallel worktrees
just linux test            # full Linux suite from macOS
just linux test -- --filter PlatformHandlesTests   # focused; keeps --jobs 2 --no-parallel
just linux stop            # then `just linux delete` for a fresh environment
```

### Windows

Windows on Apple silicon has two supported workflows — see the guides for first-time
setup, SSH configuration, GUI validation, and troubleshooting:

- **Scripted (recommended):** [Windows VM with Frost](docs/WindowsFrostVM.md).
- **Manual desktop:** [Manual Windows VM with UTM](docs/WindowsVM.md).

The normal Frost loop builds the pinned Windows `libghostty-vt` artifact once per pin,
then runs the Ghostty-backed suites against disposable overlays:

```sh
just windows-frost start
just windows-frost build-ghostty   # re-run after bumping scripts/ghostty-vt-version.txt
just windows-frost stop
just windows-frost test            # add `-- --filter WindowsInputLoopTests` to focus
```

For manual GUI validation, run a Tessera demo in each host you support — Windows Terminal
(PowerShell), PowerShell in classic conhost, and `cmd.exe` — and verify arrow keys, `q`
clean exit, `Ctrl-C` cleanup, resize-driven redraw, and terminal restoration (prompt
returns with normal echo, a visible cursor, and the primary screen active).

To spend fewer hosted CI minutes: validate locally before pushing, keep the `skip-ci`
label on draft PRs until a hosted run is needed, push one fixup commit per attempt so
concurrency cancels obsolete runs, and rerun only failed jobs.

## Terminal lifecycle verification

Terminal lifecycle, signal-handling, and renderer changes need manual verification in a
real terminal in addition to unit tests. Use two panes — one running a fixture, one
sending signals:

```sh
swift run --package-path Examples LifecycleModesDemo   # pane 1
pgrep -fl LifecycleModesDemo && kill -TERM <pid>       # pane 2
```

Verify before merging such changes:

- `Ctrl-C` returns the shell with normal echo and the primary screen visible.
- `SIGTERM` (and, if practical, `SIGHUP` via closing the pane) restores the terminal.
- Repeated resizes keep the fixture responding and repainting the full screen.
- Interrupting an active redraw leaves no half-rendered frame in supported terminals, and
  unsupported terminals still recover modes and the primary screen.
- After an injected write/flush failure, the next successful draw repaints conservatively
  rather than trusting partially written damage bytes.

If a development build ever wedges your terminal, use the recovery commands in the
README's [Terminal recovery](README.md#terminal-recovery) section.

## Source-release checklist

Tessera releases source only from `main`. The first public release is `v0.1.0`; subsequent
tags use `v<SemVer>`. Before 1.0, increment the minor version for breaking API changes or
substantial new capability and the patch version for backward-compatible fixes. Never move
or reuse a tag that has been published.

The dated version section in `CHANGELOG.md` is the canonical GitHub Release body and the
content delivered to release-feed subscribers. `scripts/release_notes.py` extracts that
section without rewriting it, adds a link to the tagged changelog, and fails on missing,
duplicate, empty, wrapped, unsupported, or out-of-order content. GitHub-generated notes
are appended afterward as supplementary pull-request links and contributor attribution.

For each release:

1. Start from an up-to-date, clean `main` checkout and choose the SemVer version.
2. Confirm the proposed tag is absent locally and remotely with
   `git tag --list v<version>` and `git ls-remote --tags origin refs/tags/v<version>`.
3. Finalize `CHANGELOG.md`: replace `Unreleased` content with a dated `[<version>]`
   section, add a new empty `[Unreleased]` section, and update comparison links. For the
   first release, compare `Unreleased` from `v0.1.0`; for later releases, link the new
   version to the previous tag.
4. If the release contains `Breaking Changes`, put reviewed migration guidance directly in
   that changelog section so the extracted release body and RSS/Atom entry include it.
5. Update the README dependency example from `main` to the exact released version and add
   or refresh a release badge only after its destination exists.
6. Run `python3 scripts/release_notes.py v<version>`, inspect `.build/release-notes.md`,
   and confirm every category and bullet exactly matches the dated changelog section.
7. Run `just quality format`, the complete `swift test`, and `just quality lint`, in that
   order. Run `just docs lint` when reference documentation changed.
8. Merge the finalized release changes to `main`, then create an annotated tag with
   `git tag -a v<version> -m "Tessera v<version>"`.
9. Push only the tag, then immediately verify that a fresh external Swift package resolves
   the tagged dependency declaration shown in the README.
10. Run the **Draft release** workflow with the existing tag. It checks out the immutable
    tag, regenerates `.build/release-notes.md`, and creates or updates a draft titled
    `Tessera v<version>`. The curated changelog text remains first;
    [`.github/release.yml`](.github/release.yml) controls the generated pull-request list
    appended beneath it.
11. Review the rendered draft for exact changelog wording, migration guidance, PR
    categories, contributor attribution, comparison links, and Markdown layout. The
    workflow must never publish automatically.
12. Publish only after the tag, comparison links, draft body, generated notes, and
    anonymous package resolution all pass. Verify the release page, README links, and the
    release's entry in `https://github.com/robfeldmann/tessera/releases.atom` after
    publication.

Any failed check is a release hold. Before tagging, fix the release commit and rerun the
gate. After a tag is visible remotely, do not force-move it: keep the release unpublished,
fix `main`, and choose a new SemVer version. After publication, correct the problem with a
new release rather than rewriting published history.

## Review process

All submissions require review. Reviewers check correctness and completeness, adherence to
the coding standards above, test coverage, documentation, and performance implications.

## License

By contributing, you agree that your contributions will be licensed under the
[Apache License 2.0](LICENSE).
