"""Unit tests for the SwiftPM view-layer package-boundary checker."""

from __future__ import annotations

import importlib.util
import io
import unittest
from pathlib import Path


CHECKER_PATH = Path(__file__).with_name("check-package-boundaries.py")
SPEC = importlib.util.spec_from_file_location("check_package_boundaries", CHECKER_PATH)
assert SPEC and SPEC.loader
checker = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(checker)


class PackageBoundaryTests(unittest.TestCase):
    def package(self, dependencies: dict[str, list[str]]) -> dict[str, object]:
        return {
            "targets": [
                {"name": name, "target_dependencies": target_dependencies}
                for name, target_dependencies in dependencies.items()
            ]
        }

    def valid_package(self) -> dict[str, object]:
        return self.package(
            {
                "TesseraCore": [
                    "TesseraTerminalBuffer",
                    "TesseraTerminalCore",
                    "TesseraTerminalInput",
                ],
                "TesseraLayout": ["TesseraCore"],
                "TesseraWidgets": ["TesseraCore", "TesseraLayout"],
                "Tessera": [
                    "TesseraCore",
                    "TesseraLayout",
                    "TesseraTerminal",
                    "TesseraWidgets",
                ],
            }
        )

    def test_accepts_the_intended_acyclic_view_graph(self) -> None:
        self.assertEqual(checker.check_package_boundaries(self.valid_package()), [])

    def test_reports_each_forbidden_direct_edge_in_order(self) -> None:
        package = self.valid_package()
        targets = package["targets"]
        assert isinstance(targets, list)
        targets[0]["target_dependencies"].append("TesseraTerminalIO")
        targets[2]["target_dependencies"].append("TesseraTerminalRendering")

        self.assertEqual(
            checker.check_package_boundaries(package),
            [
                "TesseraCore -> TesseraTerminalIO",
                "TesseraWidgets -> TesseraTerminalRendering",
            ],
        )

    def test_reports_forbidden_product_dependencies(self) -> None:
        package = self.valid_package()
        targets = package["targets"]
        assert isinstance(targets, list)
        targets[0]["product_dependencies"] = ["UnexpectedProduct"]

        self.assertEqual(
            checker.check_package_boundaries(package),
            ["TesseraCore -> product UnexpectedProduct"],
        )

    def test_requires_all_view_layer_targets(self) -> None:
        package = self.valid_package()
        targets = package["targets"]
        assert isinstance(targets, list)
        del targets[1]

        self.assertEqual(
            checker.check_package_boundaries(package),
            ["Missing required view-layer target: TesseraLayout"],
        )

    def test_rejects_invalid_target_dependencies_shape(self) -> None:
        with self.assertRaisesRegex(ValueError, "non-array target_dependencies"):
            checker.check_package_boundaries(
                {"targets": [{"name": "TesseraCore", "target_dependencies": "bad"}]}
            )

    def test_rejects_invalid_product_dependencies_shape(self) -> None:
        with self.assertRaisesRegex(ValueError, "non-array product_dependencies"):
            checker.check_package_boundaries(
                {"targets": [{"name": "TesseraCore", "product_dependencies": "bad"}]}
            )

    def test_main_reports_invalid_json(self) -> None:
        stderr = io.StringIO()

        exit_code = checker.main(io.StringIO("not json"), stderr)

        self.assertEqual(exit_code, 2)
        self.assertIn("Invalid SwiftPM package description", stderr.getvalue())

    def test_main_reports_violations(self) -> None:
        stderr = io.StringIO()

        exit_code = checker.main(
            io.StringIO(
                '{"targets":[{"name":"TesseraCore",'
                '"target_dependencies":["TesseraTerminalIO"]}]}'
            ),
            stderr,
        )

        self.assertEqual(exit_code, 1)
        self.assertEqual(
            stderr.getvalue(),
            "Forbidden package dependency edges:\n"
            "TesseraCore -> TesseraTerminalIO\n"
            "Missing required view-layer target: TesseraLayout\n"
            "Missing required view-layer target: TesseraWidgets\n"
            "Missing required view-layer target: Tessera\n",
        )


if __name__ == "__main__":
    unittest.main()
