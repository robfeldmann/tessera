---
name: investigations
description:
  Record research findings, debugging analysis, or a survey as a research page in
  docs/research/ when the user commissions it. Use when investigating root causes,
  comparing approaches, or researching APIs whose findings must outlive the session.
version: 0.2.0
---

# Research records

A research record captures what was observed, with citations, and what it means. Unlike a
plan it is exploratory: it answers "what did we learn?" rather than "what should we
build?". Records live in `docs/research/<slug>.md`, inside the `docs/` IWE workspace, and
`docs/research.md` lists them.

## When

- The user commissions a question whose answer is only knowledge: a root cause, a
  comparison of approaches or libraries, how an API or tool behaves. A commissioned
  question whose answer is work to do is a plan instead (`planning` skill), with the
  answer in its Outcome.
- Findings you turn up on your own while building go to the current plan's Discoveries,
  not to a new record.

## File and frontmatter

Slug filename, no number: `docs/research/phase-3-full-suite-hang.md`. Older records were
numbered; `docs/research.md` keeps each one's number beside its link.

```yaml
---
type: research
observed: YYYY-MM-DD # citations hold at the commit of that day
status: open # open | resolved
description: One line for docs/research.md.
---
```

The schema is `docs/.iwe/schemas/research.yaml`; `iwe schema validate` from `docs/` checks
it. Add the new record to `docs/research.md` with its date.

## Shape

```markdown
# Topic

## Question

What are we trying to find out?

## Findings

- Finding, with the evidence: a `path:line` citation, a command and its output, a link.
- Mark anything not observed as inference.

## Conclusion

What we learned and any recommended action. Set `status: resolved` once this exists.
```

One paragraph per line; relative `.md` links; no raw HTML. Line citations into the spec
stay as they were written: `docs/spec.md` was split into pages on 2026-10-22, and a
citation like `docs/Spec.md:1234` holds at the commit it cites, so older records are not
rewritten.
