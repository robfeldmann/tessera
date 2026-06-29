set shell := ["bash", "-c"]
set working-directory := '..'

linux_vm_name := env_var_or_default("TESSERA_LINUX_VM_NAME", "tessera-linux")

# ── Linux ────────────────────────────────────────────────────────────────────

sdk-id:
    @scripts/linux-sdk-id.sh

install-sdk:
    scripts/install-linux-sdk.sh

build: install-sdk
    swift build --swift-sdk $(scripts/linux-sdk-id.sh)

start:
    @if ! command -v limactl &> /dev/null; then \
        echo "⚠️  limactl not found — run 'brew bundle install'"; \
        exit 1; \
    fi
    limactl --yes start --name={{ linux_vm_name }} --mount-only "$PWD:w" --param ProjectDir="$PWD" scripts/config/lima/tessera-linux.yaml

shell:
    @if ! command -v limactl &> /dev/null; then \
        echo "⚠️  limactl not found — run 'brew bundle install'"; \
        exit 1; \
    fi
    limactl shell {{ linux_vm_name }}

stop:
    limactl stop {{ linux_vm_name }}

delete:
    limactl delete {{ linux_vm_name }}

test:
    @set -euo pipefail; \
    if ! command -v limactl &> /dev/null; then \
        echo "⚠️  limactl not found — run 'brew bundle install'"; \
        exit 1; \
    fi; \
    status="$(limactl list --json | python3 -c 'import json, sys; print(next((json.loads(line)["status"] for line in sys.stdin if json.loads(line)["name"] == "{{ linux_vm_name }}"), ""))')"; \
    project_dir="$(limactl list --json | python3 -c 'import json, sys; print(next((json.loads(line).get("param", {}).get("ProjectDir", "") for line in sys.stdin if json.loads(line)["name"] == "{{ linux_vm_name }}"), ""))')"; \
    started_vm=0; \
    if [[ -z "$status" ]]; then \
        limactl --yes start --name={{ linux_vm_name }} --mount-only "$PWD:w" --param ProjectDir="$PWD" scripts/config/lima/tessera-linux.yaml; \
        started_vm=1; \
    elif [[ "$project_dir" != "$PWD" && "$status" != "Running" ]]; then \
        limactl delete --force {{ linux_vm_name }}; \
        limactl --yes start --name={{ linux_vm_name }} --mount-only "$PWD:w" --param ProjectDir="$PWD" scripts/config/lima/tessera-linux.yaml; \
        started_vm=1; \
    elif [[ "$project_dir" != "$PWD" ]]; then \
        echo "⚠️  {{ linux_vm_name }} is already running for $project_dir, not $PWD"; \
        exit 1; \
    elif [[ "$status" != "Running" ]]; then \
        limactl start {{ linux_vm_name }}; \
        started_vm=1; \
    fi; \
    cleanup() { \
        if [[ "$started_vm" == "1" ]]; then \
            limactl stop {{ linux_vm_name }}; \
        fi; \
    }; \
    trap cleanup EXIT; \
    limactl shell {{ linux_vm_name }} -- bash -lc "source ~/.local/share/swiftly/env.sh && export PATH=~/.local/bin:\$PATH && cd '$PWD' && rm -rf .build/aarch64-unknown-linux-gnu/debug/ModuleCache* .build/x86_64-unknown-linux-gnu/debug/ModuleCache* && scripts/build-libghostty-vt.sh && swift test --jobs 2 --no-parallel"
