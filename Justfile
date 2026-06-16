# Tessera — Swift package management
# Run `just` to see available recipes

set shell := ["bash", "-c"]
set fallback := true

# ── Default ──────────────────────────────────────────────────────────────────

default:
    @just --list

# ── Lifecycle ────────────────────────────────────────────────────────────────

build: build-libghostty-vt
    swift build

build-libghostty-vt:
    scripts/build-libghostty-vt.sh

test: build-libghostty-vt
    swift test --no-parallel

test-coverage: build-libghostty-vt
    swift test --no-parallel --enable-code-coverage

coverage-summary:
    scripts/coverage-summary.py $(swift test --show-codecov-path)

example name="":
    @set -euo pipefail; \
    example="{{name}}"; \
    if [[ -z "$example" ]]; then \
        if [[ -t 0 ]] && [[ "$(just examples-list | wc -l | tr -d ' ')" == "1" ]]; then \
            example="$(just examples-list)"; \
        elif [[ -t 0 ]] && command -v fzf &> /dev/null; then \
            example="$(just examples-list | fzf --prompt='Example> ')"; \
        else \
            echo "Available examples:"; \
            just examples-list | sed 's/^/  /'; \
            echo "Run: just example <name>"; \
            exit 1; \
        fi; \
    fi; \
    swift run --package-path Examples "$example"

examples:
    swift build --package-path Examples

examples-list:
    @swift package --package-path Examples describe --type json | python3 -c 'import json, sys; package = json.load(sys.stdin); print("\n".join(sorted(product["name"] for product in package["products"] if "executable" in product["type"])))'

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
    @set -euo pipefail; \
    if ! command -v limactl &> /dev/null; then \
        echo "⚠️  limactl not found — run 'brew bundle install'"; \
        exit 1; \
    fi; \
    status="$(limactl list --json | python3 -c 'import json, sys; print(next((json.loads(line)["status"] for line in sys.stdin if json.loads(line)["name"] == "tessera-linux"), ""))')"; \
    project_dir="$(limactl list --json | python3 -c 'import json, sys; print(next((json.loads(line).get("param", {}).get("ProjectDir", "") for line in sys.stdin if json.loads(line)["name"] == "tessera-linux"), ""))')"; \
    started_vm=0; \
    if [[ -z "$status" ]]; then \
        limactl --yes start --name=tessera-linux --mount-only "$PWD:w" --param ProjectDir="$PWD" scripts/config/lima/tessera-linux.yaml; \
        started_vm=1; \
    elif [[ "$project_dir" != "$PWD" && "$status" != "Running" ]]; then \
        limactl delete --force tessera-linux; \
        limactl --yes start --name=tessera-linux --mount-only "$PWD:w" --param ProjectDir="$PWD" scripts/config/lima/tessera-linux.yaml; \
        started_vm=1; \
    elif [[ "$project_dir" != "$PWD" ]]; then \
        echo "⚠️  tessera-linux is already running for $project_dir, not $PWD"; \
        exit 1; \
    elif [[ "$status" != "Running" ]]; then \
        limactl start tessera-linux; \
        started_vm=1; \
    fi; \
    cleanup() { \
        if [[ "$started_vm" == "1" ]]; then \
            limactl stop tessera-linux; \
        fi; \
    }; \
    trap cleanup EXIT; \
    limactl shell tessera-linux -- bash -lc "source ~/.local/share/swiftly/env.sh && export PATH=~/.local/bin:\$PATH && cd '$PWD' && rm -rf .build/aarch64-unknown-linux-gnu/debug/ModuleCache* .build/x86_64-unknown-linux-gnu/debug/ModuleCache* && scripts/build-libghostty-vt.sh && swift test --jobs 2 --no-parallel"

# ── Windows ──────────────────────────────────────────────────────────────────

windows-vm-start:
    @set -euo pipefail; \
    vm="${TESSERA_WINDOWS_VM_NAME:-tessera-windows}"; \
    if ! command -v utmctl &> /dev/null; then \
        echo "⚠️  utmctl not found — run 'brew bundle install'"; \
        exit 1; \
    fi; \
    utmctl start --hide "$vm"

windows-vm-stop:
    @set -euo pipefail; \
    vm="${TESSERA_WINDOWS_VM_NAME:-tessera-windows}"; \
    if ! command -v utmctl &> /dev/null; then \
        echo "⚠️  utmctl not found — run 'brew bundle install'"; \
        exit 1; \
    fi; \
    utmctl stop --request "$vm"

