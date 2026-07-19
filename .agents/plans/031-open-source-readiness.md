---
name: Tessera open-source readiness

description:
  Prepare Tessera for a deliberate public GitHub launch with Apache-2.0 licensing,
  community governance, release notes, and post-launch static DocC hosting.
status: pending
created: 2026-07-17
updated: 2026-07-19
---

<!-- Allowed status values: planning, in-review, pending, in-progress, complete. -->

## Progress

- [x] **Phase 1 — Establish the public-release baseline**
  - [x] 1.1 Audit repository history, tracked files, and public/private dependencies
  - [x] 1.2 Verify licensing, copyright, and asset provenance
  - [x] 1.3 Resolve the supported-platform and release-version contract
  - [x] 1.4 Record the GitHub launch and billing assumptions
- [x] **Phase 2 — Apply the Apache-2.0 legal baseline**
  - [x] 2.1 Replace the MIT license after ownership approval
  - [x] 2.2 Align legal references and third-party notices
- [ ] **Phase 3 — Rebuild the public-facing documentation**
  - [ ] 3.1 Add and verify the Tessera brand asset
  - [ ] 3.2 Rewrite the README around a clear user journey
  - [ ] 3.3 Publish project status, roadmap, and documentation boundaries
- [ ] **Phase 4 — Make changelog and releases predictable**
  - [ ] 4.1 Cleanly reorganize the changelog without losing history
  - [ ] 4.2 Add GitHub-generated release-note configuration
  - [ ] 4.3 Define the version, tag, and release checklist
- [ ] **Phase 5 — Establish a lightweight contribution and trust model**
  - [ ] 5.1 Add thoughtful issue and pull-request entry points
  - [ ] 5.2 Add private security reporting and support boundaries
  - [ ] 5.3 Adopt a safe, maintainer-controlled vouch workflow
  - [ ] 5.4 Add ownership metadata only where it reflects real stewardship
- [ ] **Phase 6 — Harden GitHub automation for public forks**
  - [ ] 6.1 Review workflows, actions, permissions, and fork behavior
  - [ ] 6.2 Configure repository governance and maintenance automation
  - [ ] 6.3 Perform the pre-publication safety gate
- [ ] **Phase 7 — Publish static DocC on GitHub Pages after launch**
  - [ ] 7.1 Make the existing combined DocC build Pages-ready
  - [ ] 7.2 Add a read-only-validation plus main-branch deployment workflow
  - [ ] 7.3 Enable and verify the GitHub Pages deployment
- [ ] **Phase 8 — Execute the staged public launch**
  - [ ] 8.1 Run the complete local release gate
  - [ ] 8.2 Change visibility and verify anonymous-user behavior
  - [ ] 8.3 Run the first public CI, release, and documentation smoke checks

## Overview

This plan turns Tessera from a closed repository into a deliberately public, still-early
Swift project without pretending that the unfinished Phase 4 Showcase product surface is
production-ready. It covers the legal and provenance gate before any visibility change, a
README and release experience informed by Herdr, GRDB.swift, and The Composable
Architecture, and a maintainer-controlled contribution model rather than an unbounded
promise of support. The current read-only DocC workflow remains the validation path;
static combined DocC publishing is a separate post-publication operation so it can use
free public-repository GitHub Actions as requested.

The plan assumes that the repository owner can approve the Apache-2.0 transition and that
Tessera's public GitHub identity remains `robfeldmann/tessera`. It does not assume that an
email address, sponsor program, custom domain, SPI hosting, or release binary artifacts
are ready; those must not be invented in the implementation. If the provenance audit
cannot establish relicensing authority, or if a secret/private dependency is found in
history, the visibility change is a hard gate rather than something to paper over in
README text.

## Phase 1 — Establish the public-release baseline

**Goal**: produce a signed-off inventory of what can safely become public and settle the
contracts that all later documentation and automation will describe.

### Step 1.1 — Audit repository history, tracked files, and public/private dependencies

- Files: repository history and index; `.gitignore`; `Package.swift`; `Package.resolved`;
  `Examples/**/Package.swift`; `.github/**`; `scripts/**`; `Sources/**`; `Tests/**`;
  `docs/**`; `design/**`; `CHANGELOG.md`; `README.md`; `CONTRIBUTING.md`;
  `CODE_OF_CONDUCT.md`.
