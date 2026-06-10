#!/usr/bin/env python3
"""Print project-scoped SwiftPM llvm-cov JSON coverage totals."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


def percent(covered: int, count: int) -> float:
    return 100.0 if count == 0 else covered * 100.0 / count


def add(into: dict, summary: dict) -> None:
    for key in ("lines", "functions", "regions"):
        into[key]["count"] += summary[key]["count"]
        into[key]["covered"] += summary[key]["covered"]


def empty_totals() -> dict:
    return {
        key: {"count": 0, "covered": 0} for key in ("lines", "functions", "regions")
    }


def is_project_source(path: Path, root: Path) -> bool:
    try:
        relative = path.resolve().relative_to(root)
    except ValueError:
        return False
    parts = relative.parts
    return bool(parts) and parts[0] == "Sources" and ".build" not in parts


def is_production_source(path: Path, root: Path) -> bool:
    try:
        relative = path.resolve().relative_to(root)
    except ValueError:
        return False
    parts = relative.parts
    return (
        bool(parts)
        and parts[0] == "Sources"
        and len(parts) > 1
        and not parts[1].startswith("C")
        and not parts[1].endswith("TestSupport")
        and "SnapshotSupport" not in parts[1]
    )


def print_totals(label: str, totals: dict) -> None:
    print(label)
    for key in ("lines", "functions", "regions"):
        item = totals[key]
        print(
            f"  {key:9} {item['covered']:5}/{item['count']:<5} {percent(item['covered'], item['count']):6.2f}%"
        )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "json", type=Path, help="Path from `swift test --show-codecov-path`"
    )
    parser.add_argument("--root", type=Path, default=Path.cwd())
    args = parser.parse_args()

    data = json.loads(args.json.read_text())
    files = data["data"][0]["files"]
    project = empty_totals()
    production = empty_totals()
    modules: dict[str, dict] = {}

    for file in files:
        path = Path(file["filename"])
        if not is_project_source(path, args.root):
            continue
        summary = file["summary"]
        add(project, summary)
        module = path.resolve().relative_to(args.root).parts[1]
        modules.setdefault(module, empty_totals())
        add(modules[module], summary)
        if is_production_source(path, args.root):
            add(production, summary)

    print_totals("All project Sources/", project)
    print_totals("Production Swift Sources/", production)
    print("Per-module line coverage")
    for module, totals in sorted(modules.items()):
        lines = totals["lines"]
        print(
            f"  {module:32} {lines['covered']:5}/{lines['count']:<5} {percent(lines['covered'], lines['count']):6.2f}%"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