windows-vm-status:
    @set -euo pipefail; \
    vm="${TESSERA_WINDOWS_VM_NAME:-tessera-windows}"; \
    if ! command -v utmctl &> /dev/null; then \
        echo "⚠️  utmctl not found — run 'brew bundle install'"; \
        exit 1; \
    fi; \
    utmctl status "$vm"

windows-vm-ip:
    @set -euo pipefail; \
    vm="${TESSERA_WINDOWS_VM_NAME:-tessera-windows}"; \
    if ! command -v utmctl &> /dev/null; then \
        echo "⚠️  utmctl not found — run 'brew bundle install'"; \
        exit 1; \
    fi; \
    ip="$(utmctl ip-address "$vm" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$$' | head -1)"; \
    if [[ -z "$ip" ]]; then \
        echo "⚠️  No IPv4 address found for $vm. Is the VM running with UTM Guest Tools installed?"; \
        exit 1; \
    fi; \
    echo "$ip"

windows-vm-push-setup-script:
    @set -euo pipefail; \
    vm="${TESSERA_WINDOWS_VM_NAME:-tessera-windows}"; \
    path="${TESSERA_WINDOWS_VM_SETUP_PATH:-C:\\Windows\\Temp\\setup-windows-vm.ps1}"; \
    if ! command -v utmctl &> /dev/null; then \
        echo "⚠️  utmctl not found — run 'brew bundle install'"; \
        exit 1; \
    fi; \
    if [[ ! -f scripts/setup-windows-vm.ps1 ]]; then \
        echo "⚠️  scripts/setup-windows-vm.ps1 not found"; \
        exit 1; \
    fi; \
    output="$(utmctl file push "$vm" "$path" < scripts/setup-windows-vm.ps1 2>&1)" || { echo "$output"; exit 1; }; \
    if echo "$output" | grep -E "Error from event:|failed to open file" > /dev/null; then \
        echo "$output"; \
        exit 1; \
    fi; \
    if [[ -n "$output" ]]; then echo "$output"; fi; \
    echo "✅ Pushed scripts/setup-windows-vm.ps1 to $vm:$path"

windows-vm-check:
    @set -euo pipefail; \
    host="${TESSERA_WINDOWS_VM_SSH:-}"; \
    if [[ -z "$host" ]]; then \
        echo "⚠️  TESSERA_WINDOWS_VM_SSH is not set"; \
        echo "Set it to your Windows VM SSH target, for example:"; \
        echo "  set -x TESSERA_WINDOWS_VM_SSH tessera-windows"; \
        echo "See CONTRIBUTING.md#windows-test-runs-with-utm for VM setup."; \
        exit 1; \
    fi; \
    ssh -o BatchMode=yes -o ConnectTimeout=5 $host "swift --version"

windows-vm-ssh:
    @set -euo pipefail; \
    host="${TESSERA_WINDOWS_VM_SSH:-}"; \
    if [[ -z "$host" ]]; then \
        echo "⚠️  TESSERA_WINDOWS_VM_SSH is not set"; \
        echo "See CONTRIBUTING.md#windows-test-runs-with-utm for VM setup."; \
        exit 1; \
    fi; \
    ssh $host

test-windows-vm:
    @set -euo pipefail; \
    host="${TESSERA_WINDOWS_VM_SSH:-}"; \
    repo="${TESSERA_WINDOWS_VM_REPO:-tessera}"; \
    if [[ -z "$host" ]]; then \
        echo "⚠️  TESSERA_WINDOWS_VM_SSH is not set"; \
        echo "Set it to your Windows VM SSH target, then rerun this recipe."; \
        echo "See CONTRIBUTING.md#windows-test-runs-with-utm for VM setup."; \
        exit 1; \
    fi; \
    if ! ssh -o BatchMode=yes -o ConnectTimeout=5 $host "swift --version"; then \
        echo "⚠️  Windows VM is unreachable or Swift is not installed."; \
        echo "Run scripts/setup-windows-vm.ps1 inside the VM and verify SSH access."; \
        exit 1; \
    fi; \
    ssh $host "cd $repo && swift test --no-parallel"

