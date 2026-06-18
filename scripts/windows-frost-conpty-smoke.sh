#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
# shellcheck source=scripts/windows-frost-env.sh
source "$repo_root/scripts/windows-frost-env.sh"

SSH_KEY="${TESSERA_FROST_SSH_KEY:-$HOME/.ssh/tessera_windows}"
SSHOPTS=(-tt -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10)
if [[ -f "$SSH_KEY" ]]; then
  SSHOPTS+=(-i "$SSH_KEY")
fi

ps_script='$esc=[char]27; Write-Host "ConPTY ANSI smoke"; Write-Host "$esc[31mred$esc[0m $esc[32mgreen$esc[0m $esc[34mblue$esc[0m"; Write-Host "cursor save/restore:$esc[s here$esc[u done"'
encoded="$(printf '%s' "$ps_script" | iconv -f UTF-8 -t UTF-16LE | base64 | tr -d '\n')"
ssh_command=(ssh "${SSHOPTS[@]}" -p "$TESSERA_FROST_SSH_PORT" "$TESSERA_FROST_USER@localhost" powershell -NoProfile -EncodedCommand "$encoded")

if [[ -t 0 ]]; then
  exec "${ssh_command[@]}"
fi

# CI/agent shells often do not provide a local TTY. Wrap ssh in script(1) so
# OpenSSH can allocate a real local pseudo-terminal while still forcing a Windows
# ConPTY on the remote side.
exec script -q /dev/null "${ssh_command[@]}"
