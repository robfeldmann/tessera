---
name: planning
description:
  Use when the user asks to plan, design, or scope multi-step work before implementation.
version: 0.1.0
---

# Planning

Plans are numbered markdown files in `.agents/plans/` that decompose work into phases and
steps. They outlive chat sessions and allow resuming work from any point.

## File Naming

`NNN-kebab-case-slug.md` where `NNN` is a zero-padded 3-digit sequence number.

- `001-rack-model.md` ✅
- `rack-model.md` ❌ (no number)
- `1-rack.md` ❌ (not zero-padded)

Find the next number: `ls .agents/plans/ | grep -E '^[0-9]{3}-' | sort | tail -1` then
increment.

## Plan Structure

Every plan MUST have:

1. **YAML frontmatter** (name, description, status, dates).
2. **Progress checklist** (flat task list of all phases and steps).
3. **Overview** (2–6 sentences: what and why).
4. **Phases with Steps** (each step specifies files touched, what to do, acceptance
   criteria).

```yaml
---
name: Plan Name
description: One-line description of what this plan delivers.
status: pending # pending | in-progress | completed
created: YYYY-MM-DD
updated: YYYY-MM-DD
---
```

## Progress Checklist

A flat task list right after the frontmatter. This is what a returning agent reads first.

```markdown
## Progress

- [ ] **Phase 1 — Types & scaffolding**
  - [ ] 1.1 Add `Foo` interface and `Bar` union type
  - [ ] 1.2 Export from `src/index.ts`
- [ ] **Phase 2 — Business logic**
  - [ ] 2.1 Implement `processFoo(foo)`
  - [ ] 2.2 Implement `findBars(foo)`
```

Tick boxes (`[x]`) as work completes. A phase is checked only when all its steps are.

## Phases & Steps

Each **phase** is a named milestone. Each **step** is concrete and small enough for a
single agent turn.

```markdown
## Phase 1 — Types & scaffolding

**Goal**: Introduce the data model without changing runtime behaviour.

### Step 1.1 — Add `Foo` and `Bar` types

- File: `src/types.ts`
- Add `Foo` interface and `Bar` union type.
- Acceptance: `npm run typecheck` passes.
```

```markdown
## Phase 2 — Business logic

**Goal**: Implement core operations over the data model.

### Step 2.1 — Implement `processFoo(foo)`

- File: `src/service.ts`
- Implement `processFoo()` that validates and transforms a `Foo`.
- Acceptance: unit tests in `src/service.test.ts` pass.

### Step 2.2 — Implement `findBars(foo)`

- File: `src/service.ts`
- Implement `findBars()` that returns matching `Bar` values for a given `Foo`.
- Acceptance: unit tests pass; `npm run typecheck` passes.
```

## How to Create a Plan

1. Pick the next zero-padded number.
2. Create `.agents/plans/NNN-slug.md` with the structure above.
3. Status starts at `pending`.
4. Show the user the plan before implementing — they may want to revise.
5. Do **not** start implementation unless the user says to.

## How to Execute a Plan

1. **Read the entire plan** first — frontmatter, progress, all phases.
2. Find the first unchecked step in the lowest unchecked phase.
3. **Implement that single step**, respecting its acceptance criteria.
4. **Update the plan**: tick the step, bump `updated`, set `status: in-progress` if
   needed.
5. If all steps in a phase are complete, tick the phase checkbox.
6. After completing each phase, pause and await user review and explicit approval before
   proceeding to the next phase.
7. When every phase is complete, set `status: completed`.
8. If a step turns out to be wrong, **edit the plan first** (add/split/remove steps), then
   resume.

## Plan Template

```markdown
---
name: <Plan name>
description: <One-line description>
status: pending
created: YYYY-MM-DD
updated: YYYY-MM-DD
---

## Progress

- [ ] **Phase 1 — <name>**
  - [ ] 1.1 <step>
  - [ ] 1.2 <step>
- [ ] **Phase 2 — <name>**
  - [ ] 2.1 <step>

## Overview

<2–6 sentences: what and why.>

## Phase 1 — <name>

**Goal**: <what this phase delivers>

### Step 1.1 — <title>

- File: `path/to/file.ts`
- <what to do>
- Acceptance: <how we know it's done>

### Step 1.2 — <title>

- File: `...`
- <what to do>
- Acceptance: <...>

## Phase 2 — <name>

...

## References

- <links to docs, related plans, etc.>
```
