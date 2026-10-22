---
description: Review a design catalog page against the promotion gate for its next status.
argument-hint: <kind>/<name> <wireframed|specified|ready>
---

# Promote a design catalog page

Review a component page in `docs/design/` for promotion to its next status.

Page: `docs/design/$1.md` -- target status: `$2` (`wireframed`, `specified`, or `ready`)

## Steps

1. Use the `design-catalog` skill. Read the promotion gate for the target status in `docs/design.md#status-ladder`; the gate is the checklist, verbatim.
2. Verify mechanically first:
   - `scripts/check-wireframes.py docs/design/$1.md`
   - `node_modules/.bin/markdownlint-cli2 docs/design/$1.md`
3. Verify against the schemas (`docs/design.md#table-schemas`):
   - every table has exactly the schema columns and closed-vocabulary values;
   - every key/mouse precondition references only declared state-model rows;
   - every mouse Region is named in the anatomy callouts;
   - every requirement traces to a table row or wireframe state;
   - the sizing table has its mandatory rows with exact integers.
4. For `ready` additionally: every primitive dependency is `ready` or `implemented` in the README index; every open question is resolved or explicitly deferred with a destination (Spec.md section or issue); the doc does not contradict the Phase 4 theses in `docs/spec.md`.
5. Report violations as a list with file/section references. Only if all gates pass: update the frontmatter status and the README index row.

Do not fix substantive design gaps silently during review; report them. Mechanical fixes (width slips, broken anchors) may be applied directly.
