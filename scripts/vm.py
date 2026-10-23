#!/usr/bin/env python3
"""Tessera's VMs: macOS guests under Tart, the Linux guest under Lima, and the Windows
guest under UTM.

docs/guides/vms.md is the guide. Disks live under ~/.local/share/vms/<manager>/: TART_HOME
and LIMA_HOME override that, and both are set for this process and its children only, so
other Tart and Lima users on the host keep their own defaults. Bases are named
`base-<os>-<version>` and are never started after they are built; work instances are named
`<project>-<os>[-<arch>][-<role>]` and are cloned from a base.

macOS bases start from a Cirrus Labs vanilla image (user `admin`, password `admin`, SSH on,
passwordless sudo) and get Xcode either from the host's installed Xcode, over a read-only
directory share, or from `xcodes` in the guest, which needs an Apple Account. The host
reaches guests with a dedicated key (~/.ssh/tessera-vm) through a generated SSH config
(~/.config/tessera/vm-ssh.config); nothing edits ~/.ssh/config. A guest's checkout is
~/tessera, delivered by macos-push and kept between runs, so `.build` stays warm.

The Windows guest is a UTM VM (docs/guides/windows-vm.md); UTM keeps its bundles in its own
container, so `utmctl` and the bundle's config.plist are the sources of truth for it.
"""

from __future__ import annotations

import argparse
import base64
import html
import json
import os
import plistlib
import re
import secrets
import shlex
import shutil
import socket
import subprocess
import sys
import tarfile
import tempfile
import threading
import time
import uuid
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
HOME = Path.home()
VM_ROOT = HOME / ".local/share/vms"
CONFIG_DIR = Path(os.environ.get("XDG_CONFIG_HOME") or HOME / ".config") / "tessera"
SSH_CONFIG = CONFIG_DIR / "vm-ssh.config"
KNOWN_HOSTS = CONFIG_DIR / "vm-known-hosts"
SSH_KEY = HOME / ".ssh/tessera-vm"

# Cirrus Labs vanilla images ship this account with SSH enabled and passwordless sudo.
GUEST_USER = "admin"
GUEST_PASSWORD = "admin"
GUEST_CHECKOUT = "tessera"
GUEST_PATH = "$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
# The host's Xcode appears here when the base is started with `--dir xcode:<app>:ro`.
GUEST_XCODE_SHARE = "/Volumes/My Shared Files/xcode"
CLONE_CPUS = "8"
CLONE_MEMORY_MB = "16384"
BOOT_TIMEOUT = 600

LINUX_CONFIG = ROOT / "scripts/config/lima/tessera-linux.yaml"

# UTM. `utmctl` drives UTM.app over Apple Events and launches it when it is not running,
# but a launch that nothing ever activated leaves `start` and `stop` hanging for two
# minutes with OSStatus -1712 (docs/plans/windows-on-utm.md, Discoveries), so the code
# below activates UTM itself and avoids Apple Events where a file answers the question.
UTM_BUNDLE_ID = "com.utmapp.UTM"
UTM_APP = Path("/Applications/UTM.app")
UTMCTL = shutil.which("utmctl") or str(UTM_APP / "Contents/MacOS/utmctl")
UTM_DOCUMENTS = HOME / "Library/Containers/com.utmapp.UTM/Data/Documents"
DHCPD_LEASES = Path("/var/db/dhcpd_leases")
WINDOWS_DEFAULT_NAME = "tessera-windows-11"
WINDOWS_USER = "tester"
# The key the existing guest trusts; new guests get SSH_KEY from windows-provision.
WINDOWS_LEGACY_KEY = HOME / ".ssh/tessera_windows"
WINDOWS_TEMP = "C:/Windows/Temp"
WINDOWS_PROVISION_SCRIPT = ROOT / "scripts/provision-windows-vm.ps1"
WINDOWS_TEMPLATE = ROOT / "scripts/config/utm/windows-11-arm64.plist"
UTM_TIMEOUT = 180


@dataclass(frozen=True)
class MacOSRelease:
    major: str
    image: str
    macos_version: str
    xcode_version: str

    @property
    def base(self) -> str:
        return f"base-macos-{self.macos_version}-xcode-{self.xcode_version}"

    @property
    def instance(self) -> str:
        return f"tessera-macos-{self.major}"

    @property
    def guest_xcode(self) -> str:
        # The name xcodes gives an install, which mise.toml's DEVELOPER_DIR looks for.
        return f"/Applications/Xcode-{self.xcode_version}.0.app"

    def host_xcodes(self) -> list[Path]:
        return [
            Path(self.guest_xcode),
            Path(f"/Applications/Xcode_{self.xcode_version}.app"),
        ]


# macOS 26 with Xcode 26.6 runs the baseline; macOS 27 with Xcode 27.1 runs the Swift 6.4
# lane (docs/architecture/toolchain-lanes.md).
RELEASES = {
    "26": MacOSRelease(
        "26", "ghcr.io/cirruslabs/macos-tahoe-vanilla:26.6.2", "26.6.2", "26.6"
    ),
    "27": MacOSRelease(
        "27", "ghcr.io/cirruslabs/macos-golden-gate-vanilla:27.0", "27.0", "27.1"
    ),
}


class VMError(Exception):
    """A failure the user can act on; printed without a traceback."""


def run(args: list[str], *, check: bool = True, capture: bool = False, **kwargs):
    try:
        return subprocess.run(
            args, check=check, capture_output=capture, text=capture, **kwargs
        )
    except FileNotFoundError:
        raise VMError(f"required command is missing: {args[0]}") from None


def output(args: list[str]) -> str:
    return run(args, capture=True).stdout


def require(*commands: str) -> None:
    for name in commands:
        if shutil.which(name) is None:
            hint = {
                "tart": "run `mise install`",
                "limactl": "run `brew bundle install`",
            }.get(name, "install it")
            raise VMError(f"{name} not found: {hint}")


def storage() -> None:
    """Point Tart and Lima at the shared VM root for this process and its children."""
    for variable, manager in (("TART_HOME", "tart"), ("LIMA_HOME", "lima")):
        if not os.environ.get(variable):
            os.environ[variable] = str(VM_ROOT / manager)


# Tart


def tart_vms() -> dict[str, dict]:
    entries = json.loads(
        output(["tart", "list", "--source", "local", "--format", "json"])
    )
    return {entry["Name"]: entry for entry in entries}


