# Second checker

The verdicts of items 11, 12, and 15 are graded twice. The second
grader is `AI_Amplifier.Recheck`. It does not call
`AI_Amplifier.Traces`, `AI_Amplifier.Audit`, or
`AI_Amplifier.Steps`.

Visible stamp: **v0.21.0-moreproofs**

Live page: https://robertboettchersf.github.io/ada-ai-amplifier/?v=0.21.0-moreproofs

## The idea, and the licence

[formal-math](https://github.com/anthropics/formal-math) checks a
result with a second kernel, written apart from the first, and a
comparator that fails when the two disagree. The repository is
Apache-2.0. That licence would allow a copy if the notice were
kept. This tree does not contain one. No file, no checker, and no
sentence from that repository is here. The link is the credit for
the idea. The package in `src/ai_amplifier-recheck.adb` is a new
program.

## What each side recomputes

The first checkers are the ones items 11, 12, and 15 already
shipped. The second checker has its own parser, its own XOR
forward pass, its own one-step gradient, its own Fibonacci walk,
and its own reading of the benchmark text.

A trace is still run on `AI_Amplifier.MLP`. That unit is the
trainer the verdict is about. The second checker does not call
the first checker's replay or its `Decide`. It applies the step
itself and then uses its own rules: loss under `0.05`, class 1
at least `0.8`, class 0 at most `0.2`, weights inside ±`1000`,
and a loss gap of `0.0001`.

A checked-step solution is the text `AI_Amplifier.Steps` stores.
Both graders read that text. The second grader does not call
`Grade`. A float matches within `0.00005`. A Fibonacci step is
accepted when this unit's own recurrence accepts it. The
hand-written net is the six weights named in
`docs/WEIGHT_SPACE.md`: OR, AND, and the output that is OR and
not AND. The series for tanh, sigmoid, and the log are written
in the second checker. They are not the series in
`AI_Amplifier.Tensors`.

A benchmark task is read by this unit's own parser from its own
copy of the twenty tasks. XOR labels are the four points. The
Fibonacci answer is this unit's walk, and index 21 has no
answer. A weight status is the shape `2 8 1` and the limit
`1000`. The stop word of `fib-6-bad-sum` is this unit's check of
that recorded walk.

## The line they both emit

Every case becomes one line:

```text
verdict <word> reason <word> bad <number>
```

A checked step adds `answer pass` or `answer fail`. `bad` is the
first bad row, or `0` when the case has no row to mark. A trace
verdict is about one next step, so `bad` is `0`. An audit flag
is a rule name, not a row, so `bad` is `0` there too.

`bin/recheck_test` prints `recheck ok` when every line matches.
A mismatch names the case and prints both lines. The counts on
this tree are 44 of 44 for the wrong turns (four traces, codes
`0` through `10`), 22 of 22 for the audit (twenty tasks and the
two scores), and 12 of 12 for the checked steps.

## What CI does with a planted bug

`tools/check-recheck-selftest.sh` builds a throwaway copy. The
copy is not a git checkout: `.git` is not copied, and the script
stops if `git rev-parse` succeeds there. On that copy it changes
one checker at a time. A wrong reason in the trace checker, a
missing `wrong-expected` flag in the auditor, a skipped
`bad-value` in the step checker, and the same kind of edit in
`AI_Amplifier.Recheck` each have to make the comparison fail.
The failure names the case and both answers. The clean tree
has to pass.

## On the page

`build.sh` runs the comparison and writes
`obj/gen/recheck-report.txt`. The page embeds that file.
JavaScript copies the three counts and any disagreement lines.
It does not grade a case. If the report was not written, the
panel says so.

## What is proved

`AI_Amplifier.Agree_Rule` is proved for the agreement count.
`proof/item_17.out` is summary 9, 7 checks on that unit,
unproved 0. A pair holds when the agree count equals the
total and the total is positive. `AI_Amplifier.Recheck` is
plain Ada. `SPARK_Mode` is off. Agreement is not a proof of
either checker. This change does not add an Assume pragma
or an Annotate pragma.

Agreement makes a shared bug less likely. It does not prove
either checker right. A mistake that both graders share still
matches. Both were written in this project, by the same kind of
session, against the same notes. The comparison is a test. It
is not a proof that the verdicts are the right verdicts, and it
is not a proof about reasoning outside these cases.
