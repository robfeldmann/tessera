---
name: Risk-Driven Test Coverage
date: 2026-06-10
status: resolved
---

# Risk-Driven Test Coverage

## Question

Can Tessera's terminal lifecycle, POSIX I/O, ANSI encoding, and cancellation-sensitive
paths be covered with deterministic tests while improving production coverage to at least
85%?

## Findings

- Baseline from the plan was 65.26% production-source line coverage, measured with
  `swift test --enable-code-coverage` and the project-scoped coverage JSON.
- Added `scripts/coverage-summary.py` and `just core coverage-summary` to report project
  source totals, production Swift totals, and per-module line coverage from SwiftPM's
  llvm-cov JSON.
- Added deterministic test seams using task-local syscall overrides for POSIX write, poll,
  input-loop pipe/read/write/close/fcntl behavior. Task-local overrides avoid cross-test
  interference under Swift Testing parallel execution.
- Added deterministic resize tests by factoring resize notifications from signal delivery.
  The live path still uses `DispatchSourceSignal` for `SIGWINCH`.
- Added PTY-backed macOS live-terminal tests for alternate screen bytes, raw mode
  restoration, size querying, and output writes.
- Final coverage after implementation:
  - All project `Sources/`: 88.07% lines, 87.17% functions, 87.28% regions.
  - Production Swift sources: 85.04% lines, 85.79% functions, 88.89% regions.
  - `TesseraTerminalIO`: 90.27% line coverage.
- Remaining lower coverage is concentrated in `TesseraTerminalANSI` at 71.05% line
  coverage. The uncovered lines are mostly exhaustive encoder branches or defensive helper
  paths; wire behavior now has broad direct byte and virtual-terminal coverage.

## Conclusion

The risk-driven target was met: production Swift line coverage is above 85%, terminal I/O
coverage is above 90%, and the highest-risk terminal lifecycle and POSIX failure paths now
have deterministic tests. Further coverage work should focus only on materially risky ANSI
branches rather than chasing percentage-only gaps.
