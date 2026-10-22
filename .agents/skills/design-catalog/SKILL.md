---
name: design-catalog
description: Work with the Tessera design catalog in docs/design/ -- component design docs for view-layer primitives and widgets. Use when creating, extending, reviewing, or promoting a component design (wireframes, interaction tables, state models), when triaging docs/design/inbox.md, or when migrating an implemented component's design into DocC.
version: 0.2.0
---

# Design catalog

The catalog in `docs/design/` (hub `docs/design.md`) holds per-component design docs for Tessera's Phase 4 view layer. `docs/spec.md` stays the architectural constitution; the catalog owns appearance, interaction tables, state models, and requirements per component.

`docs/design.md` defines every rule. This skill tells you when to read which part; it never duplicates the rules, so the hub always wins on conflict.

## Before any catalog work

1. Read `docs/design.md` in full the first time; afterwards at least the section relevant to your task.
2. Before writing or editing any behavior table, re-read `docs/design.md#table-schemas`. Tables have fixed columns and closed vocabularies; a precondition may only reference declared state-model rows, and a mouse Region only anatomy callout regions.
3. Check `docs/design/tokens.md` before inventing any glyph, color role, or viewport size.

## Creating a component doc

- Copy `docs/design/templates/widget.md` or `docs/design/templates/primitive.md` into `docs/design/widgets/` or `docs/design/primitives/`; lowercase-hyphen filename.
- Set frontmatter `status: sketch`. Statuses and promotion gates: `docs/design.md#status-ladder`. Never skip a gate silently.
- Cite prior art with concrete paths (local ratatui checkout first: `~/Developer/ratatui/ratatui/main/ratatui-widgets/src/`).
- Add the component to the index table in `docs/design.md#index`.

## Wireframes

- Fenced blocks tagged `wireframe WxH`; exactly H rows, display width <= W, trailing-trimmed, no tabs. Full rules: `docs/design.md#wireframe-conventions`.
- Do not hand-count widths. Generate or verify grids programmatically, then run `scripts/check-wireframes.py docs/design/` before considering the doc done.
- Keep the grid pristine; explanation goes in the callout list. Callouts name the regions the mouse table may reference.

## Requirements

Each requirement is a backticked sentence-style Swift Testing name (matches the project's test-naming convention) with a trace to a table row or wireframe state. When the component is implemented, this list is the test plan; write it so a test file could be transcribed from it.

## Validation before yielding

```fish
scripts/check-wireframes.py docs/design/
node_modules/.bin/markdownlint-cli2 docs/design.md "docs/design/**/*.md"
```

Both also run in `just quality lint` (the `wireframes` and `markdown` recipes). Pages carry the `kind`/`status` frontmatter of `docs/.iwe/schemas/design.yaml`; `iwe schema validate` from `docs/` checks it. One paragraph per line outside wireframes; no raw HTML.

## Graduation

When implementing a component from a `ready` doc, the definition of done includes the migration in `docs/design.md#graduation`: DocC extension file, snapshot fixtures from the wireframes, and shrinking the catalog doc to a stub. Do not leave the catalog doc as a stale duplicate of shipped docs.
