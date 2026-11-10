#!/usr/bin/env python3
"""Fail if the README "What is proven" block is not generated text.

The table and the summary line are built from STATUS. Nothing in
those rows is typed by hand. The last line is built from
proof/ask_rule.out, because that proof is not an item in STATUS.

  python3 tools/check-readme-status.py
  python3 tools/check-readme-status.py --write
  python3 tools/check-readme-status.py --self-test
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

BEGIN = "<!-- status-table: begin -->"
END = "<!-- status-table: end -->"

ROOT = Path(__file__).resolve().parent.parent
README = ROOT / "README.md"
STATUS = ROOT / "STATUS"
ASK = ROOT / "proof" / "ask_rule.out"

ITEM_RE = re.compile(r"item (\d+) (proved|tested|unchecked) (.*)")
SUMMARY_RE = re.compile(
    r"summary proved (\d+) of (\d+), tested (\d+), unchecked (\d+)"
)
UNIT_RE = re.compile(r"unit (\S+) \d+/\d+ checks (\d+)")
RULE_RE = re.compile(r"proved for the ([^;]+)")
WHY_RE = re.compile(r"not proved: (.*)$")
PROVED_RE = re.compile(r"and proved \((\d+) checks\)")


def integers(line: str) -> list[int]:
    return [int(token) for token in re.findall(r"\d+", line)]


def ask_rule_checks(text: str) -> tuple[int, int]:
    """Return (checks on ai_amplifier-ask_rule, summary unproved)."""
    checks = 0
    in_unit = False
    unproved: int | None = None
    for raw in text.splitlines():
        line = raw.strip()
        if line.startswith("in unit "):
            in_unit = line.startswith("in unit ai_amplifier-ask_rule,")
            continue
        if in_unit:
            found = PROVED_RE.search(line)
            if found:
                checks += int(found.group(1))
        if line.startswith("Total"):
            numbers = integers(line)
            if len(numbers) >= 4:
                unproved = numbers[5] if len(numbers) >= 6 else 0
    if unproved is None:
        sys.exit("proof/ask_rule.out has no summary total")
    if checks <= 0:
        sys.exit("proof/ask_rule.out has no checks on ai_amplifier-ask_rule")
    return checks, unproved


def cell(text: str) -> str:
    if "|" in text or "\n" in text:
        sys.exit(f"STATUS text cannot sit in a table cell: {text!r}")
    return text


def parse_status(text: str) -> tuple[list[tuple[str, str, str, str, str]], str]:
    rows: list[tuple[str, str, str, str, str]] = []
    summary = ""
    for raw in text.splitlines():
        if raw.startswith("summary "):
            if summary:
                sys.exit("STATUS has two summary lines")
            summary = raw
            continue
        match = ITEM_RE.fullmatch(raw)
        if match is None:
            if raw.strip():
                sys.exit(f"STATUS line is not an item or the summary: {raw}")
            continue
        number = str(int(match.group(1)))
        label = match.group(2)
        evidence = match.group(3)
        rule = ""
        checks = ""
        why = ""
        if label == "proved":
            unit = UNIT_RE.search(evidence)
            named = RULE_RE.search(evidence)
            if unit is None:
                sys.exit(f"item {number} is proved and names no unit checks")
            checks = unit.group(2)
            rule = named.group(1).strip() if named else unit.group(1)
            if f"checks {checks}" not in evidence or rule not in evidence:
                sys.exit(f"item {number} row is not taken from STATUS")
        else:
            why_match = WHY_RE.search(evidence)
            if why_match is None:
                sys.exit(f"item {number} is {label} and says no reason")
            why = why_match.group(1).strip()
            if why not in evidence:
                sys.exit(f"item {number} reason is not taken from STATUS")
        rows.append((number, label, cell(rule), cell(checks), cell(why)))
    if not summary:
        sys.exit("STATUS has no summary line")
    found = SUMMARY_RE.fullmatch(summary)
    if found is None:
        sys.exit(f"STATUS summary is not the expected shape: {summary}")
    proved = sum(1 for row in rows if row[1] == "proved")
    tested = sum(1 for row in rows if row[1] == "tested")
    unchecked = sum(1 for row in rows if row[1] == "unchecked")
    got = (proved, len(rows), tested, unchecked)
    want = tuple(int(part) for part in found.groups())
    if got != want:
        sys.exit(
            "STATUS summary does not match its rows: "
            f"{summary} counted proved {proved} of {len(rows)}, "
            f"tested {tested}, unchecked {unchecked}"
        )
    return rows, summary


def render_block(rows: list[tuple[str, str, str, str, str]], summary: str, ask: str) -> str:
    checks, unproved = ask_rule_checks(ask)
    lines = [
        "| Item | Label | Rule proved | Checks | Why it stays tested |",
        "|---:|---|---|---:|---|",
    ]
    for number, label, rule, count, why in rows:
        lines.append(f"| {number} | {label} | {rule} | {count} | {why} |")
    lines.append("")
    lines.append(summary)
    lines.append("")
    lines.append(
        "AI_Amplifier.Ask_Rule is not an item in STATUS. "
        f"proof/ask_rule.out has {checks} checks on ai_amplifier-ask_rule "
        f"and unproved {unproved}."
    )
    return "\n".join(lines) + "\n"


def extract(readme: str) -> str:
    begin = readme.find(BEGIN)
    end = readme.find(END)
    if begin < 0 or end < 0 or end < begin:
        sys.exit("README.md is missing the status-table markers")
    if readme.find(BEGIN, begin + 1) >= 0 or readme.find(END, end + 1) >= 0:
        sys.exit("README.md has more than one status-table block")
    block = readme[begin + len(BEGIN) : end]
    if not block.startswith("\n") or not block.endswith("\n"):
        sys.exit("status-table markers must each sit on their own line")
    return block[1:]


def expected() -> str:
    rows, summary = parse_status(STATUS.read_text(encoding="utf-8"))
    return render_block(rows, summary, ASK.read_text(encoding="utf-8", errors="replace"))


def compare(readme: str, block: str) -> str | None:
    try:
        got = extract(readme)
    except SystemExit as err:
        return str(err)
    if got == block:
        return None
    return "README status table does not match STATUS and proof/ask_rule.out"


def write_block(block: str) -> None:
    readme = README.read_text(encoding="utf-8")
    begin = readme.find(BEGIN)
    end = readme.find(END)
    if begin < 0 or end < 0 or end < begin:
        sys.exit("README.md is missing the status-table markers")
    updated = readme[: begin + len(BEGIN)] + "\n" + block + readme[end:]
    if updated == readme:
        print("status table already matches")
        return
    README.write_text(updated, encoding="utf-8")
    print("wrote the status table into README.md")


def splice(readme: str, got: str, replacement: str) -> str:
    needle = BEGIN + "\n" + got + END
    updated = readme.replace(needle, BEGIN + "\n" + replacement + END, 1)
    if updated == readme:
        sys.exit("self-test could not splice the status table")
    return updated


def self_test(block: str) -> None:
    readme = README.read_text(encoding="utf-8")
    mismatch = compare(readme, block)
    if mismatch:
        sys.exit(mismatch)
    got = extract(readme)
    changed_summary = got.replace("unchecked 0", "unchecked 1", 1)
    if changed_summary == got:
        sys.exit("self-test could not find unchecked 0 in the table")
    if compare(splice(readme, got, changed_summary), block) is None:
        sys.exit("self-test: a changed summary still matched")
    changed_row = got.replace(" | proved |", " | unchecked |", 1)
    if changed_row == got:
        sys.exit("self-test could not find a proved row")
    if compare(splice(readme, got, changed_row), block) is None:
        sys.exit("self-test: a changed row still matched")
    print("readme status self-test ok")


def main() -> int:
    block = expected()
    if "--write" in sys.argv:
        write_block(block)
    mismatch = compare(README.read_text(encoding="utf-8"), block)
    if mismatch:
        print(mismatch, file=sys.stderr)
        print("--- expected ---", file=sys.stderr)
        print(block, end="", file=sys.stderr)
        return 1
    print("readme status table ok")
    if "--self-test" in sys.argv:
        self_test(block)
    return 0


if __name__ == "__main__":
    sys.exit(main())
