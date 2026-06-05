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

lint: lint-swift lint-swiftlint lint-markdown lint-docs
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

lint-docs: docs-clean docs-targets docs-merge
    @echo "✅ Documentation is clean"

# ── CI ───────────────────────────────────────────────────────────────────────

check: lint test

ci: ci-build-test

ci-build-test: build test

ci-lint: lint

# ── Documentation ────────────────────────────────────────────────────────────

docs: docs-clean docs-targets docs-merge docs-transform
    @echo "✅ Documentation generated in .build/docs"

docs-clean:
    rm -rf .build/docs .build/doccarchives
    mkdir -p .build/doccarchives/targets

docs-targets:
    @echo "▶ Building documentation for Tessera targets..."
    @set -e; \
    base_targets=( \
        TesseraCore \
        TesseraTerminalANSI \
        TesseraTerminalBuffer \
        TesseraTerminalCore \
        TesseraTerminalInput \
        TesseraTerminalIO \
        TesseraTerminalRendering \
        TesseraTerminalSnapshotSupport \
        TesseraTerminalTestSupport \
    ); \
    for target in "${base_targets[@]}"; do \
        swift package \
            --allow-writing-to-directory .build/doccarchives/targets \
            generate-documentation \
            --target "$target" \
            --disable-indexing \
            --warnings-as-errors \
            --enable-experimental-external-link-support \
            --output-path ".build/doccarchives/targets/$target.doccarchive"; \
    done; \
    dependency_args=""; \
    for archive in .build/doccarchives/targets/TesseraTerminal*.doccarchive; do \
        if [[ "$archive" != *"/TesseraTerminal.doccarchive" ]]; then \
            dependency_args="$dependency_args --dependency $archive"; \
        fi; \
    done; \
    swift package \
        --allow-writing-to-directory .build/doccarchives/targets \
        generate-documentation \
        --target TesseraTerminal \
        --disable-indexing \
        --warnings-as-errors \
        --enable-experimental-external-link-support \
        $dependency_args \
        --output-path .build/doccarchives/targets/TesseraTerminal.doccarchive; \
    dependency_args=""; \
    for archive in .build/doccarchives/targets/*.doccarchive; do \
        if [[ "$archive" != *"/Tessera.doccarchive" ]]; then \
            dependency_args="$dependency_args --dependency $archive"; \
        fi; \
    done; \
    swift package \
        --allow-writing-to-directory .build/doccarchives/targets \
        generate-documentation \
        --target Tessera \
        --disable-indexing \
        --warnings-as-errors \
        --enable-experimental-external-link-support \
        $dependency_args \
        --output-path .build/doccarchives/targets/Tessera.doccarchive

docs-merge:
    @echo "▶ Merging documentation archives..."
    rm -rf .build/doccarchives/tessera.doccarchive
    xcrun docc merge \
        .build/doccarchives/targets/Tessera.doccarchive \
        .build/doccarchives/targets/TesseraCore.doccarchive \
        .build/doccarchives/targets/TesseraTerminal.doccarchive \
        .build/doccarchives/targets/TesseraTerminalANSI.doccarchive \
        .build/doccarchives/targets/TesseraTerminalBuffer.doccarchive \
        .build/doccarchives/targets/TesseraTerminalCore.doccarchive \
        .build/doccarchives/targets/TesseraTerminalInput.doccarchive \
        .build/doccarchives/targets/TesseraTerminalIO.doccarchive \
        .build/doccarchives/targets/TesseraTerminalRendering.doccarchive \
        .build/doccarchives/targets/TesseraTerminalSnapshotSupport.doccarchive \
        .build/doccarchives/targets/TesseraTerminalTestSupport.doccarchive \
        --output-path .build/doccarchives/tessera.doccarchive \
        --synthesized-landing-page-kind "Swift Package" \
        --synthesized-landing-page-name Tessera

docs-transform:
    @echo "▶ Transforming documentation for static hosting..."
    mkdir -p .build/docs
    xcrun docc process-archive \
        transform-for-static-hosting .build/doccarchives/tessera.doccarchive \
        --hosting-base-path / \
        --output-path .build/docs

docs-preview: docs
    @if ! command -v python3 &> /dev/null; then \
        echo "⚠️  python3 not found — cannot start preview server (brew install python@3)"; \
    else \
        echo "🚀 Preview: http://localhost:8000/documentation/"; \
        python3 -m http.server --directory .build/docs 8000; \
    fi

# ── Setup ────────────────────────────────────────────────────────────────────

install-linux-sdk:
    scripts/install-linux-sdk.sh

install-hooks:
    pre-commit install
    pre-commit install --hook-type commit-msg
    @echo "✅ Pre-commit hooks installed"
