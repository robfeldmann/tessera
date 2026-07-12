set shell := ["bash", "-c"]
set working-directory := '..'

# ── Frost Windows VM ────────────────────────────────────────────────────────

# Check Frost Windows VM host prerequisites and configuration.
doctor:
    scripts/windows-frost-doctor.sh

# Print the Frost Windows VM environment configuration.
env:
    scripts/windows-frost.sh env

# Show Frost Windows VM helper usage.
help:
    scripts/windows-frost.sh help

# Print planned Frost VM operations without applying changes.
dry-run:
    scripts/windows-frost.sh dry-run

# Build the reusable Frost Windows base image.
build-base *args:
    scripts/windows-frost-build-base.sh {{ args }}

# Verify that the Frost Windows base image is available.
check-base:
    scripts/windows-frost.sh check-base

# Provision the Swift toolchain inside the Frost Windows VM.
provision-toolchain *args:
    scripts/windows-frost-provision-toolchain.sh {{ args }}

# Verify the Swift toolchain inside the Frost Windows VM.
check-toolchain:
    scripts/windows-frost-check-toolchain.sh

# Sync the local source tree into the Frost Windows VM.
sync-source:
    scripts/windows-frost-sync-source.sh

# Sync Frost VM state from a UTM Windows host.
sync-utm host="":
    @set -euo pipefail; \
    if [[ -n "{{ host }}" ]]; then \
        scripts/windows-frost-sync-utm.sh "{{ host }}"; \
    else \
        scripts/windows-frost-sync-utm.sh; \
    fi

# Install UTM guest tools in the Frost Windows VM.
install-utm-tools host="":
    @set -euo pipefail; \
    if [[ -n "{{ host }}" ]]; then \
        scripts/windows-frost-install-utm-tools.sh "{{ host }}"; \
    else \
        scripts/windows-frost-install-utm-tools.sh; \
    fi

# Configure Frost Windows VM GUI settings.
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

# Start the Frost Windows VM.
start *args:
    scripts/windows-frost-start.sh {{ args }}

# Stop the Frost Windows VM.
stop:
    scripts/windows-frost-stop.sh

# Open an SSH session or run a command in the Frost Windows VM.
ssh *args:
    scripts/windows-frost-ssh.sh {{ args }}

# Run a quick Windows ConPTY smoke test in the Frost VM.
conpty-smoke:
    scripts/windows-frost-conpty-smoke.sh
