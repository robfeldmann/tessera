# Tessera — Swift package management
# Run `just` to see available recipes

set shell := ["bash", "-c"]
set fallback := true

# ── Default ──────────────────────────────────────────────────────────────────

default:
    @just --list

# ── Lifecycle ────────────────────────────────────────────────────────────────

build:
    swift build

test:
    swift test

test-coverage:
    swift test --enable-code-coverage

swift-version:
    @cat .swift-version

install-swift:
    swiftly install

clean:
    rm -rf .build

# ── Linux ────────────────────────────────────────────────────────────────────

linux-sdk-id:
    @scripts/linux-sdk-id.sh

build-linux: install-linux-sdk
    swift build --swift-sdk $(scripts/linux-sdk-id.sh)

linux-vm-start:
    @if ! command -v limactl &> /dev/null; then \
        echo "⚠️  limactl not found — run 'brew bundle install'"; \
        exit 1; \
    fi
    limactl --yes start --name=tessera-linux --mount-only "$PWD:w" --param ProjectDir="$PWD" scripts/config/lima/tessera-linux.yaml

linux-vm-shell:
    @if ! command -v limactl &> /dev/null; then \
        echo "⚠️  limactl not found — run 'brew bundle install'"; \
        exit 1; \
    fi
    limactl shell tessera-linux

linux-vm-stop:
    limactl stop tessera-linux

linux-vm-delete:
    limactl delete tessera-linux

test-linux-vm:
    @if ! command -v limactl &> /dev/null; then \
        echo "⚠️  limactl not found — run 'brew bundle install'"; \
        exit 1; \
    fi
    limactl shell tessera-linux -- bash -lc "source ~/.local/share/swiftly/env.sh && cd '$PWD' && swift test --jobs 2"

# ── Formatting ───────────────────────────────────────────────────────────────

format: _format-json _format-markdown
    swift-format format -i -r Sources Tests Package.swift

_format-json:
    @if command -v jq &> /dev/null; then \
        find . -name "*.json" -not -path "./.build/*" -not -path "./.git/*" | \
        while read -r file; do \
            jq --sort-keys . "$file" > "$file.tmp" && mv "$file.tmp" "$file"; \
        done; \
    else \
        echo "⚠️  jq not found — skip JSON sorting (brew install jq)"; \
    fi

_format-markdown:
    @if command -v prettier &> /dev/null; then \
        prettier --write "**/*.md"; \
    else \
        echo "⚠️  prettier not found — skip markdown formatting (pnpm add -g prettier)"; \
    fi

# ── Linting ──────────────────────────────────────────────────────────────────

lint: format lint-swift lint-markdown lint-docs
    @echo "✅ All lint checks passed"

lint-swift:
    swift-format lint -r Sources Tests Package.swift

lint-swiftlint:
    swiftlint

lint-markdown:
    @if command -v prettier &> /dev/null; then \
        prettier --check "**/*.md"; \
    else \
        echo "⚠️  prettier not found — skip markdown linting (pnpm add -g prettier)"; \
    fi

lint-docs:
    swift package generate-documentation \
        --target Tessera \
        --disable-indexing \
        --warnings-as-errors \
        && echo "✅ Tessera docs are clean"
    swift package generate-documentation \
        --target TesseraTerminal \
        --disable-indexing \
        --warnings-as-errors \
        && echo "✅ TesseraTerminal docs are clean"

# ── CI ───────────────────────────────────────────────────────────────────────

ci: lint test

# ── Documentation ────────────────────────────────────────────────────────────

docs:
    swift package --disable-sandbox generate-documentation \
        --enable-experimental-combined-documentation \
        --transform-for-static-hosting \
        --hosting-base-path /tessera \
        --target Tessera \
        --target TesseraTerminal
    @mv .build/plugins/Swift-DocC/outputs/Tessera.doccarchive .build/plugins/Swift-DocC/outputs/tessera
    @echo "✅ Documentation generated in .build/plugins/Swift-DocC/outputs/tessera"

docs-preview: docs
    @if ! command -v python3 &> /dev/null; then \
        echo "⚠️  python3 not found — cannot start preview server (brew install python@3)"; \
    else \
        echo "🚀 Preview: http://localhost:8000/tessera/documentation/"; \
        cd .build/plugins/Swift-DocC/outputs && python3 -m http.server 8000; \
    fi

# ── Setup ────────────────────────────────────────────────────────────────────

install-linux-sdk:
    scripts/install-linux-sdk.sh

install-hooks:
    pre-commit install
    pre-commit install --hook-type commit-msg
    @echo "✅ Pre-commit hooks installed"
