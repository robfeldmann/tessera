"""Regression tests for the annotation-free wireframe geometry validator."""

from __future__ import annotations

import contextlib
import importlib.util
import io
import tempfile
import unittest
from pathlib import Path


CHECKER_PATH = Path(__file__).with_name("check-wireframes.py")
SPEC = importlib.util.spec_from_file_location("check_wireframes", CHECKER_PATH)
assert SPEC and SPEC.loader
checker = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(checker)


class GeometryTests(unittest.TestCase):
    def assert_geometry_clean(self, rows: list[str]) -> None:
        self.assertEqual(checker.check_wireframe_geometry(rows, 10), [])

    def test_aligned_light_rounded_heavy_and_double_boxes(self) -> None:
        for rows in (
            ["┌──┐", "│  │", "└──┘"],
            ["╭──╮", "│  │", "╰──╯"],
            ["┏━━┓", "┃  ┃", "┗━━┛"],
            ["╔══╗", "║  ║", "╚══╝"],
        ):
            with self.subTest(rows=rows):
                self.assert_geometry_clean(rows)

    def test_junctions_can_form_a_split_box(self) -> None:
        self.assert_geometry_clean(
            [
                "┌──┬──┐",
                "│  │  │",
                "├──┼──┤",
                "│  │  │",
                "└──┴──┘",
            ]
        )

    def test_junction_reciprocity_requires_top_separator_shape(self) -> None:

        self.assert_geometry_clean(
            [
                "┌──┬──┐",
                "│  │  │",
                "└──┴──┘",
            ]
        )
        errors = checker.check_wireframe_geometry(
            [
                "┌──┼──┐",
                "│  │  │",
                "└──┴──┘",
            ],
            1,
        )
        self.assertTrue(
            any("junction lacks a reciprocal connection north" in error for error in errors)
        )

    def test_non_box_crosshair_requires_three_reciprocal_arms(self) -> None:
        crosshair = (
            "──────────────────────┼────────────────────────────────┼──────────────────────",
            "                      │                                │                      ",
        )
        errors = checker.check_wireframe_geometry(list(crosshair), 1)
        self.assertGreaterEqual(
            sum("junction lacks a reciprocal connection north" in error for error in errors),
            2,
        )
        self.assert_geometry_clean(
            [
                crosshair[0].replace("┼", "┬"),
                crosshair[1],
            ]
        )

    def test_titled_top_border_is_allowed(self) -> None:
        self.assert_geometry_clean(["┌ Title ┐", "│       │", "└───────┘"])

    def test_side_by_side_and_nested_boxes_are_allowed(self) -> None:
        self.assert_geometry_clean(["┌─┐ ┌─┐", "│ │ │ │", "└─┘ └─┘"])
        self.assert_geometry_clean(
            [
                "┌─────┐",
                "│┌──┐ │",
                "││  │ │",
                "│└──┘ │",
                "└─────┘",
            ]
        )

    def test_wide_and_combining_content_uses_display_columns(self) -> None:
        rows = ["界e\u0301┌──┐", "界e\u0301│  │", "界e\u0301└──┘"]
        self.assert_geometry_clean(rows)
        self.assertEqual(checker.display_grid(rows)[0][3], "┌")

    def test_extended_graphemes_keep_box_edges_in_display_columns(self) -> None:
        rows = [
            "┌─────────┐",
            "│東京👩🏽‍💻 e\u0301▏│",
            "└─────────┘",
        ]
        self.assert_geometry_clean(rows)
        self.assertEqual(checker.display_width("東京👩🏽‍💻 e\u0301▏"), 9)
        self.assertEqual(checker.display_grid(rows)[1][10], "│")

    def test_extended_grapheme_widths(self) -> None:
        self.assertEqual(checker.display_width("e\u0301"), 1)
        self.assertEqual(checker.display_width("\u0301"), 0)
        self.assertEqual(checker.display_width("👩🏽‍💻"), 2)
        self.assertEqual(checker.display_width("🇯🇵"), 2)
        self.assertEqual(checker.display_width("1️⃣"), 2)
        self.assertEqual(checker.display_width("☀️"), 2)

    def test_trailing_scroll_indicators_stay_in_a_single_column(self) -> None:
        self.assert_geometry_clean(["content │", "content █"])
        self.assert_geometry_clean(["content |", "content #"])

        unicode_errors = checker.check_wireframe_geometry(["content │", "content  █"], 1)
        ascii_errors = checker.check_wireframe_geometry(["content |", "content  #"], 1)
        self.assertTrue(
            any("trailing indicator shifts to column 9" in error for error in unicode_errors)
        )
        self.assertTrue(
            any("trailing indicator shifts to column 9" in error for error in ascii_errors)
        )

    def test_shifted_right_border_reports_display_coordinates(self) -> None:
        errors = checker.check_wireframe_geometry(["┌──┐", "│  │", "└──  ┘"], 40)
        self.assertTrue(any("line 41 column 3" in error for error in errors))
        self.assertTrue(any("shifts to column 5" in error for error in errors))
        self.assertTrue(any("bottom-right corner is missing at column 3" in error for error in errors))

    def test_missing_top_right_corner_is_rejected_when_box_is_otherwise_closed(self) -> None:
        errors = checker.check_wireframe_geometry(["┌── ", "│  │", "└──┘"], 40)
        self.assertTrue(any("line 40 column 3" in error for error in errors))
        self.assertTrue(
            any("box top-right corner is missing at column 3" in error for error in errors)
        )

    def test_mismatched_bottom_corner_and_edge_are_rejected(self) -> None:
        corner_errors = checker.check_wireframe_geometry(["┌──┐", "│  │", "└──┐"], 1)
        self.assertTrue(any("bottom-right corner is missing" in error for error in corner_errors))

        edge_errors = checker.check_wireframe_geometry(["┌──┐", "│  │", "└  ┘"], 1)
        self.assertTrue(any("bottom edge lacks" in error for error in edge_errors))

    def test_shifted_split_view_like_divider_is_rejected(self) -> None:
        errors = checker.check_wireframe_geometry(
            ["┌──┬──┐", "│  │  │", "│   │ │", "└─────┘"], 1
        )
        self.assertTrue(any("line 2 column 3" in error for error in errors))
        self.assertTrue(any("shifts to column 4" in error for error in errors))

    def test_standalone_divider_endpoint_is_allowed(self) -> None:
        self.assert_geometry_clean(["──┬──", "     "])
        self.assert_geometry_clean(["┌"])
        self.assert_geometry_clean(["┌── ", "│   ", "└──┘"])
        self.assert_geometry_clean(["┌── ", "│  ┌", "│  │", "└──┘"])
        self.assert_geometry_clean(["██"])
        self.assert_geometry_clean(["───"])
        self.assert_geometry_clean(["+"])
        self.assert_geometry_clean(["┼"])

    def test_orphan_corner_is_reported_only_in_box_network(self) -> None:
        errors = checker.check_wireframe_geometry(["┌───┐", "│┌  │", "└───┘"], 1)
        self.assertTrue(any("orphan box corner" in error for error in errors))
        self.assert_geometry_clean(["┌"])


