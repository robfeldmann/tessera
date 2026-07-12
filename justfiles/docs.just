set shell := ["bash", "-c"]
set working-directory := '..'

# ── Documentation ────────────────────────────────────────────────────────────

# Build the static documentation site.
default: build

# Generate, merge, and transform DocC archives for static hosting.
build: clean targets merge transform
    @echo "✅ Documentation generated in .build/docs"

# Generate and merge DocC archives with warnings treated as errors.
lint: clean targets merge
    @echo "✅ Documentation is clean"

# Remove generated documentation output and archives.
clean:
    rm -rf .build/docs .build/doccarchives
    mkdir -p .build/doccarchives/targets

# Generate DocC archives for all documented package targets.
targets:
    just core build-libghostty-vt
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

# Merge target DocC archives into one package documentation archive.
merge:
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

# Transform the merged DocC archive for static hosting.
transform:
    @echo "▶ Transforming documentation for static hosting..."
    mkdir -p .build/docs
    xcrun docc process-archive \
        transform-for-static-hosting .build/doccarchives/tessera.doccarchive \
        --hosting-base-path / \
        --output-path .build/docs

# Build docs and serve the static output locally.
preview: build
    @if ! command -v python3 &> /dev/null; then \
        echo "⚠️  python3 not found — cannot start preview server (brew install python@3)"; \
    else \
        echo "🚀 Preview: http://localhost:8000/documentation/"; \
        python3 -m http.server --directory .build/docs 8000; \
    fi
