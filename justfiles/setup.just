set shell := ["bash", "-c"]
set working-directory := '..'

# ── Setup ────────────────────────────────────────────────────────────────────

# Install the committed Lefthook hook stages.
hooks:
    lefthook install
    @echo "✅ Lefthook hooks installed"

# Create/update the project-local Python environment for pinned quality tools.
quality-tools:
    scripts/quality-python.sh --bootstrap
