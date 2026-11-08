#!/usr/bin/env python3
"""Fail if a built item has no row in STATUS.

A built item is an item_NN.adb main in ada_ai_amplifier.gpr.
STATUS must contain a line "item NN " for each of those numbers.
The summary line is not an item row.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


ITEM_MAIN = re.compile(r"item_(\d+)\.adb")
STATUS_ROW = re.compile(r"^item (\d+) ", re.MULTILINE)


def built_items(gpr_text: str) -> list[int]:
    found = {int(number) for number in ITEM_MAIN.findall(gpr_text)}
    return sorted(found)


def status_items(status_text: str) -> set[int]:
    return {int(number) for number in STATUS_ROW.findall(status_text)}


def missing_rows(gpr_text: str, status_text: str) -> list[int]:
    present = status_items(status_text)
    return [number for number in built_items(gpr_text) if number not in present]


def check(gpr_text: str, status_text: str) -> list[str]:
    built = built_items(gpr_text)
    if not built:
        return ["the project file names no item_NN.adb main"]
    gone = missing_rows(gpr_text, status_text)
    if not gone:
        return []
    names = ", ".join(f"item {number:02d}" for number in gone)
    return [f"built item missing from STATUS: {names}"]


def self_test(root: Path) -> int:
    gpr = (root / "ada_ai_amplifier.gpr").read_text(encoding="utf-8")
    status = (root / "STATUS").read_text(encoding="utf-8")
    errors = check(gpr, status)
    if errors:
        for message in errors:
            print(message, file=sys.stderr)
        print("real tree failed the built-item check", file=sys.stderr)
        return 1
    dropped = "\n".join(
        line for line in status.splitlines(keepends=True)
        if not line.startswith("item 18 ")
    )
    if not missing_rows(gpr, dropped):
        print("dropping item 18 still passed", file=sys.stderr)
        return 1
    extra = gpr.replace(
        '"item_19.adb");',
        '"item_19.adb",\n            "item_20.adb");',
        1,
    )
    if extra == gpr or not missing_rows(extra, status):
        print("an extra built item still passed", file=sys.stderr)
        return 1
    print(
        f"built status ok ({len(built_items(gpr))} items)"
    )
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=None)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    root = args.root
    if root is None:
        root = Path(__file__).resolve().parent.parent
    root = root.resolve()
    if args.self_test:
        return self_test(root)
    errors = check(
        (root / "ada_ai_amplifier.gpr").read_text(encoding="utf-8"),
        (root / "STATUS").read_text(encoding="utf-8"),
    )
    if errors:
        for message in errors:
            print(message, file=sys.stderr)
        return 1
    count = len(built_items((root / "ada_ai_amplifier.gpr").read_text(encoding="utf-8")))
    print(f"built status ok ({count} items)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
