#!/usr/bin/env python3
"""Fail if a proved STATUS row has no clean gnatprove run of its own.

Each proved line must name proof/item_NN.out. That file has to exist,
its summary unproved count has to be 0, and the row's check count has
to be greater than 0.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path


def integers(line: str) -> list[int]:
    return [int(token) for token in re.findall(r"\d+", line)]


def summary_unproved(text: str) -> int | None:
    for raw in text.splitlines():
        line = raw.strip()
        if not line.startswith("Total"):
            continue
        numbers = integers(line)
        if len(numbers) < 4:
            continue
        if len(numbers) >= 6:
            return numbers[5]
        return 0
    return None


def main() -> int:
    root = Path(__file__).resolve().parent.parent
    status = (root / "STATUS").read_text(encoding="utf-8")
    errors: list[str] = []
    proved = 0
    for raw in status.splitlines():
        match = re.match(r"item (\d+) proved (.*)", raw)
        if match is None:
            continue
        proved += 1
        number = int(match.group(1))
        evidence = match.group(2)
        name = f"item_{number:02d}.out"
        path = root / "proof" / name
        if f"proof/{name}" not in evidence:
            errors.append(f"item {number:02d} does not name proof/{name}")
        if "unproved 0" not in evidence:
            errors.append(f"item {number:02d} does not say unproved 0")
        checks = re.findall(r"checks (\d+)", evidence)
        if not checks or any(int(count) <= 0 for count in checks):
            errors.append(f"item {number:02d} has no positive check count")
        if not path.is_file():
            errors.append(f"missing {path}")
            continue
        unproved = summary_unproved(path.read_text(encoding="utf-8", errors="replace"))
        if unproved is None:
            errors.append(f"{name} has no summary total")
        elif unproved != 0:
            errors.append(f"{name} summary unproved is {unproved}")
    if proved == 0:
        errors.append("STATUS has no proved item")
    if errors:
        for message in errors:
            print(message, file=sys.stderr)
        return 1
    print(f"proof runs ok ({proved} proved)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
