set shell := ["bash", "-c"]
set working-directory := '..'

linux_vm_name := env_var_or_default("TESSERA_LINUX_VM_NAME", "tessera-linux")

# ── Linux ────────────────────────────────────────────────────────────────────

# Print the configured Swift SDK identifier for Linux builds.
sdk-id:
    @scripts/linux-sdk-id.sh

# Install the Swift SDK required for Linux cross-compilation.
install-sdk:
    scripts/install-linux-sdk.sh

# Build the package with the configured Linux Swift SDK.
build: install-sdk
    swift build --swift-sdk $(scripts/linux-sdk-id.sh)

# Start the Lima Linux VM for cross-platform development.
start:
    @if ! command -v limactl &> /dev/null; then \
        echo "⚠️  limactl not found — run 'brew bundle install'"; \
        exit 1; \
    fi
    limactl --yes start --name={{ linux_vm_name }} --mount-only "$PWD:w" --param ProjectDir="$PWD" scripts/config/lima/tessera-linux.yaml

# Open an interactive shell inside the Lima Linux VM.
shell:
    @if ! command -v limactl &> /dev/null; then \
        echo "⚠️  limactl not found — run 'brew bundle install'"; \
        exit 1; \
    fi
    limactl shell {{ linux_vm_name }}

# Stop the Lima Linux VM.
stop:
    limactl stop {{ linux_vm_name }}

# Delete the Lima Linux VM.
delete:
    limactl delete {{ linux_vm_name }}

# Run Linux VM tests; pass SwiftPM test args after `--`, e.g. `-- --filter FooTests`
test *args:
    scripts/linux-test.sh {{ args }}
