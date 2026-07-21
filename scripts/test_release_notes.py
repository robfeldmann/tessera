import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from scripts.release_notes import (
    ReleaseNotesError,
    extract_version_body,
    normalize_tag,
    render_release_notes,
)


VERSION_BODY = """### Added

- Added an exact, detailed capability description that must reach RSS readers unchanged.

### Fixed

- Fixed a specific failure mode without losing its technical explanation."""

CHANGELOG = f"""# Changelog

## [Unreleased]

### Added

- Added future work.

## [1.2.0] - 2026-07-20

{VERSION_BODY}

## [1.1.0] - 2026-07-01

### Added

- Added older work.
"""

FIRST_RELEASE_BODY = """### Added

- Added the complete first public release."""

FIRST_RELEASE_CHANGELOG = f"""# Changelog

## [Unreleased]

## [0.1.0] - 2026-07-20

{FIRST_RELEASE_BODY}

[Unreleased]: https://github.com/robfeldmann/tessera/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/robfeldmann/tessera/releases/tag/v0.1.0
"""


class ReleaseNotesTests(unittest.TestCase):
    def test_normalizes_a_semantic_version_tag(self) -> None:
        self.assertEqual(normalize_tag("v1.2.3"), ("v1.2.3", "1.2.3"))
        self.assertEqual(
            normalize_tag("1.2.3-beta.1+build.4"),
            ("v1.2.3-beta.1+build.4", "1.2.3-beta.1+build.4"),
        )

    def test_extracts_only_the_requested_version_verbatim(self) -> None:
        self.assertEqual(extract_version_body(CHANGELOG, "1.2.0"), VERSION_BODY)

    def test_extracts_the_last_version_before_trailing_link_definitions(self) -> None:
        self.assertEqual(
            extract_version_body(FIRST_RELEASE_CHANGELOG, "0.1.0"),
            FIRST_RELEASE_BODY,
        )

    def test_renders_a_tagged_source_link_before_the_exact_body(self) -> None:
        notes = render_release_notes("v1.2.0", CHANGELOG)

        self.assertIn(
            "https://github.com/robfeldmann/tessera/blob/v1.2.0/CHANGELOG.md",
            notes,
        )
        self.assertTrue(notes.endswith(f"{VERSION_BODY}\n"))

    def test_rejects_an_invalid_or_ambiguous_version_section(self) -> None:
        invalid_cases = {
            "missing": (CHANGELOG, "9.9.9", "no dated"),
            "duplicate": (
                CHANGELOG + "\n## [1.2.0] - 2026-07-21\n\n### Added\n\n- Duplicate.\n",
                "1.2.0",
                "multiple",
            ),
            "invalid date": (
                CHANGELOG.replace("2026-07-20", "2026-02-30"),
                "1.2.0",
                "invalid release date",
            ),
        }

        for name, (content, version, message) in invalid_cases.items():
            with self.subTest(name=name):
                with self.assertRaisesRegex(ReleaseNotesError, message):
                    extract_version_body(content, version)

    def test_rejects_content_that_cannot_round_trip_through_commit_tools(self) -> None:
        invalid_bodies = {
            "unknown category": "### Documentation\n\n- Added docs.",
            "out of order": "### Fixed\n\n- Fixed it.\n\n### Added\n\n- Added it.",
            "wrapped bullet": "### Added\n\n- Added a detailed entry\n  that was wrapped.",
            "interior link definition": (
                "### Added\n\n- Added before the link.\n\n"
                "[Guide]: https://example.com\n\n- Added after the link."
            ),
            "prose": "### Added\n\nUnbulleted release prose.",
        }

        for name, body in invalid_bodies.items():
            with self.subTest(name=name):
                changelog = f"## [1.2.0] - 2026-07-20\n\n{body}\n"
                with self.assertRaises(ReleaseNotesError):
                    extract_version_body(changelog, "1.2.0")

    def test_command_writes_the_first_release_body_before_link_definitions(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            directory = Path(temporary_directory)
            changelog = directory / "CHANGELOG.md"
            output = directory / "notes" / "release.md"
            changelog.write_text(FIRST_RELEASE_CHANGELOG, encoding="utf-8")

            result = subprocess.run(
                [
                    sys.executable,
                    "scripts/release_notes.py",
                    "v0.1.0",
                    str(output),
                    "--changelog",
                    str(changelog),
                ],
                check=False,
                capture_output=True,
                cwd=Path(__file__).parent.parent,
                text=True,
            )

            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(
                output.read_text(encoding="utf-8"),
                render_release_notes("v0.1.0", FIRST_RELEASE_CHANGELOG),
            )


if __name__ == "__main__":
    unittest.main()