# Install a macOS public key into the guest's administrators_authorized_keys so
# the BatchMode SSH recipes work unattended. Uses password SSH for this one-time
# step (you will be prompted for the Windows password), so it does not depend on
# key auth already working. Override the key with TESSERA_WINDOWS_VM_PUBKEY.
windows-vm-install-ssh-key:
    @set -euo pipefail; \
    vm="${TESSERA_WINDOWS_VM_NAME:-tessera-windows}"; \
    user="${TESSERA_WINDOWS_VM_USER:-tess}"; \
    pubkey="${TESSERA_WINDOWS_VM_PUBKEY:-$HOME/.ssh/tessera_windows.pub}"; \
    if ! command -v utmctl &> /dev/null; then \
        echo "⚠️  utmctl not found — run 'brew bundle install'"; \
        exit 1; \
    fi; \
    if [[ ! -f "$pubkey" ]]; then \
        echo "⚠️  Public key not found: $pubkey"; \
        echo "Generate one: ssh-keygen -t ed25519 -f ~/.ssh/tessera_windows -N \"\""; \
        exit 1; \
    fi; \
    ip="$(utmctl ip-address "$vm" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$$' | head -1)"; \
    if [[ -z "$ip" ]]; then \
        echo "⚠️  No IPv4 address found for $vm. Is the VM running with UTM Guest Tools installed?"; \
        exit 1; \
    fi; \
    key="$(cat "$pubkey")"; \
    echo "Installing SSH key for $user@$ip (you may be prompted for the Windows password)..."; \
    printf '%s\n' \
        "\$ErrorActionPreference = 'Stop'" \
        "\$dst = 'C:\\ProgramData\\ssh\\administrators_authorized_keys'" \
        "\$key = '$key'" \
        "New-Item -ItemType Directory -Force C:\\ProgramData\\ssh | Out-Null" \
        "if (-not (Test-Path \$dst) -or -not ((Get-Content \$dst) -contains \$key)) { Add-Content -Path \$dst -Value \$key }" \
        "icacls \$dst /inheritance:r /grant Administrators:F /grant SYSTEM:F | Out-Null" \
        "Write-Host 'Key installed.'" \
    | ssh -o PreferredAuthentications=password -o PubkeyAuthentication=no "$user@$ip" "powershell -NoProfile -Command -"; \
    echo "✅ Try: just windows-vm-check"

# Push the current local branch straight into the guest checkout over SSH so you
# can edit on macOS and test on Windows without going through GitHub. Relies on
# `receive.denyCurrentBranch=updateInstead` (configured here) to update the guest
# working tree in place; the guest tree must be clean for the push to apply.
windows-vm-sync:
    @set -euo pipefail; \
    host="${TESSERA_WINDOWS_VM_SSH:-}"; \
    repo="${TESSERA_WINDOWS_VM_REPO:-tessera}"; \
    if [[ -z "$host" ]]; then \
        echo "⚠️  TESSERA_WINDOWS_VM_SSH is not set"; \
        echo "See docs/WindowsVM.md for VM setup."; \
        exit 1; \
    fi; \
    branch="$(git rev-parse --abbrev-ref HEAD)"; \
    if ! ssh -o BatchMode=yes -o ConnectTimeout=5 "$host" "cd $repo && git --version" > /dev/null 2>&1; then \
        echo "⚠️  Cannot reach the guest repo '$repo' on '$host'."; \
        echo "Check the VM is running and 'just windows-vm-check' succeeds."; \
        exit 1; \
    fi; \
    ssh "$host" "cd $repo && git config receive.denyCurrentBranch updateInstead"; \
    echo "Pushing $branch to $host:$repo ..."; \
    git push --force-with-lease "$host:$repo" "HEAD:$branch"; \
    ssh "$host" "cd $repo && git log -1 --oneline && git status -sb"

# ── Windows Frost prototype ──────────────────────────────────────────────────

windows-frost-doctor:
    scripts/windows-frost-doctor.sh

windows-frost-env:
    scripts/windows-frost.sh env

windows-frost-help:
    scripts/windows-frost.sh help

windows-frost-dry-run:
    scripts/windows-frost.sh dry-run

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

lint-changed:
    scripts/lint-changed.sh

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

# Matches the DocC validation command run by CI.
lint-docs: docs-clean docs-targets docs-merge
    @echo "✅ Documentation is clean"

# ── CI ───────────────────────────────────────────────────────────────────────

check: lint test

ci: ci-build-test

ci-build-test: build-libghostty-vt
    swift build
    swift test --no-parallel

ci-lint: lint

# ── Documentation ────────────────────────────────────────────────────────────

docs: docs-clean docs-targets docs-merge docs-transform
    @echo "✅ Documentation generated in .build/docs"

docs-clean:
    rm -rf .build/docs .build/doccarchives
    mkdir -p .build/doccarchives/targets

docs-targets: build-libghostty-vt
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
