#!/usr/bin/env python3
"""Fingerprint specs/LOCK and reject Assume, Annotate, and a skipped test.

The scan reads Ada sources under src/ and specs/. A pull_request event
also requires that an updated specs/LOCK is named in the pull request
description. Set CHECK_LOCKED_EVENT, CHECK_LOCKED_BASE, and
CHECK_LOCKED_BODY for that check.
"""

from __future__ import annotations

import argparse
import hashlib
import os
import re
import subprocess
import sys
from pathlib import Path

ASSUME = re.compile(r"\bpragma\s+Assume\b", re.IGNORECASE)
ANNOTATE = re.compile(r"\bpragma\s+Annotate\b", re.IGNORECASE)
SUPPRESS = re.compile(
    r"\bpragma\s+Suppress\s*\(\s*Assertions?\b", re.IGNORECASE
)
SKIP_COMMENT = re.compile(
    r"^\s*--.*\b(?:skipped\s+test|disabled\s+test|test\s+skipped|"
    r"test\s+disabled|skip\s+test|disable\s+test)\b",
    re.IGNORECASE | re.MULTILINE,
)
SORRY_COMMENT = re.compile(r"^\s*--\s*sorry\b", re.IGNORECASE | re.MULTILINE)
SKIP_ID = re.compile(
    r"\b(?:Skip_Test|Test_Skipped|Disabled_Test|Test_Disabled|"
    r"Not_Applicable)\b"
)


def fail(errors: list[str], message: str) -> None:
    errors.append(message)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load_lock(path: Path, errors: list[str]) -> dict[str, str]:
    if not path.is_file():
        fail(errors, f"missing {path}")
        return {}
    found: dict[str, str] = {}
    for number, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.split()
        if len(parts) != 2 or not re.fullmatch(r"[0-9a-f]{64}", parts[1]):
            fail(errors, f"{path}:{number}: expected 'name sha256'")
            continue
        found[parts[0]] = parts[1]
    return found


_LOCK_MATCH: Path | None = None


def compiler_repo() -> Path:
    return Path(__file__).resolve().parent.parent


def lock_match_exe() -> Path:
    """Build the native compare once. The throwaway --root is not this repo."""
    global _LOCK_MATCH
    if _LOCK_MATCH is not None:
        return _LOCK_MATCH
    home = compiler_repo()
    binary = home / "bin" / "lock_match"
    ran = subprocess.run(
        ["gprbuild", "-P", str(home / "lock_match.gpr"), "-p"],
        cwd=home,
        capture_output=True,
        text=True,
    )
    if ran.returncode != 0 or not binary.is_file():
        raise SystemExit(
            "could not build lock_match\n" + ran.stdout + ran.stderr
        )
    _LOCK_MATCH = binary
    return binary


def digits_match(left: str, right: str) -> bool:
    if len(left) != 64 or len(right) != 64:
        return False
    ran = subprocess.run(
        [str(lock_match_exe()), left, right],
        capture_output=True,
        text=True,
    )
    if ran.returncode == 0:
        return True
    if ran.returncode == 1:
        return False
    raise SystemExit("lock_match failed\n" + ran.stdout + ran.stderr)


def set_holds(flags: list[bool]) -> bool:
    if not flags or len(flags) > 19:
        return False
    ran = subprocess.run(
        [str(lock_match_exe()), "--all", *("1" if flag else "0" for flag in flags)],
        capture_output=True,
        text=True,
    )
    if ran.returncode == 0:
        return True
    if ran.returncode == 1:
        return False
    raise SystemExit("lock_match --all failed\n" + ran.stdout + ran.stderr)