def tart_state(name: str) -> str:
    vm = tart_vms().get(name)
    if vm is None:
        raise VMError(f"Tart VM does not exist: {name}")
    return vm["State"]


def tart_start(name: str, dirs: list[str] | None = None) -> None:
    """Start a VM headless unless it is running, and wait for its IP address."""
    if tart_state(name) != "running":
        log_path = Path(tempfile.gettempdir()) / f"tessera-tart-{name}.log"
        flags = [f"--dir={share}" for share in dirs or []]
        with log_path.open("wb") as log:
            process = subprocess.Popen(
                ["tart", "run", "--no-graphics", *flags, name],
                stdin=subprocess.DEVNULL,
                stdout=log,
                stderr=subprocess.STDOUT,
                start_new_session=True,
            )
        print(f"vm: started {name} (tart pid {process.pid}, log {log_path})")
        if run(
            ["tart", "ip", name, "--wait", "120"], check=False, capture=True
        ).returncode:
            process.poll()
            raise VMError(
                f"{name} got no IP address within 120 s "
                f"(tart exited: {process.returncode is not None}); see {log_path}"
            )
    write_ssh_config(name)


def boot(name: str) -> None:
    tart_start(name)
    wait_for_ssh(name)


def tart_stop(name: str) -> None:
    if tart_state(name) == "running":
        run(["tart", "stop", name, "--timeout", "120"])
    print(f"vm: {name} is stopped")


# SSH: a dedicated key and a generated config; host keys are recorded per VM name.


def ensure_key() -> None:
    if not SSH_KEY.exists():
        SSH_KEY.parent.mkdir(mode=0o700, exist_ok=True)
        run(
            [
                "ssh-keygen",
                "-q",
                "-t",
                "ed25519",
                "-N",
                "",
                "-C",
                "tessera-vm",
                "-f",
                str(SSH_KEY),
            ]
        )
        print(f"vm: generated {SSH_KEY}")


def forget_host_key(name: str) -> None:
    if KNOWN_HOSTS.exists():
        run(
            ["ssh-keygen", "-q", "-R", name, "-f", str(KNOWN_HOSTS)],
            capture=True,
            check=False,
        )
        Path(f"{KNOWN_HOSTS}.old").unlink(missing_ok=True)


def ssh_host(name: str, user: str, resolve: str, keys: list[Path]) -> list[str]:
    """One Host block; `resolve` is a shell command printing the guest's address."""
    connect = f'exec /usr/bin/nc "$({resolve})" 22'
    return [
        f"\nHost {name}\n",
        f"  User {user}\n",
        f"  ProxyCommand /bin/sh -c {shlex.quote(connect)}\n",
        *(f'  IdentityFile "{key}"\n' for key in keys),
        "  IdentitiesOnly yes\n",
        f"  HostKeyAlias {name}\n",
        "  StrictHostKeyChecking accept-new\n",
        f'  UserKnownHostsFile "{KNOWN_HOSTS}"\n',
        "  ServerAliveInterval 30\n",
        "  LogLevel ERROR\n",
    ]


def write_ssh_config(*extra: str) -> None:
    """Write a Host entry for every Tessera Tart VM plus `extra`, and every UTM guest."""
    ensure_key()
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    KNOWN_HOSTS.touch(mode=0o600, exist_ok=True)
    lines = [
        "# Generated by scripts/vm.py (mise run vm:*); edits are overwritten.\n",
        f"# Use it with `ssh -F {SSH_CONFIG} <vm>`, or Include it from ~/.ssh/config.\n",
    ]
    tart = shutil.which("tart")
    tart_names = set(extra)
    if tart:
        tart_names |= {name for name in tart_vms() if name.startswith("tessera-")}
    for name in sorted(tart_names):
        resolve = (
            f"TART_HOME={shlex.quote(os.environ['TART_HOME'])} "
            f"{shlex.quote(tart)} ip {name} --wait 60"
        )
        lines += ssh_host(name, GUEST_USER, resolve, [SSH_KEY])
    for name in sorted(utm_names()):
        resolve = (
            f"{shlex.quote(sys.executable)} {shlex.quote(__file__)} "
            f"windows-ip --name {shlex.quote(name)}"
        )
        keys = [SSH_KEY]
        if WINDOWS_LEGACY_KEY.exists():
            keys.append(WINDOWS_LEGACY_KEY)
        lines += ssh_host(name, WINDOWS_USER, resolve, keys)
    temporary = SSH_CONFIG.with_suffix(".tmp")
    temporary.write_text("".join(lines), encoding="utf-8")
    temporary.chmod(0o600)
    temporary.replace(SSH_CONFIG)


def ssh_args(name: str, *options: str) -> list[str]:
    return ["ssh", "-F", str(SSH_CONFIG), *options, name]


def guest(name: str, script: str, *args: str, tty: bool = False, check: bool = True):
    """Run a bash script in the guest, streaming its output."""
    command = shlex.join(
        ["/bin/bash", "-c", f"set -euo pipefail\n{script}", "bash", *args]
    )
    return run([*ssh_args(name, *(["-t"] if tty else [])), command], check=check)


def wait_for_ssh(name: str, *, password: bool = False) -> None:
    """Wait for the guest's SSH server; with `password`, authorize the key on first contact."""
    if password:
        authorize = "umask 077; mkdir -p ~/.ssh; cat >> ~/.ssh/authorized_keys"
        options = [
            "-o",
            "PubkeyAuthentication=no",
            "-o",
            "PreferredAuthentications=password,keyboard-interactive",
            "-o",
            "NumberOfPasswordPrompts=1",
        ]
    else:
        # `exit 0` is understood by bash, cmd.exe, and PowerShell alike.
        authorize = "exit 0"
        options = ["-o", "BatchMode=yes"]
    with tempfile.TemporaryDirectory() as scratch:
        askpass = Path(scratch) / "askpass"
        askpass.write_text(f"#!/bin/sh\necho {GUEST_PASSWORD}\n", encoding="utf-8")
        askpass.chmod(0o700)
        environment = {
            **os.environ,
            "SSH_ASKPASS": str(askpass),
            "SSH_ASKPASS_REQUIRE": "force",
        }
        key = SSH_KEY.with_suffix(".pub").read_bytes()
        deadline = time.monotonic() + BOOT_TIMEOUT
        while True:
            attempt = subprocess.run(
                [*ssh_args(name, "-o", "ConnectTimeout=10", *options), authorize],
                input=key if password else b"",
                capture_output=True,
                env=environment,
            )
            if attempt.returncode == 0:
                return
            if time.monotonic() > deadline:
                error = attempt.stderr.decode(errors="replace").strip()
                raise VMError(
                    f"{name} did not accept SSH within {BOOT_TIMEOUT} s: {error}"
                )
            time.sleep(5)