- Enumerate tracked and ignored files, large/binary assets, generated output,
  machine-local configuration, private hostnames, credentials, tokens, personal data, and
  accidental build/VM state. Inspect history as well as the current tree; a value removed
  from HEAD is still a public-release blocker if it remains recoverable in Git history.
- Confirm every package dependency and GitHub Action resolves from a public, intended
  source. Pay particular attention to Ghostty checkout/build inputs, local module maps,
  `.windows-frost.env`, VM configuration, and the public/private boundary of the examples.
- Run a secret scanner and a dependency/license inventory appropriate for the toolchain;
  record false positives and remediation in the release checklist rather than deleting
  evidence. Rotate any credential found in history before opening visibility.
- Acceptance: a checked-off inventory identifies every tracked artifact that will be
  public, every intentionally ignored local artifact, every external URL, and every
  remediation. Anonymous checkout/history review finds no credential, private dependency,
  or private infrastructure requirement.

### Step 1.2 — Verify licensing, copyright, and asset provenance

- Files: `LICENSE`; all existing source/documentation headers if any; `Package.swift`;
  `Package.resolved`; `Sources/**/Resources/**`; `Sources/**/*.docc/**`; `design/**`;
  `CODE_OF_CONDUCT.md`; the supplied `/Users/rob/Downloads/Tessera Logo.png`; any copied
  screenshots/icons.
- Build a contributor/author and copyright-owner list from the history and confirm who can
  approve a license change. Check that the Tessera logo, DocC artwork, Ghostty-derived
  material, vendored/generated files, and copied snippets have permissions compatible with
  Apache-2.0 distribution. Preserve required upstream attribution and license text.
- Inventory dependency licenses and distinguish dependency obligations from Tessera's own
  license. Do not add a `NOTICE` file merely by convention; add it only when the audit
  identifies notices that must accompany the distribution.
- Acceptance: the owner has an explicit relicensing decision, every non-Tessera asset has
  a documented source/license or is replaced, and the implementation phase has a complete
  attribution/notice list with no unresolved ownership assumption.

### Step 1.3 — Resolve the supported-platform and release-version contract

- Files: `Package.swift`; every example package manifest; `README.md`; `.swift-version`;
  `.github/workflows/ci.yml`; `.github/workflows/docs.yml`; `CONTRIBUTING.md`; `.spi.yml`;
  `CHANGELOG.md`.
- Reconcile the current manifest/platform declarations with the README's macOS, Linux, and
  Windows claim and the three-OS CI matrix. Decide whether each platform is supported,
  experimental, or only used for development, then make manifests, docs, CI, and issue
  forms say the same thing. Do not advertise a platform that cannot build the declared
  package products.
- Define the first public release policy: whether `0.1.0` remains the baseline, what
  branch is release-capable, whether tags are `v<SemVer>`, and how unreleased work maps to
  a future release. Keep the existing Swift Package Index configuration for possible later
  use, but do not claim SPI-hosted docs in the interim.
- Verify the actual local and remote tag inventory before choosing that policy. The
  current repository has no `v0.1.0` tag even though the README and changelog reference
  one; either establish an intentional `v0.1.0` baseline or update every installation,
  changelog, and release link to the selected first public version.
- Acceptance: a short release contract names supported OS/toolchain versions, package
  products, default branch, tag format, and semantic-versioning policy; all current public
  entry points either implement that contract or are updated in later phases.

### Step 1.4 — Record the GitHub launch and billing assumptions

- Files: `.github/**`; `CONTRIBUTING.md`; the final release checklist (repository
  operations, not committed secrets).
- Identify the GitHub organization/repository owner, default branch, required checks,
  Actions permission policy, Pages availability, vulnerability-reporting availability, and
  whether public-repository standard runners are free under the account's current GitHub
  policy. Confirm no workflow depends on private runners, paid macOS machines, private
  package credentials, or organization-only Actions.
- Decide which labels, Discussions, Projects, sponsorship, and CODEOWNERS are actually
  maintained. Do not add a funding or contact path without a real destination.
- Acceptance: the launch checklist has named settings owners and a rollback/hold decision;
  the plan contains no unverified claim that public CI or Pages is free for this account.

