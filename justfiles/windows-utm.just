set shell := ["bash", "-c"]
set working-directory := '..'

# ── Manual UTM Windows VM ───────────────────────────────────────────────────

start:
    @set -euo pipefail; \
    vm="${TESSERA_WINDOWS_VM_NAME:-tessera-windows}"; \
    if ! command -v utmctl &> /dev/null; then \
        echo "⚠️  utmctl not found — run 'brew bundle install'"; \
        exit 1; \
    fi; \
    utmctl start --hide "$vm"

stop:
    @set -euo pipefail; \
    vm="${TESSERA_WINDOWS_VM_NAME:-tessera-windows}"; \
    if ! command -v utmctl &> /dev/null; then \
        echo "⚠️  utmctl not found — run 'brew bundle install'"; \
        exit 1; \
    fi; \
    utmctl stop --request "$vm"

status:
    @set -euo pipefail; \
    vm="${TESSERA_WINDOWS_VM_NAME:-tessera-windows}"; \
    if ! command -v utmctl &> /dev/null; then \
        echo "⚠️  utmctl not found — run 'brew bundle install'"; \
        exit 1; \
    fi; \
    utmctl status "$vm"

ip:
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

push-setup-script:
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

check:
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

ssh:
    @set -euo pipefail; \
    host="${TESSERA_WINDOWS_VM_SSH:-}"; \
    if [[ -z "$host" ]]; then \
        echo "⚠️  TESSERA_WINDOWS_VM_SSH is not set"; \
        echo "See CONTRIBUTING.md#windows-test-runs-with-utm for VM setup."; \
        exit 1; \
    fi; \
    ssh $host

test:
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

install-ssh-key:
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
    echo "✅ Try: just windows-utm check"

# Push the current local branch straight into the guest checkout over SSH so you
# can edit on macOS and test on Windows without going through GitHub. Relies on
# `receive.denyCurrentBranch=updateInstead` (configured here) to update the guest
# working tree in place; the guest tree must be clean for the push to apply.

sync:
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
        echo "Check the VM is running and 'just windows-utm check' succeeds."; \
        exit 1; \
    fi; \
    ssh "$host" "cd $repo && git config receive.denyCurrentBranch updateInstead"; \
    echo "Pushing $branch to $host:$repo ..."; \
    git push --force-with-lease "$host:$repo" "HEAD:$branch"; \
    ssh "$host" "cd $repo && git log -1 --oneline && git status -sb"
