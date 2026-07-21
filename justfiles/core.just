set shell := ["bash", "-c"]
set working-directory := '..'

# ── Lifecycle ────────────────────────────────────────────────────────────────

# Build the Swift package after preparing libghostty-vt.
build: build-libghostty-vt
    swift build

# Build or reuse the pinned libghostty-vt C shim dependency.
build-libghostty-vt:
    scripts/build-libghostty-vt.sh

# Print local development environment state and dependency diagnostics.
doctor:
    scripts/dev-state.sh

# Remove the cached libghostty-vt build output.
clean-libghostty-vt:
    @set -euo pipefail; \
    cache_home="${XDG_CACHE_HOME:-${HOME:-$PWD/.build}/.cache}"; \
    output_root="${GHOSTTY_VT_OUTPUT_DIR:-$cache_home/tessera/libghostty-vt}"; \
    rm -rf "$output_root"; \
    echo "Removed $output_root"

# Run the full Swift test suite without parallel execution.
test: build-libghostty-vt
    swift test --no-parallel

# Run the full Swift test suite with code coverage enabled.
test-coverage: build-libghostty-vt
    swift test --no-parallel --enable-code-coverage

# Print a summary for the latest Swift code coverage report.
coverage-summary:
    scripts/coverage-summary.py $(swift test --show-codecov-path)

# Run an example executable, prompting when no name is supplied.
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

# Run the Tessera Showcase example directly.
showcase:
    swift run --package-path Examples TesseraShowcase

# Build all example package executables.
examples:
    swift build --package-path Examples

# List executable products in the Examples package.
examples-list:
    @swift package --package-path Examples describe --type json | python3 -c 'import json, sys; package = json.load(sys.stdin); print("\n".join(sorted(product["name"] for product in package["products"] if "executable" in product["type"])))'

# Print the Swift toolchain version pinned by this repository.
swift-version:
    @cat .swift-version

# Install the pinned Swift toolchain with swiftly.
install-swift:
    swiftly install

# Remove SwiftPM build artifacts.
clean:
    rm -rf .build
