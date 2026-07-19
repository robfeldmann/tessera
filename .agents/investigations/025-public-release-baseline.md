---
name: Public Release Baseline
date: 2026-07-19
status: open
---

# Public Release Baseline

## Question

Can the repository at `2039f34303c297b9f33cbfc7717b6e7078902d99` safely become public, and
what contracts must later public documentation and automation follow?

## Findings

### Repository surface

- `HEAD` contains 510 tracked paths: the root Swift package and lockfile; the separate
  `Examples` package; `Sources`, `Tests`, `docs`, `design`, `scripts`, `justfiles`, and
  `.github`; project metadata; and tracked `.agents` plans and investigations. The DocC
  catalogs include 56 PNG/SVG icon and card assets.
- The ignored local/generated inventory is `.build/`, `.venv/`, `.windows-frost.env`,
  `Sources/CGhosttyVT/include/ghostty/`, `node_modules/`, and `scripts/__pycache__/`.
  `.gitignore` intentionally excludes the Frost local configuration, generated Ghostty
  headers, build outputs, caches, and machine-local IDE state.
- All SwiftPM dependencies resolve from public GitHub source-control URLs. The root
  lockfile pins `swift-custom-dump`, `swift-displaywidth`, `swift-docc-plugin`,
  `swift-docc-symbolkit`, `swift-snapshot-testing`, `swift-syntax`, `swift-system`, and
  `xctest-dynamic-overlay` to revisions. Ghostty is fetched separately from
  `ghostty-org/ghostty` at the revision in `scripts/ghostty-vt-version.txt`; its generated
  headers are ignored.
- Workflow execution inputs are public GitHub Actions, Homebrew, apt, npm, SwiftPM, Zig,
  and the local Ghostty build scripts. CI and documentation validation use only
  `contents: read`; checkout disables persisted credentials. Action pinning and
  fork-safety review belong to Phase 6.
- A tracked Frost VM password was hard-coded in two scripts and published in the Frost VM
  guide and historical planning material. It was introduced in two reachable commits. On
  2026-07-19, the current tree and its local Frost build input removed those copies and
  require an explicitly injected local credential; the static source search is clean.
- The owner rotated the Frost account, rebuilt and verified the Frost base and toolchain
  images, and deleted all three pre-remediation UTM images. This does not remediate local
  clones, GitHub PR views, or reachable Git history.
- This remains a public-release blocker until the credential is removed from every
  reachable Git ref and hosted artifact, then the rewritten remote is independently
  scanned and reviewed.
- `gitleaks git --no-banner --redact --log-opts=--all` scanned 90 commits and reported no
  leaks. Its failure to flag the known Frost credential makes that result insufficient as
  a clearance. Rerun an approved history-capable scanner after the rewrite and manually
  inspect all reachable refs, including plan history.
- Git history has one human author identity and Dependabot. The human commit identity
  includes an email address, so the repository owner must explicitly approve exposing that
  identity with the history.

### License and asset provenance

- Tessera is currently MIT-licensed with a generic `Tessera Contributors` copyright line.
  No `NOTICE`, contributor list, or ownership approval exists in the repository. The
  Apache-2.0 relicensing decision is therefore **not approved** by this audit.
- The resolved dependency checkout inventory contains MIT-licensed Point-Free,
  `swift-displaywidth`, and `swift-snapshot-testing` components, and Apache-2.0 components
  from the Swift and DocC projects. Verify the exact upstream notices and all transitive
  obligations at the pinned revisions before choosing whether a third-party inventory or
  `NOTICE` file is required. Do not add a `NOTICE` by convention.
- The 56 DocC card/icon assets have Pixelmator-generated source SVGs but no recorded
  author, source, license, font, template, or stock-art provenance. The owner must attest
  that Tessera can distribute each asset under Apache-2.0, or replace it.
- Ghostty source material is downloaded and used to build `libghostty-vt`; no upstream
  license text or attribution propagation is recorded. Verify the Ghostty license and
  required notice at the pinned revision before distribution. This is a likely
  attribution/notice input, not permission to add one yet.
- No tracked screenshots, photographs, or external logo assets were found. The supplied
  untracked logo image at `/Users/rob/Downloads/Tessera Logo.png` is not part of this
  audit and requires its own provenance attestation before Phase 3 adds it.

### Supported-platform and release contract

- **Supported distribution platform:** macOS 26 or later. This is the sole platform
  declared by both package manifests. The required toolchain is Swift 6.3; the repository
  pins Swift 6.3.2 and uses Swift language mode 6.
- **CI-only validation platforms:** Linux and Windows. The CI matrix builds and tests all
  three operating systems, with Windows enabling the Ghostty target through
  `TESSERA_GHOSTTY_WINDOWS=1`, but those runs do not make Linux or Windows supported
  SwiftPM platforms while the manifests declare only macOS.
- **Published products:** `Tessera`, `TesseraTerminal`, `TesseraTerminalSnapshotSupport`,
  `TesseraTerminalTestSupport`, and `TesseraTestSupport`. The examples are a separate
  macOS-only package with local-path dependency on the parent checkout; they are not
  released library products.
- **Release policy:** `main` is the release-capable default branch. The first public
  source release will be `v0.1.0`, created only after the Apache-2.0 baseline and release
  gate pass. Subsequent releases use immutable `v<SemVer>` tags and SemVer. No local tag
  currently exists; the owner must verify the remote tag and release inventory before
  public documentation or changelog links can claim `v0.1.0` exists.

### GitHub launch assumptions

- The configured origin is `https://github.com/robfeldmann/tessera.git`; GitHub reports
  the repository as private, with `main` as its default branch and the current viewer as
  an administrator.
- **Settings owner:** the `robfeldmann` repository owner. Before visibility changes, that
  owner must verify branch protection or rulesets and required checks, Actions permissions
  and runner availability, current billing/minutes policy, Pages and private
  vulnerability-reporting availability, Packages access, remote tags/releases, and whether
  Discussions, labels, CODEOWNERS, Projects, or sponsorship are actually maintained.
- This baseline makes no claim that public Actions or Pages are free for this account. It
  makes no claim that Swift Package Index registration or hosted documentation is active.

## Launch Decision

**HOLD — do not make the repository public.** The hold remains until the Frost credential
and its reachable history are remediated; the owner approves Apache-2.0 relicensing
authority, Ghostty attribution, and every DocC asset; the owner approves public commit
identity exposure; and the platform/release and GitHub settings checklist above is signed
off. Phase 2 may not replace the license until the ownership decision is recorded.
