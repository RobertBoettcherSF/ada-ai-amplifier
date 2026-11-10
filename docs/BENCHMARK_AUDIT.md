# Benchmark audit

Twenty short tasks about code this repository already has, five of
them broken on purpose, and an Ada auditor that runs before any
score is accepted.

Visible stamp: **v0.24.0-readme**

Live page: https://robertboettchersf.github.io/ada-ai-amplifier/?v=0.24.0-readme

## The idea, and the licences

Public benchmark cleanups are why this item exists. A score moves
when the questions are broken, so the questions have to be checked
before the number is trusted. This file links that work. It does
not copy it. No task text, no annotation, no table, and no program
from those projects is in this tree.

1. [SWE-bench](https://github.com/SWE-bench/SWE-bench) (Jimenez and
   others) is MIT. The licence file is
   [LICENSE](https://github.com/SWE-bench/SWE-bench/blob/main/LICENSE).
   The harness keeps an instance only when the tests fail before
   the fix and pass after it. A check that is already happy does
   not measure a solution. Nothing from that harness or those
   instances was copied, so that copyright notice is not reproduced
   here as if their code had been included.
2. OpenAI's notes on the Verified subset,
   [Introducing SWE-bench Verified](https://openai.com/index/introducing-swe-bench-verified/)
   and
   [Why we no longer evaluate SWE-bench Verified](https://openai.com/index/why-we-no-longer-evaluate-swe-bench-verified/),
   are OpenAI's pages. They describe tasks whose statement does not
   fix what a correct solution is, tests that reject a correct fix,
   and models that could reproduce a stored patch. This repository
   does not reproduce their wording, their counts, or their
   annotations.
3. [Are We Done with MMLU?](https://arxiv.org/abs/2406.04127)
   (Gema and others, 2024) and the
   [MMLU-Redux](https://huggingface.co/datasets/edinburgh-dawg/mmlu-redux)
   annotations sort questions into ground-truth problems and
   questions that cannot be answered as written, including a wrong
   label and a question with no correct option. MMLU-Redux is
   CC-BY-4.0. It is not included here. Do not copy it into this MIT
   tree. The paper's own notice is on the arXiv page.

The five rules below are an independent check against this
repository's own XOR labels, Fibonacci checker, and weight-file
reader. They are not those projects' guidelines. A duplicate
question, and an answer token sitting in the prompt, are included
because each one moves a score. The pages above are the credit for
auditing before trusting the number.

## What the auditor measures

`AI_Amplifier.Audit` reads a task file, recomputes each answer by
calling code that is already in this repository, and flags what
does not match. It does not read the planted list. That list is
`AI_Amplifier.Audit.Manifest`, and only the native test compares
the two.

| Rule | When it fires |
|---|---|
| `wrong-expected` | The recomputed text is not the expected field |
| `unsolvable` | This code has no answer for that input. Index 21 is past the Fibonacci checker. An XOR point that is not in the dataset would be the same kind of miss |
| `duplicate` | An earlier task has the same kind and the same input. The earlier task is not flagged for being copied |
| `accept-anything` | The grader accepts a fixed probe that is not the expected answer. `grade any` is that grader |
| `answer-leaked` | The expected answer is a token in the prompt, and that token is not one of the input tokens. A digit that is only the question's own input is not a leak |

A task can carry more than one flag. The seeded file has one each.
The order in the report is duplicate, then unsolvable, then
wrong-expected, then answer-leaked, then accept-anything.

Recompute uses:

| Kind | Call |
|---|---|
| `xor-label` | `MLP.Make_Dataset` on the XOR points, and the label stored there |
| `xor-count` | The count of that same dataset. The input has to be empty |
| `fib-answer` | `Recurse.Correct_Chain`, then `Check_Chain`. The answer is the one the checker reports at the base. An index above 20 does not build |
| `fib-stop` | `Replay_Recorded` on the chain whose name is the input, then the stop word |
| `weight-status` | `Hand_XOR`, `Write_Weights`, then `Read_Weights` after the input's edit: `roundtrip`, `shape ...`, or `value ...` |

`grade exact` accepts only the expected field. `grade any` accepts
every string, including the probe. Scoring compares the task's
`sample` field with that grader. The samples are written in the
file. They are not a model's replies. The page does not call a
model, and `audit_cli` does not either.

## The seeded file

Twenty tasks. Fifteen match the recomputed answer and are not
flagged. Five are planted.

| Task | What is wrong | Sample, and how the naive grader treats it |
|---|---|---|
| `fib-5-wrong` | Expected `9`. The checker says 5 | Sample `9` matches the bad key, so it counts as a hit |
| `fib-21` | Index 21 does not build. There is no answer to grade | Sample `10946` matches the expected field, so it counts as a hit |
| `xor-01-copy` | Same kind and input as `xor-01` | Sample `1` is right, and it is counted twice |
| `weight-any` | `grade any`. The file really does load a weight of 0 | Sample `nope` is accepted |
| `fib-4-leaked` | The prompt contains the token `3`, which is F(4) and is not the input | Sample `3` matches, because it was written out in the prompt |

The other fifteen are XOR labels, the XOR count, the hand-written
file read back, a shape `2 8 1`, a weight of 1000, a weight of
1001, a shape `2 4 1`, Fibonacci answers at 0, 1, 6, and 20, and
the stop word of `fib-6-bad-sum`. Six of those samples are wrong
on purpose (`xor-10`, `xor-11`, `weight-limit`, `fib-0`, `fib-1`,
`fib-stop-bad`). Nine match.

`bin/audit_test` requires every planted id to be flagged with that
one rule, and it requires every other task in the file to have no
flag. It also loads a second file whose ids are not the planted
ones, with the same five breaks, and a one-task file with no
breaks. The second file is there so a check that only recognised
the planted ids would fail.

## The two scores

Scoring is refused while a flagged task is still in the set.
Dropping those tasks is the cleaned score, and that one is
accepted.

On the seeded samples the program prints:

```text
Full set: 14 of 20. Not accepted: audit-flagged.
Cleaned set: 9 of 15. Accepted.
```

14 of 20 is 70 percent. 9 of 15 is 60 percent. The full set is
higher because the five broken tasks are all counted as hits: a
wrong key, an unsolvable item, a second copy of a hit, a grader
that accepts `nope`, and an answer copied out of the prompt. That
gap is the skew. The 70 percent figure is not an accepted score.

A file with no flags accepts the full set. The one-task check in
`bin/audit_test` is that case. Calling `Score` before `Examine`
is refused with `not-examined`, and the tally stays at 0 of 0.

## On the page

The audit section is drawn from `AI_Amplifier.Audit.Demo`. Ada
writes one line per task (`pass`, or `flag` and the rule names),
the line that says how many tasks were flagged, and the two score
sentences. JavaScript copies those strings into the list. It does
not recompute, and it does not decide that a score is accepted.

The panel runs the built-in file. It does not upload a task file.
`bin/audit_cli` with no arguments prints the same report. With
one path, it reads that file and runs the same `Load`, `Examine`,
and `Score_Line`. A file that does not parse exits 1. A parsed
file exits 0 even when the score is refused: the refusal is a
line of the report, not a crash.

## What this is not

- Not a proof. `AI_Amplifier.Audit` is plain Ada. `SPARK_Mode` is
  off. There is no Silver claim and no Gold claim.
- Not a general benchmark validator. It only flags these five
  kinds, and only when this repository's own code can recompute
  the answer. A wrong expected answer for a question we cannot
  recompute is invisible. A near-duplicate with a different input
  is invisible. A prompt that gives the answer away in other
  words, without the answer token, is invisible.
- Not a test of whether a model saw the task in training. The
  leak rule looks at the prompt text only.
- Not a claim about SWE-bench, MMLU, or any other published
  score. The 14 of 20 and 9 of 15 figures are this file's samples.
- Not a live model. The samples were typed into the task file.
