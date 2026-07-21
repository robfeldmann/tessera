set shell := ["bash", "-c"]
set working-directory := '..'

# ── CI ───────────────────────────────────────────────────────────────────────

# Run the full local CI gate: core tests followed by portable quality checks.
default: check

# Run core tests followed by strict portable quality checks.
check:
    just core test
    just quality lint

# Build libghostty-vt, then build and test the package.
build-test:
    just core build-libghostty-vt
    swift build
    swift test --no-parallel

# Build and test on Windows, honoring TESSERA_CI_WINDOWS_TEST_FILTER.
ci-windows:
    swift build
    if [[ -n "${TESSERA_CI_WINDOWS_TEST_FILTER:-}" ]]; then swift test --no-parallel --filter "$TESSERA_CI_WINDOWS_TEST_FILTER"; else swift test --no-parallel; fi

# Run the strict full-repo quality gate.
lint:
    just quality lint
