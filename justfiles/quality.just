set shell := ["bash", "-c"]
set working-directory := '..'

# ── Formatting ───────────────────────────────────────────────────────────────

# Auto-fix formatting and safe SwiftLint corrections.
format: _format-json _format-markdown
    swift-format format -i -r Sources Tests Package.swift Examples/Sources Examples/Package.swift
    swiftlint lint --fix --quiet --config .swiftlint.yml

# Sort JSON files when jq is available.
_format-json:
    @if command -v jq &> /dev/null; then \
        find . -name "*.json" -not -path "./.build/*" -not -path "./.git/*" | \
        while read -r file; do \
            jq --sort-keys . "$file" > "$file.tmp" && mv "$file.tmp" "$file"; \
        done; \
    else \
        echo "⚠️  jq not found — skip JSON sorting (brew install jq)"; \
    fi

# Format Markdown files when Prettier is available.
_format-markdown:
    @if command -v prettier &> /dev/null; then \
        prettier --write "**/*.md"; \
    else \
        echo "⚠️  prettier not found — skip markdown formatting (pnpm add -g prettier)"; \
    fi

# ── Linting ──────────────────────────────────────────────────────────────────

# Strict full-repo quality gate for CI, agents, and pre-PR checks.
lint: _swift-format swiftlint markdown docs
    @echo "✅ All lint checks passed"

# Strict changed-file quality gate for pre-commit/local iteration.
changed:
    scripts/lint-changed.sh

# Run the strict full-repo SwiftFormat formatting check.
_swift-format:
    swift-format lint -r Sources Tests Package.swift Examples/Sources Examples/Package.swift

# Strict SwiftLint gate; warnings fail here to prevent drift.
swiftlint:
    swiftlint lint --strict --config .swiftlint.yml

# Markdown formatting check.
markdown:
    @if command -v prettier &> /dev/null; then \
        prettier --check "**/*.md"; \
    else \
        echo "⚠️  prettier not found — skip markdown linting (pnpm add -g prettier)"; \
    fi

# DocC documentation check.
docs:
    just docs lint
