"""Regression tests for the annotation-free wireframe geometry validator."""

from __future__ import annotations

import contextlib
import importlib.util
import io
import sys
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

    def test_scroll_thumbs_continue_a_box_edge_without_starting_one(self) -> None:
        for thumb in "█▐▌":
            self.assert_geometry_clean(["┌──┐┌──┐", "│ a││ a│", f"│ b{thumb}│ b{thumb}", "└──┘└──┘"])

        errors = checker.check_wireframe_geometry(["┌──┐", "│ a│", "│ b █", "└──┘"], 1)
        self.assertTrue(any("vertical edge lacks a reciprocal connection below" in e for e in errors))
        self.assert_geometry_clean(["█", "│"])

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


WIREFRAME = ["```wireframe 6x1", "[ OK ]", "```"]


def document(
    *,
    wireframe: list[str] | None = None,
    header: str = "text",
    chars: list[str] | None = None,
    style: list[str] | None = None,
    legend: list[str] | None = None,
) -> str:
    """A wireframe followed by its styled grid. With the defaults, lines 1-3 are the
    wireframe, line 5 opens the grid, 6-7 are its chars, 8-9 its style and 10-11 its
    legend."""
    lines = [
        *(WIREFRAME if wireframe is None else wireframe),
        "",
        f"```{header}",
        "── chars ──",
        *(["[ OK ]"] if chars is None else chars),
        "── style ──",
        *([".AAAA."] if style is None else style),
        "── legend ──",
        *(["A  fg=accent bold"] if legend is None else legend),
        "```",
    ]
    return "\n".join(lines) + "\n"


class LintTestCase(unittest.TestCase):
    def lint(self, body: str) -> list[str]:
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "doc.md"
            path.write_text(body, encoding="utf-8")
            return [error.removeprefix(f"{path}:") for error in checker.check_file(path)]

    def assert_clean(self, body: str) -> None:
        self.assertEqual(self.lint(body), [])

    def assert_error(self, body: str, line: int, fragment: str) -> None:
        errors = self.lint(body)
        self.assertTrue(
            any(error.startswith(f"{line}:") and fragment in error for error in errors),
            f"no `{fragment}` error at line {line} in {errors}",
        )


class FenceHeaderTests(LintTestCase):
    def wireframes(self, *headers: str) -> str:
        return "".join(f"```wireframe {header}\nok\n```\n\n" for header in headers)

    def test_id_is_optional_and_accepted(self) -> None:
        self.assert_clean(self.wireframes("2x1", "2x1 id=anatomy", "2x1 id=min-80"))

    def test_malformed_ids_are_rejected(self) -> None:
        for name in ("Anatomy", "a_b", "", "-a", "a-", "a--b", "a.b"):
            with self.subTest(name=name):
                self.assert_error(self.wireframes(f"2x1 id={name}"), 1, "invalid wireframe id")

    def test_duplicate_id_is_rejected_with_the_first_line(self) -> None:
        self.assert_error(
            self.wireframes("2x1 id=a", "2x1 id=a"),
            5,
            "duplicate wireframe id `a` (first used at line 1)",
        )

    def test_nothing_else_may_follow_the_size(self) -> None:
        self.assert_error(self.wireframes("2x1 anatomy"), 1, "unexpected `anatomy`")
        self.assert_error(self.wireframes("2x1 id=a mobile"), 1, "unexpected `mobile`")
        self.assert_error(self.wireframes("2x1 id=a id=b"), 1, "more than one `id=`")
        self.assert_error(self.wireframes("id=a"), 1, "needs a WxH size")

    def test_id_must_not_shadow_the_position_of_an_id_less_wireframe(self) -> None:
        self.assert_error(
            self.wireframes("2x1", "2x1 id=0"),
            5,
            "collides with the position-based identity of the id-less wireframe at line 1",
        )
        self.assert_clean(self.wireframes("2x1 id=0", "2x1 id=1"))

    def test_a_fence_nested_in_a_longer_fence_is_documentation(self) -> None:
        self.assert_clean("````text\n```wireframe not-a-size\nrow\n```\n````\n")

    def test_unterminated_fences_are_reported(self) -> None:
        self.assert_error("```wireframe 2x1\nok\n", 1, "unterminated wireframe fence")
        self.assert_error("text\n```text\nrow\n", 2, "unterminated code fence")