# macOS


def macos_base(major: str, xcode: str) -> None:
    rel = RELEASES[major]
    base = os.environ.get("TESSERA_MACOS_BASE") or rel.base
    if base in tart_vms():
        raise VMError(
            f"{base} already exists; to rebuild it, delete it first with "
            f"`TART_HOME={os.environ['TART_HOME']} tart delete {base}`"
        )
    dirs = []
    if xcode == "host":
        app = next((path for path in rel.host_xcodes() if path.is_dir()), None)
        if app is None:
            searched = ", ".join(str(path) for path in rel.host_xcodes())
            raise VMError(
                f"no Xcode {rel.xcode_version} on this host ({searched}); use --xcode xcodes"
            )
        dirs.append(f"xcode:{app}:ro")
    run(["tart", "clone", rel.image, base])
    try:
        forget_host_key(base)
        tart_start(base, dirs)
        wait_for_ssh(base, password=True)
        wait_for_ssh(base)
        print(
            f"vm: {base} answers on SSH; installing mise and Xcode {rel.xcode_version}"
        )
        guest(
            base,
            r"""
sudo -n true || { echo "passwordless sudo is not configured for $USER" >&2; exit 1; }
curl -fsSL https://mise.run | sh
grep -q 'mise activate zsh' ~/.zshrc 2>/dev/null \
  || echo 'eval "$("$HOME/.local/bin/mise" activate zsh)"' >> ~/.zshrc
"$HOME/.local/bin/mise" --version
""",
        )
        if xcode == "host":
            guest(
                base,
                """
share="$1"
app="$2"
for _ in $(seq 60); do [[ -d "$share/Contents" ]] && break; sleep 2; done
[[ -d "$share/Contents" ]] || { echo "the Xcode share is not mounted at $share" >&2; exit 1; }
echo "copying $share to $app"
# The share adds a com.apple.provenance attribute the host's Xcode does not have, and
# reading it from a symlink fails (ELOOP), which breaks ditto and cp; tar can skip it.
mkdir "$app"
(cd "$share" && tar --no-mac-metadata -cf - .) | tar -xf - --hfsCompression -C "$app"
""",
                GUEST_XCODE_SHARE,
                rel.guest_xcode,
            )
        else:
            # Interactive: xcodes asks for the Apple Account and its two-factor code.
            guest(
                base,
                f'export PATH="{GUEST_PATH}"\n'
                "mise install xcodes@latest\n"
                'mise exec xcodes@latest -- xcodes install "$1" --experimental-unxip --directory /Applications\n'
                # Clones inherit the base's keychain; leave no Apple Account in it.
                "mise exec xcodes@latest -- xcodes signout",
                rel.xcode_version,
                tty=True,
            )
        guest(
            base,
            """
app="$1"
[[ -d "$app" ]] || { echo "Xcode is not installed at $app" >&2; exit 1; }
# Gatekeeper checks the bundle against its seal on the first launch and, headless, waits
# forever on a prompt nobody sees if anything differs. A used Xcode can hold files its own
# builds added (*.dependency-scan.dia next to SWBBuildService), so remove what the seal
# does not cover and stop on any other difference.
report="$(mktemp)"
echo "verifying the code signature of $app"
until codesign --verify --deep --strict --verbose=2 "$app" > "$report" 2>&1; do
  added="$(sed -n 's/^file added: //p' "$report")"
  if [[ -z "$added" ]]; then grep -v '^--' "$report" >&2; exit 1; fi
  while IFS= read -r path; do
    echo "removing a file outside the signature: $path"
    rm -f -- "$path"
  done <<< "$added"
done
sudo -n xcode-select --switch "$app/Contents/Developer"
sudo -n xcodebuild -license accept
sudo -n xcodebuild -runFirstLaunch
xcodebuild -version
xcrun swift --version
""",
            rel.guest_xcode,
        )
        tart_stop(base)
    except BaseException:
        print(f"vm: building {base} failed; deleting the partial base", file=sys.stderr)
        run(["tart", "stop", base, "--timeout", "30"], check=False, capture=True)
        run(["tart", "delete", base], check=False)
        forget_host_key(base)
        write_ssh_config()
        raise
    write_ssh_config()
    print(
        f"vm: {base} is ready; `mise run vm:macos-clone {major}` makes a work instance"
    )


def macos_clone(major: str) -> None:
    rel = RELEASES[major]
    base = os.environ.get("TESSERA_MACOS_BASE") or rel.base
    name = os.environ.get("TESSERA_MACOS_VM_NAME") or rel.instance
    vms = tart_vms()
    if base not in vms:
        raise VMError(
            f"{base} does not exist; build it with `mise run vm:macos-base {major}`"
        )
    if name in vms:
        raise VMError(f"{name} already exists")
    run(["tart", "clone", base, name])
    run(["tart", "set", name, "--cpu", CLONE_CPUS, "--memory", CLONE_MEMORY_MB])
    forget_host_key(name)
    write_ssh_config(name)
    print(f"vm: cloned {base} to {name} (stopped)")


def macos_delete(name: str) -> None:
    if name.startswith("base-"):
        raise VMError(f"refusing to delete a base: {name}")
    tart_state(name)
    run(["tart", "delete", name])
    forget_host_key(name)
    write_ssh_config()
    print(f"vm: deleted {name}")


def source_paths() -> list[str]:
    """Tracked plus untracked-but-not-ignored paths, what a push delivers."""
    listing = output(
        [
            "git",
            "-C",
            str(ROOT),
            "ls-files",
            "-z",
            "--cached",
            "--others",
            "--exclude-standard",
        ]
    )
    return [
        path for path in listing.split("\0") if path and os.path.lexists(ROOT / path)
    ]


