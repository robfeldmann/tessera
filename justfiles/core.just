set shell := ["bash", "-c"]
set working-directory := '..'

# ── Lifecycle ────────────────────────────────────────────────────────────────

build: build-libghostty-vt
    swift build

build-libghostty-vt:
    scripts/build-libghostty-vt.sh

doctor:
    scripts/dev-state.sh

clean-libghostty-vt:
    @set -euo pipefail; \
    cache_home="${XDG_CACHE_HOME:-${HOME:-$PWD/.build}/.cache}"; \
    output_root="${GHOSTTY_VT_OUTPUT_DIR:-$cache_home/tessera/libghostty-vt}"; \
    rm -rf "$output_root"; \
    echo "Removed $output_root"

test: build-libghostty-vt
    swift test --no-parallel

test-coverage: build-libghostty-vt
    swift test --no-parallel --enable-code-coverage

coverage-summary:
    scripts/coverage-summary.py $(swift test --show-codecov-path)

example name="":
    @set -euo pipefail; \
    example="{{ name }}"; \
    if [[ -z "$example" ]]; then \
        if [[ -t 0 ]] && [[ "$(just core examples-list | wc -l | tr -d ' ')" == "1" ]]; then \
            example="$(just core examples-list)"; \
        elif [[ -t 0 ]] && command -v fzf &> /dev/null; then \
            example="$(just core examples-list | fzf --prompt='Example> ')"; \
        else \
            echo "Available examples:"; \
            just core examples-list | sed 's/^/  /'; \
            echo "Run: just core example <name>"; \
            exit 1; \
        fi; \
    fi; \
    swift run --package-path Examples "$example"

examples:
    swift build --package-path Examples

examples-list:
    @swift package --package-path Examples describe --type json | python3 -c 'import json, sys; package = json.load(sys.stdin); print("\n".join(sorted(product["name"] for product in package["products"] if "executable" in product["type"])))'

swift-version:
    @cat .swift-version

install-swift:
    swiftly install

clean:
    rm -rf .build