class StyledGridTests(LintTestCase):
    def test_a_styled_grid_matching_its_wireframe_is_clean(self) -> None:
        self.assert_clean(document())

    def test_a_four_backtick_wireframe_and_grid_are_linted_like_any_other(self) -> None:
        body = document().replace("```", "````")
        self.assert_clean(body)
        self.assert_error(body.replace("[ OK ]\n── style", "[ NO ]\n── style"), 7, "do not match")

    def test_chars_that_do_not_match_the_wireframe_are_rejected(self) -> None:
        self.assert_error(
            document(chars=["[ NO ]"]), 7, "chars do not match the preceding wireframe at line 1"
        )
        self.assert_error(
            document(chars=["[ OK ]", "extra"]), 7, "2 chars rows but the wireframe has 1"
        )

    def test_trailing_spaces_in_chars_are_ignored(self) -> None:
        self.assert_clean(document(chars=["[ OK ]  "]))

    def test_a_grid_belongs_to_the_nearest_preceding_wireframe(self) -> None:
        second = ["```wireframe 6x1", "[ NO ]", "```"]
        body = "\n".join(WIREFRAME) + "\n\n" + document(wireframe=second, chars=["[ NO ]"])
        self.assert_clean(body)
        self.assert_error(body.replace("[ NO ]\n── style", "[ OK ]\n── style"), 11, "at line 5")

    def test_a_grid_without_a_wireframe_needs_standalone(self) -> None:
        body = document(wireframe=[]).removeprefix("\n")
        self.assert_error(body, 1, "no preceding wireframe fence")
        self.assert_clean(body.replace("```text", "```text standalone"))

    def test_standalone_grids_skip_the_matching_rule_but_are_still_linted(self) -> None:
        body = document(header="text standalone", chars=["something else"], style=["A"])
        self.assert_clean(body)
        self.assert_error(body.replace("fg=accent bold", "fg=bogus"), 11, "unknown role `bogus`")

    def test_standalone_style_rows_are_not_limited_to_a_wireframe_width(self) -> None:
        self.assert_clean(document(header="text standalone", style=[".AAAAAAAAAAAA"]))

    def test_only_standalone_may_follow_text(self) -> None:
        self.assert_error(
            document(header="text alone"), 5, "the only header word is `standalone`"
        )

    def test_standalone_is_rejected_on_a_plain_text_fence(self) -> None:
        self.assert_error("```text standalone\njust text\n```\n", 1, "`standalone` applies only")

    def test_sections_must_be_chars_style_legend_in_order(self) -> None:
        self.assert_error(
            document(style=[".AAAA.", "── legend ──", "A  bold"]),
            6,
            "once each and in that order",
        )
        self.assert_error(
            document().replace("── style ──", "── attributes ──"),
            8,
            "unknown section `── attributes ──`",
        )

    def test_stray_section_headers_are_reported(self) -> None:
        self.assert_error("```text\n── style ──\nAAA\n```\n", 1, "outside a styled grid")
        self.assert_error("```\n── chars ──\nrow\n```\n", 1, "must be a `text` fence")

    def test_a_fence_that_documents_a_grid_is_not_linted_as_one(self) -> None:
        self.assert_clean("````text\n" + document() + "````\n")

    def test_a_short_style_row_and_missing_rows_are_the_default_style(self) -> None:
        self.assert_clean(document(style=[".AA"]))
        self.assert_clean(document(style=[""], legend=[".  default"]))
        self.assert_clean(document(style=[], legend=[".  default"]))

    def test_style_rows_may_run_past_the_trimmed_chars_up_to_the_wireframe_width(self) -> None:
        trimmed = ["```wireframe 6x1", "[ OK", "```"]
        self.assert_clean(document(wireframe=trimmed, chars=["[ OK"], style=["AAAAAA"]))
        self.assert_clean(document(style=[".AAAAA"]))
        self.assert_error(
            document(style=[".AAAAAA"]), 9, "7 cells wide; the wireframe is 6 wide"
        )

    def test_there_are_no_more_style_rows_than_chars_rows(self) -> None:
        self.assert_error(
            document(style=[".AAAA.", "AAAAAA"]), 10, "2 style rows but only 1 chars rows"
        )

    def test_style_rows_hold_no_whitespace(self) -> None:
        self.assert_error(document(style=[".AA  A"]), 9, "whitespace at column c3")

    def test_a_style_letter_missing_from_the_legend_is_rejected(self) -> None:
        self.assert_error(document(style=[".AABB."]), 9, "style letter `B` is not defined")

    def test_a_legend_letter_no_style_row_uses_is_rejected(self) -> None:
        self.assert_error(
            document(legend=["A  fg=accent bold", "B  fg=error"]),
            12,
            "legend letter `B` is not used",
        )

    def test_the_default_entry_is_optional_and_may_go_unused(self) -> None:
        self.assert_clean(document(style=["AAAAAA"]))
        self.assert_clean(document(legend=[".  default", "A  fg=accent bold"]))
        self.assert_clean(document(legend=[".  default -- terminal colours", "A  bold"]))

    def test_default_is_only_for_the_dot_entry(self) -> None:
        self.assert_error(
            document(legend=[".  fg=accent", "A  bold"]), 11, "its entry is `.  default`"
        )
        self.assert_error(
            document(legend=["A  default"]), 11, "`default` is only for the `.` entry"
        )

    def test_legend_lines_are_one_letter_two_spaces_and_a_spec(self) -> None:
        for line in ("A fg=accent", "A   fg=accent", "AB  fg=accent", "A  ", "A"):
            with self.subTest(line=line):
                self.assert_error(document(legend=[line]), 11, "must be `L  SPEC`")
        self.assert_error(
            document(legend=["A  fg=accent", "", "B  bold"], style=[".AB..."]),
            12,
            "blank line in the legend",
        )
        self.assert_error(
            document(legend=["A  fg=accent", "A  bold"]),
            12,
            "legend letter `A` is defined twice (first at line 11)",
        )
        self.assert_error(
            document(legend=["日  fg=accent"], style=["日"]), 11, "one display cell wide"
        )

    def test_specs_take_fg_bg_and_attributes(self) -> None:
        for spec in (
            "fg=accent bg=surface bold underline",
            "bg=selection.fill",
            "fg=contrast bg=accent bold",
            "fg=faint(accent) bg=faint(secondary) dim italic reverse strikethrough",
            "fg=syntax.plain",
        ):
            with self.subTest(spec=spec):
                self.assert_clean(document(legend=[f"A  {spec}"]))

    def test_specs_take_nothing_else(self) -> None:
        for spec, fragment in (
            ("fg=accent fg=error", "`fg=` appears twice"),
            ("bg=surface bg=hover", "`bg=` appears twice"),
            ("bolder", "unknown token `bolder`"),
            ("accent", "unknown token `accent`"),
            ("fill=accent", "unknown token `fill=accent`"),
            ("tinted", "unknown token `tinted`"),
        ):
            with self.subTest(spec=spec):
                self.assert_error(document(legend=[f"A  {spec}"]), 11, fragment)

    def test_unknown_roles_are_rejected(self) -> None:
        for value in (
            "bogus",
            "muted",
            "semantic.primary",
            "contrast*",
            "faint(bogus)",
            "faint()",
            "solid(accent)",
            "faint(solid(accent))",
        ):
            with self.subTest(value=value):
                self.assert_error(
                    document(legend=[f"A  fg={value}"]), 11, f"unknown role `{value}`"
                )
        self.assert_error(document(legend=["A  fg=solid(accent)"]), 11, "fg=contrast bg=R bold")

    def test_prose_without_a_double_dash_is_rejected(self) -> None:
        for prose in (
            "fg=focus, bold",
            "fg=focus: cursor and active-chip caps",
            "fg=accent (pill caps)",
            "disabled full Style",
            "syntax.plain",
        ):
            with self.subTest(prose=prose):
                self.assert_error(document(legend=[f"A  {prose}"]), 11, "unknown")

    def test_a_description_after_a_double_dash_is_free_text(self) -> None:
        for spec in (
            "fg=focus bold -- cursor and active-chip caps",
            "fg=accent -- (pill caps), fg=focus: not a token -- still prose",
            "fg=accent --  two spaces",
        ):
            with self.subTest(spec=spec):
                self.assert_clean(document(legend=[f"A  {spec}"]))

    def test_an_empty_description_or_spec_is_rejected(self) -> None:
        self.assert_error(document(legend=["A  fg=accent --"]), 11, "empty description after `--`")
        self.assert_error(document(legend=["A  -- only prose"]), 11, "no style before `--`")

    def test_a_double_dash_inside_a_token_is_not_a_description(self) -> None:
        self.assert_error(
            document(legend=["A  fg=accent--bold"]), 11, "unknown role `accent--bold`"
        )

    def test_tabs_in_a_grid_are_reported(self) -> None:
        self.assert_error(document(chars=["[\tOK ]"]), 7, "tab character in chars row r0")

    def test_the_cli_reports_doc_and_line_and_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "doc.md"
            path.write_text(document(legend=["A  fg=bogus"]), encoding="utf-8")
            stdout, stderr = io.StringIO(), io.StringIO()
            with contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
                status = checker.main([str(path)])
        self.assertEqual(status, 1)
        self.assertIn(f"{path}:11: styled grid: legend `A`: unknown role `bogus`", stderr.getvalue())
        self.assertIn("1 problem(s) in 1 file(s)", stderr.getvalue())