def macos_push(name: str) -> None:
    boot(name)
    with tempfile.TemporaryDirectory() as scratch:
        archive = Path(scratch) / "tessera-source.tar.gz"
        paths = source_paths()
        with tarfile.open(archive, "w:gz") as tar:
            for path in paths:
                tar.add(ROOT / path, arcname=path, recursive=False)
        print(f"vm: delivering {len(paths)} paths to {name}:~/{GUEST_CHECKOUT}")
        remote = f"/tmp/tessera-source-{os.getpid()}.tar.gz"
        run(["scp", "-q", "-F", str(SSH_CONFIG), str(archive), f"{name}:{remote}"])
    # The checkout is a Git repository whose index records the last delivery, so paths the
    # host no longer has are removed, and scripts that call `git rev-parse` work.
    guest(
        name,
        """
archive="$1"
checkout="$HOME/$2"
mkdir -p "$checkout"
cd "$checkout"
[[ -d .git ]] || git init -q
git -c core.quotePath=false ls-files | LC_ALL=C sort > "$archive.old"
tar -tzf "$archive" | LC_ALL=C sort > "$archive.new"
LC_ALL=C comm -23 "$archive.old" "$archive.new" | while IFS= read -r path; do rm -f -- "$path"; done
tar -xzf "$archive"
git add -A
rm -f "$archive" "$archive.old" "$archive.new"
""",
        remote,
        GUEST_CHECKOUT,
    )
    print(f"vm: {name}:~/{GUEST_CHECKOUT} matches the working tree")


def macos_check(name: str) -> int:
    boot(name)
    result = guest(
        name,
        f"""
export PATH="{GUEST_PATH}"
cd "$HOME/$1"
mise trust --quiet mise.toml
mise install
mise exec -- npm ci
mise exec -- swift --version
mise run ci:check
mise run docs:lint
mise run core:examples
""",
        GUEST_CHECKOUT,
        check=False,
    )
    status = (
        "passed" if result.returncode == 0 else f"failed (exit {result.returncode})"
    )
    print(f"vm: check matrix in {name} {status}")
    return result.returncode


# Linux (Lima)


def linux_name() -> str:
    return os.environ.get("TESSERA_LINUX_VM_NAME") or "tessera-linux"


def lima_vm(name: str) -> dict | None:
    # Read the whole list: stopping early used to close the pipe while limactl wrote.
    listing = output(["limactl", "list", "--json"])
    entries = [json.loads(line) for line in listing.splitlines() if line.strip()]
    return next((entry for entry in entries if entry["name"] == name), None)


def lima_create(name: str) -> None:
    run(
        [
            "limactl",
            "--yes",
            "start",
            f"--name={name}",
            "--mount-only",
            f"{ROOT}:w",
            "--param",
            f"ProjectDir={ROOT}",
            str(LINUX_CONFIG),
        ]
    )


def linux_start(name: str) -> bool:
    """Create or start the VM for this checkout; return whether this call started it."""
    vm = lima_vm(name)
    if vm is None:
        lima_create(name)
        return True
    project_dir = vm.get("param", {}).get("ProjectDir", "")
    running = vm["status"] == "Running"
    if project_dir != str(ROOT):
        if running:
            raise VMError(f"{name} is running for {project_dir}, not {ROOT}")
        # A Lima VM mounts one checkout. Re-point a stopped one at this checkout rather
        # than recreating it, so its toolchains and caches survive a worktree switch.
        run(
            [
                "limactl",
                "edit",
                "--tty=false",
                "--mount-only",
                f"{ROOT}:w",
                "--set",
                f".param.ProjectDir = {json.dumps(str(ROOT))}",
                name,
            ]
        )
    if running:
        return False
    run(["limactl", "start", name])
    return True


def linux_test(name: str, args: list[str]) -> int:
    started = linux_start(name)
    # The guest keeps the baseline (.swift-version) as its swiftly default;
    # TESSERA_LINUX_SWIFT_VERSION selects another release for one run (for example 6.4.1,
    # the Swift 6.4 lane), installing it on first use.
    swift_version = os.environ.get("TESSERA_LINUX_SWIFT_VERSION") or (
        (ROOT / ".swift-version").read_text(encoding="utf-8").strip()
    )
    script = r"""
set -euo pipefail
repo_root="$1"
swift_version="$2"
shift 2

source ~/.local/share/swiftly/env.sh
export PATH=~/.local/bin:$PATH

if ! swiftly list | grep -q "^Swift $swift_version "; then
  swiftly install "$swift_version" --assume-yes
fi

cd "$repo_root"
rm -rf \
  .build/aarch64-unknown-linux-gnu/debug/ModuleCache* \
  .build/x86_64-unknown-linux-gnu/debug/ModuleCache*

swiftly run "+$swift_version" swift --version
swiftly run "+$swift_version" swift test --jobs 2 --no-parallel "$@"
"""
    try:
        result = run(
            [
                "limactl",
                "shell",
                name,
                "--",
                "bash",
                "-lc",
                script,
                "bash",
                str(ROOT),
                swift_version,
                *args,
            ],
            check=False,
        )
    finally:
        if started:
            run(["limactl", "stop", name])
    return result.returncode


# Windows (UTM)


def utm_names() -> list[str]:
    """The Tessera guests UTM knows, from its documents folder (no Apple Events)."""
    if not UTM_DOCUMENTS.is_dir():
        return []
    return sorted(
        path.stem
        for path in UTM_DOCUMENTS.glob("tessera-*.utm")
        if (path / "config.plist").is_file()
    )


def utm_bundle(name: str) -> Path:
    bundle = UTM_DOCUMENTS / f"{name}.utm"
    if not (bundle / "config.plist").is_file():
        raise VMError(
            f"no UTM virtual machine named {name}; "
            f"`mise run vm:windows-create --import <bundle.utm>` adds one"
        )
    return bundle


def utm_config(name: str) -> dict:
    with open(utm_bundle(name) / "config.plist", "rb") as file:
        return plistlib.load(file)


def utm_app() -> str | None:
    """`None` when UTM.app is not running, else "hidden" or "visible"."""
    # The first line reads `"UTM" ASN:0x0-0x61c61c: (hidden)` while it runs; a launch
    # nothing activated (an Apple Event, `open -g`) also reports hidden.
    header = output(["lsappinfo", "info", UTM_BUNDLE_ID]).splitlines()[:1]
    if not header or "ASN:" not in header[0] or "[ NULL ]" in header[0]:
        return None
    return "hidden" if "(hidden)" in header[0] else "visible"


def frontmost_bundle_id() -> str | None:
    asn = output(["lsappinfo", "front"]).strip()
    info = output(["lsappinfo", "info", "-only", "bundleid", asn]) if asn else ""
    match = re.search(r'bundleID="([^"]+)"', info)
    return match.group(1) if match else None


def utmctl(*args: str, check: bool = True, capture: bool = True):
    return run([UTMCTL, *args], check=check, capture=capture)


