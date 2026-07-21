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
  images, and deleted all three pre-remediation UTM images.
- The local shared history and the three ordinary origin branch refs were rewritten on
  2026-07-19. Direct content searches found zero credential matches in all local refs and
  in a fresh clone of every ordinary origin branch; `gitleaks` also found no leaks.
- GitHub pull refs still retain historical copies in pull requests 8, 9, 12, 13, and 14.
  They are read-only GitHub-managed refs, so an owner must ask GitHub Support to purge the
  sensitive data and related caches, pull-request diffs, Actions logs, artifacts, and
  releases before changing repository visibility.
- The separate public `solcreek/frost` repository also contained the credential in current
  source. Its local checkout is remediated, but this audit's GitHub credential has only
  read access there. A Frost maintainer must rewrite and verify that repository
  separately.
- The owner accepted this residual-hosted-history risk. This audit cannot certify a clean
  history while GitHub pull refs retain the credential; reconsider the acceptance before
  changing repository visibility.
- Git history has one human author identity and Dependabot. The owner confirmed sole
  copyright authority, authorized Apache-2.0 relicensing, and approved public exposure of
  the existing commit-author identity and email address.

### License and asset provenance

- Tessera is currently MIT-licensed with a generic `Tessera Contributors` copyright line.
  The owner authorized the Phase 2 Apache-2.0 transition and selected
  `Copyright 2026 Rob Feldmann` for Tessera's original material.
- The owner attested that all 56 Pixelmator-generated DocC card/icon assets and the
  supplied Tessera logo are original work, contain no third-party stock art, marks,
  templates, or restricted fonts, and may be distributed under Apache-2.0.
- The resolved Swift dependency inventory contains MIT-licensed `swift-custom-dump`,
  `swift-displaywidth`, `swift-snapshot-testing`, and `xctest-dynamic-overlay`; and
  Apache-2.0 components from the Swift and DocC projects. No dependency checkout contains
  a `NOTICE` file. Phase 2 must retain a third-party license inventory and include any
  notice text required by a distributed dependency artifact.
- Ghostty at `ae52f97dcac558735cfa916ea3965f247e5c6e9e` is MIT-licensed, copyright
  Mitchell Hashimoto and Ghostty contributors. Phase 2 must retain that license text and
  attribution whenever Tessera distributes Ghostty-derived headers, source, or
  `libghostty-vt`.
- No tracked screenshots, photographs, or external logo assets were found. The logo
  provenance attestation completes the Phase 1 asset inventory; Phase 3 may add it.

### Supported-platform and release contract

- **Supported distribution platforms:** macOS 26 or later, Linux, and Windows. The
  required toolchain is Swift 6.3; the repository pins Swift 6.3.2 and uses Swift language
  mode 6. The package manifests declare the macOS deployment baseline but do not define or
  exclude the supported non-Apple platforms.
- **CI validation:** the CI matrix builds and tests all three supported operating systems,
  with Windows enabling the Ghostty target through `TESSERA_GHOSTTY_WINDOWS=1`.
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

The owner accepts the residual historical Frost credential in GitHub pull refs and in the
separate public Frost repository, and is not requesting GitHub purging or an immediate
Frost rewrite. This is a documented risk acceptance, not evidence that hosted history is
clean; it must be reconsidered before changing public visibility.

## Phase 6 Recheck

Rechecked on 2026-07-20 after hardening the public-fork automation:

- `gitleaks git --redact --no-banner .` scanned all 93 locally reachable commits and found
  no leaks. A tracked-tree search found no owner home-directory or private workspace paths
  after replacing those paths with public references or generic examples.
- Validation workflows now run lint and tests after edited pull requests, use read-only
  permissions, disable checkout credential persistence, pin every external action to a
  full commit SHA, and cache only reproducible build artifacts. `actionlint` passes.
- Repository Actions are enabled only for GitHub-owned actions and the reviewed
  Swift/Zig/`just`/draft-release actions, with full-SHA pinning required.
- The active default-branch ruleset requires squash pull requests, one code-owner
  approval, resolved threads, signed commits, linear history, and every CI and
  documentation job. The administrator emergency bypass works only through a pull request.
  Discussions and every linked category are enabled; merge commits and rebase merges are
  disabled; automatic merge and deletion of merged head branches are enabled.
- Dependabot covers Swift, npm, and GitHub Actions monthly. All release-note and
  issue-form labels referenced by repository configuration exist.
- The dependency graph resolves from public GitHub URLs. The repository still has no
  release tags, Pages site, or anonymous external package-resolution path; those are
  intentionally deferred to Phases 7–8.

The owner explicitly accepts the residual risk from the rotated Frost credential retained
in GitHub-managed pull refs 8, 9, 12, 13, and 14 and the separate public `solcreek/frost`
history; no GitHub Support purge is requested. The owner also confirms that
`me@robfeldmann.com` is monitored daily for private conduct and security reports, approves
the live governance settings, and approves a source-only launch with no GitHub Packages
contract. These decisions clear the Phase 6 safety gate; the repository remains private
until the later launch phase.

Rollback before publication is to keep repository visibility private, disable the active
ruleset if it blocks recovery, and restore the prior repository Actions policy. After a
visibility change, immediately returning the repository to private and disabling Actions,
Pages, and Releases limits further exposure but cannot retract clones or cached public
history; credential rotation and GitHub Support remediation remain available fallbacks.
