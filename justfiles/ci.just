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

lint:
    just quality lint