## Phase 2 — Apply the Apache-2.0 legal baseline

**Goal**: make the license users see in GitHub, the checkout, and the README accurate and
legally supportable.

### Step 2.1 — Replace the MIT license after ownership approval

- Files: `LICENSE`; any required `NOTICE`; source/documentation attribution locations
  identified in Phase 1.
- Replace the MIT text with the canonical Apache License 2.0 text, using the approved
  copyright attribution and preserving any required third-party notices. Do not silently
  relicense contributions whose owners have not approved the change.
- Acceptance: the license file matches the approved Apache-2.0 text, GitHub detects
  Apache- 2.0, and a clean checkout contains no stale claim that Tessera itself is
  MIT-licensed.

### Step 2.2 — Align legal references and third-party notices

- Files: `README.md`; `CHANGELOG.md`; `CONTRIBUTING.md`; `CODE_OF_CONDUCT.md`; DocC
  landing pages and package metadata where license links are present; dependency/license
  inventory from Phase 1.
- Update all user-facing license links and wording to Apache-2.0. Add explicit attribution
  for reused assets or code where required, and document dependency licenses in the place
  chosen by the audit. Record the transition in the unreleased history, but do not claim
  that the currently untagged `0.1.0` draft was publicly distributed under either license;
  align the first real release tag with the approved Apache-2.0 baseline.
- Acceptance: repository-wide search returns only intentional historical context for MIT,
  every license link resolves, and the dependency/asset attribution review passes.

## Phase 3 — Rebuild the public-facing documentation

**Goal**: make a first-time visitor understand what Tessera is, whether it is usable, how
it is installed, what is unfinished, and where the deeper documentation lives.

### Step 3.1 — Add and verify the Tessera brand asset

- Files: create a repository-owned asset path such as `assets/tessera-logo.png` from
  `/Users/rob/Downloads/Tessera Logo.png`; `README.md`; optionally social-preview metadata
  only if the repository owner wants to maintain it.
- After the provenance approval in Step 1.2, copy the supplied logo into a stable,
  case-sensitive repository path, optimize it without changing its appearance, and use a
  relative README link with meaningful alt text. Check GitHub rendering from the
  repository root and from a fork/branch URL.
- Acceptance: the image is tracked, licensed/attributed as approved, renders at a useful
  size in light and dark GitHub themes, and does not depend on a local Downloads path.

### Step 3.2 — Rewrite the README around a clear user journey

- File: `README.md`.
- Lead with the logo, one-sentence value proposition, appropriate badges, and a prominent
  early-development warning: Tessera is new, actively developing, unfinished, not for
  production use, and community help may not be ready until after the project's Phase 4
  Showcase product milestone. State the project's current phase without discouraging
  respectful issue reports. project's current phase without discouraging respectful issue
  reports.
- Add a stable table of contents and organize sections for: what Tessera provides; current
  feature/module map; requirements and supported platforms; installation; a minimal
  working usage example; documentation; roadmap/Showcase milestone status; contributing;
  code of conduct; changelog/releases; and Apache-2.0 license.
- Use badges that will be true at launch: CI, supported Swift/toolchain, license, latest
  release only after a release exists, and static docs only after Pages is live. Do not
  add SPI or coverage/sponsorship badges without a maintained endpoint.
- Correct the current Swift Package Manager example so it is valid Swift and shows one
  dependency declaration plus product dependencies; link to the exact public products and
  examples that are actually supported. Preserve useful terminal-recovery guidance while
  moving contributor-only VM/cache detail to `CONTRIBUTING.md` and the docs.
- Acceptance: a clean reader can reach install, first use, API docs, contribution rules,
  security reporting, and release history in under a few links; the warning and license
  are visible before the detailed usage sections; all README links, code samples, badges,
  and image references resolve.

### Step 3.3 — Publish project status, roadmap, and documentation boundaries

- Files: `README.md`; `CONTRIBUTING.md`; current `docs/**`; DocC catalog landing pages;
  existing Phase 4 Showcase product milestone plans/design material.
- Explain what is stable enough to try, what is experimental, and what remains planned.
  Link the existing Phase 4 Showcase product milestone material without presenting
  internal planning documents as a supported API contract. Define where bug reports, usage
  questions, and design discussion belong before that product milestone.
