"""Regression tests for the Conventional Commit validator."""

from __future__ import annotations

import contextlib
import importlib.util
import io
import tempfile
import unittest
from pathlib import Path
from unittest import mock


VALIDATOR_PATH = Path(__file__).with_name("conventional_commits.py")
SPEC = importlib.util.spec_from_file_location("conventional_commits", VALIDATOR_PATH)
assert SPEC and SPEC.loader
validator = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(validator)


class ConventionalCommitTests(unittest.TestCase):
    def run_main(self, *args: str) -> tuple[int, str, str]:
        stdout = io.StringIO()
        stderr = io.StringIO()
        with contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
            result = validator.main(list(args))
        return result, stdout.getvalue(), stderr.getvalue()

    def test_message_file_validates_only_its_first_line(self) -> None:
        with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8") as message_file:
            message_file.write("feat(hooks): validate commit messages\ninvalid body text\n")
            message_file.flush()

            result, stdout, stderr = self.run_main("--message-file", message_file.name)

        self.assertEqual(result, 0)
        self.assertEqual(stdout, "Validated 1 Conventional Commit subject(s).\n")
        self.assertEqual(stderr, "")

    def test_message_file_rejects_invalid_first_line(self) -> None:
        with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8") as message_file:
            message_file.write("invalid subject\nfeat: valid body text\n")
            message_file.flush()

            result, stdout, stderr = self.run_main("--message-file", message_file.name)

        self.assertEqual(result, 1)
        self.assertEqual(stdout, "")
        self.assertIn("invalid subject", stderr)
        self.assertIn("Example: feat: add thing", stderr)

    def test_subject_range_and_message_file_share_validation(self) -> None:
        with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8") as message_file:
            message_file.write("fix: repair validation\n")
            message_file.flush()

            self.assertEqual(self.run_main("fix: repair validation")[0], 0)
            self.assertEqual(self.run_main("--message-file", message_file.name)[0], 0)
            with mock.patch.object(validator, "subjects_in_range", return_value=["fix: repair validation"]):
                self.assertEqual(self.run_main("--range", "before..after")[0], 0)

            self.assertEqual(self.run_main("invalid subject")[0], 1)
            with mock.patch.object(validator, "subjects_in_range", return_value=["invalid subject"]):
                self.assertEqual(self.run_main("--range", "before..after")[0], 1)

    def test_message_file_mode_rejects_conflicts_and_missing_files(self) -> None:
        for args in (
            ("feat: add thing", "--message-file", "message"),
            ("--range", "before..after", "--message-file", "message"),
        ):
            with self.assertRaises(SystemExit) as error:
                self.run_main(*args)
            self.assertEqual(error.exception.code, 2)

        with self.assertRaises(SystemExit) as error:
            self.run_main("--message-file", "missing-message")
        self.assertEqual(error.exception.code, 2)

    def test_empty_message_file_is_invalid(self) -> None:
        with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8") as message_file:
            result, _, stderr = self.run_main("--message-file", message_file.name)

        self.assertEqual(result, 1)
        self.assertIn("Expected format: type(scope): description", stderr)


if __name__ == "__main__":
    unittest.main()
