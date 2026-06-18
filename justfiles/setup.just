set shell := ["bash", "-c"]
set working-directory := '..'

# ── Setup ────────────────────────────────────────────────────────────────────

hooks:
    pre-commit install
    pre-commit install --hook-type commit-msg
    @echo "✅ Pre-commit hooks installed"
