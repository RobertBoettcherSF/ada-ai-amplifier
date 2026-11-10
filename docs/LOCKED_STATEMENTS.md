# Locked statements

Nineteen specs. Items 1 through 19. Each spec is a small
Ada program that calls this library and asserts numbers that
item's tests already check. CI builds those programs and runs
them. The page shows the source, the SHA-256, and whether this
build passed.

Visible stamp: **v0.23.0-ci-cache**

Live page: https://robertboettchersf.github.io/ada-ai-amplifier/?v=0.23.0-ci-cache

## The idea, and the licence

[formal-math](https://github.com/anthropics/formal-math) keeps a
mathematical statement apart from the proof of that statement, so
a proof cannot quietly rewrite what it claims to show. The
repository is Apache-2.0. That licence would allow a copy if the
notice were kept. This tree does not contain one. No file, no
statement, and no sentence from that repository is here. The link
is the credit for the split. The specs in `specs/` are the
statements. The library is what they run against. A change to a
statement is a change to a file whose fingerprint is recorded.

## What the fingerprint does

`specs/LOCK` stores the SHA-256 of `item_01.adb` through
`item_19.adb`, including `item_16.adb`. CI hashes the files again. If a spec's bytes are
not the bytes in `specs/LOCK`, the job fails. That is the silent
edit: a spec that moved, and a lock file that did not.

If `specs/LOCK` changes in a pull request, the description of
that pull request has to contain the text `specs/LOCK`. The
change is then written down where a reviewer can see it. The
check runs on `pull_request` events, where the description is
available.

A fingerprint stops a silent edit. It cannot tell whether a spec
is the right one. A wrong statement, hashed and written into
`specs/LOCK` in the open, still matches. The hash does not know
what the item was supposed to show. It only knows whether the
file still says what the lock recorded.

## What CI also rejects

The same step reads every `.ads` and `.adb` file under `src/` and
`specs/`. It fails if it finds an Assume pragma, an Annotate
pragma, a suppressed assertion pragma, or a test marked skipped
or disabled. That is the no-sorry rule for this tree: a check is
not turned off to make a run look clean. The scan is a text
search. It is not a proof that every check in the program is the
right check.

On a throwaway copy, CI edits one spec without updating
`specs/LOCK`, and it inserts an Assume pragma. Both runs have to
fail. A third edit marks a test skipped, and that has to fail
too. A lock update whose pull-request text does not name
`specs/LOCK` has to fail. The clean tree has to pass.

## What is proved

`AI_Amplifier.Lock_Rule` is proved for the lock-compare rule.
`proof/item_16.out` is summary 11, 9 checks on that unit,
unproved 0. Two fingerprints match when every hex digit
matches, and the set holds only when every compared spec
matches. Hashing a file is not in that unit.
`AI_Amplifier.Locked` is plain Ada. `SPARK_Mode` is off.
The specs are plain Ada. They are tests. A fingerprint is
not a proof of the spec. This change does not add an Assume
pragma or an Annotate pragma.

The page reads a body that `tools/bake-locked.py` writes after
the specs have run. JavaScript copies the spec text, the
fingerprint, and the word pass or fail. It does not hash the
files. It does not decide the pass. If the module does not load,
the panel says so.
