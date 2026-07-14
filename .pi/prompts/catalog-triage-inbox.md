# Triage the Design Catalog Inbox

Use this prompt to process `design/inbox.md`.

## Steps

1. Use the `design-catalog` skill.
2. For each entry under `## Entries`, decide one of:
   - **Move**: the entry concerns an existing component -- append it to that doc's
     Inspiration section (keep the date), then delete it from the inbox.
   - **Seed**: the entry deserves a new component -- create a `sketch` doc via the
     `catalog-new-component` prompt flow (template copy + prior art + index row) and move
     the entry into its Inspiration section.
   - **Escalate**: the entry challenges an architectural rule -- it belongs in
     `docs/Spec.md` discussion or an issue, not the catalog. Note the destination, move it
     there, delete from inbox.
   - **Kill**: no longer interesting -- delete, optionally with a one-line tombstone in
     the relevant doc's Open questions if the rejection is informative.
3. Never leave an entry both in the inbox and in a doc; the inbox holds only untriaged
   thoughts.
4. Validate touched files:
   `pnpx markdownlint-cli design/ && prettier --check "design/**/*.md"`.

Report a short table: entry, decision, destination.
