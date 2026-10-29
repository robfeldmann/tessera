"""Tests for the plans hub renderer: the hub is written and checked in `iwe normalize` form."""

from __future__ import annotations

import contextlib
import importlib.util
import io
import sys
import tempfile
import textwrap
import unittest
from pathlib import Path
from unittest import mock

PLANS_PATH = Path(__file__).with_name("plans.py")
SPEC = importlib.util.spec_from_file_location("plans", PLANS_PATH)
assert SPEC and SPEC.loader
plans = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(plans)

PLAN = textwrap.dedent(
    """\
    ---
    type: plan
    stage: proposed
    order: 1
    description: A plan
    created: 2026-01-01
    ---

    # First plan
    """
)

# Stands in for `iwe normalize -k plans`: refuses any other arguments and marks the hub, so a
# test can tell a normalized hub from a rendered one.
FAKE_IWE = textwrap.dedent(
    """\
    import sys
    from pathlib import Path

    if sys.argv[1:] != ["normalize", "-k", "plans"]:
        sys.exit("unexpected arguments: " + " ".join(sys.argv[1:]))
    hub = Path("plans.md")
    hub.write_text(hub.read_text() + "<!-- normalized -->\\n")
    """
)


class PlansHubTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        root = Path(self.temp.name)
        self.docs = root / "docs"
        (self.docs / "plans").mkdir(parents=True)
        (self.docs / "plans" / "first.md").write_text(PLAN, encoding="utf-8")
        fake = root / "fake_iwe.py"
        fake.write_text(FAKE_IWE, encoding="utf-8")
        self.hub = self.docs / "plans.md"
        for patcher in (
            mock.patch.object(plans, "ROOT", root),
            mock.patch.object(plans, "DOCS", self.docs),
            mock.patch.object(plans, "PLANS", self.docs / "plans"),
            mock.patch.object(plans, "HUB", self.hub),
            mock.patch.object(plans, "iwe_command", return_value=[sys.executable, str(fake)]),
        ):
            patcher.start()
            self.addCleanup(patcher.stop)

    def run_main(self, *argv: str) -> tuple[int, str, str]:
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = plans.main(list(argv))
        return code, out.getvalue(), err.getvalue()

    def test_rewrite_writes_the_normalized_hub(self) -> None:
        code, _, _ = self.run_main()
        self.assertEqual(code, 0)
        text = self.hub.read_text(encoding="utf-8")
        self.assertIn("[First plan](plans/first.md)", text)
        self.assertTrue(text.endswith("<!-- normalized -->\n"))

    def test_check_passes_after_a_rewrite(self) -> None:
        self.run_main()
        code, out, _ = self.run_main("--check")
        self.assertEqual(code, 0)
        self.assertIn("matches", out)

    def test_check_fails_on_a_hub_that_is_rendered_but_not_normalized(self) -> None:
        self.hub.write_text(plans.render(plans.load_plans()[0]), encoding="utf-8")
        code, _, err = self.run_main("--check")
        self.assertEqual(code, 1)
        self.assertIn("stale", err)

    def test_check_never_writes_the_workspace(self) -> None:
        self.hub.write_text("stale\n", encoding="utf-8")
        before = sorted((path, path.read_bytes()) for path in self.docs.rglob("*") if path.is_file())
        code, _, _ = self.run_main("--check")
        after = sorted((path, path.read_bytes()) for path in self.docs.rglob("*") if path.is_file())
        self.assertEqual(code, 1)
        self.assertEqual(before, after)

    def test_a_failing_iwe_stops_the_run(self) -> None:
        with mock.patch.object(plans, "iwe_command", return_value=[sys.executable, "-c", "raise SystemExit(3)"]):
            with self.assertRaises(SystemExit) as raised:
                self.run_main("--check")
        self.assertIn("failed", str(raised.exception))

    def test_a_missing_iwe_stops_the_run(self) -> None:
        with mock.patch.object(plans, "iwe_command", return_value=["/nonexistent/iwe"]):
            with self.assertRaises(SystemExit) as raised:
                self.run_main("--check")
        self.assertIn("cannot run iwe", str(raised.exception))


if __name__ == "__main__":
    unittest.main()