def utm_ensure_running() -> None:
    """Launch or activate UTM.app, then hand focus back to the caller's app.

    `utmctl start` and `stop` hang for two minutes with OSStatus -1712 unless UTM.app has
    been activated once since it launched, and a launch by `utmctl` itself, `open -g`, or
    the URL scheme never is; `open -a` activates it. A hidden UTM is either that trap or
    one the user hid, so it is activated again (a one-second focus flash, nothing else).
    """
    if not UTM_APP.is_dir():
        raise VMError("UTM.app is not installed: run `brew bundle install`")
    if utm_app() == "visible":
        return
    front = frontmost_bundle_id()
    run(["open", "-a", str(UTM_APP)])
    deadline = time.monotonic() + 30
    while utmctl("list", check=False).returncode != 0:
        if time.monotonic() > deadline:
            raise VMError("UTM.app did not answer `utmctl list` within 30 s")
        time.sleep(0.5)
    if front and front != UTM_BUNDLE_ID:
        run(["open", "-b", front], check=False)


def utm_quit() -> None:
    if utm_app() is None:
        return
    run(["osascript", "-e", f'tell application id "{UTM_BUNDLE_ID}" to quit'])
    deadline = time.monotonic() + 30
    while utm_app() is not None:
        if time.monotonic() > deadline:
            raise VMError("UTM.app did not quit within 30 s")
        time.sleep(0.5)
    print("vm: UTM.app quit")


def utm_state(name: str) -> str:
    """`utmctl status`, or "stopped" from the bundle alone while UTM.app is not running."""
    utm_bundle(name)
    if utm_app() is None:
        return "stopped"
    return utmctl("status", name).stdout.strip()


def utm_wait(name: str, state: str, timeout: int = UTM_TIMEOUT) -> None:
    deadline = time.monotonic() + timeout
    while utm_state(name) != state:
        if time.monotonic() > deadline:
            raise VMError(f"{name} did not reach {state} within {timeout} s")
        time.sleep(2)


def windows_name(args: argparse.Namespace) -> str:
    """`--name`, then $TESSERA_WINDOWS_VM_NAME, then the one Tessera guest UTM has."""
    name = getattr(args, "name", None)
    remote = getattr(args, "args", None)
    # Pass-through commands take no options; a leading `--name <vm>` is still honored.
    if remote and remote[:1] == ["--name"] and len(remote) > 1:
        name = remote[1]
        del remote[:2]
    name = name or os.environ.get("TESSERA_WINDOWS_VM_NAME")
    if name or args.command == "windows-create":
        return name or WINDOWS_DEFAULT_NAME
    names = utm_names()
    if WINDOWS_DEFAULT_NAME in names or len(names) != 1:
        return WINDOWS_DEFAULT_NAME
    return names[0]


def windows_start(name: str) -> None:
    utm_ensure_running()
    if utm_state(name) != "started":
        # No `--hide`: it prints OSStatus -10004 twice per command (UTM issue 5509).
        result = utmctl("start", name, check=False)
        if result.returncode != 0:
            error = (result.stderr or result.stdout).strip()
            if "-1712" in error:
                error += (
                    "; UTM.app was never activated since it launched, so Apple Events "
                    "time out: quit it (`mise run vm:windows-stop --quit`) and retry"
                )
            raise VMError(f"utmctl start {name} failed: {error}")
        utm_wait(name, "started")
    write_ssh_config()
    print(f"vm: {name} is started")


def windows_stop(name: str, *, force: bool = False, quit_app: bool = False) -> None:
    if utm_state(name) != "stopped":
        utm_ensure_running()
        if force:
            # `utmctl stop` defaults to this power-off event.
            utmctl("stop", name, "--force")
        elif ssh_answers(name):
            # Windows ignored the ACPI request once in a while; `shutdown` never did.
            run([*ssh_args(name), "shutdown /s /f /t 0"], check=False)
        else:
            utmctl("stop", name, "--request")
        utm_wait(name, "stopped")
    print(f"vm: {name} is stopped")
    if quit_app:
        utm_quit()


def windows_ip(name: str) -> str:
    """The guest's IPv4 address: UTM guest tools first, then the host's DHCP lease."""
    if utm_app() is not None and utm_state(name) == "started":
        result = utmctl("ip-address", name, check=False)
        for line in result.stdout.splitlines():
            if re.fullmatch(r"\d+\.\d+\.\d+\.\d+", line.strip()):
                return line.strip()
    mac = utm_config(name)["Network"][0]["MacAddress"]
    wanted = [int(octet, 16) for octet in mac.split(":")]
    # Entries look like `hw_address=1,76:f9:a1:50:3c:f0`, octets without zero padding.
    leases = DHCPD_LEASES.read_text(encoding="utf-8") if DHCPD_LEASES.exists() else ""
    for block in leases.split("}"):
        fields = dict(
            line.strip().split("=", 1) for line in block.splitlines() if "=" in line
        )
        hardware = fields.get("hw_address", "").partition(",")[2]
        if hardware and [int(octet, 16) for octet in hardware.split(":")] == wanted:
            return fields["ip_address"]
    raise VMError(
        f"no address for {name} ({mac}): it has not booted on this host yet, "
        "or its lease in /var/db/dhcpd_leases expired"
    )


def windows_boot(name: str) -> None:
    windows_start(name)
    wait_for_ssh(name)


def powershell(script: str) -> list[str]:
    """A PowerShell invocation that survives Windows OpenSSH's cmd.exe quoting."""
    encoded = base64.b64encode(script.encode("utf-16-le")).decode()
    return ["powershell", "-NoProfile", "-EncodedCommand", encoded]


def decode_clixml(blob: str) -> str:
    """The error and warning records of a CLIXML blob as text; the rest is noise."""
    lines = []
    for body in re.findall(r'<S S="(?:Error|warning)">(.*?)</S>', blob, re.S):
        text = html.unescape(body).replace("_x000D__x000A_", "\n").replace("_x000A_", "\n")
        lines.append(text if text.endswith("\n") else text + "\n")
    return "".join(lines)


