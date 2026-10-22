---
name: Vouch Workflow Comparison
date: 2026-07-20
status: resolved
---

# Vouch Workflow Comparison

## Question

Before Tessera implements Phase 5 Step 5.3, how does Herdr's custom approved-contributor
workflow compare with [`mitchellh/vouch`](https://github.com/mitchellh/vouch), and which
model better fits Tessera's maintainer-controlled trust policy?

## Findings

The implementations solve the same narrow problem: a repository-owned trust list decides
whether a GitHub user may open a pull request. Neither grants merge, push, release, or
required-check bypass authority. The differences are policy breadth, trust lifecycle, and
operational safety.

### Herdr

Herdr implements its policy directly in three workflows at commit
[`6f7ef04`](https://github.com/ogulcancelik/herdr/tree/6f7ef04e7dd5a8ec35c5aac8c9b6be1447290399):

- [`.github/APPROVED_CONTRIBUTORS`](https://github.com/ogulcancelik/herdr/blob/6f7ef04e7dd5a8ec35c5aac8c9b6be1447290399/.github/APPROVED_CONTRIBUTORS)
  is a public, case-insensitive, one-login-per-line allowlist. It has no denounced state,
  reason, expiry, scope, or automated removal path.
- [`approve-contributor.yml`](https://github.com/ogulcancelik/herdr/blob/6f7ef04e7dd5a8ec35c5aac8c9b6be1447290399/.github/workflows/approve-contributor.yml)
  accepts `/approve` on an issue from a collaborator with `admin`, `maintain`, or `write`
  permission. It appends the issue author or named user, then uses a repository secret PAT
  to commit and push directly to the default branch.
- [`approve-merged-contributor.yml`](https://github.com/ogulcancelik/herdr/blob/6f7ef04e7dd5a8ec35c5aac8c9b6be1447290399/.github/workflows/approve-merged-contributor.yml)
  automatically adds every non-bot author after any merged pull request. A merge therefore
  grants durable permission to submit future pull requests without a second maintainer
  decision.
- [`pr-gate.yml`](https://github.com/ogulcancelik/herdr/blob/6f7ef04e7dd5a8ec35c5aac8c9b6be1447290399/.github/workflows/pr-gate.yml)
  runs on `pull_request_target` for opened or reopened pull requests. It reads only
  trusted default-branch data, permits collaborators and allowlisted users, labels
  accepted work, and comments on and closes other pull requests. It never checks out or
  executes fork code.

This is small and understandable, and its fork boundary is sound. Its weak points are the
long-lived write token, direct default-branch pushes, no revocation or denouncement model,
no concurrency control for simultaneous list updates, bot bypasses, and automatic durable
trust after one merge. The gate is also a project-specific workflow rather than a reusable
policy component.

### `mitchellh/vouch`

Vouch is a reusable Nushell CLI and set of composite GitHub Actions. The project describes
itself as experimental; the repository was created in February 2026, remains active, and
has a `v1.5.0` tag. This review used commit
[`d66fa29`](https://github.com/mitchellh/vouch/tree/d66fa29a64600490892131ad87597c30c91fcac4),
which is the current floating `v1` target.

- [`.github/VOUCHED.td`](https://github.com/mitchellh/vouch/blob/d66fa29a64600490892131ad87597c30c91fcac4/.github/VOUCHED.td)
  is still a committed flat file, but supports vouched, unknown, and explicitly denounced
  users; optional platform prefixes; and optional public reasons. Git history is the audit
  log. `unvouch` removes either a positive or negative entry.
- [`check-pr`](https://github.com/mitchellh/vouch/blob/d66fa29a64600490892131ad87597c30c91fcac4/action/check-pr/README.md)
  provides the Herdr-style `pull_request_target` gate. It can require a vouch or allow
  unknown users while blocking only denounced users. It supports a separate trust-list
  repository and a response template. Bots and write-capable collaborators are allowed.
  The action reads PR and trust data through the API and does not check out contributor
  code.
- [`check-issue`](https://github.com/mitchellh/vouch/blob/d66fa29a64600490892131ad87597c30c91fcac4/action/check-issue/README.md)
  can apply the same policy to issues, including optional closure and locking.
  `check-user` exposes the status for other repository policies.
- [`manage-by-issue`](https://github.com/mitchellh/vouch/blob/d66fa29a64600490892131ad87597c30c91fcac4/action/manage-by-issue/README.md)
  and `manage-by-discussion` support `vouch`, `unvouch`, and `denounce`, custom command
  words, configurable manager roles, and an optional separate manager trust list. Updates
  can push directly or open a pull request. The default eligible roles include `triage`,
  which is broader than Herdr's maintainer set and Tessera's current requirement.
- Management updates are serialized and direct pushes retry. Vouch also offers CODEOWNERS
  synchronization and cross-repository trust, neither of which Tessera currently needs.
- The
  [cookbook](https://github.com/mitchellh/vouch/blob/d66fa29a64600490892131ad87597c30c91fcac4/COOKBOOK.md)
  recommends a private GitHub App when list updates must bypass branch protection. That is
  incompatible with Tessera's requirement that vouching never bypass required checks.

Vouch is materially more complete than Herdr's implementation, particularly for
revocation, negative trust, policy configuration, update serialization, and reviewed
list-update pull requests. It is also a larger supply-chain surface. Its composite actions
run third-party Nushell code; `check-pr` installs Nushell through a pinned `setup-nu`
action but requests Nushell version `*`. Vouch's own example workflows reference its
mutable `main` branch. A Tessera integration would need an immutable Vouch commit pin and
would still inherit the unbounded Nushell runtime download unless upstream adds a version
input or pin.

A Vouch trust-file read or parse failure is treated as an unknown user. With the default
`require-vouch: true`, that fails closed; with `require-vouch: false`, it fails open for
unknown users and blocks only explicit denouncements. Management workflows necessarily
hold write authority, so an untrusted comment must remain data only and the called action
must be pinned and narrowly permissioned.

### Direct comparison

| Concern             | Herdr                                              | `mitchellh/vouch`                                      |
| ------------------- | -------------------------------------------------- | ------------------------------------------------------ |
| Persistence         | Plain approved-login file                          | Trustdown file with vouched and denounced states       |
| First-time PR       | Close unless collaborator or approved              | Same by default; configurable to denounce-only         |
| Approval            | `/approve` on an issue                             | Issue or Discussion commands, CLI, or manual file edit |
| Removal             | Manual edit only                                   | `unvouch`, `denounce`, or manual edit                  |
| Post-merge          | Automatically trusts every merged human author     | No automatic post-merge policy; project decides        |
| Authorized managers | `admin`, `maintain`, `write`                       | Configurable; default also includes `triage`           |
| List update         | Secret PAT, direct push                            | `GITHUB_TOKEN`/App, direct push, or reviewable PR      |
| Branch protection   | Custom token may push or fail depending on rules   | Cookbook proposes App bypass when needed               |
| Concurrent updates  | No serialization                                   | Serialized workflow and push retries                   |
| Fork-code execution | None in the gate                                   | None in the gate                                       |
| Dependencies        | Pinned checkout and GitHub Script plus inline code | Composite action, Nushell setup, CLI, GitHub APIs      |
| Maturity            | Project-specific observed policy                   | Purpose-built but explicitly experimental              |

### Future growth triggers

Tessera should add trust automation only in response to observed operating friction, one
capability at a time. Each change must preserve manual merge authority and the separation
between permission to present a contribution and permission to merge it.

- **When maintainer-authored trust-list pull requests become frequent administrative
  work**, consider Vouch's `manage-by-issue` or `manage-by-discussion` action with
  `pull-request: true` and `merge-immediately: false`. Pin the action and runtime,
  restrict `roles` to the actual maintainer set instead of the default `triage` inclusion,
  serialize updates, and leave every generated pull request subject to normal checks and
  manual merge.
- **When several maintainers routinely make trust decisions**, define the allowed Vouch
  manager roles explicitly. Consider a separate `vouched-managers` file only if trusted
  community stewards without repository write access genuinely need that responsibility;
  changes to manager authority must themselves use a reviewed pull request.
- **When trustworthy merged contributors are routinely missed during manual follow-up**,
  consider post-merge automation that opens a proposed trust-list pull request. It may
  prepare the one-line diff, but must not modify the default branch, merge its own pull
  request, or treat every merge as permanent trust.
- **When abusive issues from known accounts create measurable moderation load**, consider
  Vouch's `check-issue` action with `require-vouch: false`, so unknown users can still
  report bugs and only explicitly denounced users are blocked. Automatic locking should
  remain limited to an established moderation policy; sensitive evidence belongs in the
  private conduct or security process, not `VOUCHED.td`.
- **When several Tessera repositories develop inconsistent trust lists**, consider Vouch's
  separate `vouched-repo` support. Protect the central repository at least as strongly as
  source repositories, make consumers read-only, and define which projects share a
  community before centralizing their trust decisions.
- **When CODEOWNERS becomes a complete and actively maintained statement of trusted
  stewardship**, consider `sync-codeowners`. Audit upstream behavior first: the reviewed
  implementation is additive and can replace a denounced entry with a vouch, so Tessera
  must not enable it without a conflict safeguard and a deliberate rule for team
  membership changes.
- **When maintaining the local checker costs more than the dependency risk**, and Vouch
  provides an immutably pinned Nushell runtime and stable action release, consider
  migrating to the pinned `check-pr` action. Re-run the fork, malformed-file, denial,
  collaborator, bot, and API-failure scenarios before replacing the local gate.
- **When the default `GITHUB_TOKEN` cannot create management pull requests under the
  repository's rules**, consider a narrowly installed GitHub App that can create a branch
  and pull request. Do not add the App to a ruleset bypass list or grant release,
  administration, or unrelated repository permissions.
- **When the public trust list becomes large enough that stale access is plausible**, add
  a periodic maintainer audit that proposes removals through an ordinary pull request.
  Vouch has no expiry model, so inactivity must not silently create either automatic
  removal or permanent entitlement.

Growth is not a reason to enable direct default-branch pushes, immediate merges, automatic
trust after every merged contribution, or branch-protection bypass. If review capacity is
the bottleneck, weakening the trust boundary only hides that bottleneck.

## Conclusion

Tessera should adopt Vouch's **policy and file model**, but should not copy Herdr's
complete workflow set and should not initially enable Vouch's write-capable management
automation. The safe launch configuration is:

1. Keep a public `.github/VOUCHED.td` file with no sensitive moderation reasons.
2. Gate only pull requests, not issues. Run the gate from trusted default-branch workflow
   code, never check out fork code, pin every action to an immutable commit, and keep CI,
   review, and branch rules authoritative.
3. Add and remove users through maintainer-authored trust-list pull requests subject to
   normal checks and manual merge. A trustworthy merged contribution may inform the
   decision, but must not automatically create permanent trust.
4. Do not create a PAT, GitHub App, branch-protection bypass, delegated manager list,
   CODEOWNERS synchronization, or cross-repository trust store for the initial launch.
5. If comment-driven management later becomes worth the added authority, use Vouch's
   pull-request update mode, disable immediate merge, narrow manager roles to the actual
   maintainer set, serialize updates, and keep the resulting pull request subject to
   normal checks and review.

Phase 5 should use the small in-repository read-only gate because Vouch's current
unbounded Nushell runtime is avoidable risk in a privileged workflow. Reconsider the
pinned `check-pr` action only when the corresponding growth trigger is met and the
runtime, action, and failure behavior pass a fresh audit. Step 5.3 should remove the
Herdr-specific automatic post-merge workflow and direct-push approval workflow either way.
