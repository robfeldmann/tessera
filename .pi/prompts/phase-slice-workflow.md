# Phase/Slice Implementation Workflow

Use this prompt when implementing the next phase or slice from `docs/Spec.md`.

## Start by planning

1. Read `AGENTS.md` and the relevant `docs/Spec.md` section.
2. Use the `planning` skill when creating or substantially revising a plan.
3. If the work is larger than one small change, create or update a numbered plan in
   `.agents/plans/`.
4. Plan steps should pair production code and tests together. This makes API review easier
   because the API and its usage are visible in the same review chunk.
5. Avoid separate "add tests later" steps unless there is a strong reason.
6. Show the plan before implementation if creating a new plan.

## API design bias

- Build the real public API shape as early as feasible, even when the implementation is
  intentionally minimal.
- Do not put phase/slice names in public API (`parsePhase1`, `Phase1Event`, etc.).
- Phase-specific names are acceptable only for private throwaway helpers.
- Keep scope small by limiting behavior, not by making intentionally temporary public API.
- Prefer living with the durable API early so design issues show up while examples/tests
  are still small.

## Test style

- Use the `pfw` and `pfw-snapshot-testing` skills before adding or substantially changing
  snapshot tests.
- Prefer snapshots for structured state humans inspect as a whole.
- Prefer direct assertions for small scalar/API-shape behavior.
- For terminal byte output, snapshots should be both exact and readable: include raw hex
  bytes plus semantic/readable text chunks.
- Put reusable custom-dump/snapshot helpers in `TesseraTerminalTestSupport`, not ad hoc in
  individual test files, when they may be useful beyond one file.
- Generate inline snapshots by writing `assertInlineSnapshot` first and letting the tool
  record them; do not hand-write large snapshots unless explicitly asked.

## Examples

- Treat runnable demos as examples, not root package targets.
- Put example apps in the separate `Examples/` package.
- Examples should depend on the root package by named path dependency:

  ```swift
  .package(name: "tessera", path: "..")
  ```

- Examples should use public products like `TesseraTerminal`/`Tessera`, not internal root
  targets, unless there is a deliberate reason.
- Use `just examples`, `just examples-list`, and `just example <Name>` for example
  workflows.

## Dependencies and concurrency

- Prefer Point-Free Dependencies for injectable live/test clients when that fits the
  problem, especially for I/O seams.
- Consult the relevant `pfw-*` skill before adding or using a Point-Free library.
- For Swift concurrency changes, avoid escape hatches like `@unchecked Sendable`,
  `@preconcurrency`, and `Task.detached` unless there is a documented safety invariant and
  a clear reason.
- Prefer actors over locks for test support state.
- If a temporary blocking bridge is necessary, document why it is safe now and where the
  spec replaces it later.

## Validation loop

During implementation:

1. Run the narrowest relevant test first, for example:

   ```fish
   swift test --filter TesseraTerminalIOTests
   swift build --package-path Examples --product HelloTessera
   ```

2. Run changed-file lint while iterating:

   ```fish
   just lint-changed
   ```

3. Run Markdown lint for edited Markdown files:

   ```fish
   pnpx markdownlint-cli <path>
   ```

4. Run targeted DocC generation when public symbols or DocC pages change.

Before committing:

```fish
just lint
swift test
```

## Commit/review flow

- Do not automatically commit the current step after implementing it. Leave it reviewable
  unless explicitly told to commit.
- After a step is approved, commit it with a Conventional Commit message.
- If a reviewed step needs API cleanup after it was already committed, make a `fixup!`
  commit for the original commit when asked.
- Keep plan progress updated as work completes.
- Pause after completing a phase and wait for explicit approval before moving to the next
  phase.

## Communication

- Be concise and direct.
- Explain tradeoffs when API/test design is uncertain.
- If a decision might not scale, call that out and either document the future direction in
  `docs/Spec.md` or update the plan so it is not forgotten.
