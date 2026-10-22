---
description: Triage every entry in the design catalog inbox into a component page, a new sketch, the spec, or deletion.
---

# Triage the design catalog inbox

Process every entry in `docs/design/inbox.md`.

## Steps

1. Use the `design-catalog` skill.
2. For each entry under `## Entries`, decide one of:
   - **Move**: the entry concerns an existing component -- append it to that doc's Inspiration section (keep the date), then delete it from the inbox.
   - **Seed**: the entry deserves a new component -- create a `sketch` doc via the `catalog-new-component` prompt flow (template copy + prior art + index row) and move the entry into its Inspiration section.
   - **Escalate**: the entry challenges an architectural rule -- it belongs in `docs/spec.md` discussion or an issue, not the catalog. Note the destination, move it there, delete from inbox.
   - **Kill**: no longer interesting -- delete, optionally with a one-line tombstone in the relevant doc's Open questions if the rejection is informative.
3. Never leave an entry both in the inbox and in a doc; the inbox holds only untriaged thoughts.
4. Validate touched files: `node_modules/.bin/markdownlint-cli2 docs/design.md "docs/design/**/*.md"`.

Report a short table: entry, decision, destination.
