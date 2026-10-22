#!/usr/bin/env python3
"""Tessera's VMs: macOS guests under Tart and the Linux guest under Lima.

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
"""

from __future__ import annotations

import argparse
import json
import os
import shlex
import shutil
import subprocess
import sys
import tarfile
import tempfile
import time
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


def write_ssh_config(*extra: str) -> None:
    """Write a Host entry for every Tessera Tart VM plus `extra`, resolving `tart ip`."""
    ensure_key()
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    KNOWN_HOSTS.touch(mode=0o600, exist_ok=True)
    tart = shutil.which("tart")
    names = sorted(
        {name for name in tart_vms() if name.startswith("tessera-")} | set(extra)
    )
    lines = [
        "# Generated by scripts/vm.py (mise run vm:*); edits are overwritten.\n",
        f"# Use it with `ssh -F {SSH_CONFIG} <vm>`, or Include it from ~/.ssh/config.\n",
    ]
    for name in names:
        resolve = (
            f'exec /usr/bin/nc "$(TART_HOME={shlex.quote(os.environ["TART_HOME"])} '
            f'{shlex.quote(tart)} ip {name} --wait 60)" 22'
        )
        lines += [
            f"\nHost {name}\n",
            f"  User {GUEST_USER}\n",
            f"  ProxyCommand /bin/sh -c {shlex.quote(resolve)}\n",
            f'  IdentityFile "{SSH_KEY}"\n',
            "  IdentitiesOnly yes\n",
            f"  HostKeyAlias {name}\n",
            "  StrictHostKeyChecking accept-new\n",
            f'  UserKnownHostsFile "{KNOWN_HOSTS}"\n',
            "  ServerAliveInterval 30\n",
            "  LogLevel ERROR\n",
        ]
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
        authorize = "true"
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
    """Tracked plus untracked-but-not-ignored paths, as windows-frost-sync-source.sh sends."""
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

scripts/build-libghostty-vt.sh
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
    print(f"SSH config: {SSH_CONFIG}")


def parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="vm.py", description=__doc__.splitlines()[0])
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("status", help="list the Tart and Lima VMs")
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
