set shell := ["bash", "-c"]
set working-directory := '..'

# ── CI ───────────────────────────────────────────────────────────────────────

default: build-test

check:
    just quality lint
    just core test

build-test:
    just core build-libghostty-vt
    swift build
    swift test --no-parallel

ci-windows:
    swift build
    if [[ -n "${TESSERA_CI_WINDOWS_TEST_FILTER:-}" ]]; then swift test --no-parallel --filter "$TESSERA_CI_WINDOWS_TEST_FILTER"; else swift test --no-parallel; fi

lint:
    just quality lint
