set shell := ["bash", "-c"]
set working-directory := '..'

# ── CI ───────────────────────────────────────────────────────────────────────

# Run the default CI build-and-test workflow.
default: build-test

# Run strict quality checks followed by the core test suite.
check:
    just quality lint
    just core test

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
