---
description: Start a new design catalog component page from its template, with prior art and an index row.
argument-hint: <Name> <widget|primitive>
---

# New design catalog component

Start a new component design page in `docs/design/`.

Component: `$1` -- kind: `$2` (`widget` or `primitive`)

## Steps

1. Use the `design-catalog` skill. Read `docs/design.md` (at minimum the status ladder, wireframe conventions, and table schemas) and `docs/design/tokens.md`.
2. Copy the matching file from `docs/design/templates/` into `docs/design/widgets/` or `docs/design/primitives/` with a lowercase-hyphen filename; set `status: sketch`.
3. Research prior art before drawing anything. Check the local ratatui checkout (`~/Developer/ratatui/ratatui/main/ratatui-widgets/src/`), bubbles, Textual, and SwiftUI. Record what to copy and what to reject, with paths.
4. Sweep `docs/design/inbox.md` for entries about this component; move them into the doc's Inspiration section.
5. Write the overview and the state model first: what does the app own (bindings), what is ephemeral (`NodeState`), what is styling (`Environment`)? For widgets, the controlled rule from `docs/spec.md` Slice 7 is non-negotiable.
6. Draw the anatomy wireframe. Generate grids programmatically or verify with `scripts/check-wireframes.py`; never hand-count widths. Name every region in the callouts.
7. Fill the behavior tables against the schemas in `docs/design.md#table-schemas`. List primitive dependencies and flag missing ones.
8. Add the component to the index in `docs/design.md`, then validate:

   ```fish
   scripts/check-wireframes.py design/
   mise exec -- rumdl check docs/design
   prettier --check "design/**/*.md"
   ```

Stop at the highest status the content honestly earns; do not inflate the frontmatter. List what blocks the next promotion.
