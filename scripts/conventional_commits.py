#!/usr/bin/env python3
"""Validate Conventional Commit subjects.

Usage:
  scripts/conventional_commits.py "feat: add thing"
  scripts/conventional_commits.py --range BEFORE..AFTER
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys

CONVENTIONAL_SUBJECT = re.compile(
    r"^(?P<type>build|chore|ci|docs|feat|fix|perf|refactor|revert|style|test)"
    r"(\([A-Za-z0-9_.-]+\))?"
    r"!?"
    r": "
    r"\S.*$"
)

ZERO_SHA = "0" * 40


def subjects_in_range(commit_range: str) -> list[str]:
    before, sep, after = commit_range.partition("..")
    if not sep:
        raise ValueError(f"expected commit range BEFORE..AFTER, got {commit_range!r}")

    if before == ZERO_SHA:
        commit_range = after

    try:
        result = subprocess.run(
            ["git", "log", "--format=%s", commit_range],
            check=True,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
    except subprocess.CalledProcessError as error:
        if sep and before != ZERO_SHA:
            print(
                "Unable to resolve pushed commit range; this can happen after a force push. "
                "Validating the pushed HEAD commit only.",
                file=sys.stderr,
            )
            result = subprocess.run(
                ["git", "log", "--format=%s", "-1", after],
                check=True,
                text=True,
                stdout=subprocess.PIPE,
            )
        else:
            raise error

    return [line for line in result.stdout.splitlines() if line]


def is_valid(subject: str) -> bool:
    if subject.startswith("Merge "):
        return True
    return bool(CONVENTIONAL_SUBJECT.match(subject))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("subject", nargs="?", help="single commit subject or PR title")
    parser.add_argument("--range", dest="commit_range", help="git commit range to validate")
    args = parser.parse_args()

    if args.commit_range and args.subject:
        parser.error("pass either a subject or --range, not both")
    if not args.commit_range and not args.subject:
        parser.error("pass a subject or --range")

    subjects = subjects_in_range(args.commit_range) if args.commit_range else [args.subject]
    failures = [subject for subject in subjects if not is_valid(subject)]

    if failures:
        print("Invalid Conventional Commit subject(s):", file=sys.stderr)
        for subject in failures:
            print(f"  - {subject}", file=sys.stderr)
        print("\nExpected format: type(scope): description", file=sys.stderr)
        print("Allowed types: build, chore, ci, docs, feat, fix, perf, refactor, revert, style, test", file=sys.stderr)
        return 1

    print(f"Validated {len(subjects)} Conventional Commit subject(s).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