- State that SPI publication is intentionally deferred and describe the interim static
  GitHub Pages destination only once it is enabled in Phase 7.
- Acceptance: the public status language agrees with the roadmap and package API; no
  internal/private path is linked; a newcomer can tell whether to file an issue, start a
  discussion, or wait for a later phase.

## Phase 4 — Make changelog and releases predictable

**Goal**: preserve the project's history while giving maintainers and users a repeatable
way to prepare and publish release notes.

### Step 4.1 — Cleanly reorganize the changelog without losing history

- File: `CHANGELOG.md`.
- Preserve the material history in the current `0.1.0` draft, but keep it as a release
  entry only if the Phase 1 tag decision establishes `v0.1.0` as a real baseline.
  Otherwise fold or relabel it into the selected first public version. Rewrite the very
  large current `Unreleased` section into user-oriented categories such as Added, Changed,
  Fixed, Documentation, and Tooling/Infrastructure. Consolidate duplicate implementation
  details into meaningful capabilities, call out platform support and compatibility
  changes, and move purely internal planning noise out of release notes.
- Keep comparison/tag links accurate under the selected `v<SemVer>` policy and reference
  only tags that exist locally and on the public remote. Add a short release-note
  convention to `CONTRIBUTING.md`: each user-visible change gets a concise entry or a
  labeled PR that can be summarized at release time.
- Acceptance: the changelog is readable without losing the material history, links resolve
  against real tags, and the next release can be prepared without reclassifying every
  commit from scratch.

### Step 4.2 — Add GitHub-generated release-note configuration

- File: create `.github/release.yml` using GitHub's generated-release-notes configuration.
- Define categories and labels for breaking changes, features, fixes, documentation,
  maintenance, and dependencies; exclude or group automation-only changes; and provide a
  release-name/body template that links the generated notes to `CHANGELOG.md` and the
  migration guidance when needed. Add only labels that the repository will actually use.
- Prefer GitHub's tag/release generation over a bespoke release bot because Tessera has no
  binary artifact publication contract yet. If later packaging is needed, keep it as a
  separate reviewed workflow rather than coupling it to note generation.
- Acceptance: a dry-run or test tag produces correctly categorized notes from
  representative PR labels, does not expose commit metadata that should remain private,
  and leaves the hand-edited changelog as the canonical historical record.

### Step 4.3 — Define the version, tag, and release checklist

- Files: `CONTRIBUTING.md`; `CHANGELOG.md`; `.github/release.yml`; optional
  `.github/workflows/release.yml` only if the audit demonstrates a needed automated step.
- Document pre-release checks, changelog finalization, tag creation, generated-note
  review, GitHub release publication, README badge updates, and post-release
  comparison-link updates. Do not promise signed releases, binaries, Homebrew, or SPI
  until an owner and reproducible implementation exist.
- Include a tag-integrity and consumer check: every changelog comparison/release link must
  resolve to a real public tag, and a fresh external package must resolve the exact
  dependency declaration shown in the README.
- Acceptance: a maintainer can publish a source-only SemVer release from a clean checkout
  by following the checklist, and a failed validation has a clear hold/rollback action.

## Phase 5 — Establish a lightweight contribution and trust model

**Goal**: invite useful contributions without pretending that an unfinished
solo-maintained project can provide unlimited support or safely execute untrusted fork
code.

### Step 5.1 — Add thoughtful issue and pull-request entry points

- Files: create `.github/ISSUE_TEMPLATE/bug.yml`; `.github/ISSUE_TEMPLATE/feature.yml` or
  `enhancement.yml`; `.github/ISSUE_TEMPLATE/config.yml`; create
  `.github/PULL_REQUEST_TEMPLATE.md`.
- Use concise forms modeled on TCA's useful environment/reproduction capture and GRDB's
  clear issue/discussion boundaries: platform, Swift/Xcode version, Tessera revision,
  reproducible steps, expected/actual behavior, logs or snapshots, and scope. Add a
  question/support route to Discussions only if Discussions will be enabled and monitored.
- The PR template should ask for intent, user-visible behavior, tests/validation, docs or
  changelog impact, and compatibility/Breaking Change notes without becoming a long form.
  Add a no-secrets reminder and a note that early-project issues may be triaged slowly.