class RoleTableTests(unittest.TestCase):
    def test_roles_come_from_the_tokens_role_tables(self) -> None:
        roles = checker.load_roles()
        for role in (
            "primary",
            "secondary",
            "border",
            "disabled",
            "focus",
            "accent",
            "info",
            "success",
            "warning",
            "error",
            "destructive",
            "surface",
            "hover",
            "selection.fill",
            "selection.inactive",
            "disabled.fill",
            "disabled.label",
            "contrast",
            "syntax.plain",
            "syntax.keyword",
            "syntax.comment",
        ):
            self.assertIn(role, roles)

    def test_composite_styles_and_glyph_tokens_are_not_roles(self) -> None:
        roles = checker.load_roles()
        for name in ("solid(R)", "faint(R)", "selection.bar", "selection.member", "ink2"):
            self.assertNotIn(name, roles)

    def test_faint_takes_a_role(self) -> None:
        roles = checker.load_roles()
        self.assertTrue(checker.is_role("faint(accent)", roles))
        self.assertTrue(checker.is_role("faint(disabled.fill)", roles))
        self.assertFalse(checker.is_role("faint(R)", roles))
        self.assertFalse(checker.is_role("faint(faint(accent))", roles))

    def test_a_tokens_file_without_roles_fails_loudly(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            tokens = Path(temporary) / "tokens.md"
            tokens.write_text("# Tokens\n\n## Roles\n\nNo tables.\n", encoding="utf-8")
            with self.assertRaises(checker.RoleTableError):
                checker.load_roles(tokens)
            with self.assertRaises(checker.RoleTableError):
                checker.load_roles(Path(temporary) / "missing.md")

    def test_the_gallery_resolves_exactly_these_roles(self) -> None:
        path = Path(__file__).resolve().parent.parent / "DevTools" / "gallery" / "colors.py"
        spec = importlib.util.spec_from_file_location("gallery_colors", path)
        assert spec and spec.loader
        colors = importlib.util.module_from_spec(spec)
        sys.modules[spec.name] = colors  # dataclasses look their module up here
        try:
            spec.loader.exec_module(colors)
        finally:
            del sys.modules[spec.name]
        self.assertEqual(colors.ROLES, checker.load_roles())


if __name__ == "__main__":
    unittest.main()
