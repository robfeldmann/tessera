# Tessera — Swift package management
# Run `just` to see available recipe modules

set shell := ["bash", "-c"]
set fallback

# ── Default ──────────────────────────────────────────────────────────────────

default:
    @just --list --list-submodules

mod core 'justfiles/core.just'
mod linux 'justfiles/linux.just'
mod windows-utm 'justfiles/windows-utm.just'
mod windows-frost 'justfiles/windows-frost.just'
mod quality 'justfiles/quality.just'
mod ci 'justfiles/ci.just'
mod docs 'justfiles/docs.just'
mod setup 'justfiles/setup.just'