- Acceptance: opening a bug, feature, and PR on a disposable branch presents the intended
  fields, accepts accessibility-friendly plain text, and does not force contributors
  through irrelevant questions.

### Step 5.2 — Add private security reporting and support boundaries

- Files: create `SECURITY.md`; `CODE_OF_CONDUCT.md`; optionally create `SUPPORT.md` only
  if a maintained support channel is chosen; update `README.md` and `CONTRIBUTING.md`
  links.
- Prefer GitHub private vulnerability reporting/security advisories if available;
  otherwise use a real owner-controlled contact address approved in Phase 1. Choose a real
  private, owner-controlled reporting path for conduct incidents as well, and replace the
  code of conduct's current public-issue enforcement instruction with it. Never invent an
  email address or request sensitive reports in a public issue. Define supported versions,
  expected acknowledgement, disclosure handling, and what is explicitly out of scope for
  this pre-production project.
- Acceptance: the security link is visible and gives a private path, the path has been
  tested by the maintainer without sending a real vulnerability, and no public template
  asks for credentials, private logs, or other secrets.

### Step 5.3 — Adopt a safe, maintainer-controlled vouch workflow

- Files: `.github/APPROVED_CONTRIBUTORS` (or an equivalent reviewed allowlist);
  `.github/workflows/approve-contributor.yml`;
  `.github/workflows/approve-merged-contributor.yml`; any PR/issue gate workflows;
  `CONTRIBUTING.md`.
- Adapt the observable Herdr pattern—an explicit approved-contributor list and a
  maintainer action after a trustworthy contribution—rather than copying its
  project-specific code. Define who may vouch, how a contributor is added or removed,
  whether the list is public, and how first-time contributions are reviewed. Keep CI and
  branch protection authoritative: a vouch must never merge code or bypass required
  checks.
- Make all automation least-privilege and fork-safe. Do not check out or execute untrusted
  PR code in a privileged `pull_request_target` workflow; do not expose secrets to fork
  builds; validate maintainer identity for any approval command; and prefer a manual,
  auditable list update if GitHub permissions cannot make an automated update safe.
- Acceptance: a disposable fork/first-time-contributor scenario demonstrates the approval
  and post-merge path, an already-vouched contributor is not repeatedly gated,
  unauthorized actors cannot add themselves, and required CI/branch rules still apply.

### Step 5.4 — Add ownership metadata only where it reflects real stewardship

- Files: create `.github/CODEOWNERS` only after the owner/team paths are confirmed;
  `.github/FUNDING.yml` only if a real sponsorship destination is ready; repository
  settings.
- Assign review ownership for package, CI, docs, and governance files only to maintainers
  who will actually respond. Do not add aspirational teams, sponsors, or social links.
- Acceptance: GitHub resolves every CODEOWNERS entry and required review rules match the
  maintainer's real capacity; optional files are omitted when there is no maintained
  target.

## Phase 6 — Harden GitHub automation for public forks

**Goal**: make public CI useful and free without granting untrusted pull requests write
access or relying on private-repository behavior.

### Step 6.1 — Review workflows, actions, permissions, and fork behavior

- Files: `.github/workflows/ci.yml`; `.github/workflows/docs.yml`;
  `.github/actions/setup-swift/action.yml`; `.github/dependabot.yml`; all new workflows
  from Phases 4–5.
- Retain the current read-only PR validation model, then audit every third-party action
  for source/pinning, required permissions, runtime support, and public-repository
  availability. Keep `contents: read` on validation workflows, use job-scoped
  `pages: write` and `id-token: write` only for the Pages deploy job, and keep
  `persist-credentials: false` where checkout does not need to push.
- Test `pull_request` behavior from a fork, label changes, edited PRs, manual dispatch,
  push to the default branch, and empty/first-push commit ranges. Confirm caches contain
  only reproducible artifacts and no local credentials. Review the `skip-ci` policy so it
  cannot create a misleading green status or permanent lockout.
- Acceptance: workflow lint/static analysis passes; fork PRs run without secrets or write
  tokens; each required check reports a useful status; public CI uses only public inputs
  and the selected runner classes.

### Step 6.2 — Configure repository governance and maintenance automation

- Files: `.github/dependabot.yml`; labels and branch/ruleset settings; optional
  `.github/ISSUE_TEMPLATE/config.yml`; `CONTRIBUTING.md`.
