# New Design Catalog Component

Use this prompt to start a new component design doc in `design/`.

Component: `<NAME>` -- kind: `<widget|primitive>`

## Steps

1. Use the `design-catalog` skill. Read `design/README.md` (at minimum the status ladder,
   wireframe conventions, and table schemas) and `design/tokens.md`.
2. Copy the matching file from `design/templates/` into `design/widgets/` or
   `design/primitives/` with a lowercase-hyphen filename; set `status: sketch`.
3. Research prior art before drawing anything. Check the local ratatui checkout
   (`~/Developer/ratatui/ratatui/main/ratatui-widgets/src/`), bubbles, Textual, and
   SwiftUI. Record what to copy and what to reject, with paths.
4. Sweep `design/inbox.md` for entries about this component; move them into the doc's
   Inspiration section.
5. Write the overview and the state model first: what does the app own (bindings), what is
   ephemeral (`NodeState`), what is styling (`Environment`)? For widgets, the controlled
   rule from `docs/Spec.md` Slice 7 is non-negotiable.
6. Draw the anatomy wireframe. Generate grids programmatically or verify with
   `scripts/check-wireframes.py`; never hand-count widths. Name every region in the
   callouts.
7. Fill the behavior tables against the schemas in `design/README.md#table-schemas`. List
   primitive dependencies and flag missing ones.
8. Add the component to the index in `design/README.md`, then validate:

   ```fish
   scripts/check-wireframes.py design/
   pnpx markdownlint-cli design/
   prettier --check "design/**/*.md"
   ```

Stop at the highest status the content honestly earns; do not inflate the frontmatter.
List what blocks the next promotion.
