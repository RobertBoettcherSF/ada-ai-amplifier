# Reasoning summary vs checked steps

Eight worked problems. Each one has a short written summary
and the list of steps that were actually taken. Ada checks
each step on its own, then compares the summary with those
steps.

Visible stamp: **v0.20.0-readme**

Live page: https://robertboettchersf.github.io/ada-ai-amplifier/?v=0.20.0-readme

## The idea, and the licence

[openai/math](https://github.com/openai/math) releases abridged
summaries of a model's reasoning next to results at different
stages of verification. The repository is Apache-2.0. That
licence would allow a copy if the notice were kept. This tree
does not contain one. No manuscript, no summary, no problem,
and no sentence from that repository is here. The link is the
credit for setting a written summary next to the work it
describes.

The eight summaries below were written in this repository.
They are not the words of a model. Nothing here reproduces a
lab result.

## What is checked

Each step is one line. `AI_Amplifier.Steps.Check_Alone` asks
the item 15 checker for that line alone:

| Verdict | When |
|---|---|
| checked-correct | The line is a step this repository recomputes, and the number matches |
| checked-wrong | The line is a step this repository recomputes, and the number does not match |
| not checkable | The line is a sentence, or a name the checker does not recompute |

Order is not a failure of that check. A later line can be
correct even when an earlier line is wrong. The whole-solution
grade from item 15 is a different question. It still lives on
the checked-steps panel.

`AI_Amplifier.Summary_Rules` then compares the summary with
those verdicts. A summary is flagged for the first of these:

| Flag | What it means |
|---|---|
| omitted-failure | A checked-wrong step is not named by any sentence |
| phantom-step | A sentence names a step that was not taken |
| smoother-story | A sentence presents a wrong step as the true value, or lists taken steps in a smoother order than they were written |

A sentence that names a wrong step and says that step failed
is not flagged. The summary and the steps agree that the step
is wrong.

## The eight problems

| Problem | Summary check | What it shows |
|---|---|---|
| `xor-clean` | none | Every step is checked-correct, and the summary says so |
| `xor-smooth` | smoother-story | The summary reads as a clean forward pass. `h1` and `h2` are checked-wrong |
| `xor-omit` | omitted-failure | The summary describes the forward pass and leaves out the answer, which is checked-wrong |
| `fib-phantom` | phantom-step | Every taken step is checked-correct. The summary also claims a step at index 13 |
| `fib-honest` | none | Two steps are checked-wrong, and the summary says so |
| `sum-reorder` | smoother-story | Every step is checked-correct. The summary tells the addition in a smoother order than the lines |
| `sum-note` | none | One sentence is not checkable. The numbers around it are checked-correct |
| `train-omit` | omitted-failure | The summary describes the stored bias and leaves out `grad-b2`, which is checked-wrong |

Five summaries are flagged. Three of those sit on a wrong
step: the summary can read cleanly while a step underneath is
wrong. Two are flagged while every checked step is correct:
the summary is the part that does not hold. One summary keeps
a wrong step and is not flagged, because it tells that failure.
The sentence on the page is `8 problems. Summaries flagged 5.
3 of those sit on a wrong step. 2 are flagged while every
checked step is correct.`

`bin/summary_cli` prints the same table. The page does not
run that program.

## What is proved

`AI_Amplifier.Summary_Rules` is SPARK. `proof/item_19.out`
is a level 2 run of that unit alone: summary 22, 15 checks
on the unit, unproved 0. `proof/summary_rules.out` is the
same bytes. The proved assertion says an omitted flag points
at a checked-wrong step, and the other flags point at a
sentence. That is not a proof that every future summary will
be flagged the same way, and it is not a proof of the eight
summaries or of the step checker they call.

The tensor runs are separate. This item is not part of those
totals. `AI_Amplifier.Summary` and its demo are plain Ada.
There is no `pragma Annotate` and no `pragma Assume`.

The `STATUS` row is proved for the flag-rule unit. It says the
summary package is not in that run.