- Enable Dependabot updates for GitHub Actions and Swift/other dependency ecosystems that
  are actually configured. Create a small label set matching release-note categories and
  issue forms. Protect `main` with required CI/docs checks, review requirements
  appropriate to the maintainer count, and no direct bypass except the owner emergency
  path.
- Decide whether Discussions, squash merge, signed commits, merge queue, and automatic
  deletion of head branches are enabled; document only settings that are active.
- Acceptance: a test PR cannot merge while required checks fail, Dependabot and generated
  notes use existing labels, and governance settings do not require unavailable teams or
  paid services.

### Step 6.3 — Perform the pre-publication safety gate

- Files: all tracked files and history; final versions of `LICENSE`, `README.md`,
  `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `SECURITY.md`, `.github/**`, `CHANGELOG.md`.
- Re-run secret/history, dependency/license, link, tag-integrity, documented-dependency,
  and public-build audits after all content changes. Verify every changelog tag/comparison
  link resolves and a fresh external package can resolve the README's selected version.
  changes. Verify no local path such as `/Users/rob`, private checkout, token, VM state,
  or private issue/person data remains in the public surface. Review GitHub repository
  visibility, default branch, Actions access, Packages access, Pages source, and security
  settings as a two-person or owner checklist even if only one person executes it.
- Acceptance: every release-blocking item is closed or explicitly marked safe, the owner
  signs off on Apache-2.0, public history, and private conduct/security reporting paths,
  and the repository is ready for visibility change with a documented rollback plan.

## Phase 7 — Publish static DocC on GitHub Pages after launch

**Goal**: reuse Tessera's existing combined DocC pipeline to publish a static site without
SPI and without granting Pages privileges to pull-request builds.

### Step 7.1 — Make the existing combined DocC build Pages-ready

- Files: `justfiles/docs.just`; `.github/workflows/docs.yml`; all Tessera `.docc` catalogs
  under `Sources/**`; `README.md`.
- Preserve the current per-target archive generation, dependency-aware merge, warnings-as-
  errors validation, and `transform-for-static-hosting` flow. Add a deliberate Pages/build
  recipe or parameter so `--hosting-base-path` is not an unexplained hard-coded `/`.
- Decide whether the project uses the repository Pages path (`/tessera`) or a configured
  custom/root domain. Use the selected base path consistently in the DocC transform,
  preview instructions, links, and deployment URL. Keep `just docs lint` validation-only;
  Pages must invoke the build/transform path (`just docs build` or an equivalent explicit
  recipe).
- Acceptance: on macOS, the combined `.build/docs` output is generated from a clean state,
  serves locally at the selected base path, links to every merged module, and contains no
  references to private paths or unpublished SPI hosting.

### Step 7.2 — Add a read-only-validation plus main-branch deployment workflow

- File: `.github/workflows/docs.yml` or a new `.github/workflows/pages.yml`.
- Keep PR and non-deploy documentation validation read-only and run it only where DocC and
  the Ghostty prerequisite are available. Add a push-to-main/manual deployment path with
  an environment named `github-pages`, `actions/upload-pages-artifact@v3`, and
  `actions/deploy-pages@v4`; grant `pages: write` and `id-token: write` only to the deploy
  job. Use `actions/configure-pages` if needed for the selected base path and retain
  concurrency cancellation so stale main builds do not deploy over newer ones.
- Adapt the local
  `~/Developer/removed-client/removed-private-repository/main/.github/workflows/generate-docs.yml` pattern
  only for its public pieces. Do not carry over its private token, private private dependency,
  Artifactory credentials, authenticated checkout, xlarge runner, or private dependency
  setup. Use the existing public package checkout and public toolchain/dependency cache.
- Acceptance: a fork PR cannot deploy or access Pages write permissions; a main push
  builds, uploads, and deploys the static artifact; a manual dispatch can recover a failed
  deploy; the workflow is safe when the docs build fails and never deploys a partial
  directory.

### Step 7.3 — Enable and verify the GitHub Pages deployment

- Settings: repository **Pages** source set to **GitHub Actions**; `github-pages`
  environment/deployment protection; Actions permissions; custom-domain setting only if
  selected in Step 7.1.
- After the repository is public, enable Pages and run the workflow. Verify the published
  URL from an anonymous browser, the README docs link, module landing pages, assets, deep
  links, and refreshes at non-root routes. Check that a later main push cancels/stops
  stale deployment work as intended.
- Acceptance: static DocC is reachable at the documented URL, all links and assets work
  under the actual base path, no SPI hosting is implied, and the Pages environment shows
  only the intended deployment job.

## Phase 8 — Execute the staged public launch

**Goal**: change visibility only after the legal/safety gate, then prove the public
workflow end to end before announcing the project.

### Step 8.1 — Run the complete local release gate

- Files: final repository tree and all changed Markdown/YAML/Swift/configuration files.
- Run the repository-required quality sequence before handoff: `just quality format`, the
  complete `swift test` suite, and `just quality lint`. Also run the narrowest relevant
  build/checks while iterating (`swift build`, `swift package dump-package`,
  `just docs lint` and `just docs build` on macOS), the repository's link/secret/license
  checks, and `pnpx markdownlint-cli <path>` for each edited Markdown file as required by
  the local contributor rules. Review formatter-only changes rather than suppressing
  findings.
- Acceptance: all required checks pass from a clean working tree, the README install
  sample is compile-valid or demonstrably matches the manifest, the changelog/release
  configuration parses, and the generated DocC site passes its local smoke check.

### Step 8.2 — Change visibility and verify anonymous-user behavior

- Operations: GitHub repository visibility, Actions/Pages/security settings, default
  branch, ruleset, labels, issue forms, Discussions, and release configuration.
- Change the repository to public only after Step 6.3 sign-off. From a clean anonymous
  session and a fresh clone, verify source, history, tags/releases, package resolution,
  README images/links, issue/PR forms, security link, and contributor setup. Confirm that
  no private repository, secret, or local absolute path is needed for `swift build` or the
  supported CI path.
- Acceptance: an unauthenticated user can clone and follow the documented first-use path;
  a fork can open a PR and receive safe CI; the maintainer can still perform the vouch,
  release, and moderation operations.

### Step 8.3 — Run the first public CI, release, and documentation smoke checks

- Operations: push/PR CI, manual docs dispatch, a disposable/test release or generated
  notes preview, and the Pages deployment from `main`.
- Exercise one representative public fork PR, one main push, one docs build/deploy, and
  one release-note generation path. Verify required statuses and cache behavior, then
  remove any test tag/release and record observed runner minutes or billing behavior for
  future budgeting. Announce the project only after the early-development disclaimer,
  support boundaries, and links have been observed live.
- Acceptance: the public CI gate, vouch moderation path, generated release notes, and
  static DocC deployment all work end to end; any discrepancy is fixed before launch
  communication rather than deferred as an undocumented follow-up.

## References

- Current repository surfaces: `README.md`, `CHANGELOG.md`, `LICENSE`, `CONTRIBUTING.md`,
  `.github/workflows/ci.yml`, `.github/workflows/docs.yml`,
  `.github/actions/setup-swift/action.yml`, `justfiles/docs.just`, `.spi.yml`,
  `Package.swift`, and `.gitignore`.
- Herdr stewardship patterns: <https://github.com/ogulcancelik/herdr>, especially
  `.github/APPROVED_CONTRIBUTORS`, `.github/ISSUE_TEMPLATE/**`, and
  `.github/workflows/approve-contributor.yml`, `approve-merged-contributor.yml`,
  `pr-gate.yml`, and `release.yml`.
- GRDB.swift README and release/documentation structure:
  <https://github.com/groue/GRDB.swift> and
  <https://github.com/groue/GRDB.swift/blob/master/README.md>.
- The Composable Architecture contribution and issue-form patterns:
  <https://github.com/pointfreeco/swift-composable-architecture>.
- Local static DocC comparison checkout:
  `~/Developer/removed-client/removed-private-repository/main/.github/workflows/generate-docs.yml` and
  `~/Developer/removed-client/removed-private-repository/main/Makefile`.
- GitHub generated release notes configuration:
  <https://docs.github.com/en/repositories/releasing-projects-on-github/automatically-generated-release-notes>.
- GitHub Pages custom workflows:
  <https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages>.
- Apache License 2.0: <https://www.apache.org/licenses/LICENSE-2.0>.
