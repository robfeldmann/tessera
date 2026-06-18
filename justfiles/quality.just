set shell := ["bash", "-c"]
set working-directory := '..'

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

lint: swift swiftlint markdown docs
    @echo "✅ All lint checks passed"

changed:
    scripts/lint-changed.sh

swift:
    swift-format lint -r Sources Tests Package.swift

swiftlint:
    swiftlint

markdown:
    @if command -v prettier &> /dev/null; then \
        prettier --check "**/*.md"; \
    else \
        echo "⚠️  prettier not found — skip markdown linting (pnpm add -g prettier)"; \
    fi

docs:
    just docs lint
