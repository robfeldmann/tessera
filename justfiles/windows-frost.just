set shell := ["bash", "-c"]
set working-directory := '..'

# ── Frost Windows VM ────────────────────────────────────────────────────────

doctor:
    scripts/windows-frost-doctor.sh

env:
    scripts/windows-frost.sh env

help:
    scripts/windows-frost.sh help

dry-run:
    scripts/windows-frost.sh dry-run

build-base *args:
    scripts/windows-frost-build-base.sh {{ args }}

check-base:
    scripts/windows-frost.sh check-base

provision-toolchain *args:
    scripts/windows-frost-provision-toolchain.sh {{ args }}

check-toolchain:
    scripts/windows-frost-check-toolchain.sh

sync-source:
    scripts/windows-frost-sync-source.sh

sync-utm host="":
    @set -euo pipefail; \
    if [[ -n "{{ host }}" ]]; then \
        scripts/windows-frost-sync-utm.sh "{{ host }}"; \
    else \
        scripts/windows-frost-sync-utm.sh; \
    fi

install-utm-tools host="":
    @set -euo pipefail; \
    if [[ -n "{{ host }}" ]]; then \
        scripts/windows-frost-install-utm-tools.sh "{{ host }}"; \
    else \
        scripts/windows-frost-install-utm-tools.sh; \
    fi

configure-gui host="":
    @set -euo pipefail; \
    if [[ -n "{{ host }}" ]]; then \
        scripts/windows-frost-configure-gui.sh "{{ host }}"; \
    else \
        scripts/windows-frost-configure-gui.sh; \
    fi

# Build pinned libghostty-vt in the persistent VM and cache it on the host
build-ghostty *args:
    scripts/windows-frost-build-ghostty.sh {{ args }}

# Run Windows Frost tests; pass SwiftPM test args after `--`, e.g. `-- --filter FooTests`
test *args:
    scripts/windows-frost-test.sh {{ args }}

start *args:
    scripts/windows-frost-start.sh {{ args }}

stop:
    scripts/windows-frost-stop.sh

ssh *args:
    scripts/windows-frost-ssh.sh {{ args }}

conpty-smoke:
    scripts/windows-frost-conpty-smoke.sh
