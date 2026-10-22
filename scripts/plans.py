#!/usr/bin/env python3
"""Render docs/plans.md from plan frontmatter and report where the plans stand.

Each plan's frontmatter is the record: `stage` (active, proposed, planned, done,
cancelled), `order` (position in the plan sequence; the old plan number for migrated
plans), `description` (one line for the hub), `created`, and `completed` for done plans.
The hub groups plans as Active, Next (pending in order), Done (by completion date), and
Cancelled, and keeps a one-time table from each old plan number to its slug, so "plan 032"
in commit messages and older notes still resolves. Editing the hub by hand is pointless
because the quality gate compares it with this rendering.

Usage: plans.py            rewrite docs/plans.md
       plans.py --check    exit 1 when docs/plans.md is stale or frontmatter is invalid
       plans.py --status   print the plans as a table
"""

from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PLANS = ROOT / "docs" / "plans"
HUB = ROOT / "docs" / "plans.md"
PENDING = ("proposed", "planned")
STAGES = ("active", *PENDING, "done", "cancelled")
FRONTMATTER_RE = re.compile(r"\A---\n(.*?)\n---\n", re.DOTALL)
TITLE_RE = re.compile(r"^# (.+?)\s*$", re.MULTILINE)
DATE_RE = re.compile(r"\d{4}-\d{2}-\d{2}")

# Plans that existed before the docs workspace carried a number in their filename and were
# cited as "plan NNN". The number is their `order`; the hub keeps the table.
NUMBERED_PLANS_THROUGH = 35

HEADER = """---
type: hub
stage: living
---

# Plans

One plan per piece of work, in order. This page is rendered from each plan's frontmatter by `scripts/plans.py`; change `stage`, `order`, `description`, or `completed` in the plan and re-run it (`mise run quality:lint` fails while the page is stale). Read a plan's Progress list and `Next:` line before resuming it, and its Approach and Acceptance before starting it.
"""

NUMBERS_INTRO = """
## Plan numbers

Plans written before the docs workspace were numbered (`.agents/plans/NNN-slug.md`) and are cited by number in commit messages, research records, and older plans. The number is now the plan's `order`; this table maps each number to its page.
"""


@dataclass(frozen=True)
class Plan:
    path: Path
    title: str
    stage: str
    order: int
    description: str
    created: str
    completed: str

    @property
    def link(self) -> str:
        return f"[{self.title}](plans/{self.path.name})"


def parse_frontmatter(text: str) -> dict[str, str]:
    match = FRONTMATTER_RE.match(text)
    if not match:
        return {}
    fields: dict[str, str] = {}
    key = ""
    for line in match.group(1).splitlines():
        if line.startswith((" ", "\t")) and key:
            # A plain scalar folded over several indented lines.
            fields[key] = f"{fields[key]} {line.strip()}".strip()
            continue
        key, separator, value = line.partition(":")
        key = key.strip()
        if separator:
            fields[key] = value.strip()
    return {key: value.strip("'\"") for key, value in fields.items()}


def load_plans() -> tuple[list[Plan], list[str]]:
    plans: list[Plan] = []
    errors: list[str] = []
    for path in sorted(PLANS.glob("*.md")):
        text = path.read_text(encoding="utf-8")
        fields = parse_frontmatter(text)
        title = TITLE_RE.search(text)
        name = path.relative_to(ROOT)
        if fields.get("type") != "plan" or not title:
            errors.append(f"{name}: needs `type: plan` frontmatter and a level-one title")
            continue
        stage = fields.get("stage", "")
        if stage not in STAGES:
            errors.append(f"{name}: stage must be one of {', '.join(STAGES)}")
        order = fields.get("order", "")
        if not order.isdigit():
            errors.append(f"{name}: order must be a positive integer")
        description = fields.get("description", "")
        if not description:
            errors.append(f"{name}: description (one line for the hub) is required")
        created = fields.get("created", "")
        completed = fields.get("completed", "")
        if not DATE_RE.fullmatch(created):
            errors.append(f"{name}: created must be an ISO date")
        if stage == "done" and not DATE_RE.fullmatch(completed):
            errors.append(f"{name}: a done plan needs an ISO `completed` date")
        if stage != "done" and completed:
            errors.append(f"{name}: only done plans carry `completed`")
        plans.append(
            Plan(
                path,
                title.group(1),
                stage,
                int(order) if order.isdigit() else 0,
                description,
                created,
                completed,
            )
        )
    seen: dict[int, Plan] = {}
    for plan in plans:
        if plan.order in seen:
            errors.append(
                f"{plan.path.name} and {seen[plan.order].path.name} share order {plan.order}"
            )
        seen[plan.order] = plan
    return sorted(plans, key=lambda plan: plan.order), errors


def render(plans: list[Plan]) -> str:
    sections: list[str] = [HEADER]

    def section(heading: str, rows: list[str]) -> None:
        if rows:
            sections.append(f"\n## {heading}\n\n" + "\n".join(rows) + "\n")

    active = [plan for plan in plans if plan.stage == "active"]
    pending = [plan for plan in plans if plan.stage in PENDING]
    done = sorted(
        (plan for plan in plans if plan.stage == "done"),
        key=lambda plan: (plan.completed, plan.order),
    )
    cancelled = [plan for plan in plans if plan.stage == "cancelled"]

    section("Active", [f"- {plan.link}: {plan.description}" for plan in active])
    section(
        "Next",
        [f"{index}. {plan.link}: {plan.description}" for index, plan in enumerate(pending, 1)],
    )
    section("Done", [f"- {plan.completed} {plan.link}: {plan.description}" for plan in done])
    section("Cancelled", [f"- {plan.link}: {plan.description}" for plan in cancelled])

    numbered = [plan for plan in plans if plan.order <= NUMBERED_PLANS_THROUGH]
    if numbered:
        sections.append(NUMBERS_INTRO)
        sections.append("\n| Number | Plan | Stage |\n| --- | --- | --- |\n")
        sections.append(
            "\n".join(f"| {plan.order:03d} | {plan.link} | {plan.stage} |" for plan in numbered)
            + "\n"
        )
    return "".join(sections)


def status(plans: list[Plan]) -> str:
    width = max(len(plan.title) for plan in plans)
    lines = [f"{'#':>3}  {'plan':<{width}}  {'stage':<9}  when"]
    for plan in plans:
        when = plan.completed or plan.created
        lines.append(f"{plan.order:>3}  {plan.title:<{width}}  {plan.stage:<9}  {when}")
    counts = {stage: sum(plan.stage == stage for plan in plans) for stage in STAGES}
    summary = ", ".join(f"{count} {stage}" for stage, count in counts.items() if count)
    return "\n".join(lines) + f"\n{summary}"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--check", action="store_true", help="fail when the hub is stale")
    mode.add_argument("--status", action="store_true", help="print the plans table")
    args = parser.parse_args(argv)

    plans, errors = load_plans()
    if errors:
        print("plans: invalid frontmatter:", file=sys.stderr)
        for error in errors:
            print(f"  {error}", file=sys.stderr)
        return 1

    if args.status:
        print(status(plans))
        return 0
    rendered = render(plans)
    current = HUB.read_text(encoding="utf-8") if HUB.is_file() else ""
    if args.check:
        if current != rendered:
            print(
                "plans: docs/plans.md is stale; run `scripts/plans.py` to rewrite it",
                file=sys.stderr,
            )
            return 1
        print("plans: docs/plans.md matches plan frontmatter")
        return 0
    if current != rendered:
        HUB.write_text(rendered, encoding="utf-8")
        print("plans: rewrote docs/plans.md")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
