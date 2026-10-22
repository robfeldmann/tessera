#!/usr/bin/env python3
"""Serve the component gallery: the design catalog's wireframes, one page per component.

    /                    index of catalog components by folder, with their status
    /c/<slug>            one component: every wireframe fence, in document order
    /tokens              role swatches and catalog samples per theme (docs/design/tokens.md)

Pages are built on every request from `docs/design/primitives/*.md` and `docs/design/widgets/*.md`
(each `wireframe` fence is one entry; a styled grid that follows it colours it) and show
empty "Current" and "Previous" slots until `.build/tessera-dev/` holds renders of the real
widgets. Choose a colour theme with `?theme=` (see DevTools/gallery/themes.json). A banner
offers a reload when those files change on disk.

    python3 scripts/gallery-serve.py [--port 8790] [--host HOST] [--font-dir DIR]

By default it listens on 127.0.0.1 and, when available, this machine's Tailscale IPv4
address; --host replaces both. A Nerd Font found on this machine is served to the browser
so Powerline and icon glyphs draw. Standard library only; the pages and colour maths live in
DevTools/gallery.
"""

from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
import threading
import traceback
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, unquote, urlsplit

REPO = Path(__file__).resolve().parent.parent
sys.dont_write_bytecode = True
sys.path.insert(0, str(REPO / "DevTools"))

from gallery import pages  # noqa: E402

FONT_FACES = {
    "regular": ["MapleMono-NF-Regular.ttf", "JetBrainsMonoNLNerdFont-Regular.ttf"],
    "bold": ["MapleMono-NF-Bold.ttf", "JetBrainsMonoNLNerdFont-Bold.ttf"],
}
FONT_DIRS = [
    Path.home() / "Library/Fonts",
    Path("/Library/Fonts"),
    Path.home() / ".local/share/fonts",
    Path("/usr/share/fonts"),
]


def find_fonts(extra: Path | None) -> dict[str, Path]:
    dirs = ([extra] if extra else []) + FONT_DIRS
    found = {}
    for face, names in FONT_FACES.items():
        for name in names:
            match = next((d / name for d in dirs if (d / name).is_file()), None)
            if match:
                found[face] = match
                break
    return found


def tailscale_ip() -> str | None:
    tailscale = shutil.which("tailscale") or "/Applications/Tailscale.app/Contents/MacOS/Tailscale"
    try:
        out = subprocess.run(
            [tailscale, "ip", "-4"], capture_output=True, text=True, timeout=5, check=True
        ).stdout.split()
    except (OSError, subprocess.SubprocessError):
        return None
    return out[0] if out else None


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--host", action="append", help="bind address (repeatable)")
    parser.add_argument("--port", type=int, default=8790)
    parser.add_argument("--font-dir", type=Path, help="directory holding a Nerd Font .ttf")
    args = parser.parse_args()
    fonts = find_fonts(args.font_dir)
    hosts = args.host or ["127.0.0.1", *filter(None, [tailscale_ip()])]

    class Handler(BaseHTTPRequestHandler):
        def do_GET(self) -> None:  # noqa: N802 (http.server API)
            url = urlsplit(self.path)
            path = unquote(url.path).rstrip("/") or "/"
            query = {key: values[0] for key, values in parse_qs(url.query).items()}
            try:
                self.route(path, query)
            except Exception:  # a dev tool: show the traceback in the browser
                self.send(500, "text/plain; charset=utf-8", traceback.format_exc().encode())

        def route(self, path: str, query: dict[str, str]) -> None:
            body: str | None
            if path in ("/", "/index.html"):
                body = pages.index_page(pages.pick_theme(query.get("theme")))
            elif path.startswith("/c/"):
                body = pages.component_page(
                    path.removeprefix("/c/"), pages.pick_theme(query.get("theme"))
                )
            elif path == "/tokens":
                body = pages.tokens_page(query.get("tier"))
            elif path == "/api/stamp":
                self.send(200, "text/plain", pages.stamp().encode())
                return
            elif path.startswith("/render/"):
                slug, _, name = path.removeprefix("/render/").partition("/")
                render = pages.render_path(slug, name)
                if render is None:
                    self.send(404, "text/plain", b"not found")
                else:
                    self.send(200, "image/svg+xml", render.read_bytes())
                return
            elif path.startswith("/font/") and path.removeprefix("/font/").removesuffix(
                ".ttf"
            ) in fonts:
                face = path.removeprefix("/font/").removesuffix(".ttf")
                self.send(200, "font/ttf", fonts[face].read_bytes())
                return
            else:
                body = None
            if body is None:
                self.send(404, "text/plain", b"not found")
            else:
                self.send(200, "text/html; charset=utf-8", body.encode())

        def send(self, status: int, kind: str, body: bytes) -> None:
            self.send_response(status)
            self.send_header("Content-Type", kind)
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(body)

        def log_message(self, *_: object) -> None:
            pass

    servers = [ThreadingHTTPServer((host, args.port), Handler) for host in hosts]
    font_note = ", ".join(f"{k}: {v.name}" for k, v in fonts.items()) or "none found"
    urls = ", ".join(f"http://{host}:{args.port}/" for host in hosts)
    print(f"gallery on {urls} (font {font_note})", flush=True)
    for server in servers[1:]:
        threading.Thread(target=server.serve_forever, daemon=True).start()
    servers[0].serve_forever()


if __name__ == "__main__":
    main()