class FileAndCliTests(unittest.TestCase):
    def write_markdown(self, directory: Path, name: str, body: str) -> Path:
        path = directory / name
        path.write_text(body, encoding="utf-8")
        return path

    def test_existing_dimension_tab_and_trailing_whitespace_rules(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            path = self.write_markdown(
                Path(temporary),
                "invalid.md",
                "```wireframe 2x1\nabc \t\n```\n",
            )
            errors = checker.check_file(path)
            height_path = self.write_markdown(
                Path(temporary),
                "wrong-height.md",
                "```wireframe 2x2\nok\n```\n",
            )
            height_errors = checker.check_file(height_path)
        self.assertTrue(any("trailing whitespace" in error for error in errors))
        self.assertTrue(any("tab character" in error for error in errors))
        self.assertTrue(any("display width 3 exceeds" in error for error in errors))
        self.assertTrue(any("declared 2x2 but block has 1 rows" in error for error in height_errors))

    def test_check_file_and_cli_accept_a_valid_wireframe(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            path = self.write_markdown(
                Path(temporary),
                "valid.md",
                "```wireframe 4x3\n┌──┐\n│OK│\n└──┘\n```\n",
            )
            self.assertEqual(checker.check_file(path), [])
            stdout = io.StringIO()
            stderr = io.StringIO()
            with contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
                status = checker.main([str(path)])
        self.assertEqual(status, 0)
        self.assertIn("1 file(s) clean", stdout.getvalue())
        self.assertEqual(stderr.getvalue(), "")


if __name__ == "__main__":
    unittest.main()
