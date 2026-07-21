#!/usr/bin/env python3
"""Extract one version's curated changelog text for a GitHub Release body."""

from __future__ import annotations

import argparse
import re
from datetime import date
from pathlib import Path

REPOSITORY = "robfeldmann/tessera"
SUPPORTED_CATEGORIES = (
    "Breaking Changes",
    "Added",
    "Changed",
    "Deprecated",
    "Removed",
    "Fixed",
    "Security",
)
SEMVER_PATTERN = (
    r"(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)"
    r"(?:-[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?"
    r"(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?"
)
LINK_REFERENCE_DEFINITION = re.compile(
    r"^\[[^\]\n]+\]:[ \t]+\S.*$",
    re.MULTILINE,
)


class ReleaseNotesError(ValueError):
    """The changelog cannot produce release notes for the requested tag."""


def normalize_tag(value: str) -> tuple[str, str]:
    """Return canonical tag and changelog version strings."""
    candidate = value.strip()
    version = candidate[1:] if candidate.startswith("v") else candidate
    if re.fullmatch(SEMVER_PATTERN, version) is None:
        raise ReleaseNotesError(f"expected a v<SemVer> tag, got {value!r}")
    return f"v{version}", version


def extract_version_body(content: str, version: str) -> str:
    """Return the exact body under one dated changelog version heading."""
    heading = re.compile(
        rf"^## \[{re.escape(version)}\] - (?P<date>\d{{4}}-\d{{2}}-\d{{2}})\s*$",
        re.MULTILINE,
    )
    matches = list(heading.finditer(content))
    if not matches:
        raise ReleaseNotesError(f"CHANGELOG.md has no dated [{version}] section")
    if len(matches) > 1:
        raise ReleaseNotesError(f"CHANGELOG.md has multiple [{version}] sections")

    match = matches[0]
    try:
        date.fromisoformat(match.group("date"))
    except ValueError as error:
        raise ReleaseNotesError(
            f"CHANGELOG.md [{version}] has an invalid release date"
        ) from error

    next_heading = re.search(r"^## \[", content[match.end() :], re.MULTILINE)
    end = match.end() + next_heading.start() if next_heading else len(content)
    section = content[match.end() : end]
    link_definitions = _trailing_link_definitions_start(section)
    if link_definitions is not None:
        section = section[:link_definitions]
    body = section.strip()
    if not body:
        raise ReleaseNotesError(f"CHANGELOG.md [{version}] is empty")

    _validate_body(body, version)
    return body


def _trailing_link_definitions_start(content: str) -> int | None:
    for match in LINK_REFERENCE_DEFINITION.finditer(content):
        remainder = content[match.start() :]
        if all(
            not line.strip() or LINK_REFERENCE_DEFINITION.fullmatch(line)
            for line in remainder.splitlines()
        ):
            return match.start()
    return None


def _validate_body(body: str, version: str) -> None:
    category_indexes: list[int] = []
    saw_bullet = False
    current_category: str | None = None

    for line in body.splitlines():
        if not line.strip():
            continue
        if line.startswith("### "):
            category = line.removeprefix("### ").strip()
            if category not in SUPPORTED_CATEGORIES:
                raise ReleaseNotesError(
                    f"CHANGELOG.md [{version}] uses unsupported category {category!r}"
                )
            category_index = SUPPORTED_CATEGORIES.index(category)
            if category_index in category_indexes:
                raise ReleaseNotesError(
                    f"CHANGELOG.md [{version}] repeats category {category!r}"
                )
            if category_indexes and category_index < category_indexes[-1]:
                raise ReleaseNotesError(
                    f"CHANGELOG.md [{version}] categories are out of canonical order"
                )
            category_indexes.append(category_index)
            current_category = category
            continue
        if current_category is None or not line.startswith(("- ", "* ")):
            raise ReleaseNotesError(
                f"CHANGELOG.md [{version}] contains non-bullet or wrapped entry text: {line!r}"
            )
        saw_bullet = True

    if not category_indexes:
        raise ReleaseNotesError(
            f"CHANGELOG.md [{version}] has no supported category headings"
        )
    if not saw_bullet:
        raise ReleaseNotesError(f"CHANGELOG.md [{version}] has no release-note entries")


def render_release_notes(tag: str, content: str) -> str:
    """Build a release body while preserving the changelog section verbatim."""
    canonical_tag, version = normalize_tag(tag)
    body = extract_version_body(content, version)
    source_url = (
        f"https://github.com/{REPOSITORY}/blob/{canonical_tag}/CHANGELOG.md"
    )
    return (
        "These curated notes are copied verbatim from "
        f"[CHANGELOG.md]({source_url}).\n\n{body}\n"
    )


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Extract a tagged CHANGELOG.md section for a GitHub Release."
    )
    parser.add_argument("tag", help="Release tag in v<SemVer> form")
    parser.add_argument(
        "output",
        nargs="?",
        type=Path,
        default=Path(".build/release-notes.md"),
        help="Output Markdown path (default: .build/release-notes.md)",
    )
    parser.add_argument(
        "--changelog",
        type=Path,
        default=Path("CHANGELOG.md"),
        help="Changelog path (default: CHANGELOG.md)",
    )
    return parser.parse_args()


def main() -> None:
    arguments = parse_arguments()
    try:
        content = arguments.changelog.read_text(encoding="utf-8")
        notes = render_release_notes(arguments.tag, content)
    except (OSError, ReleaseNotesError) as error:
        raise SystemExit(f"error: {error}") from error

    arguments.output.parent.mkdir(parents=True, exist_ok=True)
    arguments.output.write_text(notes, encoding="utf-8")
    print(f"Wrote {arguments.output}")


if __name__ == "__main__":
    main()
