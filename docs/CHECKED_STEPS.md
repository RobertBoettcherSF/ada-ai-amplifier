# Checked steps, not just answers

Twelve worked solutions. Two grades. The answer-only grade
looks at the final number. The step grade accepts a solution
only when every step matches a value this repository recomputes.

Visible stamp: **v0.15.1-backlog**

Live page: https://robertboettchersf.github.io/ada-ai-amplifier/?v=0.15.1-backlog

## The idea, and the licences

Public work on process supervision compares a check of each
step with a check of the final answer alone. This file links
that work. It does not copy it. No sentence, no problem, no
solution, no label, and no program from those pages is in
this tree.

1. [Let's Verify Step by Step](https://arxiv.org/abs/2305.20050)
   (Lightman, Kosaraju, Burda, Edwards, Baker, Lee, Leike,
   Schulman, Sutskever, and Cobbe, 2023) is the arXiv record
   `2305.20050`. The record does not name a licence that
   permits copying the paper into this tree. The authors hold
   the copyright. Nothing from it is included here.
2. The dataset released with that paper is
   [openai/prm800k](https://github.com/openai/prm800k). Its
   [LICENSE](https://github.com/openai/prm800k/blob/main/LICENSE)
   is MIT, copyright 2023 OpenAI. That licence would allow a
   copy of the software if the notice were kept. This tree
   does not contain the dataset, the labeler instructions,
   the grading program, or any solution from it. The MATH
   problems inside that dataset are not from this repository.
3. [Solving math word problems with process- and outcome-based feedback](https://arxiv.org/abs/2211.14275)
   (Uesato, Kushman, Kumar, Song, Siegel, Wang, Creswell,
   Irving, and Higgins, 2022) is the arXiv record `2211.14275`.
   The record does not name a licence that permits copying
   the paper. Nothing from it is included here.
4. [Training Verifiers to Solve Math Word Problems](https://arxiv.org/abs/2110.14168)
   (Cobbe, Kosaraju, Bavarian, Chen, Jun, Kaiser, Plappert,
   Tworek, Hilton, Nakano, Hesse, and Schulman, 2021) is the
   arXiv record `2110.14168`, an outcome-verifier paper. The
   record does not name a licence that permits copying it.
   Nothing from it is included here.

The twelve solutions below were written in this repository,
against this repository's own arithmetic.

## What this can check, and what it cannot

Ada accepts a step when the number on the line matches the
number our own code returns for that step, within `0.00005`
for a `Float`. A Fibonacci step is accepted when
`AI_Amplifier.Recurse.Check_Step` accepts it against the true
previous state.

That is possible here because every step is a call we already
have:

- an XOR forward pass is `Mat_Vec`, `Add`, `Tanh`, and
  `Sigmoid` on the hand-written net
- one training update is `Mean_Loss`, `Predict`, `Backprop`,
  and `Step` on that same net and the four XOR points
- a Fibonacci chain is the recurrence `Recurse` already checks
- a vector sum is `Tensors.Add` of `(2, -1, 4)` and
  `(3, 5, -2)`, then the sum of the three components

Most real reasoning is not like that. A step in an essay, a
plan, or a proof is not a value this library can recompute.
This checker cannot grade it. A pass here is not evidence
about a process reward model, and it is not a claim that the
same check works on MATH or on any other benchmark.

## The twelve solutions

A solution is a name, a problem, one step per line, and an
answer. Blank lines and lines whose first visible character
is `#` are ignored. The answer-only grade ignores the steps.
The step grade is a pass only when every required step is
present, in order, and matches, and the answer matches too.
The first bad step is the one the page marks.

| Solution | Answer only | Steps | First bad step |
|---|---|---|---|
| `xor-00-right` | pass | pass | |
| `xor-10-cancel` | pass | fail | step 2, `bad-value` |
| `xor-11-skip` | pass | fail | step 2, `skipped-step` |
| `xor-00-guess` | pass | fail | step 1, `guessed-first` |
| `xor-01-wrong` | fail | fail | step 8, `wrong-answer` |
| `train-right` | pass | pass | |
| `train-cancel` | pass | fail | step 6, `bad-value` |
| `fib-6-right` | pass | pass | |
| `fib-5-cancel` | pass | fail | step 2, `bad-arithmetic` |
| `fib-4-skip` | pass | fail | step 2, `not-toward-base` |
| `sum-right` | pass | pass | |
| `sum-guess` | pass | fail | step 1, `guessed-first` |

Eleven answers pass. Four solutions pass the steps. The
sentence on the page is `12 solutions. Answer-only passes 11.
Steps pass 4. Only the steps count.`

`xor-10-cancel` is the cancelling pair. On input `(1, 0)` the
forward pass returns tanh of `3` and tanh of `-3`. The
solution writes each of those `0.05` lower. In
`6*h1 - 6*h2 - 6` the two shifts cancel, so the output logit
and the class stay the ones `Sigmoid` returns. The class is
1. The first bad step is `h1`.

`xor-11-skip` keeps the right class for `(1, 1)` and omits
both tanh steps. The line that jumps ahead is `h2-logit`.

`xor-00-guess` writes `answer 0` before any step. The lines
under it are a different story: both voting units at 0, then
the output bias alone. The class happens to be right.

`xor-01-wrong` runs the real forward pass for `(0, 1)` and
then writes class 0. The output is about `0.997`.

`train-cancel` writes a bias gradient `0.25` above the one
`Backprop` returns. The bias on the next line is still the
bias `Step` stores, which is not what that gradient would
have produced. The answer matches `Step`. The first bad step
is `grad-b2`.

`fib-5-cancel` follows `Recurse` for the first step, adds one
too many on the step that leaves index 3, carries that sum,
and then states the true pair. The answer is still F(5),
which is 5. The first bad step is `bad-arithmetic`.

`fib-4-skip` omits the step that leaves index 2. The answer
is still F(4), which is 3. The first bad step is
`not-toward-base`.

`sum-guess` states the total `11` before the three components
of `Add`. The components underneath are the right ones.

The planted list lives in `AI_Amplifier.Steps.Manifest`. The
checker does not read it. `bin/steps_test` compares the two.

## A file of your own

`bin/steps_cli` with no arguments prints the table above.
`steps_cli FILE` grades one solution in the same shape. A
file whose steps fail exits 1. The page does not run this
program.

```text
problem xor 0 1
step h1-logit 3
step h1 0.99505485
step h2-logit -3
step h2 -0.99505479
step silent 0
step out-logit 5.94065857
step output 0.99737657
answer 1
```

The problems a file may name are `xor` with inputs 0 or 1,
`train` for the one step above, `fib` with an index from 0
to 12, and `sum` for the two vectors above. Anything else is
`unknown-problem`.

## What is proved

Nothing in this item. `AI_Amplifier.Steps` and its demo are
plain Ada. `SPARK_Mode` is off. There is no new proof, no
`pragma Annotate`, and no `pragma Assume`. The tensor kernels
these steps call stay at the levels already in the proof
table. A pass in `bin/steps_test` is a test. It is not a
proof that every future solution will be graded the same way,
and it is not a proof about reasoning outside this code.
