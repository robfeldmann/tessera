---
name: investigations
description:
  Record findings from research, debugging, or exploratory work as markdown files in
  .agents/investigations/. Use when investigating root causes, comparing approaches,
  researching APIs, or any analysis that should be preserved for future reference.
version: 0.1.0
---

# Investigations

Investigations capture research findings, debugging results, or comparative analysis.
Unlike plans, they are exploratory — they answer "what did we learn?" rather than "what
should we build?".

## When to Create

- Debugging a non-obvious issue and discovering the root cause.
- Comparing approaches or libraries before deciding on a direction.
- Researching an API, framework, or tool whose behaviour is unclear.
- Any analysis whose findings will be useful beyond the current session.

## File Naming

`NNN-topic.md` where `NNN` is a zero-padded 3-digit sequence number.

- `000-receipt-caching-strategy.md` ✅
- `001-typebox-version-compat.md` ✅

Find the next number: `ls .agents/investigations/ | grep -E '^[0-9]{3}-' | sort | tail -1`
then increment.

## Structure

```markdown
---
name: Topic
date: YYYY-MM-DD
status: open # open | resolved
---

# Topic

## Question

What are we trying to find out?

## Findings

- Finding 1 with supporting evidence.
- Finding 2 with links or code snippets.

## Conclusion

Summary of what we learned and any recommended action.
```

Set `status: resolved` when the investigation has a clear conclusion.
