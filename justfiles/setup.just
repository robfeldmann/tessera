set shell := ["bash", "-c"]
set working-directory := '..'

# ── Setup ────────────────────────────────────────────────────────────────────

# Install pre-commit and commit-message hooks.
hooks:
    pre-commit install
    pre-commit install --hook-type commit-msg
    @echo "✅ Pre-commit hooks installed"
