#!/usr/bin/env python3
"""Reject view-layer target edges that cross Tessera's ownership boundary."""

from __future__ import annotations

import json
import sys
from collections.abc import Mapping, Sequence
from typing import Any, TextIO


ALLOWED_DIRECT_DEPENDENCIES: dict[str, frozenset[str]] = {
    "TesseraCore": frozenset(
        {"TesseraTerminalBuffer", "TesseraTerminalCore", "TesseraTerminalInput"}
    ),
    "TesseraLayout": frozenset({"TesseraCore"}),
    "TesseraWidgets": frozenset({"TesseraCore", "TesseraLayout"}),
    "Tessera": frozenset(
        {"TesseraCore", "TesseraLayout", "TesseraTerminal", "TesseraWidgets"}
    ),
}
ALLOWED_PRODUCT_DEPENDENCIES: dict[str, frozenset[str]] = {
    target: frozenset() for target in ALLOWED_DIRECT_DEPENDENCIES
}



def package_dependencies(
    package: Mapping[str, Any],
) -> tuple[dict[str, frozenset[str]], dict[str, frozenset[str]]]:
    """Return each declared target's direct target and product dependencies."""
    targets = package.get("targets")
    if not isinstance(targets, Sequence) or isinstance(targets, (str, bytes)):
        raise ValueError("Package description must contain a targets array")

    target_dependencies: dict[str, frozenset[str]] = {}
    product_dependencies: dict[str, frozenset[str]] = {}
    for target in targets:
        if not isinstance(target, Mapping):
            raise ValueError("Package description contains a non-object target")

        name = target.get("name")
        if not isinstance(name, str):
            raise ValueError("Package target is missing a string name")

        target_dependencies[name] = validated_dependencies(
            target,
            name=name,
            key="target_dependencies",
            description="target",
        )
        product_dependencies[name] = validated_dependencies(
            target,
            name=name,
            key="product_dependencies",
            description="product",
        )

    return target_dependencies, product_dependencies


def validated_dependencies(
    target: Mapping[str, Any],
    *,
    name: str,
    key: str,
    description: str,
) -> frozenset[str]:
    """Validate and return one SwiftPM dependency array."""
    raw_dependencies = target.get(key, [])
    if not isinstance(raw_dependencies, Sequence) or isinstance(
        raw_dependencies, (str, bytes)
    ):
        raise ValueError(f"Target {name} has a non-array {key} value")
    if not all(isinstance(dependency, str) for dependency in raw_dependencies):
        raise ValueError(f"Target {name} has a non-string {description} dependency")
    return frozenset(raw_dependencies)


def check_package_boundaries(package: Mapping[str, Any]) -> list[str]:
    """Return deterministic diagnostics for missing or illegal view-layer edges."""
    target_dependencies, product_dependencies = package_dependencies(package)
    violations: list[str] = []

    for target, allowed_dependencies in ALLOWED_DIRECT_DEPENDENCIES.items():
        actual_dependencies = target_dependencies.get(target)
        if actual_dependencies is None:
            violations.append(f"Missing required view-layer target: {target}")
            continue

        for dependency in sorted(actual_dependencies - allowed_dependencies):
            violations.append(f"{target} -> {dependency}")
        actual_products = product_dependencies[target]
        allowed_products = ALLOWED_PRODUCT_DEPENDENCIES[target]
        for dependency in sorted(actual_products - allowed_products):
            violations.append(f"{target} -> product {dependency}")

    return violations


def main(stdin: TextIO = sys.stdin, stderr: TextIO = sys.stderr) -> int:
    try:
        package = json.load(stdin)
        if not isinstance(package, Mapping):
            raise ValueError("Package description must be a JSON object")
        violations = check_package_boundaries(package)
    except (json.JSONDecodeError, ValueError) as error:
        print(f"Invalid SwiftPM package description: {error}", file=stderr)
        return 2

    if not violations:
        return 0

    print("Forbidden package dependency edges:", file=stderr)
    print("\n".join(violations), file=stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
