---
name: planning
description:
  Use when the user commissions, resumes, or closes a plan in docs/plans/ ("plan X", "pick
  up the plan", "what's next on"), or commissions an investigation whose answer is a
  plan's Outcome. Keeps Progress and Next: current and records decisions with evidence.
version: 0.2.0
---

# Planning

A plan is a living document the user commissions. It exists to agree on the work before
building it, and so a fresh session can resume from the file alone. Plans live in
`docs/plans/<slug>.md`, inside the `docs/` IWE workspace, and `docs/plans.md` is rendered
from their frontmatter by `scripts/plans.py` (the quality gate fails while the hub is
stale).

## When

- Only when the user asks. Never start a plan on your own; findings you turn up go to the
  current plan's Discoveries, or to a research record (`investigations` skill) when the
  user commissions one.
- One or two files with an obvious approach need no plan: say so and do the work.
- A commissioned question ("find out why X crashes") is a plan whose Outcome is the
  answer.

## File and frontmatter

Slug filename, no number: `docs/plans/terminal-io-concurrency-review-fixes.md`. Plans
written before the workspace were numbered; `docs/plans.md` keeps the number-to-slug
table, and "plan 034" in older text means the plan whose `order` is 34.

```yaml
---
type: plan
stage: proposed # proposed | planned | active | done | cancelled
created: YYYY-MM-DD
completed: YYYY-MM-DD # only when done
order: 36 # next integer after the highest in docs/plans/
description: One line shown beside the plan in docs/plans.md.
---
```

`proposed` is being shaped, `planned` the user approved the outline, `active` underway,
`done` with `completed`, or `cancelled` with a link to its successor in the body. The
schema is `docs/.iwe/schemas/plan.yaml`; `iwe schema validate` from `docs/` checks it.
After changing any frontmatter field, run `scripts/plans.py` to re-render the hub.

## Shape

```markdown
# <Outcome as a verb phrase>

Goal: two to four sentences. What is true when this is done, for whom, and how you will
see it.

## Progress

- [x] 1 <Slice> — <evidence: SHA, command and result>
- [ ] 2 <Slice>
  - [x] 2.1 <Step> — <evidence>
  - [ ] 2.2 <Step>

Next: <the very next action, or the blocker and who owns it>

## Approach

Current state, end state, patterns to follow and to avoid, the files that orient a
newcomer, non-goals. Open questions while proposed. About 40 lines.

## Slices

### 1 <Slice>

Delivers: <observable behavior>. Verify: <exact command or scenario, and what you should
see>.

## Acceptance

- [ ] <Behavior-level check for the whole plan>

## Decisions

- <YYYY-MM-DD> <Decision>, because <reason>. (<who decided it>)

## Discoveries

- <Observation> — <evidence>

## Outcome

Written at close: what shipped, what did not, what to remember.
```

- Progress stays first and at most two levels deep; its numbers match the Slices headings.
  Older plans use Phases and Steps instead of Slices; keep a plan's existing shape when
  resuming it.
- Slices are vertical, each verifiable on its own and small enough for one session,
  ordered so the build stays green. Name files in Approach; Slices and Acceptance speak in
  behavior.
- Stay under about 300 lines; a longer plan wants splitting.
- One paragraph per line; relative `.md` links; no raw HTML (`iwe normalize` deletes it).

## Build

- Resume by reading the whole plan and starting at `Next:`. Do not reopen recorded
  Decisions without new evidence.
- Work one slice at a time. Check a box only when its evidence exists, and put the
  evidence on the line: a SHA, a command and its result, a snapshot path.
- Record Decisions (dated, with the reason) and Discoveries (with evidence) when they
  happen.
- Pause after each slice the user asked to review; otherwise keep going.
- End every session that touched the plan by updating Progress and the `Next:` line; it is
  the handoff.

## Close

When Acceptance holds, write the Outcome, set `stage: done` with `completed`, and
re-render the hub. Promote durable decisions out of the plan into
`docs/architecture/<slug>.md` (schema `architecture.yaml`; add it to
`docs/architecture.md`), and add a dated line to `docs/log.md`.