def relay_powershell_stderr(pipe) -> None:
    """Print a guest PowerShell's stderr, decoding what sshd makes it serialize.

    Without a console, PowerShell wraps its error, warning, information, and progress
    streams in CLIXML on stderr, so every Write-Host would otherwise appear twice.
    """
    blob = ""
    for raw in iter(pipe.readline, b""):
        line = raw.decode(errors="replace")
        if blob or line.startswith("<Objs "):
            blob += line
            if "</Objs>" in line:
                sys.stderr.write(decode_clixml(blob))
                blob = ""
        elif not line.startswith("#< CLIXML"):
            sys.stderr.write(line)
        sys.stderr.flush()
    if blob:
        sys.stderr.write(decode_clixml(blob))
        sys.stderr.flush()


def windows_run(name: str, *command: str, check: bool = True):
    """Run a command in the guest over SSH, relaying stderr through the decoder."""
    process = subprocess.Popen([*ssh_args(name), *command], stderr=subprocess.PIPE)
    relay = threading.Thread(target=relay_powershell_stderr, args=(process.stderr,))
    relay.start()
    returncode = process.wait()
    relay.join()
    if check and returncode:
        raise subprocess.CalledProcessError(returncode, process.args)
    return subprocess.CompletedProcess(process.args, returncode)


def windows_guest(name: str, script: str, *, check: bool = True):
    """Run a PowerShell script in the guest, streaming its output."""
    return windows_run(name, *powershell(script), check=check)


def ssh_answers(name: str, *, batch: bool = True) -> bool:
    options = ["-o", "ConnectTimeout=10"] + (["-o", "BatchMode=yes"] if batch else [])
    return run([*ssh_args(name, *options), "exit 0"], check=False).returncode == 0


def port_open(host: str, port: int) -> bool:
    with socket.socket() as probe:
        probe.settimeout(3)
        try:
            probe.connect((host, port))
        except OSError:
            return False
    return True


def windows_reboot(name: str) -> None:
    run([*ssh_args(name), "shutdown /r /t 0"], check=False)
    address = windows_ip(name)
    deadline = time.monotonic() + UTM_TIMEOUT
    while port_open(address, 22):
        if time.monotonic() > deadline:
            raise VMError(f"{name} did not go down for its reboot within {UTM_TIMEOUT} s")
        time.sleep(3)
    wait_for_ssh(name)


def pinned_swift_version() -> str:
    return (ROOT / ".swift-version").read_text(encoding="utf-8").strip()


def pinned_zig_version() -> str:
    """mise.toml's `zig`, which scripts/build-libghostty-vt.ps1 must match."""
    match = re.search(
        r'^zig\s*=\s*"([^"]+)"', (ROOT / "mise.toml").read_text(encoding="utf-8"), re.M
    )
    if match is None:
        raise VMError("mise.toml does not pin zig")
    return match.group(1)


def windows_provision(name: str) -> None:
    """Converge the guest on the toolchain the checkout names; reboots as needed."""
    windows_start(name)
    swift_version = pinned_swift_version()
    zig_version = pinned_zig_version()
    if not ssh_answers(name):
        if not port_open(windows_ip(name), 22):
            raise VMError(
                f"{name} has no SSH server yet. In the guest, open an elevated PowerShell "
                "and run\n"
                "  Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0; "
                "Set-Service sshd -StartupType Automatic; Start-Service sshd\n"
                f"then rerun `mise run vm:windows-provision`; it asks for {WINDOWS_USER}'s "
                "password once and installs its key."
            )
        print(f"vm: {name} asks for a password until its key is installed")
    script = f"{WINDOWS_TEMP}/{WINDOWS_PROVISION_SCRIPT.name}"
    key = f"{WINDOWS_TEMP}/tessera-vm.pub"
    run(
        [
            "scp",
            "-q",
            "-F",
            str(SSH_CONFIG),
            str(WINDOWS_PROVISION_SCRIPT),
            str(SSH_KEY.with_suffix(".pub")),
            f"{name}:{WINDOWS_TEMP}/",
        ]
    )
    command = (
        f"powershell -NoProfile -ExecutionPolicy Bypass -File {script} "
        f"-ExpectedSwiftVersion {swift_version} -ZigVersion {zig_version} "
        f"-AuthorizedKeyPath {key}"
    )
    for attempt in range(1, 6):
        print(f"vm: provisioning {name} (pass {attempt})")
        result = windows_run(name, command, check=False)
        if result.returncode == 0:
            print(f"vm: {name} is provisioned (Swift {swift_version}, Zig {zig_version})")
            return
        if result.returncode != 100:
            raise VMError(f"provisioning {name} failed (exit {result.returncode})")
        print(f"vm: {name} needs a reboot; rebooting and continuing")
        windows_reboot(name)
    raise VMError(f"{name} still wanted a reboot after 5 passes; see {WINDOWS_TEMP}")


def random_mac() -> str:
    octets = [secrets.randbits(8) for _ in range(6)]
    octets[0] = (octets[0] & 0xFC) | 0x02  # locally administered, unicast
    return ":".join(f"{octet:02X}" for octet in octets)


def clone_path(source: Path, target: Path) -> None:
    """Copy with APFS clonefile when possible (instant, shares blocks), else bytewise."""
    if run(["cp", "-Rc", str(source), str(target)], check=False, capture=True).returncode:
        shutil.rmtree(target, ignore_errors=True)
        if target.exists():
            target.unlink()
        run(["cp", "-R", str(source), str(target)])


def windows_create(name: str, *, bundle: Path | None, disk: Path | None) -> None:
    """Add a UTM VM: a copy of an existing bundle, or the template around a qcow2 disk."""
    target = UTM_DOCUMENTS / f"{name}.utm"
    if target.exists():
        raise VMError(f"{target} already exists")
    if utm_app() is not None:
        # UTM scans its documents folder when it launches; a running UTM would not see
        # the new bundle until the next launch.
        if any(utm_state(vm) != "stopped" for vm in utm_names()):
            raise VMError("stop the running UTM guests first; UTM.app has to be quit")
        utm_quit()
    UTM_DOCUMENTS.mkdir(parents=True, exist_ok=True)
    if bundle is not None:
        if not (bundle / "config.plist").is_file():
            raise VMError(f"{bundle} is not a UTM bundle")
        print(f"vm: copying {bundle} to {target}")
        clone_path(bundle, target)
        with open(target / "config.plist", "rb") as file:
            config = plistlib.load(file)
    else:
        if disk is None or not disk.is_file():
            raise VMError("windows-create needs --import <bundle.utm> or --disk <image>")
        with open(WINDOWS_TEMPLATE, "rb") as file:
            config = plistlib.load(file)
        (target / "Data").mkdir(parents=True)
        image = f"{name}.qcow2"
        print(f"vm: copying {disk} to {target / 'Data' / image}")
        clone_path(disk, target / "Data" / image)
        shutil.copy(UTM_APP / "Contents/Resources/qemu/edk2-arm-vars.fd", target / "Data/efi_vars.fd")
        config["Drive"][0]["ImageName"] = image
        config["Drive"][0]["Identifier"] = str(uuid.uuid4()).upper()
    config["Information"]["Name"] = name
    config["Information"]["UUID"] = str(uuid.uuid4()).upper()
    for interface in config.get("Network", []):
        interface["MacAddress"] = random_mac()
    with open(target / "config.plist", "wb") as file:
        plistlib.dump(config, file, sort_keys=True)
    print(f"vm: created {name}; `mise run vm:windows-provision --name {name}` is next")


