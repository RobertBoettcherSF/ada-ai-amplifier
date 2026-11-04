#!/usr/bin/env python3
"""Fail if a quoted file in docs/HOWTO.md differs from the file itself.

A marker `<!-- quote:tools/howto-steps.sh -->` immediately before a
```sh fence means that fence is the file. CI runs this so the guide
and the runner stay the same text.
"""
import pathlib
import re
import sys

root = pathlib.Path(__file__).resolve().parent.parent
guide = (root / "docs" / "HOWTO.md").read_text()
pattern = re.compile(
    r"<!-- quote:([^\s>]+) -->\n```sh\n(.*?)```",
    re.DOTALL,
)
found = pattern.findall(guide)
if not found:
    sys.exit("docs/HOWTO.md has no quoted files")
for name, body in found:
    path = root / name
    if not path.is_file():
        sys.exit(f"quoted path is not a file: {name}")
    disk = path.read_text()
    if not body.endswith("\n"):
        body += "\n"
    if body != disk:
        sys.exit(f"{name} differs from the fence in docs/HOWTO.md")
    print(f"quote ok {name}")
