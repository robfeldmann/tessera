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

# Run Linux VM tests; pass SwiftPM test args after `--`, e.g. `-- --filter FooTests`
test *args:
    scripts/linux-test.sh {{ args }}
