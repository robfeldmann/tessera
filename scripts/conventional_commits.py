#!/usr/bin/env python3
"""Validate Conventional Commit subjects.

Usage:
  scripts/conventional_commits.py "feat: add thing"
  scripts/conventional_commits.py --range BEFORE..AFTER
  scripts/conventional_commits.py --message-file .git/COMMIT_EDITMSG
"""

from __future__ import annotations

import argparse
import re
from pathlib import Path
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


def subject_in_message_file(message_file: str) -> str:
    try:
        with Path(message_file).open(encoding="utf-8") as file:
            return file.readline().rstrip("\r\n")
    except OSError as error:
        raise ValueError(f"unable to read commit message file {message_file!r}: {error}") from error


def is_valid(subject: str) -> bool:
    if subject.startswith("Merge "):
        return True
    return bool(CONVENTIONAL_SUBJECT.match(subject))


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("subject", nargs="?", help="single commit subject or PR title")
    parser.add_argument("--range", dest="commit_range", help="git commit range to validate")
    parser.add_argument("--message-file", help="Git commit message file to validate")
    args = parser.parse_args(argv)

    if args.commit_range and args.subject:
        parser.error("pass either a subject or --range, not both")
    if args.message_file and args.subject:
        parser.error("pass either a subject or --message-file, not both")
    if args.message_file and args.commit_range:
        parser.error("pass either --range or --message-file, not both")
    if not args.commit_range and not args.subject and not args.message_file:
        parser.error("pass a subject or --range")

    try:
        subjects = (
            subjects_in_range(args.commit_range)
            if args.commit_range
            else [subject_in_message_file(args.message_file)]
            if args.message_file
            else [args.subject]
        )
    except ValueError as error:
        parser.error(str(error))
    failures = [subject for subject in subjects if not is_valid(subject)]

    if failures:
        print("Invalid Conventional Commit subject(s):", file=sys.stderr)
        for subject in failures:
            print(f"  - {subject}", file=sys.stderr)
        print("\nExpected format: type(scope): description", file=sys.stderr)
        print("Allowed types: build, chore, ci, docs, feat, fix, perf, refactor, revert, style, test", file=sys.stderr)
        if args.message_file:
            print("Example: feat: add thing", file=sys.stderr)
        return 1

    print(f"Validated {len(subjects)} Conventional Commit subject(s).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