def windows_delete(name: str) -> None:
    bundle = utm_bundle(name)
    if utm_state(name) != "stopped":
        raise VMError(f"{name} is running; stop it first")
    if utm_app() is not None:
        utm_quit()
    shutil.rmtree(bundle)
    forget_host_key(name)
    print(f"vm: deleted {name}")


def ps_quote(value: str) -> str:
    """A single-quoted PowerShell string literal."""
    return "'" + value.replace("'", "''") + "'"


def windows_push(name: str) -> None:
    """Deliver the working tree to the guest's checkout, as macos-push does."""
    windows_boot(name)
    with tempfile.TemporaryDirectory() as scratch:
        archive = Path(scratch) / "tessera-source.tar.gz"
        paths = source_paths()
        with tarfile.open(archive, "w:gz") as tar:
            for path in paths:
                tar.add(ROOT / path, arcname=path, recursive=False)
        print(f"vm: delivering {len(paths)} paths to {name}:~/{GUEST_CHECKOUT}")
        remote = f"{WINDOWS_TEMP}/tessera-source-{os.getpid()}.tar.gz"
        run(["scp", "-q", "-F", str(SSH_CONFIG), str(archive), f"{name}:{remote}"])
    # The checkout is a Git repository whose index records the last delivery, so paths
    # the host no longer has are removed, and scripts that call `git rev-parse` work.
    windows_guest(
        name,
        f"""
$ErrorActionPreference = "Stop"
$archive = {ps_quote(remote)}
$checkout = Join-Path $env:USERPROFILE {ps_quote(GUEST_CHECKOUT)}
New-Item -ItemType Directory -Force $checkout | Out-Null
Set-Location $checkout
if (-not (Test-Path .git)) {{ git init -q }}
$delivered = [Collections.Generic.HashSet[string]]::new([string[]]@(tar -tzf $archive))
foreach ($path in @(git -c core.quotePath=false ls-files)) {{
    if (-not $delivered.Contains($path)) {{
        Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
    }}
}}
tar -xzf $archive
if ($LASTEXITCODE) {{ throw "tar failed with exit code $LASTEXITCODE" }}
# The index only records deliveries; never let Git rewrite line endings on the way in.
git -c core.autocrlf=false add -A
Remove-Item $archive -Force
""",
    )
    print(f"vm: {name}:~/{GUEST_CHECKOUT} matches the working tree")


def windows_test(name: str, args: list[str]) -> int:
    windows_boot(name)
    swift_args = ", ".join(ps_quote(arg) for arg in args)
    result = windows_guest(
        name,
        f"""
$checkout = Join-Path $env:USERPROFILE {ps_quote(GUEST_CHECKOUT)}
& (Join-Path $checkout "scripts\\run-windows-tests.ps1") -RepoPath $checkout `
    -SwiftTestArgs @({swift_args})
exit $LASTEXITCODE
""",
        check=False,
    )
    status = (
        "passed" if result.returncode == 0 else f"failed (exit {result.returncode})"
    )
    print(f"vm: tests in {name} {status}")
    return result.returncode


def windows_conpty_smoke(name: str) -> int:
    """Print colored lines through a real ConPTY, to see ANSI survive the round trip."""
    windows_boot(name)
    script = (
        '$esc = [char]27; Write-Host "ConPTY ANSI smoke"; '
        'Write-Host "$esc[31mred$esc[0m $esc[32mgreen$esc[0m $esc[34mblue$esc[0m"; '
        'Write-Host "cursor save/restore:$esc[s here$esc[u done"'
    )
    command = [*ssh_args(name, "-tt"), *powershell(script)]
    if not sys.stdin.isatty():
        # OpenSSH needs a local pseudo-terminal to request a ConPTY on the far side.
        command = ["script", "-q", "/dev/null", *command]
    return run(command, check=False).returncode


def utm_snapshots(name: str) -> Path:
    return VM_ROOT / "utm" / name / "snapshots"


def windows_snapshot(name: str, snapshot: str | None) -> None:
    """Keep an APFS clone of the stopped guest's disk, firmware, and TPM state."""
    if snapshot is None:
        for path in sorted(utm_snapshots(name).glob("*")):
            print(path.name)
        return
    if utm_state(name) != "stopped":
        raise VMError(f"{name} is running; stop it first")
    target = utm_snapshots(name) / snapshot
    if target.exists():
        raise VMError(f"snapshot {snapshot} of {name} already exists")
    target.parent.mkdir(parents=True, exist_ok=True)
    clone_path(utm_bundle(name) / "Data", target)
    print(f"vm: {name} snapshot {snapshot} taken at {target}")


def windows_restore(name: str, snapshot: str) -> None:
    source = utm_snapshots(name) / snapshot
    if not source.is_dir():
        raise VMError(f"no snapshot {snapshot} of {name}; `windows-snapshot` lists them")
    if utm_state(name) != "stopped":
        raise VMError(f"{name} is running; stop it first")
    data = utm_bundle(name) / "Data"
    incoming = data.with_name("Data.restoring")
    shutil.rmtree(incoming, ignore_errors=True)
    clone_path(source, incoming)
    shutil.rmtree(data)
    incoming.rename(data)
    print(f"vm: {name} restored to snapshot {snapshot}")


# Commands


def status() -> None:
    for title, manager, command in (
        ("Tart", "TART_HOME", ["tart", "list", "--source", "local"]),
        ("Lima", "LIMA_HOME", ["limactl", "list"]),
    ):
        print(f"{title} ({os.environ[manager]}):")
        if shutil.which(command[0]) is None:
            print(f"  {command[0]} not found")
            continue
        sys.stdout.flush()
        run(command)
    print(f"UTM ({UTM_DOCUMENTS}):")
    if not UTM_APP.is_dir():
        print("  UTM.app not found")
    elif utm_app() is None:
        # `utmctl list` would launch UTM.app; the bundles answer without it.
        for name in utm_names():
            print(f"  stopped  {name}  (UTM.app not running)")
    else:
        sys.stdout.flush()
        utmctl("list", capture=False)
    print(f"SSH config: {SSH_CONFIG}")


def parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="vm.py", description=__doc__.splitlines()[0])
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("status", help="list the Tart, Lima, and UTM VMs")
    commands.add_parser("macos-names", help="print the Tessera Tart instances")
    base = commands.add_parser("macos-base", help="build a macOS base with Xcode")
    base.add_argument("major", choices=RELEASES)
    base.add_argument("--xcode", choices=("host", "xcodes"), default="host")
    commands.add_parser(
        "macos-clone", help="clone a work instance from a base"
    ).add_argument("major", choices=RELEASES)
    for command in (
        "macos-start",
        "macos-stop",
        "macos-delete",
        "macos-push",
        "macos-check",
    ):
        commands.add_parser(command).add_argument("name")
    ssh = commands.add_parser(
        "macos-ssh", help="open a shell or run a command in a guest"
    )
    ssh.add_argument("name")
    ssh.add_argument("args", nargs=argparse.REMAINDER)
    for command in ("linux-start", "linux-stop", "linux-delete"):
        commands.add_parser(command)
    for command in ("linux-ssh", "linux-test"):
        # No option prefix, so every argument, `-h` included, passes through to the guest.
        passthrough = commands.add_parser(command, prefix_chars="\0", add_help=False)
        passthrough.add_argument("args", nargs=argparse.REMAINDER)
    for command, help_text in (
        ("windows-create", "add a UTM VM from a bundle or a disk image"),
        ("windows-provision", "install the toolchain, SSH key, and guest tools"),
        ("windows-start", "start the UTM guest (launching UTM.app if needed)"),
        ("windows-stop", "shut the UTM guest down"),
        ("windows-ip", "print the UTM guest's IPv4 address"),
        ("windows-push", "deliver the working tree to the guest's ~/tessera"),
        ("windows-conpty-smoke", "print ANSI-colored lines through a ConPTY"),
        ("windows-snapshot", "take a named snapshot of the stopped guest, or list them"),
        ("windows-restore", "put the stopped guest back to a snapshot"),
        ("windows-delete", "delete the UTM guest's bundle"),
    ):
        windows = commands.add_parser(command, help=help_text)
        windows.add_argument("--name", help="UTM VM (default: $TESSERA_WINDOWS_VM_NAME)")
        if command == "windows-stop":
            windows.add_argument("--force", action="store_true", help="power off")
            windows.add_argument(
                "--quit", action="store_true", help="quit UTM.app afterwards"
            )
        elif command == "windows-create":
            source = windows.add_mutually_exclusive_group(required=True)
            source.add_argument(
                "--import", dest="bundle", type=Path, help="copy this .utm bundle"
            )
            source.add_argument(
                "--disk", type=Path, help="wrap this qcow2 disk in the template"
            )
        elif command == "windows-snapshot":
            windows.add_argument("snapshot", nargs="?")
        elif command == "windows-restore":
            windows.add_argument("snapshot")
    for command in ("windows-ssh", "windows-test"):
        passthrough = commands.add_parser(command, prefix_chars="\0", add_help=False)
        passthrough.add_argument("args", nargs=argparse.REMAINDER)
    return parser


def guest_args(args: argparse.Namespace) -> list[str]:
    remote = getattr(args, "args", [])
    return remote[1:] if remote[:1] == ["--"] else remote


def dispatch(args: argparse.Namespace) -> int:
    command = args.command
    if command == "status":
        status()
    elif command == "macos-names":
        print("\n".join(name for name in tart_vms() if name.startswith("tessera-")))
    elif command.startswith("macos-"):
        require("tart")
        name = getattr(args, "name", None)
        if command == "macos-base":
            macos_base(args.major, args.xcode)
        elif command == "macos-clone":
            macos_clone(args.major)
        elif command == "macos-start":
            boot(name)
            print(
                f"vm: {name} is running; `mise run vm:macos-ssh {name}` opens a shell"
            )
        elif command == "macos-stop":
            tart_stop(name)
        elif command == "macos-delete":
            macos_delete(name)
        elif command == "macos-push":
            macos_push(name)
        elif command == "macos-check":
            return macos_check(name)
        elif command == "macos-ssh":
            boot(name)
            return run([*ssh_args(name), *guest_args(args)], check=False).returncode
    elif command.startswith("windows-"):
        name = windows_name(args)
        if command == "windows-create":
            windows_create(name, bundle=args.bundle, disk=args.disk)
        elif command == "windows-provision":
            windows_provision(name)
        elif command == "windows-start":
            windows_start(name)
        elif command == "windows-stop":
            windows_stop(name, force=args.force, quit_app=args.quit)
        elif command == "windows-ip":
            print(windows_ip(name))
        elif command == "windows-push":
            windows_push(name)
        elif command == "windows-conpty-smoke":
            return windows_conpty_smoke(name)
        elif command == "windows-snapshot":
            windows_snapshot(name, args.snapshot)
        elif command == "windows-restore":
            windows_restore(name, args.snapshot)
        elif command == "windows-delete":
            windows_delete(name)
        elif command == "windows-ssh":
            windows_boot(name)
            return run([*ssh_args(name), *guest_args(args)], check=False).returncode
        elif command == "windows-test":
            return windows_test(name, guest_args(args))
    else:
        require("limactl")
        name = linux_name()
        if command == "linux-start":
            linux_start(name)
        elif command == "linux-stop":
            run(["limactl", "stop", name])
        elif command == "linux-delete":
            run(["limactl", "delete", name])
        elif command == "linux-ssh":
            return run(
                ["limactl", "shell", name, *guest_args(args)], check=False
            ).returncode
        elif command == "linux-test":
            return linux_test(name, guest_args(args))
    return 0


def main(argv: list[str] | None = None) -> int:
    args = parser().parse_args(argv)
    storage()
    try:
        return dispatch(args)
    except VMError as error:
        print(f"vm: {error}", file=sys.stderr)
        return 1
    except subprocess.CalledProcessError as error:
        return error.returncode or 1
    except KeyboardInterrupt:
        return 130


if __name__ == "__main__":
    raise SystemExit(main())
