# Promote a Design Catalog Doc

Use this prompt to review a component doc in `design/` for promotion to its next status.

Doc: `design/<kind>/<name>.md` -- target status: `<wireframed|specified|ready>`

## Steps

1. Use the `design-catalog` skill. Read the promotion gate for the target status in
   `design/README.md#status-ladder`; the gate is the checklist, verbatim.
2. Verify mechanically first:
   - `scripts/check-wireframes.py design/<kind>/<name>.md`
   - `pnpx markdownlint-cli design/<kind>/<name>.md`
3. Verify against the schemas (`design/README.md#table-schemas`):
   - every table has exactly the schema columns and closed-vocabulary values;
   - every key/mouse precondition references only declared state-model rows;
   - every mouse Region is named in the anatomy callouts;
   - every requirement traces to a table row or wireframe state;
   - the sizing table has its mandatory rows with exact integers.
4. For `ready` additionally: every primitive dependency is `ready` or `implemented` in the
   README index; every open question is resolved or explicitly deferred with a destination
   (Spec.md section or issue); the doc does not contradict the Phase 4 theses in
   `docs/Spec.md`.
5. Report violations as a list with file/section references. Only if all gates pass:
   update the frontmatter status and the README index row.

Do not fix substantive design gaps silently during review; report them. Mechanical fixes
(width slips, broken anchors) may be applied directly.
