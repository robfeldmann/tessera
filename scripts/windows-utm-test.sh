#!/usr/bin/env bash
set -euo pipefail

host="${TESSERA_WINDOWS_VM_SSH:-}"
repo="${TESSERA_WINDOWS_VM_REPO:-tessera}"
if [[ "${1:-}" == "--" ]]; then
  shift
fi


if [[ -z "$host" ]]; then
  echo "⚠️  TESSERA_WINDOWS_VM_SSH is not set"
  echo "Set it to your Windows VM SSH target, then rerun this recipe."
  echo "See CONTRIBUTING.md#windows-test-runs-with-utm for VM setup."
  exit 1
fi

if ! ssh -o BatchMode=yes -o ConnectTimeout=5 "$host" "swift --version"; then
  echo "⚠️  Windows VM is unreachable or Swift is not installed."
  echo "Run scripts/setup-windows-vm.ps1 inside the VM and verify SSH access."
  exit 1
fi

swift_test_args_json="$(python3 -c 'import json, sys; print(json.dumps(sys.argv[1:]))' "$@")"
swift_test_args_b64="$(printf '%s' "$swift_test_args_json" | base64 | tr -d '\n')"

ps_repo="${repo//\'/\'\'}"
ps_args="${swift_test_args_b64//\'/\'\'}"

ssh "$host" "powershell -NoProfile -ExecutionPolicy Bypass -Command -" <<POWERSHELL
\$ErrorActionPreference = "Stop"
\$RepoPath = '$ps_repo'
\$SwiftTestArgsBase64 = '$ps_args'

function Decode-SwiftTestArgs {
    param([string]\$EncodedArgs)

    if (-not \$EncodedArgs) {
        return @()
    }

    \$json = [Text.Encoding]::UTF8.GetString(
        [Convert]::FromBase64String(\$EncodedArgs)
    )
    return @(\$json | ConvertFrom-Json)
}

Set-Location \$RepoPath
\$swiftTestArgs = Decode-SwiftTestArgs -EncodedArgs \$SwiftTestArgsBase64
\$swiftArgs = @("test", "--no-parallel") + \$swiftTestArgs

Write-Host "==> swift \$(\$swiftArgs -join ' ')"
& swift @swiftArgs
exit \$LASTEXITCODE
POWERSHELL