def check_hashes(root: Path, errors: list[str]) -> None:
    spec_dir = root / "specs"
    lock_path = spec_dir / "LOCK"
    locked = load_lock(lock_path, errors)
    files = sorted(p.name for p in spec_dir.glob("item_*.adb"))
    if not files:
        fail(errors, "specs/ has no item_*.adb")
    names = set(locked)
    if names != set(files):
        missing = sorted(set(files) - names)
        extra = sorted(names - set(files))
        if missing:
            fail(errors, "specs/LOCK does not name " + ", ".join(missing))
        if extra:
            fail(errors, "specs/LOCK names missing " + ", ".join(extra))
    flags: list[bool] = []
    for name in files:
        digest = sha256(spec_dir / name)
        recorded = locked.get(name)
        if recorded is None:
            continue
        same = digits_match(recorded, digest)
        flags.append(same)
        if not same:
            fail(
                errors,
                f"{name} changed without specs/LOCK updated in the same change "
                f"(file {digest}, LOCK {recorded})",
            )
    if flags and not set_holds(flags):
        fail(errors, "the lock-compare rule rejected the set")


def check_source(root: Path, errors: list[str]) -> None:
    roots = [root / "src", root / "specs"]
    for base in roots:
        if not base.is_dir():
            continue
        for path in sorted(base.rglob("*")):
            if path.suffix not in {".ads", ".adb"}:
                continue
            text = path.read_text(encoding="utf-8")
            rel = path.relative_to(root)
            for label, pattern in (
                ("pragma Assume", ASSUME),
                ("pragma Annotate", ANNOTATE),
                ("pragma Suppress of assertions", SUPPRESS),
                ("skipped or disabled test", SKIP_COMMENT),
                ("sorry comment", SORRY_COMMENT),
                ("skipped or disabled test", SKIP_ID),
            ):
                match = pattern.search(text)
                if match is None:
                    continue
                line = text.count("\n", 0, match.start()) + 1
                fail(errors, f"{rel}:{line}: {label} is not allowed")


def git_names(root: Path, base: str) -> list[str]:
    probe = subprocess.run(
        ["git", "cat-file", "-e", f"{base}^{{commit}}"],
        cwd=root,
        capture_output=True,
        text=True,
    )
    if probe.returncode != 0:
        fetched = subprocess.run(
            ["git", "fetch", "--depth=1", "origin", base],
            cwd=root,
            capture_output=True,
            text=True,
        )
        if fetched.returncode != 0:
            raise SystemExit(
                "cannot see pull request base "
                + base
                + "\n"
                + fetched.stderr
            )
    diff = subprocess.run(
        ["git", "diff", "--name-only", base, "HEAD"],
        cwd=root,
        capture_output=True,
        text=True,
        check=True,
    )
    return [line for line in diff.stdout.splitlines() if line]


def check_pull_request(root: Path, errors: list[str]) -> None:
    event = os.environ.get("CHECK_LOCKED_EVENT", "")
    if event != "pull_request":
        return
    base = os.environ.get("CHECK_LOCKED_BASE", "")
    if not base:
        fail(errors, "pull_request event did not provide CHECK_LOCKED_BASE")
        return
    try:
        names = git_names(root, base)
    except subprocess.CalledProcessError as exc:
        fail(errors, "git diff failed: " + (exc.stderr or exc.stdout or str(exc)))
        return
    specs_changed = [name for name in names if name.startswith("specs/item_")]
    lock_changed = "specs/LOCK" in names
    if specs_changed and not lock_changed:
        fail(
            errors,
            "a spec changed without specs/LOCK updated in the same pull request: "
            + ", ".join(specs_changed),
        )
    if lock_changed:
        body = os.environ.get("CHECK_LOCKED_BODY") or ""
        if "specs/LOCK" not in body:
            fail(
                errors,
                "specs/LOCK was updated and the pull request description "
                "does not name specs/LOCK",
            )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=None)
    args = parser.parse_args()
    root = args.root
    if root is None:
        root = Path(__file__).resolve().parent.parent
    root = root.resolve()
    errors: list[str] = []
    check_hashes(root, errors)
    check_source(root, errors)
    check_pull_request(root, errors)
    if errors:
        for message in errors:
            print(message, file=sys.stderr)
        return 1
    print("locked ok")
    return 0


if __name__ == "__main__":
    sys.exit(main())
